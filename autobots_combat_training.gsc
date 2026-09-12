// ============================================================
// Autobots Combat Training Script (MP-ONLY, TRIMMED)
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

// --------------------------
// Config
// --------------------------
combatTrainingForce = true;          // true = always CT target cap; false = auto-detect by map/gametype
combatTrainingMaxPlayers = 12;       // total players (humans + bots) in CT
dedicatedMaxPlayers = 18;            // total players (humans + bots) in normal MP
defaultBotDifficulty = "veteran";    // LOCKED MAX now veteran
defaultBotLevel = 55;

// AW-style knobs
awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;

// Compatibility toggles
compatUseSetPrestigeNative = false;  // set true only if title supports self setprestige(...)
compatUseSetRankNative = false;      // set true only if title supports self setrank(...)
compatUseBotDropNative = true;       // set false if bot_drop() crashes/unsupported

// Debug
debugAutobots = true;
debugVerbose = false;
debugHeartbeatInterval = 5.0;

// Performance controls
botDifficultyEnforcerInterval = 5.0;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 8;         // hard cap to avoid pathological loops if spawns are failing

// --------------------------
// Init
// --------------------------
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
    if (botDifficultyEnforcerInterval < 1.0)
        botDifficultyEnforcerInterval = 1.0;
    if (spawnFailBackoff < 0.10)
        spawnFailBackoff = 0.10;
    if (maxSpawnAttemptsPerTick < 1)
        maxSpawnAttemptsPerTick = 1;

    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    // Hard-lock to veteran no matter what config says
    defaultBotDifficulty = "veteran";

    dbg("init() MP-only combatTraining=" + level.combatTraining
        + " ctMax=" + combatTrainingMaxPlayers
        + " dedMax=" + dedicatedMaxPlayers
        + " awStyle=" + awStyleEnable
        + " defaultDiff=" + defaultBotDifficulty);

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();
}

// --------------------------
// Difficulty helpers
// --------------------------
isValidDifficulty(s)
{
    return (s == "regular"
        || s == "hardened"
        || s == "veteran");
}

normalizeDifficultyName(d)
{
    // Hard-lock normalize result to veteran
    return "veteran";
}

setBotDifficulty(difficulty)
{
    dbg("setBotDifficulty() called with difficulty=" + difficulty);

    // Defensive normalize
    d = "regular";
    if (isDefined(difficulty))
        d = toLower(difficulty);

    switch (d)
    {
        case "regular":
            self.botAccuracy = 0.60;
            self.reactionTime = 0.50;
            self.maxHealth = 100;
            self.botAggression = 0.50;
            dbg("setBotDifficulty(): REGULAR");
            break;

        case "hardened":
            self.botAccuracy = 0.90;
            self.reactionTime = 0.20;
            self.maxHealth = 150;
            self.botAggression = 0.80;
            dbg("setBotDifficulty(): HARDENED");
            break;

        case "veteran":
            self.botAccuracy = 0.98;
            self.reactionTime = 0.12;
            self.maxHealth = 200;
            self.botAggression = 0.90;
            dbg("setBotDifficulty(): VETERAN");
            break;

        default:
            // Strict mode: anything unknown falls back to veteran
            self.botAccuracy = 0.98;
            self.reactionTime = 0.12;
            self.maxHealth = 200;
            self.botAggression = 0.90;
            dbg("setBotDifficulty(): DEFAULT->VETERAN (unknown token=" + d + ")");
            break;
    }

    dbg("setBotDifficulty(): acc=" + self.botAccuracy
        + " react=" + self.reactionTime
        + " maxHp=" + self.maxHealth
        + " aggro=" + self.botAggression);

    // Optional immediate heal to new max
    if (awHealthRegenOnSpawn)
        safeFullHeal(self);
}

// --------------------------
// Utility
// --------------------------
dbg(msg)
{
    if (!debugAutobots)
        return;

    if (!isDefined(msg))
        msg = "undefined";

    if (isDefined(level) && isDefined(level.time))
        println("[AUTOBOTS][" + level.time + "] " + msg);
    else
        println("[AUTOBOTS] " + msg);
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

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle))
        return false;

    return issubstr(hay, needle);
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

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"]))
        return self.pers["isBot"];

    g = self getguid();
    if (isDefined(g))
        return isSubStr(g, "bot") || isSubStr(g, "BOT") || isSubStr(g, "Bot");

    return false;
}

safeFullHeal(ent)
{
    if (!isDefined(ent))
        return;
    if (!isDefined(ent.maxHealth))
        return;

    ent.health = ent.maxHealth;
}

// --------------------------
// Player/bot accounting
// --------------------------
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

// --------------------------
// Rank/Prestige compat
// --------------------------
setBotRankCompat(rankValue)
{
    r = int(rankValue);
    self.rank = r;

    if (!isDefined(self.pers))
        self.pers = [];
    self.pers["rank"] = r;

    if (!compatUseSetRankNative)
        return;

    self setrank(r);
}

applyBotPrestigeSetting()
{
    if (!isDefined(self.pers))
        self.pers = [];
    self.pers["prestige"] = 0;

    if (!compatUseSetPrestigeNative)
        return;

    self setprestige(0);
}

// --------------------------
// Difficulty application
// --------------------------
applyAutobotDifficulty(diff)
{
    // Ignore requested diff and force veteran
    d = "veteran";

    if (!isDefined(self.pers))
        self.pers = [];
    self.pers["autobot_diff_applied"] = d;

    // Global fallback used by many MP bot systems
    setdvar("bot_difficulty", d);

    // Per-bot stat profile
    self setBotDifficulty(d);
}

applyDifficultyToAllBots(diff, forceWritePers)
{
    // Ignore requested diff and force veteran
    d = "veteran";
    applied = 0;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity()))
            continue;

        p applyAutobotDifficulty(d);
        p setBotRankCompat(defaultBotLevel);
        p applyBotPrestigeSetting();

        if (!isDefined(p.pers))
            p.pers = [];

        if (forceWritePers || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != d)
            p.pers["autobot_diff_applied"] = d;

        if (awHealthRegenOnSpawn)
            safeFullHeal(p);

        applied++;
    }

    if (debugAutobots && debugVerbose)
        dbg("applyDifficultyToAllBots(): applied=" + applied + " diff=" + d);
}

// --------------------------
// Connect + population
// --------------------------
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
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers))
                player.pers = [];
            player.pers["autobot_diff_applied"] = "veteran";

            if (awHealthRegenOnSpawn)
                safeFullHeal(player);
        }
        else if (!level.combatTraining)
        {
            trimBotsToTarget();
        }
    }
}

spawnBotsSafe(amount)
{
    if (!isDefined(amount) || amount <= 0)
        return false;

    before = level.players.size;
    spawn_bots(amount, "autoassign");
    wait 0.05;
    after = level.players.size;

    if (after <= before)
    {
        dbg("spawnBotsSafe(): spawn_bots produced no new players");
        return false;
    }

    return true;
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

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;

    for (;;)
    {
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        if (target < 0)
            target = 0;

        attempts = 0;
        while (level.players.size < target && attempts < maxSpawnAttemptsPerTick)
        {
            attempts++;
            if (!spawnBotsSafe(1))
                wait spawnFailBackoff;
            else
                wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (attempts >= maxSpawnAttemptsPerTick && level.players.size < target && debugAutobots && debugVerbose)
            dbg("serverBotFill(): reached maxSpawnAttemptsPerTick=" + maxSpawnAttemptsPerTick);

        if (!level.combatTraining && level.players.size > target)
            trimBotsToTarget();

        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

// --------------------------
// Enforcers
// --------------------------
delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 1.0;
    applyDifficultyToAllBots("veteran", true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");

    for (;;)
    {
        applyDifficultyToAllBots("veteran", false);
        wait botDifficultyEnforcerInterval;
    }
}

liveDebugHeartbeat()
{
    level endon("game_ended");

    for (;;)
    {
        if (debugAutobots && debugVerbose)
        {
            humans = countHumans();
            bots = countBots();
            total = level.players.size;
            target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

            // Added: live dvar visibility for verification
            dbg("heartbeat total=" + total
                + " humans=" + humans
                + " bots=" + bots
                + " target=" + target
                + " ct=" + level.combatTraining
                + " diff=" + defaultBotDifficulty
                + " dvar(bot_difficulty)=" + getdvar("bot_difficulty"));
        }

        wait debugHeartbeatInterval;
    }
}
