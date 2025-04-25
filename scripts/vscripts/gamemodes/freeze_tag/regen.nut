// FREEZE TAG SCRIPT - POST-THAW REGEN 
// by Sarexicus and Le Codex
// -------------------------------

::regen_rate <- 10;   // how much health you'll be regenerating per second

// -------------------------------

::regen_trigger_particles <- [
    SpawnEntityFromTable("trigger_particle", {
        particle_name = regen_particle + "_red",
        attachment_type = 1, // PATTACH_ABSORIGIN_FOLLOW,
        spawnflags = 64 // allow everything
    }),
    SpawnEntityFromTable("trigger_particle", {
        particle_name = regen_particle + "_blu",
        attachment_type = 1, // PATTACH_ABSORIGIN_FOLLOW,
        spawnflags = 64 // allow everything
    }),
]

::StartRegenerating <- function(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = player.GetMaxHealth() - player.GetHealth() + 1;  // +1 so it's a full heal, for some reason it doesn't fully heal otherwise
    regen_trigger_particles[player.GetTeam() - 2].AcceptInput("StartTouch", "!activator", player, player);
}

::StopRegenerating <- function(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = 0;
    scope.partial_regen = 0;
    player.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null);
}

::RegenThink <- function(player) {
    local scope = player.GetScriptScope();
    if (scope.regen_amount <= 0) return;
    if (!IsPlayerAlive(player)) {
        StopRegenerating(player);
        return;
    }

    local regen_amount = min(scope.regen_amount, regen_rate * tick_rate);
    scope.regen_amount -= regen_amount;
    scope.partial_regen += regen_amount;

    local max_health = player.GetMaxHealth();
    local health = player.GetHealth();
    while (scope.partial_regen > 1) {
        health = min(max_health, health + 1);
        scope.partial_regen--;
    }
    player.SetHealth(health);
    if (health >= max_health || scope.regen_amount <= 0) StopRegenerating(player);
}
