#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1
#define MAX_POINTS 1280
#define MAX_PATHS 10

#define getArrayBits(%1,%2) (%1[%2 >> 5] & (1 << (%2 & 31)))
#define setArrayBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define unsetArrayBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

enum (<<= 1)
{
    WAYPOINT_JUMP = 1,
	WAYPOINT_DUCK
};

enum (<<= 1)
{
	WAYPATH_JUMP = 1,
	WAYPATH_DUCK
};

new const WAYPOINT_FLAGS[][] = {"Jump", "Duck"};

// HAPYY AMXX ^O^
new Float:g_wayPoint[MAX_POINTS][3];
new Float:g_wayRange[MAX_POINTS][MAX_PATHS];
new g_wayPaths[MAX_POINTS][MAX_PATHS];
new g_wayPathFlags[MAX_POINTS][MAX_PATHS];
new g_wayFlags[MAX_POINTS];
new g_wayCount;

new g_editor;
new Float:g_range;
new g_auto;
new Float:g_autoDist;
new Float:g_autoPathDist;
new g_menuPage;

new g_currentPoint;
new g_aimPoint;

new g_sprBeam1, g_sprBeam4, g_sprArrow;

public plugin_precache()
{
	g_sprBeam1 = precache_model("sprites/zbeam1.spr");
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
	g_sprArrow = precache_model("sprites/arrow1.spr");
}

public plugin_init()
{
	register_plugin("Waypoint", "0.1", "penguinux");
	
	register_clcmd("wp_menu", "CmdWaypointMenu");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	
	set_task(0.5, "DrawWaypoints", 0, .flags="b");
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

public ShowWaypointMenu(id)
{
	new text[64];
	new menu = menu_create("Waypoint Menu", "HandleWaypointMenu");
	
	menu_additem(menu, "Create waypoint");
	menu_additem(menu, "Remove waypoint");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Remove path");
	
	formatex(text, charsmax(text), "Set waypoint flags", g_autoPathDist);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Waypoint range: \y%.f", g_range);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto path distance: \y%.f", g_autoPathDist);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto waypoint: %s", g_auto ? "\yOn" : "\dOff");
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto waypoint distance: \y%.f", g_autoDist);
	menu_additem(menu, text);
	
	if (g_editor)
		formatex(text, charsmax(text), "Hide waypoints");
	else
		formatex(text, charsmax(text), "Show waypoints");
		
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
			ShowTypeMenu(id);
			return;
		}
		case 1: // Remove waypoint
		{
			new point = g_currentPoint;
			if (!isPointValid(point))
				client_print(0, print_chat, "Cannot find current waypoint.");
			else
			{
				removePoint(point);
				client_print(0, print_chat, "Remove waypoint #%d.", point);
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
				client_print(0, print_chat, "Cannot find current waypoint.");
			}
			else if (!isPointValid(point2))
			{
				client_print(0, print_chat, "Cannot find aim waypoint.");
			}
			else
			{
				if (getPath(point2, point))
				{
					removePath(point2, point);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point2, point);
				}
				else if (getPath(point, point2))
				{
					removePath(point, point2);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point, point2);
				}
			}
		}
		case 4:
		{
			
		}
		case 5: // Waypoint range
		{
			ShowRangeMenu(id);
		}
	}
	
	ShowWaypointMenu(id);
}

public ShowTypeMenu(id)
{
	static const types[] = {0, 1};
	
	new menu = menu_create("Waypoint Type", "HandleTypeMenu");
	
	new info[11]; info[0] = 0;
	menu_additem(menu, "Normal", info);
	
	for (new i = 0; i < sizeof(types); i++)
	{
		new j = types[i];
		num_to_str((1 << j), info, charsmax(info));
		menu_additem(menu, WAYPOINT_FLAGS[j], info);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleTypeMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		menu_destroy(menu);
		return;
	}
	
	new info[11], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	new Float:origin[3];
	pev(id, pev_origin, origin);
	
	new flags = str_to_num(info);
	new point = createPoint(origin, g_range, flags);
	
	if (point == NULL)
		client_print(0, print_chat, "Cannot create more waypoints.");
	else
		client_print(0, print_chat, "Create waypoint #%d", point);
	
	ShowWaypointMenu(id);
}

public ShowPathMenu(id)
{
	new menu = menu_create("Create Path", "HandlePathMenu");
	
	menu_additem(menu, "Outgoing path");
	menu_additem(menu, "Incoming path");
	menu_additem(menu, "Both ways");
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandlePathMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT || g_editor != id)
		return;
	
	new point = g_currentPoint;
	if (!isPointValid(point))
	{
		client_print(id, print_chat, "Cannot find current waypoint.");
		return;
	}
	
	new point2 = g_aimPoint;
	if (!isPointValid(point2))
	{
		client_print(id, print_chat, "Cannot find aim waypoint.");
		return;
	}
	
	switch (item)
	{
		case 0: // Outgoing
		{
			if (createPath(point, point2))
			{
				removePath(point2, point);
				client_print(id, print_chat, "Connect waypoints #%d -> #%d.", point, point2);
			}
		}
		case 1: // Incoming
		{
			if (createPath(point2, point))
			{
				removePath(point, point2);
				client_print(id, print_chat, "Connect waypoints #%d -> #%d.", point2, point);
			}
		}
		case 2: // Both ways
		{
			createPath(point, point2);
			createPath(point2, point);
			
			client_print(id, print_chat, "Connect waypoints #%d <-> #%d.", point, point2);
		}
	}
}

public ShowRangeMenu(id)
{
	static const ranges[] = {0, 8, 16, 32, 48, 64, 80, 96, 128};
	
	new menu = menu_create("Waypoint Range", "HandleRangeMenu");
	new text[32], info[4];
	
	for (new i = 0; i < sizeof ranges; i++)
	{
		formatex(text, charsmax(text), "");
		num_to_str(ranges[i], info, charsmax(info));
		menu_additem(menu, text, info);
	}
}

stock bool:isPointValid(point)
{
	if (point < 0 || point >= MAX_POINTS)
		return false;
	
	return true;
}

stock createPoint(Float:origin[3], Float:range=0.0, flags=0)
{
	new index = g_wayCount;
	if (index >= MAX_POINTS)
		return NULL;
	
	g_wayPoint[index] = origin;
	g_wayRange[index] = range;
	g_wayFlags[index] = flags;
	arrayset(g_wayPaths[index], NULL, MAX_PATHS);
	arrayset(g_wayPathFlags[index], 0, MAX_PATHS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock bool:getPath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new index = g_wayPaths[point][i];
		if (index == point2)
			return true;
	}
	
	return false;
}

stock bool:createPath(point, point2)
{
	if (point == point2)
		return false;
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPaths[point][i] == point2)
			return false;
	}
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPaths[point][i] == NULL)
		{
			g_wayPaths[point][i] = point2;
			return true;
		}
	}
	
	return false;
}

stock bool:removePath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPaths[point][i] == point2)
		{
			g_wayPaths[point][i] = NULL;
			return true;
		}
	}
	
	return false;
}