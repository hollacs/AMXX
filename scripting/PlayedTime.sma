#include <amxmodx>
#include <nvault>

new g_vault;

new Float:g_joinedTime[33];
new g_playedMinutes[33];

public plugin_init()
{
	register_clcmd("played_time", "CmdPlayedTime");
	register_clcmd("add_hour", "CmdAddHour");
	
	g_vault = nvault_open("PlayedTime");
}

public CmdPlayedTime(id)
{
	new strTime[32];
	formatMinutes(getPlayedMinutes(id), strTime, charsmax(strTime));
	
	client_print(id, print_chat, "你玩了 %s", strTime);
}

public CmdAddHour(id)
{
	g_playedMinutes[id] += 60;
}

public client_putinserver(id)
{
	loadData(id);
	
	g_joinedTime[id] = get_gametime();
}

public client_disconnected(id)
{
	saveData(id);
	
	g_playedMinutes[id] = 0;
}

loadData(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	g_playedMinutes[id] = nvault_get(g_vault, name);
}

saveData(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[16];
	num_to_str(getPlayedMinutes(id), data, charsmax(data));
	
	nvault_set(g_vault, name, data);
}

stock getPlayedMinutes(id)
{
	return g_playedMinutes[id] + floatround((get_gametime() - g_joinedTime[id]) / 60);
}

stock formatMinutes(mins, output[], len)
{
	new minutes = mins;
	
	new hours = minutes / 60;
	minutes -= hours * 60;
	
	new bool:addSpace = false;
	if (hours > 0)
	{
		format(output, len, "%d小時", hours);
		addSpace = true;
	}
	
	if (minutes > 0 || hours <= 0)
	{
		if (addSpace) add(output, len, " ");
		format(output, len, "%s%d分鐘", output, minutes);
	}
}