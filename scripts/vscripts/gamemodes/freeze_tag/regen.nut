// FREEZE TAG SCRIPT - POST-THAW REGEN 
// by Sarexicus and Le Codex
// -------------------------------

regen_rate <- 20;   // how much health you'll be regenerating per second

// -------------------------------

function StartRegenerating(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = player.GetMaxHealth() - player.GetHealth();

    local sprite_particle = SpawnEntityFromTable("info_particle_system", {
        effect_name = "powerup_icon_regen_" + (player.GetTeam() == TF_TEAM_RED ? "red": "blue"),
        origin = player.GetOrigin() + Vector(0, 0, 128)
        start_active = 1
    });
    sprite_particle.AcceptInput("SetParent", "!activator", player, player);
    scope.regen_particle = sprite_particle;
}

function StopRegenerating(player) {
    local scope = player.GetScriptScope();
    scope.regen_amount = 0;
    SafeDeleteFromScope(scope, "regen_particle");
}

function RegenThink(player) {
    local scope = player.GetScriptScope();
    if (scope.regen_amount <= 0) return;
    if (!IsPlayerAlive(player)) {
        StopRegenerating(player);
        return;
    }

    local regen_amount = min(scope.regen_amount, regen_rate * FrameTime());
    scope.regen_amount -= regen_amount;

    local max_health = player.GetMaxHealth();
    local health = min(max_health, player.GetHealth() + regen_amount);
    player.SetHealth(health);
    if (health >= max_health || scope.regen_amount <= 0) StopRegenerating(player);
}