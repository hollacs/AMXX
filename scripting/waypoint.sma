#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1

#define MAX_WAYPOINTS 1280
#define MAX_NEIGHBORS 10

new Float:g_wayPoint[MAX_WAYPOINTS][3];
new Float:g_wayRange[MAX_WAYPOINTS];
new g_wayFlags[MAX_WAYPOINTS];
new g_wayPaths[MAX_WAYPOINTS][MAX_NEIGHBORS];
new g_wayPathFlags[MAX_WAYPOINTS][MAX_NEIGHBORS];
new g_wayCount;

new g_editor;
new bool:g_show;
new bool:g_auto;
new Float:g_autoDist = AUTO_WAYPOINT_DIST;
new Float:g_pathDist = AUTO_PATH_DIST;
new Float:g_range = WAYPOINT_RANGE;
new g_menuPage;

new g_sprArrow, g_sprBeam1, g_sprBeam4;

public plugin_precache()
{
	g_sprArrow = precache_model("sprites/arrow1.spr");
	g_sprBeam1 = precache_model("sprites/zbeam1.spr");
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
}

public plugin_init()
{
	register_plugin("Waypoint", "0.1", "penguinux");
	
	register_clcmd("wp_menu", "CmdWaypointMenu");
	
	set_task(0.5, "ShowWaypoints", 0, .flags="b");
}

public CmdWaypointMenu(id)
{
	if (g_editor && g_editor != id)
	{
		client_print(id, print_chat, "Waypoint menu is already in use.");
		return PLUGIN_HANDLED
	}
	
	g_editor = id;
	ShowWaypointMenu(id);
	return PLUGIN_HANDLED;
}

public client_disconnected(id)
{
	if (g_editor == id)
		g_editor = 0;
}

// Waypoint menu
public ShowWaypointMenu(id)
{
	new text[64];
	new menu = menu_create("Waypoint Menu", "HandleWaypointMenu");
	
	menu_additem(menu, "Create waypoint");
	menu_additem(menu, "Remove waypoint");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Remove path");
	
	formatex(text, charsmax(text), "Waypoint range: \y%.f", g_range);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto path distance: \y%.f", g_autoPathDist);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto waypoint: %s", g_auto ? "\yOn" : "\dOff");
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto waypoint distance: \y%.f", g_autoDist);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Show waypoints: %s", g_show ? "\yOn" : "\dOff");
	menu_additem(menu, text);
	
	menu_additem(menu, "Save");
	menu_additem(menu, "Load");
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu, g_menuPage);
}

public HandleWaypointMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		if (g_editor == id)
			g_editor = 0;
		
		menu_destroy(menu);
		return;
	}
	
	if (is_user_connected(id))
	{
		new dummy;
		player_menu_info(id, dummy, dummy, g_menuPage);
	}
	
	menu_destroy(menu);
	
	switch (item)
	{
		case 0: // Create waypoint
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new point = createWaypoint(origin, g_range, 0);
			if (point == NULL)
			{
				client_print(id, print_chat, "* Cannot create more waypoints.");
			}
			else
			{
				client_print(0, print_chat, "* Create waypoint #%d.", point);
			}
		}
		case 1: // Remove waypoint
		{
			new point = g_currentPoint;
			if (!isWaypointValid(point))
			{
				client_print(id, print_chat, "* Cannot find current waypoint.");
			}
			else
			{
				removePoint(point);
				client_print(0, print_chat, "* Remove waypoint #%d.", point);
			}
		}
		case 2: // Create path
		{
			ShowPathMenu(id);
			return;
		}
		case 3: // Remove path
		{
			new point = g_currentPoint;
			new point2 = g_aimPoint;
			
			if (!isPointValid(point))
			{
				client_print(id, print_chat, "Cannot find current waypoint.");
			}
			else if (!isPointValid(point2))
			{
				client_print(id, print_chat, "Cannot find aim waypoint.");
			}
			else
			{
				if (getPath(point2, point) != NULL)
				{
					removePath(point2, point);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point2, point);
				}
				else if (getPath(point, point2) != NULL)
				{
					removePath(point, point2);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point, point2);
				}
			}
		}
		case 4: // Waypoint range
		{
			ShowRangeMenu(id);
			return;
		}
		case 5: // Auto path distance
		{
			ShowPathDistMenu(id);
			return;
		}
		case 6: // Auto waypoint On/Off
		{
			g_auto = !g_auto;
		}
		case 7: // Auto waypoint distance
		{
			ShowAutoDistMenu(id);
			return;
		}
		case 8: // Show/Hide waypoints
		{
			g_show = !g_show;
		}
	}
	
	ShowWaypointMenu(id);
}

stock createWaypoint(Float:origin[3], Float:range=0.0, flags=0)
{
	new index = g_wayCount;
	if (index >= MAX_WAYPOINTS)
		return NULL;
	
	g_wayPoint[index] = origin;
	g_wayRange[index] = range;
	g_wayFlags[index] = flags;
	
	arrayset(g_wayPaths[index], NULL, MAX_NEIGHBORS);
	arrayset(g_wayPathFlags[index], 0, MAX_NEIGHBORS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock bool:isWaypointValid(point)
{
	if (point < 0 || point >= MAX_POINTS)
		return false;
	
	return true;
}