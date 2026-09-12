// ============================================================
// Autobots Combat Training Script (MAX COMPAT MODE)
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

defaultBotDifficulty = "impossable"; // supports: regular, hardened, veteran, expert, pro, impossible (alias: impossable)
defaultBotLevel = 55;

// AW-style knobs
awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;

// Compatibility toggles (disable risky natives by default)
compatUseSetPrestigeNative = false; // set true only if your title supports self setprestige(...)
compatUseSetRankNative = false;     // set true only if your title supports self setrank(...)
compatUseBotDropNative = true;      // set false if bot_drop() crashes/unsupported

// Debug controls
debugAutobots = true;
debugVerbose = false;
debugHeartbeatInterval = 5.0;

// Runtime mode
campaignMode = false;

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

    if (debugHeartbeatInterval < 0.2)
        debugHeartbeatInterval = 0.2;

    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    campaignMode = isCampaignMode();

    defaultBotDifficulty = normalizeDifficultyName(defaultBotDifficulty);

    dbg("init() combatTraining=" + level.combatTraining
        + " ctMax=" + combatTrainingMaxPlayers
        + " dedMax=" + dedicatedMaxPlayers
        + " awStyle=" + awStyleEnable
        + " campaignMode=" + campaignMode
        + " defaultDiff=" + defaultBotDifficulty);

    if (campaignMode)
    {
        applyCampaignDifficulty(defaultBotDifficulty);
        level thread campaignDifficultyEnforcer();
    }

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();

    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();
}

normalizeDifficultyName(d)
{
    if (!isDefined(d))
        return "regular";

    s = toLower(d);
    if (s == "impossable")
        return "impossible";

    return s;
}

safeGetGuid(ent)
{
    if (!isDefined(ent))
        return "unknown";

    g = ent getguid();
    if (!isDefined(g) || g == "")
        return "unknown";

    return g;
}

isCampaignMode()
{
    if (!isDefined(level.gametype) || level.gametype == "")
        return true;

    gt = toLower(level.gametype);

    if (isSubStr(gt, "dm")
        || isSubStr(gt, "tdm")
        || isSubStr(gt, "ctf")
        || isSubStr(gt, "sd")
        || isSubStr(gt, "war")
        || isSubStr(gt, "dom")
        || isSubStr(gt, "combat")
        || isSubStr(gt, "training"))
    {
        return false;
    }

    return true;
}

detectCombatTraining()
{
    gt = "";
    if (isDefined(level.gametype))
        gt = toLower(level.gametype);

    if (isSubStr(gt, "combat") || isSubStr(gt, "training"))
        return true;

    mn = "";
    if (isDefined(level.mapname))
        mn = toLower(level.mapname);

    if (isSubStr(mn, "combat") || isSubStr(mn, "training"))
        return true;

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

        guid = safeGetGuid(player);
        bot = player isBotEntity();
        dbg("connected guid=" + guid + " isBot=" + bot);

        if (bot)
        {
            player applyAutobotDifficulty(defaultBotDifficulty);

            player.rank = int(defaultBotLevel);
            if (!isDefined(player.pers))
                player.pers = [];
            player.pers["rank"] = int(defaultBotLevel);
            player.pers["autobot_diff_applied"] = defaultBotDifficulty;

            player applyBotPrestigeSetting();

            if (awHealthRegenOnSpawn)
                player.health = player.maxHealth;
        }
        else if (!level.combatTraining)
        {
            trimBotsToTarget();
        }
    }
}

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"]))
        return self.pers["isBot"];

    g = self getguid();
    if (isDefined(g))
        return isSubStr(g, "bot") || isSubStr(g, "BOT") || isSubStr(g, "Bot");

    return false;
}

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;

    for (;;)
    {
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        if (target < 0)
            target = 0;

        while (level.players.size < target)
        {
            spawnBots(1);
            wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (!level.combatTraining && level.players.size > target)
            trimBotsToTarget();

        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

countBots()
{
    n = 0;
    foreach (p in level.players)
    {
        if (isDefined(p) && (p isBotEntity()))
            n++;
    }
    return n;
}

countHumans()
{
    n = 0;
    foreach (p in level.players)
    {
        if (isDefined(p) && !(p isBotEntity()))
            n++;
    }
    return n;
}

spawnBots(a)
{
    if (!isDefined(a) || a <= 0)
        return;

    // Assume _bots provides this.
    spawn_bots(a, "autoassign");
}

kickOneBot()
{
    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity()))
            continue;

        guid = safeGetGuid(p);

        if (!compatUseBotDropNative)
        {
            dbg("kickOneBot(): bot_drop disabled by compat toggle guid=" + guid);
            return false;
        }

        // Risky native path can be turned off by toggle above.
        p bot_drop();
        dbg("kickOneBot(): dropped bot guid=" + guid);
        return true;
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
        wait (awStyleEnable ? awTrimDelay : 0.05);
    }
}

delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 1.0;
    applyDifficultyToAllBots(defaultBotDifficulty, true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        applyDifficultyToAllBots(defaultBotDifficulty, false);
        wait 3.0;
    }
}

campaignDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        applyCampaignDifficulty(defaultBotDifficulty);
        wait 2.0;
    }
}

applyDifficultyToAllBots(difficulty, force)
{
    difficulty = normalizeDifficultyName(difficulty);
    if (!isDefined(force))
        force = false;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity()))
            continue;

        if (!force
            && isDefined(p.pers)
            && isDefined(p.pers["autobot_diff_applied"])
            && p.pers["autobot_diff_applied"] == difficulty)
        {
            continue;
        }

        p applyAutobotDifficulty(difficulty);

        p.rank = int(defaultBotLevel);
        if (!isDefined(p.pers))
            p.pers = [];
        p.pers["rank"] = int(defaultBotLevel);
        p.pers["autobot_diff_applied"] = difficulty;

        p applyBotPrestigeSetting();

        if (awHealthRegenOnSpawn)
            p.health = p.maxHealth;
    }
}

applyAutobotDifficulty(difficulty)
{
    difficulty = normalizeDifficultyName(difficulty);

    if (campaignMode)
    {
        self applyCampaignDifficultyToActor(difficulty);
        return;
    }

    if (awStyleEnable)
    {
        switch (difficulty)
        {
            case "regular":   self.botAccuracy = 0.68; self.reactionTime = 0.35; self.maxHealth = 100; self.botAggression = 0.72; break;
            case "hardened":  self.botAccuracy = 0.85; self.reactionTime = 0.16; self.maxHealth = 120; self.botAggression = 0.90; break;
            case "veteran":   self.botAccuracy = 0.95; self.reactionTime = 0.10; self.maxHealth = 140; self.botAggression = 0.98; break;
            case "expert":    self.botAccuracy = 0.99; self.reactionTime = 0.06; self.maxHealth = 165; self.botAggression = 1.00; break;
            case "pro":       self.botAccuracy = 1.00; self.reactionTime = 0.03; self.maxHealth = 185; self.botAggression = 1.00; break;
            case "impossible":self.botAccuracy = 1.00; self.reactionTime = 0.01; self.maxHealth = 250; self.botAggression = 1.00; break;
            default:          self.botAccuracy = 0.68; self.reactionTime = 0.35; self.maxHealth = 100; self.botAggression = 0.72; break;
        }
    }
    else
    {
        switch (difficulty)
        {
            case "regular":   self.botAccuracy = 0.60; self.reactionTime = 0.50; self.maxHealth = 100; self.botAggression = 0.50; break;
            case "hardened":  self.botAccuracy = 0.90; self.reactionTime = 0.20; self.maxHealth = 150; self.botAggression = 0.80; break;
            case "veteran":   self.botAccuracy = 0.98; self.reactionTime = 0.12; self.maxHealth = 200; self.botAggression = 0.98; break;
            case "expert":    self.botAccuracy = 1.00; self.reactionTime = 0.08; self.maxHealth = 225; self.botAggression = 1.00; break;
            case "pro":       self.botAccuracy = 1.00; self.reactionTime = 0.04; self.maxHealth = 250; self.botAggression = 1.00; break;
            case "impossible":self.botAccuracy = 1.00; self.reactionTime = 0.01; self.maxHealth = 300; self.botAggression = 1.00; break;
            default:          self.botAccuracy = 0.60; self.reactionTime = 0.50; self.maxHealth = 100; self.botAggression = 0.50; break;
        }
    }

    self.health = self.maxHealth;
    dbg("applyAutobotDifficulty(): " + difficulty + " guid=" + safeGetGuid(self));
}

applyCampaignDifficulty(diff)
{
    d = normalizeDifficultyName(diff);

    switch (d)
    {
        case "regular":    setDvar("ai_accuracy", "0.55"); setDvar("ai_cautiousness", "0.45"); setDvar("ai_meleeRange", "64");  setDvar("player_healthregentime", "5");  break;
        case "hardened":   setDvar("ai_accuracy", "0.72"); setDvar("ai_cautiousness", "0.30"); setDvar("ai_meleeRange", "72");  setDvar("player_healthregentime", "6");  break;
        case "veteran":    setDvar("ai_accuracy", "0.85"); setDvar("ai_cautiousness", "0.20"); setDvar("ai_meleeRange", "80");  setDvar("player_healthregentime", "7");  break;
        case "expert":     setDvar("ai_accuracy", "0.92"); setDvar("ai_cautiousness", "0.12"); setDvar("ai_meleeRange", "88");  setDvar("player_healthregentime", "8");  break;
        case "pro":        setDvar("ai_accuracy", "0.97"); setDvar("ai_cautiousness", "0.08"); setDvar("ai_meleeRange", "96");  setDvar("player_healthregentime", "9");  break;
        case "impossible": setDvar("ai_accuracy", "1.00"); setDvar("ai_cautiousness", "0.00"); setDvar("ai_meleeRange", "112"); setDvar("player_healthregentime", "10"); break;
        default:           setDvar("ai_accuracy", "0.55"); setDvar("ai_cautiousness", "0.45"); setDvar("ai_meleeRange", "64");  setDvar("player_healthregentime", "5");  break;
    }
}

applyCampaignDifficultyToActor(diff)
{
    d = normalizeDifficultyName(diff);

    switch (d)
    {
        case "regular": self.maxHealth = 100; break;
        case "hardened": self.maxHealth = 120; break;
        case "veteran": self.maxHealth = 150; break;
        case "expert": self.maxHealth = 175; break;
        case "pro": self.maxHealth = 200; break;
        case "impossible": self.maxHealth = 250; break;
        default: self.maxHealth = 100; break;
    }

    self.health = self.maxHealth;
}

applyBotPrestigeSetting()
{
    mode = getPrestigeModeSafe();

    if (mode == -1)
        self setBotPrestige(getHostPrestige());
    else if (mode == -2)
        self setBotPrestige(randomInt(16));
    else
        self setBotPrestige(mode);
}

getPrestigeModeSafe()
{
    m = getDvarInt("bots_main_prestige");
    if (m < -2) m = -2;
    if (m > 15) m = 15;
    return m;
}

getHostPrestige()
{
    foreach (p in level.players)
    {
        if (!isDefined(p) || (p isBotEntity()))
            continue;

        if (isDefined(p.prestige))
            return int(p.prestige);

        if (isDefined(p.pers) && isDefined(p.pers["prestige"]))
            return int(p.pers["prestige"]);

        return 0;
    }
    return 0;
}

setBotPrestige(prestige)
{
    if (!isDefined(prestige))
        prestige = 0;

    prestige = int(prestige);
    if (prestige < 0) prestige = 0;
    if (prestige > 15) prestige = 15;

    // Safe storage path (always)
    if (!isDefined(self.pers))
        self.pers = [];
    self.pers["prestige"] = prestige;
    self.prestige = prestige;

    self.rank = int(defaultBotLevel);
    self.pers["rank"] = int(defaultBotLevel);

    // Optional risky natives behind toggles
    if (compatUseSetPrestigeNative)
        self setprestige(prestige);

    if (compatUseSetRankNative)
        self setrank(int(defaultBotLevel));
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
            + " aw=" + awStyleEnable
            + " campaign=" + campaignMode);

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
