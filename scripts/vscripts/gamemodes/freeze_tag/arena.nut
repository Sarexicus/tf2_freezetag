::mainLogic <- this;
::mainLogicEntity <- self;

::GAMERULES <- Entities.FindByClassname(null, "tf_gamerules");
::GAME_TIMER <- Entities.FindByClassname(null, "team_round_timer");
::CENTRAL_CP <- Entities.FindByClassname(null, "team_control_point");
::PLAYER_DESTRUCTION_LOGIC <- Entities.FindByClassname(null, "tf_logic_player_destruction");
::TEXT_PLAYERCOUNT_RED <- Entities.FindByName(null, "text_playercounter_red");
::TEXT_PLAYERCOUNT_BLU <- Entities.FindByName(null, "text_playercounter_blu");

EntFireByHandle(GAMERULES, "SetRedTeamRespawnWaveTime", "99999", -1, null, null);
EntFireByHandle(GAMERULES, "SetBlueTeamRespawnWaveTime", "99999", -1, null, null);
EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "SetPointsOnPlayerDeath", "0", -1, null, null);
EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "EnableMaxScoreUpdating", "0", -1, null, null);
EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "DisableMaxScoreUpdating", "0", 1, null, null);

EntityOutputs.AddOutput(CENTRAL_CP, "OnCapTeam1", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(Constants.ETFTeam.TF_TEAM_RED)", 0, -1);
EntityOutputs.AddOutput(CENTRAL_CP, "OnCapTeam2", mainLogicEntity.GetName(), "RunScriptCode", "WinRound(Constants.ETFTeam.TF_TEAM_BLUE)", 0, -1);


enum GAMESTATES {
    SETUP = 0,
    ROUND = 1,
    ROUND_END = 2
}
::STATE <- GAMESTATES.SETUP;

function ChangeStateToSetup() {
    STATE = GAMESTATES.SETUP;
    EntFireByHandle(GAME_TIMER, "Enable", "", -1, null, null);
    EntFireByHandle(GAME_TIMER, "RoundSpawn", "", 0, null, null);

    EntFire("template_spawn", "ForceSpawn", "", 0, null);
    EntFire("setupgate*", "Close", "", 0, null);
    EntFire("game_forcerespawn", "ForceRespawn", "", 0.3, null);

    EntityOutputs.AddOutput(GAME_TIMER, "OnSetupFinished", mainLogicEntity.GetName(), "RunScriptCode", "ChangeStateToRound()", 0, 1);
    RoundStart();
}

function ChangeStateToRound() {
    STATE = GAMESTATES.ROUND;
    EntFireByHandle(GAME_TIMER, "Disable", "", 0, null, null);
    EntFireByHandle(CENTRAL_CP, "SetLocked", "1", 0, null, null);
    EntFireByHandle(CENTRAL_CP, "SetUnlockTime", "50", 0, null, null);
    EntFireByHandle(CENTRAL_CP, "HideModel", "", 0, null, null);

    EntFire("respawnrom_*", "Kill", "", 0, null);
    EntFire("regenerate", "Kill", "", 0, null);
    EntFire("setupgate*", "Open", "", 0, null);
    EntFire("game_forcerespawn", "ForceTeamRespawn", "2", 0.3, null);
    EntFire("game_forcerespawn", "ForceTeamRespawn", "3", 0.3, null);

    RunWithDelay(CountAlivePlayers, 0.5);
}

function CountAlivePlayers(checkForGameEnd=false) {
    local redAlive = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_RED);
    local bluAlive = GetAliveTeamPlayerCount(Constants.ETFTeam.TF_TEAM_BLUE);

    NetProps.SetPropString(TEXT_PLAYERCOUNT_RED, "m_iszMessage", redAlive.tostring());
    NetProps.SetPropString(TEXT_PLAYERCOUNT_BLU, "m_iszMessage", bluAlive.tostring());
    EntFireByHandle(TEXT_PLAYERCOUNT_RED, "Display", "", 0, null, null);
    EntFireByHandle(TEXT_PLAYERCOUNT_BLU, "Display", "", 0, null, null);

    if (checkForGameEnd) {
        local redTeamDead = redAlive == 0;
        local bluTeamDead = bluAlive == 0;

        if (redTeamDead && bluTeamDead) return WinRound(0);
        if (redTeamDead) return WinRound(Constants.ETFTeam.TF_TEAM_BLUE);
        if (bluTeamDead) return WinRound(Constants.ETFTeam.TF_TEAM_RED);
    }
}

function WinRound(winnerTeam) {
    if (winnerTeam) {
        EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "Score"+TeamName(winnerTeam, true)+"Points", "", 0, null, null);
        EntFire("text_win_"+TeamName(winnerTeam), "Display", "", 0, null);
    } else {
        EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "ScoreRedPoints", "", 0, null, null);
        EntFireByHandle(PLAYER_DESTRUCTION_LOGIC, "ScoreBluePoints", "", 0, null, null);
        EntFire("text_win_none", "Display", "", 0, null);
    }

    foreach (player in GetAllPlayers()) {
        local team = player.GetTeam();
        if (!winnerTeam || team != winnerTeam) {
            if (IsPlayerAlive(player)) StunPlayer(player, 9999);
        } else {
            if (!IsPlayerAlive(player)) UnfreezePlayer(player);
            // Delay is necessary because of the potential respawn
            RunWithDelay(function(player) {
                player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED_FIRST_BLOOD, 9999, null) 
            }, 0.1, [this, player]);
        }
    }

    ChangeStateToRoundEnd();
}

function ChangeStateToRoundEnd() {
    STATE = GAMESTATES.ROUND_END;
    RunWithDelay(function() {
        if (GetRoundState() == Constants.ERoundState.GR_STATE_RND_RUNNING) ChangeStateToSetup();
    }, 5);

    EntFireByHandle(CENTRAL_CP, "SetOwner", "0", 3, mainLogicEntity, mainLogicEntity);
    EntFire("cp1_prop", "Skin", "0", 3, null);
    EntFireByHandle(CENTRAL_CP, "SetLocked", "1", 0, null, null);
}