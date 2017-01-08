#include <amxmodx>

new Array:g_messages;
new Array:g_hasShown;
new g_msgCount;

new cvar_delayMin, cvar_delayMax;

public plugin_init()
{
	register_plugin("Announce", "0.1", "penguin");

	register_srvcmd("announce_add", "CmdAddMessage");

	cvar_delayMin = register_cvar("announce_delay_min", "20");
	cvar_delayMax = register_cvar("announce_delay_max", "70");
	
	g_messages = ArrayCreate(192);
	g_hasShown = ArrayCreate(1);
	
	set_task(5.0, "FirstStart");
}

public FirstStart()
{
	set_task(random_float(get_pcvar_float(cvar_delayMin), get_pcvar_float(cvar_delayMax)), "Announce");
}

public Announce()
{
	new message[192];
	ArrayGetString(g_messages, g_msgIndex, message, charsmax(message));
	
	client_print_color(0, print_team_default, message);
	g_msgIndex++;
	
	set_task(random_float(get_pcvar_float(cvar_delayMin), get_pcvar_float(cvar_delayMax)), "Announce");
}

public CmdAddMessage()
{
	new arg[192];
	read_args(arg, charsmax(arg));
	remove_quotes(arg);
	
	if (!arg[0])
		return PLUGIN_HANDLED;
	
	replace_string(arg, charsmax(arg), "\x01", "^x01");
	replace_string(arg, charsmax(arg), "\x03", "^x03");
	replace_string(arg, charsmax(arg), "\x04", "^x04");
	
	ArrayPushString(g_messages, arg);
	g_msgCount++;
	
	return PLUGIN_HANDLED;
}