#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <QuestManager>

new g_quest[3];
new g_suicided[33][3];

public plugin_init()
{
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled");
	
	g_quest[0] = quest_register("自殺(一)", "無", "自殺1次", "100$");
	g_quest[1] = quest_register("自殺(二)", "無", "自殺5次", "200$");
	g_quest[2] = quest_register("自殺(三)", "無", "自殺10次", "300$");
}

public OnPlayerKilled(id, attacker)
{
	if (id == attacker || attacker == 0)
	{
		for (new i = 0; i < 3; i++)
		{
			if (quest_in_progress(id, g_quest[i]))
				g_suicided[id][i]++;
		}
	}
}

public quest_check_condition(id, quest)
{
	if (quest == g_quest[0] || quest == g_quest[1] || quest == g_quest[2])
		return true;
	
	return false;
}

public quest_show_status(id, quest)
{
	for (new i = 0; i < 3; i++)
	{
		if (quest == g_quest[i])
		{
			static text[64];
			formatex(text, charsmax(text), "已自殺 %d 次", g_suicided[id][i]);
			quest_set_status_text(text);
		}
	}
}

public quest_check_goal(id, quest)
{
	if (quest == g_quest[0] && g_suicided[id][0] >= 1)
		return true;
	if (quest == g_quest[1] && g_suicided[id][1] >= 5)
		return true;
	if (quest == g_quest[2] && g_suicided[id][2] >= 10)
		return true;
	
	return false;
}

public quest_on_cancel(id, quest)
{
	for (new i = 0; i < 3; i++)
	{
		if (quest == g_quest[i])
			g_suicided[id][i] = 0;
	}
}

public quest_on_complete(id, quest)
{
	if (quest == g_quest[0])
		cs_set_user_money(id, cs_get_user_money(id) + 100);
	if (quest == g_quest[1])
		cs_set_user_money(id, cs_get_user_money(id) + 200);
	if (quest == g_quest[2])
		cs_set_user_money(id, cs_get_user_money(id) + 300);
}