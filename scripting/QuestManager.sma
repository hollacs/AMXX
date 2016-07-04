#include <amxmodx>
#include <nvault>

enum
{
	QUEST_AVAILABLE,
	QUEST_INPROGRESS,
	QUEST_COMPLETE
}

enum _:Forwards
{
	FW_CONDITION,
	FW_GOAL,
	FW_SHOW_STATUS,
	FW_COMPLETE,
	FW_CANCEL
}

new Array:g_questName;
new Array:g_questCondition;
new Array:g_questTarget;
new Array:g_questReward;
new Array:g_questStatus[33];
new g_questCount;

new g_menuData[33];
new g_statusText[64];

new g_forward[Forwards];
new g_return;

new g_vault;

public plugin_init()
{
	register_plugin("Quests", "0.1", "Colgate");
	
	register_clcmd("quest_menu", "cmdQuestMenu");
	
	register_menucmd(register_menuid("Quest Info"), 1023, "handleMenuInfo");
	
	g_questName = ArrayCreate(32);
	g_questCondition = ArrayCreate(64);
	g_questTarget = ArrayCreate(128);
	g_questReward = ArrayCreate(64);
	
	for (new i = 0; i < sizeof g_questStatus; i++)
		g_questStatus[i] = ArrayCreate(1);
	
	g_forward[FW_CONDITION] = CreateMultiForward("quest_check_condition", ET_CONTINUE, FP_CELL, FP_CELL);
	g_forward[FW_GOAL] = CreateMultiForward("quest_check_goal", ET_CONTINUE, FP_CELL, FP_CELL);
	g_forward[FW_SHOW_STATUS] = CreateMultiForward("quest_show_status", ET_IGNORE, FP_CELL, FP_CELL);
	g_forward[FW_COMPLETE] = CreateMultiForward("quest_on_complete", ET_IGNORE, FP_CELL, FP_CELL);
	g_forward[FW_CANCEL] = CreateMultiForward("quest_on_cancel", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_vault = nvault_open("QuestManager");
}

public plugin_end()
{
	nvault_close(g_vault);
}

public client_disconnected(id)
{
	saveData(id);
	
	for (new i = 0; i < g_questCount; i++)
	{
		setQuestStatus(id, i, QUEST_AVAILABLE);
	}
	
	g_menuData[id] = 0;
}

public client_putinserver(id)
{
	loadData(id);
}

public cmdQuestMenu(id)
{
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public showMainMenu(id)
{
	new menu = menu_create("任務", "handleMenuMain");
	
	menu_additem(menu, "可接受");
	menu_additem(menu, "進行中");
	menu_additem(menu, "已完成");
	
	menu_display(id, menu);
}

public handleMenuMain(id, menu, item)
{
	menu_destroy(menu);
	
	switch (item)
	{
		case 0: // available
			showAvailableMenu(id);
		case 1: // in progress
			showInProgressMenu(id);
		case 2: // complete
			showCompleteMenu(id);
	}
}

public showAvailableMenu(id)
{
	new text[64];
	formatex(text, charsmax(text), "可接受的任務 \y(%d 個)", countQuests(id, QUEST_AVAILABLE));
	
	new menu = menu_create(text, "handleMenuQuest");
	
	for (new i = 0; i < g_questCount; i++)
	{
		if (getQuestStatus(id, i) != QUEST_AVAILABLE)
			continue;
		
		static name[32];
		ArrayGetString(g_questName, i, name, charsmax(name));
		
		static info[2];
		info[0] = i;
		
		menu_additem(menu, name, info);
	}
	
	menu_display(id, menu);
}

public showInProgressMenu(id)
{
	new text[64];
	formatex(text, charsmax(text), "進行中的任務 \y(%d 個)", countQuests(id, QUEST_INPROGRESS));
	
	new menu = menu_create(text, "handleMenuQuest");
	
	for (new i = 0; i < g_questCount; i++)
	{
		if (getQuestStatus(id, i) != QUEST_INPROGRESS)
			continue;
		
		static name[32];
		ArrayGetString(g_questName, i, name, charsmax(name));
		
		static info[2];
		info[0] = i;
		
		menu_additem(menu, name, info);
	}
	
	menu_display(id, menu);
}

public showCompleteMenu(id)
{
	new text[64];
	formatex(text, charsmax(text), "已完成的任務 \y(%d 個)", countQuests(id, QUEST_COMPLETE));
	
	new menu = menu_create(text, "handleMenuQuest");
	
	for (new i = 0; i < g_questCount; i++)
	{
		if (getQuestStatus(id, i) != QUEST_COMPLETE)
			continue;
		
		static name[32];
		ArrayGetString(g_questName, i, name, charsmax(name));
		
		static info[2];
		info[0] = i;
		
		menu_additem(menu, name, info);
	}
	
	menu_display(id, menu);
}

public handleMenuQuest(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}
	
	new info[2], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	
	new quest = info[0];
	showQuestInfoMenu(id, quest);
}

public showQuestInfoMenu(id, quest)
{
	static menu[512], len, keys;
	
	keys = MENU_KEY_0;
	
	len = formatex(menu, charsmax(menu), "\y任務: \w%a^n^n", ArrayGetStringHandle(g_questName, quest));
	len += formatex(menu[len], 511-len, "\y條件: \w%a^n", ArrayGetStringHandle(g_questCondition, quest));
	len += formatex(menu[len], 511-len, "\y獎勵: \w%a^n", ArrayGetStringHandle(g_questReward, quest));
	len += formatex(menu[len], 511-len, "\y目標: \w%a^n", ArrayGetStringHandle(g_questTarget, quest));
	
	switch (getQuestStatus(id, quest))
	{
		case QUEST_AVAILABLE:
		{
			len += formatex(menu[len], 511-len, "^n");
			len += formatex(menu[len], 511-len, "\y1. \w接受任務^n");
			keys |= MENU_KEY_1;
		}
		case QUEST_INPROGRESS:
		{
			g_statusText[0] = 0;
			
			ExecuteForward(g_forward[FW_SHOW_STATUS], g_return, id, quest);
			
			len += formatex(menu[len], 511-len, "\y狀態: \w%s^n", g_statusText);
			len += formatex(menu[len], 511-len, "^n");
			
			if (checkQuestGoal(id, quest))
			{
				len += formatex(menu[len], 511-len, "\y1. \w完成任務^n");
				keys |= MENU_KEY_1;
			}
			else
				len += formatex(menu[len], 511-len, "\y1. \d完成任務^n");
			
			len += formatex(menu[len], 511-len, "\y2. \w放棄任務^n");
			keys |= MENU_KEY_2
		}
	}
	
	len += formatex(menu[len], 511-len, "^n\y0. \w取消");
	
	g_menuData[id] = quest;
	show_menu(id, keys, menu, -1, "Quest Info");
}

public handleMenuInfo(id, key)
{
	new quest = g_menuData[id];
	
	switch (getQuestStatus(id, quest))
	{
		case QUEST_AVAILABLE:
		{
			if (key == 0)
				acceptQuest(id, quest);
		}
		case QUEST_INPROGRESS:
		{
			if (key == 0)
			{
				if (checkQuestGoal(id, quest))
					completeQuest(id, quest);
				else
					client_print(id, print_chat, "你尚未達成目標.");
			}
			else if (key == 1)
				cancelQuest(id, quest);
		}
	}
}

saveData(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[512], len;
	for (new i = 0; i < g_questCount; i++)
	{
		len += formatex(data[len], 511-len, "%d ", getQuestStatus(id, i));
	}
	
	server_print(data);
	nvault_set(g_vault, name, data);
}

loadData(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[512];
	nvault_get(g_vault, name, data, charsmax(data));
	
	for (new i = 0; i < g_questCount; i++)
	{
		static left[5];
		argbreak(data, left, charsmax(left), data, charsmax(data));
		setQuestStatus(id, i, str_to_num(left));
	}
}

public plugin_natives()
{
	register_native("quest_register", "native_register_quest");
	register_native("quest_get_status", "native_get_status");
	register_native("quest_set_status_text", "native_set_status_text");
}

public native_register_quest()
{
	new name[32], condition[64], target[128], reward[64];
	get_string(1, name, charsmax(name));
	get_string(2, condition, charsmax(condition));
	get_string(3, target, charsmax(target));
	get_string(4, reward, charsmax(reward));
	
	ArrayPushString(g_questName, name);
	ArrayPushString(g_questCondition, condition);
	ArrayPushString(g_questTarget, target);
	ArrayPushString(g_questReward, reward);
	
	for (new i = 0; i < sizeof g_questStatus; i++)
		ArrayPushCell(g_questStatus[i], QUEST_AVAILABLE);
	
	g_questCount++;
	
	server_print("good");
	
	return g_questCount - 1;
}

public native_get_status()
{
	return getQuestStatus(get_param(1), get_param(2));
}

public native_set_status_text()
{
	new text[64];
	get_string(1, text, charsmax(text));
	
	g_statusText = text;
}

stock acceptQuest(id, quest)
{
	if (!checkQuestCondition(id, quest))
	{
		client_print(id, print_chat, "你的條件不足");
		return;
	}
	
	setQuestStatus(id, quest, QUEST_INPROGRESS);
	
	client_print(id, print_chat, "你接受了任務: %a", ArrayGetStringHandle(g_questName, quest));
}

stock cancelQuest(id, quest)
{
	setQuestStatus(id, quest, QUEST_AVAILABLE);
	
	client_print(id, print_chat, "你放棄了任務: %a", ArrayGetStringHandle(g_questName, quest));
	
	ExecuteForward(g_forward[FW_CANCEL], g_return, id, quest);
}

stock completeQuest(id, quest)
{
	setQuestStatus(id, quest, QUEST_COMPLETE);
	
	client_print(id, print_chat, "你完成了任務: %a", ArrayGetStringHandle(g_questName, quest));
	
	ExecuteForward(g_forward[FW_COMPLETE], g_return, id, quest);
}

stock checkQuestGoal(id, quest)
{
	ExecuteForward(g_forward[FW_GOAL], g_return, id, quest);
	return g_return;
}

stock checkQuestCondition(id, quest)
{
	ExecuteForward(g_forward[FW_CONDITION], g_return, id, quest);
	client_print(0, print_chat, "return %d", g_return);
	return g_return;
}

stock countQuests(id, status)
{
	new count = 0;
	
	for (new i = 0; i < g_questCount; i++)
	{
		if (status >= 0 && getQuestStatus(id, i) != status)
			continue;
		
		count++;
	}
	
	return count;
}

stock getQuestStatus(id, quest)
{
	return ArrayGetCell(g_questStatus[id], quest);
}

stock setQuestStatus(id, quest, status)
{
	ArraySetCell(g_questStatus[id], quest, status);
}