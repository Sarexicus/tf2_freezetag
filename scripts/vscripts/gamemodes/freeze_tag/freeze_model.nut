// FREEZE TAG SCRIPT - FROZEN PLAYER MODEL
// by Sarexicus and Le Codex
// -------------------------------

::frozen_player_model_root <- "models/freezetag/player/";
::frozen_player_model_suffix <- "_frozen";
::single_frozen_player_model <- null;
::extra_prop_model <- null;
::model_scale <- 1.0;
::extra_prop_model_scale <- 1.0;

::transfer_sequence <- true;
::transfer_pose <- true;
::transfer_cosmetics <- true;

::frozen_color <- { [TF_TEAM_BLUE] = "255 255 255", [TF_TEAM_RED] = "255 255 255" };        // this is the color that will tint frozen weapons and cosmetics
::statue_color <- { [TF_TEAM_BLUE] = "225 240 255", [TF_TEAM_RED] = "255 225 240" };        // this is the color that will tint the frozen player models
::allowed_cosmetic_bones <- [ "bip_head", "medal_bone", "prp_pack_back" ];                  // cosmetics with any of those bones are allowed (cosmetics are disallowed by default)
::disallowed_cosmetic_bones <- [ "bip_spine0", "bip_spine1", "bip_spine2", "bip_spine3", "bip_pelvis", "bip_jacketcollar_0_R", "bip_jacketcollar_0_L", "bip_jacketcollar_0_B" ];  // cosmetics with any of those bones are disallowed

::bodygroup_is_class <- false;
::bodygroups_per_class <- {
    [TF_CLASS_SCOUT] = [0, 1],
    [TF_CLASS_SOLDIER] = [1, 2],
    [TF_CLASS_PYRO] = [0],
    [TF_CLASS_DEMOMAN] = [],
    [TF_CLASS_HEAVYWEAPONS] = [0],
    [TF_CLASS_ENGINEER] = [0, 1],
    [TF_CLASS_MEDIC] = [],
    [TF_CLASS_SNIPER] = [0, 1, 2],
    [TF_CLASS_SPY] = [],
}

// -------------------------------

::GetFrozenPlayerModel <- function(player_class) {
    if (single_frozen_player_model) return single_frozen_player_model;
    switch(player_class) {
        case TF_CLASS_SCOUT:         return frozen_player_model_root + "scout" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_SOLDIER:       return frozen_player_model_root + "soldier" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_PYRO:          return frozen_player_model_root + "pyro" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_DEMOMAN:       return frozen_player_model_root + "demo" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_HEAVYWEAPONS:  return frozen_player_model_root + "heavy" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_ENGINEER:      return frozen_player_model_root + "engineer" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_MEDIC:         return frozen_player_model_root + "medic" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_SNIPER:        return frozen_player_model_root + "sniper" + frozen_player_model_suffix + ".mdl";
        case TF_CLASS_SPY:           return frozen_player_model_root + "spy" + frozen_player_model_suffix + ".mdl";
        default: return "";
    }
}

::CreateFrozenPlayerModel <- function(pos, player, hide_until_unlocked=false) {
    // Reestablish this when we have found a way to get the disguise's animation
    local friendly_disguised = false; // player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") == player.GetTeam();
    local scope = player.GetScriptScope();

    local player_class = player.GetPlayerClass();
    if (friendly_disguised) player_class = GetPropInt(player, "m_Shared.m_nDisguiseClass");
    local fpm = GetFrozenPlayerModel(player_class);

    local extra_prop = null
    if (extra_prop_model) {
        extra_prop = SpawnEntityFromTable("prop_dynamic", {
            targetname = "frozen_player_extra",
            model = extra_prop_model,
            origin = pos,
            angles = player.GetAbsAngles(),
            rendermode = 2,
            renderamt = hide_until_unlocked ? 0 : 255,
            modelscale = extra_prop_model_scale,
            solid = 0,
            DisableBoneFollowers = true,
            disableshadows = true
        });
        local trace = {
            start = pos + Vector(0, 0, 32),
            end = pos + Vector(0, 0, -10000),
            ignore = player,
            mask = CONTENTS_SOLID | CONTENTS_PLAYERCLIP | CONTENTS_TRANSLUCENT | CONTENTS_MOVEABLE
        };
        if (TraceLineEx(trace) && "enthit" in trace) {
            local v = extra_prop.GetForwardVector();
            local up = trace.plane_normal;
            up.Norm();
            local axis = Vector(0, 0, 1).Cross(up);
            axis.Norm();
            local pitch = acos(up.Dot(Vector(0, 0, 1)));
            local rotated = RotateAroundVector(v, axis, pitch);
            extra_prop.SetForwardVector(rotated);

            local angles = extra_prop.GetAbsAngles();
            angles.z = v.Dot(Vector(0, 0, 1).Cross(up)) * 180 / PI;
            extra_prop.SetAbsOrigin(trace.endpos);
            extra_prop.SetAbsAngles(angles);
        }
    }

    local frozen_player_model = SpawnEntityFromTable("prop_dynamic", {
        targetname = "frozen_player",
        model = fpm,
        origin = extra_prop ? extra_prop.GetOrigin() : pos,
        angles = player.GetAbsAngles(),
        skin = player.GetSkin(),
        rendermode = 2,
        rendercolor = statue_color[player.GetTeam()]
        renderamt = hide_until_unlocked ? 0 : 100
        modelscale = model_scale
        solid = scope.solid ? 6 : 0,
        DisableBoneFollowers = true,
    });

    // bodygroups
    if (bodygroup_is_class) {
        frozen_player_model.SetBodygroup(1, player_class - 1);
    } else {
        foreach (i in bodygroups_per_class[player.GetPlayerClass()]) {
            frozen_player_model.SetBodygroup(i, player.GetBodygroup(i));
        }
    }

    if (extra_prop) {
        extra_prop.AcceptInput("SetParent", "!activator", frozen_player_model, frozen_player_model);
        extra_prop.SetCollisionGroup(COLLISION_GROUP_NONE);
        extra_prop.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);
    }

    if (transfer_sequence) {
        local sequence_name = GetGroundedSequenceName(player);
        frozen_player_model.ResetSequence(frozen_player_model.LookupSequence(sequence_name));
        frozen_player_model.SetCycle(player.GetCycle());
        frozen_player_model.SetPlaybackRate(0.001);
    }
    SetPropBool(frozen_player_model, "m_bClientSideAnimation", false);
    frozen_player_model.SetCollisionGroup(COLLISION_GROUP_NONE);
    frozen_player_model.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);

    // pose parameters
    if (transfer_pose) {
        local ang = scope.ang;
        local eye_ang = scope.eye_ang;
        local vel = scope.vel;
        local dir = Vector(vel.x, vel.y, vel.z);
        local speed = dir.Norm() / 300.0;
        frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("move_x"), dir.Dot(ang.Forward()) * speed);
        frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("move_y"), dir.Dot(ang.Left()) * speed);
        frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("body_pitch"), -eye_ang.x);
        frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("body_yaw"), ang.y - eye_ang.y);
    }

    // Weapon model
    /* local weapon_modelname = friendly_disguised ? GetPropEntity(player, "m_Shared.m_hDisguiseWeapon").GetModelName() : GetWeaponModel(scope.weapon_index);
    local frozen_weapon_model = null;
    if (weapon_modelname != null && weapon_modelname != "") {
        frozen_weapon_model = SpawnEntityFromTable("prop_dynamic_ornament", {
            "model": weapon_modelname,
            "rendermode": 5,
            "renderamt": 192,
            "rendercolor": frozen_color[player.GetTeam()],
            "targetname": "frozen_weapon_model",
            "skin": player.GetSkin()
        });
        EntFireByHandle(frozen_weapon_model, "SetAttached", "!activator", 0.05, frozen_player_model, null);

        scope.frozen_weapon_model <- frozen_weapon_model;
    } */

    // cosmetics
    if (transfer_cosmetics) {
        local disguise_target = GetPropEntity(player, "m_Shared.m_hDisguiseTarget");
        local origin = friendly_disguised ? (disguise_target.GetPlayerClass() == player_class ? disguise_target : null) : player;
        if (origin) {
            for (local wearable = origin.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer())
            {
                if (wearable.GetClassname() != "tf_wearable")
                    continue;

                local wearable_modelname = wearable.GetModelName();
                if (wearable_modelname == null || wearable_modelname == "")
                    continue;

                local cosmetic_model = SpawnEntityFromTable("prop_dynamic_ornament", {
                    targetname = "frozen_wearable",
                    origin = frozen_player_model.GetOrigin(),
                    rendermode = 2,
                    renderamt = hide_until_unlocked ? 0 : 192,
                    rendercolor = frozen_color[player.GetTeam()],
                    model = wearable.GetModelName(),
                    skin = player.GetSkin()
                });

                local valid = false;
                foreach (bone_name in allowed_cosmetic_bones) {
                    if (cosmetic_model.LookupBone(bone_name) > -1) {
                        valid = true;
                        break;
                    }
                }
                foreach (bone_name in disallowed_cosmetic_bones) {
                    if (cosmetic_model.LookupBone(bone_name) > -1) {
                        valid = false;
                        break;
                    }
                }

                if (!valid) {
                    cosmetic_model.Destroy();
                    continue;
                }

                EntFireByHandle(cosmetic_model, "SetAttached", "!activator", 0.05, frozen_player_model, null);
            }
        }
    }

    return frozen_player_model;
}