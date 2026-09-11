#include maps/mp/bots/_bots;

combatTrainingForce = true;
combatTrainingMaxPlayers = 12;
dedicatedMaxPlayers = 18;

defaultBotDifficulty = "veteran";
defaultBotLevel = 55;

// Enable/disable debug logs
debugAutobots = true;

init()
{
    if (!combatTrainingForce)
        level.combatTraining = detectCombatTraining();
    else
        level.combatTraining = true;

    dbg("init() combatTraining=" + level.combatTraining);

    level thread onPlayerConnect();
    level thread serverBotFill();
    level thread setDiffBots();
}

detectCombatTraining()
{
    if (isDefined(level.gametype))
    {
        if (isSubStr(level.gametype, "combat") || isSubStr(level.gametype, "training"))
        {
            dbg("detectCombatTraining(): matched gametype=" + level.gametype);
            return true;
        }
    }

    if (isDefined(level.mapname))
    {
        if (isSubStr(level.mapname, "combat") || isSubStr(level.mapname, "training"))
        {
            dbg("detectCombatTraining(): matched mapname=" + level.mapname);
            return true;
        }
    }

    dbg("detectCombatTraining(): no match, default false");
    return false;
}

onPlayerConnect()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);
        dbg("connected guid=" + player getguid() + " isBot=" + (player isBot()));

        if (player isBot())
        {
            player setBotDifficulty(defaultBotDifficulty);
            player applyBotPrestigeSetting();
        }
        else if (!level.combatTraining)
        {
            dbg("human connected in dedicated mode -> kickBotForHumanJoin()");
            player thread kickBotForHumanJoin();
        }
        else
        {
            dbg("human connected in combat training mode -> no bot kick");
        }
    }
}

isBot()
{
    return isSubStr(self getguid(), "bot");
}

serverBotFill()
{
    level endon("game_ended");
    level waittill("connected", player);
    dbg("serverBotFill() started");

    for (;;)
    {
        target = level.combatTraining ? combatTrainingMaxPlayers : dedicatedMaxPlayers;

        if (level.players.size < target)
            dbg("fill loop: players=" + level.players.size + " target=" + target);

        while (level.players.size < target)
        {
            dbg("spawning 4 bots...");
            self spawnBots(4);
            wait 1;
        }

        if (!level.combatTraining)
        {
            if (level.players.size >= target && countBots() > 0)
            {
                dbg("dedicated trim: players=" + level.players.size + " bots=" + countBots() + " -> kickOneBot()");
                kickOneBot();
            }
        }

        wait 0.05;
    }
}

countBots()
{
    bots = 0;
    foreach (player in level.players)
    {
        if (player isBot())
            bots++;
    }
    return bots;
}

spawnBots(a)
{
    spawn_bots(a, "autoassign");
}

kickOneBot()
{
    level endon("game_ended");
    foreach (player in level.players)
    {
        if (player isBot())
        {
            dbg("kickOneBot(): dropping bot guid=" + player getguid());
            player bot_drop();
            break;
        }
    }
}

kickBotForHumanJoin()
{
    dbg("kickBotForHumanJoin()");
    kickOneBot();
}

setDiffBots()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);
        if (player isBot())
        {
            dbg("setDiffBots(): applying difficulty=" + defaultBotDifficulty + " guid=" + player getguid());
            player setBotDifficulty(defaultBotDifficulty);
        }
    }
}

setBotDifficulty(difficulty)
{
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
            self.botAccuracy = 0.98;
            self.reactionTime = 0.12;
            self.maxHealth = 200;
            self.botAggression = 0.9;
            break;

        default:
            self.botAccuracy = 0.6;
            self.reactionTime = 0.5;
            self.maxHealth = 100;
            self.botAggression = 0.5;
            break;
    }

    self.health = self.maxHealth;
    dbg("setBotDifficulty(): " + difficulty + " health=" + self.health + " guid=" + self getguid());
}

applyBotPrestigeSetting()
{
    prestigeMode = -2;

    // NOTE: if getDvarInt is unavailable in your build, this line will error.
    // Replace with your engine's dvar function if needed.
    prestigeMode = getDvarInt("bots_main_prestige");

    dbg("applyBotPrestigeSetting(): mode=" + prestigeMode + " guid=" + self getguid());

    if (prestigeMode == -1)
    {
        hostPrestige = getHostPrestige();
        dbg("prestige mode -1 -> hostPrestige=" + hostPrestige);
        self setBotPrestige(hostPrestige);
    }
    else if (prestigeMode == -2)
    {
        r = randomInt(16); // 0..15
        dbg("prestige mode -2 -> randomPrestige=" + r);
        self setBotPrestige(r);
    }
    else
    {
        if (prestigeMode < 0)
            prestigeMode = 0;
        if (prestigeMode > 15)
            prestigeMode = 15;

        dbg("prestige fixed -> " + prestigeMode);
        self setBotPrestige(prestigeMode);
    }
}

getHostPrestige()
{
    foreach (p in level.players)
    {
        if (!(p isBot()))
        {
            if (isDefined(p.prestige))
                return p.prestige;

            if (isDefined(p.pers) && isDefined(p.pers["prestige"]))
                return p.pers["prestige"];

            return 0;
        }
    }

    return 0;
}

setBotPrestige(prestige)
{
    self.prestige = prestige;

    if (!isDefined(self.pers))
        self.pers = [];

    self.pers["prestige"] = prestige;
    self.rank = defaultBotLevel;
    self.pers["rank"] = defaultBotLevel;

    dbg("setBotPrestige(): prestige=" + prestige + " rank=" + defaultBotLevel + " guid=" + self getguid());
}

dbg(msg)
{
    if (!debugAutobots)
        return;

    // try both common outputs depending on build
    iprintln("^2[Autobots]^7 " + msg);
    println("[Autobots] " + msg);
}
