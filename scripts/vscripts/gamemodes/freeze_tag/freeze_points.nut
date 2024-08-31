// FREEZE TAG SCRIPT - FREEZING (STUCK PREVENTION)
// by Sarexicus and Le Codex
// --------------------------------------

local nav_threshold_calculate = 16;             // check this far away from a downwards trace for a navmesh to create a new freeze point
local nav_threshold_is_grounded = 48;           // check this far away for a navmesh to see if a player is "grounded"

local max_freeze_points = 50;                   // maximum number of spots to check per-player for safe freezing on death
local unique_distance_points_threshold = 0.5;   // fraction of freeze points which will enforce a minimum distance to all others

local hull_trace_margin = Vector(5, 5, 0);      // expand the player's hull by this amount to check if a freeze spot is valid to avoid getting stuck from imprecision. DON'T EXPAND VERTICALLY
local offground_leniency = Vector(0, 0, 5);     // raise the hull by this much, to prevent margins colliding with complex geometry like displacements

// --------------------------------------

function CalculatePlayerFreezePoint(player) {
    player.ValidateScriptScope();
    local scope = player.GetScriptScope();
    
    local traceTable = {
        "start": player.GetOrigin() + Vector(0, 0, 32)
        "end": player.GetOrigin() + Vector(0, 0, -10000),
        "ignore": player,
        "hullmin": player.GetPlayerMins(),
        "hullmax": player.GetPlayerMaxs() - Vector(0, 0, 64),  // Make the hull shorter to avoid it getting stuck if the player is crouching
        "mask": CONTENTS_SOLID
    }
    if(TraceHull(traceTable) && "hit" in traceTable) {
        local freeze_position = traceTable["endpos"];
        local navPosition = NavMesh.GetNearestNavArea(freeze_position, nav_threshold_calculate, true, true);
        if(navPosition != null) {
            if(scope.freeze_positions.len() >= 2) {
                local previous_index = scope.position_index-1;
                if(previous_index <= 0) previous_index = scope.freeze_positions.len() - 1;

                // don't allow new freeze points too close to the previous X points defined by the threshold
                local j = previous_index;
                for (local i = 0; i < floor(max_freeze_points * unique_distance_points_threshold); i++) {
                    local previous_position = scope.freeze_positions[j];

                    if(Distance(freeze_position, previous_position) < 24) {
                        if (i > 0) scope.position_index = RollingPush(scope.freeze_positions, previous_position, scope.position_index, max_freeze_points);
                        return;
                    }

                    j -= 1;
                    if(j <= 0) j = scope.freeze_positions.len() - 1;
                }
            }
            if (developer() >= 2) DebugDrawBox(freeze_position, vectriple(-4), vectriple(4), 255, 0, 0, 100, 5)

            // rolling array - only store a fixed amount maximum, start replacing above maximum size
            scope.position_index = RollingPush(scope.freeze_positions, freeze_position, scope.position_index, max_freeze_points);
        }
    }
}

function RollingPush(arr, element, index, max_size) {
    if (arr.len() <= index) {
        arr.push(element);
    } else {
        arr[index] = element;
    }

    return (index + 1) % max_size;
}

function SpaceAvailableForFreezePoint(location, player) {
    local traceTable = {
        "start": location,
        "end": location,
        "hullmin": player.GetPlayerMins() - hull_trace_margin + offground_leniency,
        "hullmax": player.GetPlayerMaxs() + hull_trace_margin,
        "ignore": player
    }
    TraceHull(traceTable);
    return !("enthit" in traceTable);
}

function FindFreezePoint(player) {
    // Make special triggers collide with traces to invalidate any freeze points inside
    local collisionGroup = null;
    for (local ent; ent = Entities.FindByName(ent, "ft_func_nofreeze");) {
        if (!collisionGroup) collisionGroup = ent.GetCollisionGroup();  // Store the first one, because all of them should be equal anyways
        ent.SetCollisionGroup(COLLISION_GROUP_NONE);
        ent.RemoveSolidFlags(FSOLID_NOT_SOLID);
    }

    local result = SearchForFreezePoint(player);

    // Revert the changes
    for (local ent; ent = Entities.FindByName(ent, "ft_func_nofreeze");) {
        ent.SetCollisionGroup(collisionGroup);
        ent.AddSolidFlags(FSOLID_NOT_SOLID);
    }

    return result;
}

function SearchForFreezePoint(player) {
    local scope = player.GetScriptScope();

    // don't find a freeze point for non-aerial players who are near the navmesh,
    //  because they're already "grounded" and teleporting them is a waste.
    //  still perform the collision check, though, because they could die while standing inside a teammate,
    //  and we don't want that teammate getting stuck
    if(GetPropEntity(player, "m_hGroundEntity") != null) {
        local navPosition = NavMesh.GetNearestNavArea(player.GetOrigin(), nav_threshold_is_grounded, true, true);
        if(navPosition != null && SpaceAvailableForFreezePoint(player.GetOrigin(), player)) {
            scope.solid <- players_solid_when_frozen;
            return player.GetOrigin();
        }
    }

    local foundFreezePoint = false;
    local searchIndex = scope.position_index - 1;
    local maxSearchIndex = searchIndex;
    if(searchIndex <= 0) searchIndex = scope.freeze_positions.len() - 1;

    // worst-case scenario - they haven't moved at all and spawned too close to a teammate. just freeze them here.
    if (searchIndex == -1) {
        scope.solid <- false;
        return player.GetOrigin();
    }

    local iterations = 0;
    local max_iterations = max_freeze_points;

    while (searchIndex != maxSearchIndex || iterations < max_iterations) {
        local searchPos = scope.freeze_positions[searchIndex];

        if (developer() >= 2) DebugDrawBox(searchPos, player.GetPlayerMins(), player.GetPlayerMaxs(), 0, 255, 0, 100, 15)

        if (SpaceAvailableForFreezePoint(searchPos, player)) {
            scope.solid <- players_solid_when_frozen;
            return searchPos;
        }

        searchIndex -= 1;
        if(searchIndex <= 0) searchIndex = scope.freeze_positions.len() - 1;
        iterations += 1;
    }

    // if no places are free, and we absolutely can't place it anywhere else,
    //  use the most recent location and set the model to nonsolid for now
    scope.solid <- false;
    return scope.freeze_positions[maxSearchIndex];
}
