// FREEZE TAG SCRIPT - THAW METER
// by Sarexicus and Le Codex
// -------------------------------

local show_thawing_text = false; // does the word "THAWING" show up on the thaw meter?

// -------------------------------

local small_numbers = {
    "1": "₁",
    "2": "₂",
    "3": "₃",
    "4": "₄",
    "5": "₅",
    "6": "₆",
    "7": "₇",
    "8": "₈",
    "9": "₉",
    "0": "₀",
    ".": "."
}

local filled = "▰";
local unfilled = "▱";

text_thaw_meter <- SpawnEntityFromTable("game_text", {
    channel = 1, color = "255 255 255", color2 = "0 0 0", fadein = 0, fadeout = 0, holdtime = 0.5, effect = 0,
    message = "0"
    targetname = "text_thaw_meter", x = -1, y = 0.75, spawnflags = 0
});
text_thaw_timeleft <- SpawnEntityFromTable("game_text", {
    channel = 2, color = "255 255 255", color2 = "0 0 0", fadein = 0, fadeout = 0, holdtime = 0.5, effect = 0,
    message = "0"
    targetname = "text_thaw_timeleft", x = -1, y = 0.73, spawnflags = 0
});

function ToSubscript(text) {
    local out = "";
    foreach (char in text)
        out += small_numbers[char.tochar()];
    return out;
}

function GenerateMeterText(percent) {
    local out = "";
    for (local i = 0; i < 1; i += 0.1) {
        out += (i+0.08 < percent) ? filled : unfilled;
    }
    return out;
}

function TestShowThawMeterText(seconds, max_seconds, rate) {
    local player = activator;
    ShowThawMeterText(player, seconds, max_seconds, rate);
}

function ShowThawMeterText(player, seconds, max_seconds, rate) {
    if (seconds < 0 || seconds >= max_seconds) return;
    if (rate == -1) rate = 0;

    local percentage = seconds / max_seconds;
    local seconds_text = format("%s ₍⤫%s₎", ToSubscript(format("%1.1f", max_seconds - seconds)), ToSubscript(format("%1.0f", rate)));

    local opt = "ᵀᴴᴬᵂᴵᴺᴳ\n";
    if (show_thawing_text) seconds_text = opt + seconds_text;

    local percent_meter = GenerateMeterText(percentage);

    DisplayText(text_thaw_timeleft, player, seconds_text);
    DisplayText(text_thaw_meter, player, percent_meter);
}

function DisplayText(entity, player, text) {
    entity.AcceptInput("AddOutput", "message " + text, null, null);
    entity.AcceptInput("Display", "", player, player);
}