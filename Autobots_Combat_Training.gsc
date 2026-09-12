// ============================================================
// Autobots Combat Training Script (AW-style tuning)
// ------------------------------------------------------------
// Credits
// ------------------------------------------------------------
// Original script/base logic:
//   - lp0r0b0tech
//
// Maintenance, integration, and server-side tuning:
//   - lp0r0b0tech
//
// Community knowledge/reference patterns:
//   - Call of Duty modding/scripting community
//
// AI-assisted debugging/refactor support:
//   - GitHub Copilot (OpenAI)
//
// License/Attribution Notice:
//   - Preserve this credit block in redistributions and derivatives.
//   - If you reuse portions, retain attribution to original authors.
// ============================================================
#include maps/mp/bots/_bots;

combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;

defaultBotDifficulty = "expert";     // now supports: regular, hardened, veteran, expert
defaultBotLevel = 55;

// AW-style knobs
awStyleEnable = true;
awPressureSpawnDelay = 0.15;         // faster refill pressure than 0.25
awTrimDelay = 0.03;                  // faster slot cleanup
awHealthRegenOnSpawn = true;

// Debug controls
debugAutobots = true;          // master switch
debugVerbose = false;          // noisy per-loop/per-spawn logs
debugHeartbeatInterval = 5.0;  // seconds

init()
{
    if (combatTrainingMaxPlayers < 0)
        combatTrainingMaxPlayers = 0;

    if (dedicatedMaxPlayers < 0)
        dedicatedMaxPlayers = 0;

    if (awPressureSpawnDelay < 0.05)
        awPressureSpawnDelay = 0.05;

    if (awTrimDelay < 0.01)
        awTrimDelay = 0.01;

    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    dbg("init() combatTraining=" + level.combatTraining
        + " ctMax=" + combatTrainingMaxPlayers
        + " dedMax=" + dedicatedMaxPlayers
        + " awStyle=" + awStyleEnable
        + " defaultDiff=" + defaultBotDifficulty);

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
}

detectCombatTraining()
{
    if (isDefined(level.gametype))
    {
        if (isSubStr(level.gametype, "combat") || isSubStr(level.gametype, "training")
         || isSubStr(level.gametype, "COMBAT") || isSubStr(level.gametype, "TRAINING")
         || isSubStr(level.gametype, "Combat") || isSubStr(level.gametype, "Training"))
        {
            dbg("detectCombatTraining(): matched gametype=" + level.gametype);
            return true;
        }
    }

    if (isDefined(level.mapname))
    {
        if (isSubStr(level.mapname, "combat") || isSubStr(level.mapname, "training")
         || isSubStr(level.mapname, "COMBAT") || isSubStr(level.mapname, "TRAINING")
         || isSubStr(level.mapname, "Combat") || isSubStr(level.mapname, "Training"))
        {
            dbg("detectCombatTraining(): matched mapname=" + level.mapname);
            return true;
        }
    }

    dbg("detectCombatTraining(): no match, default false");
    return false;
}

onPlayerConnect()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);

        if (!isDefined(player))
            continue;

        guid = "unknown";
        if (isDefined(player getguid()))
            guid = player getguid();

        bot = player isBotEntity();
        dbg("connected guid=" + guid + " isBot=" + bot);

        if (bot)
        {
            player setBotDifficulty(defaultBotDifficulty);
            
            // Apply rank and prestige before applyBotPrestigeSetting
            player.rank = int(defaultBotLevel);
            if (!isDefined(player.pers))
                player.pers = [];
            player.pers["rank"] = int(defaultBotLevel);
            
            player applyBotPrestigeSetting();

            if (awHealthRegenOnSpawn)
                player.health = player.maxHealth;
        }
        else if (!level.combatTraining)
        {
            dbg("human connected in dedicated mode -> trimBotsToTarget()");
            trimBotsToTarget();
        }
        else
        {
            dbg("human connected in combat training mode -> no bot kick");
        }
    }
}

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"]))
        return self.pers["isBot"];

    if (isDefined(self getguid()))
    {
        guid = self getguid();
        return isSubStr(guid, "bot") || isSubStr(guid, "BOT") || isSubStr(guid, "Bot");
    }

    return false;
}

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;
    dbg("serverBotFill() started");

    for (;;)
    {
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

        if (target < 0)
            target = 0;

        total = level.players.size;

        if (debugVerbose)
            dbg("fill loop: players=" + total + " target=" + target + " bots=" + countBots());

        while (level.players.size < target)
        {
            missing = target - level.players.size;
            spawnCount = 1;

            if (missing < spawnCount)
                spawnCount = missing;

            if (spawnCount <= 0)
                break;

            if (debugVerbose)
                dbg("spawning bots=" + spawnCount + " missing=" + missing);

            spawnBots(spawnCount);

            if (awStyleEnable)
                wait awPressureSpawnDelay;
            else
                wait 0.25;
        }

        if (!level.combatTraining && level.players.size > target)
            trimBotsToTarget();

        if (awStyleEnable)
            wait 0.15;
        else
            wait 0.25;
    }
}

countBots()
{
    bots = 0;
    foreach (player in level.players)
    {
        if (!isDefined(player))
            continue;

        if (player isBotEntity())
            bots++;
    }
    return bots;
}

countHumans()
{
    humans = 0;
    foreach (player in level.players)
    {
        if (!isDefined(player))
            continue;

        if (!(player isBotEntity()))
            humans++;
    }
    return humans;
}

spawnBots(a)
{
    if (!isDefined(a) || a <= 0)
        return;

    spawn_bots(a, "autoassign");
}

kickOneBot()
{
    level endon("game_ended");

    foreach (player in level.players)
    {
        if (!isDefined(player))
            continue;

        if (player isBotEntity())
        {
            guid = "unknown";
            if (isDefined(player getguid()))
                guid = player getguid();

            dbg("kickOneBot(): dropping bot guid=" + guid);
            player bot_drop();
            return true;
        }
    }

    return false;
}

trimBotsToTarget()
{
    target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

    if (target < 0)
        target = 0;

    safety = 32;
    while (level.players.size > target && countBots() > 0 && safety > 0)
    {
        if (!kickOneBot())
            break;

        safety--;

        if (awStyleEnable)
            wait awTrimDelay;
        else
            wait 0.05;
    }

    if (safety == 0)
        dbg("trimBotsToTarget(): safety break hit");
}

setBotDifficulty(difficulty)
{
    if (!isDefined(difficulty))
        difficulty = "regular";

    // AW-style: faster reaction + higher aggression profile
    if (awStyleEnable)
    {
        switch (difficulty)
        {
            case "regular":
                self.botAccuracy = 0.68;
                self.reactionTime = 0.35;
                self.maxHealth = 100;
                self.botAggression = 0.72;
                break;

            case "hardened":
                self.botAccuracy = 0.85;
                self.reactionTime = 0.16;
                self.maxHealth = 120;
                self.botAggression = 0.90;
                break;

            case "veteran":
                self.botAccuracy = 0.95;
                self.reactionTime = 0.10;
                self.maxHealth = 140;
                self.botAggression = 0.98;
                break;

            case "expert":
                self.botAccuracy = 0.99;
                self.reactionTime = 0.06;
                self.maxHealth = 165;
                self.botAggression = 1.00;
                break;

            default:
                self.botAccuracy = 0.68;
                self.reactionTime = 0.35;
                self.maxHealth = 100;
                self.botAggression = 0.72;
                difficulty = "regular";
                break;
        }
    }
    else
    {
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
                self.botAccuracy = 0.98;
                self.reactionTime = 0.12;
                self.maxHealth = 200;
                self.botAggression = 0.98;
                break;

            case "expert":
                self.botAccuracy = 1.00;
                self.reactionTime = 0.08;
                self.maxHealth = 225;
                self.botAggression = 1.00;
                break;

            default:
                self.botAccuracy = 0.6;
                self.reactionTime = 0.5;
                self.maxHealth = 100;
                self.botAggression = 0.5;
                difficulty = "regular";
                break;
        }
    }

    self.health = self.maxHealth;

    guid = "unknown";
    if (isDefined(self getguid()))
        guid = self getguid();

    dbg("setBotDifficulty(): " + difficulty
        + " acc=" + self.botAccuracy
        + " rt=" + self.reactionTime
        + " hp=" + self.health
        + " aggr=" + self.botAggression
        + " aw=" + awStyleEnable
        + " guid=" + guid);
}

applyBotPrestigeSetting()
{
    prestigeMode = getPrestigeModeSafe();

    guid = "unknown";
    if (isDefined(self getguid()))
        guid = self getguid();

    dbg("applyBotPrestigeSetting(): mode=" + prestigeMode + " guid=" + guid);

    if (prestigeMode == -1)
    {
        hostPrestige = getHostPrestige();
        dbg("prestige mode -1 -> hostPrestige=" + hostPrestige);
        self setBotPrestige(hostPrestige);
    }
    else if (prestigeMode == -2)
    {
        r = randomInt(16);
        dbg("prestige mode -2 -> randomPrestige=" + r);
        self setBotPrestige(r);
    }
    else
    {
        if (prestigeMode < 0)
            prestigeMode = 0;
        if (prestigeMode > 15)
            prestigeMode = 15;

        dbg("prestige fixed -> " + prestigeMode);
        self setBotPrestige(prestigeMode);
    }
}

getPrestigeModeSafe()
{
    mode = getDvarInt("bots_main_prestige");

    if (mode < -2)
        mode = -2;
    if (mode > 15)
        mode = 15;

    return mode;
}

getHostPrestige()
{
    foreach (p in level.players)
    {
        if (!isDefined(p))
            continue;

        if (!(p isBotEntity()))
        {
            if (isDefined(p.prestige))
                return int(p.prestige);

            if (isDefined(p.pers) && isDefined(p.pers["prestige"]))
                return int(p.pers["prestige"]);

            return 0;
        }
    }

    return 0;
}

setBotPrestige(prestige)
{
    if (!isDefined(prestige))
        prestige = 0;

    prestige = int(prestige);

    if (prestige < 0)
        prestige = 0;
    if (prestige > 15)
        prestige = 15;

    // Set prestige first
    if (isDefined(self setprestige))
        self setprestige(prestige);

    self.prestige = prestige;

    if (!isDefined(self.pers))
        self.pers = [];

    self.pers["prestige"] = prestige;
    
    // Apply rank AFTER prestige
    self.rank = int(defaultBotLevel);
    self.pers["rank"] = int(defaultBotLevel);
    
    // Force rank update if method exists
    if (isDefined(self setrank))
        self setrank(int(defaultBotLevel));

    guid = "unknown";
    if (isDefined(self getguid()))
        guid = self getguid();

    dbg("setBotPrestige(): prestige=" + prestige + " rank=" + self.rank + " guid=" + guid);
}

liveDebugHeartbeat()
{
    level endon("game_ended");

    for (;;)
    {
        humans = countHumans();
        bots = countBots();

        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

        dbg("LIVE mode=" + (level.combatTraining ? "combat" : "dedicated")
            + " total=" + level.players.size
            + " humans=" + humans
            + " bots=" + bots
            + " target=" + target
            + " aw=" + awStyleEnable);

        wait debugHeartbeatInterval;
    }
}

dbg(msg)
{
    if (!debugAutobots)
        return;

    iprintln("^2[Autobots]^7 " + msg);
    println("[Autobots] " + msg);
}
