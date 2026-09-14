// ============================================================
// EMZ Safe Coexist Script
// - Designed to coexist with MP autobots scripts
// - Only runs in zombie/exo-zombie contexts
// - Throttled debug output
// ============================================================

init()
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
    if (isDefined(level.gametype))
        gt = toLower(level.gametype);

    mn = "";
    if (isDefined(level.mapname))
        mn = toLower(level.mapname);

    pl = "";
    if (isDefined(level.playlist))
        pl = toLower(level.playlist);

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