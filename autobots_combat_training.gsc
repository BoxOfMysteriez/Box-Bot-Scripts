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
combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;
defaultBotDifficulty = "godlike";
defaultBotLevel = 55;
lockedBotDifficulty = "godlike";   // regular | hardened | veteran | nightmare | impossible | godlike | legendary

awStyleEnable = true;
awPressureSpawnDelay = 0.15;
awTrimDelay = 0.03;
awHealthRegenOnSpawn = true;

opWeaponsEnable = true;
opPrimaryWeapon = "iw5_m4_mp";
opPrimaryAttachment = "reflex";
opSecondaryWeapon = "iw5_44magnum_mp";
opLethal = "frag_grenade_mp";
opTactical = "flash_grenade_mp";
opGiveFullAmmo = true;

compatUseSetPrestigeNative = false;
compatUseSetRankNative = false;
compatUseBotDropNative = true;

debugAutobots = true;
debugVerbose = false;
debugHeartbeatInterval = 5.0;

botDifficultyEnforcerInterval = 5.0;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 8;

sanityTestEnable = true;
sanityTestDuration = 60.0;
sanityTestSampleInterval = 5.0;

// v2 counting controls
countSpectatorsAsPlayers = false;
countConnectingAsPlayers = false;

// --------------------------
// Init
// --------------------------
init()
{
    if (combatTrainingMaxPlayers < 0) combatTrainingMaxPlayers = 0;
    if (dedicatedMaxPlayers < 0) dedicatedMaxPlayers = 0;
    if (awPressureSpawnDelay < 0.05) awPressureSpawnDelay = 0.05;
    if (awTrimDelay < 0.01) awTrimDelay = 0.01;
    if (debugHeartbeatInterval < 0.2) debugHeartbeatInterval = 0.2;
    if (botDifficultyEnforcerInterval < 1.0) botDifficultyEnforcerInterval = 1.0;
    if (spawnFailBackoff < 0.10) spawnFailBackoff = 0.10;
    if (maxSpawnAttemptsPerTick < 1) maxSpawnAttemptsPerTick = 1;
    if (sanityTestDuration < 5.0) sanityTestDuration = 5.0;
    if (sanityTestSampleInterval < 1.0) sanityTestSampleInterval = 1.0;

    if (!combatTrainingForce) level.combatTraining = detectCombatTraining();
    else level.combatTraining = true;

    lockedBotDifficulty = normalizeDifficultyName(lockedBotDifficulty);
    defaultBotDifficulty = normalizeDifficultyName(defaultBotDifficulty);
    setdvar("bot_difficulty", lockedBotDifficulty);

    dbg("init() ct=" + level.combatTraining + " ctMax=" + combatTrainingMaxPlayers + " dedMax=" + dedicatedMaxPlayers + " lock=" + lockedBotDifficulty);

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();

    if (sanityTestEnable) level thread run60SecondSanityTest();
}

// --------------------------
// Difficulty
// --------------------------
isValidDifficulty(s)
{
    return (s == "regular"
        || s == "hardened"
        || s == "veteran"
        || s == "nightmare"
        || s == "impossible"
        || s == "godlike"
        || s == "legendary");
}

normalizeDifficultyName(diff)
{
    if (!isDefined(diff))
        diff = "veteran";

    diff = toLower(diff);
    if (!isValidDifficulty(diff))
        diff = "veteran";

    return diff;
}

setBotDifficulty(difficulty)
{
    if (!isDefined(difficulty))
        difficulty = "undefined";

    lockDiff = normalizeDifficultyName(difficulty);
    dbg("setBotDifficulty(): forcing " + lockDiff + " (requested=" + difficulty + ")");

    switch (lockDiff)
    {
        case "legendary":
            self.botAccuracy = 2.35;
            self.reactionTime = 0.02;
            self.maxHealth = 500;
            self.botAggression = 2.35;
            break;

        case "godlike":
            self.botAccuracy = 2.00;
            self.reactionTime = 0.03;
            self.maxHealth = 400;
            self.botAggression = 2.00;
            break;

        case "impossible":
            self.botAccuracy = 1.50;
            self.reactionTime = 0.05;
            self.maxHealth = 300;
            self.botAggression = 1.50;
            break;

        case "nightmare":
            self.botAccuracy = 1.25;
            self.reactionTime = 0.10;
            self.maxHealth = 250;
            self.botAggression = 1.25;
            break;

        case "hardened":
            self.botAccuracy = 1.10;
            self.reactionTime = 0.16;
            self.maxHealth = 220;
            self.botAggression = 1.10;
            break;

        case "regular":
            self.botAccuracy = 0.90;
            self.reactionTime = 0.24;
            self.maxHealth = 180;
            self.botAggression = 0.90;
            break;

        case "veteran":
        default:
            self.botAccuracy = 1.00;
            self.reactionTime = 0.20;
            self.maxHealth = 200;
            self.botAggression = 1.00;
            break;
    }

    if (awHealthRegenOnSpawn)
        safeFullHeal(self);
}

// --------------------------
// Utility
// --------------------------
dbg(msg)
{
    if (!debugAutobots) return;
    if (!isDefined(msg)) msg = "undefined";
    if (isDefined(level) && isDefined(level.time)) println("[AUTOBOTS][" + level.time + "] " + msg);
    else println("[AUTOBOTS] " + msg);
}

sanity(msg)
{
    if (!debugAutobots) return;
    if (!isDefined(msg)) msg = "undefined";
    if (isDefined(level) && isDefined(level.time)) println("[AUTOBOTS][SANITY][" + level.time + "] " + msg);
    else println("[AUTOBOTS][SANITY] " + msg);
}

safeGetGuid(ent)
{
    if (!isDefined(ent)) return "unknown";
    g = ent getguid();
    if (!isDefined(g) || g == "") return "unknown";
    return g;
}

isSubStr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
}

detectCombatTraining()
{
    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isSubStr(gt, "combat") || isSubStr(gt, "training")) return true;

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);
    if (isSubStr(mn, "combat") || isSubStr(mn, "training")) return true;

    return false;
}

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"]))
        return self.pers["isBot"];

    g = self getguid();
    if (isDefined(g))
    {
        gl = toLower(g);
        if (isSubStr(gl, "bot"))
            return true;
    }

    if (isDefined(self.name))
    {
        nl = toLower(self.name);
        if (isSubStr(nl, "bot "))
            return true;
        if (isSubStr(nl, "[bot]"))
            return true;
    }

    return false;
}

safeFullHeal(ent)
{
    if (!isDefined(ent)) return;
    if (!isDefined(ent.maxHealth)) return;
    if (!isDefined(ent.health)) return;
    ent.health = ent.maxHealth;
}

hasWeaponSafe(ent, weap)
{
    // Compatibility-safe: avoid engine-specific calls like `hasweapon`
    // that may not exist on some runtimes.
    if (!isDefined(ent) || !isDefined(weap) || weap == "")
        return false;

    // Unknown inventory API on this build -> force conservative reapply path.
    return false;
}

applyOpLoadout(ent)
{
    if (!opWeaponsEnable || !isDefined(ent)) return;

    if (!isDefined(ent.pers)) ent.pers = [];

    desiredSig = opPrimaryWeapon + "|" + opPrimaryAttachment + "|" + opSecondaryWeapon + "|" + opLethal + "|" + opTactical;

    primaryToGive = "";
    if (isDefined(opPrimaryWeapon) && opPrimaryWeapon != "")
    {
        primaryToGive = opPrimaryWeapon;
        if (isDefined(opPrimaryAttachment) && opPrimaryAttachment != "")
            primaryToGive = opPrimaryWeapon + "_" + opPrimaryAttachment;
    }

    // Compat mode: trust signature and skip reapply.
    if (isDefined(ent.pers["autobot_loadout_sig"]) && ent.pers["autobot_loadout_sig"] == desiredSig)
        return;

    ent takeallweapons();

    primaryToSwitch = "";
    if (primaryToGive != "")
    {
        ent giveweapon(primaryToGive);
        primaryToSwitch = primaryToGive;
        ent switchtoweapon(primaryToSwitch);

        if (opGiveFullAmmo)
        {
            ent givemaxammo(primaryToGive);
            if (primaryToGive != opPrimaryWeapon)
                ent givemaxammo(opPrimaryWeapon);
        }
    }

    if (isDefined(opSecondaryWeapon) && opSecondaryWeapon != "")
    {
        ent giveweapon(opSecondaryWeapon);
        if (opGiveFullAmmo) ent givemaxammo(opSecondaryWeapon);
    }

    if (isDefined(opLethal) && opLethal != "") ent giveweapon(opLethal);
    if (isDefined(opTactical) && opTactical != "") ent giveweapon(opTactical);

    ent.pers["autobot_loadout_sig"] = desiredSig;
    dbg("applyOpLoadout(): applied to guid=" + safeGetGuid(ent) + " sig=" + desiredSig);
}

isPlayerCountable(ent)
{
    if (!isDefined(ent)) return false;

    if (!countSpectatorsAsPlayers && isDefined(ent.sessionstate))
    {
        st = toLower(ent.sessionstate);
        if (st == "spectator" || st == "intermission")
            return false;
    }

    if (!countConnectingAsPlayers && isDefined(ent.pers) && isDefined(ent.pers["connected"]))
    {
        c = toLower(ent.pers["connected"]);
        if (c != "connected")
            return false;
    }

    return true;
}

countTotalPlayersForCap()
{
    n = 0;
    foreach (p in level.players)
        if (isPlayerCountable(p)) n++;
    return n;
}

// --------------------------
// Accounting
// --------------------------
countBots()
{
    n = 0;
    foreach (p in level.players)
        if (isDefined(p) && (p isBotEntity())) n++;
    return n;
}

countHumans()
{
    n = 0;
    foreach (p in level.players)
        if (isDefined(p) && !(p isBotEntity())) n++;
    return n;
}

// --------------------------
// Rank/Prestige compat
// --------------------------
setBotRankCompat(rankValue)
{
    r = int(rankValue);
    self.rank = r;

    if (!isDefined(self.pers)) self.pers = [];
    self.pers["rank"] = r;

    if (!compatUseSetRankNative) return;
    self setrank(r);
}

applyBotPrestigeSetting()
{
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["prestige"] = 23;

    if (!compatUseSetPrestigeNative) return;
    self setprestige(23);
}

// --------------------------
// Difficulty application
// --------------------------
applyAutobotDifficulty(diff)
{
    if (!isDefined(self.pers)) self.pers = [];
    applied = normalizeDifficultyName(diff);
    self.pers["autobot_diff_applied"] = applied;

    self setBotDifficulty(applied);
    applyOpLoadout(self);
}

applyDifficultyToAllBots(forceWritePers)
{
    appliedCount = 0;
    expected = normalizeDifficultyName(lockedBotDifficulty);

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        p applyAutobotDifficulty(expected);
        p setBotRankCompat(defaultBotLevel);
        p applyBotPrestigeSetting();

        if (!isDefined(p.pers)) p.pers = [];
        if (forceWritePers || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != expected)
            p.pers["autobot_diff_applied"] = expected;

        if (awHealthRegenOnSpawn) safeFullHeal(p);
        appliedCount++;
    }

    if (debugAutobots && debugVerbose)
        dbg("applyDifficultyToAllBots(): applied=" + appliedCount + " diff=" + expected);
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
        if (!isDefined(player)) continue;

        guid = safeGetGuid(player);
        bot = player isBotEntity();
        dbg("connected guid=" + guid + " isBot=" + bot);

        if (bot)
        {
            player applyAutobotDifficulty(lockedBotDifficulty);
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers)) player.pers = [];
            player.pers["autobot_diff_applied"] = normalizeDifficultyName(lockedBotDifficulty);

            if (awHealthRegenOnSpawn) safeFullHeal(player);
        }
        else if (!level.combatTraining)
        {
            trimBotsToTarget();
        }
    }
}

spawnBotsSafe(amount)
{
    if (!isDefined(amount) || amount <= 0) return false;

    beforePlayers = countTotalPlayersForCap();
    beforeBots = countBots();

    spawn_bots(amount, "autoassign");
    wait 0.05;

    afterPlayers = countTotalPlayersForCap();
    afterBots = countBots();

    if (afterPlayers <= beforePlayers && afterBots <= beforeBots)
    {
        wait 0.10;
        afterPlayers2 = countTotalPlayersForCap();
        afterBots2 = countBots();
        if (afterPlayers2 <= beforePlayers && afterBots2 <= beforeBots)
        {
            dbg("spawnBotsSafe(): spawn_bots produced no net growth");
            return false;
        }
    }

    return true;
}

pickBotForDrop()
{
    bots = [];
    foreach (p in level.players)
    {
        if (isDefined(p) && (p isBotEntity()))
            bots[bots.size] = p;
    }

    if (bots.size <= 0) return undefined;
    idx = randomint(bots.size);
    return bots[idx];
}

kickOneBot()
{
    p = pickBotForDrop();
    if (!isDefined(p)) return false;

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

trimBotsToTarget()
{
    target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
    if (target < 0) target = 0;

    safety = 32;
    while (countTotalPlayersForCap() > target && countBots() > 0 && safety > 0)
    {
        if (!kickOneBot()) break;
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
        if (target < 0) target = 0;

        attempts = 0;
        while (countTotalPlayersForCap() < target && attempts < maxSpawnAttemptsPerTick)
        {
            if (level.players.size >= target)
                break;

            attempts++;
            if (!spawnBotsSafe(1)) wait spawnFailBackoff;
            else wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (attempts >= maxSpawnAttemptsPerTick && countTotalPlayersForCap() < target && debugAutobots && debugVerbose)
            dbg("serverBotFill(): reached maxSpawnAttemptsPerTick=" + maxSpawnAttemptsPerTick);

        if (!level.combatTraining && countTotalPlayersForCap() > target)
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
    applyDifficultyToAllBots(true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");

    for (;;)
    {
        setdvar("bot_difficulty", normalizeDifficultyName(lockedBotDifficulty));
        applyDifficultyToAllBots(false);
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
            totalCap = countTotalPlayersForCap();
            totalRaw = level.players.size;
            target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

            dbg("heartbeat totalCap=" + totalCap
                + " totalRaw=" + totalRaw
                + " humans=" + humans
                + " bots=" + bots
                + " target=" + target
                + " ct=" + level.combatTraining
                + " diff=" + normalizeDifficultyName(lockedBotDifficulty)
                + " dvar(bot_difficulty)=" + getdvar("bot_difficulty"));
        }

        wait debugHeartbeatInterval;
    }
}

// --------------------------
// 60-second sanity test
// --------------------------
run60SecondSanityTest()
{
    level endon("game_ended");
    sanity("BEGIN 60s sanity test");

    expected = normalizeDifficultyName(lockedBotDifficulty);

    if (defaultBotDifficulty == expected)
        sanity("PASS defaultBotDifficulty=" + expected);
    else
        sanity("WARN defaultBotDifficulty=" + defaultBotDifficulty + " (expected " + expected + ")");

    if (getdvar("bot_difficulty") == expected)
        sanity("PASS dvar(bot_difficulty)=" + expected + " at start");
    else
        sanity("WARN dvar(bot_difficulty)=" + getdvar("bot_difficulty") + " at start");

    startTime = 0;
    if (isDefined(level.time)) startTime = level.time;

    samples = 0;
    dvarFailures = 0;
    overTargetFailures = 0;
    anyBotsSeen = false;
    badBotDiffSeen = 0;

    for (;;)
    {
        elapsed = 0.0;
        if (isDefined(level.time)) elapsed = (level.time - startTime) / 1000.0;
        if (elapsed >= sanityTestDuration) break;

        total = countTotalPlayersForCap();
        totalRaw = level.players.size;
        bots = countBots();
        humans = countHumans();
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        dvarNow = getdvar("bot_difficulty");

        if (bots > 0) anyBotsSeen = true;
        if (dvarNow != expected) dvarFailures++;

        if (!level.combatTraining && total > target) overTargetFailures++;

        foreach (p in level.players)
        {
            if (!isDefined(p) || !(p isBotEntity())) continue;
            if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != expected)
                badBotDiffSeen++;
        }

        sanity("sample=" + samples
            + " elapsed=" + elapsed
            + " totalCap=" + total
            + " totalRaw=" + totalRaw
            + " humans=" + humans
            + " bots=" + bots
            + " target=" + target
            + " ct=" + level.combatTraining
            + " dvar=" + dvarNow);

        samples++;
        wait sanityTestSampleInterval;
    }

    if (dvarFailures == 0) sanity("PASS dvar(bot_difficulty) stayed " + expected);
    else sanity("WARN dvar(bot_difficulty) drifted " + dvarFailures + " sample(s)");

    if (!level.combatTraining)
    {
        if (overTargetFailures == 0) sanity("PASS non-CT population stayed <= target");
        else sanity("WARN non-CT population exceeded target in " + overTargetFailures + " sample(s)");
    }
    else
    {
        sanity("INFO CT mode: over-target sample warning suppressed");
    }

    if (!anyBotsSeen) sanity("WARN no bots observed during test window");
    else sanity("PASS bots observed during test window");

    if (badBotDiffSeen == 0) sanity("PASS bot pers difficulty token remained " + expected);
    else sanity("WARN bot pers difficulty token mismatches observed=" + badBotDiffSeen);

    sanity("END 60s sanity test");
}
