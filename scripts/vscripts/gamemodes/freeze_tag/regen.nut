// FREEZE TAG SCRIPT - POST-THAW REGEN 
// by Sarexicus and Le Codex
// -------------------------------

regen_rate <- 10;   // how much health you'll be regenerating per second

// -------------------------------

::StartRegenerating <- function(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = player.GetMaxHealth() - player.GetHealth() + 1;  // +1 so it's a full heal, for some reason it doesn't fully heal otherwise

    local sprite_particle = SpawnEntityFromTable("info_particle_system", {
        targetname = "regen_particle"
        effect_name = "powerup_icon_regen_" + (player.GetTeam() == TF_TEAM_RED ? "red": "blue"),
        origin = player.GetOrigin() + Vector(0, 0, 96)
        start_active = 1
    });
    sprite_particle.AcceptInput("SetParent", "!activator", player, player);
    scope.regen_particle = sprite_particle;
}

::StopRegenerating <- function(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = 0;
    scope.partial_regen = 0;
    SafeDeleteFromScope(scope, "regen_particle");
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