// FREEZE TAG SCRIPT - THAWING
// by Sarexicus and Le Codex
// -------------------------------

IncludeScript(VSCRIPT_PATH + "thaw_meter.nut", this);
IncludeScript(VSCRIPT_PATH + "spectate.nut", this);
::revive_sprite_frames <- 40; // number of frames in the revive sprite's animation. need to set this manually, I think

// -------------------------------

::UnfreezePlayer <- function(player, no_respawn=false) {
    // prevent the player from switching class while dead.
    // FIXME: this still lets players change weapons. can we fix this?
    local scope = player.GetScriptScope();

    if (!no_respawn) {
        player.SetPlayerClass(scope.player_class);
        local desired_player_class = GetPropInt(player, "m_Shared.m_iDesiredPlayerClass");
        SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", scope.player_class);
        CleanRespawn(player);
        SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", desired_player_class);
    }
    RunWithDelay(function(player) { player.SetHealth(player.GetMaxHealth() * health_multiplier_on_thaw); StartRegenerating(player); }, 0.01, [this, player]);
    player.AddCondEx(TF_COND_INVULNERABLE_USER_BUFF, 1.0, player);
    player.AcceptInput("SpeakResponseConcept", "TLK_RESURRECTED", null, null);
    player.SetAbsAngles(scope.ang);
    player.SnapEyeAngles(scope.eye_ang);

    foreach (i, num in scope.ammo)
        SetPropIntArray(player, "localdata.m_iAmmo", num, i);

    // put the player at the freeze point where they died if it exists.
    //  it should do this nearly every time, but as a failsafe it'll put them in the spawn room
    // if (scope.freeze_point) player.SetOrigin(scope.freeze_point);
    if (scope.revive_marker) player.SetOrigin(scope.revive_marker.GetOrigin() + Vector(0, 0, 1));
    if (scope.revive_players.len() > 0) GenerateThawKillfeedEvent(scope.revive_players, player);

    ResetPlayer(player);
    PlayThawSound(player);
    ShowThawParticle(player);
    RunWithDelay(CountAlivePlayers, 0.05);
}

::ResetPlayer <- function(player) {
    local scope = player.GetScriptScope();
    scope.frozen <- false;
    scope.revive_progress <- 0;
    scope.revive_players <- [];
    scope.highest_thawing_player <- null;

    RemoveFrozenPlayerModel(player);
    RemoveReviveProgressSprite(scope);
    RemoveGlow(scope);
    RemovePlayerReviveMarker(scope);
    RemoveParticles(scope);
    RemoveSpectateOrigin(scope);
}

::PlayThawSound <- function(player) {
    EmitSoundEx({
        sound_name = thaw_finish_sound, channel = 128 + player.entindex(), sound_level = 120
        origin = player.GetCenter(),
        filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
    });
}

::ShowThawParticle <- function(player) {
    local particle = SpawnEntityFromTable("trigger_particle", {
        particle_name = thaw_particle,
        attachment_type = 1, // PATTACH_ABSORIGIN_FOLLOW,
        spawnflags = 64 // allow everything
    });
    particle.AcceptInput("StartTouch", "!activator", player, player);
    particle.Kill();
}

::RemovePlayerReviveMarker <- function(scope) {
    SafeDeleteFromScope(scope, "revive_marker");
}

::RemoveGlow <- function(scope) {
    SafeDeleteFromScope(scope, "glow");
}

::RemoveReviveProgressSprite <- function(scope) {
    SafeDeleteFromScope(scope, "revive_progress_sprite");
}

::RemoveParticles <- function(scope) {
    SafeDeleteFromScope(scope, "particles");
}

::RemoveSpectateOrigin <- function(scope) {
    SafeDeleteFromScope(scope, "spectate_origin");
}

::RemoveFrozenPlayerModel <- function(player) {
    local scope = player.GetScriptScope();
    SafeDeleteFromScope(scope, "frozen_player_model");
    SafeDeleteFromScope(scope, "frozen_weapon_model");
}

::GenerateThawKillfeedEvent <- function(thawing_players, thawed_player) {
    local revive_icon = (thawed_player.GetTeam() == 2) ? "redcapture" : "bluecapture";

    local credits = [];
    foreach (player in thawing_players)
        if (player != thawed_player)
            credits.push(player);

    // Safety: if the player was thawed miracurously, make it so they thawed themselves
    if (credits.len() == 0) credits = [thawed_player];

    local params = {
        "weapon": revive_icon,
        "userid": GetPlayerUserID(thawed_player),
        "attacker": GetPlayerUserID(credits[0]),
        "death_flags": custom_death_flags
    };

    // if multiple players thawed, grab one of them for the assist
    if (credits.len() > 1) {
        params["assister"] <- GetPlayerUserID(credits[1]);
    }

    SendGlobalGameEvent("player_death", params)
}

::ThawThink <- function(player) {
    local scope = player.GetScriptScope();
    if (!scope.frozen) return;

    if (developer() >= 2) DebugDrawBox(scope.freeze_point, vectriple(-4), vectriple(4), 0, 255, 0, 128, 0.5);

    // spectating (cycle and forced)
    ForcePlayerSpectateRules(player);
    FrozenPlayerSpectatorCycle(player);

    local new_unlock_time = scope.revive_unlock_time - tick_rate;
    if (new_unlock_time > 0) {
        scope.revive_unlock_time = new_unlock_time;
        scope.revive_playercount <- 0;
        return;
    }
    if (scope.revive_unlock_time > 0) scope.revive_progress_sprite.AcceptInput("ShowSprite", "", null, null);

    local was_being_thawed = scope.revive_playercount > 0;
    local was_being_blocked = scope.revive_blocked;
    scope.revive_playercount <- 0;
    scope.revive_players <- [];
    scope.revive_blocked <- false;
    scope.is_medigun_revived <- false;
    ForEachAlivePlayer(ThawCheck, {
        "frozen_player": player,
        "scope": scope
    });

    scope.revive_playercount = min(scope.revive_playercount, 3);
    if (scope.revive_playercount > 0) {
        if (!was_being_thawed)
            ShowPlayerAnnotation(player, "You are being thawed!", max_thaw_time + 1, scope.frozen_player_model);

        if (scope.revive_blocked && (!was_being_blocked || !was_being_thawed))
            PlayThawStateSound(player, thaw_block_sound);

        if (!scope.revive_blocked && (was_being_blocked || !was_being_thawed))
            PlayThawStateSound(player, thaw_start_sound);

        local rate = scope.revive_blocked ? 0 : 0.57721 + log(scope.revive_playercount + 0.5);   // Using real approximation for Medigun partial cap rates
        scope.revive_progress += (1 / max_thaw_time) * tick_rate * rate;
    } else if (scope.revive_playercount == 0) {
        if (was_being_thawed)
            ShowPlayerAnnotation(player, "", 0.1);

        scope.revive_progress -= (1 / decay_time) * tick_rate;
        local min_progress = GetTeamMinProgress(player.GetTeam());
        if (scope.revive_progress < min_progress) {
            scope.did_force_spectate = false;
            scope.revive_progress = min_progress;
        }
    }

    UpdateHighestThawedPlayer(player, scope);
    UpdateThawHUDs(player, scope);
    SetReviveMarkerHealth(player);
    UpdateGlowColor(player);
    UpdateReviveProgressSprite(player);
    ChangeFrozenPlayerModelSolidity(scope);

    // HACK: medics healing frozen players' revive markers can sometimes outpace the tickrate.
    //  check if the frozen player is otherwise alive (because they've been revived) and manually thaw in that case
    local medic_hack = IsPlayerAlive(player);

    if (scope.revive_progress >= 1 || medic_hack) {
        UnfreezePlayer(player, medic_hack);
    }
}

::PlayThawStateSound <- function(player, sound_name) {
    local scope = player.GetScriptScope();
    EmitSoundEx({
        sound_name = sound_name, channel = 128 + player.entindex(),
        origin = scope.frozen_player_model.GetOrigin(),
        sound_level = 80, filter_type = RECIPIENT_FILTER_GLOBAL
    });
}

::UpdateHighestThawedPlayer <- function(player, scope) {
    foreach(revive_player in scope.revive_players) {
        local rp_scope = revive_player.GetScriptScope();
        local htp = rp_scope.highest_thawing_player;
        if (htp == null || !htp.IsValid()) {
            rp_scope.highest_thawing_player = player;
            return;
        }

        local htp_scope = htp.GetScriptScope();
        if (htp_scope.revive_progress < scope.revive_progress) {
            rp_scope.highest_thawing_player = player;
            return;
        }
    }
}

::UpdateThawHUDs <- function(player, scope) {
    foreach(revive_player in scope.revive_players) {
        local rp_scope = revive_player.GetScriptScope();
        if (rp_scope.highest_thawing_player == player) {
            ShowThawMeterText(revive_player, scope.revive_progress * max_thaw_time, max_thaw_time, scope.revive_playercount, scope.revive_blocked);
        }
    }
}

::GetTeamMinProgress <- function(team) {
    local ratio = current_playercount[team].tofloat() / initial_playercount[team];
    return (max_thaw_time - min_thaw_time) / max_thaw_time * (1 - max(0.0, min((ratio - min_thaw_time_percent) / (max_thaw_time_percent - min_thaw_time_percent), 1.0)));
}

::ChangeFrozenPlayerModelSolidity <- function(scope) {
    local frozen_player_model = scope.frozen_player_model;
    if (!frozen_player_model || !frozen_player_model.IsValid()) return;
    frozen_player_model.SetSolid(scope.solid ? 6 : 0);
}

::SetReviveMarkerHealth <- function(player) {
    local scope = player.GetScriptScope();
    local revive_marker = scope.revive_marker;
    if (!revive_marker || !revive_marker.IsValid()) return;

    SetPropInt(revive_marker, "m_iMaxHealth", player.GetMaxHealth() * health_multiplier_on_thaw);

    // scale the health on the revive marker based on the revive progress.
    // always show at least one health or it doesn't show the hp bar at all
    SetPropInt(revive_marker, "m_iHealth", max(1, player.GetMaxHealth() * scope.revive_progress * health_multiplier_on_thaw));
}

::UpdateGlowColor <- function(player) {
    local scope = player.GetScriptScope();
    local glow = scope.glow;

    local progress = pow(scope.revive_progress, 2);
    local goalColor = player.GetTeam() == TF_TEAM_RED ? [255, 0, 0] : [0, 0, 255];
    foreach (i, component in goalColor) goalColor[i] = (255 * (1 - progress) + component * progress).tointeger();
    SetPropInt(glow, "m_glowColor", (goalColor[0]) | (goalColor[1] << 8) | (goalColor[2] << 16) | (255 << 24));
}

::UpdateReviveProgressSprite <- function(player) {
    local scope = player.GetScriptScope();
    local sprite = scope.revive_progress_sprite;

    local progress = scope.revive_progress;
    SetPropFloat(sprite, "m_flFrame", revive_sprite_frames * progress);
}

::CanThaw <- function(player) {
    local no_thaw_conditions = [TF_COND_STEALTHED, TF_COND_INVULNERABLE, TF_COND_INVULNERABLE_USER_BUFF, TF_COND_PHASE, TF_COND_MEGAHEAL];
    foreach (cond in no_thaw_conditions)
        if (player.InCond(cond)) return false;

    if (player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") != player.GetTeam())
        return false;

    return true;
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

::GetPlayerThawSpeed <- function(player) {
    if (player.GetPlayerClass() == TF_CLASS_SCOUT) return 2;
    if (PlayerHasPainTrain(player)) return 2;

    return 1;
}

::StatueDistanceCheck <- function(point_a, point_b, distance) {
    local adjusted_z = Vector(point_a.x, point_a.y, point_b.z);
    if (Distance(adjusted_z, point_b) > distance) return false;
    if (abs(point_a.z - point_b.z) > distance) return false;

    return true;
}

::ThawCheck <- function(player, params) {
    if (!CanThaw(player)) return;

    local scope = params.scope;
    local frozen_statue = scope.frozen_player_model;
    local revive_marker = scope.revive_marker;
    if (!frozen_statue || !frozen_statue.IsValid()) return;

    local frozen_statue_location = frozen_statue.GetCenter();
    local frozen_player = params.frozen_player;

    local within_radius = StatueDistanceCheck(frozen_statue_location, player.GetCenter(), thaw_distance);
    
    local weapon = player.GetActiveWeapon();
    if (revive_marker && GetPropEntity(weapon, "m_hHealingTarget") == revive_marker) {
        scope.revive_playercount += within_radius ? GetPlayerThawSpeed(player) : medigun_thawing_efficiency;
        scope.revive_players.push(player);
        scope.is_medigun_revived = true;
        return;
    }

    if (!within_radius) return;

    // line-of-sight check
    if (TraceLine(player.GetOrigin() + player.GetClassEyeHeight(), frozen_statue_location, player) != 1) return;
    if (developer() >= 2) DebugDrawLine(player.GetCenter(), frozen_statue_location, 0, 0, 255, false, 0.5);

    // block progress if any enemy players are too close by
    //  (set number of thawing players to -1, marking the capture as blocked)
    if (player.GetTeam() == frozen_player.GetTeam()) {
        scope.revive_playercount += GetPlayerThawSpeed(player);
        scope.revive_players.push(player);
    } else {
        scope.revive_blocked = true;
    }
}