#include <amxmodx>

#pragma semicolon 1

#define VERSION "0.1"

#define MAX_MODS_IN_VOTE 6
#define MAX_MOD_NOMINATEIONS 4
#define ID_EXTEND 8

new Array:g_modPrefix;
new Array:g_modName;
new Array:g_modDesc;
new Array:g_modMaps;
new g_modCount;

new Array:g_mapList;

new g_voting;
new g_currentMod = 0;
new Float:g_voteTime, Float:g_rockTime;
new g_menuChoices[9], g_numChoices;

new g_maxClients;
new g_hudSyncObj;

// Player variables
new bool:g_hasRtv[33];
new g_nomination[33] = {-1, ...};

// CVars
new cvar_wait, cvar_ratio, cvar_ready, cvar_duration;

public plugin_precache()
{
	g_modPrefix = ArrayCreate(32);
	g_modName = ArrayCreate(32);
	g_modDesc = ArrayCreate(64);
	g_modMaps = ArrayCreate(1);
	g_mapList = ArrayCreate(32);
	
	loadMods();
	g_mapList = getAllMaps();
	g_currentMod = random(g_modCount);
}

public plugin_init()
{
	register_plugin("Mod Manager", VERSION, "penguinux");
	
	register_clcmd("say rtv", "CmdSayRtv");
	register_clcmd("say", "CmdSay");
	
	register_srvcmd("mods", "CmdMods");

	cvar_wait = register_cvar("mm_rtv_wait", "120");
	cvar_ratio = register_cvar("mm_rtv_ratio", "0.7");
	cvar_ready = register_cvar("mm_rtv_ready", "7.0");
	cvar_duration = register_cvar("mm_vote_duration", "15.0");
	
	g_maxClients = get_maxplayers();
	g_hudSyncObj = CreateHudSyncObj();
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
		
		g_voting = 1;
		
		remove_task(0);
		set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
		
		client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42)^"");
		//client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42) cap(s50)^"");
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
	new size = ArraySize(g_mapList);

	for (new i = 0; i < size; i++)
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
			remove_task(0);
		}
	}
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
					
					server_print("%a nominated", ArrayGetStringHandle(g_modName, j));
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
		
		if (mod == -1)
			break;
		
		g_menuChoices[g_numChoices++] = mod;
	}
	
	g_menuChoices[ID_EXTEND] = true;
	
	server_print("current mod is %a", ArrayGetStringHandle(g_modName, g_currentMod));
	
	for (new i = 0; i < g_numChoices; i++)
	{
		mod = g_menuChoices[i];
		server_print("%d. %a", i+1, ArrayGetStringHandle(g_modName, mod));
	}
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

stock bool:isInArrayInt(value, const array[], size, start=0)
{
	for (new i = start; i < size; i++)
	{
		if (array[i] == value)
			return true;
	}
	
	return false;
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