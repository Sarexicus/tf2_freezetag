// FREEZE TAG SCRIPT - UTILITY
// by Sarexicus and Le Codex
// -------------------------------

function vectriple(a) { return Vector(a, a, a); }
function Distance(vec1, vec2) { return (vec1-vec2).Length(); }
function max(a, b) { return (a > b) ? a : b; }

::MaxPlayers <- MaxClients().tointeger();
::ROOT <- getroottable();

// table folding (constants, netprops)
if (!("ConstantNamingConvention" in ROOT)) // make sure folding is only done once
{
    // fold constants
	foreach (a,b in Constants)
		foreach (k,v in b)
			ROOT[k] <- v != null ? v : 0;

    // fold netprops
    foreach (k, v in ::NetProps.getclass())
        if (k != "IsValid")
            ROOT[k] <- ::NetProps[k].bindenv(::NetProps);
}


function ForEachAlivePlayer(callback, params = {}) {
    for (local i = 1; i <= MaxPlayers; i++)
    {
        local player = PlayerInstanceFromIndex(i)
        if (player == null) continue;

        if(GetPropInt(player, "m_lifeState") != 0) continue;

        callback(player, params);
    }
}