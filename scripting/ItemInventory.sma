#include <amxmodx>

#include <ItemManager>

#define VERSION "0.1"

#define NULL -1

#define MAX_CLIENTS 32
#define MAX_SLOTS 35

#define DEFAULT_SLOTS 14

new g_inventory[MAX_CLIENTS+1][MAX_SLOTS];
new g_inventory2[MAX_CLIENTS+1][MAX_SLOTS];
new g_maxSlots[MAX_CLIENTS+1] = {DEFAULT_SLOTS, ...};

public plugin_init()
{
	register_plugin("Item Inventory", VERSION, "colga");
	
	register_clcmd("inventory", "CmdInventory");
	
	for (new i = 0; i <= MAX_CLIENTS; i++)
	{
		arrayset(g_inventory[i], NULL, sizeof(g_inventory[]));
	}
}

public CmdInventory(id)
{
	ShowInventoryMenu(id);
	return PLUGIN_HANDLED;
}

public ShowInventoryMenu(id)
{
	new menu = menu_create("物品欄\d", "HandleInventoryMenu");
	
	for (new i = 0; i < g_maxSlots[id]; i++)
	{
		static text[64];
		
		new item = g_inventory[id][i];
		if (item != NULL)
		{
			static name[32];
			im_GetItemName(item, name, charsmax(name));
			
			new size = g_inventory2[id][i];
			new maxSize = GetItemMaxSize(item);
			
			formatex(text, charsmax(text), "%s \y[%d/%d]", name, size, maxSize);
		}
		else
		{
			formatex(text, charsmax(text), "\d---");
		}
		
		menu_additem(menu, text);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu, g_menuPage[id]);
}

public HandleInventoryMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (is_user_connected(id))
	{
		new menu, newMenu;
		player_menu_info(id, menu, newMenu, g_menuPage[id]);
	}
	
	if (item == MENU_EXIT)
		return;
	
	new itemId = g_inventory[id][item];
	if (itemId != NULL)
	{
		ShowSlotInfoMenu(id, item);
	}
	else
	{
		ShowInventoryMenu(id);
	}
}

public ShowSlotInfoMenu(id, slot)
{
	new item = g_inventory[id][slot];
	new size = g_inventory2[id][slot];
	new maxSize = GetItemMaxSize(item);
	
	new name[32], desc[128];
	im_GetItemName(item, name, charsmax(name));
	im_GetItemDesc(item, desc, charsmax(desc));
	
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
	
	static menu[512], len;
	len = formatex(menu, 511, "\y如何處理 \w%s \y(%d/%d) ?^n", name, size, maxSize);
	len += formatex(menu[len], 511-len, "%s^n^n", desc);
	
	len += formatex(menu[len], 511-len, "\y1. \w使用^n");
	len += formatex(menu[len], 511-len, "\y2. \w丟棄^n");
	len += formatex(menu[len], 511-len, "\y3. \w丟棄 %d 個^n", size);
	
	len += formatex(menu[len], 511-len, "^n\y0. \w返回");
}

stock GetItemMaxSize(item)
{
	new class[32];
	im_GetItemClass(item, class, charsmax(class));
	
	new value;
	if (TrieGetCell(g_itemMaxSize, class, value))
		return value;
	
	return 1;
}

for (new i = 0; i < sizeof auction_data; i++)
{
	arrayset(auction_data[i], -1, sizeof auction_data[]);
}