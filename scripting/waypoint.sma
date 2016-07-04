#include <amxmodx>
#include <fakemeta>
#include <xs>

#define MAX_POINTS 1024
#define MAX_PATHS 8

new Float:g_wayPoint[MAX_POINTS][3];
new g_wayPath[MAX_POINTS][MAX_PATHS];
new g_wayCount;

new bool:g_auto;
new Float:g_autoDist;

public plugin_init()
{
	register_plugin("Way Point", "0.1", "Colgate");
	
	register_clcmd("wp_menu", "cmdMenuWayPoint");
}

public cmdMenuWayPoint(id)
{
	new menu = menu_create("Waypoint Menu", "handleMenuWayPoint");
	
	menu_additem(menu, "Create node");
	menu_additem(menu, "Remove node");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Create two-way path");
	menu_additem(menu, "Remove path");
	
	if (g_auto)
		menu_additem(menu, "Auto waypoint mode: \yON");
	else
		menu_additem(menu, "Auto waypoint mode: \rOFF");
	
	new text[64];
	formatex(text, charsmax(text), "Auto waypoint distance: %.f", g_autoDist);
	
	menu_display(id, menu);
}