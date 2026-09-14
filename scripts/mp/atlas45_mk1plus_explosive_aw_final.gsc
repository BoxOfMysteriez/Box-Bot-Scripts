#include common_scripts\utility;
#include common_scripts\weapons;

/*
=================================================
ATLAS 45 (MK1+ EXPLOSIVE) - AW HARDENED MP FINAL
- Mk1+ always explosive
- Queue-based fire requests (no overwrite race)
- No level.host dependency
- No notify payload dependency
- Virtual projectile (no script_model collision dependency)
- Correct AW DoDamage order
=================================================
*/

#define MAX_UPGRADE_LEVEL 25

#define PROJ_SPEED 1700.0
#define PROJ_LIFETIME 3.0
#define FIRE_COOLDOWN 0.14
#define STEP_DT 0.03

#define BASE_INNER_DAMAGE 220
#define UPGRADE_DAMAGE_SCALER 12
#define SPLASH_RADIUS 220.0
#define INNER_RADIUS 90.0

#define SELF_DAMAGE_SCALE 1.0

#define ATLAS45_DEBUG 0

atlas45_dbg( msg )
{
    if ( ATLAS45_DEBUG )
        iprintln( "^3[ATLAS45]^7 " + msg );
}

init()
{
    level endon( "game_ended" );

    if ( !isdefined(level.atlas45_initialized) )
    {
        level.atlas45_initialized = true;
        level.atlas45_q_head = 0;
        level.atlas45_q_tail = 0;
        level thread atlas45_fire_listener();
        atlas45_dbg( "queue listener started" );
    }
}

/*
Call from weapon fire event:
fire_atlas45( upgrade_level, player );
*/
fire_atlas45( upgrade_level, player )
{
    if ( !isdefined(player) || !is_alive(player) )
        return;

    upgrade_level = clamp( upgrade_level, 1, MAX_UPGRADE_LEVEL );

    atlas45_queue_push( player, upgrade_level );
    level notify( "atlas45_fire_request" );
}

/* ---------------- Queue ---------------- */

atlas45_queue_push( player, upgrade_level )
{
    if ( !isdefined(level.atlas45_q_head) ) level.atlas45_q_head = 0;
    if ( !isdefined(level.atlas45_q_tail) ) level.atlas45_q_tail = 0;

    idx = level.atlas45_q_tail;

    level.atlas45_q_player[idx] = player;
    level.atlas45_q_level[idx] = upgrade_level;

    level.atlas45_q_tail = idx + 1;

    if ( level.atlas45_q_tail > 1000000 && level.atlas45_q_head >= level.atlas45_q_tail )
    {
        level.atlas45_q_head = 0;
        level.atlas45_q_tail = 0;
    }
}

atlas45_queue_has_items()
{
    if ( !isdefined(level.atlas45_q_head) || !isdefined(level.atlas45_q_tail) )
        return false;

    return level.atlas45_q_head < level.atlas45_q_tail;
}

atlas45_queue_pop_player()
{
    return level.atlas45_q_player[level.atlas45_q_head];
}

atlas45_queue_pop_level()
{
    return level.atlas45_q_level[level.atlas45_q_head];
}

atlas45_queue_advance()
{
    idx = level.atlas45_q_head;

    level.atlas45_q_player[idx] = undefined;
    level.atlas45_q_level[idx] = undefined;

    level.atlas45_q_head = idx + 1;

    if ( level.atlas45_q_head >= level.atlas45_q_tail )
    {
        level.atlas45_q_head = 0;
        level.atlas45_q_tail = 0;
    }
}

/* -------------- Listener --------------- */

atlas45_fire_listener()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        if ( !atlas45_queue_has_items() )
            level waittill( "atlas45_fire_request" );

        while ( atlas45_queue_has_items() )
        {
            player = atlas45_queue_pop_player();
            upgrade_level = atlas45_queue_pop_level();
            atlas45_queue_advance();

            if ( !isdefined(player) || !is_alive(player) )
                continue;

            if ( !isdefined(player.atlas45_next_fire_time) )
                player.atlas45_next_fire_time = 0;

            now = gettime();
            if ( now < player.atlas45_next_fire_time )
                continue;

            player.atlas45_next_fire_time = now + int(FIRE_COOLDOWN * 1000);

            atlas45_spawn_virtual_projectile( player, upgrade_level );
        }

        wait 0.001;
    }
}

/* ----------- Virtual projectile ---------- */

atlas45_spawn_virtual_projectile( player, upgrade_level )
{
    fwd = player getforwarddir();
    if ( !isdefined(fwd) )
        fwd = (1,0,0);

    if ( !isdefined(player.atlas45_hand) )
        player.atlas45_hand = 0;
    player.atlas45_hand = 1 - player.atlas45_hand;

    xoff = (player.atlas45_hand == 0) ? -6 : 6;
    start = player.origin + (xoff, 0, 42);

    level thread atlas45_virtual_projectile_think( start, fwd, upgrade_level, player );
}

atlas45_virtual_projectile_think( pos, fwd, upgrade_level, owner )
{
    level endon( "game_ended" );

    start_ms = gettime();
    step_len = PROJ_SPEED * STEP_DT;

    while ( true )
    {
        if ( !isdefined(owner) || !is_alive(owner) )
            return;

        now = gettime();
        if ( (now - start_ms) >= int(PROJ_LIFETIME * 1000) )
        {
            atlas45_explode( pos, upgrade_level, owner );
            return;
        }

        next = pos + (fwd * step_len);

        tr = bullettrace( pos, next, false, owner );
        if ( isdefined(tr) && tr["fraction"] < 1 )
        {
            hit_pos = pos;
            if ( isdefined(tr["position"]) )
                hit_pos = tr["position"];

            atlas45_explode( hit_pos, upgrade_level, owner );
            return;
        }

        ai = getaiarray();
        for ( i = 0; i < ai.size; i++ )
        {
            z = ai[i];
            if ( !isdefined(z) || !is_alive(z) )
                continue;

            if ( distance(next, z.origin) <= 18 )
            {
                atlas45_explode( next, upgrade_level, owner );
                return;
            }
        }

        pos = next;
        wait STEP_DT;
    }
}

/* --------------- Explosion --------------- */

atlas45_explode( pos, upgrade_level, owner )
{
    playfx( getfx("exp_grenade_concussion_explo"), pos );
    playsoundatposition( "exp_grenade_concussion_explo", pos );

    max_dmg = BASE_INNER_DAMAGE + (upgrade_level - 1) * UPGRADE_DAMAGE_SCALER;

    ai = getaiarray();
    for ( i = 0; i < ai.size; i++ )
    {
        z = ai[i];
        if ( !isdefined(z) || !is_alive(z) )
            continue;

        d = distance(pos, z.origin);
        if ( d > SPLASH_RADIUS )
            continue;

        dmg = atlas45_splash_damage(max_dmg, d);
        if ( dmg <= 0 )
            continue;

        // AW DoDamage order:
        // DoDamage(damage, position, attacker, inflictor, hitLoc, mod, dFlags, weapon)
        z dodamage( int(dmg), pos, owner, owner, "none", "MOD_EXPLOSIVE", 0, "" );
    }

    if ( isdefined(owner) && is_alive(owner) )
    {
        pd = distance(pos, owner.origin);
        if ( pd <= SPLASH_RADIUS )
        {
            self_dmg = atlas45_splash_damage(max_dmg, pd) * SELF_DAMAGE_SCALE;
            if ( self_dmg > 0 )
                owner dodamage( int(self_dmg), pos, owner, owner, "none", "MOD_EXPLOSIVE", 0, "" );
        }
    }
}

atlas45_splash_damage( max_dmg, d )
{
    if ( d >= SPLASH_RADIUS )
        return 0;

    if ( d <= INNER_RADIUS )
        return max_dmg;

    span = SPLASH_RADIUS - INNER_RADIUS;
    if ( span <= 0.001 )
        return 0;

    t = (d - INNER_RADIUS) / span;
    t = clamp(t, 0, 1);

    return max_dmg * (1.0 - t);
}