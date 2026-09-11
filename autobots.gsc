/*
Mod: Autobots - Fixed & Enhanced
Originally Developed by DoktorSAS
Difficulty Addition By Kalitos
Tested by BoxOfMysteriez
Updated with COOP support and veteran difficulty

This version:
- Detects COOP mode and uses separate target player counts
- Sets bot difficulty to "veteran" for both COOP and multiplayer
- Maintains compatibility with S1X bot functions
- Includes proper error handling
*/

#include maps/mp/bots/_bots;

//
// Configuration
//
level.autobots_mpTargetPlayers = 18;   // target players for multiplayer
level.autobots_coopTargetPlayers = 6;  // target players for COOP
level.autobots_coopDifficulty = "veteran";
level.autobots_mpDifficulty = "veteran";

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
			self spawnBots(11);
			wait 1;
		}

		// Kick bots if we exceed target
		if (level.players.size > target && contBots() > 0)
		{
			kickbot();
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

spawnBots(a)
{
	spawn_bots(a, "autoassign");
}

kickbot()
{
	level endon("game_ended");
	foreach (player in level.players)
	{
		if (player isentityabot())
		{
			player bot_drop();
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
			player bot_drop();
			break;
		}
	}
}

/*
Set Bot difficulty with setDiffBots function
Level 1 - 2 "recruit"
Level 17 - 25 "regular"
Level 37 - 44 "hardened"
Level 47 - 50 with Prestige - "veteran"
*/
setDiffBots()
{
	for (;;)
	{
		level waittill("connected", player);
		if (player isentityabot())
		{
			// Determine difficulty based on game mode
			if (isCoopMode())
				difficulty = level.autobots_coopDifficulty;
			else
				difficulty = level.autobots_mpDifficulty;

			// Set the difficulty using the base bot utility function
			player maps/mp/bots/_bots_util::_id_16EB(difficulty, undefined);
		}
	}
}
