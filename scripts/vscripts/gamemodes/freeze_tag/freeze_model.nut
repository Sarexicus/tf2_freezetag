// FREEZE TAG SCRIPT - FROZEN PLAYER MODEL
// by Sarexicus and Le Codex
// -------------------------------

::CreateFrozenPlayerModel <- function(pos, player, hide_until_unlocked=false) {
    // Reestablish this when we have found a way to get the disguise's animation
    local friendly_disguised = false; // player.InCond(TF_COND_DISGUISED) && GetPropInt(player, "m_Shared.m_nDisguiseTeam") == player.GetTeam();
    local scope = player.GetScriptScope();

    local player_class = player.GetPlayerClass();
    if (friendly_disguised) player_class = GetPropInt(player, "m_Shared.m_nDisguiseClass");
    local fpm = "models/freezetag/player/ft_hologram.mdl";

    local emitter = SpawnEntityFromTable("prop_dynamic", {
        targetname = "frozen_player_projector",
        model = "models/props_mvm/hologram_projector.mdl",
        origin = pos,
        angles = player.GetAbsAngles(),
        rendermode = 2,
        renderamt = hide_until_unlocked ? 0 : 255,
        modelscale = 0.5,
        solid = 0,
        DisableBoneFollowers = true
    });
    local trace = {
        start = pos + Vector(0, 0, 32),
        end = pos + Vector(0, 0, -10000),
        ignore = player,
        mask = CONTENTS_SOLID | CONTENTS_PLAYERCLIP | CONTENTS_TRANSLUCENT | CONTENTS_MOVEABLE
    };
    if (TraceLineEx(trace) && "enthit" in trace) {
        local v = emitter.GetForwardVector();
        local up = trace.plane_normal;
        up.Norm();
        local axis = Vector(0, 0, 1).Cross(up);
        axis.Norm();
        local pitch = acos(up.Dot(Vector(0, 0, 1)));
        local rotated = RotateAroundVector(v, axis, pitch);
        emitter.SetForwardVector(rotated);

        local angles = emitter.GetAbsAngles();
        angles.z = v.Dot(Vector(0, 0, 1).Cross(up)) * 180 / PI;
        emitter.SetAbsOrigin(trace.endpos);
        emitter.SetAbsAngles(angles);
    }

    local frozen_player_model = SpawnEntityFromTable("prop_dynamic", {
        targetname = "frozen_player",
        model = fpm,
        origin = emitter.GetOrigin(),
        angles = player.GetAbsAngles(),
        skin = player.GetSkin(),
        rendermode = 2,
        renderamt = hide_until_unlocked ? 0 : 100,
        modelscale = 1.3,
        solid = scope.solid ? 6 : 0,
        DisableBoneFollowers = true,
        disableshadows = true
        renderfx = hide_until_unlocked ? 0 : 4  // Fast Wide Pulse
    });

    emitter.AcceptInput("SetParent", "!activator", frozen_player_model, frozen_player_model);

    // bodygroups
    frozen_player_model.SetBodygroup(1, player_class - 1);
    frozen_player_model.SetCollisionGroup(COLLISION_GROUP_NONE);
    frozen_player_model.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);
    emitter.SetCollisionGroup(COLLISION_GROUP_NONE);
    emitter.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_FLY_BOUNCE);

    return frozen_player_model;
}