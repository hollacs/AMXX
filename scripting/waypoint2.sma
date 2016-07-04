#include <amxmodx>
#include <fakemeta>

#define NULL -1

#define MAX_POINTS 512
#define MAX_PATHS 8

new Float:g_nodePos[MAX_POINTS][3];
new g_nodePath[MAX_POINTS][MAX_PATHS];
new g_nodeCount;

new g_sprBeam1, g_sprBeam4, g_sprArrow;

public plugin_precache()
{
	g_sprBeam1 = precache_model("sprites/zbeam1.spr");
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
	g_sprArrow = precache_model("sprites/arrow1.spr");
}

public plugin_init()
{
	register_plugin("Way point", "0.1", "Colgate");
	
	register_clcmd("wp_menu", "cmdWayPointMenu");
}

public cmdWayPointMenu(id)
{
	static text[64];
	
	new menu = menu_create("Waypoint menu", "handleWayPointMenu");
	
	menu_additem(menu, "Create node");
	menu_additem(menu, "Remove node");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Create two-way path");
	menu_additem(menu, "Remove path");
	
	if (g_auto)
		menu_additem(menu, "Auto waypoint: \yOn");
	else
		menu_additem(menu, "Auto waypoint: \rOff");
	
	formatex(text, charsmax(text), "Auto waypoint distance: %.f", g_autoDist);
	menu_additem(menu, text);
	
	menu_additem(menu, "Save");
	menu_additem(menu, "Load");
	
	menu_display(id, menu);
	
	g_editor = id;
	return PLUGIN_HANDLED;
}

public handleWayPointMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT)
	{
		g_editor = 0;
		return;
	}
	
	new Float:origin[3];
	pev
	
	switch (item)
	{
		case 0:
		{
			new point = createPoint(origin);
			if (point == NULL)
				client_print(0, print_chat, "Can't create more points.");
			else
			{
				
			}
		}
	}
}

stock createPoint(Float:origin[3])
{
	new index = g_wayCount;
	if (index >= MAX_POINTS)
		return NULL;
	
	g_wayPoint[index] = origin;
	arrayset(g_wayPath[index], NULL, MAX_PATHS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock