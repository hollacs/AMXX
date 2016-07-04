#include <amxmodx>

#include <ItemManager>
#include <ItemInventory>

new const ITEM_NAME[][] = {"蘋果", "橙", "牙齒", "化石", "精靈球", "恢復藥", "卡片", "假牙"};

new const ITEM_DESC[][] = 
{
	"恢復體力 20",
	"恢復體力 30",
	"人類的牙齒",
	"恐龍的化石",
	"可以收服小精靈",
	"恢復體力 50",
	"不是誰的卡片",
	"沒有描述"
};

new const ITEM_CLASS[][] = 
{
	"item_apple", 
	"item_orange", 
	"item_tooth", 
	"item_oldthing", 
	"item_pokemon", 
	"item_medkit", 
	"item_card",
	"item_test"
};

new g_itemId[sizeof ITEM_CLASS];

public plugin_init()
{
	register_plugin("Item Random", "0.1", "Colgate");
	
	for (new i = 0; i < sizeof ITEM_NAME; i++)
	{
		g_itemId[i] = im_CreateItem(ITEM_NAME[i], ITEM_DESC[i], ITEM_CLASS[i], 0);
	}
	
	ii_SetItemMaxSize("item_apple", 3);
	ii_SetItemMaxSize("item_orange", 5);
	ii_SetItemMaxSize("item_tooth", 12);
	ii_SetItemMaxSize("item_oldthing", 10);
	ii_SetItemMaxSize("item_card", 10);
	
	register_clcmd("give_item", "CmdGiveItem");
	register_clcmd("drop_item", "CmdDropItem");
	register_clcmd("list_items", "CmdListItems");
}

public CmdGiveItem(id)
{
	new arg1[32], arg2[10];
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	
	new amount = str_to_num(arg2);
	ii_GiveNamedItem(id, arg1, amount, false);
}

public CmdDropItem(id)
{
	new arg1[32], arg2[10];
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	
	new amount = str_to_num(arg2);
	ii_DropNamedItem(id, arg1, amount);
}

public CmdListItems(id)
{
	client_print(id, print_console, "#  [name]  [class]  [max size]  [flags]")
	
	new num = im_GetItemCount();
	
	for (new i = 0; i < num; i++)
	{
		static name[32], class[32];
		im_GetItemName(i, name, charsmax(name));
		im_GetItemClass(i, class, charsmax(class));
		
		new flags = im_GetItemFlags(i);
		new maxSize = ii_GetItemMaxSize(i);
		
		client_print(id, print_console, "#%d  ^"%s^"  ^"%s^"  %d  %d", i, name, class, maxSize, flags);
	}
}

public II_ShowSlotInfo(id, slot, item)
{
	if (item == g_itemId[2])
	{
		ii_SetMenuKeys(MENU_KEY_4);
		ii_SetMenuText("\y4. \w製造假牙 (需要 32 隻牙齒)^n");
	}
}

public II_SelectSlotInfo(id, key, slot, item)
{
	if (item == g_itemId[2] && (key+1) == 4)
	{
		if (ii_GetItemCount(id, item) < 32)
		{
			client_print(id, print_chat, "你沒有足夠的牙齒.");
		}
		else
		{
			ii_DropNamedItem(id, "item_tooth", 32);
			ii_GiveNamedItem(id, "item_test", 1, false);
			
			client_print(id, print_chat, "你製造了 1 個假牙.");
		}
	}
}

public II_UseItem(id, slot, item)
{
	// do something here
}