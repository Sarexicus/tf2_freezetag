// FREEZE TAG SCRIPT - UTILITY
// by Sarexicus and Le Codex (try to find which part is whom's)
// -------------------------------

function vectriple(a) { return Vector(a, a, a); }
function Distance(vec1, vec2) { return (vec1-vec2).Length(); }
function max(a, b) { return (a > b) ? a : b; }

::MaxPlayers <- MaxClients().tointeger();
::ROOT <- getroottable();

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


function ForEachAlivePlayer(callback, params = {}) {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        if(GetPropInt(player, "m_lifeState") != 0) continue;

        callback(player, params);
    }
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
    return NetProps.GetPropInt(player, "m_lifeState") == LIFE_STATE.ALIVE;
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
    for (local i = 0; i < MaxClients(); i++) {
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

::CleanRespawn <- function(player) {
    player.ForceRegenerateAndRespawn();
    // HACK: If we don't do this, for some reason, players stay in a "dead" state
    RunWithDelay(function() {
        NetProps.SetPropInt(player, "m_lifeState", LIFE_STATE.ALIVE);
    }, 0.1);
    player.Weapon_Equip(GetPropEntityArray(player, "m_hMyWeapons", 0));
    RunWithDelay(CountAlivePlayers, 0.5);
}