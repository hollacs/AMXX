#include <amxmodx>
#include <nvault>

#define VERSION "0.2"

new Array:g_adminTag, Array:g_adminFlags;
new g_adminCount;

new g_nick[33][32];
new g_format[128];
new g_vault;

new CvarNick, CvarMinLen, CvarMaxLen;

public plugin_init()
{
	register_plugin("AMX Chat", VERSION, "penguinux")
	
	register_srvcmd("amx_chat_tag", "CmdChatTag");
	
	register_clcmd("say", "CmdSay");
	register_clcmd("say_team", "CmdSay");
	
	register_message(get_user_msgid("SayText"), "MsgSayText");
	
	CvarNick = register_cvar("chat_nick_enable", "1");
	CvarMinLen = register_cvar("chat_nick_min_len", "3");
	CvarMaxLen = register_cvar("chat_nick_max_len", "16");
	
	g_adminTag = ArrayCreate(32);
	g_adminFlags = ArrayCreate(1);
	
	g_vault = nvault_open("amx_chat");
}

public plugin_end()
{
	nvault_close(g_vault);
}

public client_putinserver(id)
{
	new address[40];
	if (isAuthIdValid(address))
		get_user_authid(id, address, charsmax(address));
	else
		get_user_ip(id, address, charsmax(address), 1);
	
	nvault_get(g_vault, address, g_nick[id], charsmax(g_nick[]));
}

public client_disconnected(id)
{
	if (g_nick[id][0])
	{
		new address[40];
		if (isAuthIdValid(address))
			get_user_authid(id, address, charsmax(address));
		else
			get_user_ip(id, address, charsmax(address), 1);
		
		nvault_set(g_vault, address, g_nick[id]);
	}
	
	g_nick[id][0] = 0;
}

public CmdChatTag(id)
{
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	
	new flags = read_flags(arg);
	
	read_argv(2, arg, charsmax(arg));
	if (!strlen(arg))
	{
		server_print( "Tag name cannot be empty");
		return PLUGIN_HANDLED;
	}
	
	ArrayPushString(g_adminTag, arg);
	ArrayPushCell(g_adminFlags, flags);
	g_adminCount++;
	return PLUGIN_HANDLED;
}

public CmdSay(id)
{
	new arg[64];
	read_argv(1, arg, charsmax(arg));
	
	if (get_pcvar_num(CvarNick))
	{
		new cmd[16], nick[32];
		argbreak(arg, cmd, charsmax(cmd), nick, charsmax(nick));
		
		if (equal(cmd, "/msg"))
		{
			if (g_nick[id][0] && !nick[0])
			{
				g_nick[id][0] = 0;
				client_print(id, print_chat, "你的個人稱號已重設");
				return PLUGIN_HANDLED;
			}
			
			new len = strlen(nick);
			new minLen = get_pcvar_num(CvarMinLen);
			new maxLen = get_pcvar_num(CvarMaxLen);
			
			if (len < minLen || len > maxLen)
			{
				client_print(id, print_chat, "請使用 %d 至 %d 個字元作為稱號", minLen, maxLen);
				return PLUGIN_HANDLED;
			}
			
			replace_string(nick, charsmax(nick), "%", " ");
			
			copy(g_nick[id], charsmax(g_nick[]), nick);
			client_print(id, print_chat, "你的個人稱號設定為 ^"%s^"", g_nick[id]);
			return PLUGIN_HANDLED;
		}
	}
	
	formatSay(id);
	return PLUGIN_CONTINUE;
}

public MsgSayText(msgId, msgDest, id)
{
	new string1[32];
	get_msg_arg_string(2, string1, charsmax(string1));
	
	if (!equal(string1, "#Cstrike_Chat", 13))
		return;
	
	if (g_format[0])
	{
		if(equal(string1, "#Cstrike_Chat_All"))
			set_msg_arg_string(2, "%s1 ^1:  %s2");
		
		set_msg_arg_string(3, g_format);
	}
}

stock formatSay(id)
{
	g_format[0] = 0;
	
	new len;
	new index = checkAdminFlags(id);
	if (index != -1)
		len = formatex(g_format, charsmax(g_format), "^4%a ", ArrayGetStringHandle(g_adminTag, index));
	
	if (g_nick[id][0])
		len += formatex(g_format[len], 255-len, "^1[^3%s^1] ", g_nick[id]);
	
	if (len > 0)
	{
		new name[32];
		get_user_name(id, name, charsmax(name));
		
		len += formatex(g_format[len], 255-len, "^3%s", name);
	}
}

stock checkAdminFlags(id)
{
	for(new i = 0; i < g_adminCount; i++)
	{
		if(get_user_flags(id) & ArrayGetCell(g_adminFlags, i))
			return i;
	}
	
	return -1;
}

stock bool:isAuthIdValid(const authId[])
{
	if (equali(authId, "STEAM_ID_PENDING") ||
		equali(authId, "STEAM_ID_LAN") ||
		equali(authId, "HLTV") ||
		equali(authId, "4294967295") ||
		equali(authId, "VALVE_ID_LAN") ||
		equali(authId, "VALVE_ID_PENDING"))
		return false;
	
	return true
}