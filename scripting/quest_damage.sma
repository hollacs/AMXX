#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <QuestManager>

new g_quest[3];
new Float:g_damage[33][3];

public plugin_init()
{
	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");
	
	g_quest[0] = quest_register("自殘(一)", "無", "自殘造成50傷害", "100$");
	g_quest[1] = quest_register("自殘(二)", "無", "自殘造成200傷害", "200$");
	g_quest[2] = quest_register("自殘(三)", "無", "自殘造成400傷害", "300$");
}

public OnPlayerTakeDamage(id, inflictor, attacker, Float:damage)
{
	if (id == attacker || attacker == 0)
	{
		for (new i = 0; i < 3; i++)
		{
			if (quest_in_progress(id, g_quest[i]))
				g_damage[id][i] += damage;
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
			formatex(text, charsmax(text), "已造成 %.f 傷害", g_damage[id][i]);
			quest_set_status_text(text);
		}
	}
}

public quest_check_goal(id, quest)
{
	if (quest == g_quest[0] && g_damage[id][0] >= 50)
		return true;
	if (quest == g_quest[1] && g_damage[id][1] >= 200)
		return true;
	if (quest == g_quest[2] && g_damage[id][2] >= 400)
		return true;
	
	return false;
}

public quest_on_cancel(id, quest)
{
	for (new i = 0; i < 3; i++)
	{
		if (quest == g_quest[i])
			g_damage[id][i] = 0.0;
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