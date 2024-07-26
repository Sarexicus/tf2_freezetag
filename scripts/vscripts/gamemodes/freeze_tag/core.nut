// FREEZE TAG SCRIPT
// by Sarexicus and Le Codex
// version 0.1
// -----------------------------------------------

::VSCRIPT_PATH <- "gamemodes/freeze_tag/";
IncludeScript(VSCRIPT_PATH + "arena.nut", this);
IncludeScript(VSCRIPT_PATH + "util.nut", this);

ClearGameEventCallbacks();

// CONFIG
// -----------------------------------------------
health_multiplier_on_thaw <- 0.5;   // how much health a frozen player gets when they thaw (fraction of max hp)
thaw_time <- 4.0;                   // how many seconds it takes for one player to thaw a frozen player
decay_time <- 8.0;                  // how many seconds it takes for thawing progress to decay from full to empty
thaw_distance <- 128.0;             // how close to a frozen player on your team you have to be to start thawing them
players_solid_when_frozen <- false; // whether frozen players have collisions

::freeze_sound <- "Icicle.TurnToIce";
::thaw_sound <- "Icicle.Melt";
::thaw_particle <- "ft_playerthaw";
::fake_thaw_sound <- "Halloween.spell_stealth";
::fake_disappear_particle <- "ghost_smoke";

tick_rate <- 0.1; // how often the base think rate polls

// -----------------------------------------------

IncludeScript(VSCRIPT_PATH + "freeze.nut", this);
IncludeScript(VSCRIPT_PATH + "thaw.nut", this);

function PrecacheParticle(particle_name) {
    PrecacheEntityFromTable({
        classname = "info_particle_system",
        effect_name = particle_name
    });
}

function Precache() {
    PrecacheParticle(thaw_particle);
    PrecacheParticle(fake_disappear_particle);

    PrecacheScriptSound(freeze_sound);
    PrecacheScriptSound(thaw_sound);
    PrecacheScriptSound(fake_thaw_sound);
}

function RecordPlayerTeam(player, params) {
    local scope = player.GetScriptScope();
    scope.team <- player.GetTeam();
}

function RoundStart() {
    EntFire("ft_relay_newround", "Trigger", "", 0, null);

    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        ResetPlayer(player);
        SetupPlayer(player);
        RecordPlayerTeam(player, {});
    }
}

local _ticks = 0;
function Think() {
    // skip running any thinks when WFP is going
    if (IsInWaitingForPlayers()) return;

    // only run the freeze think every second tick, for performance's sake
    if (_ticks % (tick_rate * 2) == 0) {
        FreezeThink();
    }

    if (STATE == GAMESTATES.ROUND) ThawThink();

    deadRingerSpies.clear();

    _ticks += tick_rate;
    if (_ticks > 1) _ticks = 0;
    return tick_rate;
}

function SetupPlayer(player) {
    local scope = player.GetScriptScope();
    scope.frozen <- false;
    scope.thawed <- false;
    scope.freeze_positions <- [];
    scope.position_index <- 0;
    scope.revive_players <- 0;
    scope.frozen_player_model <- null;
}

// EVENTS
// -----------------------------

function OnGameEvent_teamplay_round_start(params) {
    if(IsInWaitingForPlayers()) return;
    ChangeStateToSetup();
}

function OnGameEvent_player_team(params) {
    // if a player changes team, remove their statue
    local player = GetPlayerFromUserID(params.userid);
    if (player == null) return;

    local scope = player.GetScriptScope();
    if (params.team != params.oldteam) {
        ResetPlayer(player);
    }
}

function OnGameEvent_player_spawn(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (player == null) return;

    player.ValidateScriptScope();
    if (params.team == 0) {
        SetupPlayer(player);
    } else if (STATE == GAMESTATES.ROUND) {
        // if someone spawns mid-round and they weren't just thawed,
        //  then they're joining mid-round, so we silently kill them.
        local scope = player.GetScriptScope();

        if (!scope.rawin("thawed") || !scope.thawed) {
            RunWithDelay(function() {
                scope.thawed = true;
                KillPlayerSilent(player);
                SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SCOUT);
            }, 0.1);
        }
    }
}

function OnGameEvent_player_disconnect(params) {
    // check if this means a round would end
    if (STATE == GAMESTATES.ROUND) RunWithDelay(CountAlivePlayers, 0.1, [this, true]);

    // remove their statue if they were frozen
    local player = GetPlayerFromUserID(params.userid);
    local scope = player.GetScriptScope();
    ResetPlayer(player);
}

__CollectGameEventCallbacks(this);