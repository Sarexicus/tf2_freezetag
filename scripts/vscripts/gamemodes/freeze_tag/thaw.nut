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
    player.SetHealth(player.GetMaxHealth() * health_multiplier_on_thaw);
    player.AddCondEx(TF_COND_INVULNERABLE_USER_BUFF, 1.0, player);
    player.AcceptInput("SpeakResponseConcept", "TLK_RESURRECTED", null, null);

    foreach (i, num in scope.ammo)
        SetPropIntArray(player, "localdata.m_iAmmo", num, i);
    
    // put the player at the freeze point where they died if it exists.
    //  it should do this nearly every time, but as a failsafe it'll put them in the spawn room
    if (scope.rawin("freeze_point") && scope.freeze_point) {
        player.SetOrigin(scope.freeze_point);
    }

    ResetPlayer(player);
    PlayThawSound(player);
    ShowThawParticle(player);
}

function ResetPlayer(player) {
    local scope = player.GetScriptScope();
    scope.frozen <- false;
    scope.revive_progress <- 0;

    RemoveFrozenPlayerModel(player);
    RemoveReviveProgressSprite(scope);
    RemoveGlow(scope);
    RemovePlayerReviveMarker(scope);
    RemoveParticles(scope);
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
    if (scope.rawin("revive_marker") && scope.revive_marker != null && scope.revive_marker.IsValid()) {
        scope.revive_marker.Kill();
    }
    scope.revive_marker <- null;
}

function RemoveGlow(scope) {
    if (scope.rawin("glow") && scope.glow != null && scope.glow.IsValid()) {
        scope.glow.Kill();
    }
    scope.glow <- null;
}

function RemoveReviveProgressSprite(scope) {
    if (scope.rawin("revive_progress_sprite") && scope.revive_progress_sprite != null && scope.revive_progress_sprite.IsValid()) {
        scope.revive_progress_sprite.Kill();
    }
    scope.revive_progress_sprite <- null;
}

function RemoveParticles(scope) {
    if (scope.rawin("particles") && scope.particles != null && scope.particles.IsValid()) {
        scope.particles.Kill();
    }
    scope.particles <- null;
}


function RemoveFrozenPlayerModel(player) {
    local scope = player.GetScriptScope();
    if( scope.rawin("frozen_player_model") && scope.frozen_player_model != null && scope.frozen_player_model.IsValid()) scope.frozen_player_model.Kill();
    if (scope.rawin("frozen_weapon_model") && scope.frozen_weapon_model != null && scope.frozen_weapon_model.IsValid()) scope.frozen_weapon_model.Kill();
}

function ThawThink() {
    for (local i = 1; i <= MaxPlayers; i++) {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        local scope = player.GetScriptScope();
        if (!scope.frozen) continue;

        if (developer() >= 2) DebugDrawBox(scope.freeze_point, vectriple(-4), vectriple(4), 0, 255, 0, 128, 0.5);

        local was_being_thawed = scope.revive_players > 0;
        scope.revive_players <- 0;
        ForEachAlivePlayer(ThawCheck, {
            "frozen_player": player,
            "scope": scope
        });
        
        scope.revive_players = min(scope.revive_players, 3);
        if (scope.revive_players > 0) {
            if (!was_being_thawed)
                SendGlobalGameEvent("show_annotation", {
                    text = "You are being thawed!"
                    id = player.entindex()
                    visibilityBitfield = 1 << player.entindex()
                    follow_entindex = scope.frozen_player_model.entindex()
                    lifetime = thaw_time
                    show_effect = false
                });

            local rate = 1.0;
            for (local j = 0; j < scope.revive_players - 1; j++) rate += 1 / (i+2);          
            scope.revive_progress += (1 / thaw_time) * tick_rate * rate;
        } else if (scope.revive_players == 0) {
            if (was_being_thawed)
                SendGlobalGameEvent("show_annotation", {
                    text = ""
                    id = player.entindex()
                    worldPosX = 0.0 worldPosY = 0.0 worldPosZ = 0.0
                    visibilityBitfield = 1 << player.entindex()
                    lifetime = 0.01
                    show_effect = false
                });

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

function ThawCheck(player, params) {
    if (!CanThaw(player)) return;

    local scope = params.scope;
    local frozen_statue = scope.frozen_player_model;
    local revive_marker = scope.revive_marker;
    if (!frozen_statue || !frozen_statue.IsValid()) return;

    local frozen_statue_location = frozen_statue.GetCenter();
    local frozen_player = params.frozen_player;
    if (scope.revive_players == -1) return;

    if (Distance(frozen_statue_location, player.GetCenter()) > thaw_distance) {
        local weapon = player.GetActiveWeapon();
        if (GetPropEntity(weapon, "m_hHealingTarget") == revive_marker) scope.revive_players += medigun_thawing_efficiency;
        return;
    }

    // line-of-sight check
    if (TraceLine(player.GetOrigin() + player.GetClassEyeHeight(), frozen_statue_location, player) != 1) return;
    if (developer() >= 2) DebugDrawLine(player.GetCenter(), frozen_statue_location, 0, 0, 255, false, 0.5);

    // block progress if any enemy players are too close by
    //  (set number of thawing players to -1, marking the capture is blocked)
    if (player.GetTeam() == frozen_player.GetTeam()) {
        scope.revive_players += 1;
    } else {
        scope.revive_players = -1;
    }
}