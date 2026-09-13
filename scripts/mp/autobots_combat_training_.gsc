// ============================================================
// Autobots Combat Training Script (MP-ONLY, HARDENED v5)
// - Forces locked difficulty to ULTRA
// - Fixes persistence by normalizing + enforcing dvar + per-bot state
// ============================================================
#include scripts/mp/_bots;

// --------------------------
// Config
// --------------------------
combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;

// FORCE ULTRA
defaultBotDifficulty = "ultra";
lockedBotDifficulty  = "ultra";

defaultBotLevel = 50;
defaultBotPrestige = 23;

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

botDifficultyEnforcerInterval = 2.0;
spawnFailBackoff = 0.50;
maxSpawnAttemptsPerTick = 8;

sanityTestEnable = true;
sanityTestDuration = 60.0;
sanityTestSampleInterval = 5.0;

// v2 counting controls
countSpectatorsAsPlayers = false;
countConnectingAsPlayers = false;

// v3 hardening controls
strictBotIdentityMode = true;
spawnConfirmPhase1Delay = 0.05;
spawnConfirmPhase2Delay = 0.10;
spawnConfirmPhase3Delay = 0.20;
trimSafetyMaxDrops = 32;
countStateLogUnknownOnce = true;

// --------------------------
// Atlas 45 upgrade-safe buff
// --------------------------
atlas45EnableBuff = true;
atlas45BaseId = "iw5_44magnum_mp";
atlas45Upg1Id = "iw5_44magnum_mp_upgraded";
atlas45Upg2Id = "iw5_44magnum_mp_upgraded2";
atlas45BaseMult = 1.20;
atlas45Upg1Mult = 1.45;
atlas45Upg2Mult = 1.75;
atlas45MonitorInterval = 0.25;

// --------------------------
// Init
// --------------------------
init()
{
    if (!shouldRunAutobotsHere())
    {
        dbg("init(): disabled for this mode/map (Exo Survival/Exo Zombies or non-MP context)");
        return;
    }

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
    if (defaultBotPrestige < 0) defaultBotPrestige = 0;
    if (spawnConfirmPhase1Delay < 0.01) spawnConfirmPhase1Delay = 0.01;
    if (spawnConfirmPhase2Delay < 0.01) spawnConfirmPhase2Delay = 0.01;
    if (spawnConfirmPhase3Delay < 0.01) spawnConfirmPhase3Delay = 0.01;
    if (trimSafetyMaxDrops < 1) trimSafetyMaxDrops = 1;
    if (atlas45MonitorInterval < 0.05) atlas45MonitorInterval = 0.05;

    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;

    if (!combatTrainingForce) level.combatTraining = detectCombatTraining();
    else level.combatTraining = true;

    lockedBotDifficulty = "ultra";
    defaultBotDifficulty = "ultra";
    setdvar("bot_difficulty", "ultra");

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread liveDebugHeartbeat();
    level thread delayedBotDifficultyApply();
    level thread botDifficultyEnforcer();
    level thread atlas45GlobalMonitor();

    if (sanityTestEnable) level thread run60SecondSanityTest();
}

shouldRunAutobotsHere()
{
    if (isDefined(level.mapname))
    {
        mn = toLower(level.mapname);
        if (isSubStr(mn, "exo survival") || isSubStr(mn, "exo zombies")) return false;
        if (isSubStr(mn, "cp_") || isSubStr(mn, "survival")) return false;
        if (isSubStr(mn, "zm_") || isSubStr(mn, "zombies")) return false;
    }

    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);
    if (isSubStr(gt, "survival") || isSubStr(gt, "zombie") || isSubStr(gt, "infect")) return false;

    if (isDefined(level.playlist))
    {
        pl = toLower(level.playlist);
        if (isSubStr(pl, "survival") || isSubStr(pl, "zombie") || isSubStr(pl, "exo")) return false;
    }

    return true;
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

dbg(msg)
{
    if (!debugAutobots) return;
    if (!isDefined(msg)) msg = "undefined";
    if (isDefined(level) && isDefined(level.time)) println("[AUTOBOTS][" + level.time + "] " + msg);
    else println("[AUTOBOTS] " + msg);
}

warnOnce(key, msg)
{
    if (!debugAutobots) return;
    if (!isDefined(level.autobotsWarnOnce)) level.autobotsWarnOnce = [];
    if (!isDefined(key)) key = "unknown_key";
    if (isDefined(level.autobotsWarnOnce[key])) return;
    level.autobotsWarnOnce[key] = true;
    dbg("WARN_ONCE " + key + ": " + msg);
}

safeGetGuid(ent)
{
    if (!isDefined(ent)) return "unknown";
    g = ent getguid();
    if (!isDefined(g) || g == "") return "unknown";
    return g;
}

isBotEntity()
{
    if (isDefined(self.pers) && isDefined(self.pers["isBot"])) return self.pers["isBot"];

    guidFallback = safeGetGuid(self);
    warnOnce("isBot_missing_" + guidFallback, "pers[\"isBot\"] missing for guid=" + guidFallback + "; using fallback checks");

    g = self getguid();
    if (isDefined(g))
    {
        gl = toLower(g);
        if (isSubStr(gl, "bot")) return true;
    }

    if (!strictBotIdentityMode && isDefined(self.name))
    {
        nl = toLower(self.name);
        if (isSubStr(nl, "bot ")) return true;
        if (isSubStr(nl, "[bot]")) return true;
    }

    return false;
}

safeFullHeal(ent)
{
    if (!isDefined(ent) || !isDefined(ent.maxHealth) || !isDefined(ent.health)) return;
    ent.health = ent.maxHealth;
}

setBotDifficulty(difficulty)
{
    self.botAccuracy = 2.75;
    self.reactionTime = 0.01;
    self.maxHealth = 650;
    self.botAggression = 2.75;
    if (awHealthRegenOnSpawn) safeFullHeal(self);
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

    if (isDefined(ent.pers["autobot_loadout_sig"]) && ent.pers["autobot_loadout_sig"] == desiredSig) return;

    ent takeallweapons();

    if (primaryToGive != "")
    {
        ent giveweapon(primaryToGive);
        ent switchtoweapon(primaryToGive);
        if (opGiveFullAmmo)
        {
            ent givemaxammo(primaryToGive);
            if (primaryToGive != opPrimaryWeapon) ent givemaxammo(opPrimaryWeapon);
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
}

isPlayerCountable(ent)
{
    if (!isDefined(ent)) return false;

    if (!countSpectatorsAsPlayers && isDefined(ent.sessionstate))
    {
        st = toLower(ent.sessionstate);
        if (st == "spectator" || st == "intermission") return false;
    }

    if (!countConnectingAsPlayers && isDefined(ent.pers) && isDefined(ent.pers["connected"]))
    {
        c = toLower(ent.pers["connected"]);
        if (c != "connected") return false;
    }

    return true;
}

countTotalPlayersForCap()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isPlayerCountable(p)) n++;
    return n;
}

countBots()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isDefined(p) && (p isBotEntity())) n++;
    return n;
}

countHumans()
{
    if (!isDefined(level.players)) return 0;
    n = 0; foreach (p in level.players) if (isDefined(p) && !(p isBotEntity())) n++;
    return n;
}

setBotRankCompat(rankValue)
{
    r = int(rankValue);
    self.rank = r;
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["rank"] = r;
    if (compatUseSetRankNative) self setrank(r);
}

applyBotPrestigeSetting()
{
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["prestige"] = defaultBotPrestige;
    if (compatUseSetPrestigeNative) self setprestige(defaultBotPrestige);
}

applyAutobotDifficulty(diff)
{
    if (!isDefined(self.pers)) self.pers = [];
    self.pers["autobot_diff_applied"] = "ultra";
    self setBotDifficulty("ultra");
    applyOpLoadout(self);
    atlas45ApplyTierBuff(self, atlas45GetCurrentWeaponSafe(self));
}

applyDifficultyToAllBots(forceWritePers)
{
    if (getdvar("bot_difficulty") != "ultra") setdvar("bot_difficulty", "ultra");
    if (!isDefined(level.players)) return;

    foreach (p in level.players)
    {
        if (!isDefined(p) || !(p isBotEntity())) continue;

        needsApply = true;
        if (isDefined(p.pers) && isDefined(p.pers["autobot_diff_applied"]) && p.pers["autobot_diff_applied"] == "ultra" && !forceWritePers)
            needsApply = false;

        if (needsApply)
        {
            p applyAutobotDifficulty("ultra");
            p setBotRankCompat(defaultBotLevel);
            p applyBotPrestigeSetting();

            if (!isDefined(p.pers)) p.pers = [];
            p.pers["autobot_diff_applied"] = "ultra";
            if (awHealthRegenOnSpawn) safeFullHeal(p);
        }
    }
}

onPlayerConnect()
{
    level endon("game_ended");
    for (;;)
    {
        level waittill("connected", player);
        if (!isDefined(player)) continue;

        if (player isBotEntity())
        {
            player applyAutobotDifficulty("ultra");
            player setBotRankCompat(defaultBotLevel);
            player applyBotPrestigeSetting();

            if (!isDefined(player.pers)) player.pers = [];
            player.pers["autobot_diff_applied"] = "ultra";

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

    wait spawnConfirmPhase1Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase2Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    wait spawnConfirmPhase3Delay;
    if (countTotalPlayersForCap() > beforePlayers || countBots() > beforeBots) return true;

    return false;
}

pickBotForDrop()
{
    bots = [];
    if (!isDefined(level.players)) return undefined;

    foreach (p in level.players)
        if (isDefined(p) && (p isBotEntity()))
            bots[bots.size] = p;

    if (bots.size <= 0) return undefined;
    return bots[randomint(bots.size)];
}

kickOneBot()
{
    p = pickBotForDrop();
    if (!isDefined(p)) return false;
    if (!compatUseBotDropNative) return false;
    p bot_drop();
    return true;
}

trimBotsToTarget()
{
    if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;

    hadLock = level.autobotAdjusting;
    if (!hadLock) level.autobotAdjusting = true;

    target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
    if (target < 0) target = 0;

    safety = trimSafetyMaxDrops;
    while (countTotalPlayersForCap() > target && countBots() > 0 && safety > 0)
    {
        if (!kickOneBot()) break;
        safety--;
        wait (awStyleEnable ? awTrimDelay : 0.05);
    }

    if (!hadLock) level.autobotAdjusting = false;
}

serverBotFill()
{
    level endon("game_ended");
    wait 0.05;

    for (;;)
    {
        if (!isDefined(level.autobotAdjusting)) level.autobotAdjusting = false;
        if (level.autobotAdjusting) { wait 0.10; continue; }
        level.autobotAdjusting = true;

        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        if (target < 0) target = 0;

        attempts = 0;
        while (countTotalPlayersForCap() < target && attempts < maxSpawnAttemptsPerTick)
        {
            if (countTotalPlayersForCap() >= target) break;
            attempts++;
            if (!spawnBotsSafe(1)) wait spawnFailBackoff;
            else wait (awStyleEnable ? awPressureSpawnDelay : 0.25);
        }

        if (!level.combatTraining && countTotalPlayersForCap() > target)
            trimBotsToTarget();

        level.autobotAdjusting = false;
        wait (awStyleEnable ? 0.15 : 0.25);
    }
}

delayedBotDifficultyApply()
{
    level endon("game_ended");
    wait 0.5;
    setdvar("bot_difficulty", "ultra");
    applyDifficultyToAllBots(true);
}

botDifficultyEnforcer()
{
    level endon("game_ended");
    for (;;)
    {
        if (getdvar("bot_difficulty") != "ultra")
            setdvar("bot_difficulty", "ultra");

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
            target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
            dbg("heartbeat totalCap=" + countTotalPlayersForCap()
                + " totalRaw=" + (isDefined(level.players) ? level.players.size : 0)
                + " humans=" + countHumans()
                + " bots=" + countBots()
                + " target=" + target
                + " ct=" + level.combatTraining
                + " diff=ultra"
                + " dvar(bot_difficulty)=" + getdvar("bot_difficulty"));
        }
        wait debugHeartbeatInterval;
    }
}

run60SecondSanityTest()
{
    level endon("game_ended");
    if (!debugAutobots) return;

    expected = "ultra";
    startTime = 0;
    if (isDefined(level.time)) startTime = level.time;

    samples = 0;
    dvarFailures = 0;
    overTargetFailures = 0;
    anyBotsSeen = false;
    badBotDiffSeen = 0;
    maxOvershoot = 0;
    spawnSuccessStreak = 0;
    spawnFailStreak = 0;

    for (;;)
    {
        elapsed = 0.0;
        if (isDefined(level.time)) elapsed = (level.time - startTime) / 1000.0;
        if (elapsed >= sanityTestDuration) break;

        total = countTotalPlayersForCap();
        bots = countBots();
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;
        dvarNow = getdvar("bot_difficulty");

        if (bots > 0) anyBotsSeen = true;
        if (dvarNow != expected) dvarFailures++;
        if (!level.combatTraining && total > target) overTargetFailures++;

        overshoot = total - target;
        if (overshoot > maxOvershoot) maxOvershoot = overshoot;

        if (total < target) spawnFailStreak++; else spawnFailStreak = 0;
        if (total >= target) spawnSuccessStreak++; else spawnSuccessStreak = 0;

        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p) || !(p isBotEntity())) continue;
                if (!isDefined(p.pers) || !isDefined(p.pers["autobot_diff_applied"]) || p.pers["autobot_diff_applied"] != expected)
                    badBotDiffSeen++;
            }
        }

        samples++;
        wait sanityTestSampleInterval;
    }

    dbg("SANITY end samples=" + samples
        + " dvarFailures=" + dvarFailures
        + " overTargetFailures=" + overTargetFailures
        + " anyBotsSeen=" + anyBotsSeen
        + " badBotDiffSeen=" + badBotDiffSeen
        + " maxOvershoot=" + maxOvershoot
        + " spawnSuccessStreak=" + spawnSuccessStreak
        + " spawnFailStreak=" + spawnFailStreak);
}

// =========================
// Atlas 45 upgrade-safe buff
// =========================
atlas45GlobalMonitor()
{
    level endon("game_ended");

    for (;;)
    {
        if (isDefined(level.players))
        {
            foreach (p in level.players)
            {
                if (!isDefined(p)) continue;
                if (!(p isBotEntity())) continue;

                if (!isDefined(p.pers)) p.pers = [];

                if (!isDefined(p.pers["atlas45_monitor_started"]) || !p.pers["atlas45_monitor_started"])
                {
                    p.pers["atlas45_monitor_started"] = true;
                    p thread atlas45EntityMonitor();
                }
            }
        }

        wait 1.0;
    }
}

atlas45EntityMonitor()
{
    self endon("death");
    self endon("disconnect");
    level endon("game_ended");

    if (!isDefined(self.pers)) self.pers = [];
    self.pers["atlas45_last_weapon"] = "";

    for (;;)
    {
        if (!atlas45EnableBuff) { wait atlas45MonitorInterval; continue; }

        w = atlas45GetCurrentWeaponSafe(self);
        if (!isDefined(w)) w = "";
        w = toLower(w);

        last = "";
        if (isDefined(self.pers["atlas45_last_weapon"])) last = self.pers["atlas45_last_weapon"];

        if (w != last)
        {
            self.pers["atlas45_last_weapon"] = w;
            atlas45ApplyTierBuff(self, w);
        }

        wait atlas45MonitorInterval;
    }
}

atlas45GetCurrentWeaponSafe(ent)
{
    if (!isDefined(ent)) return "";
    cw = ent getcurrentweapon();
    if (!isDefined(cw)) return "";
    return cw;
}

atlas45ApplyTierBuff(ent, currentWeapon)
{
    if (!isDefined(ent)) return;
    if (!isDefined(ent.pers)) ent.pers = [];

    w = toLower(currentWeapon);
    mult = 1.0;

    if (w == toLower(atlas45Upg2Id)) mult = atlas45Upg2Mult;
    else if (w == toLower(atlas45Upg1Id)) mult = atlas45Upg1Mult;
    else if (w == toLower(atlas45BaseId)) mult = atlas45BaseMult;

    ent.pers["weapon_damage_mult_" + atlas45BaseId] = 1.0;
    ent.pers["weapon_damage_mult_" + atlas45Upg1Id] = 1.0;
    ent.pers["weapon_damage_mult_" + atlas45Upg2Id] = 1.0;

    if (mult > 1.0)
    {
        ent.pers["weapon_damage_mult_" + atlas45BaseId] = mult;
        ent.pers["weapon_damage_mult_" + atlas45Upg1Id] = mult;
        ent.pers["weapon_damage_mult_" + atlas45Upg2Id] = mult;
        ent.pers["atlas45_damage_mult_active"] = mult;
    }
    else
    {
        ent.pers["atlas45_damage_mult_active"] = 1.0;
    }
}