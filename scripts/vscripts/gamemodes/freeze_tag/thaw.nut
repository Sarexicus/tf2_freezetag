// FREEZE TAG SCRIPT - THAWING
// by Sarexicus and Le Codex
// -------------------------------

revive_sprite_frames <- 40; // number of frames in the revive sprite's animation. need to set this manually, I think

// -------------------------------

function UnfreezePlayer(player, no_respawn=false) {
    // prevent the player from switching class while dead.
    // FIXME: this still lets players change weapons. can we fix this?
    local scope = player.GetScriptScope();

    if (!no_respawn) {
        if (scope.rawin("player_class")) {
            player.SetPlayerClass(scope.player_class);
            SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", scope.player_class);
        }
        CleanRespawn(player);
    }
    RunWithDelay(function(player) { player.SetHealth(player.GetMaxHealth() * health_multiplier_on_thaw) }, 0.01, [this, player]);
    player.AddCondEx(TF_COND_INVULNERABLE_USER_BUFF, 1.0, player);
    player.AcceptInput("SpeakResponseConcept", "TLK_RESURRECTED", null, null);

    foreach (i, num in scope.ammo)
        SetPropIntArray(player, "localdata.m_iAmmo", num, i);

    // put the player at the freeze point where they died if it exists.
    //  it should do this nearly every time, but as a failsafe it'll put them in the spawn room
    if (scope.rawin("freeze_point") && scope.freeze_point) {
        player.SetOrigin(scope.freeze_point);
    }

    if ("revive_players" in scope && scope.revive_players != null && scope.revive_players.len() > 0) GenerateThawKillfeedEvent(scope.revive_players, player);

    ResetPlayer(player);
    PlayThawSound(player);
    ShowThawParticle(player);
}

function ResetPlayer(player) {
    local scope = player.GetScriptScope();
    scope.frozen <- false;
    scope.revive_progress <- 0;
    scope.revive_players <- [];

    RemoveFrozenPlayerModel(player);
    RemoveReviveProgressSprite(scope);
    RemoveGlow(scope);
    RemovePlayerReviveMarker(scope);
    RemoveParticles(scope);
    RemoveSpectateOrigin(scope);
}

function PlayThawSound(player) {
    EmitSoundEx({
        sound_name = thaw_sound,
        origin = player.GetCenter(),
        filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
    });
}

function ShowThawParticle(player) {
    local particle = SpawnEntityFromTable("trigger_particle", {
        particle_name = thaw_particle,
        attachment_type = 1, // PATTACH_ABSORIGIN_FOLLOW,
        spawnflags = 64 // allow everything
    });
    particle.AcceptInput("StartTouch", "!activator", player, player);
    particle.Kill();
}

function RemovePlayerReviveMarker(scope) {
    SafeDeleteFromScope(scope, "revive_marker");
}

function RemoveGlow(scope) {
    SafeDeleteFromScope(scope, "glow");
}

function RemoveReviveProgressSprite(scope) {
    SafeDeleteFromScope(scope, "revive_progress_sprite");
}

function RemoveParticles(scope) {
    SafeDeleteFromScope(scope, "particles");
}

function RemoveSpectateOrigin(scope) {
    SafeDeleteFromScope(scope, "spectate_origin");
}

function RemoveFrozenPlayerModel(player) {
    local scope = player.GetScriptScope();
    SafeDeleteFromScope(scope, "frozen_player_model");
    SafeDeleteFromScope(scope, "frozen_weapon_model");
}

function ForceSpectateFrozenPlayer(player) {
    local scope = player.GetScriptScope();
    SetPropEntity(player, "m_hObserverTarget", scope.spectate_origin);
    scope.spectating_self <- true;
}

function FrozenPlayerSpectate(player) {
    local scope = player.GetScriptScope();
    local observer = GetPropEntity(player, "m_hObserverTarget");
    if (observer == null || !observer.IsValid()) return;

    if(!scope.spectating_self) {
        if (observer == spectator_proxy) {
            ForceSpectateFrozenPlayer(player);
            return;
        }
    } else if (observer != scope.spectate_origin) {
        scope.spectating_self <- false;
        SetPropEntity(player, "m_hObserverTarget", FindFirstAlivePlayerOnTeam(player.GetTeam()));
        // if (observer.GetClassname() == "info_observer_point") {
        //     SetPropEntity(player, "m_hObserverTarget", FindFirstAlivePlayerOnTeam(player.GetTeam()));
        // }
    }
}

function GenerateThawKillfeedEvent(thawing_players, thawed_player) {
    local revive_icon = (thawed_player.GetTeam() == 2) ? "redcapture" : "bluecapture";

    local params = {
        "weapon": revive_icon,
        "userid": GetPlayerUserID(thawed_player),
        "attacker": GetPlayerUserID(thawing_players[0]),
        "death_flags": custom_death_flags
    };

    // if multiple players thawed, grab one of them for the assist
    if (thawing_players.len() > 1) {
        params["assister"] <- GetPlayerUserID(thawing_players[1]);
    }

    SendGlobalGameEvent("player_death", params)
}

function ThawThink() {
    for (local i = 1; i <= MaxPlayers; i++) {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        local scope = player.GetScriptScope();
        if (!scope.frozen) continue;

        if (developer() >= 2) DebugDrawBox(scope.freeze_point, vectriple(-4), vectriple(4), 0, 255, 0, 128, 0.5);

        FrozenPlayerSpectate(player);

        local was_being_thawed = scope.revive_playercount > 0;
        scope.revive_playercount <- 0;
        scope.revive_players <- [];
        ForEachAlivePlayer(ThawCheck, {
            "frozen_player": player,
            "scope": scope
        });

        local prev_revive_progress = scope.revive_progress;

        scope.revive_playercount = min(scope.revive_playercount, 3);
        if (scope.revive_playercount > 0) {
            if (!was_being_thawed)
                ShowPlayerAnnotation(player, "You are being thawed!", thaw_time, scope.frozen_player_model);

            local rate = 0.57721 + log(scope.revive_playercount + 0.5); // Using real approximation for Medigun partial cap rates
            scope.revive_progress += (1 / thaw_time) * tick_rate * rate;

            // force a player to spectate their statue if they begin thawing
            if (prev_revive_progress == 0 && scope.revive_progress > 0) {
                ForceSpectateFrozenPlayer(player);
            }
        } else if (scope.revive_playercount == 0) {
            if (was_being_thawed)
                ShowPlayerAnnotation(player, "", 0.1);

            scope.revive_progress -= (1 / decay_time) * tick_rate;
            if (scope.revive_progress < 0) scope.revive_progress = 0;
        }

        SetReviveMarkerHealth(player);
        UpdateGlowColor(player);
        UpdateReviveProgressSprite(player);
        ChangeFrozenPlayerModelSolidity(scope);

        // HACK: medics healing frozen players' revive markers can sometimes outpace the tickrate.
        //  check if the frozen player is otherwise alive (because they've been revived) and manually thaw in that case
        local medic_hack = (IsPlayerAlive(player) && scope.revive_progress > 0.9);

        if (scope.revive_progress >= 1 || medic_hack) {
            UnfreezePlayer(player, medic_hack);
        }
    }
}

function ChangeFrozenPlayerModelSolidity(scope) {
    local frozen_player_model = scope.frozen_player_model;
    if (!frozen_player_model || !frozen_player_model.IsValid()) return;
    frozen_player_model.SetSolid(scope.solid ? 6 : 0);
}

function SetReviveMarkerHealth(player) {
    local scope = player.GetScriptScope();
    local revive_marker = scope.revive_marker;

    SetPropInt(revive_marker, "m_iMaxHealth", player.GetMaxHealth() * health_multiplier_on_thaw);

    // scale the health on the revive marker based on the revive progress.
    // always show at least one health or it doesn't show the hp bar at all
    SetPropInt(revive_marker, "m_iHealth", max(1, player.GetMaxHealth() * scope.revive_progress * health_multiplier_on_thaw));
}

function UpdateGlowColor(player) {
    local scope = player.GetScriptScope();
    local glow = scope.glow;

    local progress = pow(scope.revive_progress, 2);
    local goalColor = player.GetTeam() == TF_TEAM_RED ? [255, 0, 0] : [0, 0, 255];
    foreach (i, component in goalColor) goalColor[i] = (255 * (1 - progress) + component * progress).tointeger();
    SetPropInt(glow, "m_glowColor", (goalColor[0]) | (goalColor[1] << 8) | (goalColor[2] << 16) | (255 << 24));
}

function UpdateReviveProgressSprite(player) {
    local scope = player.GetScriptScope();
    local sprite = scope.revive_progress_sprite;

    local progress = scope.revive_progress;
    SetPropFloat(sprite, "m_flFrame", revive_sprite_frames * progress);
}

function CanThaw(player) {
    local no_thaw_conditions = [TF_COND_STEALTHED, TF_COND_INVULNERABLE];
    foreach (cond in no_thaw_conditions)
        if (player.InCond(cond)) return false;

    if (player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") != player.GetTeam())
        return false;

    return true;
}

function PlayerHasPainTrain(player) {
    for (local i = 0; i < 7; i++){
        local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
        if (!weapon || !weapon.IsValid()) continue;
        if (GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex") == 154) {
            return true;
        }
    }
    return false;
}

function GetPlayerThawSpeed(player) {
    if (player.GetPlayerClass() == TF_CLASS_SCOUT) return 2;
    if (PlayerHasPainTrain(player)) return 2;

    return 1;
}

function ThawCheck(player, params) {
    if (!CanThaw(player)) return;

    local scope = params.scope;
    local frozen_statue = scope.frozen_player_model;
    local revive_marker = scope.revive_marker;
    if (!frozen_statue || !frozen_statue.IsValid()) return;

    local frozen_statue_location = frozen_statue.GetCenter();
    local frozen_player = params.frozen_player;
    if (scope.revive_playercount == -1) return;

    if (Distance(frozen_statue_location, player.GetCenter()) > thaw_distance) {
        local weapon = player.GetActiveWeapon();
        if (GetPropEntity(weapon, "m_hHealingTarget") == revive_marker) {
            scope.revive_playercount += medigun_thawing_efficiency;
            scope.revive_players.push(player);
        }
        return;
    }

    // line-of-sight check
    if (TraceLine(player.GetOrigin() + player.GetClassEyeHeight(), frozen_statue_location, player) != 1) return;
    if (developer() >= 2) DebugDrawLine(player.GetCenter(), frozen_statue_location, 0, 0, 255, false, 0.5);

    // block progress if any enemy players are too close by
    //  (set number of thawing players to -1, marking the capture as blocked)
    if (player.GetTeam() == frozen_player.GetTeam()) {
        scope.revive_playercount += GetPlayerThawSpeed(player);
        scope.revive_players.push(player);
    } else {
        scope.revive_playercount = -1;
    }
}