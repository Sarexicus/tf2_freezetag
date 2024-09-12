// FREEZE TAG SCRIPT - PSEUDO-ARENA
// by Sarexicus and Le Codex
// --------------------------------------

local setup_length = 10;    // how long setup lasts, in seconds

// --------------------------------------

::GAMERULES <- Entities.FindByClassname(null, "tf_gamerules");
::CENTRAL_CP <- Entities.FindByClassname(null, "team_control_point");
::PLAYER_DESTRUCTION_LOGIC <- Entities.FindByClassname(null, "tf_logic_player_destruction");

::GAME_TIMER <- SpawnEntityFromTable("team_round_timer", {
    auto_countdown = 0, start_paused = 0, show_in_hud = 1, show_time_remaining = 1, StartDisabled = 0
    timer_length = setup_length, max_length = 0, setup_length = 0, reset_time = 1
    targetname = "game_timer"
});

::TEXT_WIN <- {
    [TF_TEAM_RED] = SpawnEntityFromTable("game_text", {
        channel = 3, color = "255 0 0", fadein = 0.5, fadeout = 0.5, holdtime = 5,
        message = "RED wins the round!"
        targetname = "text_win_red", x = -1, y = -1, spawnflags = 1
    }),
    [TF_TEAM_BLUE] = SpawnEntityFromTable("game_text", {
        channel = 3, color = "0 128 255", fadein = 0.5, fadeout = 0.5, holdtime = 5,
        message = "BLU wins the round!"
        targetname = "text_win_blu", x = -1, y = -1, spawnflags = 1
    }),
    [0] = SpawnEntityFromTable("game_text", {
        channel = 3, color = "255 0 255", fadein = 0.5, fadeout = 0.5, holdtime = 5,
        message = "It's a tie!"
        targetname = "text_win_none", x = -1, y = -1, spawnflags = 1
    })
};

// pseudo-arena setup
GAMERULES.AcceptInput("SetRedTeamRespawnWaveTime", "99999", null, null);
GAMERULES.AcceptInput("SetBlueTeamRespawnWaveTime", "99999", null, null);
PLAYER_DESTRUCTION_LOGIC.AcceptInput("SetPointsOnPlayerDeath", "0", null, null);
EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "EnableMaxScoreUpdating", "0", -1, null, null);
EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "DisableMaxScoreUpdating", "0", 1, null, null);

EntityOutputs.AddOutput(CENTRAL_CP, "OnCapTeam1", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(TF_TEAM_RED)", 0, -1);
EntityOutputs.AddOutput(CENTRAL_CP, "OnCapTeam2", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(TF_TEAM_BLUE)", 0, -1);

// player count flags
::initial_playercount <- { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };
::current_playercount <- { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };
::escrow_playercount <- { [TF_TEAM_RED] = null, [TF_TEAM_BLUE] = null };

local round_scored = false;
local scores = { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };

::GAMESTATES <- {
    SETUP = 0,
    ROUND = 1,
    ROUND_END = 2
}
::STATE <- GAMESTATES.SETUP;

::ChangeStateToSetup <- function() {
    STATE = GAMESTATES.SETUP;

    round_scored = false;
    GAME_TIMER.AcceptInput("Enable", "", null, null);
    GAME_TIMER.AcceptInput("SetTime", setup_length.tostring(), null, null);

    EntFireByHandle(GAMERULES, "PlayVO", "Announcer.RoundBegins10Seconds", setup_length - 11, null, null);
    EntityOutputs.AddOutput(GAME_TIMER, "On10SecRemain", GAMERULES.GetName(), "PlayVO", "Announcer.RoundBegins5Seconds", 4, 1);
    EntityOutputs.AddOutput(GAME_TIMER, "On5SecRemain", GAMERULES.GetName(), "PlayVO", "Announcer.RoundBegins4Seconds", 0, 1);
    EntityOutputs.AddOutput(GAME_TIMER, "On4SecRemain", GAMERULES.GetName(), "PlayVO", "Announcer.RoundBegins3Seconds", 0, 1);
    EntityOutputs.AddOutput(GAME_TIMER, "On3SecRemain", GAMERULES.GetName(), "PlayVO", "Announcer.RoundBegins2Seconds", 0, 1);
    EntityOutputs.AddOutput(GAME_TIMER, "On2SecRemain", GAMERULES.GetName(), "PlayVO", "Announcer.RoundBegins1Seconds", 0, 1);
    
    EntFire("regen_particle", "Kill", null, 0, null);
    EntFire("tf_dropped_weapon", "Kill", "", 0, null);
    EntFire("template_ft_preround", "ForceSpawn", "", 0, null);
    EntFire("setupgate*", "Close", "", 0, null);
    EntFire("game_forcerespawn", "ForceRespawn", "", 0.3, null);
    EntFire("ft_relay_newround", "Trigger", "", 0.3, null);
    RunWithDelay(UpdateTeamEscrows, 0.5);

    EntityOutputs.AddOutput(GAME_TIMER, "OnFinished", mainLogicEntity.GetName(), "RunScriptCode", "ChangeStateToRound()", 0, 1);
    RoundStart();
}

::ChangeStateToRound <- function() {
    STATE = GAMESTATES.ROUND;
    GAME_TIMER.AcceptInput("Disable", "", null, null);
    CENTRAL_CP.AcceptInput("SetLocked", "1", null, null);
    CENTRAL_CP.AcceptInput("HideModel", "", null, null);
    CENTRAL_CP.AcceptInput("SetUnlockTime", point_unlock_timer.tostring(), null, null);

    EntFire("ft_preround*", "Kill", "", 0, null);
    EntFire("setupgate*", "Open", "", 0, null);
    EntFire("game_forcerespawn", "ForceTeamRespawn", "2", 0.3, null);
    EntFire("game_forcerespawn", "ForceTeamRespawn", "3", 0.3, null);

    GAMERULES.AcceptInput("PlayVO", "Announcer.AM_RoundStartRandom", null, null);
    GAMERULES.AcceptInput("PlayVO", "Ambient.Siren", null, null);

    UpdateTeamEscrows();
    RunWithDelay(function() { initial_playercount = CountAlivePlayers() }, 0.1);
}

::SpawnEscrows <- function() {
    foreach (team, escrow in escrow_playercount)
        if (escrow && escrow.IsValid()) escrow.Destroy();
    
    escrow_playercount[TF_TEAM_BLUE] <- SpawnEscrowPlayercountFlag(TF_TEAM_BLUE);
    escrow_playercount[TF_TEAM_RED] <- SpawnEscrowPlayercountFlag(TF_TEAM_RED);

    RunWithDelay(UpdateTeamEscrows, 1);
}

::SpawnEscrowPlayercountFlag <- function(team) {
    local player = FindFirstAlivePlayerOnTeam(team);

    local flag = SpawnEntityFromTable("item_teamflag", {
        "PointValue": 1,
        "flag_model": "models/empty.mdl",
        "GameType": 6,
        "trail_effect": 0,
    });

    SetPropInt(flag, "m_nPointValue", 1);
    SetPropInt(flag, "m_nFlagStatus", 1);
    SetPropEntity(flag, "m_hPrevOwner", player);
    flag.AcceptInput("Disable", "", null, null);

    return flag;
}

::UpdateTeamEscrows <- function() {
    local alive = {
        [TF_TEAM_RED] = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_RED),
        [TF_TEAM_BLUE] = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_BLUE)
    };
    foreach(player in GetAllPlayers()) {
        if (player.InCond(TF_COND_FEIGN_DEATH)) alive[player.GetTeam()]--;
    }

    UpdateTeamEscrow(TF_TEAM_BLUE, alive[TF_TEAM_BLUE]);
    UpdateTeamEscrow(TF_TEAM_RED, alive[TF_TEAM_RED]);
}

::UpdateTeamEscrow <- function(team, score) {
    local escrow = escrow_playercount[team];
    SetPropInt(escrow, "m_nPointValue", score);

    // check if the player responsible for a team's score is disconnected or has changed team
    local owner = GetPropEntity(escrow, "m_hPrevOwner");
    if (owner == null || !owner.IsValid() || owner.GetTeam() != team) {
        SetPropEntity(escrow, "m_hPrevOwner", FindFirstAlivePlayerOnTeam(team));
    }
}

::CountAlivePlayers <- function(checkForGameEnd=false) {
    UpdateTeamEscrows();

    local alive = {
        [TF_TEAM_RED] = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_RED),
        [TF_TEAM_BLUE] = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_BLUE)
    };

    if (checkForGameEnd) {
        local redTeamDead = alive[TF_TEAM_RED] == 0;
        local bluTeamDead = alive[TF_TEAM_BLUE] == 0;

        if (redTeamDead && bluTeamDead) return WinRound(0);
        if (redTeamDead) return WinRound(Constants.ETFTeam.TF_TEAM_BLUE);
        if (bluTeamDead) return WinRound(Constants.ETFTeam.TF_TEAM_RED);
    }

    current_playercount = clone alive;
    return alive;
}

::WinRound <- function(winnerTeam) {
    if (round_scored) return;

    EntFire("freeze_particles", "Kill", null, 0, null);
    EntFire("revive_progress_sprite", "Kill", null, 0, null);

    GAMERULES.AcceptInput("PlayVO", "Hud.EndRoundScored", null, null);
    if (winnerTeam) {
        PLAYER_DESTRUCTION_LOGIC.AcceptInput("Score"+TeamName(winnerTeam, true)+"Points", "", null, null);
        scores[winnerTeam]++;
    } else {
        PLAYER_DESTRUCTION_LOGIC.AcceptInput("ScoreRedPoints", "", null, null);
        PLAYER_DESTRUCTION_LOGIC.AcceptInput("ScoreBluePoints", "", null, null);
        scores[TF_TEAM_RED]++; scores[TF_TEAM_BLUE]++;
    }

    if (scores[TF_TEAM_RED] < 3 && scores[TF_TEAM_BLUE] < 3) {
        TEXT_WIN[winnerTeam].AcceptInput("Display", "", null, null);
    }

    for (local ent; ent = Entities.FindByClassname(ent, "obj_sentrygun");) {
        if (ent.GetTeam() != winnerTeam) ent.AcceptInput("Disable", "", null, null);
    }

    foreach (player in GetAllPlayers()) {
        local team = player.GetTeam();
        local scope = player.GetScriptScope();

        StopRegenerating(player);
        if (!winnerTeam || team != winnerTeam) {
            if (IsPlayerAlive(player)) StunPlayer(player, 9999);
        } else {
            if (!IsPlayerAlive(player) && !scope.late_joiner) UnfreezePlayer(player);
            // Delay is necessary because of the potential respawn
            RunWithDelay(function(player) {
                player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED_FIRST_BLOOD, 9999, null)
            }, 0.1, [this, player]);
        }
    }

    round_scored = true;
    ChangeStateToRoundEnd();
}

::ChangeStateToRoundEnd <- function() {
    STATE = GAMESTATES.ROUND_END;
    RunWithDelay(function() {
        if (GetRoundState() == Constants.ERoundState.GR_STATE_RND_RUNNING) ChangeStateToSetup();
    }, 5);

    CENTRAL_CP.AcceptInput("SetUnlockTime", "9999", null, null);
    CENTRAL_CP.AcceptInput("SetLocked", "1", null, null);
    EntFireByHandle(CENTRAL_CP, "SetOwner", "0", 3, mainLogicEntity, mainLogicEntity);
    EntFire("cp1_prop", "Skin", "0", 3, null);
}