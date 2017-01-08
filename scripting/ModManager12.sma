#include <amxmodx>

#define VERSION "0.1"

#define MAX_MODS_IN_MENU 6
#define MAX_ITEMS_IN_MENU 9

enum
{
	VOTE_MOD,
	VOTE_MAP
}

new g_voting;
new Float:g_voteTime;
new Float:g_rockTime;

new g_hasRtv[33];
new g_selected[33];

new cvar_wait, cvar_ratio, cvar_ready, cvar_duration;

new g_maxClients;
new g_hudSyncObj;

new Array:g_modClass;
new Array:g_modName;
new Array:g_modMaps;
new g_modCount;

new g_itemCount;
new g_voteItems[MAX_ITEMS_IN_MENU + 1]

public plugin_precache()
{
	loadMods();
}

public plugin_init()
{
	register_plugin("Mod Manager", VERSION, "penguinux");
	
	register_clcmd("say rtv", "CmdSayRtv");
	
	register_srvcmd("test", "CmdTest");

	register_menucmd(register_menuid("Vote Mod"), 1023, "HandleModMenu");
	
	cvar_wait = register_cvar("mm_rtv_wait", "60");
	cvar_ratio = register_cvar("mm_rtv_ratio", "0.7");
	cvar_ready = register_cvar("mm_rtv_ready", "6");
	cvar_duration = register_cvar("mm_vote_duration", "15");

	g_maxClients = get_maxplayers();
	
	g_hudSyncObj = CreateHudSyncObj();
	
	set_localinfo("mm_current_mod", "zombiemod");
}

public CmdTest()
{
	new Array:maps;
	
	for (new i = 0, j; i < g_modCount; i++)
	{
		server_print("%d %a %a", i, ArrayGetStringHandle(g_modClass, i), ArrayGetStringHandle(g_modName, i));
		
		maps = ArrayGetCell(g_modMaps, i);
		for (j = 0; j < ArraySize(maps); j++)
		{
			server_print("- %a", ArrayGetStringHandle(maps, j));
		}
	}
}

public CmdSayRtv(id)
{
	if (g_voting)
	{
		client_print(id, print_chat, "投票正在進行中.");
		return PLUGIN_HANDLED;
	}

	new Float:second = g_voteTime + get_pcvar_float(cvar_wait) - get_gametime();
	if (second > 0.0)
	{
		client_print(id, print_chat, "不能在 %.f 秒內再投票.", second);
		return PLUGIN_HANDLED;
	}
	
	if (g_hasRtv[id])
	{
		g_hasRtv[id] = false;
		client_print(id, print_chat, "%n 取消了轉換地圖的投票 (剩下 %d 人)", id, countRtv());
		return PLUGIN_HANDLED;
	}	
	
	g_hasRtv[id] = true;
	
	new numPlayers = floatround(countPlayers() * get_pcvar_float(cvar_ratio)) - countRtv();
	
	client_print(id, print_chat, "%n 投票轉換地圖 (還需 %d 人)", id, numPlayers);
	
	if (numPlayers <= 0)
	{
		g_rockTime = get_gametime();
		
		g_voting = VOTE_MOD;
		
		remove_task(0);
		set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
	}
	
	return PLUGIN_HANDLED;
}

public TaskReadyToVote()
{
	if (g_vote == VOTE_MOD)
	{
		new second = floatround(g_rockTime + get_pcvar_float(cvar_ready) - get_gametime())
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
	else if (g_vote == VOTE_MAP)
	{
		new second = floatround(g_rockTime + get_pcvar_float(cvar_duration) + get_pcvar_float(cvar_ready) - get_gametime())
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

public StartModVote()
{	
	new maxItems = min(g_modCount - 1, MAX_MODS_IN_MENU);
	new mod;

	g_itemCount = 0;
	
	while (g_itemCount < maxItems)
	{
		mod = random(g_modCount);
		while (isInMenu(mod) || g_currentMod)
		{
			if (++mod >= g_modCount)
				mod = 0;
		}
		
		g_voteItems[g_itemCount++] = mod;
	}

	g_voting = VOTE_MOD;
	g_voteTime = get_gametime();
	arrayset(g_selected, -1, sizeof g_selected);
	
	remove_task(0);
	set_task(1.0, "ShowModMenu", 0, _, _, "a", get_pcvar_num(cvar_duration));
	set_task(get_pcvar_float(cvar_duration), "CheckModVotes", 0);
}

public ShowModMenu()
{
	static menu[512], len;
	len = formatex(menu, charsmax(menu), "\y投票下一個遊戲模式^n^n");
	
	new mod, keys;
	
	for (new i = 1, j; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		keys = MENU_KEY_9;
		
		for (j = 0; j < g_itemCount; j++)
		{
			mod = g_voteItems[j];
			
			if (g_selected[i] == -1)
				len += formatex(menu[len], 511-len, "\y%d. \w%a^n", j+1, ArrayGetStringHandle(g_modName, mod));
			else
			{
				new percent = countVotes(j) * 100 / countPlayers();
				len += formatex(menu[len], 511-len, "\y%d. \w%a \y(%d%%)^n", j+1, ArrayGetStringHandle(g_modName, mod), percent);
			}
			
			keys |= (1 << i);
		}
		
		new class[32];
		getCurrentModClass(class, charsmax(class));
		mod = getModByClass(class);
		
		if (g_selected[i] == -1)
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %a", ArrayGetStringHandle(g_modName, mod));
		else
		{
			new percent = countVotes(g_itemCount) * 100 / countPlayers();
			len += formatex(menu[len], 511-len, "^n\y9. \w繼續 %a \y(%d%%)", j+1, ArrayGetStringHandle(g_modName, mod), percent);
		}
		
		show_menu(i, keys, menu, 2, "Vote Mod");
	}
}

public HandleModMenu(id, key)
{
	if (g_selected[id] == -1)
	{
		if (key == 8)
		{
			g_selected[id] = g_itemCount;
		}
		else
		{
			g_selected[id] = key;
		}
	}
}

public CheckModVotes()
{
	remove_task(0);
	show_menu(0, 0, "^n", 1);
	
	new best, score, score2;
	for (new i = 0; i <= g_itemCount; i++)
	{
		score2 = countVotes(i);
		if (score2 > score)
		{
			best = i;
			score = score2;
		}
	}
	
	new same[sizeof g_voteItems], numSame = 0;
	for (new i = 0; i <= g_itemCount; i++)
	{
		score2 = countVotes(i);
		if (score == score2)
		{
			same[numSame++] = i;
		}
	}
	
	if (numSame > 1)
	{
		client_print(0, print_chat, "由於有 %d 個結果相同所以隨機選擇了其中一個.", numSame);
		best = same[random(numSame)];
	}
	
	if (best == g_itemCount)
		g_nextMod = g_currentMod
	else
		g_nextMod = g_voteItems[best];
	
	client_print(0, print_chat, "投票遊戲模式結束, 結果是 %a.", ArrayGetStringHandle(g_modName, g_nextMod));
	
	g_voting = VOTE_MAP;
	set_task(1.0, "TaskReadyToVote", 0, _, _, "b");
}

public StartMapVote()
{
	new maxItems = min(g_modCount - 1, MAX_MODS_IN_MENU);
	new mod;

	g_itemCount = 0;
	
	while (g_itemCount < maxItems)
	{
		mod = random(g_modCount);
		while (isInMenu(mod) || g_currentMod)
		{
			if (++mod >= g_modCount)
				mod = 0;
		}
		
		g_voteItems[g_itemCount++] = mod;
	}

	g_voting = VOTE_MOD;
	g_voteTime = get_gametime();
	arrayset(g_selected, -1, sizeof g_selected);
	
	remove_task(0);
	set_task(1.0, "ShowMapMenu", 0, _, _, "a", get_pcvar_num(cvar_duration));
	set_task(get_pcvar_float(cvar_duration), "CheckMapVotes", 0);
}

stock loadMods()
{
	g_modClass = ArrayCreate(32);
	g_modName = ArrayCreate(32);
	g_modMaps = ArrayCreate(32);
	
	new basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
	add(basePath, charsmax(basePath), "/modmanager");

	new filePath[100];
	formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);

	new fp = fopen(filePath, "r");
	if (fp)
	{
		new section = -1;
		new class[32], name[32];

		new buff[512];
		new key[64], value[400];

		while (!feof(fp))
		{
			fgets(fp, buff, charsmax(buff));
			
			if (!buff[0] || buff[0] == ';')
				continue;
			
			if (buff[0] == '[')
			{
				strtok2(buff, key, charsmax(key), value, charsmax(value), ']');
				trim(key);

				copy(class, charsmax(class), key[1]);
				section++;

				continue;
			}
			
			strtok2(buff, key, charsmax(key), value, charsmax(value), '=');

			trim(key);
			trim(value);
			
			if (equal(key, "name"))
			{
				copy(name, charsmax(name), value);
			}
			else if (equal(key, "maps"))
			{
				while (value[0] != 0 && strtok(value, key, charsmax(key), value, charsmax(value), ','))
				{
					trim(key);
					trim(value);
					
					formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
					loadModMaps(section, filePath);
				}
				
				// maps array is set
				if (ArraySize(g_modMaps) > section)
				{
					ArrayPushString(g_modClass, class);
					ArrayPushString(g_modName, name);
					g_modCount++;
				}
			}
		}
		
		fclose(fp);
	}
}

stock bool:loadModMaps(mod, const path[])
{
	new Array:maps;
	
	// map is not set
	if (ArraySize(g_modMaps) <= mod)
		maps = ArrayCreate(32);
	else
		maps = ArrayGetCell(g_modMaps, mod)
	
	new fp = fopen(path, "r");
	if (fp)
	{
		new buff[100], name[32];
		while (!feof(fp))
		{
			fgets(fp, buff, charsmax(buff));
			parse(buff, name, charsmax(name));
			
			if (is_map_valid(name) && arrayFindString(maps, name) == -1)
				ArrayPushString(maps, name);
		}
		
		fclose(fp);
	}
	
	if (!ArraySize(maps))
	{
		ArrayDestroy(maps);
		return false;
	}
	
	// push
	if (ArraySize(g_modMaps) <= mod)
		ArrayPushCell(g_modMaps, maps);
	
	return true;
}

stock bool:isCurrentMod(mod)
{
	new class[32], class2[32];
	getCurrentModClass(class, charsmax(class));
	ArrayGetString(g_modClass, mod, class2, charsmax(class2));
	
	if (equal(class, class2))
		return true;
	
	return false;
}

stock bool:isInMenu(item)
{
	for (new i = 0; i < g_itemCount; i++)
	{
		if (g_voteItems[i] == item)
			return true;
	}
	
	return false;
}

stock getModByClass(const class[])
{
	return arrayFindString(g_modClass, class);
}

stock getCurrentModClass(class[], len)
{
	get_localinfo("mm_current_mod", class, len);
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

stock countVotes(item)
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (g_selected[i] == item)
			count++
	}
	
	return count;
}

stock countRtv()
{
	new count = 0;
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (is_user_connected(i) && g_hasRtv[i])
			count++;
	}
	
	return count;
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