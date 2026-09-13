#include common_scripts\utility;
#include common_scripts\weapons;

/*
================================
ATLAS 45 FINAL FIXED (COMPAT)
- Mk 1+ always explosive
- Backward compatible: fire_atlas45(upgrade_level, player)
================================
*/

#define MAX_UPGRADE_LEVEL 25

// Explosive tuning
#define PROJ_SPEED 1700
#define PROJ_LIFETIME 3.0
#define FIRE_COOLDOWN 0.14

#define BASE_INNER_DAMAGE 220
#define UPGRADE_DAMAGE_SCALER 12
#define SPLASH_RADIUS 220.0
#define INNER_RADIUS 90.0

#define SELF_DAMAGE_SCALE 1.0
#define ZOMBIE_KNOCKBACK 380

// Debug toggle
#define ATLAS45_DEBUG 0

atlas45_dbg( msg )
{
    if ( ATLAS45_DEBUG )
        iprintln( "^3[ATLAS45]^7 " + msg );
}

init()
{
    atlas45_dbg( "init" );
}

/*
Backward-compatible entry point.
Use this if your existing weapon code calls:
    fire_atlas45( upgrade_level, player )
*/
fire_atlas45( upgrade_level, player )
{
    fire_atlas45_with_variant( upgrade_level, player, 0 );
}

/*
Extended entry point with optional variant id.
variant_id currently unused for compatibility stability.
*/
fire_atlas45_with_variant( upgrade_level, player, variant_id )
{
    if ( !isdefined(player) || !is_alive(player) )
        return;

    if ( !isdefined(variant_id) )
        variant_id = 0;

    // Mk1+ always explosive
    upgrade_level = clamp( upgrade_level, 1, MAX_UPGRADE_LEVEL );
    fire_atlas45_explosive( upgrade_level, player, variant_id );
}

fire_atlas45_explosive( upgrade_level, player, variant_id )
{
    if ( !isdefined(player.atlas45_next_fire_time) )
        player.atlas45_next_fire_time = 0;

    now = gettime();
    if ( now < player.atlas45_next_fire_time )
        return;

    player.atlas45_next_fire_time = now + int(FIRE_COOLDOWN * 1000);

    dir = player getforwarddir();
    if ( !isdefined(dir) )
        dir = (1,0,0);

    // Alternate simple hand offset for dual feel
    if ( !isdefined(player.atlas45_hand) )
        player.atlas45_hand = 0;
    player.atlas45_hand = 1 - player.atlas45_hand;

    xoff = (player.atlas45_hand == 0) ? -6 : 6;
    spawn_pos = player.origin + (xoff, 0, 42);

    proj = spawn("script_model", spawn_pos);
    if ( !isdefined(proj) )
    {
        atlas45_dbg( "spawn failed" );
        return;
    }

    proj.owner = player;
    proj.upgrade_level = upgrade_level;
    proj.variant_id = variant_id;
    proj.spawn_time = now;
    proj.forward = dir;

    proj setvelocity( dir * PROJ_SPEED );
    proj thread atlas45_proj_think();
}

atlas45_proj_think()
{
    self endon("death");

    while ( isdefined(self) )
    {
        now = gettime();

        // Timeout explode
        if ( (now - self.spawn_time) >= int(PROJ_LIFETIME * 1000) )
        {
            atlas45_explode( self.origin, self.upgrade_level, self.owner, self.variant_id );
            self delete();
            return;
        }

        pos = self.origin;

        if ( !isdefined(self.forward) )
            self.forward = (1,0,0);

        // Forward trace impact
        next = pos + (self.forward * (PROJ_SPEED * 0.03));
        tr = bullettrace( pos, next, false, self );

        if ( isdefined(tr) && tr["fraction"] < 1 )
        {
            hit_pos = pos;
            if ( isdefined(tr["position"]) )
                hit_pos = tr["position"];

            atlas45_explode( hit_pos, self.upgrade_level, self.owner, self.variant_id );
            self delete();
            return;
        }

        // Zombie proximity detonation
        ai = getaiarray();
        for ( i = 0; i < ai.size; i++ )
        {
            z = ai[i];
            if ( !isdefined(z) || !is_alive(z) )
                continue;

            if ( distance( pos, z.origin ) <= 18 )
            {
                atlas45_explode( pos, self.upgrade_level, self.owner, self.variant_id );
                self delete();
                return;
            }
        }

        wait 0.03;
    }
}

atlas45_explode( pos, upgrade_level, owner, variant_id )
{
    playfx( getfx("exp_grenade_concussion_impact"), pos );
    playsoundatposition( "exp_grenade_concussion_explo", pos );

    max_dmg = BASE_INNER_DAMAGE + (upgrade_level - 1) * UPGRADE_DAMAGE_SCALER;

    ai = getaiarray();
    for ( i = 0; i < ai.size; i++ )
    {
        z = ai[i];
        if ( !isdefined(z) || !is_alive(z) )
            continue;

        d = distance( pos, z.origin );
        if ( d > SPLASH_RADIUS )
            continue;

        dmg = atlas45_splash_damage( max_dmg, d );
        if ( dmg <= 0 )
            continue;

        z dodamage( dmg, owner, owner, owner, "MOD_EXPLOSIVE" );

        if ( d > 0.001 )
        {
            dir = (z.origin - pos) / d;
            kb = ZOMBIE_KNOCKBACK * (1.0 - (d / SPLASH_RADIUS));
            if ( kb < 0 )
                kb = 0;

            z push( dir * kb );
        }
    }

    // Self-damage
    if ( isdefined(owner) && is_alive(owner) )
    {
        pd = distance( pos, owner.origin );
        if ( pd <= SPLASH_RADIUS )
        {
            self_dmg = atlas45_splash_damage( max_dmg, pd ) * SELF_DAMAGE_SCALE;
            if ( self_dmg > 0 )
                owner dodamage( self_dmg, owner, owner, owner, "MOD_EXPLOSIVE" );
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
    t = clamp( t, 0, 1 );

    return max_dmg * (1.0 - t);
}