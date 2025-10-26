// FREEZE TAG SCRIPT - PSEUDO-ARENA
// by Sarexicus and Le Codex
// --------------------------------------

::setup_length <- 10;            // how long setup lasts, in seconds
::last_man_alive_cooldown <- 10; // how long between each annoucner "last man alive" callouts, in seconds

// --------------------------------------

::GAMERULES <- Entities.FindByClassname(null, "tf_gamerules");
::RED_WIN_RELAY <- Entities.FindByName(null, "ft_relay_win_red"); 
::BLU_WIN_RELAY <- Entities.FindByName(null, "ft_relay_win_blu"); 
::PLAYER_DESTRUCTION_LOGIC <- Entities.FindByClassname(null, "tf_logic_player_destruction");
::FORCERESPAWN <- Entities.FindByClassname(null, "game_forcerespawn");

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
        channel = 3, color = "180 0 180", fadein = 0.5, fadeout = 0.5, holdtime = 5,
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

EntityOutputs.AddOutput(RED_WIN_RELAY, "OnTrigger", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(TF_TEAM_RED)", 0, -1);
EntityOutputs.AddOutput(BLU_WIN_RELAY, "OnTrigger", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(TF_TEAM_BLUE)", 0, -1);

// player count flags
::initial_playercount <- { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };
::current_playercount <- { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };
::escrow_playercount <- { [TF_TEAM_RED] = null, [TF_TEAM_BLUE] = null };

local round_scored = false;
local scores = { [TF_TEAM_RED] = 0, [TF_TEAM_BLUE] = 0 };
::flawless <- { [TF_TEAM_RED] = false, [TF_TEAM_BLUE] = false };

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

    EntFireByHandle(FORCERESPAWN, "ForceTeamRespawn", "2", 4, null, null);
    EntFireByHandle(FORCERESPAWN, "ForceTeamRespawn", "3", 4, null, null);

    EntFire("tf_dropped_weapon", "Kill", "", 0, null);
    EntFire("tf_ragdoll", "Kill", "", 0, null);
    EntFire("template_ft_preround", "ForceSpawn", "", 0, null);
    EntFire("setupgate*", "Close", "", 0, null);
    EntFire("game_forcerespawn", "ForceRespawn", "", 0, null);
    EntFire("ft_relay_newround", "Trigger", "", 0, null);
    for (local ent; ent = Entities.FindByClassname(ent, "item_healthkit_*");) {
        if (ent.GetOwner()) ent.Destroy();
    }
    
    RunWithDelay(UpdateTeamEscrows, 0.5);

    EntityOutputs.AddOutput(GAME_TIMER, "OnFinished", mainLogicEntity.GetName(), "RunScriptCode", "ChangeStateToRound()", 0, 1);
    RoundStart();
}

::ChangeStateToRound <- function() {
    STATE = GAMESTATES.ROUND;
    GAME_TIMER.AcceptInput("Disable", "", null, null);
    for (local ent; ent = Entities.FindByName(ent, "ft_cp*");) {
        ent.AcceptInput("SetLocked", "1", null, null);
        ent.AcceptInput("HideModel", "", null, null);
        ent.AcceptInput("SetUnlockTime", point_unlock_timer.tostring(), null, null);
    }
    FORCERESPAWN.AcceptInput("ForceTeamRespawn", "2", null, null);
    FORCERESPAWN.AcceptInput("ForceTeamRespawn", "3", null, null);

    flawless[TF_TEAM_RED] = true;
    flawless[TF_TEAM_BLUE] = true;

    EntFire("ft_preround*", "Kill", "", 0, null);
    EntFire("setupgate*", "Open", "", 0, null);

    GAMERULES.AcceptInput("PlayVO", "Announcer.AM_RoundStartRandom", null, null);
    GAMERULES.AcceptInput("PlayVO", "Ambient.Siren", null, null);

    RunWithDelay(function() {
        UpdateTeamEscrows();
        initial_playercount = CountAlivePlayers();
    }, 0.1);
}

::SpawnEscrows <- function() {
    for (local ent; ent = Entities.FindByName(ent, "escrow_flag");)
        ent.Destroy();

    escrow_playercount[TF_TEAM_BLUE] <- SpawnEscrowPlayercountFlag(TF_TEAM_BLUE);
    escrow_playercount[TF_TEAM_RED] <- SpawnEscrowPlayercountFlag(TF_TEAM_RED);

    RunWithDelay(UpdateTeamEscrows, 1);
}

::SpawnEscrowPlayercountFlag <- function(team) {
    local player = FindFirstAlivePlayerOnTeam(team);

    local flag = SpawnEntityFromTable("item_teamflag", {
        "targetname": "escrow_flag"
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
        [TF_TEAM_RED] = GetAliveTeamPlayerCount(TF_TEAM_RED),
        [TF_TEAM_BLUE] = GetAliveTeamPlayerCount(TF_TEAM_BLUE)
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
        [TF_TEAM_RED] = GetAliveTeamPlayerCount(TF_TEAM_RED),
        [TF_TEAM_BLUE] = GetAliveTeamPlayerCount(TF_TEAM_BLUE)
    };

    if (checkForGameEnd) {
        local redTeamDead = alive[TF_TEAM_RED] == 0;
        local bluTeamDead = alive[TF_TEAM_BLUE] == 0;

        if (redTeamDead && bluTeamDead) return WinRound(0);
        if (redTeamDead) return WinRound(TF_TEAM_BLUE);
        if (bluTeamDead) return WinRound(TF_TEAM_RED);
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
        if (flawless[winnerTeam]) {
            GAMERULES.AcceptInput("PlayVO"+TeamName(winnerTeam, true), "Announcer.AM_FlawlessVictoryRandom", null, null);
            GAMERULES.AcceptInput("PlayVO"+TeamName(5-winnerTeam, true), "Announcer.AM_FlawlessDefeatRandom", null, null);
        }
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
            if (IsPlayerAlive(player)) {
                StunPlayer(player, 9999);
                player.RemoveCond(TF_COND_STEALTHED);
            } else if (scope.frozen && scope.hidden) {
                UnlockAndShowStatue(player);
            }
        } else {
            if (!IsPlayerAlive(player) && !scope.late_joiner) UnfreezePlayer(player);
            // Delay is necessary because of the potential respawn
            RunWithDelay(function(player) {
                player.AddCondEx(TF_COND_CRITBOOSTED_FIRST_BLOOD, 9999, null)
            }, 0.1, [this, player]);
        }
    }

    round_scored = true;
    ChangeStateToRoundEnd();
}

::ChangeStateToRoundEnd <- function() {
    STATE = GAMESTATES.ROUND_END;
    RunWithDelay(function() {
        if (GetRoundState() == GR_STATE_RND_RUNNING) ChangeStateToSetup();
    }, 5);

    for (local ent; ent = Entities.FindByName(ent, "ft_cp*");) {
        ent.AcceptInput("SetUnlockTime", "9999", null, null);
        ent.AcceptInput("SetLocked", "1", null, null);
        EntFireByHandle(ent, "SetOwner", "0", 3, mainLogicEntity, mainLogicEntity);
        EntFire(ent.GetName() + "_prop", "Skin", "0", 3, null);
    }
}