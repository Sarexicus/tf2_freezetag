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
health_multiplier_on_thaw <- 0.5;   // how much health does the player get when they thaw? (fraction of max hp)
thaw_time <- 4.0;                   // how many seconds it takes for one player to thaw a player
thaw_distance <- 128.0;             // you must be this close to a player to start thawing them

freeze_sound <- "Icicle.TurnToIce";
thaw_sound <- "Fire.Engulf";
thaw_particle <- "heavy_ring_of_fire_fp_child01";

tick_rate <- 0.1; // how often the base think rate polls

// -----------------------------------------------

IncludeScript(VSCRIPT_PATH + "freeze.nut", this);
IncludeScript(VSCRIPT_PATH + "thaw.nut", this);

function Precache() {
    PrecacheScriptSound(freeze_sound);
    PrecacheScriptSound(thaw_sound);
}

function RoundStart() {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        ResetPlayer(player);
        SetupPlayer(player);
    }

    ChangeStateToSetup();
}

local _ticks = 0;
function Think() {
    // only run the freeze think every second tick, for performance's sake
    if (_ticks % (tick_rate * 2) == 0) {
        FreezeThink();
    }

    if (STATE == GAMESTATES.ROUND) ThawThink();

    _ticks += tick_rate;
    if (_ticks > 1) _ticks = 0;
    return tick_rate;
}

function SetupPlayer(player) {
    SetPropInt(player, "m_nRenderMode", 0);
    local scope = player.GetScriptScope();
    scope.frozen <- false;
    scope.freeze_positions <- [];
    scope.position_index <- 0;
}

// EVENTS
// -----------------------------

function OnGameEvent_teamplay_round_start(params) {
    RoundStart();
}

function OnGameEvent_player_spawn(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (params.team == 0) {
        player.ValidateScriptScope();
        SetupPlayer(player);
    } else if (STATE == GAMESTATES.ROUND) {
        RunWithDelay(function() {
            NetProps.SetPropInt(player, "m_lifeState", LIFE_STATE.DEAD);
        }, 0.1);
    }
}

function OnGameEvent_player_disconnect(params) {
    if (STATE == GAMESTATES.ROUND) RunWithDelay(CountAlivePlayers, 0.1, [this, true]);
}

__CollectGameEventCallbacks(this);