// Combat-training-aware autobots script for S1X
// Bot scripts for S1x and H1-Mod for use on dedicated servers
// Updated: added Combat Training handling (fills to smaller size, don't kick bots on human join)
// Keep the rest of your mod/API calls (spawn_bots, bot_drop, getguid, etc.)

#include maps/mp/bots/_bots;

/*
 Mod: Autobots (Combat Training aware)
 Updated to S1X-compatible style
 - Auto-detects Combat Training (best-effort). You can also force it via config below.
 - In Combat Training: fill to a smaller match size, do NOT kick bots when a human joins.
 - In normal server mode: previous behavior (fill up to 18, kick bots when human joins to make space).
*/

////////////////////////////////////////////////////////////////////////////////
// CONFIG
////////////////////////////////////////////////////////////////////////////////
// Force combat training mode. If null/false, the script will try to auto-detect.
combatTrainingForce = true;

// Combat Training target player count (smaller than full-server dedicated matches)
combatTrainingMaxPlayers = 12;

// Dedicated-server target player count (original behavior)
dedicatedMaxPlayers = 18;

////////////////////////////////////////////////////////////////////////////////
// Initialization
////////////////////////////////////////////////////////////////////////////////

init()
{
    // decide mode early, so other threads can read the flag
    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread setDiffBots();
}

////////////////////////////////////////////////////////////////////////////////
// Try to auto-detect Combat Training (best-effort).
// If your S1X build exposes a clear gametype or mapname for combat training,
// this helper will pick it up. If detection fails, set combatTrainingForce = true.
detectCombatTraining()
{
    // best-effort checks: look for "combat" or "training" in gametype or mapname
    if (level)
    {
        if (level.gametype)
        {
            if (isSubStr(level.gametype, "combat") || isSubStr(level.gametype, "training"))
                return true;
        }

        if (level.mapname)
        {
            if (isSubStr(level.mapname, "combat") || isSubStr(level.mapname, "training"))
                return true;
        }
    }

    // fallback: if there is only one local player and not a networked server,
    // some builds may indicate offline mode by level.localplayer or similar;
    // we leave this conservative — allow manual override via combatTrainingForce.
    return false;
}

////////////////////////////////////////////////////////////////////////////////
// Player connect / join handling
////////////////////////////////////////////////////////////////////////////////

onPlayerConnect()
{
    level endon("game_ended");
    for (;;)
    {
        level waittill("connected", player);

        // If running Combat Training, we do not kick bots when a human joins.
        // Otherwise keep original behavior: if a human connected, kick a bot to make space.
        if (!level.combatTraining && !player isBot())
        {
            player thread kickBotOnJoin();
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
// isBot helper (S1X-friendly)
////////////////////////////////////////////////////////////////////////////////
isBot()
{
    return isSubStr(self getguid(), "bot");
}

////////////////////////////////////////////////////////////////////////////////
// Server fill thread: fills up to a mode-dependent target
////////////////////////////////////////////////////////////////////////////////
serverBotFill()
{
    level endon("game_ended");
    level waittill("connected", player);

    // determine fill target based on mode
    for (;;)
    {
        target = (level.combatTraining) ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

        while (level.players.size < target && !level.gameended)
        {
            // spawn a small batch so spawn_bots helper can handle team/autoassign behavior
            self spawnBots(4);
            wait 1;
        }

        // In dedicated-server mode, if humans fill the lobby and there are still bots,
        // kick bots to make room for humans (original behavior).
        if (!level.combatTraining)
        {
            if (level.players.size >= target && contBots() > 0)
                kickbot();
        }

        // In Combat Training mode we intentionally don't kick bots when a human joins.
        wait 0.05;
    }
}

////////////////////////////////////////////////////////////////////////////////
// Count bots currently in the level
////////////////////////////////////////////////////////////////////////////////
contBots()
{
    bots = 0;
    foreach (player in level.players)
    {
        if (player isBot())
        {
            bots++;
        }
    }
    return bots;
}

////////////////////////////////////////////////////////////////////////////////
// Spawn helper that delegates to base mod/API function
////////////////////////////////////////////////////////////////////////////////
spawnBots(a)
{
    // Use the project's provided spawn helper (preserves team/autoassign behavior):
    spawn_bots(a, "autoassign"); // spawnbots(n, team);
}

////////////////////////////////////////////////////////////////////////////////
// Kick a bot (legacy helper)
////////////////////////////////////////////////////////////////////////////////
kickbot()
{
    level endon("game_ended");
    foreach (player in level.players)
    {
        if (player isBot())
        {
            player bot_drop(); // bot_drop();
            break;
        }
    }
}

kickBotOnJoin()
{
    level endon("game_ended");
    foreach (player in level.players)
    {
        if (player isBot())
        {
            player bot_drop(); // bot_drop();
            break;
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
// Bot difficulty assignment
////////////////////////////////////////////////////////////////////////////////
/*
Set Bot difficulty below with the setDiffBots function
Level 1 - 2 "recruit"
Level 17 - 25 "regular"
Level 37 - 44 "hardened"
Level 47 - 50 with Prestige - "veteran"
*/
setDiffBots()
{
    for (;;)
    {
        level waittill("connected", player);
        // Apply difficulty only to bot entities
        if (player isBot())
        {
            // default to veteran in this example; change per your needs
            difficulty = "veteran";
            player setBotDifficulty(difficulty);
        }
    }
}

setBotDifficulty(difficulty)
{
    // 'self' = the bot player entity
    switch (difficulty)
    {
        case "regular":
            self.botAccuracy = 0.6;
            self.reactionTime = 0.5;
            self.maxHealth = 100;
            self.botAggression = 0.5;
            break;
        case "hardened":
            self.botAccuracy = 0.9;
            self.reactionTime = 0.2;
            self.maxHealth = 150;
            self.botAggression = 0.8;
            break;
        case "veteran":
            // Stronger, faster, more aggressive bots for veteran difficulty
            self.botAccuracy = 0.98;
            self.reactionTime = 0.12;
            self.maxHealth = 200;
            self.botAggression = 1.0;
            break;
        default:
            self.botAccuracy = 0.6;
            self.reactionTime = 0.5;
            self.maxHealth = 100;
            self.botAggression = 0.5;
            break;
    }
    self.health = self.maxHealth;
}
