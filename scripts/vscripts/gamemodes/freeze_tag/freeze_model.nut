// FREEZE TAG SCRIPT - FROZEN PLAYER MODEL
// by Sarexicus and Le Codex
// -------------------------------

::frozen_color <- { [TF_TEAM_BLUE] = "255 255 255", [TF_TEAM_RED] = "255 255 255" };        // this is the color that will tint frozen weapons and cosmetics
::statue_color <- { [TF_TEAM_BLUE] = "225 240 255", [TF_TEAM_RED] = "255 225 240" };        // this is the color that will tint the frozen player models
::allowed_cosmetic_bones <- [ "bip_head", "medal_bone", "prp_pack_back" ];                  // cosmetics with any of those bones are allowed (cosmetics are disallowed by default)
::disallowed_cosmetic_bones <- [ "bip_spine0", "bip_spine1", "bip_spine2", "bip_spine3", "bip_pelvis", "bip_jacketcollar_0_R", "bip_jacketcollar_0_L", "bip_jacketcollar_0_B" ];  // cosmetics with any of those bones are disallowed
::bodygroups_per_class <- { 
    [TF_CLASS_SCOUT] = [0, 1],
    [TF_CLASS_SOLDIER] = [1, 2],
    [TF_CLASS_PYRO] = [0],
    [TF_CLASS_DEMOMAN] = [],
    [TF_CLASS_HEAVYWEAPONS] = [1],
    [TF_CLASS_ENGINEER] = [0, 1],
    [TF_CLASS_MEDIC] = [],
    [TF_CLASS_SNIPER] = [0, 1, 2],
    [TF_CLASS_SPY] = [],
}

// -------------------------------

::CreateFrozenPlayerModel <- function(pos, player) {
    // Reestablish this when we have found a way to get the disguise's animation
    local friendly_disguised = false; // player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") == player.GetTeam();
    local scope = player.GetScriptScope();

    local player_class = player.GetPlayerClass();
    if (friendly_disguised) player_class = GetPropInt(player, "m_Shared.m_nDisguiseClass");
    local fpm = GetFrozenPlayerModel(player_class);

    local frozen_player_model = SpawnEntityFromTable("prop_dynamic", {
        targetname = "frozen_player",
        model = fpm,
        origin = pos,
        angles = player.GetAbsAngles(),
        skin = player.GetSkin(),
        rendermode = 2,
        rendercolor = statue_color[player.GetTeam()]
        renderamt = 100
        solid = scope.solid ? 6 : 0,
        DisableBoneFollowers = true
    });

    // bodygroups
    foreach (i in bodygroups_per_class[player.GetPlayerClass()]) {
        frozen_player_model.SetBodygroup(i, player.GetBodygroup(i));
    }
    
    local sequence_name = GetGroundedSequenceName(player);
    frozen_player_model.ResetSequence(frozen_player_model.LookupSequence(sequence_name));
    frozen_player_model.SetCycle(player.GetCycle());
    frozen_player_model.SetPlaybackRate(0.001);
    SetPropBool(frozen_player_model, "m_bClientSideAnimation", false);
    frozen_player_model.SetCollisionGroup(COLLISION_GROUP_NONE);
    frozen_player_model.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);

    // pose parameters
    local ang = scope.ang;
    local eye_ang = scope.eye_ang;
    local vel = scope.vel;
    local dir = Vector(vel.x, vel.y, vel.z);
    local speed = dir.Norm() / 300.0;
    frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("move_x"), dir.Dot(ang.Forward()) * speed);
    frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("move_y"), dir.Dot(ang.Left()) * speed);
    frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("body_pitch"), -eye_ang.x);
    frozen_player_model.SetPoseParameter(frozen_player_model.LookupPoseParameter("body_yaw"), ang.y - eye_ang.y);

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
                renderamt = 192,
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

    return frozen_player_model;
}