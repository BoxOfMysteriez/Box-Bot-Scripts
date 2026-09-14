// ============================================================
// Combined Safe Coexist Script (Atlas45 + EMZ)
// - Fixes init() collision by using atlas45_init() + emz_init()
// - Single global init() calls both systems
// ============================================================

init()
{
    atlas45_init();
    emz_init();
}

// =======================
// Atlas45 Section
// =======================

atlas45_init()
{
    init_atlas45_progression();
    init_atlas45_impact_pulse();
    level.callbackPlayerDamage = ::atlas45_player_damage_hook;
}

init_atlas45_impact_pulse()
{
    if (!isDefined(level.atlas45_pulse_enabled))      level.atlas45_pulse_enabled = true;
    if (!isDefined(level.atlas45_pulse_min_mk))       level.atlas45_pulse_min_mk = 1; // MK1+
    if (!isDefined(level.atlas45_pulse_proc_chance))  level.atlas45_pulse_proc_chance = 0.30;
    if (!isDefined(level.atlas45_pulse_radius))       level.atlas45_pulse_radius = 140;
    if (!isDefined(level.atlas45_pulse_bonus_damage)) level.atlas45_pulse_bonus_damage = 35;
    if (!isDefined(level.atlas45_pulse_cooldown_ms))  level.atlas45_pulse_cooldown_ms = 500;
    if (!isDefined(level.atlas45_pulse_debug))        level.atlas45_pulse_debug = true;
}

atlas45_randf_0_1()
{
    return (randomint(10000) / 10000.0);
}

is_atlas45_weapon(weaponName)
{
    if (!isDefined(weaponName)) return false;
    w = toLower(weaponName);
    if (w == "titan45_mp") return true;
    if (w == "titan45akimbo_mp") return true;
    if (issubstr(w, "titan45")) return true;
    return false;
}

atlas45_is_zombie_ent(ent)
{
    if (!isDefined(ent)) return false;
    if (isDefined(ent.team) && toLower(ent.team) == "axis") return true;
    if (isDefined(ent.sessionteam) && toLower(ent.sessionteam) == "axis") return true;
    if (isDefined(ent.agent_type) && issubstr(toLower(ent.agent_type), "zombie")) return true;
    return false;
}

atlas45_get_zombie_array()
{
    arr = [];
    a = getentarray("actor", "classname");
    if (isDefined(a) && a.size > 0) return a;
    return arr;
}

atlas45_try_impact_pulse(victim, attacker, weaponName, hitPoint)
{
    if (!isDefined(level.atlas45_pulse_enabled) || !level.atlas45_pulse_enabled) return;
    if (!isDefined(attacker) || !isPlayer(attacker)) return;
    if (!is_atlas45_weapon(weaponName)) return;

    mk = 1;
    if (isDefined(attacker.atlas45_mk)) mk = attacker.atlas45_mk;
    if (mk < level.atlas45_pulse_min_mk) return;

    now = 0;
    if (isDefined(level.time)) now = level.time;

    last = 0;
    if (isDefined(attacker.atlas45_last_pulse_time)) last = attacker.atlas45_last_pulse_time;

    if (now - last < level.atlas45_pulse_cooldown_ms) return;
    if (atlas45_randf_0_1() > level.atlas45_pulse_proc_chance) return;

    attacker.atlas45_last_pulse_time = now;

    center = undefined;
    if (isDefined(hitPoint)) center = hitPoint;
    else if (isDefined(victim) && isDefined(victim.origin)) center = victim.origin;
    else if (isDefined(attacker.origin)) center = attacker.origin;
    else return;

    zombies = atlas45_get_zombie_array();
    if (!isDefined(zombies) || zombies.size <= 0) return;

    for (i = 0; i < zombies.size; i++)
    {
        z = zombies[i];
        if (!isDefined(z) || !isAlive(z) || !isDefined(z.origin)) continue;
        if (!atlas45_is_zombie_ent(z)) continue;

        d = distance(center, z.origin);
        if (d > level.atlas45_pulse_radius) continue;

        falloff = 1.0 - (d / level.atlas45_pulse_radius);
        if (falloff < 0.25) falloff = 0.25;

        baseBonus = int(level.atlas45_pulse_bonus_damage * falloff);
        if (baseBonus < 1) baseBonus = 1;

        mkScale = 1.0 + (0.05 * (mk - 1));
        if (mkScale > 3.0) mkScale = 3.0;

        bonus = int(baseBonus * mkScale);
        if (bonus < 1) bonus = 1;

        z DoDamage(bonus, z.origin, attacker, attacker, "none", "MOD_UNKNOWN", "", "");
    }

    if (isDefined(level.atlas45_pulse_debug) && level.atlas45_pulse_debug)
        println("[ATLAS45_PULSE] MK:" + mk + " proc");
}

atlas45_player_damage_hook(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
    dmg = iDamage;

    if (isDefined(eAttacker) && isPlayer(eAttacker) && is_atlas45_weapon(sWeapon))
    {
        if (!isDefined(eAttacker.atlas45_mk))
            atlas45_apply_progression(eAttacker, 1);

        if (isDefined(eAttacker.atlas45_damage_mul))
            dmg = int(dmg * eAttacker.atlas45_damage_mul);

        if (isDefined(sHitLoc) && isDefined(eAttacker.atlas45_crit_mul) && toLower(sHitLoc) == "head")
            dmg = int(dmg * eAttacker.atlas45_crit_mul);

        if (dmg < 1) dmg = 1;
    }

    atlas45_try_impact_pulse(self, eAttacker, sWeapon, vPoint);

    self finishPlayerDamage(
        eInflictor,
        eAttacker,
        dmg,
        iDFlags,
        sMeansOfDeath,
        sWeapon,
        vPoint,
        vDir,
        sHitLoc,
        timeOffset
    );
}

// =======================
// EMZ Section
// =======================

emz_init()
{
    level.emz_debug = true;
    level.emz_emp_range = 3.0;
    level.emz_tick = 0.25;
    level.emz_log_interval = 1.0;

    if (!isDefined(level.emz_last_log_time))
        level.emz_last_log_time = 0;

    if (!emz_should_run_here())
    {
        emz_log("init: disabled (non-zombie context)");
        return;
    }

    emz_log("init: enabled");
}

emz_should_run_here()
{
    gt = "";
    if (isDefined(level.gametype)) gt = toLower(level.gametype);

    mn = "";
    if (isDefined(level.mapname)) mn = toLower(level.mapname);

    pl = "";
    if (isDefined(level.playlist)) pl = toLower(level.playlist);

    if (emz_substr(gt, "zombie") || emz_substr(gt, "infect")) return true;
    if (emz_substr(mn, "zm_") || emz_substr(mn, "zombie")) return true;
    if (emz_substr(pl, "zombie") || emz_substr(pl, "exo")) return true;

    return false;
}

emz_substr(hay, needle)
{
    if (!isDefined(hay) || !isDefined(needle)) return false;
    return issubstr(hay, needle);
}

emz_log(msg)
{
    if (!isDefined(level.emz_debug) || !level.emz_debug) return;
    if (!isDefined(msg)) msg = "undefined";

    now = 0;
    if (isDefined(level.time)) now = level.time;

    last = 0;
    if (isDefined(level.emz_last_log_time)) last = level.emz_last_log_time;

    minGapMs = int(level.emz_log_interval * 1000.0);
    if (now - last < minGapMs) return;

    level.emz_last_log_time = now;
    println("[EMZ] " + msg);
}

zombie_spawn_init(animname_set)
{
    if (!emz_should_run_here()) return;
    if (!isDefined(self)) return;

    emz_log("zombie_spawn_init called");
    self thread emz_test_loop();
}

emz_test_loop()
{
    if (!isDefined(self)) return;

    self endon("death");
    self endon("disconnect");
    level endon("game_ended");

    for (;;)
    {
        if (!emz_should_run_here())
            return;

        if (!isDefined(level.emz_emp_range) || level.emz_emp_range <= 0)
            level.emz_emp_range = 3.0;

        if (!isDefined(level.emz_tick) || level.emz_tick < 0.05)
            level.emz_tick = 0.25;

        players = getplayers();
        if (!isDefined(players))
        {
            emz_log("getplayers undefined");
            wait(level.emz_tick);
            continue;
        }

        if (!isDefined(self.origin))
        {
            wait(level.emz_tick);
            continue;
        }

        for (i = 0; i < players.size; i++)
        {
            player = players[i];
            if (!isDefined(player)) continue;
            if (!isDefined(player.origin)) continue;

            dist = distance(self.origin, player.origin);

            if (dist <= level.emz_emp_range)
                emz_log("player within EMP range: " + dist);
        }

        wait(level.emz_tick);
    }
}