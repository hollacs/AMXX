#include <amxmodx>

#pragma semicolon 1

#define VERSION "0.1"

#define MAX_MODS_IN_VOTE 6
#define MAX_MOD_NOMINATEIONS 4
#define MAX_MAPS_IN_VOTE 6
#define MAX_MAP_NOMINATEIONS 4
#define ID_EXTEND 8

new Array:g_modPrefix;
new Array:g_modName;
new Array:g_modDesc;
new Array:g_modMaps;
new g_modCount;

new Array:g_mapList;
new g_mapCount;

new g_voting;
new g_currentMod = -1;
new g_nextMod = -1;
new Float:g_voteTime, Float:g_rockTime;
new g_menuChoices[9], g_numChoices;
new g_voteCount[9];

new g_maxClients;
new g_hudSyncObj;

// Player variables
new bool:g_hasRtv[33];
new bool:g_hasVoted[33];
new g_nomination[33] = {-1, ...};

// CVars
new cvar_wait, cvar_ratio, cvar_ready, cvar_duration, cvar_changeTime;
new cvar_extendStep, cvar_extendMax;
new cvar_timeLimit;

public plugin_precache()
{
	g_modPrefix = ArrayCreate(32);
	g_modName = ArrayCreate(32);
	g_modDesc = ArrayCreate(64);
	g_modMaps = ArrayCreate(1);
	g_mapList = ArrayCreate(32);
	
	loadMods();
	
	if (!g_modCount)
	{
		set_fail_state("No mod loaded.");
		return;
	}
	
	g_mapList = getAllMaps();
	g_mapCount = ArraySize(g_mapList);
	
	new currentMap[32];
	get_mapname(currentMap, charsmax(currentMap));

	new nextMod[32];
	get_localinfo("mm_nextmod", nextMod, charsmax(nextMod));
	
	// mod found
	g_currentMod = arrayFindString(g_modPrefix, nextMod);
	if (g_currentMod != -1)
	{
		// current map not in current mod
		if (!isMapInMod(currentMap, g_currentMod))
		{
			// find a available mod
			new mod = random(g_modCount);
			new begin = mod;
			
			while (!isMapInMod(currentMap, mod))
			{
				if (++mod >= g_modCount)
					mod = 0;

				if (mod == begin)
				{
					mod = -1;
					break;
				}
			}
			
			// no available mod found
			setNextMod(mod);
			
			if (mod != -1)
				server_print("[Mod Manager] Current mod doesn't match current map. New mod (%d) selected.", mod);
			else
				server_print("[Mod Manager] Current mod doesn't match current map. No new mod selected.");
			
			// restart the server to load new mod
			server_cmd("restart");
		}
		else
		{
			setNextMod(g_currentMod);
		}
	}
	else
	{
		// find a available mod
		new mod = random(g_modCount);
		new begin = mod;
		
		while (!isMapInMod(currentMap, mod))
		{
			if (++mod >= g_modCount)
				mod = 0;

			if (mod == begin)
			{
				mod = -1;
				break;
			}
		}

		setNextMod(mod);
		
		// mod found
		if (mod != -1)
		{
			server_print("[Mod Manager] No mod found. New mod (%d) selected.", mod);
			server_cmd("restart");
		}
		else
		{
			server_print("[Mod Manager] No mod found.");
		}
	}
}

public plugin_init()
{
	register_plugin("Mod Manager", VERSION, "penguinux");
	
	register_event("HLTV", "OnEventNewRound", "a", "1=0", "2=0");
	
	register_menucmd(register_menuid("Vote Mod"), 1023, "CountModVote");
	register_menucmd(register_menuid("Vote Map"), 1023, "CountMapVote");
	
	register_clcmd("say rtv", "CmdSayRtv");
	register_clcmd("say", "CmdSay");
	
	register_srvcmd("mods", "CmdMods");

	cvar_wait = register_cvar("mm_rtv_wait", "120");
	cvar_ratio = register_cvar("mm_rtv_ratio", "0.7");
	cvar_ready = register_cvar("mm_rtv_ready", "7.0");
	cvar_duration = register_cvar("mm_vote_duration", "15.0");
	cvar_changeTime = register_cvar("mm_change_time", "180.0");
	
	cvar_extendStep = register_cvar("mm_extend_step", "15");
	cvar_extendMax = register_cvar("mm_extend_max", "120");
	
	cvar_timeLimit = get_cvar_pointer("mp_timelimit");
	
	g_maxClients = get_maxplayers();
	g_hudSyncObj = CreateHudSyncObj();
	
	set_task(10.0, "CheckEndOfMap", 1337, _, _, "b");
}

public plugin_cfg()
{
	if (g_currentMod == -1)
		return;
	
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	add(basePath, charsmax(basePath), "/modmanager");
	
	new filePath[100];
	formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);
	
	new fp = fopen(filePath, "r");
	if (!fp)
		return;
	
	new buffer[512];
	new prefix[32], prefix2[32];
	new key[64], value[448];
	
	ArrayGetString(g_modPrefix, g_currentMod, prefix, charsmax(prefix));

	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));

		if (!buffer[0] || buffer[0] == ';')
			continue;

		if (buffer[0] == '[')
		{
			strtok2(buffer[1], prefix2, charsmax(prefix2), buffer, charsmax(buffer), ']', 1);
			continue;
		}
		
		if (!equal(prefix, prefix2))
			continue;
		
		strtok(buffer, key, charsmax(key), value, charsmax(value), '=');
		
		trim(key);
		trim(value);
		
		if (equali(key, "cfgs") && value[0])
		{
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				server_cmd("exec ^"%s/%s^"", basePath, key);
			}
		}
	}
	
	fclose(fp);
}

public plugin_end()
{	
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	
	new pluginsFile[100];
	formatex(pluginsFile, charsmax(pluginsFile), "%s/plugins-modmanager.ini", basePath);
	
	if (file_exists(pluginsFile))
		delete_file(pluginsFile);
	
	if (g_nextMod == -1)
		return;
	
	new filePath[100];
	add(basePath, charsmax(basePath), "/modmanager");
	formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);
	
	new fp = fopen(filePath, "r");
	if (!fp)
		return;
	
	new buffer[512];
	new prefix[32], prefix2[32];
	new key[64], value[448];
	
	get_localinfo("mm_nextmod", prefix, charsmax(prefix));

	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));

		if (!buffer[0] || buffer[0] == ';')
			continue;

		if (buffer[0] == '[')
		{
			strtok2(buffer[1], prefix2, charsmax(prefix2), buffer, charsmax(buffer), ']', 1);
			continue;
		}
		
		if (!equal(prefix, prefix2))
			continue;
		
		strtok(buffer, key, charsmax(key), value, charsmax(value), '=');
		
		trim(key);
		trim(value);
		
		if (equali(key, "amxx") && value[0])
		{
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
				appendPluginsFile(pluginsFile, filePath);
				server_print("is %s and %s ...", pluginsFile, filePath);
			}
		}
	}
	
	fclose(fp);
}

public OnEventNewRound()
{
	if (g_voting == 3)
		ChangeLevel();
}

public CheckEndOfMap()
{
	if (g_voting)
		return;
	
	if (get_timeleft() < 130)
	{
		g_voting = 1;
		client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use^"");
		
		remove_task(0);
		set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
	}
}

public CmdMods(id)
{
	new Array:maps;
	new size = 0;
	
	for (new i, j; i < g_modCount; i++)
	{
		server_print("%d. [%a] %a", i, ArrayGetStringHandle(g_modPrefix, i), ArrayGetStringHandle(g_modName, i));
		
		maps = ArrayGetCell(g_modMaps, i);
		size = ArraySize(maps);
		
		for (j = 0; j < size; j++)
		{
			server_print("- %a", ArrayGetStringHandle(maps, j));
		}
	}
}

public CmdSayRtv(id)
{
	if (g_voting)
	{
		client_print_color(id, print_team_default, "^4[HKGSE] ^1投票正在進行中.");
		return PLUGIN_HANDLED;
	}

	new Float:seconds = g_voteTime + get_pcvar_float(cvar_wait) - get_gametime();
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
	
	new numPlayers = floatround(countPlayers() * get_pcvar_float(cvar_ratio), floatround_ceil) - countRtv();
	
	client_print_color(0, id, "^4[HKGSE] ^3%n ^1話想轉地圖 (仲差 ^3%d ^1個人)", id, numPlayers);
	
	if (numPlayers <= 0)
	{
		g_rockTime = get_gametime();
		arrayset(g_hasRtv, false, sizeof g_hasRtv);
		
		g_voting = 1;
		client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use^"");
		
		remove_task(0);
		set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
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
	
	new mapId = arrayFindString(g_mapList, arg1);
	if (mapId != -1)
	{
		nominateMap(id, arg1);
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
			
			if (isCurrentMap(mapName))
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
	
	nominateMap(id, info);
}

public TaskReadyToVote()
{
	if (g_voting == 1)
	{
		new second = floatround(g_rockTime + get_pcvar_float(cvar_ready) - get_gametime());
		if (second > 0)
		{
			set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 1.0, -1);
			ShowSyncHudMsg(0, g_hudSyncObj, "投票遊戲模式將於 %d 秒後開始...", second);
		}
		else
		{
			makeModVote();
		}
	}
	else if (g_voting == 2)
	{
		new second = floatround(g_voteTime + get_pcvar_float(cvar_duration) + get_pcvar_float(cvar_ready) - get_gametime());
		if (second > 0)
		{
			set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 1.0, -1);
			ShowSyncHudMsg(0, g_hudSyncObj, "投票地圖將於 %d 秒後開始...", second);
		}
		else
		{
			makeMapVote();
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
			
			len += formatex(menu[len], 511-len, "\y%d. \w%a^n", i+1, ArrayGetStringHandle(g_modName, mod));
			keys |= (1 << i);
		}
		
		if (g_menuChoices[ID_EXTEND])
		{
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %a", ArrayGetStringHandle(g_modName, g_currentMod));
			keys |= MENU_KEY_9;
		}
		
		len += formatex(menu[len], 511-len, "^n\y0. \w沒有意見");
		
		show_menu(player, keys, menu, 5, "Vote Mod");
	}
}

public CountModVote(id, key)
{
	if (g_voting != 1 || g_hasVoted[id])
		return;
	
	if (key == ID_EXTEND)
		g_voteCount[ID_EXTEND]++;
	else
		g_voteCount[key]++;
	
	g_hasVoted[id] = true;
}

public CheckModVotes()
{
	g_voting = 2;

	// Find the best choice
	new best;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > g_voteCount[best])
			best = i;
	}
	
	// Find if choice having same vote count
	new sameVotes[sizeof g_voteCount], numSame = 0;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > 0 && g_voteCount[i] == g_voteCount[best])
			sameVotes[numSame++] = i;
	}
	
	// Random
	if (numSame > 1)
	{
		best = sameVotes[random(numSame)];
		client_print_color(0, print_team_default, "^4[HKGSE] ^1由於有 ^3%d ^1個結果相同, 所以隨機選擇了其中一個.", numSame);
	}

	if (best == ID_EXTEND)
		setNextMod(g_currentMod);
	else
		setNextMod(g_menuChoices[best]);

	new prefix[32];
	ArrayGetString(g_modPrefix, g_nextMod, prefix, charsmax(prefix));
	set_localinfo("mm_nextmod", prefix);
	
	client_print_color(0, print_team_default, "^4[HKGSE] ^1遊戲模式投票結果是 ^3%a^1. 投票下一個地圖即將開始...", ArrayGetStringHandle(g_modName, g_nextMod));

	ShowModVoteResult();

	remove_task(0);
	set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
	
	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42) cap(s50)^"");
}

public ShowModVoteResult()
{
	new numPlayers = countPlayers();
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;
	
	static mod;
	static menu[512], len;
	len = formatex(menu, 511, "\y投票結果^n^n");
	
	for (new i = 0; i < g_numChoices; i++)
	{
		mod = g_menuChoices[i];
		
		len += formatex(menu[len], 511-len, "\y%d. \w%a \y(%d%%)\r(%d)^n",
						i+1,
						ArrayGetStringHandle(g_modName, mod),
						getPercent(g_voteCount[i], numPlayers),
						g_voteCount[i]);
	}
	
	if (g_menuChoices[ID_EXTEND])
	{
		len += formatex(menu[len], 511-len, "^n\y9. \w%a \y(%d%%)\r(%d)^n",
						ArrayGetStringHandle(g_modName, g_currentMod),
						getPercent(g_voteCount[ID_EXTEND], numPlayers),
						g_voteCount[ID_EXTEND]);
	}
	
	len += formatex(menu[len], 511-len, "^n\y0. \w取消");
	
	show_menu(0, keys, menu, 7, "");
}

public ShowMapVote()
{
	static menu[512], len, keys;
	static map, mapName[32];
	
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
		
		if (g_menuChoices[ID_EXTEND])
		{
			get_mapname(mapName, charsmax(mapName));
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %s", mapName);
			keys |= MENU_KEY_9;
		}
		
		len += formatex(menu[len], 511-len, "^n\y0. \w沒有意見");
		
		show_menu(player, keys, menu, 5, "Vote Map");
	}
}

public CountMapVote(id, key)
{
	if (g_voting != 2 || g_hasVoted[id])
		return;
	
	if (key == 8)
		g_voteCount[ID_EXTEND]++;
	else
		g_voteCount[key]++;
	
	g_hasVoted[id] = true;
}

public CheckMapVotes()
{
	remove_task();
	
	// Find the best choice
	new best;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > g_voteCount[best])
			best = i;
	}
	
	// Find if choice having same vote count
	new sameVotes[sizeof g_voteCount], numSame = 0;
	for (new i = 0; i < sizeof g_voteCount; i++)
	{
		if (g_voteCount[i] > 0 && g_voteCount[i] == g_voteCount[best])
			sameVotes[numSame++] = i;
	}
	
	// Random
	if (numSame > 1)
	{
		best = sameVotes[random(numSame)];
		client_print_color(0, print_team_default, "^4[HKGSE] ^1由於有 ^3%d ^1個結果相同, 所以隨機選擇了其中一個.", numSame);
	}

	new mapName[32];
	if (best == ID_EXTEND)
	{
		g_voting = 0;
		get_mapname(mapName, charsmax(mapName));
	
		if (get_timeleft() < 130)
			set_pcvar_float(cvar_timeLimit, get_pcvar_float(cvar_timeLimit) + get_pcvar_float(cvar_extendStep));
		
		client_print_color(0, print_team_default, "^4[HKGSE] ^1投票地圖結束. %s 將會延長 %d 分鐘.", mapName, get_pcvar_num(cvar_extendStep));
	}
	else
	{
		g_voting = 3;
		ArrayGetString(g_mapList, g_menuChoices[best], mapName, charsmax(mapName));
		
		set_cvar_string("amx_nextmap", mapName);
		set_task(get_pcvar_float(cvar_changeTime), "ChangeLevel", 0);
		
		client_print_color(0, print_team_default, "^4[HKGSE] ^1投票地圖結果是 ^3%s^1. 地圖將會在下一局轉換...", mapName);
	}
	
	ShowMapVoteResult();
}

public ShowMapVoteResult()
{
	new numPlayers = countPlayers();
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9;
	
	static map, mapName[32];
	static menu[512], len;
	len = formatex(menu, 511, "\y投票結果^n^n");
	
	for (new i = 0; i < g_numChoices; i++)
	{
		map = g_menuChoices[i];
		
		len += formatex(menu[len], 511-len, "\y%d. \w%a \y(%d%%)\r(%d)^n",
						i+1,
						ArrayGetStringHandle(g_mapList, map),
						getPercent(g_voteCount[i], numPlayers),
						g_voteCount[i]);
	}
	
	if (g_menuChoices[ID_EXTEND])
	{
		get_mapname(mapName, charsmax(mapName));
		len += formatex(menu[len], 511-len, "^n\y9. \w%s \y(%d%%)\r(%d)^n",
						mapName,
						getPercent(g_voteCount[ID_EXTEND], numPlayers),
						g_voteCount[ID_EXTEND]);
	}
	
	len += formatex(menu[len], 511-len, "^n\y0. \w取消");
	
	show_menu(0, keys, menu, 7, "");
}

public ChangeLevel()
{
	emessage_begin(MSG_BROADCAST, SVC_INTERMISSION);
	emessage_end();
	
	new mapName[32];
	get_cvar_string("amx_nextmap", mapName, charsmax(mapName));
	client_print(0, print_chat, "* 正在更換地圖 %s...", mapName);
}

stock makeModVote()
{
	g_voting = 1;
	g_voteTime = get_gametime();
	g_numChoices = 0;
	
	new mapName[32];
	new Array:nominations = ArrayCreate(1);
	new numNominations = 0;
	
	for (new i = 1, j; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_nomination[i] != -1)
		{
			ArrayGetString(g_mapList, g_nomination[i], mapName, charsmax(mapName));
			
			for (j = 0; j < g_modCount; j++)
			{
				if (isMapInMod(mapName, j) && arrayFindCell(nominations, j) == -1)
				{
					ArrayPushCell(nominations, j);
					numNominations++;
				}
			}
		}
	}
	
	new i, mod, begin;
	new maxChoices = min(g_modCount, MAX_MODS_IN_VOTE);
	new maxNomination = min(numNominations, MAX_MOD_NOMINATEIONS);

	while (g_numChoices < maxChoices)
	{
		mod = -1;
		
		// Get nomination mods
		if (g_numChoices < maxNomination)
		{
			i = random(numNominations);
			begin = i;
			
			while (isInArrayInt((mod = ArrayGetCell(nominations, i)), g_menuChoices, g_numChoices) || g_currentMod == mod)
			{
				if (++i >= numNominations)
					i = 0;

				if (i == begin)
				{
					mod = -1;
					break;
				}
			}
		}
		
		// Get random mods
		if (mod == -1)
		{
			mod = random(g_modCount);
			begin = mod;
			
			while (isInArrayInt(mod, g_menuChoices, g_numChoices) || g_currentMod == mod)
			{
				if (++mod >= g_modCount)
					mod = 0;

				if (mod == begin)
				{
					mod = -1;
					break;
				}
			}
		}
		
		// No more mod can find
		if (mod == -1)
			break;
		
		// Add to menu
		g_menuChoices[g_numChoices++] = mod;
	}
	
	g_menuChoices[ID_EXTEND] = true;
	
	arrayset(g_voteCount, 0, sizeof g_voteCount);
	arrayset(g_hasVoted, false, sizeof g_hasVoted);
	
	remove_task(0);
	set_task(1.0, "ShowModVote", 0, _, _, "b");
	set_task(get_pcvar_float(cvar_duration), "CheckModVotes", 0);
	
	client_cmd(0, "spk Gman/Gman_Choose%d", random_num(1, 2));
}

stock makeMapVote()
{
	g_voting = 2;
	g_numChoices = 0;
	
	new map;
	new mapName[32];
	new nominations[32];
	new numNominations = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		map = g_nomination[i];
		if (map != -1)
		{
			ArrayGetString(g_mapList, map, mapName, charsmax(mapName));
			
			if (isMapInMod(mapName, g_nextMod))
				nominations[numNominations++] = map;
		}
	}
	
	new i, begin;
	new maxChoices = min(g_mapCount, MAX_MAPS_IN_VOTE);
	new maxNomination = min(numNominations, MAX_MAP_NOMINATEIONS);

	while (g_numChoices < maxChoices)
	{
		map = -1;
		
		// Get nomination maps
		if (g_numChoices < maxNomination)
		{
			i = random(numNominations);
			begin = i;
			
			while (isInArrayInt((map = nominations[i]), g_menuChoices, g_numChoices) || isCurrentMap2(map))
			{
				if (++i >= numNominations)
					i = 0;
				
				if (i == begin)
				{
					map = -1;
					break;
				}
			}
		}
		
		// Get random maps
		if (map == -1)
		{
			map = random(g_mapCount);
			begin = map;
			
			while (isInArrayInt(map, g_menuChoices, g_numChoices) || !isMapInMod2(map, g_nextMod) || isCurrentMap2(map))
			{
				if (++map >= g_mapCount)
					map = 0;
				
				if (map == begin)
				{
					map = -1;
					break;
				}
			}
		}
		
		// No more mod can find
		if (map == -1)
			break;
		
		// Add to menu
		g_menuChoices[g_numChoices++] = map;
	}
	
	get_mapname(mapName, charsmax(mapName));
	if (get_pcvar_float(cvar_timeLimit) < get_pcvar_float(cvar_extendMax) && isMapInMod(mapName, g_nextMod))
		g_menuChoices[ID_EXTEND] = true;
	else
		g_menuChoices[ID_EXTEND] = false;

	arrayset(g_voteCount, 0, sizeof g_voteCount);
	arrayset(g_hasVoted, false, sizeof g_hasVoted);
	
	remove_task(0);
	set_task(1.0, "ShowMapVote", 0, _, _, "b");
	set_task(get_pcvar_float(cvar_duration), "CheckMapVotes", 0);
	
	client_cmd(0, "spk Gman/Gman_Choose%d", random_num(1, 2));
}

stock setNextMod(mod)
{
	g_nextMod = mod;

	new prefix[32] = "";
	if (mod != -1)
		ArrayGetString(g_modPrefix, mod, prefix, charsmax(prefix));
	
	set_localinfo("mm_nextmod", prefix);
}

stock loadMods()
{
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	add(basePath, charsmax(basePath), "/modmanager");
	
	new filePath[100];
	formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);
	
	new fp = fopen(filePath, "r");

	if (!fp)
		return;
	
	new buffer[512];
	new key[64], value[448];
	new prefix[32], name[32], desc[64];
	new section = -1;

	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));

		if (!buffer[0] || buffer[0] == ';')
			continue;

		if (buffer[0] == '[')
		{
			strtok2(buffer[1], prefix, charsmax(prefix), buffer, charsmax(buffer), ']', 1);
			section++;
			continue;
		}
		
		if (section < 0)
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
			while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
			{
				trim(key);
				trim(value);
				
				formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
				loadModMaps(section, filePath);
			}
			
			if (ArraySize(g_modMaps) > section)
			{
				ArrayPushString(g_modPrefix, prefix);
				ArrayPushString(g_modName, name);
				ArrayPushString(g_modDesc, desc);
				g_modCount++;
			}
		}
	}
	
	fclose(fp);
}

stock loadModMaps(modId, const filePath[])
{
	new Array:maps;
	
	if (ArraySize(g_modMaps) <= modId)
		maps = ArrayCreate(32);
	else
		maps = ArrayGetCell(g_modMaps, modId);
	
	new fp = fopen(filePath, "r");
	if (fp)
	{
		new buffer[100], name[32];
		
		while (!feof(fp))
		{
			fgets(fp, buffer, charsmax(buffer));
			parse(buffer, name, charsmax(name));
			
			if (is_map_valid(name) && arrayFindString(maps, name) == -1)
			{
				ArrayPushString(maps, name);
			}
		}
		
		fclose(fp);
	}
	
	if (!ArraySize(maps))
	{
		ArrayDestroy(maps);
		return false;
	}
	
	if (ArraySize(g_modMaps) <= modId)
		ArrayPushCell(g_modMaps, maps);
	
	return true;
}

stock nominateMap(id, const mapName[])
{
	new index = arrayFindString(g_mapList, mapName);

	if (isCurrentMap(mapName))
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
			client_print_color(id, print_team_default, "^4[HKGSE] ^1你取消了提名 ^3%s.", mapName);
			return 1;
		}
	}
	
	g_nomination[id] = index;
	client_print_color(0, id, "^4[HKGSE] ^3%n ^1話想玩 ^3%s. (%d)", id, mapName, index);
	return 2;
}

stock getPercent(part, all, percent=100)
{
	return part * percent / all;
}

stock bool:isMapInMod(const mapName[], mod)
{
	new name[32];
	new Array:maps = ArrayGetCell(g_modMaps, mod);
	new size = ArraySize(maps);
	
	for (new i = 0; i < size; i++)
	{
		ArrayGetString(maps, i, name, charsmax(name));
		
		if (equal(name, mapName))
			return true;
	}
	
	return false;
}

stock bool:isMapInMod2(map, mod)
{
	new name[32], mapName[32];
	ArrayGetString(g_mapList, map, mapName, charsmax(mapName));
	
	new Array:maps = ArrayGetCell(g_modMaps, mod);
	new size = ArraySize(maps);
	
	for (new i = 0; i < size; i++)
	{
		ArrayGetString(maps, i, name, charsmax(name));
		
		if (equal(name, mapName))
			return true;
	}
	
	return false;
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

stock bool:isCurrentMap(const mapName[])
{
	new currentMap[32];
	get_mapname(currentMap, charsmax(currentMap));
	
	if (equal(mapName, currentMap))
		return true;
	
	return false;
}

stock bool:isCurrentMap2(mapId)
{
	new currentMap[32], mapName[32];
	get_mapname(currentMap, charsmax(currentMap));
	ArrayGetString(g_mapList, mapId, mapName, charsmax(mapName));
	
	if (equal(mapName, currentMap))
		return true;
	
	return false;
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

stock appendPluginsFile(const pluginsFile[], const fileToCopy[])
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

stock Array:getAllMaps()
{
	new Array:aMaps = ArrayCreate(32);
	new Trie:tMaps = TrieCreate();
	
	new Array:modMaps;
	new mapName[32];
	new size = 0;
	
	for (new i, j; i < g_modCount; i++)
	{
		modMaps = ArrayGetCell(g_modMaps, i);
		size = ArraySize(modMaps);
		
		for (j = 0; j < size; j++)
		{
			ArrayGetString(modMaps, j, mapName, charsmax(mapName));
			
			if (TrieKeyExists(tMaps, mapName))
				continue;
			
			ArrayPushString(aMaps, mapName);
			TrieSetCell(tMaps, mapName, 1);
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
	new size = ArraySize(which);
	new string2[64];
	
	for (new i = 0; i < size; i++)
	{
		ArrayGetString(which, i, string2, charsmax(string2));
		
		if (equal(string, string2))
			return i;
	}
	
	return -1;
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