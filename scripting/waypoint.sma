#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <waypoint_const>

//#define DEBUG

#define NULL -1

#define MAX_POINT_TO_SHOW 50 // Max waypoints that will be shown

#define AUTO_DIST_DEFAULT 124.0 // Default value of auto waypoint distance
#define AUTOPATH_DIST_DEFAULT 190.0 // Default value of auto path distance
#define WAYPOINT_RANGE_DEFAULT 32.0 // Default value of waypoint range
#define WAYPOINT_RANGE_SIDES 6 // Number of polygon sides for displaying waypoint range
#define HEURISTIC 1

new const WAYPOINT_FLAG_NAME[][] = {"Duck", "Camp"};

// HAPYY AMXX ^O^
new Float:g_wayPoint[MAX_POINTS][3];
new Float:g_wayRange[MAX_POINTS];
new g_wayFlags[MAX_POINTS];
new g_wayPaths[MAX_POINTS][MAX_PATHS];
new g_wayPathFlags[MAX_POINTS][MAX_PATHS];
new g_wayCount = 0;

new g_editor = 0;
new g_point;
new g_flags;
new bool:g_show = false;
new bool:g_auto = false;
new Float:g_autoDist = AUTO_DIST_DEFAULT;
new Float:g_autoPathDist = AUTOPATH_DIST_DEFAULT;
new Float:g_range = WAYPOINT_RANGE_DEFAULT;
new g_menuPage = 0;

new g_currentPoint = NULL;
new g_aimPoint = NULL;

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
	
	set_task(0.5, "ShowWaypoints", 0, .flags="b");
	
	loadWaypoints();
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

public OnPlayerPreThink(id)
{
	if (g_auto && g_editor == id && is_user_alive(id) && (pev(id, pev_flags) & FL_ONGROUND))
	{
		new Float:origin[3];
		pev(id, pev_origin, origin);
		
		new point = getClosestPoint(origin, g_autoDist);
		if (point == NULL)
		{
			new flags = g_flags;
			if (pev(id, pev_flags) & FL_DUCKING)
				flags |= WAYPOINT_DUCK;
			
			point = createPoint(origin, g_range, flags);
			if (point != NULL)
			{
				connectPoint(point);
				client_print(0, print_chat, "Create waypoint #%d", point);
			}
		}
	}
}

// Show waypoints
public ShowWaypoints()
{
	if (!g_editor || !g_show)
		return;
	
	new Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
	g_currentPoint = getClosestPoint(origin, 64.0);
	
	static points[MAX_POINTS], Float:dists[MAX_POINTS];
	// Insertion sort
	{
		new p, Float:d;
		for (new i = 0, j; i < g_wayCount; i++)
		{
			j = i-1;
			p = i;
			d = get_distance_f(origin, g_wayPoint[i]);
			
			points[i] = p;
			dists[i] = d;
			
			while (j >= 0 && dists[j] > d)
			{
				points[j+1] = points[j];
				dists[j+1] = dists[j];
				j = j - 1;
			}
			
			points[j+1] = p;
			dists[j+1] = d;
		}
	}
	
	new shown[MAX_POINTS >> 5];
	{
		new index, flags, Float:range;
		new Float:size, color[3], color2[3];
		new Float:pos[3], Float:pos1[3], Float:pos2[3];
		new string[64];
		
		new maxPoints = min(g_wayCount, MAX_POINT_TO_SHOW);
		for (new i = 0, j, k; i < maxPoints; i++)
		{
			index = points[i];
			flags = g_wayFlags[index];
			pos = g_wayPoint[index];
			
			// Default style
			size = 36.0;
			color = {0, 255, 0};
			
			if (flags & WAYPOINT_DUCK)
				size = 20.0;
			
			if (index == g_currentPoint)
			{
				range = g_wayRange[index];
				
				getPointFlagsString(index, string, charsmax(string));
				
				set_hudmessage(0, 200, 50, 0.3, 0.25, 0, 0.0, 0.5, 0.0, 0.0, 4);
				show_hudmessage(g_editor, "Waypoint #%d^nXYZ: {%.2f, %.2f, %.2f}^nFlags: %s^nRange: %.f", 
								index, pos[0], pos[1], pos[2], string, g_wayRange[index]);
				
				if (range <= 0.0)
				{
					// Draw a cross if waypoint has no range 
					drawLine(g_editor, 
							pos[0]+16.0, pos[1], pos[2]-size/2.0,
							pos[0]-16.0, pos[1], pos[2]-size/2.0,
							g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
					
					drawLine(g_editor, 
							pos[0], pos[1]+16.0, pos[2]-size/2.0,
							pos[0], pos[1]-16.0, pos[2]-size/2.0,
							g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
				}
				else
				{
					// Draw a polygon to display waypoint range
					
					// first
					pos2[0] = floatcos(360 / 6 * float(WAYPOINT_RANGE_SIDES) - 180.0, degrees) * range + g_wayPoint[index][0];
					pos2[1] = floatsin(360 / 6 * float(WAYPOINT_RANGE_SIDES) - 180.0, degrees) * range + g_wayPoint[index][1];
					pos2[2] = g_wayPoint[index][2] - size / 2.0;
					
					for (j = 1; j <= WAYPOINT_RANGE_SIDES; j++)
					{
						pos1[0] = floatcos(360 / 6 * float(j) - 180.0, degrees) * range + g_wayPoint[index][0];
						pos1[1] = floatsin(360 / 6 * float(j) - 180.0, degrees) * range + g_wayPoint[index][1];
						pos1[2] = g_wayPoint[index][2] - size / 2.0;
						
						drawLine2(g_editor, pos1, pos2, g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
						
						pos2 = pos1;
					}
				}
				
				// Draw paths for current waypoint
				for (j = 0; j < MAX_PATHS; j++)
				{
					k = g_wayPaths[index][j];
					if (k == NULL)
						continue;
					
					pos2 = g_wayPoint[k];
					// Both way
					if (getPath(k, index) != NULL)
					{
						color2 = {200, 200, 0};
						drawLine2(g_editor, pos, pos2,
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 200, 0}, .alpha=255, .scroll=5);
					}
					// Outcoming
					else
					{
						color2 = {200, 50, 0};
						drawLine2(g_editor, pos, pos2,
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 50, 0}, .alpha=255, .scroll=5);
					}
					
					if (g_wayPathFlags[index][j] & WAYPATH_JUMP)
					{
						color2 = {0, 100, 200};
					}

					drawLine2(g_editor, pos, pos2,
						g_sprBeam1, .life=5, .width=10, .noise=5, .color=color2, .alpha=255, .scroll=5);
				}
				
				// Draw incoming paths
				for (j = 0; j < g_wayCount; j++)
				{
					if (getPath(j, index) != NULL && getPath(index, j) == NULL)
					{
						drawLine2(g_editor, pos, g_wayPoint[j],
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 0, 0}, .alpha=255, .scroll=5);
					}
				}
			}
			
			// Draw a waypoint
			drawLine(g_editor,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-size,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+size,
					g_sprBeam4, .life=5, .width=20, .color=color, .alpha=255);
			
			setArrayBits(shown, index);
		}
	}
	
	// Get aim waypoint
	g_aimPoint = getAimPoint(g_editor, 16.0, shown);
	
	if (isPointValid(g_aimPoint))
	{
		drawLine2(g_editor, origin, g_wayPoint[g_aimPoint],
			g_sprArrow, .life=5, .width=20, .color={200, 200, 200}, .alpha=255);
	}
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
			
			new flags = g_flags;
			if (pev(id, pev_flags) & FL_DUCKING)
				flags |= WAYPOINT_DUCK;
				
			new point = createPoint(origin, g_range, flags);
			if (point == NULL)
				client_print(id, print_chat, "Maximum number of waypoints reached.");
			else
			{
				connectPoint(point);
				client_print(0, print_chat, "Create waypoint #%d.", point);
			}
		}
		case 1: // Remove waypoint
		{
			new point = g_currentPoint;
			if (!isPointValid(point))
				client_print(id, print_chat, "Cannot find current waypoint.");
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
		case 4:
		{
			ShowFlagsMenu(id);
			return;
		}
		case 5: // Waypoint range
		{
			ShowRangeMenu(id);
			return;
		}
		case 6: // Auto path distance
		{
			ShowPathDistMenu(id);
			return;
		}
		case 7: // Auto waypoint On/Off
		{
			g_auto = !g_auto;
		}
		case 8: // Auto waypoint distance
		{
			ShowAutoDistMenu(id);
			return;
		}
		case 9: // Show/Hide waypoints
		{
			g_show = !g_show;
		}
		case 10: // Save
		{
			saveWaypoints();
			client_print(0, print_chat, "Saved %d waypoints.", g_wayCount);
		}
		case 11: // Load
		{
			g_wayCount = 0;
			loadWaypoints();
			client_print(0, print_chat, "Loaded %d waypoints.", g_wayCount);
		}
	}
	
	ShowWaypointMenu(id);
}

// Create path menu
public ShowPathMenu(id)
{
	new menu = menu_create("Create Path", "HandlePathMenu");
	
	menu_additem(menu, "Outgoing path");
	menu_additem(menu, "Incoming path");
	menu_additem(menu, "Both ways");
	
	new point = g_currentPoint;
	
	if (isPointValid(point))
	{
		menu_additem(menu, "Jump path (Outgoing)");
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandlePathMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT || g_editor != id)
		return;
	
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
		switch (item)
		{
			case 0: // Outgoing
			{
				removePath(point2, point);
				
				if (createPath(point, point2) != NULL)
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point, point2);
			}
			case 1: // Incoming
			{
				removePath(point, point2);
				
				if (createPath(point2, point) != NULL)
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point2, point);
			}
			case 2: // Both ways
			{
				createPath(point, point2);
				createPath(point2, point);
				
				client_print(0, print_chat, "Connect waypoints #%d <-> #%d.", point, point2);
			}
			case 3: // Jump path
			{
				if (!addPathFlags2(point, point2, WAYPATH_JUMP))
				{
					client_print(0, print_chat, "Both points are not connected.");
				}
				else
				{
					// Jump path has only one direction, so remove the jump flag for another path
					removePathFlags2(point2, point, WAYPATH_JUMP);
					client_print(0, print_chat, "Add jump flag to path #%d -> #%d.", point, point2);
				}
			}
		}
	}
	
	ShowWaypointMenu(id);
}

public ShowFlagsMenu(id)
{
	new flags;
	new point = g_currentPoint;
	if (!isPointValid(point))
	{
		flags = g_flags;
	}
	else
	{
		flags = g_wayFlags[point];
	}
	
	new text[64], info[16];
	if (isPointValid(point))
		formatex(text, charsmax(text), "Waypoint Flags \r#%d\y", point);
	else
		formatex(text, charsmax(text), "Waypoint Flags \rANY\y");
	
	new menu = menu_create(text, "HandleFlagsMenu");
	
	for (new i = 0; i < sizeof WAYPOINT_FLAG_NAME; i++)
	{
		if (flags & (1 << i))
			formatex(text, charsmax(text), "\w%s", WAYPOINT_FLAG_NAME[i]);
		else
			formatex(text, charsmax(text), "\d%s", WAYPOINT_FLAG_NAME[i]);
		
		num_to_str((1 << i), info, charsmax(info));
		menu_additem(menu, text, info);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
	
	g_point = point;
}

public HandleFlagsMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		if (g_editor == id)
			ShowWaypointMenu(id);
		
		menu_destroy(menu);
		return;
	}
	
	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	new flag = str_to_num(info);
	
	if (!isPointValid(g_point))
	{
		if (g_flags & flag)
			g_flags &= ~flag;
		else
			g_flags |= flag;
	}
	else
	{
		if (g_wayFlags[g_point] & flag)
			g_wayFlags[g_point] &= ~flag;
		else
			g_wayFlags[g_point] |= flag;
	}
	
	ShowFlagsMenu(id);
}

// Waypoint range menu
public ShowRangeMenu(id)
{
	static const ranges[] = {0, 8, 16, 32, 48, 64, 80, 96, 128};
	
	new menu = menu_create("Waypoint Range", "HandleRangeMenu");
	new info[4];
	
	for (new i = 0; i < sizeof ranges; i++)
	{
		num_to_str(ranges[i], info, charsmax(info));
		menu_additem(menu, info, info);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleRangeMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		if (g_editor == id)
			ShowWaypointMenu(id);
		
		menu_destroy(menu);
		return;
	}
	
	new info[4], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	new point = g_currentPoint;
	g_range = str_to_float(info);
	
	if (isPointValid(point))
	{
		g_wayRange[point] = g_range;
		client_print(0, print_chat, "Waypoint #%d range change to %.f.", point, g_range);
	}
	
	ShowWaypointMenu(id);
}

// Choose auto path distance menu
public ShowPathDistMenu(id)
{
	static distances[] = {0, 100, 120, 140, 160, 190, 220, 250};
	
	new menu = menu_create("Auto Path Distance", "HandlePathDistMenu");
	new info[4];
	
	for (new i = 0; i < sizeof distances; i++)
	{
		num_to_str(distances[i], info, charsmax(info));
		menu_additem(menu, info, info);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandlePathDistMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		if (g_editor == id)
			ShowWaypointMenu(id);
		
		menu_destroy(menu);
		return;
	}
	
	new info[4], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_autoPathDist = str_to_float(info);
	ShowWaypointMenu(id);
}

// Choose auto waypoint distance menu
public ShowAutoDistMenu(id)
{
	static distances[] = {100, 108, 116, 124, 132, 148, 164, 180, 200};
	
	new menu = menu_create("Auto Waypoint Distance", "HandleAutoDistMenu");
	new info[4];
	
	for (new i = 0; i < sizeof distances; i++)
	{
		num_to_str(distances[i], info, charsmax(info));
		menu_additem(menu, info, info);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleAutoDistMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		if (g_editor == id)
			ShowWaypointMenu(id);
		
		menu_destroy(menu);
		return;
	}
	
	new info[4], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_autoDist = str_to_float(info);
	ShowWaypointMenu(id);
}

public plugin_natives()
{
	register_library("waypoint");
	
	register_native("wp_GetOrigin", "native_GetOrigin");
	register_native("wp_GetRange", "native_GetRange");
	register_native("wp_GetFlags", "native_GetFlags");
	register_native("wp_GetNeighbor", "native_GetNeighbor");
	register_native("wp_IsNeighborSet", "native_IsNeighborSet");
	register_native("wp_GetPathFlags", "native_GetPathFlags");
	register_native("wp_GetCount", "native_GetCount");
	register_native("wp_IsValid", "native_IsValid");
	register_native("wp_GetClosestPoint", "native_GetClosestPoint");
	register_native("wp_GetCurrentPoint", "native_GetCurrentPoint");
	register_native("wp_AStar", "native_AStar");
}

public native_GetOrigin()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return;
	}
	
	set_array_f(2, g_wayPoint[point], 3);
}

public Float:native_GetRange()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return 0.0;
	}
	
	return g_wayRange[point];
}

public native_GetFlags()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return 0;
	}
	
	return g_wayFlags[point];
}

public native_GetNeighbor()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return NULL;
	}
	
	new i = get_param(2);
	if (i < 0 || i >= MAX_PATHS)
	{
		log_error(AMX_ERR_NATIVE, "Invalid path index.");
		return NULL;
	}
	
	return g_wayPaths[point][i];
}

public native_IsNeighborSet()
{
	new point = get_param(1);
	new point2 = get_param(2);
	
	if (!isPointValid(point) || !isPointValid(point2))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return NULL;
	}
	
	return getPath(point, point2);
}

public native_GetPathFlags()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return 0;
	}
	
	new point2 = get_param(2);
	if (!isPointValid(point2))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return 0;
	}
	
	return getPathFlags(point, point2);
}

public native_GetCount()
{
	return g_wayCount;
}

public native_GetClosestPoint()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new Float:distance = get_param_f(2);
	return getClosestPoint(origin, distance);
}

public native_GetCurrentPoint()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new Float:distance = get_param_f(2);
	return getCurrentPoint(origin, distance);
}

public Array:native_AStar()
{
	new start = get_param(1);
	new goal = get_param(2);
	
	if (!isPointValid(start) || !isPointValid(goal))
	{
		log_error(AMX_ERR_NATIVE, "Invalid start or goal.");
		return Invalid_Array;
	}
	
	return aStar(start, goal);
}

public bool:native_IsValid()
{
	new point = get_param(1);
	return isPointValid(point);
}

stock Array:aStar(start, goal)
{
	new closedList[MAX_POINTS >> 5];
	new openListBits[MAX_POINTS >> 5];
	
	static openList[MAX_POINTS];
	static sizeOpen; sizeOpen = 0;
	
	static cameFrom[MAX_POINTS];
	static Float:gCost[MAX_POINTS], Float:fCost[MAX_POINTS];
	
	// Initialize variables
	for (new i = 0; i < g_wayCount; i++)
	{
		cameFrom[i] = NULL;
		gCost[i] = 9999999.0;
		fCost[i] = 9999999.0;
	}
	
	// Initialize cost
	gCost[start] = 0.0;
	fCost[start] = heuristicCost(start, goal);
	
	// Add start to open list
	openList[sizeOpen++] = start;
	setArrayBits(openListBits, start);
	
	new i, j;
	new index, current, neighbor;
	new Float:cost;
	
	// If open list in not empty
	while (sizeOpen > 0)
	{
		cost = 9999999.0;
		
		// Get the element in openlist having the lowest f score
		for (i = 0; i < sizeOpen; i++)
		{
			index = openList[i];
			if (fCost[index] < cost)
			{
				j = i;
				current = index;
				cost = fCost[index];
			}
		}
		
		// We found the path
		if (current == goal)
		{
			new Array:path = ArrayCreate(1);
			ArrayPushCell(path, current);
			
			while (cameFrom[current] != NULL)
			{
				current = cameFrom[current];
				ArrayInsertCellBefore(path, 0, current);
			}
			
			return path;
		}
		
		// Remove current from open list
		openList[j] = openList[--sizeOpen];
		unsetArrayBits(openListBits, current);
		
		// Add to closed list
		setArrayBits(closedList, current);
		
		// Get the neighbors of current
		for (i = 0; i < MAX_PATHS; i++)
		{
			neighbor = g_wayPaths[current][i];
			if (neighbor == NULL)
				continue;
			
			// The neightbor is in closed list
			if (getArrayBits(closedList, neighbor))
				continue;
			
			// The path is blocked by something (like a door)
			if (!isReachable(g_wayPoint[current], g_wayPoint[neighbor], IGNORE_MONSTERS))
				continue;
			
			cost = gCost[current] + get_distance_f(g_wayPoint[current], g_wayPoint[neighbor]);
			
			// Add it if neightbor is not in open list
			if (!getArrayBits(openListBits, neighbor))
			{
				openList[sizeOpen++] = neighbor;
				setArrayBits(openListBits, neighbor);
			}
			else if (cost >= gCost[neighbor])
				continue;
			
			cameFrom[neighbor] = current;
			gCost[neighbor] = cost;
			fCost[neighbor] = gCost[neighbor] + heuristicCost(neighbor, goal);
		}
	}
	
	return Invalid_Array;
}

stock Float:heuristicCost(start, end)
{
    new Float:dx = floatabs(g_wayPoint[start][0] - g_wayPoint[end][0]);
    new Float:dy = floatabs(g_wayPoint[start][1] - g_wayPoint[end][1]);
    new Float:dz = floatabs(g_wayPoint[start][2] - g_wayPoint[end][2]);
	
    return HEURISTIC * floatsqroot(dx * dx + dy * dy + dz * dz);
}

// Check whether a point is valid
stock bool:isPointValid(point)
{
	if (point < 0 || point >= MAX_POINTS)
		return false;
	
	return true;
}

stock saveWaypoints()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/waypoints/%s.wp", filePath, mapName);
	
	new fp = fopen(filePath, "w");
	
	for (new i = 0, j; i < g_wayCount; i++)
	{
		fprintf(fp, "%f %f %f ", g_wayPoint[i][0], g_wayPoint[i][1], g_wayPoint[i][2]);
		
		fprintf(fp, "%d %.f ", g_wayFlags[i], g_wayRange[i]);
		
		for (j = 0; j < MAX_PATHS; j++)
		{
			fprintf(fp, "%d ", g_wayPaths[i][j]);
		}
		
		for (j = 0; j < MAX_PATHS; j++)
		{
			fprintf(fp, "%d ", g_wayPathFlags[i][j]);
		}
		
		fprintf(fp, "^n");
	}
	
	fclose(fp);
}

stock loadWaypoints()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/waypoints/%s.wp", filePath, mapName);
	
	new fp = fopen(filePath, "r");
	
	new i, point;
	new buffer[256], string[20];
	new Float:origin[3];
	
	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));
		
		if (!buffer[0]) continue;
		
		// Get origin
		for (i = 0; i < 3; i++)
		{
			argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
			origin[i] = str_to_float(string);
		}
		
		// Create waypoint
		point = createPoint(origin);
		if (point != NULL)
		{
			// Get flags
			argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
			g_wayFlags[point] = str_to_num(string);
			
			// Get range
			argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
			g_wayRange[point] = str_to_float(string);
			
			// Get paths
			for (i = 0; i < MAX_PATHS; i++)
			{
				argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
				g_wayPaths[point][i] = str_to_num(string);
			}
			
			// Get path flags
			for (i = 0; i < MAX_PATHS; i++)
			{
				argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
				g_wayPathFlags[point][i] = str_to_num(string);
			}
		}
	}
	
	fclose(fp);
}

// Create a waypoint
stock createPoint(const Float:origin[3], Float:range=0.0, flags=0)
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

// Remove a waypoint
stock removePoint(point)
{
	g_wayCount--;
	g_wayPoint[point] = g_wayPoint[g_wayCount];
	g_wayRange[point] = g_wayRange[g_wayCount];
	g_wayFlags[point] = g_wayFlags[g_wayCount];
	g_wayPaths[point] = g_wayPaths[g_wayCount];
	g_wayPathFlags[point] = g_wayPathFlags[g_wayCount];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		for (new j = 0; j < MAX_PATHS; j++)
		{
			if (g_wayPaths[i][j] == point)
			{
				g_wayPaths[i][j] = NULL;
			}
			else if (g_wayPaths[i][j] == g_wayCount)
			{
				g_wayPaths[i][j] = point;
			}
		}
	}
}

// Get waypoint flags string
stock getPointFlagsString(point, output[], maxLen)
{
	new flags = g_wayFlags[point];
	new len = 0;
	
	for (new i = 0; i < sizeof WAYPOINT_FLAG_NAME; i++)
	{
		if (len >= maxLen)
		{
			len = maxLen;
			break;
		}
		
		if ((flags & (1 << i)))
			len += formatex(output[len], maxLen-len, "%s ", WAYPOINT_FLAG_NAME[i]);
	}
	
	if (len <= 0)
	{
		formatex(output, maxLen, "None");
	}
	else
	{
		output[len-1] = 0;
	}
}

stock getCurrentPoint(const Float:origin[3], Float:distance=9999999.0)
{
	new point = NULL;
	new Float:minDist = distance;
	new Float:dist;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (!isReachable(origin, g_wayPoint[i], IGNORE_MONSTERS))
			continue;
		
		dist = get_distance_f(origin, g_wayPoint[i]);
		if (dist < minDist)
		{
			point = i;
			minDist = dist;
		}
	}
	
	return point;
}

// Find the closest waypoint
stock getClosestPoint(const Float:origin[3], Float:distance=9999999.0)
{
	new point = NULL;
	new Float:minDist = distance;
	new Float:dist;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		dist = get_distance_f(origin, g_wayPoint[i]);
		if (dist < minDist)
		{
			point = i;
			minDist = dist;
		}
	}
	
	return point;
}

// Get aiming waypoint
stock getAimPoint(ent, Float:distance=9999999.0, const bits[MAX_POINTS >> 5]={-1, ...})
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	
	pev(ent, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(ent, 9999, end);
	xs_vec_add(end, start, end);
	
	new best = NULL;
	new Float:minDist = distance;
	new Float:dist, Float:size;
	
	new Float:pos1[3], Float:pos2[3];
	new Float:output[3];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (!getArrayBits(bits, i))
			continue;
		
		// Get the closest point from a ray(start, end) to waypoint center
		distPointSegment(g_wayPoint[i], start, end, output);
		
		if (g_wayFlags[i] & WAYPOINT_DUCK)
			size = 20.0;
		else
			size = 36.0;
		
		pos1 = g_wayPoint[i];
		pos1[2] -= size;
		pos2 = g_wayPoint[i];
		pos2[2] += size;
		
		// Get the closest point from output to a waypoint(line segments)
		dist = distPointSegment(output, pos1, pos2, Float:{0.0, 0.0, 0.0});
		if (dist < minDist)
		{
			best = i;
			minDist = dist;
		}
	}
	
	return best;
}

// Check if point neighbors contain point2 
stock getPath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new index = g_wayPaths[point][i];
		if (index == point2)
			return i;
	}
	
	return NULL;
}

// Create a neighbor for a waypoint
stock createPath(point, point2)
{
	if (point == point2)
		return NULL;
	
	if (getPath(point, point2) != NULL)
		return NULL;
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPaths[point][i] == NULL)
		{
			g_wayPaths[point][i] = point2;
			g_wayPathFlags[point][i] = 0;
			return i;
		}
	}
	
	return NULL;
}

// Remove a neighbor for a waypoint
stock removePath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPaths[point][i] == point2)
		{
			g_wayPaths[point][i] = NULL;
			g_wayPathFlags[point][i] = 0;
			return i;
		}
	}
	
	return NULL;
}

stock getPathFlags(point, point2)
{
	new i = getPath(point, point2);
	if (i != NULL)
	{
		return g_wayPathFlags[point][i];
	}
	
	return 0;
}

// Set flags for a path
stock setPathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] = flags;
}

// Add flags for a path
stock addPathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] |= flags;
}

stock bool:addPathFlags2(point, point2, flags)
{
	new i = getPath(point, point2);
	if (i != NULL)
	{
		addPathFlags(point, i, flags);
		return true;
	}
	
	return false
}

// Remove flags for a path
stock removePathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] &= ~flags;
}

stock bool:removePathFlags2(point, point2, flags)
{
	new i = getPath(point, point2);
	if (i != NULL)
	{
		removePathFlags(point, i, flags);
		return true;
	}
	
	return false
}

stock connectPoint(point)
{
	for (new i = 0; i < g_wayCount; i++)
	{
		if (get_distance_f(g_wayPoint[point], g_wayPoint[i]) <= g_autoPathDist && g_autoPathDist >= 0.0)
		{
			if (isReachable(g_wayPoint[point], g_wayPoint[i]))
			{
				createPath(point, i);
				createPath(i, point);
			}
		}
	}
}

stock bool:isReachable(const Float:start[3], const Float:end[3], noMonsters=IGNORE_MONSTERS, skipEnt=0)
{
	engfunc(EngFunc_TraceLine, start, end, noMonsters, skipEnt, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock Float:distPointSegment(const Float:origin[3], const Float:begin[3], const Float:end[3], Float:output[3])
{
	new Float:v[3], Float:w[3];
	xs_vec_sub(end, begin, v);
	xs_vec_sub(origin, begin, w);
	
	new Float:c1 = xs_vec_dot(w, v);
	if (c1 <= 0)
	{
		output = begin;
		return get_distance_f(origin, begin);
	}
	
	new Float:c2 = xs_vec_dot(v, v);
	if (c2 <= c1)
	{
		output = end;
		return get_distance_f(origin, end);
	}
	
	new Float:b = c1 / c2;
	new Float:pB[3];
	xs_vec_mul_scalar(v, b, pB);
	xs_vec_add(begin, pB, pB);
	
	output = pB;
	return get_distance_f(origin, pB);
}

// Draw a line
stock drawLine(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, 
	sprite, frame=0, rate=0, life=10, width=10, noise=0, const color[3]={255,255,255}, alpha=127, scroll=0)
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id);
	write_byte(TE_BEAMPOINTS);
	write_coord_f(x1);
	write_coord_f(y1);
	write_coord_f(z1);
	write_coord_f(x2);
	write_coord_f(y2);
	write_coord_f(z2);
	write_short(sprite);
	write_byte(frame);
	write_byte(rate);
	write_byte(life);
	write_byte(width);
	write_byte(noise);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(alpha);
	write_byte(scroll);
	message_end();
}

// Draw a line with vector3D
stock drawLine2(id, Float:start[3], Float:end[3], sprite, frame=0, rate=0, life=10,
	width=10, noise=0, const color[3]={255,255,255}, alpha=127, scroll=0)
{
	drawLine(id, start[0], start[1], start[2], end[0], end[1], end[2],
		sprite, frame, rate, life, width, noise, color, alpha, scroll);
}