/*
Mod: Autobots - Standalone Version
Updated to S1X-compatible style
Originally: Developed by DoktorSAS
Difficulty Addition By Kalitos
Tested by BoxOfMysteriez

STANDALONE VERSION - Self-contained bot management system
No external dependencies required. All functions are defined locally.

This version:
- Does NOT require maps/mp/bots/_bots include
- Implements bot spawning and removal internally
- Sets COOP and multiplayer bot difficulty to "veteran"
- Includes error handling and null checks
- Works with standard game engine functions
*/

//
// Configuration - tweak these to fit your server expectations
//
level.autobots_enabled = true;
level.autobots_mpTargetPlayers = 18;   // desired total players for normal multiplayer
level.autobots_coopTargetPlayers = 6;  // desired total players for online COOP
level.autobots_coopDifficulty = "veteran"; // COOP bot difficulty
level.autobots_mpDifficulty = "veteran";   // Multiplayer bot difficulty
level.autobots_spawnBatchSize = 3;     // bots to spawn per iteration
level.autobots_initialized = false;

init()
{
	if (!level.autobots_enabled)
		return;
	
	level.autobots_initialized = true;
	level thread onPlayerConnect();
	level thread serverBotFill();
	level thread setDiffBots();
}

/*
=============================================================================
COOP MODE DETECTION
=============================================================================
*/

isCoopMode()
{
	// Try explicit flag first
	if (isdefined(level.coop) && level.coop)
		return true;

	// Check gametype strings
	if (isdefined(level.gametype) && isstring(level.gametype))
	{
		if (isSubStr(level.gametype, "coop"))
			return true;
	}

	if (isdefined(level.gameType) && isstring(level.gameType))
	{
		if (isSubStr(level.gameType, "coop"))
			return true;
	}

	// Check map name for COOP indicators
	if (isdefined(level.mapname) && isstring(level.mapname))
	{
		if (isSubStr(level.mapname, "coop") || isSubStr(level.mapname, "zmb"))
			return true;
	}

	// Check for campaign/mission mode
	if (isdefined(level.issingleplayermission) && level.issingleplayermission)
		return true;

	return false;
}

/*
=============================================================================
PLAYER MONITORING & BOT MANAGEMENT
=============================================================================
*/

onPlayerConnect()
{
	level endon("game_ended");

	// Event-driven handler for player connections
	level thread
	{
		for (;;)
		{
			level waittill("connected", player);

			if (isdefined(player) && !player isBot())
			{
				player thread kickBotOnJoin();
			}
		}
	};

	// Fallback scanner for edge cases (host migration, party joins)
	level thread
	{
		prevHumanCount = getHumanCount();
		for (;;)
		{
			if (level.gameended) break;
			wait 1;

			currHumanCount = getHumanCount();

			if (currHumanCount > prevHumanCount)
			{
				target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

				if (level.players.size > target && contBots() > 0)
				{
					kickbot();
				}
			}

			prevHumanCount = currHumanCount;
		}
	};
}

getHumanCount()
{
	humans = 0;
	if (!isdefined(level.players))
		return 0;
	
	foreach (p in level.players)
	{
		if (isdefined(p) && !p isBot())
			humans++;
	}
	return humans;
}

contBots()
{
	bots = 0;
	if (!isdefined(level.players))
		return 0;
	
	foreach (player in level.players)
	{
		if (isdefined(player) && player isBot())
			bots++;
	}
	return bots;
}

isBot()
{
	if (!isdefined(self))
		return false;
	
	guid = self getguid();
	if (!isdefined(guid) || !isstring(guid))
		return false;
	
	return isSubStr(guid, "bot");
}

/*
=============================================================================
BOT SPAWNING & REMOVAL
=============================================================================
*/

serverBotFill()
{
	level endon("game_ended");

	for (;;)
	{
		if (level.gameended) break;

		target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

		// Spawn bots until we hit target
		while (isdefined(level.players) && level.players.size < target && !level.gameended)
		{
			spawnBots(level.autobots_spawnBatchSize);
			wait 1;
		}

		// Kick excess bots
		if (isdefined(level.players) && level.players.size > target && contBots() > 0)
		{
			kickbot();
		}

		wait 0.5;
	}
}

spawnBots(count)
{
	if (!isdefined(count) || count < 1)
		return;

	for (i = 0; i < count; i++)
	{
		// Use engine function to add a bot
		// Common function names across engines:
		// - addtestclient() - Standard IW engine
		// - addbot() - Some mod variants
		// - spawnbot() - Custom implementations
		
		if (isfunction("addtestclient"))
		{
			addtestclient();
		}
		else if (isfunction("addbot"))
		{
			addbot();
		}
		else if (isfunction("spawnbot"))
		{
			spawnbot();
		}
		// If none exist, script will continue without error
	}
}

kickbot()
{
	level endon("game_ended");
	
	if (!isdefined(level.players))
		return;
	
	foreach (player in level.players)
	{
		if (isdefined(player) && player isBot())
		{
			// Try multiple removal methods for compatibility
			if (isfunction("bot_drop"))
			{
				player bot_drop();
			}
			else if (isfunction("removePlayer"))
			{
				player removePlayer();
			}
			else if (isfunction("kickClient"))
			{
				player kickClient("EXE_PLAYERKICKED");
			}
			else
			{
				// Fallback: disconnect the player entity
				player disconnect();
			}
			break;
		}
	}
}

kickBotOnJoin()
{
	level endon("game_ended");

	target = (isCoopMode()) ? level.autobots_coopTargetPlayers : level.autobots_mpTargetPlayers;

	if (!isdefined(level.players) || level.players.size <= target)
		return;

	foreach (player in level.players)
	{
		if (isdefined(player) && player isBot())
		{
			if (isfunction("bot_drop"))
			{
				player bot_drop();
			}
			else if (isfunction("removePlayer"))
			{
				player removePlayer();
			}
			else if (isfunction("kickClient"))
			{
				player kickClient("EXE_PLAYERKICKED");
			}
			else
			{
				player disconnect();
			}
			break;
		}
	}
}

/*
=============================================================================
BOT DIFFICULTY SYSTEM
=============================================================================
*/

setDiffBots()
{
	level endon("game_ended");

	for (;;)
	{
		if (level.gameended) break;

		coop = isCoopMode();

		if (isdefined(level.players))
		{
			foreach (player in level.players)
			{
				if (isdefined(player) && player isBot())
				{
					if (coop)
						difficulty = (isdefined(level.autobots_coopDifficulty) ? level.autobots_coopDifficulty : "veteran");
					else
						difficulty = (isdefined(level.autobots_mpDifficulty) ? level.autobots_mpDifficulty : "veteran");

					player thread setBotDifficulty(difficulty);
				}
			}
		}

		wait 1;
	}
}

setBotDifficulty(difficulty)
{
	if (!isdefined(self))
		return;
	
	// Store difficulty for reference
	self.bot_difficulty = difficulty;
	
	// Apply difficulty parameters
	switch (difficulty)
	{
		case "recruit":
			self.botAccuracy = 0.3;
			self.reactionTime = 0.8;
			self.maxHealth = 80;
			self.botAggression = 0.3;
			break;
			
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
		default:
			self.botAccuracy = 0.98;
			self.reactionTime = 0.12;
			self.maxHealth = 200;
			self.botAggression = 1.0;
			break;
	}
	
	// Set health to max
	if (isdefined(self.maxHealth))
		self.health = self.maxHealth;
}

/*
=============================================================================
DIFFICULTY LEVEL REFERENCE
=============================================================================

Recruit (Easy)
- Accuracy: 30%
- Reaction: 0.8s
- Health: 80
- Aggression: 30%

Regular (Medium)
- Accuracy: 60%
- Reaction: 0.5s
- Health: 100
- Aggression: 50%

Hardened (Hard)
- Accuracy: 90%
- Reaction: 0.2s
- Health: 150
- Aggression: 80%

Veteran (Expert)
- Accuracy: 98%
- Reaction: 0.12s
- Health: 200
- Aggression: 100%

=============================================================================
*/
