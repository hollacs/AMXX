#include <amxmodx>

#define VERSION "0.1"

new Array:g_itemName;
new Array:g_itemDesc;
new Array:g_itemClass;
new Array:g_itemFlags;
new g_itemCount;

public plugin_init()
{
	register_plugin("Item Manager", VERSION, "colga");
	
	g_itemName = ArrayCreate(32);
	g_itemDesc = ArrayCreate(128);
	g_itemClass = ArrayCreate(32);
	g_itemFlags = ArrayCreate(1);
}

public plugin_natives()
{
	register_library("ItemManager");
	
	register_native("im_CreateItem", "_CreateItem");
	register_native("im_GetItemName", "_GetItemName");
	register_native("im_GetItemDesc", "_GetItemDesc");
	register_native("im_GetItemClass", "_GetItemClass");
	register_native("im_GetItemFlags", "_GetItemFlags");
	register_native("im_FindItemByClass", "_FindItemByClass");
	register_native("im_GetItemCount", "_GetItemCount");
}

public _CreateItem(pluginId, numParams)
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

public _GetItemName(pluginId, numParams)
{
	new index = get_param(1);
	if (index < 0 || index >= g_itemCount)
	{
		log_error(AMX_ERR_NATIVE, "Item index out of range");
		return false;
	}
	
	new name[32];
	ArrayGetString(g_itemName, index, name, charsmax(name));
	
	new len = get_param(3);
	set_string(2, name, len);
	return true;
}

public _GetItemDesc(pluginId, numParams)
{
	new index = get_param(1);
	if (index < 0 || index >= g_itemCount)
	{
		log_error(AMX_ERR_NATIVE, "Item index out of range");
		return false;
	}
	
	new desc[128];
	ArrayGetString(g_itemDesc, index, desc, charsmax(desc));
	
	new len = get_param(3);
	set_string(2, desc, len);
	return true;
}

public _GetItemClass(pluginId, numParams)
{
	new index = get_param(1);
	if (index < 0 || index >= g_itemCount)
	{
		log_error(AMX_ERR_NATIVE, "Item index out of range");
		return false;
	}
	
	new class[128];
	ArrayGetString(g_itemClass, index, class, charsmax(class));
	
	new len = get_param(3);
	set_string(2, class, len);
	return true;
}

public _GetItemFlags(pluginId, numParams)
{
	new index = get_param(1);
	if (index < 0 || index >= g_itemCount)
	{
		log_error(AMX_ERR_NATIVE, "Item index out of range");
		return false;
	}
	
	return ArrayGetCell(g_itemFlags, index);
}

public _FindItemByClass()
{
	new class[32];
	get_string(1, class, charsmax(class));
	
	return ArrayFindString(g_itemClass, class);
}

public _GetItemCount()
{
	return g_itemCount;
}