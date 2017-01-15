#include <amxmodx>

#pragma semicolon 1

#define VERSION "0.1"

#define NULL -1

#define ID_EXTEND 8

#define MAX_MODS_IN_VOTE 6
#define MAX_NOMINATION_MODS 4
#define MAX_MAPS_IN_VOTE 6
#define MAX_NOMINATION_MAPS 4

new Array:g_modPrefix;
new Array:g_modName;
new Array:g_modDesc;
new Array:g_modMaps;
new Array:g_modPlugins;
new Array:g_modConfigs;
new g_modCount;

new Array:g_mapList;
new g_mapCount;

new bool:g_hasRtv[33];
new bool:g_hasVoted[33];
new g_nomination[33] = {NULL, ...};

new g_voting;
new Float:g_voteTime;
new g_menuChoices[9], g_numChoices;
new g_voteCount[9];

new g_currentMod = NULL;
new g_nextMod;
new g_currentMap[32];
new g_currentMapId;

new g_maxClients;
new g_hudSyncObj;

new CvarWait, CvarRatio, CvarReady, CvarDuration, CvarChangeTime;
new CvarExtendStep, CvarExtendMax;
new CvarTimeLimit;

public plugin_precache()
{
	g_modPrefix = ArrayCreate(32);
	g_modName = ArrayCreate(32);
	g_modDesc = ArrayCreate(32);
	g_modMaps = ArrayCreate(1);
	g_modPlugins = ArrayCreate(1);
	g_modConfigs = ArrayCreate(1);
	g_mapList = ArrayCreate(32);
	
	LoadMods();
	
	if (!g_modCount)
	{
		set_fail_state("No mod loaded.");
		return;
	}
	
	g_mapList = GetAllMaps();
	g_mapCount = ArraySize(g_mapList);
	
	get_mapname(g_currentMap, charsmax(g_currentMap));
	g_currentMapId = arrayFindString(g_mapList, g_currentMap);
	
	new modPrefix[32];
	get_localinfo("mm_nextmod", modPrefix, charsmax(modPrefix));
	
	g_currentMod = arrayFindString(g_modPrefix, modPrefix);
}

public plugin_init()
{
	register_plugin("Mod Manager", VERSION, "penguinux");
	
	register_event("HLTV", "OnEventNewRound", "a", "1=0", "2=0");
	
	register_concmd("mm_startvote", "CmdStartVote", ADMIN_MAP);

	register_clcmd("say rtv", "CmdSayRtv");
	register_clcmd("say", "CmdSay");

	register_menucmd(register_menuid("Vote Mod"), 1023, "CountModVote");
	register_menucmd(register_menuid("Vote Map"), 1023, "CountMapVote");
	
	CvarWait = register_cvar("mm_rtv_wait", "120");
	CvarRatio = register_cvar("mm_rtv_ratio", "0.7");
	CvarReady = register_cvar("mm_vote_delay", "8.0");
	CvarDuration = register_cvar("mm_vote_duration", "15.0");
	CvarChangeTime = register_cvar("mm_change_time", "180.0");
	
	CvarExtendStep = register_cvar("mm_extend_step", "15");
	CvarExtendMax = register_cvar("mm_extend_max", "120");
	
	CvarTimeLimit = get_cvar_pointer("mp_timelimit");

	g_maxClients = get_maxplayers();
	g_hudSyncObj = CreateHudSyncObj();
	
	set_task(10.0, "CheckEndOfMap", 1337, _, _, "b");

	CheckMod();
}

CheckMod()
{
	new modPrefix[32];
	
	if (g_currentMod == NULL || !isMapInMod(g_currentMap, g_currentMod))
	{
		new Array:aMods = ArrayCreate(1);

		for (new i = 0; i < g_modCount; i++)
		{
			if (isMapInMod(g_currentMap, i))
			{
				ArrayPushCell(aMods, i);
			}
		}
		
		new numMods = ArraySize(aMods);
		if (numMods > 0)
		{
			new rand = random(numMods);
			g_currentMod = ArrayGetCell(aMods, rand);

			ArrayDestroy(aMods);
			ArrayGetString(g_modPrefix, g_currentMod, modPrefix, charsmax(modPrefix));
			
			set_localinfo("mm_nextmod", modPrefix);
			server_cmd("restart");
		}
		else
		{
			set_localinfo("mm_nextmod", "Jjaio84aAKLJ921o0");
			if (g_currentMod != NULL)
				server_cmd("restart");
		}
	}
	else
	{
		ArrayGetString(g_modPrefix, g_currentMod, modPrefix, charsmax(modPrefix));
		set_localinfo("mm_nextmod", modPrefix);
	}
}

public plugin_cfg()
{
	if (g_currentMod == NULL)
		return;
	
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	add(basePath, charsmax(basePath), "/modmanager");
	
	new Array:aConfigs = ArrayGetCell(g_modConfigs, g_currentMod);
	if (aConfigs != Invalid_Array)
	{
		new path[64], filePath[100];
		new size = ArraySize(aConfigs);

		for (new i = 0; i < size; i++)
		{
			ArrayGetString(aConfigs, i, path, charsmax(path));
			formatex(filePath, charsmax(filePath), "%s/%s", basePath, path);
			if (file_exists(filePath))
				server_cmd("exec ^"%s^"", filePath);
		}
	}
}

public plugin_end()
{
	new prefix[32];
	get_localinfo("mm_nextmod", prefix, charsmax(prefix));
	
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));

	new pluginsFile[100];
	formatex(pluginsFile, charsmax(pluginsFile), "%s/plugins-modmanager.ini", basePath);
	if (file_exists(pluginsFile))
		delete_file(pluginsFile);

	new mod = arrayFindString(g_modPrefix, prefix);
	if (mod == NULL)
		return;

	add(basePath, charsmax(basePath), "/modmanager");
	
	new Array:aPlugins = ArrayGetCell(g_modPlugins, mod);
	if (aPlugins != Invalid_Array)
	{
		new path[64], filePath[100];
		new size = ArraySize(aPlugins);

		for (new i = 0; i < size; i++)
		{
			ArrayGetString(aPlugins, i, path, charsmax(path));
			formatex(filePath, charsmax(filePath), "%s/%s", basePath, path);
			if (file_exists(filePath))
			{
				AppendPluginsFile(pluginsFile, filePath);
				server_print("%s %s", pluginsFile, filePath);
			}
		}
	}
}

public CmdStartVote(id)
{
	StartTheVote();
	return PLUGIN_HANDLED;
}

public CmdSayRtv(id)
{
	if (g_voting)
	{
		client_print_color(id, print_team_default, "^4[HKGSE] ^1投票正在進行中.");
		return PLUGIN_HANDLED;
	}

	new Float:seconds = g_voteTime + get_pcvar_float(CvarWait) - get_gametime();
	if (seconds > 0.0)
	{
		client_print_color(id, print_team_default, "^4[HKGSE] ^1不能在 ^3%.f ^1秒內再投票.", seconds);
		return PLUGIN_HANDLED;
	}
	
	if (g_hasRtv[id])
	{
		g_hasRtv[id] = false;
		client_print_color(id, print_team_default, "^4[HKGSE] ^1你取消了轉換地圖的建議 (剩下 ^3%d ^1人)", countRtv());
		return PLUGIN_HANDLED;
	}	
	
	g_hasRtv[id] = true;

	new numPlayers = floatround(countPlayers() * get_pcvar_float(CvarRatio), floatround_ceil) - countRtv();
	
	client_print_color(0, id, "^4[HKGSE] ^3%n ^1話想轉地圖 (仲差 ^3%d ^1個人)", id, numPlayers);
	
	if (numPlayers <= 0)
	{
		arrayset(g_hasRtv, false, sizeof g_hasRtv);
		StartTheVote();
	}
	
	return PLUGIN_HANDLED;
}

public CmdSay(id)
{
	new arg[128];
	read_args(arg, charsmax(arg));
	remove_quotes(arg);
	
	new arg1[32], arg2[32];
	parse(arg, arg1, charsmax(arg1), arg2, charsmax(arg2));
	
	if (equal(arg1, "/nom"))
	{
		ShowNominateMenu(id, arg2);
		return PLUGIN_HANDLED;
	}
	else
	{
		new mapId = arrayFindString(g_mapList, arg1);
		if (mapId != -1)
			NominateMap(id, arg1);
	}
	
	return PLUGIN_CONTINUE;
}

public ShowNominateMenu(id, const match[])
{
	new text[64];
	formatex(text, charsmax(text), "提名地圖 \w%s\y", match);
	
	new menu = menu_create(text, "HandleNominateMenu");
	new mapName[32];

	for (new i = 0; i < g_mapCount; i++)
	{
		ArrayGetString(g_mapList, i, mapName, charsmax(mapName));
		
		if (!match[0] || containi(mapName, match) != -1)
		{
			formatex(text, charsmax(text), mapName);
			
			if (isMapNominated(mapName))
			{
				if (g_nomination[id] == i)
					add(text, charsmax(text), "\y (你已提名)");
				else
					add(text, charsmax(text), "\y (已提名)");
			}
			
			if (g_currentMapId == i)
				add(text, charsmax(text), "\y (目前地圖)");
			
			menu_additem(menu, text, mapName);
		}
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleNominateMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	new dummy, info[32];
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	NominateMap(id, info);
}

public ReadyToVote()
{
	if (g_voting == 1)
	{
		new second = floatround(g_voteTime + get_pcvar_float(CvarReady) - get_gametime());
		if (second > 0)
		{
			set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 1.0, -1);
			ShowSyncHudMsg(0, g_hudSyncObj, "投票遊戲模式將於 %d 秒後開始...", second);
		}
		else
		{
			StartModVote();
		}
	}
	else if (g_voting == 2)
	{
		new second = floatround(g_voteTime + get_pcvar_float(CvarDuration) + get_pcvar_float(CvarReady) * 2.0 - get_gametime());
		if (second > 0)
		{
			set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 1.0, -1);
			ShowSyncHudMsg(0, g_hudSyncObj, "投票地圖將於 %d 秒後開始...", second);
		}
		else
		{
			StartMapVote();
		}
	}
}

public ShowModVote()
{
	static menu[512], len, keys;
	static mod;
	
	for (new player = 1, i; player <= g_maxClients; player++)
	{
		if (!is_user_connected(player) || is_user_bot(player))
			continue;
		
		if (g_hasVoted[player])
			continue;
		
		keys = MENU_KEY_0;
		
		len = formatex(menu, charsmax(menu), "\y選擇下一個遊戲模式^n^n");
		
		for (i = 0; i < g_numChoices; i++)
		{
			mod = g_menuChoices[i];
			
			len += formatex(menu[len], 511-len, "\y%d. \w%a \d%a^n", i+1, ArrayGetStringHandle(g_modName, mod), ArrayGetStringHandle(g_modDesc, mod));
			keys |= (1 << i);
		}
		
		if (g_menuChoices[ID_EXTEND] != NULL)
		{
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %a^n", ArrayGetStringHandle(g_modName, g_menuChoices[ID_EXTEND]));
			keys |= MENU_KEY_9;
		}
		
		len += formatex(menu[len], 511-len, "^n\y0. \w沒意見");
		
		show_menu(player, keys, menu, 5, "Vote Mod");
	}
}

public CountModVote(id, key)
{
	if (key == 9 || g_voting != 1 || g_hasVoted[id])
		return;
	
	g_voteCount[key]++;
	g_hasVoted[id] = true;
}

public CheckModVotes()
{
	new best;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > g_voteCount[best])
			best = i;
	}
	
	new sameVotes[sizeof g_voteCount], numSame = 0;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > 0 && g_voteCount[i] == g_voteCount[best])
			sameVotes[numSame++] = i;
	}
	
	if (numSame > 1)
	{
		best = sameVotes[random(numSame)];
		client_print_color(0, print_team_default, "^4[HKGSE] ^1由於有 ^3%d ^1個結果相同, 系統隨機選擇了其中一個.", numSame);
	}
	
	setNextMod(g_menuChoices[best]);
	
	client_print_color(0, print_team_default, "^4[HKGSE] ^1遊戲模式投票結果是 ^3%a^1. 投票下一個地圖即將開始...", ArrayGetStringHandle(g_modName, g_nextMod));
	
	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use the mass(e42) cap(s50)^"");
	
	g_voting = 2;
	
	remove_task(0);
	set_task(1.0, "ReadyToVote", 0, _, _, "b");
	
	ShowModVoteResult();
}

public ShowMapVote()
{
	static menu[512], len, keys;
	static map;
	
	for (new player = 1, i; player <= g_maxClients; player++)
	{
		if (!is_user_connected(player) || is_user_bot(player))
			continue;
		
		if (g_hasVoted[player])
			continue;
		
		keys = MENU_KEY_0;
		
		len = formatex(menu, charsmax(menu), "\y選擇下一個地圖^n^n");
		
		for (i = 0; i < g_numChoices; i++)
		{
			map = g_menuChoices[i];
			
			len += formatex(menu[len], 511-len, "\y%d. \w%a^n", i+1, ArrayGetStringHandle(g_mapList, map));
			keys |= (1 << i);
		}
		
		if (g_menuChoices[ID_EXTEND] != NULL)
		{
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %s^n", g_currentMap);
			keys |= MENU_KEY_9;
		}
		
		len += formatex(menu[len], 511-len, "^n\y0. \w沒意見");
		
		show_menu(player, keys, menu, 5, "Vote Map");
	}
}

public CountMapVote(id, key)
{
	if (key == 9 || g_voting != 1 || g_hasVoted[id])
		return;
	
	g_voteCount[key]++;
	g_hasVoted[id] = true;
}

public CheckMapVotes()
{
	remove_task(0);
	
	new best;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > g_voteCount[best])
			best = i;
	}
	
	new sameVotes[sizeof g_voteCount], numSame = 0;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > 0 && g_voteCount[i] == g_voteCount[best])
			sameVotes[numSame++] = i;
	}
	
	if (numSame > 1)
	{
		best = sameVotes[random(numSame)];
		client_print_color(0, print_team_default, "^4[HKGSE] ^1由於有 ^3%d ^1個結果相同, 系統隨機選擇了其中一個.", numSame);
	}
	
	if (best == ID_EXTEND)
	{
		g_voting = 0;
		
		if (get_timeleft() < 130)
		{
			set_pcvar_float(CvarTimeLimit, get_pcvar_float(CvarTimeLimit) + get_pcvar_float(CvarExtendStep));
			client_print_color(0, print_team_default, "^4[HKGSE] ^1投票地圖結束. %s 將會延長 %d 分鐘.", g_currentMap, get_pcvar_num(CvarExtendStep));
		}
		else
		{
			client_print_color(0, print_team_default, "^4[HKGSE] ^1投票地圖結束. %s 將會繼續延長.", g_currentMap);
		}
	}
	else
	{
		new mapName[32];
		ArrayGetString(g_mapList, g_menuChoices[best], mapName, charsmax(mapName));
		
		g_voting = 3;

		set_cvar_string("amx_nextmap", mapName);
		set_task(get_pcvar_float(CvarChangeTime), "ChangeLevel", 0);

		client_print_color(0, print_team_default, "^4[HKGSE] ^1投票地圖結果是 ^3%s^1. 地圖將會在下一局轉換.", mapName);
	}
	
	ShowMapVoteResult();
}

public CheckEndOfMap()
{
	if (g_voting)
		return;
	
	if (get_timeleft() < 130)
		StartTheVote();
}

public OnEventNewRound()
{
	if (g_voting == 3)
		ChangeLevel();
}

public ChangeLevel()
{
	emessage_begin(MSG_BROADCAST, SVC_INTERMISSION);
	emessage_end();
	
	new mapName[32];
	get_cvar_string("amx_nextmap", mapName, charsmax(mapName));
	client_print(0, print_chat, "正在轉換地圖 %s...", mapName);
}

ShowModVoteResult()
{
	new numPlayers = countPlayers();
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;
	
	static menu[512], mod;
	new len = formatex(menu, 511, "\y投票結果^n^n");

	for (new i = 0; i < g_numChoices; i++)
	{
		mod = g_menuChoices[i];
		
		len += formatex(menu[len], 511-len, "\d%d. \w%a", i+1, ArrayGetStringHandle(g_modName, mod));
		
		if (g_voteCount[i])
			len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_voteCount[i], numPlayers));
		
		len += formatex(menu[len], 511-len, "^n");
	}

	if (g_menuChoices[ID_EXTEND] != NULL)
	{
		len += formatex(menu[len], 511-len, "^n\d9. \w%a", ArrayGetStringHandle(g_modName, g_currentMod));

		if (g_voteCount[ID_EXTEND])
			len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_voteCount[ID_EXTEND], numPlayers));
		
		len += formatex(menu[len], 511-len, "^n");
	}
	
	len += formatex(menu[len], 511-len, "^n\y0. \w離開");
	
	show_menu(0, keys, menu, 7, "");
}

ShowMapVoteResult()
{
	new numPlayers = countPlayers();
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;
	
	static menu[512], map;
	new len = formatex(menu, 511, "\y投票結果^n^n");

	for (new i = 0; i < g_numChoices; i++)
	{
		map = g_menuChoices[i];
		
		len += formatex(menu[len], 511-len, "\d%d. \w%a", i+1, ArrayGetStringHandle(g_mapList, map));
		
		if (g_voteCount[i])
			len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_voteCount[i], numPlayers));
		
		len += formatex(menu[len], 511-len, "^n");
	}

	if (g_menuChoices[ID_EXTEND] != NULL)
	{
		len += formatex(menu[len], 511-len, "^n\d9. \w%s", g_currentMap);

		if (g_voteCount[ID_EXTEND])
			len += formatex(menu[len], 511-len, " \y(%d%%)", getPercent(g_voteCount[ID_EXTEND], numPlayers));
		
		len += formatex(menu[len], 511-len, "^n");
	}
	
	len += formatex(menu[len], 511-len, "^n\y0. \w離開");
	
	show_menu(0, keys, menu, 7, "");
}

NominateMap(id, const mapName[])
{
	new index = arrayFindString(g_mapList, mapName);
	if (index == NULL)
		return 0;

	if (g_currentMapId == index)
	{
		client_print_color(id, print_team_default, "^4[HKGSE] ^1不能提名目前的地圖.");
		return 0;
	}
	
	if (isMapNominated(mapName))
	{
		if (g_nomination[id] != index)
		{
			client_print_color(id, print_team_default, "^4[HKGSE] ^1這個地圖已被提名.");
			return 0;
		}
		else
		{
			g_nomination[id] = -1;
			client_print_color(id, print_team_default, "^4[HKGSE] ^1你取消了提名 ^3%s^1.", mapName);
			return 1;
		}
	}
	
	g_nomination[id] = index;
	client_print_color(0, id, "^4[HKGSE] ^3%n ^1話想玩 ^3%s^1.", id, mapName);
	return 2;
}

StartTheVote()
{
	g_voting = 1;
	g_voteTime = get_gametime();
	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use the mode^"");
	
	remove_task(0);
	set_task(1.0, "ReadyToVote", 0, _, _, "b");
}

StartModVote()
{
	g_voting = 1;
	g_numChoices = 0;
	
	new Array:aNominations = ArrayCreate(1);
	new numNominations;
	
	for (new i = 1, j; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_nomination[i] != NULL)
		{
			for (j = 0; j < g_modCount; j++)
			{
				if (g_currentMod == j)
					continue;

				if (arrayFindCell(aNominations, j) != NULL)
					continue;
				
				if (isMapInMod2(g_nomination[i], j))
				{
					ArrayPushCell(aNominations, j);
					numNominations++;
				}	
			}
		}
	}
	
	new rand;

	while (g_numChoices < MAX_NOMINATION_MODS && numNominations > 0)
	{
		rand = random(numNominations);

		g_menuChoices[g_numChoices++] = ArrayGetCell(aNominations, rand);

		ArrayDeleteItem(aNominations, rand);
		numNominations--;
	}
	
	new Array:aMods = ArrayCreate(1);
	new numMods = 0;
	
	for (new i = 0; i < g_modCount; i++)
	{
		if (g_currentMod == i)
			continue;
		
		if (isInArrayInt(i, g_menuChoices, g_numChoices))
			continue;
		
		ArrayPushCell(aMods, i);
		numMods++;
	}
	
	while (g_numChoices < MAX_MODS_IN_VOTE && numMods > 0)
	{
		rand = random(numMods);
		
		g_menuChoices[g_numChoices++] = ArrayGetCell(aMods, rand);
		
		ArrayDeleteItem(aMods, rand);
		numMods--;
	}
	
	ArrayDestroy(aNominations);
	ArrayDestroy(aMods);
	
	if (g_currentMod != NULL)
		g_menuChoices[ID_EXTEND] = g_currentMod;
	else
		g_menuChoices[ID_EXTEND] = NULL;
	
	arrayset(g_voteCount, 0, sizeof g_voteCount);
	arrayset(g_hasVoted, false, sizeof g_hasVoted);

	remove_task(0);
	set_task(1.0, "ShowModVote", 0, _, _, "b");
	set_task(get_pcvar_float(CvarDuration), "CheckModVotes", 0);
	
	client_cmd(0, "spk Gman/Gman_Choose%d", random_num(1, 2));
}

StartMapVote()
{
	g_voting = 1;
	g_numChoices = 0;
	
	new Array:aNominations = ArrayCreate(1);
	new numNominations;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_nomination[i] == NULL)
			continue;
		
		if (isMapInMod2(g_nomination[i], g_nextMod))
		{
			ArrayPushCell(aNominations, g_nomination[i]);
			numNominations++;
		}
	}
	
	new rand;
	
	while (g_numChoices < MAX_NOMINATION_MAPS && numNominations > 0)
	{
		rand = random(numNominations);
		
		g_menuChoices[g_numChoices++] = ArrayGetCell(aNominations, rand);
		
		ArrayDeleteItem(aNominations, rand);
		numNominations--;
	}
	
	new Array:aMaps = ArrayCreate(1);
	new numMaps = 0;
	
	for (new i = 0; i < g_mapCount; i++)
	{
		if (g_currentMapId == i)
			continue;
		
		if (isInArrayInt(i, g_menuChoices, g_numChoices))
			continue;
		
		if (isMapInMod2(i, g_nextMod))
		{
			ArrayPushCell(aMaps, i);
			numMaps++;
		}
	}
	
	while (g_numChoices < MAX_MAPS_IN_VOTE && numMaps > 0)
	{
		rand = random(numMaps);
		
		g_menuChoices[g_numChoices++] = ArrayGetCell(aMaps, rand);
		
		ArrayDeleteItem(aMaps, rand);
		numMaps--;
	}
	
	ArrayDestroy(aNominations);
	ArrayDestroy(aMaps);
	
	if (get_pcvar_float(CvarTimeLimit) < get_pcvar_float(CvarExtendMax) && isMapInMod(g_currentMap, g_nextMod))
		g_menuChoices[ID_EXTEND] = g_currentMapId;
	else
		g_menuChoices[ID_EXTEND] = NULL;
	
	arrayset(g_voteCount, 0, sizeof g_voteCount);
	arrayset(g_hasVoted, false, sizeof g_hasVoted);

	remove_task(0);
	set_task(1.0, "ShowMapVote", 0, _, _, "b");
	set_task(get_pcvar_float(CvarDuration), "CheckMapVotes", 0);
	
	client_cmd(0, "spk Gman/Gman_Choose%d", random_num(1, 2));
}

LoadMods()
{
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	add(basePath, charsmax(basePath), "/modmanager");
	
	new filePath[100];
	formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);
	
	new fp = fopen(filePath, "r");
	if (!fp)
		return;
	
	new section;
	new buffer[512];
	new key[64], value[448];
	new prefix[32], name[32], desc[32];

	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));

		if (!buffer[0] || buffer[0] == ';')
			continue;

		// Prefix
		if (buffer[0] == '[')
		{
			section = g_modCount;
			strtok2(buffer[1], prefix, charsmax(prefix), buffer, charsmax(buffer), ']', 1);
			continue;
		}
		
		if (!prefix[0])
			continue;
		
		strtok(buffer, key, charsmax(key), value, charsmax(value), '=');

		trim(key);
		trim(value);
		
		if (equali(key, "name"))
		{
			copy(name, charsmax(name), value);
		}
		else if (equali(key, "desc"))
		{
			copy(desc, charsmax(desc), value);
		}
		else if (equali(key, "maps"))
		{
			// Read maps
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
				LoadModMaps(section, filePath);
			}
			
			// Push the mod into array if map is loaded.
			if (ArraySize(g_modMaps) > section)
			{
				ArrayPushString(g_modPrefix, prefix);
				ArrayPushString(g_modName, name);
				ArrayPushString(g_modDesc, desc);
				ArrayPushCell(g_modPlugins, Invalid_Array);
				ArrayPushCell(g_modConfigs, Invalid_Array);
				
				g_modCount++;
			}
		}
		else if (equali(key, "amxx"))
		{
			// Read plugins
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
				if (file_exists(filePath))
					AddModPlugins(section, key);
			}
		}
		else if (equali(key, "cfgs"))
		{
			// Read configs
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
				if (file_exists(filePath))
					AddModConfigs(section, key);
			}
		}
	}
	
	fclose(fp);
}

LoadModMaps(modId, const path[])
{	
	new fp = fopen(path, "r");
	if (!fp)
		return false;
	
	new Array:aMaps;
	if (!isArraySet(g_modMaps, modId))
		aMaps = ArrayCreate(32);
	else
		aMaps = ArrayGetCell(g_modMaps, g_modCount);
	
	new buffer[100], name[32];

	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));
		parse(buffer, name, charsmax(name));
		
		if (is_map_valid(name) && arrayFindString(aMaps, name) == NULL)
		{
			ArrayPushString(aMaps, name);
		}
	}
	
	fclose(fp);
	
	if (ArraySize(aMaps) < 1)
	{
		ArrayDestroy(aMaps);
		return false;
	}
	
	if (!isArraySet(g_modMaps, modId))
		ArrayPushCell(g_modMaps, aMaps);
	
	return true;
}

AddModPlugins(modId, const path[])
{
	new Array:aPlugins = ArrayGetCell(g_modPlugins, modId);
	if (aPlugins == Invalid_Array)
	{
		aPlugins = ArrayCreate(64);
		ArraySetCell(g_modPlugins, modId, aPlugins);
	}
	
	ArrayPushString(aPlugins, path);
	return true;
}

AddModConfigs(modId, const path[])
{
	new Array:aConfigs = ArrayGetCell(g_modConfigs, modId);
	if (aConfigs == Invalid_Array)
	{
		aConfigs = ArrayCreate(64);
		ArraySetCell(g_modConfigs, modId, aConfigs);
	}
	
	ArrayPushString(aConfigs, path);
	return true;
}

Array:GetAllMaps()
{
	new Array:aMaps = ArrayCreate(32);
	new Trie:tMaps = TrieCreate();
	
	new Array:aModMaps;
	new name[32], size = 0;
	
	for (new i, j; i < g_modCount; i++)
	{
		aModMaps = ArrayGetCell(g_modMaps, i);
		size = ArraySize(aModMaps);
		
		for (j = 0; j < size; j++)
		{
			ArrayGetString(aModMaps, j, name, charsmax(name));
			
			if (!TrieKeyExists(tMaps, name))
			{
				ArrayPushString(aMaps, name);
				TrieSetCell(tMaps, name, 1);
			}
		}
	}
	
	TrieDestroy(tMaps);

	if (ArraySize(aMaps) < 1)
	{
		ArrayDestroy(aMaps);
		return Invalid_Array;
	}
	
	return aMaps;
}

AppendPluginsFile(const pluginsFile[], const fileToCopy[])
{
	const BUFFERSIZE = 256;

	new fp_read = fopen(fileToCopy, "rb");
	if (!fp_read)
		return 0;
	
	new fp_write = fopen(pluginsFile, "ab");
	
	static buffer[BUFFERSIZE];
	static readSize, size;
	
	fseek(fp_read, 0, SEEK_END);
	size = ftell(fp_read);
	fseek(fp_read, 0, SEEK_SET);
	
	for (new i = 0; i < size; i += BUFFERSIZE)
	{
		readSize = fread_blocks(fp_read, buffer, BUFFERSIZE, BLOCK_CHAR);
		fwrite_blocks(fp_write, buffer, readSize, BLOCK_CHAR);
	}
	
	fwrite(fp_write, '^n', BLOCK_CHAR);
	
	fclose(fp_read);
	fclose(fp_write);
	return 1;
}

stock getPercent(part, all, percent=100)
{
	return part * percent / all;
}

stock bool:isMapNominated(const mapName[])
{
	new index = arrayFindString(g_mapList, mapName);
	if (index == -1)
		return false;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_nomination[i] == index)
			return true;
	}
	
	return false;
}

stock setNextMod(mod)
{
	g_nextMod = mod;

	new prefix[32];
	if (mod != NULL)
		ArrayGetString(g_modPrefix, mod, prefix, charsmax(prefix));
	
	set_localinfo("mm_nextmod", prefix);
}

stock bool:isMapInMod(const mapName[], modId)
{
	new Array:aMaps = ArrayGetCell(g_modMaps, modId);
	
	if (arrayFindString(aMaps, mapName) != NULL)
		return true;
	
	return false;
}

stock bool:isMapInMod2(mapId, modId)
{
	new mapName[32];
	ArrayGetString(g_mapList, mapId, mapName, charsmax(mapName));
	
	new Array:aMaps = ArrayGetCell(g_modMaps, modId);
	
	if (arrayFindString(aMaps, mapName) != NULL)
		return true;
	
	return false;
}

stock bool:isArraySet(Array:which, index)
{
	if (ArraySize(which) <= index)
		return false;
	
	return true;
}

stock arrayFindCell(Array:which, cell)
{
	new size = ArraySize(which);
	
	for (new i = 0; i < size; i++)
	{
		if (ArrayGetCell(which, i) == cell)
			return i;
	}
	
	return -1;
}

stock arrayFindString(Array:which, const string[])
{
	new string2[64];
	new size = ArraySize(which);
	
	for (new i = 0; i < size; i++)
	{
		ArrayGetString(which, i, string2, charsmax(string2));
		
		if (equal(string, string2))
			return i;
	}
	
	return -1;
}

stock bool:isInArrayInt(value, const array[], size, start=0)
{
	for (new i = start; i < size; i++)
	{
		if (array[i] == value)
			return true;
	}
	
	return false;
}

stock countPlayers()
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (is_user_connected(i) && !is_user_bot(i))
			count++;
	}
	
	return count;
}

stock countRtv()
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_hasRtv[i])
			count++;
	}
	
	return count;
}