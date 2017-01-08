#include <amxmodx>
#include <amxmisc>

new Array:g_announce;
new g_announceCount;
new g_announceId;

new cvarDelayMin, cvarDelayMax;

public plugin_init()
{
	register_plugin("Announce", "0.1", "Colgate");
	
	cvarDelayMin = register_cvar("announce_delay_min", "20.0");
	cvarDelayMax = register_cvar("announce_delay_max", "70.0");
	
	g_announce = ArrayCreate(192);
	readConfigs();
	
	g_announceId = random(g_announceCount);
	set_task(random_float(get_pcvar_float(cvarDelayMin), get_pcvar_float(cvarDelayMax)), "Announce");
}

public Announce()
{
	if (g_announceId >= g_announceCount)
		g_announceId = 0;
	
	new message[192];
	ArrayGetString(g_announce, g_announceId, message, charsmax(message));
	
	client_print_color(0, print_team_default, message);
	g_announceId++;
	
	remove_task();
	set_task(random_float(get_pcvar_float(cvarDelayMin), get_pcvar_float(cvarDelayMax)), "Announce");
}

readConfigs()
{
	new filePath[100];
	get_configsdir(filePath, charsmax(filePath));
	add(filePath, charsmax(filePath), "/announce.ini");
	
	new file = fopen(filePath, "r");
	if (file)
	{
		while(!feof(file))
		{
			static data[256];
			fgets(file, data, charsmax(data));
			
			if (!data[0] || data[0] == 239 || data[0] == ';')
				continue;
			
			trim(data);
			
			replace_all(data, charsmax(data), "^^1", "^1");
			replace_all(data, charsmax(data), "^^3", "^3");
			replace_all(data, charsmax(data), "^^4", "^4");
			
			ArrayPushString(g_announce, data);
			g_announceCount++;
		}
		
		fclose(file);
	}
}