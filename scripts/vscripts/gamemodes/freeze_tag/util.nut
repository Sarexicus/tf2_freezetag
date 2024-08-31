// FREEZE TAG SCRIPT - UTILITY
// by Sarexicus and Le Codex (try to find which part is whom's)
// -------------------------------

::vectriple <- function(a) { return Vector(a, a, a); }
::Distance <- function(vec1, vec2) { return (vec1-vec2).Length(); }
::max <- function(a, b) { return (a > b) ? a : b; }
::min <- function(a, b) { return (a < b) ? a : b; }
::playerManager <- Entities.FindByClassname(null, "tf_player_manager");

::mainLogic <- this;
::mainLogicEntity <- self;
::MaxPlayers <- MaxClients().tointeger();
::ROOT <- getroottable();

// this value allows us to detect and cancel custom death events
::custom_death_flags <- 16384;

spectator_proxy <- null;

// table folding (constants, netprops)
if (!("ConstantNamingConvention" in ROOT)) // make sure folding is only done once
{
    // fold constants
	foreach (a,b in Constants)
		foreach (k,v in b)
			ROOT[k] <- v != null ? v : 0;

    // fold netprops
    foreach (k, v in ::NetProps.getclass())
        if (k != "IsValid")
            ROOT[k] <- ::NetProps[k].bindenv(::NetProps);
}

::GetPlayerUserID <- function(player)
{
    return NetProps.GetPropIntArray(playerManager, "m_iUserID", player.entindex())
}

// change the classname of an entity to prevent preserving it
function UnpreserveEntity(entity) {
    SetPropString(entity, "m_iClassname", "info_teleport_destination");
}

function ShowPlayerAnnotation(player, text, lifetime, follow_entity = null) {
    local params = {
        text = text,
        id = player.entindex(),
        visibilityBitfield = 1 << player.entindex(),
        lifetime = lifetime,
        show_effect = false
    };
    if (follow_entity == null) {
        params.worldPosX <- 0.0;
        params.worldPosY <- 0.0;
        params.worldPosZ <- 0.0;
    } else {
        params.follow_entindex <- follow_entity.entindex()
    }

    SendGlobalGameEvent("show_annotation", params);
}

function SafeDeleteFromScope(scope, value) {
    if (scope.rawin(value) && scope[value] != null && scope[value].IsValid()) {
        scope[value].Kill();
    }
    scope[value] <- null;
}

function CreateSpectatorProxy() {
    spectator_proxy = SpawnEntityFromTable("info_observer_point", {
        "targetname": "spectator_proxy"
    });
}

function ForEachAlivePlayer(callback, params = {}) {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        if(GetPropInt(player, "m_lifeState") != 0) continue;

        callback(player, params);
    }
}

function FindFirstAlivePlayerOnTeam(team) {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        if(GetPropInt(player, "m_lifeState") != 0) continue;

        if (player.GetTeam() == team) return player;
    }

    return null;
}

::RunWithDelay <- function(next, delay, args=clone [mainLogic]) {
    local callbackName = UniqueString("callback");
    mainLogicEntity.ValidateScriptScope()
    mainLogicEntity.GetScriptScope()[callbackName] <- function() {
        next.acall(args);
    }

    EntFireByHandle(mainLogicEntity, "RunScriptCode", callbackName + "()", delay, null, null);
    EntFireByHandle(mainLogicEntity, "RunScriptCode", "delete " + callbackName, delay+0.1, null, null);
}

::TeamName <- function(team, natural=false) {
    return natural ?
        (team == Constants.ETFTeam.TF_TEAM_RED ? "Red" : "Blue") :
        (team == Constants.ETFTeam.TF_TEAM_RED ? "red" : "blu")
}

enum LIFE_STATE
{
    ALIVE = 0,
    DYING = 1,
    DEAD = 2,
    RESPAWNABLE = 3,
    DISCARDBODY = 4
}

::IsPlayerAlive <- function(player)
{
    return GetPropInt(player, "m_lifeState") == LIFE_STATE.ALIVE;
}

::IsValidPlayer <- function(player)
{
    try
    {
        return player != null && player.IsValid() && player.IsPlayer() && player.GetTeam() > 1;
    }
    catch(e)
    {
        return false;
    }
}

::GetAllPlayers <- function() {
    for (local i = 0; i <= MaxPlayers; i++) {
        local player = PlayerInstanceFromIndex(i);
        if (!IsValidPlayer(player)) continue;

        yield player;
    }

    return null;
}

::GetAliveTeamPlayerCount <- function(team)
{
    local aliveCount = 0;
    foreach (player in GetAllPlayers()) {
        if (IsPlayerAlive(player) && player.GetTeam() == team) aliveCount++;
    }
    return aliveCount;
}

::StunPlayer <- function(player, time) {
    local trigger_stun = SpawnEntityFromTable("trigger_stun", {
        targetname = "trigger_stun",
        stun_type = 2,
        stun_duration = time,
        move_speed_reduction = 0,
        trigger_delay = 0,
        ///filtername = "filter_team_blu",
        StartDisabled = 0,
        spawnflags = 1,
        solid = 2,
        "OnStunPlayer#1": "!self,Kill,0,0.01,-1",
    });
    EntFireByHandle(trigger_stun, "EndTouch", "", 0.0, player, player);
    EntFireByHandle(trigger_stun, "Kill", "", 0.1, null, null);
}

::KillPlayerSilent <- function(player) {
    if (!IsPlayerAlive(player)) return;
    NetProps.SetPropInt(player, "m_iObserverLastMode", 5);
    local team = NetProps.GetPropInt(player, "m_iTeamNum");
    NetProps.SetPropInt(player, "m_iTeamNum", 1);
    player.DispatchSpawn();
    NetProps.SetPropInt(player, "m_iTeamNum", team);
}

::CleanRespawn <- function(player) {
    player.ForceRespawn();
    player.Weapon_Equip(GetPropEntityArray(player, "m_hMyWeapons", 0));
    RunWithDelay(function(player) { player.Regenerate(true) }, 0, [this, player]);
    RunWithDelay(CountAlivePlayers, 0.05);
}

::SetRespawnTime <- function(player, time) {
    NetProps.SetPropFloatArray(GAMERULES, "m_flNextRespawnWave", time, player.entindex());
}

::SOURCE_TV <- null;
::GetSourceTV <- function() {
    if (SOURCE_TV) return SOURCE_TV;

    for (local i = 1; i <= MaxPlayers; i++) {
        if (PlayerInstanceFromIndex(i) == null) {
            local entity = EntIndexToHScript(i)
            if (entity && entity.IsPlayer()) {
                SOURCE_TV = entity;
                break;
            }
        }
    }

    return SOURCE_TV;
}

// Credit: Lizard of Oz
::detectedIssues <- {};
::ErrorHandler <- function (e)
{
    local stackInfo = getstackinfos(2);
    local key = format("'%s' @ %s#%d", e, stackInfo.src, stackInfo.line);
    local target = GetSourceTV() || GetListenServerHost();
    if (!target) return;

    if (!(key in detectedIssues))
    {
        detectedIssues[key] <- [e, 1];
        PrintError(target, "A NEW ERROR HAS OCCURRED", e);
    }
    else
    {
        detectedIssues[key][1]++;
        ClientPrint(target, 3, format("A ERROR HAS OCCURRED [%d] TIMES: [%s]", detectedIssues[key][1], key));
    }
}
seterrorhandler(ErrorHandler);

::PrintError <- function(player, title, e, printfunc = null)
{
    if (!printfunc)
        printfunc = @(m) ClientPrint(player, 3, m);
    printfunc(format("\n%s [%s]", title, e));
    printfunc("CALLSTACK");
    local s, l = 3;
    while (s = getstackinfos(l++))
        printfunc(format("*FUNCTION [%s()] %s line [%d]", s.func, s.src, s.line));
    printfunc("LOCALS");
    if (s = getstackinfos(3))
        foreach (n, v in s.locals)
        {
            local t = type(v);
            t ==    "null" ? printfunc(format("[%s] NULL"  , n))    :
            t == "integer" ? printfunc(format("[%s] %d"    , n, v)) :
            t ==   "float" ? printfunc(format("[%s] %.14g" , n, v)) :
            t ==  "string" ? printfunc(format("[%s] \"%s\"", n, v)) :
                             printfunc(format("[%s] %s %s" , n, t, v.tostring()));
        }
}