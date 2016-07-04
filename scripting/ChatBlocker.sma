#include <amxmodx>

#define VERSION "0.1"

#define PLAYERBIT(%0) (1 << (%0 & 31))

#define isBlockedPlayer(%1,%2) (g_blocked[%1] & PLAYERBIT(%2))
#define blockPlayer(%1,%2) (g_blocked[%1] |= PLAYERBIT(%2))
#define unblockPlayer(%1,%2) (g_blocked[%1] &= ~PLAYERBIT(%2))

new g_blocked[33];
new g_menuPlayers[33];

new CvarReplace;

public plugin_init()
{
	register_plugin("Chat Blocker", VERSION, "colga");
	
	register_clcmd("chat_blocker", "CmdChatBlocker");
	register_clcmd("say /blockchat", "CmdChatBlocker");
	
	CvarReplace = register_cvar("cb_replace", "");
	
	register_message(get_user_msgid("SayText"), "MsgSayText");
}

public CmdChatBlocker(id)
{
	ShowChatBlockerMenu(id);
	return PLUGIN_HANDLED;
}

public MsgSayText(msgId, msgDest, id)
{
	if (msgDest == MSG_ALL || msgDest == MSG_BROADCAST)
		return PLUGIN_CONTINUE;
	
	new string1[32]
	get_msg_arg_string(2, string1, charsmax(string1));
	
	if (!equal(string1, "#Cstrike_Chat_", 14))
		return PLUGIN_CONTINUE;
	
	new sender = get_msg_arg_int(1);
	
	if (isBlockedPlayer(id, sender))
	{
		new replace[32];
		get_pcvar_string(CvarReplace, replace, charsmax(replace));
		
		if (!replace[0])
			return PLUGIN_HANDLED;
		
		set_msg_arg_string(4, replace);
	}
	
	return PLUGIN_CONTINUE;
}

public client_disconnect(id)
{
	for (new i = 1; i <= 32; i++)
	{
		if (g_menuPlayers[i] & PLAYERBIT(id))
			g_menuPlayers[i] &= ~PLAYERBIT(id);
		
		if (isBlockedPlayer(i, id))
			unblockPlayer(i, id);
	}
	
	g_blocked[id] = 0;
}

public ShowChatBlockerMenu(id)
{
	new menu = menu_create("Chat Blocker", "HandleChatBlockerMenu");
	
	new players[32], numPlayers;
	get_players(players, numPlayers, "ch");
	
	g_menuPlayers[id] = 0;
	
	for (new i = 0; i < numPlayers; i++)
	{
		static player;
		player = players[i];
		
		if (id == player)
			continue;
		
		static name[32];
		static text[64], info[10];
		get_user_name(player, name, charsmax(name));
		
		if (isBlockedPlayer(id, player))
			formatex(text, charsmax(text), "%s \y(Blocked)", name);
		else
			copy(text, charsmax(text), name);
		
		num_to_str(player, info, charsmax(info));
		
		menu_additem(menu, text, info);
		g_menuPlayers[id] |= PLAYERBIT(player);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleChatBlockerMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	new info[10], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	
	new player = str_to_num(info);
	client_print(0, print_chat, "player = %d", player);
	
	if (~g_menuPlayers[id] & PLAYERBIT(player))
	{
		client_print(id, print_center, "Player no longer connected.");
	}
	else
	{
		new name[32];
		get_user_name(player, name, charsmax(name));
		
		if (isBlockedPlayer(id, player))
		{
			unblockPlayer(id, player);
			client_print(id, print_chat, "You have been unblocked chat for ^"%s^"", name);
		}
		else
		{
			blockPlayer(id, player);
			client_print(id, print_chat, "You have been blocked chat for ^"%s^"", name);
		}
	}
	
	menu_destroy(menu);
}