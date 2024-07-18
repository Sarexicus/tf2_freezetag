// FREEZE TAG SCRIPT - FREEZING
// by Sarexicus and Le Codex
// -------------------------------

IncludeScript(VSCRIPT_PATH + "freeze_points.nut", this);

local frozen_color = "0 228 255"; // this is the color that will tint frozen weapons, cosmetics, and placeholder player models

// -------------------------------

function FreezePlayer(player) {
    EntFireByHandle(player, "RunScriptCode", "NetProps.GetPropEntity(self, `m_hRagdoll`).Destroy()", 0.01, player, player);

    local freeze_point = FindFreezePoint(player);
    if (freeze_point != null) {
        player.Teleport(true, freeze_point, false, QAngle(0, 0, 0), true, Vector(0, 0, 0));
    }

    local scope = player.GetScriptScope();

    HidePlayer(player);
    PlayFreezeSound(player);

    scope.player_class <- player.GetPlayerClass();

    RemoveFrozenPlayerModel(player);
    CreateFrozenPlayerModel(player, scope);

    scope.frozen <- true;
    scope.revive_marker <- CreateReviveMarker(player);
    scope.revive_progress_sprite <- CreateReviveProgressSprite(player);
}

function PlayFreezeSound(player) {
    EmitSoundEx({
        sound_name = freeze_sound,
        origin = player.GetCenter(),
        filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
    });
}

function HidePlayer(player) {
    player.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);
    SetPropInt(player, "m_nRenderMode", 10);
}


function CreateReviveMarker(player) {
    local revive_marker = SpawnEntityFromTable("entity_revive_marker", {
        "targetname": "player_revive",
        "origin": player.GetOrigin()
        "angles": player.GetAbsAngles(),
        "solid": 0,
        "rendermode": 10
    });

    SetPropEntity(revive_marker, "m_hOwner", player);
    SetPropInt(revive_marker, "m_iTeamNum", player.GetTeam())
    revive_marker.SetBodygroup(1, player.GetPlayerClass() - 1);

    SetPropInt(revive_marker, "m_iMaxHealth", player.GetMaxHealth());
    return revive_marker;
}

function GetFrozenPlayerModel(player) {
    switch(player.GetPlayerClass()) {
        case TF_CLASS_SCOUT:         return "models/player/scout.mdl";//"models/frozen/scout_frozen.mdl";
        case TF_CLASS_SOLDIER:       return "models/player/soldier.mdl";
        case TF_CLASS_PYRO:          return "models/player/pyro.mdl";
        case TF_CLASS_DEMOMAN:       return "models/player/demo.mdl";
        case TF_CLASS_HEAVYWEAPONS:  return "models/player/heavy.mdl";//"models/frozen/heavy_frozen.mdl";
        case TF_CLASS_ENGINEER:      return "models/player/engineer.mdl";
        case TF_CLASS_MEDIC:         return "models/player/medic.mdl";
        case TF_CLASS_SNIPER:        return "models/player/sniper.mdl";
        case TF_CLASS_SPY:           return "models/player/spy.mdl";
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

function CreateFrozenPlayerModel(player, scope) {
    if (!scope.rawin("cosmetics")) scope.cosmetics <- [];

    local fpm = GetFrozenPlayerModel(player);

    local frozen_player_model = SpawnEntityFromTable("prop_dynamic", {
        targetname = "frozen_player",
        model = fpm,
        origin = player.GetOrigin(),
        angles = player.GetAbsAngles(),
        skin = player.GetSkin(),
        rendermode = 2,
        solid = (scope.solid) ? 6 : 0
    });

    // HACK: tint player for now if we don't have the frozen player model yet
    if (fpm.find("/player/") != null) {
        frozen_player_model.KeyValueFromString("rendercolor", frozen_color);
    }

    frozen_player_model.SetSequence(player.GetSequence());
    frozen_player_model.SetCycle(player.GetCycle());

    local weapon_modelname = GetWeaponModel(scope.weapon_index);
    local frozen_weapon_model = SpawnEntityFromTable("prop_dynamic_ornament", {
        "model": weapon_modelname,
        "rendermode": 5,
        "renderamt": 230,
        "rendercolor": frozen_color,
        "targetname": "frozen_weapon_model",
        "skin": player.GetSkin()
    });
    EntFireByHandle(frozen_weapon_model, "SetAttached", "!activator", 0.05, frozen_player_model, null);

    // cosmetics
    for (local wearable = player.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer())
    {
        if (wearable.GetClassname() != "tf_wearable")
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

    scope.frozen_player_model <- frozen_player_model;
    scope.frozen_weapon_model <- frozen_weapon_model;
    scope.revive_progress <- 0;
}

function CreateReviveProgressSprite(player) {
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
    }
}

function GetPlayerWeaponIndex(player) {
    local scope = player.GetScriptScope();
    scope.weapon_index <- GetPropInt(player.GetActiveWeapon(), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
}

// EVENTS
// -----------------------------

function OnGameEvent_player_death(params)
{
    local player = GetPlayerFromUserID(params.userid);
    if (STATE == GAMESTATES.SETUP) {
        RunWithDelay(function() {
            CleanRespawn(player);
        }, 0.1);
    } else if (STATE == GAMESTATES.ROUND) {
        FreezePlayer(player);
        RunWithDelay(CountAlivePlayers, 0.1, [this, true]);
    }
}