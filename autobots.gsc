/*
Mod: Autobots - S1X v0.0.3 Compatible
Originally Developed by DoktorSAS
Difficulty Addition By Kalitos
Tested by BoxOfMysteriez
Updated for S1X v0.0.3 with COOP support and veteran difficulty

This version uses S1X v0.0.3 compatible functions:
- spawnBots(count)
- kickBot(player)
- Bot_difficulty_default(3) for veteran difficulty
- Detects COOP mode and uses separate target player counts
- Sets bot difficulty to veteran (level 3) for both COOP and multiplayer
*/

#include maps/mp/bots/_bots;

//
// Configuration
//
level.autobots_mpTargetPlayers = 18;   // target players for multiplayer
level.autobots_coopTargetPlayers = 6;  // target players for COOP

init()
{
	level thread onPlayerConnect();
	level thread serverBotFill();
	level thread setDiffBots();
}

// Detect COOP mode
isCoopMode()
{
	if (isdefined(level.coop) && level.coop)
		return true;

	if (isdefined(level.gametype) && isstring(level.gametype) && isSubStr(level.gametype, "coop"))
		return true;

	if (isdefined(level.gameType) && isstring(level.gameType) && isSubStr(level.gameType, "coop"))
		return true;

	if (isdefined(level.mapname) && isstring(level.mapname) && (isSubStr(level.mapname, "coop") || isSubStr(level.mapname, "zmb")))
		return true;

	return false;
}

onPlayerConnect()
{
	level endon("game_ended");
	for (;;)
	{
		level waittill("connected", player);
		if (!player isentityabot())
		{
			player thread kickBotOnJoin();
		}
	}
}

isentityabot()
{
	return isSubStr(self getguid(), "bot");
}

serverBotFill()
{
	level endon("game_ended");
	level waittill("connected", player);
	for (;;)
	{
		// Get target based on game mode
		target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

		// Spawn bots until we reach target
		while (level.players.size < target && !level.gameended)
		{
			spawnBots(11);
			wait 1;
		}

		// Kick bots if we exceed target
		if (level.players.size > target && contBots() > 0)
		{
			kickBotNow();
		}

		wait 0.05;
	}
}

contBots()
{
	bots = 0;
	foreach (player in level.players)
	{
		if (player isentityabot())
		{
			bots++;
		}
	}
	return bots;
}

kickBotNow()
{
	level endon("game_ended");
	foreach (player in level.players)
	{
		if (player isentityabot())
		{
			kickBot(player);
			break;
		}
	}
}

kickBotOnJoin()
{
	level endon("game_ended");
	target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

	// Only kick a bot if we're above target
	if (level.players.size <= target)
		return;

	foreach (player in level.players)
	{
		if (player isentityabot())
		{
			kickBot(player);
			break;
		}
	}
}

/*
Set Bot difficulty with setDiffBots function
Difficulty levels:
0 - "recruit"
1 - "regular"
2 - "hardened"
3 - "veteran"
*/
setDiffBots()
{
	for (;;)
	{
		level waittill("connected", player);
		if (player isentityabot())
		{
			// Set difficulty to veteran (3) for all bots
			Bot_difficulty_default(3);
		}
	}
}
