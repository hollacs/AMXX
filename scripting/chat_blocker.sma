#include <amxmodx>

new g_lastMessage[33][128];
new Float:g_lastMsgTime[33];

public plugin_init()
{
	register_clcmd("say", "CmdSay");
	register_clcmd("say_team", "CmdSay");
}

public CmdSay(id)
{
	new arg[128];
	read_argv(1, arg, charsmax(arg));
	
	if (equal(arg, g_lastMessage[id]) && get_gametime() < g_lastMsgTime[id] + 60.0)
		return PLUGIN_HANDLED;
	
	g_lastMessage[id] = arg;
	g_lastMsgTime[id] = get_gametime();
	return PLUGIN_CONTINUE;
}