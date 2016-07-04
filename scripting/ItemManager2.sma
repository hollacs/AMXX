#include <amxmodx>

#define VERSION "0.1"

new Array:g_itemName;
new Array:g_itemDesc;
new Array:g_itemClass;
new Array:g_itemFlags;
new g_itemCount;

public plugin_init()
{
	register_plugin("Item Manager", VERSION, "Colgate");
	
	g_itemName = ArrayCreate(32);
	g_itemDesc = ArrayCreate(128);
	g_itemClass = ArrayCreate(32);
	g_itemFlags = ArrayCreate(1);
}

public plugin_natives()
{
	register_library("ItemManager");
	
	register_native("im_CreateItem", "native_create_item");
	register_native("im_GetItemName", "native_get_item_name");
	register_native("im_GetItemDesc", "native_get_item_desc");
	register_native("im_GetItemClass", "native_get_item_class");
	register_native("im_GetItemFlags", "native_get_item_flags");
	register_native("im_FindItemByClass", "native_find_item_by_class");
	register_native("im_GetItemCount", "native_get_item_count");
}

public native_create_item()
{
	new name[32], desc[128], class[32];
	get_string(1, name, charsmax(name));
	get_string(2, desc, charsmax(desc));
	get_string(3, class, charsmax(class));
	
	ArrayPushString(g_itemName, name);
	ArrayPushString(g_itemDesc, desc);
	ArrayPushString(g_itemClass, class);
	ArrayPushCell(g_itemFlags, get_param(4));
	
	g_itemCount++;
	return g_itemCount - 1;
}

public native_get_item_name()
{
	new index = get_param(1);
	
	new name[32];
	ArrayGetString(g_itemName, index, name, charsmax(name));
	
	set_string(2, name, get_param(3));
}

public native_get_item_desc()
{
	new index = get_param(1);
	
	new desc[32];
	ArrayGetString(g_itemDesc, index, desc, charsmax(desc));
	
	set_string(2, desc, get_param(3));
}

public native_get_item_class()
{
	new index = get_param(1);
	
	new class[32];
	ArrayGetString(g_itemClass, index, class, charsmax(class));
	
	set_string(2, class, get_param(3));
}

public native_get_item_flags()
{
	new index = get_param(1);
	
	return ArrayGetCell(g_itemFlags, index);
}

public native_find_item_by_class()
{
	new class[32];
	get_string(1, class, charsmax(class));
	
	return ArrayFindString(g_itemClass, class);
}

public native_get_item_count()
{
	return g_itemCount;
}