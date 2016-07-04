#include <amxmodx>
#include <amxmisc>

#define MAX_NOMINATIONS 4
#define MAX_MAPS_IN_VOTE 8
#define ID_EXTEND MAX_MAPS_IN_VOTE
#define NULL -1

#define TASK_VOTE 0

new Array:g_mapName;
new g_mapCount;

new g_voting;
new Float:g_lastVoteTime;

new g_mapChoices[MAX_MAPS_IN_VOTE + 1];
new g_mapVoteCount[MAX_MAPS_IN_VOTE + 1];
new g_numChoices;

new g_countDown;
new g_maxClients;

new g_nomination[33] = {NULL, ...};
new bool:g_voted[33];
new bool:g_rocked[33];

new CvarExtendMax, CvarExtendStep;
new CvarRtvWait, CvarRtvRatio;
new CvarTimeLimit;

public plugin_init()
{
	register_plugin("Map Voter", "0.1", "Colgate");
	
	register_menucmd(register_menuid("Map Vote Menu"), 1023, "CountMapVote");
	
	register_clcmd("say", "CmdSay");
	
	CvarExtendStep = register_cvar("mapvote_extend_step", "15");
	CvarExtendMax = register_cvar("mapvote_extend_max", "90");
	
	CvarRtvWait = register_cvar("mapvote_rtv_wait", "60");
	CvarRtvRatio = register_cvar("mapvote_rtv_ratio", "0.7");
	
	CvarTimeLimit = get_cvar_pointer("mp_timelimit");
	
	g_maxClients = get_maxplayers();
	
	g_mapName = ArrayCreate(32);
	
	loadConfigs();
	
	set_task(10.0, "CheckEndOfMap", 1337, _, _, "b");
	
	pause("ac", "mapchooser.amxx");
}

public client_disconnected(id)
{
	g_rocked[id] = false;
	g_voted[id] = false;
	g_nomination[id] = NULL;
}

public CmdSay(id)
{
	new arg[72];
	read_args(arg, charsmax(arg));
	remove_quotes(arg);
	
	new arg1[32], arg2[32];
	parse(arg, arg1, charsmax(arg1), arg2, charsmax(arg2));
	
	new mapId = ArrayFindString(g_mapName, arg1);
	if (mapId != NULL)
	{
		nominateMap(id, mapId);
		return PLUGIN_HANDLED;
	}
	else if (equal(arg1, "/nom") || equal(arg1, "/nominate"))
	{
		ShowNominationMenu(id, arg2);
		return PLUGIN_HANDLED;
	}
	else if (equal(arg1, "/rtv") || equal(arg1, "/rockthevote"))
	{
		rockTheVote(id);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public ShowNominationMenu(id, const match[])
{
	new buffer[64];
	formatex(buffer, charsmax(buffer), "提名地圖 \w%s\y", match);
	
	new menu = menu_create(buffer, "HandleMenuNomination");
	
	for (new mapId = 0; mapId < g_mapCount; mapId++)
	{
		static mapName[32];
		ArrayGetString(g_mapName, mapId, mapName, charsmax(mapName));
		
		if (contain(mapName, match) > NULL || !match[0])
		{
			static info[2];
			formatex(buffer, charsmax(buffer), mapName);
			
			if (isMapNominated(mapId))
				add(buffer, charsmax(buffer), "\r (已提名)");
			
			info[0] = mapId;
			menu_additem(menu, buffer, info);
		}
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleMenuNomination(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	new dummy, info[2];
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	
	new mapId = info[0]
	if (!nominateMap(id, mapId))
		client_print(id, print_chat, "這個地圖已被提名.");
	
	menu_destroy(menu);
}

public CheckEndOfMap()
{
	if (g_voting)
		return;
	
	if (get_timeleft() < 130)
		MakeMapVote();
}

public MakeMapVote()
{
	g_voting = 1;
	g_lastVoteTime = get_gametime();
	
	g_numChoices = 0;
	
	// Get nominated maps
	new nomination[32], numNominations = 0;
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (g_nomination[i] != NULL)
		{
			nomination[numNominations++] = g_nomination[i];
		}
	}
	
	// Add maps to choice
	new maxChoices = min(g_mapCount, MAX_MAPS_IN_VOTE);
	new maxNomination = min(numNominations, MAX_NOMINATIONS);
	
	while (g_numChoices < maxChoices)
	{
		static map;
		
		// Add nominated maps
		if (g_numChoices < maxNomination)
		{
			new i = random(numNominations);
			while (isMapInMenu( (map = nomination[i]) ))
			{
				if (++i >= numNominations)
					i = 0;
			}
		}
		// Add random maps
		else
		{
			map = random(g_mapCount);
			while (isMapInMenu(map))
			{
				if (++map >= g_mapCount)
					map = 0;
			}
		}
		
		g_mapChoices[g_numChoices++] = map;
	}
	
	// Add extend map option
	if (get_pcvar_float(CvarTimeLimit) < get_pcvar_float(CvarExtendMax))
		g_mapChoices[ID_EXTEND] = true;
	else
		g_mapChoices[ID_EXTEND] = false;
	
	arrayset(g_mapVoteCount, 0, sizeof g_mapVoteCount);
	arrayset(g_voted, false, sizeof g_voted);
	
	// Play sound
	remove_task(TASK_VOTE);
	set_task(1.0, "ShowMapVote", TASK_VOTE, _, _, "a", 7);
	set_task(7.0, "CheckMapVotes", TASK_VOTE);
	
	g_countDown = 7;
}

public ShowMapVote()
{
	new numPlayers = countRealPlayers();
	
	static menu[512], len, keys;
	
	for (new player = 1; player <= g_maxClients; player++)
	{
		if (!is_user_connected(player))
			continue;
		
		if (g_voting == 1)
			len = formatex(menu, charsmax(menu), "\y地圖投票即將開始...^n^n");
		else if (g_voting == 2)
			len = formatex(menu, charsmax(menu), "\y投票下一個地圖^n^n");
		else
			len = formatex(menu, charsmax(menu), "\y投票結果^n^n");
		
		keys = 0;
		
		for (new i = 0; i < g_numChoices; i++)
		{
			new map = g_mapChoices[i];
			
			if (g_voting != 2)
				len += formatex(menu[len], 511-len, "\d%d. \w%a", i+1, ArrayGetStringHandle(g_mapName, map));
			else
				len += formatex(menu[len], 511-len, "\y%d. \w%a", i+1, ArrayGetStringHandle(g_mapName, map));
			
			if (g_voting == 3 || (g_voted[player] && g_mapVoteCount[i]))
				len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_mapVoteCount[i], numPlayers));
			
			menu[len++] = '^n';
			keys |= (1 << i);
		}
		
		new i = ID_EXTEND;
		if (g_voting != 1 && g_mapChoices[i])
		{
			static mapName[32];
			get_mapname(mapName, charsmax(mapName));
			
			len += formatex(menu[len], 511-len, "^n%s9. \w延長 %s", g_voting == 2 ? "\y" : "\d", mapName);
			
			if (g_voting == 3 || (g_voted[player] && g_mapVoteCount[i]))
				len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_mapVoteCount[i], numPlayers));
			
			keys |= MENU_KEY_9;
		}
		
		if (g_voting != 3 && g_countDown <= 10)
		{
			len += formatex(menu[len], 511-len, "^n^n\w剩餘時間: %d", g_countDown);
		}
		
		if (g_voting != 2)
			keys = MENU_KEY_0;
		
		show_menu(player, keys, menu, 5, "Map Vote Menu");
	}
	
	g_countDown--;
}

public CountMapVote(id, key)
{
	if (g_voting != 2 || g_voted[id])
		return;
	
	if (key+1 == 9)
	{
		g_mapVoteCount[ID_EXTEND]++;
	}
	else
	{
		g_mapVoteCount[key]++
	}
	
	g_voted[id] = true;
}

public CheckMapVotes()
{
	if (g_voting == 1)
	{
		g_voting = 2;
		
		client_cmd(0, "spk Gman/Gman_Choose%d", random_num(1, 2));
		
		remove_task(TASK_VOTE);
		set_task(1.0, "ShowMapVote", TASK_VOTE, _, _, "a", 15);
		set_task(15.0, "CheckMapVotes", TASK_VOTE);
		
		g_countDown = 15;
		return;
	}
	
	g_voting = 3;
	ShowMapVote();
	
	// Find the best choice
	new best;
	for (new i = 0; i <= MAX_MAPS_IN_VOTE; i++)
	{
		if (g_mapVoteCount[i] > g_mapVoteCount[best])
			best = i;
	}
	
	// Find if choice having same vote count
	new sameVotes[MAX_MAPS_IN_VOTE + 1], num = 0;
	for (new i = 0; i <= MAX_MAPS_IN_VOTE; i++)
	{
		if (g_mapVoteCount[i] > 0 && g_mapVoteCount[i] == g_mapVoteCount[best])
		{
			sameVotes[num++] = i;
		}
	}
	
	// Get a random choice
	if (num > 1)
	{
		best = sameVotes[random(num)];
		client_print(0, print_chat, "由於有 %d 個投票結果相同, 所以隨機選擇了其中一個.", num);
	}
	
	new mapName[32];
	
	// Extend map
	if (best == ID_EXTEND)
	{
		g_voting = 0;
		get_mapname(mapName, charsmax(mapName));
		
		if (get_timeleft() < 130)
			set_cvar_float("mp_timelimit", get_cvar_float("mp_timelimit") + get_pcvar_float(CvarExtendStep));
		
		client_print(0, print_chat, "投票結束. %s 將會延續 %d 分鐘.", mapName, get_pcvar_num(CvarExtendStep));
	}
	else
	{
		ArrayGetString(g_mapName, g_mapChoices[best], mapName, charsmax(mapName));
		
		set_cvar_string("amx_nextmap", mapName);
		set_task(10.0, "changeLevel", TASK_VOTE);
		
		client_print(0, print_chat, "投票結束. 下一張地圖將會是 %s.", mapName);
	}
}

public changeLevel()
{
	emessage_begin(MSG_BROADCAST, SVC_INTERMISSION);
	emessage_end();
	
	new mapName[32];
	get_cvar_string("amx_nextmap", mapName, charsmax(mapName));
	client_print(0, print_chat, "正在更換地圖 %s.", mapName);
}

loadConfigs()
{
	new currentMap[32];
	get_mapname(currentMap, charsmax(currentMap));
	
	new filePath[100];
	get_configsdir(filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/maps.ini");
	
	new file = fopen(filePath, "r");
	if (file)
	{
		while (!feof(file))
		{
			static data[64];
			fgets(file, data, charsmax(data));
			
			static mapName[32];
			parse(data, mapName, charsmax(mapName));
			
			if (is_map_valid(mapName) && !equal(currentMap, mapName) && !isMapExists(mapName))
			{
				ArrayPushString(g_mapName, mapName);
				g_mapCount++;
			}
		}
		
		fclose(file);
	}
	
	if (!g_mapCount)
	{
		set_fail_state("Could not load any map.");
	}
}

rockTheVote(id)
{
	if (g_voting)
	{
		client_print(id, print_chat, "投票正在進行中");
		return;
	}
	
	new Float:timeWait = g_lastVoteTime + get_pcvar_float(CvarRtvWait) - get_gametime();
	if (timeWait > 0.0)
	{
		client_print(id, print_chat, "請稍後再投票 (%.f 秒)", timeWait);
		return;
	}
	
	if (g_rocked[id])
	{
		g_rocked[id] = false;
		client_print(id, print_chat, "你取消了更換地圖的投票.");
		return;
	}
	
	g_rocked[id] = true;
	
	new maxVotes = floatround(get_pcvar_float(CvarRtvRatio) * countRealPlayers());
	new numVotes = countRocked();
	
	if (numVotes >= maxVotes)
	{
		arrayset(g_rocked, false, sizeof g_rocked);
		MakeMapVote();
		
		client_print(0, print_chat, "%n 投票更換地圖.", id);
	}
	else
	{
		client_print(0, print_chat, "%n 投票更換地圖 (還需要 %d 個玩家).", id, maxVotes - numVotes);
	}
}

stock getPercent(part, all, percent=100)
{
	return part * percent / all;
}

bool:nominateMap(id, map)
{
	if (isMapNominated(map))
		return false;
	
	g_nomination[id] = map;
	client_print(0, print_chat, "%n 提名了地圖 %a.", id, ArrayGetStringHandle(g_mapName, map));
	return true;
}

stock bool:isMapInMenu(map)
{
	for (new i = 0; i < g_numChoices; i++)
	{
		if (g_mapChoices[i] == map)
			return true
	}
	
	return false;
}

stock bool:isMapExists(const map[])
{
	return (ArrayFindString(g_mapName, map) != NULL);
}

stock bool:isMapNominated(map)
{
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (g_nomination[i] == map)
			return true;
	}
	
	return false;
}

stock countRocked()
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (g_rocked[i])
			count++;
	}
	
	return count;
}

stock countRealPlayers()
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (is_user_connected(i) && !is_user_bot(i))
			count++;
	}
	
	return count;
}