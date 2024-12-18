// FREEZE TAG SCRIPT
// by Sarexicus and Le Codex
// -----------------------------------------------

// !CompilePal::IncludeDirectory("scripts/vscripts/gamemode/freezetag")
// !CompilePal::IncludeFile("resource/ui/hudobjectivefreezetag.res")
// !CompilePal::IncludeFile("particles/ft_fx.pcf")
// !CompilePal::IncludeDirectory("materials/effects/freezetag")
// !CompilePal::IncludeDirectory("materials/freeze_tag")
// !CompilePal::IncludeDirectory("materials/hud")
// !CompilePal::IncludeDirectory("materials/test")
// !CompilePal::IncludeDirectory("models/freezetag/player")
// !CompilePal::IncludeDirectory("sound/freeze_tag")

if (!getroottable().rawin("EventsID")) {
    ::EventsID <- UniqueString();
} else {
    delete getroottable()[EventsID];
}

if (developer() >= 1) printl("[FREEZE TAG] Event namespace: " + EventsID);
getroottable()[EventsID] <- {};

::VSCRIPT_PATH <- "gamemodes/freeze_tag/";
IncludeScript(VSCRIPT_PATH + "util.nut", this);
IncludeScript(VSCRIPT_PATH + "arena.nut", this);

version <- "1.12";                     // Current version. DO NOT MODIFY
if (developer() >= 1) printl("[FREEZE TAG LOADED] Version " + version);

// CONFIG
// -----------------------------------------------
::health_multiplier_on_thaw <- 0.5;     // how much health a frozen player gets when they thaw (fraction of max hp)
::min_thaw_time <- 1.0;                 // how many seconds it takes for one player to thaw a frozen player at best
::max_thaw_time <- 5.0;                 // how many seconds it takes for one player to thaw a frozen player at worst
::min_thaw_time_percent <- 0.2;         // how much of a team's players have to be alive at most for the thaw time to be minimal
::max_thaw_time_percent <- 0.75;        // how much of a team's players have to be alive at least for the thaw time to be maximal
::decay_time <- 8.0;                    // how many seconds it takes for thawing progress to decay from full to empty
::thaw_distance <- 128.0;               // how close to a frozen player on your team you have to be to start thawing them
::medigun_thawing_efficiency <- 0.66;   // how efficient is thawing with a Medigun outside the thaw distance
::players_solid_when_frozen <- false;   // whether frozen players have collisions
::point_unlock_timer <- 75;             // how many seconds it takes the point to unlock

::freeze_sound <- "Icicle.TurnToIce";
::thaw_start_sound <- "freeze_tag/thawstart.wav";
::thaw_block_sound <- "freeze_tag/thawblock.wav";
::thaw_finish_sound <- "freeze_tag/thawfinish.wav";
::thaw_particle <- "ft_playerthaw";
::fake_thaw_sound <- "freeze_tag/freezefeign.wav";
::fake_disappear_particle <- "ghost_smoke";
::regen_particle <- "ft_playeraura";
::reveal_particle <- "snow_steppuff01";

::tick_rate <- 0.1;   // how often the base think rate polls

// -----------------------------------------------

IncludeScript(VSCRIPT_PATH + "freeze.nut", this);
IncludeScript(VSCRIPT_PATH + "thaw.nut", this);
IncludeScript(VSCRIPT_PATH + "regen.nut", this);

function PrecacheParticle(particle_name) {
    PrecacheEntityFromTable({
        classname = "info_particle_system",
        effect_name = particle_name
    });
}

function Precache() {
    PrecacheParticle(thaw_particle);
    PrecacheParticle(regen_particle);
    PrecacheParticle(fake_disappear_particle);
    PrecacheParticle(reveal_particle);

    PrecacheScriptSound(freeze_sound);
    PrecacheScriptSound(thaw_start_sound);
    PrecacheScriptSound(thaw_block_sound);
    PrecacheScriptSound(thaw_finish_sound);
    PrecacheScriptSound(fake_thaw_sound);
    for (local i = 1; i <= 4; i++) PrecacheScriptSound("Announcer.AM_LastManAlive0" + i);
    PrecacheScriptSound("Announcer.AM_FlawlessVictoryRandom");
    PrecacheScriptSound("Announcer.AM_FlawlessDefeatRandom");
}

function OnPostSpawn() {
    RunWithDelay(CreateSpectatorProxy, 1);
    SpawnEscrows();

    if (NavMesh.GetNavAreaCount() == 0) {
        ClientPrint(null, HUD_PRINTCENTER, "[WARNING] The map contains no nav mesh! Statues will appear where the player has died, even if that spot is invalid (mid-air or out of reach)");
    }

    // re-enable respawn times if not in developer mode
    if (Convars.GetInt("mp_disable_respawn_times") > 0 && GetDeveloperLevel() < 1) {
        Convars.SetValue("mp_disable_respawn_times", 0);
        ClientPrint(null, HUD_PRINTTALK, "\x07cdaa00[Warning] \x07FBECCBFreeze Tag does not support mp_disable_respawn_times. Disabling.");
    }
}

local _ticks = 0;
function Think() {
    // skip running any thinks when WFP is going
    if (IsInWaitingForPlayers()) return;

    foreach(player in GetAllPlayers()) {
        local scope = player.GetScriptScope();
        if (scope.late_joiner) continue;  // Don't process late joiners

        // only run the freeze think every second tick, for performance's sake
        if (_ticks % (tick_rate * 2) == 0) {
            FreezeThink(player);
        }

        if (STATE == GAMESTATES.ROUND) {
            ThawThink(player);
            RegenThink(player);

            if (!IsPlayerAlive(player)) {
                local ragdoll = GetPropEntity(player, "m_hRagdoll");
                if (ragdoll && ragdoll.IsValid()) {
                    ragdoll.Destroy();
                    SetPropEntity(player, "m_hRagdoll", null);
                }
            }
        }
    }

    deadRingerSpies.clear();

    _ticks += tick_rate;
    if (_ticks > 1) _ticks = 0;
    return tick_rate;
}

::RoundStart <- function() {
    foreach (player in GetAllPlayers()) {
        local scope = player.GetScriptScope();
        ResetPlayer(player);
        SetupPlayer(player);
        player.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null);
    }
}

::SetupPlayer <- function(player) {
    local scope = player.GetScriptScope();
    scope.late_joiner <- true;
    scope.frozen <- false;

    scope.freeze_positions <- [];
    scope.position_index <- 0;
    scope.freeze_point <- null;
    scope.solid <- false;

    scope.revive_progress_sprite <- null;
    scope.revive_marker <- null;
    scope.frozen_player_model <- null;
    scope.particles <- null;
    scope.glow <- null;
    scope.hidden <- false;

    scope.revive_unlock_time <- 0;
    scope.revive_unlock_max_time <- revive_unlock_time;
    scope.revive_progress <- 0;
    scope.revive_playercount <- 0;
    scope.revive_players <- [];
    scope.revive_blocked <- false;
    scope.is_medigun_revived <- false;

    scope.spectate_origin <- null;
    scope.did_force_spectate <- false;
    scope.spectating_self <- false;

    scope.player_class <- 0;
    scope.ammo <- {};
    scope.ang <- QAngle(0, 0, 0);
    scope.eye_ang <- QAngle(0, 0, 0);

    scope.last_thaw_time <- 0;
    scope.regen_amount <- 0;
    scope.partial_regen <- 0;

    scope.highest_thawing_player <- null;

    scope.last_man_alive_next_time <- 0;
}

// EVENTS
// -----------------------------
getroottable()[EventsID].OnGameEvent_teamplay_round_start <- function(params) {
    if(IsInWaitingForPlayers()) {
        EntFire("setupgate*", "Open", "", 0, null);
        return;
    }
    ChangeStateToSetup();
}

getroottable()[EventsID].OnGameEvent_player_team <- function(params) {
    // if a player changes team, remove their statue
    local player = GetPlayerFromUserID(params.userid);
    if (player == null) return;

    local scope = player.GetScriptScope();
    if (params.team != params.oldteam && STATE == GAMESTATES.ROUND) {
        ResetPlayer(player);
        SetupPlayer(player);
        scope.frozen = true;
    }
}

getroottable()[EventsID].OnGameEvent_player_spawn <- function(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (player == null) return;

    player.ValidateScriptScope();
    local scope = player.GetScriptScope();
    if (params.team == 0) {
        SetupPlayer(player);
    } else if (STATE == GAMESTATES.SETUP) {
        scope.late_joiner <- false;
    } else if (STATE == GAMESTATES.ROUND) {
        // if someone spawns mid-round and they weren't just thawed,
        //  then they're joining mid-round, so we silently kill them.
        if (scope.late_joiner) {
            scope.frozen = true;
            RunWithDelay(function() {
                KillPlayerSilent(player);
                SetRespawnTime(player, 99999);
                ClientPrint(player, HUD_PRINTCENTER, "A round is in progress! You'll be able to join the next one.");
                // SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SCOUT);
            }, 0.1);
        }
    }
}

getroottable()[EventsID].OnGameEvent_player_disconnect <- function(params) {
    // check if this means a round would end
    if (STATE == GAMESTATES.ROUND) RunWithDelay(CountAlivePlayers, 0.1, [this, true]);

    // remove their statue if they were frozen
    local player = GetPlayerFromUserID(params.userid);
    if (!IsValidPlayer(player)) return;  // What happens then?
    ResetPlayer(player);
}

__CollectGameEventCallbacks(getroottable()[EventsID]);
