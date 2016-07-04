#include <amxmodx>

#define VERSION "0.1"

#define PLAYER_BIT(%0) (1 << (%0 & 31))

new const BAN_REASON[][] =
{
	"外掛/BUG",
	"辱罵"
};

new g_menuPlayers[33];
new g_menuPlayer[33];
new g_vote[33];

new g_maxClients;

new CvarBanRatio, CvarBanType, CvarBanMinute;

public plugin_init()
{
	register_plugin("Vote Ban", VERSION, "colga");
	
	register_clcmd("say /voteban", "CmdVoteBan");
	register_clcmd("voteban_reason", "CmdVoteBanReason");
	
	CvarBanRatio = register_cvar("voteban_ratio", "0.7");
	CvarBanType = register_cvar("voteban_type", "0");
	CvarBanMinute = register_cvar("voteban_minute", "20");
	
	g_maxClients = get_maxplayers();
}

public CmdVoteBan(id)
{
	ShowMainMenu(id);
	return PLUGIN_HANDLED;
}

public CmdVoteBanReason(id)
{
	new player = g_menuPlayer[id];
	if (!player)
	{
		client_print(id, print_chat, "玩家已經離開");
		return PLUGIN_HANDLED;
	}
	
	new reason[32];
	read_argv(1, reason, charsmax(reason));
	
	VoteBanPlayer(id, player, reason);
	return PLUGIN_HANDLED;
}

public ShowMainMenu(id)
{
	new menu = menu_create("Voteban Menu", "HandleMainMenu");
	
	menu_additem(menu, "投票封禁");
	menu_additem(menu, "顯示誰投票封禁了我");
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleMainMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	switch (item + 1)
	{
		case 1: ShowVoteBanMenu(id);
		case 2: ShowWhoMenu(id);
	}
	
	menu_destroy(menu);
}

public ShowVoteBanMenu(id)
{
	new numPlayers = countPlayers();
	new maxVotes = floatround(numPlayers * get_pcvar_float(CvarBanRatio));
	
	new menu = menu_create("投票封禁", "HandleVoteBanMenu");
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		new numVotes = countVotes(i);
		
		static buffer[64], info[2];
		
		if (isVotedPlayer(id, i))
			formatex(buffer, charsmax(buffer), "\d+\y%n\d#%d \y(%d/%d) \r%d%%", i, i, numVotes, maxVotes, getPercent(numVotes, numPlayers));
		else
			formatex(buffer, charsmax(buffer), "\w%n\d#%d \y(%d/%d) \r%d%%", i, i, numVotes, maxVotes, getPercent(numVotes, numPlayers));
		
		info[0] = i;
		menu_additem(menu, buffer, info);
		g_menuPlayers[id] |= PLAYER_BIT(i);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleVoteBanMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	new info[2], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	new player = info[0];
	
	// player not in menu
	if (~g_menuPlayers[id] & PLAYER_BIT(player))
	{
		client_print(id, print_chat, "玩家已經離開.");
		return;
	}
	
	if (isVotedPlayer(id, player))
	{
		client_print(0, print_chat, "%n 取消投票封禁 %n.", id, player);
		g_vote[id] &= ~PLAYER_BIT(player);
	}
	else
	{
		ShowReasonMenu(id, player);
	}
}

public ShowReasonMenu(id, player)
{
	new buffer[64];
	formatex(buffer, charsmax(buffer), "封禁 \d#%d \w%n \y的原因:", player, player);
	
	new menu = menu_create(buffer, "HandleReasonMenu");
	
	for (new i = 0; i < sizeof BAN_REASON; i++)
	{
		menu_additem(menu, BAN_REASON[i]);
	}
	
	menu_additem(menu, "其他 \d(請填寫)");
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
	
	g_menuPlayer[id] = player;
}

public HandleReasonMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT)
	{
		ShowVoteBanMenu(id);
		return;
	}
	
	new player = g_menuPlayer[id];
	if (!player)
	{
		client_print(id, print_chat, "玩家已經離開");
		return;
	}
	
	if (item < sizeof BAN_REASON)
	{
		VoteBanPlayer(id, player, BAN_REASON[item]);
	}
	else
	{
		client_cmd(id, "messagemode voteban_reason");
	}
}

public ShowWhoMenu(id)
{
	new menu = menu_create("誰投票封禁了我", "HandleWhoMenu");
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (isVotedPlayer(i, id))
		{
			static name[32];
			get_user_name(i, name, charsmax(name));
			
			menu_additem(menu, name);
		}
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleWhoMenu(id, menu, item)
{
	menu_destroy(menu);
}

public client_disconnected(id)
{
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (g_menuPlayers[i] & PLAYER_BIT(id))
			g_menuPlayers[i] &= ~PLAYER_BIT(id);
		
		if (g_menuPlayer[i] == id)
			g_menuPlayer[i] = 0;
		
		if (isVotedPlayer(i, id))
			g_vote[i] &= ~PLAYER_BIT(id);
	}
	
	g_menuPlayer[id] = 0;
	g_menuPlayers[id] = 0;
	g_vote[id] = 0;
}

VoteBanPlayer(id, player, const reason[])
{
	g_vote[id] |= PLAYER_BIT(player);
	
	new numPlayers = countPlayers();
	new numVotes = countVotes(player);
	new maxVotes = floatround(numPlayers * get_pcvar_float(CvarBanRatio));
	
	if (numVotes >= maxVotes)
	{
		BanPlayer(player, reason);
	}
	else
	{
		client_print(0, print_chat, "%n 投票封禁 %n (原因: %s)", id, player, reason);
	}
}

BanPlayer(id, const reason[])
{
	new message[192];
	formatex(message, charsmax(message), "You have been vote banned by :");
	
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (isVotedPlayer(i, id))
		{
			format(message, charsmax(message), "%s ^"%n^"", message, i);
		}
	}
	
	client_print(id, print_console, message);
	
	new banType = get_pcvar_num(CvarBanType);
	if (banType == 0)
	{
		server_cmd("kick #%d ^"You have been kicked by (See console)^"", get_user_userid(id));
		client_print(0, print_chat, "%n 已被投票踢出 (原因: %s).", id, reason);
	}
	else
	{
		new minute = get_pcvar_num(CvarBanMinute);
		
		server_cmd("kick #%d ^"You have been banned for %d minutes by (See console)^"", get_user_userid(id), minute);
		
		if (banType == 1)
		{
			new authid[40];
			get_user_authid(id, authid, charsmax(authid));
			
			server_cmd("banid %d %s; wait; writeid", minute, authid);
		}
		else
		{
			new address[40];
			get_user_ip(id, address, charsmax(address), 1);
			
			server_cmd("addip %d %s; wait; writeip", minute, address);
		}
		
		client_print(0, print_chat, "%n 已被投票封禁 %d 分鐘 (原因: %s).", id, minute, reason);
	}
}

SaveData(id)
{
	new address[32];
	get_user_ip(id, address, charsmax(address), 1);
	
	if (ArrayFindString(g_addressList, address) == -1)
		ArrayPushString(g_addressList, address);
	
	
}

stock bool:isVotedPlayer(id, player)
{
	return bool:(g_vote[id] & PLAYER_BIT(player));
}

stock getPercent(part, all, percent=100)
{
	return part * percent / all;
}

stock getBanPercent(id, percent=100)
{
	getPercent(countVotes(id), countPlayers());
}

stock countVotes(id)
{
	new count = 0;
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (isVotedPlayer(i, id))
			count++;
	}
	
	return count;
}

stock countPlayers()
{
	new count = 0;
	for (new i = 1; i <= g_maxClients; i++)
	{
		if (is_user_connected(i))
			count++;
	}
	
	return count;
}