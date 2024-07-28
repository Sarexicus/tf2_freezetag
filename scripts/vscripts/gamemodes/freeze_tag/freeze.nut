// FREEZE TAG SCRIPT - FREEZING
// by Sarexicus and Le Codex
// -------------------------------

IncludeScript(VSCRIPT_PATH + "freeze_points.nut", this);

frozen_color <- "0 228 255"; // this is the color that will tint frozen weapons, cosmetics, and placeholder player models

// -------------------------------

function FreezePlayer(player) {
    EntFireByHandle(player, "RunScriptCode", "GetPropEntity(self, `m_hRagdoll`).Destroy()", 0.01, player, player);

    local freeze_point = FindFreezePoint(player);
    if (freeze_point != null) {
        player.Teleport(true, freeze_point, false, QAngle(0, 0, 0), true, Vector(0, 0, 0));
    } else {
        freeze_point = player.GetOrigin();
    }

    local scope = player.GetScriptScope();

    PlayFreezeSound(player);

    scope.player_class <- player.GetPlayerClass();
    scope.freeze_point <- freeze_point;
    scope.revive_progress <- 0;
    scope.frozen <- true;

    RemoveFrozenPlayerModel(player);
    RemovePlayerReviveMarker(scope);
    RemoveGlow(scope);

    RunWithDelay(function() {
        scope.revive_marker <- CreateReviveMarker(freeze_point, player);
        scope.frozen_player_model <- CreateFrozenPlayerModel(freeze_point, player, scope);
        EntFireByHandle(scope.frozen_player_model, "SetParent", "!activator", -1, scope.revive_marker, scope.revive_marker);

        scope.particles <- CreateFreezeParticles(freeze_point, player, scope);
        scope.glow <- CreateGlow(player, scope.frozen_player_model);
        scope.revive_progress_sprite <- CreateReviveProgressSprite(freeze_point, player);
    }, 0);
}

function FakeFreezePlayer(player) {
    // HACK: I don't think the fake ragdoll is stored anywhere, so we have to use that
    EntFire("tf_ragdoll", "Kill", "", 0.01, player);

    local freeze_point = FindFreezePoint(player);
    local scope = player.GetScriptScope();

    PlayFreezeSound(player);

    local fake_revive_marker = CreateReviveMarker(freeze_point, player);
    local fake_frozen_player_model = CreateFrozenPlayerModel(freeze_point, player, scope);
    EntFireByHandle(fake_frozen_player_model, "SetParent", "!activator", -1, fake_revive_marker, fake_revive_marker);

    fake_revive_marker.ValidateScriptScope();
    fake_revive_marker.GetScriptScope().Think <- function() {
        if (!player.InCond(TF_COND_STEALTHED)) {
            EmitSoundEx({
                sound_name = fake_thaw_sound,
                origin = self.GetCenter(),
                filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
            });
            DispatchParticleEffect(fake_disappear_particle, self.GetCenter(), vectriple(0));
            CountAlivePlayers();
            self.Kill();
        }
    }
    AddThinkToEnt(fake_revive_marker, "Think");
}

function PlayFreezeSound(player) {
    EmitSoundEx({
        sound_name = freeze_sound,
        origin = player.GetCenter(),
        filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
    });
}

function CreateReviveMarker(pos, player) {
    local revive_marker = SpawnEntityFromTable("entity_revive_marker", {
        "targetname": "player_revive",
        "origin": pos,
        "angles": player.GetAbsAngles(),
        "solid": 0,
        "rendermode": 10
    });

    SetPropEntity(revive_marker, "m_hOwner", player);
    SetPropInt(revive_marker, "m_iTeamNum", player.GetTeam())
    revive_marker.SetBodygroup(1, player.GetPlayerClass() - 1);  // Not really necessary since it's invisible

    SetPropInt(revive_marker, "m_iMaxHealth", player.GetMaxHealth());

    revive_marker.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);
    revive_marker.SetCollisionGroup(COLLISION_GROUP_NONE);
    return revive_marker;
}

function GetFrozenPlayerModel(player_class) {
    switch(player_class) {
        case TF_CLASS_SCOUT:         return "models/props_freezetag/scout_frozen.mdl";
        case TF_CLASS_SOLDIER:       return "models/props_freezetag/soldier_frozen.mdl";
        case TF_CLASS_PYRO:          return "models/props_freezetag/pyro_frozen.mdl";
        case TF_CLASS_DEMOMAN:       return "models/props_freezetag/demo_frozen.mdl";
        case TF_CLASS_HEAVYWEAPONS:  return "models/props_freezetag/heavy_frozen.mdl";
        case TF_CLASS_ENGINEER:      return "models/props_freezetag/engineer_frozen.mdl";
        case TF_CLASS_MEDIC:         return "models/props_freezetag/medic_frozen.mdl";
        case TF_CLASS_SNIPER:        return "models/props_freezetag/sniper_frozen.mdl";
        case TF_CLASS_SPY:           return "models/props_freezetag/spy_frozen.mdl";
        default: return "";
    }
}

// spawn a weapon from its item ID specifically to grab its modelname
function GetWeaponModel(wep_idx)
{
    local wearable = Entities.CreateByClassname("tf_wearable");
    SetPropInt(wearable, "m_fEffects", 32);
    wearable.SetSolidFlags(4);
    wearable.SetCollisionGroup(11);
    SetPropInt(wearable, "m_AttributeManager.m_Item.m_bInitialized", 1);
    SetPropInt(wearable, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", wep_idx);
    Entities.DispatchSpawn(wearable);

    local name = wearable.GetModelName();

    wearable.Kill()

    return name;
}

function CreateFrozenPlayerModel(pos, player, scope) {
    if (!scope.rawin("cosmetics")) scope.cosmetics <- [];
    // Reestablish this when we have found a way to get the disguise's animation
    local friendly_disguised = false; // player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") == player.GetTeam();

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
        solid = (scope.solid) ? 6 : 0
    });
    // todo: add bodygroups later
    // for (local i = 0; i < 256; i++) {
    //     frozen_player_model.SetBodygroup(i, player.GetBodygroup(i));
    // }

    // HACK: tint player for now if we don't have the frozen player model yet
    if (fpm.find("/player/") != null) {
        frozen_player_model.KeyValueFromString("rendercolor", frozen_color);
    }

    local sequenceName = player.GetSequenceName(player.GetSequence());
    frozen_player_model.ResetSequence(frozen_player_model.LookupSequence(sequenceName));
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
    local weapon_modelname = friendly_disguised ? GetPropEntity(player, "m_Shared.m_hDisguiseWeapon").GetModelName() : GetWeaponModel(scope.weapon_index);
    local frozen_weapon_model = null;
    if (weapon_modelname != null && weapon_modelname != "") {
        frozen_weapon_model = SpawnEntityFromTable("prop_dynamic_ornament", {
            "model": weapon_modelname,
            "rendermode": 5,
            "renderamt": 230,
            "rendercolor": frozen_color,
            "targetname": "frozen_weapon_model",
            "skin": player.GetSkin()
        });
        EntFireByHandle(frozen_weapon_model, "SetAttached", "!activator", 0.05, frozen_player_model, null);

        scope.frozen_weapon_model <- frozen_weapon_model;
    }

    // cosmetics
    local disguise_target = GetPropEntity(player, "m_Shared.m_hDisguiseTarget");
    local origin = friendly_disguised ? (disguise_target.GetPlayerClass() == player_class ? disguise_target : null) : player;
    if (origin) {
        for (local wearable = origin.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer())
        {
            if (wearable.GetClassname() != "tf_wearable")
                continue;

            local wearable_modelname = wearable.GetModelName();
            printl(wearable_modelname);

            if (wearable_modelname == null || wearable_modelname == "")
                continue;

            local cosmetic_model = SpawnEntityFromTable("prop_dynamic_ornament",
            {
                targetname = "frozen_wearable",
                origin = frozen_player_model.GetOrigin(),
                rendermode = 2,
                renderamt = 230,
                rendercolor = frozen_color,
                model = wearable.GetModelName(),
                skin = player.GetSkin()
            });
            EntFireByHandle(cosmetic_model, "SetAttached", "!activator", 0.05, frozen_player_model, null);

            scope.cosmetics.push(cosmetic_model);
        }
    }

    return frozen_player_model;
}

function TestFreezeParticles(team) {
    local player = GetListenServerHost();
    local particles = SpawnEntityFromTable("info_particle_system", {
        "targetname": "freeze_particles",
        "effect_name": "ft_teamtest_sprite",
        "origin": player.GetOrigin(),
        "TeamNum": team
    });
    particles.SetTeam(team);
    particles.AcceptInput("Start", "", null, null);
    // by default, the particle will preserve between rounds. change its classname here to prevent that
    SetPropString(particles, "m_iClassname", "info_teleport_destination");
}

function CreateFreezeParticles(pos, player, scope) {
    local particle_name = "ft_thawzone_circleonly_" + ((player.GetTeam() == 2) ? "red" : "blu");

    local particles = SpawnEntityFromTable("info_particle_system", {
        "targetname": "freeze_particles",
        "effect_name": particle_name,
        "origin": pos,
        "TeamNum": player.GetTeam()
    });

    particles.SetTeam(player.GetTeam());

    particles.AcceptInput("Start", "", null, null);
    // by default, the particle will preserve between rounds. change its classname here to prevent that
    SetPropString(particles, "m_iClassname", "info_teleport_destination");

    return particles;
}

function CreateGlow(player, prop) {
    // "Prop" that will be glowing
    local proxy_entity = Entities.CreateByClassname("obj_teleporter");
    proxy_entity.SetAbsOrigin(prop.GetOrigin());
    proxy_entity.DispatchSpawn();
    proxy_entity.SetModel(prop.GetModelName());
    proxy_entity.AddEFlags(Constants.FEntityEFlags.EFL_NO_THINK_FUNCTION);
    SetPropString(proxy_entity, "m_iName", UniqueString("glow_target"));
    SetPropBool(proxy_entity, "m_bPlacing", true);
    SetPropInt(proxy_entity, "m_fObjectFlags", 2);

    // Bonemerging
    proxy_entity.SetSolid(0);
    proxy_entity.SetMoveType(0, 0);
    SetPropInt(proxy_entity, "m_fEffects", 129);
    SetPropInt(proxy_entity, "m_nNextThinkTick", 0x7FFFFFFF);
    SetPropEntity(proxy_entity, "m_hBuilder", player);
    EntFireByHandle(proxy_entity, "SetParent", "!activator", -1, prop, prop);

    // tf_glow entity
    local glow = SpawnEntityFromTable("tf_glow", {
        targetname = "glow_" + proxy_entity.GetName(),
        target = proxy_entity.GetName(),
        GlowColor = "255 255 255 255"
    });

    return glow;
}

function CreateReviveProgressSprite(pos, player) {
    local sprite = SpawnEntityFromTable("env_sprite", {
        "origin": player.GetOrigin() + player.GetClassEyeHeight() + Vector(0, 0, 32),
        "model": "freeze_tag/revive_bar.vmt",
        "framerate": 0,
        "targetname": "revive_progress_sprite",
        "rendermode": 2,
        "scale": 0.25,
        "spawnflags": 1,
        "teamnum": player.GetTeam()
    });

    // by default, the sprite will preserve between rounds. change its classname here to prevent that
    SetPropString(sprite, "m_iClassname", "info_teleport_destination");

    return sprite;
}

function FreezeThink() {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i);
        if (player == null) continue;

        if(GetPropInt(player, "m_lifeState") != 0) continue;

        CalculatePlayerFreezePoint(player);
        GetPlayerWeaponIndex(player);
        GetPlayerPoseParameters(player);
    }
}

function GetPlayerWeaponIndex(player) {
    local scope = player.GetScriptScope();
    scope.weapon_index <- GetPropInt(player.GetActiveWeapon(), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
}

function GetPlayerPoseParameters(player) {
    local scope = player.GetScriptScope();
    scope.ang <- player.GetAbsAngles();
    scope.eye_ang <- player.EyeAngles();
    scope.vel <- player.GetAbsVelocity();
}

// EVENTS
// -----------------------------

deadRingerSpies <- [];
function OnGameEvent_player_death(params)
{
    local player = GetPlayerFromUserID(params.userid);
    printl(player);
    if (STATE == GAMESTATES.SETUP) {
        RunWithDelay(function() {
            CleanRespawn(player);
        }, 0.1);
    } else if (STATE == GAMESTATES.ROUND) {
        if (params.death_flags & 32) {
            // HACK: Because of a weird inconsistency with friendly disguises, we actually need to make sure we actually got the Spy
            local spy = null;
            foreach (player in GetAllPlayers()) {
                local entindex = player.entindex();
                if (deadRingerSpies.find(entindex) == null && GetPropFloat(player, "m_Shared.m_flCloakMeter") == 50.0) {
                    spy = player;
                    deadRingerSpies.push(entindex);
                    break;
                }
            }

            if (spy) FakeFreezePlayer(spy);
        } else {
            FreezePlayer(player);
        }

        RunWithDelay(CountAlivePlayers, 0.1, [this, true]);
    }
}