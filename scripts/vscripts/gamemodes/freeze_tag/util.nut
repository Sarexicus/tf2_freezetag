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

IncludeScript(VSCRIPT_PATH + "error_handler.nut", this);

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
::UnpreserveEntity <- function(entity) {
    SetPropString(entity, "m_iClassname", "info_teleport_destination");
}

::ShowPlayerAnnotation <- function(player, text, lifetime, follow_entity = null) {
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

::SafeDeleteFromScope <- function(scope, value) {
    if (scope.rawin(value) && scope[value] != null && scope[value].IsValid()) {
        scope[value].Kill();
    }
    scope[value] <- null;
}

::ForEachAlivePlayer <- function(callback, params = {}) {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i);
        if (player == null) continue;
        if(!IsPlayerAlive(player)) continue;
        callback(player, params);
    }
}

::FindFirstAlivePlayerOnTeam <- function(team) {
    local first_player = null;
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i);
        if (player == null) continue;
        if (!IsPlayerAlive(player)) continue;
        if (!first_player) first_player = player;  // For spectators
        if (player.GetTeam() == team) return player;
    }

    return first_player;
}

::FindLastAlivePlayerOnTeam <- function(team) {
    local last_player = null;
    local last_team_player = null
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i);
        if (player == null) continue;
        if (!IsPlayerAlive(player)) continue;
        last_player = player;  // For spectators
        if (player.GetTeam() == team) last_team_player = player;
    }

    return last_team_player ? last_team_player : last_player;
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
        (team == TF_TEAM_RED ? "Red" : "Blue") :
        (team == TF_TEAM_RED ? "red" : "blu")
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
        return player != null && player.IsValid() && player.IsPlayer();
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
}

::SetRespawnTime <- function(player, _time) {
    NetProps.SetPropFloatArray(GAMERULES, "m_flNextRespawnWave", _time, player.entindex());
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

::PlayerHasPainTrain <- function(player) {
    for (local i = 0; i < 7; i++){
        local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
        if (!weapon || !weapon.IsValid()) continue;
        if (GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex") == 154) {
            return true;
        }
    }
    return false;
}

::PlayerHasYERActive <- function(player) {
    local weapon = player.GetActiveWeapon();
    if (!weapon || !weapon.IsValid()) return;
    local index = GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
    return index == 225 || index == 574;
}

::GetWeaponModel <- function(wep_idx)
{
    // spawn an econ entity weapon from its item ID specifically to grab its modelname
    local wearable = Entities.CreateByClassname("tf_wearable");
    SetPropInt(wearable, "m_fEffects", 32);
    wearable.SetSolidFlags(4);
    wearable.SetCollisionGroup(11);
    SetPropInt(wearable, "m_AttributeManager.m_Item.m_bInitialized", 1);
    SetPropInt(wearable, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", wep_idx);
    Entities.DispatchSpawn(wearable);

    local name = wearable.GetModelName();
    wearable.Kill();
    return name;
}

::StorePlayerWeaponIndex <- function(player) {
    local scope = player.GetScriptScope();
    scope.weapon_index <- GetPropInt(player.GetActiveWeapon(), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
}

::GetGroundedSequenceName <- function(player) {
    local sequence_name = player.GetSequenceName(player.GetSequence());
    // local fraction = TraceLine(player.GetOrigin() - Vector(0, 0, 8), player.GetOrigin() - Vector(0, 0, 24), player);
    // if (fraction < 1.0) return sequence_name;

    local prefixes = ["run", "stand", "crouch_walk", "crouch", "airwalk", "swim", "a_jumpfloat", "a_jumpstart", "a_jump_float", "a_jump_start", "jumpfloat", "jumpstart", "jump_float", "jump_start"];
    foreach (prefix in prefixes)
        if (startswith(sequence_name.tolower(), prefix))
            return "run" + sequence_name.slice(prefix.len());

    local explosive_jumps_prefixes = [ "melee_fall", "primary_fall_stomp", "primary_float" ];
    foreach (prefix in explosive_jumps_prefixes)
        if (startswith(sequence_name.tolower(), prefix))
            return "run_primary";

    if (sequence_name == "ref")
        return "run_melee";

    printl(sequence_name);
    return sequence_name;
}

::DetermineLastPlayerAlive <- function(player) {
    local alive = GetAliveTeamPlayerCount(player.GetTeam());
    if (alive == 1) {
        local last_man_alive = FindFirstAlivePlayerOnTeam(player.GetTeam());
        local scope = last_man_alive.GetScriptScope();
        if (scope.last_man_alive_next_time < Time()) {
            EmitSoundEx({
                sound_name = "Announcer.AM_LastManAlive0" + (rand() % 4 + 1),
                filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
                entity = last_man_alive
            });

            scope.last_man_alive_next_time = Time() + last_man_alive_cooldown;
        }
    }
}

::StorePlayerPoseParameters <- function(player) {
    local scope = player.GetScriptScope();
    scope.ang <- player.GetAbsAngles();
    scope.eye_ang <- player.EyeAngles();
    scope.vel <- player.GetAbsVelocity();
}

// distance check but the Z level is measured separately, forming a cylinder shape
::CylindricalDistanceCheck <- function(point_a, point_b, distance) {
    local adjusted_z = Vector(point_a.x, point_a.y, point_b.z);
    if (Distance(adjusted_z, point_b) > distance) return false;
    if (abs(point_a.z - point_b.z) > distance) return false;

    return true;
}

::RotateAroundVector <- function(v, axis, ang) {
    // Rodrigues formula
    return v * cos(ang) + axis.Cross(v) * sin(ang) + axis * axis.Dot(v) * (1 - cos(ang))
}
