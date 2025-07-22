// FREEZE TAG SCRIPT - FREEZING
// by Sarexicus and Le Codex
// -------------------------------

IncludeScript(VSCRIPT_PATH + "freeze_points.nut", this);
IncludeScript(VSCRIPT_PATH + "freeze_model.nut", this);

::revive_unlock_time_penalty <- 0;                          // how much the lock time increases each time you die
::revive_unlock_time <- 2 - revive_unlock_time_penalty;     // how long it takes players to become thawable after being frozen
::revive_unlock_time_grace <- 3;                            // how muh time you have after getting thawed before the penalty will be applied on death
::revive_unlock_time_cap <- 5;                              // how long the unlock time can get

// -------------------------------

::FreezePlayer <- function(player, hide_until_unlocked=false) {
    // EntFire("tf_ragdoll", "RunScriptCode", "HideRagdoll(self)", 0.01, player);
    // EntFireByHandle(player, "RunScriptCode", "GetPropEntity(self, `m_hRagdoll`).Destroy(); SetPropEntity(self, `m_hRagdoll`, null);", 0.01, player, player);
    EntFire("tf_dropped_weapon", "Kill", "", 0, null);

    local scope = player.GetScriptScope();
    local freeze_position = FindFreezePoint(player);
    local freeze_point = freeze_position.pos();

    if (!hide_until_unlocked) PlayFreezeSound(player);

    scope.player_class <- player.GetPlayerClass();
    scope.freeze_point <- freeze_position;
    scope.revive_progress <- GetTeamMinProgress(player.GetTeam());
    scope.frozen <- true;
    scope.spectating_self <- false;
    scope.hidden <- hide_until_unlocked;

    if (Time() > scope.last_thaw_time + revive_unlock_time_grace) scope.revive_unlock_max_time += revive_unlock_time_penalty;
    if (scope.revive_unlock_max_time > revive_unlock_time_cap) scope.revive_unlock_max_time = revive_unlock_time_cap;
    scope.revive_unlock_time <- scope.revive_unlock_max_time;

    // scope.ammo <- {};
    // local length = NetProps.GetPropArraySize(player, "localdata.m_iAmmo");
    // for (local i = 0; i < length; i++)
    //     scope.ammo[i] <- NetProps.GetPropIntArray(player, "localdata.m_iAmmo", i);

    RemoveFrozenPlayerModel(scope);
    RemovePlayerReviveMarker(scope);
    RemoveGlow(scope);

    RunWithDelay(function() {
        scope.revive_marker <- CreateReviveMarker(freeze_position, player, hide_until_unlocked);
        scope.frozen_player_model <- CreateFrozenPlayerModel(freeze_point, player, hide_until_unlocked);
        scope.frozen_player_model.AcceptInput("SetParent", "!activator", scope.revive_marker, scope.revive_marker);

        player.Teleport(true, freeze_point + Vector(0, 0, 48), false, QAngle(0, 0, 0), true, Vector(0, 0, 0));
        scope.spectate_origin <- CreateSpectateOrigin(freeze_point + Vector(0, 0, 48));
        scope.particles <- CreateFreezeParticles(freeze_point, player, hide_until_unlocked);
        scope.glow <- CreateGlow(player, scope.frozen_player_model, hide_until_unlocked);
        scope.revive_progress_sprite <- CreateReviveProgressSprite(freeze_point, player, hide_until_unlocked);

        scope.particles.AcceptInput("SetParent", "!activator", scope.revive_marker, scope.revive_marker);
        scope.spectate_origin.AcceptInput("SetParent", "!activator", scope.revive_marker, scope.revive_marker);
        scope.revive_progress_sprite.AcceptInput("SetParent", "!activator", scope.particles, scope.particles);
    }, 0);
}

// NOTE: No need to worry about the YER, the DR can't block backstabs
::FakeFreezePlayer <- function(player) {
    // HACK: I don't think the fake ragdoll is stored anywhere, so we have to use that
    EntFire("tf_ragdoll", "Kill", "", 0.01, player);
    EntFire("tf_dropped_weapon", "Kill", "", 0, null);

    local scope = player.GetScriptScope();
    local freeze_position = FindFreezePoint(player);
    local freeze_point = freeze_position.pos();

    PlayFreezeSound(player);

    local fake_revive_marker = CreateReviveMarker(freeze_position, player);
    local fake_frozen_player_model = CreateFrozenPlayerModel(freeze_point, player);
    local fake_particles = CreateFreezeParticles(freeze_point, player);
    local fake_revive_progress_sprite = CreateFakeReviveProgressSprite(freeze_point, player);
    fake_frozen_player_model.AcceptInput("SetParent", "!activator", fake_revive_marker, fake_revive_marker);
    fake_particles.AcceptInput("SetParent", "!activator", fake_revive_marker, fake_revive_marker);
    fake_revive_progress_sprite.AcceptInput("SetParent", "!activator", fake_particles, fake_particles);
    fake_revive_marker.SetSolid(0);

    fake_revive_marker.ValidateScriptScope();
    fake_revive_marker.GetScriptScope().Think <- function() {
        if (!player.InCond(TF_COND_STEALTHED)) {
            EmitSoundEx({
                sound_name = fake_thaw_sound, channel = 128 + player.entindex(), sound_level = 100
                origin = self.GetCenter()
                filter_type = RECIPIENT_FILTER_GLOBAL
            });
            DispatchParticleEffect(fake_disappear_particle, self.GetCenter(), vectriple(0));
            CountAlivePlayers();
            RunWithDelay(function() { this.Destroy(); }, 0.01, [self]);
        }
    }
    AddThinkToEnt(fake_revive_marker, "Think");
}

::PlayFreezeSound <- function(player) {
    EmitSoundEx({
        sound_name = freeze_sound,
        origin = player.GetCenter(),
        filter_type = RECIPIENT_FILTER_GLOBAL
    });
}

::CreateReviveMarker <- function(position, player, hide_until_unlocked=false) {
    local revive_marker = SpawnEntityFromTable("entity_revive_marker", {
        "targetname": "player_revive",
        "origin": position.pos(),
        "angles": player.GetAbsAngles(),
        "rendermode": 10
    });
    revive_marker.SetModelSimple("models/freezetag/player/scout_frozen.mdl");

    SetPropEntity(revive_marker, "m_hOwner", player);
    SetPropInt(revive_marker, "m_iTeamNum", player.GetTeam())
    revive_marker.SetBodygroup(1, player.GetPlayerClass() - 1);  // Not really necessary since it's invisible

    SetPropInt(revive_marker, "m_iMaxHealth", player.GetMaxHealth());

    revive_marker.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);
    revive_marker.SetCollisionGroup(COLLISION_GROUP_DEBRIS);
    revive_marker.SetSolidFlags(0);
    if (hide_until_unlocked) revive_marker.SetSolid(0);

    local scope = player.GetScriptScope();
    if (position.parent && position.parent.IsValid())
        revive_marker.AcceptInput("SetParent", "!activator", position.parent, position.parent);

    return revive_marker;
}

::CreateFreezeParticles <- function(pos, player, hide_until_unlocked=false) {
    local scope = player.GetScriptScope();
    local particle_name = "ft_thawzone_" + ((player.GetTeam() == 2) ? "red" : "blu");

    local particles = SpawnEntityFromTable("info_particle_system", {
        "targetname": "freeze_particles",
        "effect_name": particle_name,
        "origin": pos,
        "TeamNum": player.GetTeam()
    });

    particles.SetTeam(player.GetTeam());
    particles.AcceptInput(hide_until_unlocked ? "Stop" : "Start", "", null, null);
    // UnpreserveEntity(particles);

    return particles;
}

::CreateGlow <- function(player, prop, hide_until_unlocked=false) {
    // "Prop" that will be glowing
    local proxy_entity = Entities.CreateByClassname("obj_teleporter");
    proxy_entity.SetAbsOrigin(prop.GetOrigin());
    proxy_entity.DispatchSpawn();
    proxy_entity.SetModel(prop.GetModelName());
    proxy_entity.AddEFlags(EFL_NO_THINK_FUNCTION);
    SetPropString(proxy_entity, "m_iName", UniqueString("glow_target"));
    SetPropBool(proxy_entity, "m_bPlacing", true);
    SetPropInt(proxy_entity, "m_fObjectFlags", 2);

    foreach (i in bodygroups_per_class[player.GetPlayerClass()]) {
        proxy_entity.SetBodygroup(i, player.GetBodygroup(i));
    }
    proxy_entity.AcceptInput("AddOutput", "rendermode 1", null, null);
    proxy_entity.AcceptInput("AddOutput", "renderamt 0", null, null);

    // Bonemerging
    proxy_entity.SetSolid(0);
    proxy_entity.SetMoveType(0, 0);
    SetPropInt(proxy_entity, "m_fEffects", 129);
    SetPropInt(proxy_entity, "m_nNextThinkTick", 0x7FFFFFFF);
    SetPropEntity(proxy_entity, "m_hBuilder", player);
    proxy_entity.AcceptInput("SetParent", "!activator", prop, prop);

    // tf_glow entity
    local glow = SpawnEntityFromTable("tf_glow", {
        targetname = "glow_" + proxy_entity.GetName(),
        target = proxy_entity.GetName(),
        GlowColor = "255 255 255 " + (hide_until_unlocked ? "0" : "255")
    });

    return glow;
}

::CreateReviveProgressSprite <- function(pos, player, hide_until_unlocked=false) {
    local sprite = SpawnEntityFromTable("env_glow", {
        "origin": pos + player.GetClassEyeHeight() + Vector(0, 0, 32),
        "model": "freeze_tag/revive_bar.vmt",
        "framerate": 0,
        "targetname": "revive_progress_sprite",
        "rendermode": 4,
        "rendercolor": "255 255 255",
        "renderamt": 200
        "scale": 0.25,
        "spawnflags": 1
        "teamnum": 5 - player.GetTeam()
    });

    if (hide_until_unlocked) sprite.AcceptInput("Alpha", "0", null, null);
    // UnpreserveEntity(sprite);
    return sprite;
}

::CreateFakeReviveProgressSprite <- function(pos, player) {
    local sprite = SpawnEntityFromTable("env_glow", {
        "origin": pos + player.GetClassEyeHeight() + Vector(0, 0, 32),
        "model": "freeze_tag/dead_ringer_icon_" + (player.GetTeam() == TF_TEAM_RED ? "red" : "blu") + ".vmt",
        "targetname": "revive_progress_sprite",
        "rendermode": 1,
        "renderamt": 128,
        "scale": 0.125,
        "spawnflags": 1,
        "teamnum": 5 - player.GetTeam()
    });

    // UnpreserveEntity(sprite);
    return sprite;
}

::CreateSpectateOrigin <- function(pos) {
    local spec_origin = SpawnEntityFromTable("prop_dynamic", {
        "targetname": "frozen_player_spectate_origin",
        "model": "models/empty.mdl",
        "origin": pos
    });
    return spec_origin;
}

::FreezeThink <- function(player) {
    if (!IsPlayerAlive(player)) return;

    CalculatePlayerFreezePoint(player);
    StorePlayerWeaponIndex(player);
    StorePlayerPoseParameters(player);
}

// EVENTS
// -----------------------------

::deadRingerSpies <- [];
getroottable()[EventsID].OnGameEvent_player_death <- function(params)
{
    local player = GetPlayerFromUserID(params.userid);
    if (player.GetTeam() < 2) return;
    local attacker = GetPlayerFromUserID(params.attacker);

    if (STATE == GAMESTATES.SETUP) {
        RunWithDelay(function() {
            CleanRespawn(player);
        }, 0.1);
    } else if (STATE == GAMESTATES.ROUND) {
        // if we're firing a custom death event, get us out of here
        if (params.death_flags == custom_death_flags) return;
        if (player.GetScriptScope().late_joiner) return;

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
            flawless[player.GetTeam()] = false;
            FreezePlayer(player, IsValidPlayer(attacker) && attacker != player && PlayerHasYERActive(attacker));
            RunWithDelay(function() { DetermineLastPlayerAlive(player); }, 0.1);
        }

        RunWithDelay(CountAlivePlayers, 0.1, [this, true]);
    }
}