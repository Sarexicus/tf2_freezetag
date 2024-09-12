// FREEZE TAG SCRIPT - SPECTATING
// by Sarexicus and Le Codex
// -------------------------------

::force_spectate_when_thawing <- 2; // 0: don't force spectate. 1: force spectate once when thaw starts.
                                    // 2: force spectate while someone is thawing you. 3: force spectate while thaw has any progress. 4: always force spectate.

// -------------------------------

::ForceSpectateFrozenPlayer <- function(player) {
    local scope = player.GetScriptScope();

    local target = scope.spectate_origin;
    if (!target || !target.IsValid())
        target = FindFirstAlivePlayerOnTeam(player.GetTeam());
    else
        scope.spectating_self <- true;

    SetPropEntity(player, "m_hObserverTarget", target);
}

::FrozenPlayerSpectatorCycle <- function(player) {
    local scope = player.GetScriptScope();
    local observer = GetPropEntity(player, "m_hObserverTarget");
    if (observer == null || !observer.IsValid()) return;

    if (!scope.spectating_self) {
        if (observer == spectator_proxy) {
            ForceSpectateFrozenPlayer(player);
            return;
        }
    } else if (observer != scope.spectate_origin) {
        scope.spectating_self <- false;
        SetPropEntity(player, "m_hObserverTarget", FindFirstAlivePlayerOnTeam(player.GetTeam()));
        // if (observer.GetClassname() == "info_observer_point") {
        //     SetPropEntity(player, "m_hObserverTarget", FindFirstAlivePlayerOnTeam(player.GetTeam()));
        // }
    }
}

::ForcePlayerSpectateRules <- function(player) {
    local scope = player.GetScriptScope();
    // don't force spectate during deathcam
    if (GetPropInt(player, "m_iObserverMode") == 1) return;
    if (scope.is_medigun_revived) return;  // Mediguns already move the camera to the Medic
    switch (force_spectate_when_thawing) {
        case 0: // 0: don't force spectate.
            return;
        case 1: // 1: force spectate once when thaw starts.
            if (scope.revive_playercount > 0 && !scope.did_force_spectate) {
                ForceSpectateFrozenPlayer(player);
                scope.did_force_spectate = true;
            }
            break;
        case 2: // 2: force spectate while someone is thawing you.
            if (scope.revive_playercount > 0) {
                ForceSpectateFrozenPlayer(player);
            }
            break;
        case 3: // 3: force spectate while thaw has any progress.
            if (scope.revive_progress > 0) {
                ForceSpectateFrozenPlayer(player);
            }
            break;
        case 4: //  4: always force spectate.
            ForceSpectateFrozenPlayer(player);
            break;
    }
}