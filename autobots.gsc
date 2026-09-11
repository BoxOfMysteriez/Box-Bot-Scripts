#include maps/mp/bots/_bots;
/*
Mod: Autobots
Updated to S1X-compatible style
Originally: Developed by DoktorSAS
Difficulty Addition By Kalitos
Tested by BoxOfMysteriez
Updated for Current AW Version

Changes: Detects online COOP mode and uses COOP-specific target player counts and difficulty.
This version sets COOP and multiplayer bot difficulty to "veteran" as requested.
*/

//
// Configuration - tweak these to fit your COOP server expectations
//
level.autobots_mpTargetPlayers = 18;   // desired total players for normal multiplayer
level.autobots_coopTargetPlayers = 6;  // desired total players for online COOP
level.autobots_coopDifficulty = "veteran"; // default COOP difficulty for bots (set to veteran)
level.autobots_mpDifficulty = "veteran";   // default multiplayer difficulty (set to veteran)

init()
{
	level thread onPlayerConnect();
	level thread serverBotFill();
	level thread setDiffBots();
}

// Detect common signs of COOP mode (heuristics). If unsure, this tries several names/flags.
isCoopMode()
{
	// Try explicit flag first
	if (isdefined(level.coop) && level.coop)
		return true;

	// Some gametypes might include "coop" in their name
	if (isdefined(level.gametype) && isstring(level.gametype) && isSubStr(level.gametype, "coop"))
		return true;

	if (isdefined(level.gameType) && isstring(level.gameType) && isSubStr(level.gameType, "coop"))
		return true;

	// Map name hints (some COOP maps include "coop" or "zombie" keywords)
	if (isdefined(level.mapname) && isstring(level.mapname) && (isSubStr(level.mapname, "coop") || isSubStr(level.mapname, "zmb")))
		return true;

	// Default: not COOP
	return false;
}

onPlayerConnect()
{
	level endon("game_ended");

	// Primary event-driven behavior for player join.
	level thread
	{
		for (;;)
		{
			level waittill("connected", player);

			// If a human connected, kick a bot to make space according to current target
			if (!player isBot())
			{
				player thread kickBotOnJoin();
			}
		}
	};

	// Fallback scanner for join handling on servers that behave differently (host migration, party joins).
	// This will detect an increase in the human player count and kick a bot if needed.
	level thread
	{
		prevHumanCount = getHumanCount();
		for (;;)
		{
			if (level.gameended) break;
			wait 1;

			currHumanCount = getHumanCount();

			// If humans increased, ensure total players don't exceed target (kick a bot if necessary).
			if (currHumanCount > prevHumanCount)
			{
				target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

				// If total players now exceed target and there are bots, drop one bot.
				if (level.players.size > target && contBots() > 0)
				{
					kickbot();
				}
			}

			prevHumanCount = currHumanCount;
		}
	};
}

// Count non-bot players
getHumanCount()
{
	humans = 0;
	foreach (p in level.players)
	{
		if (!p isBot())
			humans++;
	}
	return humans;
}

// S1X-friendly bot check helper. Returns true when 'self' is a bot entity.
isBot()
{
	return isSubStr(self getguid(), "bot");
}

serverBotFill()
{
	level endon("game_ended");

	// Continuous scanning approach with event-driven responsiveness:
	// - spawn when total players < target
	// - drop bots if too many players
	for (;;)
	{
		if (level.gameended) break;

		target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

		// Spawn bots until we hit the desired total player count for the mode.
		while (level.players.size < target && !level.gameended)
		{
			// spawn a small batch so we don't overspawn in rapid loops
			self spawnBots(3);
			// give some time for spawns to register on server
			wait 1;
		}

		// If we have more total players than target and there are bots, kick one.
		if (level.players.size > target && contBots() > 0)
		{
			kickbot();
		}

		// Small sleep to avoid busy-looping but remain responsive for online coop
		wait 0.5;
	}
}

contBots()
{
	bots = 0;
	foreach (player in level.players)
	{
		if (player isBot())
		{
			bots++;
		}
	}
	return bots;
}

spawnBots(a)
{
	// Keep calling into the base spawn helper used by the mod/API.
	// Use "autoassign" so server assigns teams appropriately in coop/multiplayer.
	spawn_bots(a, "autoassign"); // spawnbots(n, team);
}

kickbot()
{
	level endon("game_ended");
	foreach (player in level.players)
	{
		if (player isBot())
		{
			player bot_drop();
			break;
		}
	}
}

kickBotOnJoin()
{
	level endon("game_ended");

	// When a human joins, prefer to drop a bot to make space.
	// This works for online coop as well because the target is coop-aware.
	target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

	// If we're already at or below target no action is necessary.
	if (level.players.size <= target) return;

	// Otherwise drop one bot to free a slot.
	foreach (player in level.players)
	{
		if (player isBot())
		{
			player bot_drop();
			break;
		}
	}
}

/*
Set Bot difficulty below with the setDiffBots function
Level 1 - 2 "recruit"
Level 17 - 25 "regular"
Level 37 - 44 "hardened"
Level 47 - 50 with Prestige - "Veteran"
Add additional slots for mixed difficulty. Example: [ "hardened", "veteran" ]
*/
setDiffBots()
{
	level endon("game_ended");

	// Continuous application of difficulty to any bot present.
	for (;;)
	{
		if (level.gameended) break;

		coop = isCoopMode();

		foreach (player in level.players)
		{
			if (player isBot())
			{
				// Choose mode-specific difficulty unless externally overridden on level
				if (coop)
					difficulty = (isdefined(level.autobots_coopDifficulty) ? level.autobots_coopDifficulty : "veteran");
				else
					difficulty = (isdefined(level.autobots_mpDifficulty) ? level.autobots_mpDifficulty : "veteran");

				player setBotDifficulty(difficulty);
			}
		}

		// Re-apply every 1 second; adjust if you want faster/slower updates
		wait 1;
	}
}

/*
Custom bot difficulty function for current AW version
Replaces the obfuscated _id_16EB function
*/
setBotDifficulty(difficulty)
{
	// 'self' = the bot player entity
	switch (difficulty)
	{
		case "regular":
			self.botAccuracy = 0.6;
			self.reactionTime = 0.5;
			self.maxHealth = 100;
			self.botAggression = 0.5;
			break;
		case "hardened":
			self.botAccuracy = 0.9;
			self.reactionTime = 0.2;
			self.maxHealth = 150;
			self.botAggression = 0.8;
			break;
		case "veteran":
			// Stronger, faster, more aggressive bots for veteran difficulty
			self.botAccuracy = 0.98;
			self.reactionTime = 0.12;
			self.maxHealth = 200;
			self.botAggression = 1.0;
			break;
		case "recruit":
			self.botAccuracy = 0.3;
			self.reactionTime = 0.8;
			self.maxHealth = 80;
			self.botAggression = 0.3;
			break;
		default:
			// default to veteran
			self.botAccuracy = 0.98;
			self.reactionTime = 0.12;
			self.maxHealth = 200;
			self.botAggression = 1.0;
			break;
	}
	self.health = self.maxHealth;
}
