#include <amxmodx>

#include <ItemManager>

#define VERSION "0.1"

#define NULL -1

#define MAX_SLOTS 28

enum Forwards
{
	FWD_USE_ITEM,
	FWD_USE_ITEM_POST,
	FWD_SHOW_SLOT_INFO,
	FWD_SELECT_SLOT_INFO
};

new Trie:g_itemMaxSize;

new g_inventory[33][MAX_SLOTS];
new g_inventory2[33][MAX_SLOTS];
new g_maxSlots[33];

new g_menuKeys;
new g_menuText[256];

new g_menuSlot[33];
new g_menuPage[33];

new g_forward[Forwards];
new g_return;

public plugin_init()
{
	register_plugin("Item Inventory", VERSION, "Colgate");
	
	register_clcmd("inventory", "CmdInventory");
	
	register_menucmd(register_menuid("Slot Info"), 1023, "HandleSlotInfoMenu");
	
	for (new i = 0; i < sizeof g_inventory; i++)
	{
		arrayset(g_inventory[i], NULL, sizeof g_inventory[]);
		arrayset(g_inventory2[i], 0, sizeof g_inventory2[]);
		g_maxSlots[i] = 14;
	}
	
	g_itemMaxSize = TrieCreate();
	
	g_forward[FWD_USE_ITEM] = CreateMultiForward("II_UseItem", ET_STOP, FP_CELL, FP_CELL, FP_CELL);
	g_forward[FWD_USE_ITEM_POST] = CreateMultiForward("II_UseItem_Post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_forward[FWD_SHOW_SLOT_INFO] = CreateMultiForward("II_ShowSlotInfo", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_forward[FWD_SELECT_SLOT_INFO] = CreateMultiForward("II_SelectSlotInfo", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
}

public CmdInventory(id)
{
	ShowInventoryMenu(id);
	return PLUGIN_HANDLED;
}

public ShowInventoryMenu(id)
{
	new menu = menu_create("Item Inventory", "HandleInventoryMenu");
	
	for (new i = 0; i < g_maxSlots[id]; i++)
	{
		static text[64];
		
		new itemId = g_inventory[id][i];
		if (itemId != NULL)
		{
			new itemSize = g_inventory2[id][i];
			new maxSize = getItemMaxSize(itemId);
			
			static itemName[32];
			im_GetItemName(itemId, itemName, charsmax(itemName));
			
			formatex(text, charsmax(text), "%s \y[%d/%d]", itemName, itemSize, maxSize);
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
	
	new menu, newmenu;
	player_menu_info(id, menu, newmenu, g_menuPage[id]);
	
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
	new itemId   = g_inventory[id][slot];
	new itemSize = g_inventory2[id][slot];
	new maxSize  = getItemMaxSize(itemId);
	
	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
	
	static name[32], desc[128];
	im_GetItemName(itemId, name, charsmax(name));
	im_GetItemDesc(itemId, desc, charsmax(desc));
	
	static menu[512], len;
	len = formatex(menu, 511, "\y如何處理 \w%s \y(%d/%d個) ?^n", name, itemSize, maxSize);
	len += formatex(menu[len], 511-len, "\w%s^n^n", desc);
	
	len += formatex(menu[len], 511-len, "\y1. \w使用^n");
	len += formatex(menu[len], 511-len, "\y2. \w丟棄^n");
	len += formatex(menu[len], 511-len, "\y3. \w丟棄 %d 個^n", itemSize);
	
	// Support addional text and keys
	g_menuKeys = 0;
	g_menuText[0] = 0;
	ExecuteForward(g_forward[FWD_SHOW_SLOT_INFO], g_return, id, slot, itemId);
	
	keys |= g_menuKeys;
	len += formatex(menu[len], 511-len, g_menuText);
	
	len += formatex(menu[len], 511-len, "^n\y0. \w返回");
	
	g_menuSlot[id] = slot;
	show_menu(id, keys, menu, -1, "Slot Info");
}

public HandleSlotInfoMenu(id, key)
{
	if (key == 9)
	{
		ShowInventoryMenu(id);
		return;
	}
	
	new slot = g_menuSlot[id];
	
	new itemId = g_inventory[id][slot];
	if (itemId == NULL)
		return;
	
	new itemName[32];
	im_GetItemName(itemId, itemName, charsmax(itemName));
	
	switch (key)
	{
		case 0:
		{
			useSlotItem(id, slot);
		}
		case 1:
		{
			dropSlotItem(id, slot);
			client_print(id, print_chat, "你丟棄了 1 個 %s.", itemName);
		}
		case 2:
		{
			new count = g_inventory2[id][slot];
			
			dropSlotItemAll(id, slot);
			client_print(id, print_chat, "你丟棄了 %d 個 %s.", count, itemName);
		}
		default:
		{
			ExecuteForward(g_forward[FWD_SELECT_SLOT_INFO], g_return, id, key, slot, itemId);
		}
	}
}

public plugin_natives()
{
	register_library("ItemInventory");
	
	register_native("ii_SetItemMaxSize", "native_set_item_max_size");
	register_native("ii_GetItemMaxSize", "native_get_item_max_size");
	register_native("ii_GetItemCount", "native_get_item_count");
	register_native("ii_GiveNamedItem", "native_give_named_item");
	register_native("ii_DropNamedItem", "native_drop_named_item");
	register_native("ii_GetSlotItem", "native_get_slot_item");
	register_native("ii_GetSlotSize", "native_get_slot_size");
	register_native("ii_SetMenuKeys", "native_set_menu_keys");
	register_native("ii_SetMenuText", "native_set_menu_text");
}

public native_set_item_max_size()
{
	new class[32];
	get_string(1, class, charsmax(class));
	
	new itemId = im_FindItemByClass(class);
	if (itemId != NULL)
	{
		TrieSetCell(g_itemMaxSize, class, get_param(2));
	}
}

public native_get_item_max_size()
{
	new itemId = get_param(1);
	
	return getItemMaxSize(itemId);
}

public native_get_item_count()
{
	new id = get_param(1);
	new itemId = get_param(2);
	
	new count = 0;
	for (new i = 0; i < g_maxSlots[id]; i++)
	{
		if (g_inventory[id][i] == itemId)
			count += g_inventory2[id][i];
	}
	
	return count;
}

public native_give_named_item()
{
	new player = get_param(1);
	
	new class[32];
	get_string(2, class, charsmax(class));
	
	return giveNamedItem(player, class, get_param(3), bool:get_param(4));
}

public native_drop_named_item()
{
	new player = get_param(1);
	
	new class[32];
	get_string(2, class, charsmax(class));
	
	return dropNamedItem(player, class, get_param(3));
}

public native_get_slot_item()
{
	new id = get_param(1);
	new slot = get_param(2);
	
	return g_inventory[id][slot];
}

public native_get_slot_size()
{
	new id = get_param(1);
	new slot = get_param(2);
	
	return g_inventory2[id][slot];
}

public native_set_menu_keys()
{
	g_menuKeys = get_param(1);
}

public native_set_menu_text()
{
	new text[256];
	get_string(1, text, charsmax(text));
	
	g_menuText = text;
}

stock giveNamedItem(id, const class[], amount, bool:checkSpace)
{
	new itemId = im_FindItemByClass(class);
	if (itemId != NULL)
	{
		new maxSize = getItemMaxSize(itemId);
		new numLeft = amount;
		
		if (checkSpace)
		{
			for (new i = 0; i < g_maxSlots[id]; i++)
			{
				if (numLeft <= 0)
					break;
				
				if (g_inventory[id][i] == NULL
				|| (g_inventory[id][i] == itemId && g_inventory2[id][i] < maxSize))
				{
					new count = min(maxSize - g_inventory2[id][i], numLeft);
					numLeft -= count;
				}
			}
			
			if (numLeft > 0)
				return -1;
		}
		
		numLeft = amount;
		
		for (new i = 0; i < g_maxSlots[id]; i++)
		{
			if (numLeft <= 0)
				break;
			
			if (g_inventory[id][i] == NULL
			|| (g_inventory[id][i] == itemId && g_inventory2[id][i] < maxSize))
			{
				new count = min(maxSize - g_inventory2[id][i], numLeft);
				g_inventory[id][i] = itemId;
				g_inventory2[id][i] += count;
				numLeft -= count;
			}
		}
		
		return amount - numLeft;
	}
	
	return -1;
}

stock dropNamedItem(id, const class[], amount)
{
	new itemId = im_FindItemByClass(class);
	if (itemId != NULL)
	{
		new numLeft = amount;
		
		for (new i = (g_maxSlots[id]-1); i >= 0; i--)
		{
			if (numLeft <= 0)
				break;
			
			if (g_inventory[id][i] == itemId)
			{
				if (numLeft >= g_inventory2[id][i])
				{
					numLeft -= g_inventory2[id][i];
					g_inventory[id][i] = NULL;
					g_inventory2[id][i] = 0;
				}
				else
				{
					g_inventory2[id][i] -= numLeft;
					numLeft = 0;
				}
			}
		}
	
		return amount - numLeft;
	}
	
	return NULL;
}

stock useSlotItem(id, slot)
{
	new itemId = g_inventory[id][slot];
	
	ExecuteForward(g_forward[FWD_USE_ITEM], g_return, id, slot, itemId);
	
	dropSlotItem(id, slot);
	
	ExecuteForward(g_forward[FWD_USE_ITEM_POST], g_return, id, slot, itemId);
}

stock dropSlotItem(id, slot, amount=1)
{
	g_inventory2[id][slot] -= amount;
	
	if (g_inventory2[id][slot] <= 0)
	{
		g_inventory[id][slot] = NULL;
		g_inventory2[id][slot] = 0;
	}
}

stock dropSlotItemAll(id, slot)
{
	g_inventory[id][slot] = NULL;
	g_inventory2[id][slot] = 0;
}

stock getItemMaxSize(item)
{
	new class[32], value;
	im_GetItemClass(item, class, charsmax(class));
	
	if (TrieGetCell(g_itemMaxSize, class, value))
		return value;
	
	return 1;
}