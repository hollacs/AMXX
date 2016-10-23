#include <amxmodx>
#include <fakemeta>
#include <xs>

//#define DEBUG

#define NULL -1

#define MAX_POINTS 1280 // Max waypoints
#define MAX_PATHS 10 // Max paths in a waypoint
#define MAX_POINTS_SHOWN 50 // Max waypoints will be shown

#define AUTO_DIST_DEFAULT 132.0 // Default value of auto waypoint distance
#define AUTOPATH_DIST_DEFAULT 140.0 // Default value of auto path distance
#define WAYPOINT_RANGE_DEFAULT 32.0 // Default value of waypoint range
#define WAYPOINT_RANGE_SIDES 6 // Number of polygon sides for displaying waypoint range

#define getArrayBits(%1,%2) (%1[%2 >> 5] & (1 << (%2 & 31)))
#define setArrayBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define unsetArrayBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

// Waypoint flags
enum (<<= 1)
{
    WAYPOINT_JUMP = 1,
	WAYPOINT_DUCK
};

// Waypoint path flags
enum (<<= 1)
{
	WAYPATH_JUMP = 1,
	WAYPATH_DUCK
};

// Waypoint flags name
new const WAYPOINT_FLAGS[][] = {"Jump", "Duck"};

// HAPYY AMXX ^O^
new Float:g_wayPoint[MAX_POINTS][3];
new Float:g_wayRange[MAX_POINTS];
new g_wayFlags[MAX_POINTS];
new g_wayPaths[MAX_POINTS][MAX_PATHS];
new g_wayPathFlags[MAX_POINTS][MAX_PATHS];
new g_wayCount = 0;

new g_editor = 0;
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

// Show waypoints
public ShowWaypoints()
{
	if (!g_editor)
		return;
	
	new Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
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
	
	new maxPointsShown = min(g_wayCount, MAX_POINTS_SHOWN);
	{
		new index, flags, Float:range;
		new Float:size, color[3];
		new Float:pos[3], Float:pos1[3], Float:pos2[3];
		
		for (new i = 0, j; i < maxPointsShown; i++)
		{
			index = points[i];
			flags = g_wayFlags[index];
			pos = g_wayPoint[index];
			
			// Default style
			size = 36.0;
			color = {0, 255, 0};
			
			if (flags & WAYPOINT_DUCK)
				size = 20.0;
			if (flags & WAYPOINT_JUMP)
				color = {0, 200, 100};
			
			if (index == g_currentPoint)
			{
				range = g_wayRange[index];
				
				set_hudmessage(0, 200, 50, 0.4, 0.25, 0, 0.0, 0.5, 0.0, 0.0, 4);
				show_hudmessage(g_editor, "Waypoint #%d^nXYZ: {%.2f, %.2f, %.2f}^nFlags: none^nRange: %.f", 
								index, pos[0], pos[1], pos[2], g_wayRange[index]);
				
				if (range <= 0.0)
				{
					// Draw a cross if no range 
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
			}
			
			drawLine(g_editor,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-size,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+size,
					g_sprBeam4, .life=5, .width=20, .color=color, .alpha=255);
			
			#if defined DEBUG
			client_print(g_editor, print_console, "points[%d] = %d, dists[%d] = %.2f", i, points[i], i, dists[i]);
			#endif
		}
	}
	#if defined DEBUG
	if (maxPointsShown)
		client_print(g_editor, print_console, "--------------------");
	#endif
	
	g_currentPoint = findClosestPoint(origin, 64.0);
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
			
		}
		case 11: // Load
		{
			
		}
	}
	
	ShowWaypointMenu(id);
}

// Waypoint type menu
public ShowTypeMenu(id)
{
	static const types[] = {0};
	
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
	if (pev(id, pev_flags) & FL_DUCKING)
		flags |= WAYPOINT_DUCK;
		
	new point = createPoint(origin, g_range, flags);
	if (point == NULL)
		client_print(id, print_chat, "Cannot create more waypoints.");
	else
		client_print(0, print_chat, "Create waypoint #%d.", point);
	
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
	if (isPointValid(point) && (g_wayFlags[point] & WAYPOINT_JUMP))
	{
		menu_addblank2(menu);
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
				if (createPath(point, point2) != NULL)
				{
					removePath(point2, point);
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point, point2);
				}
			}
			case 1: // Incoming
			{
				if (createPath(point2, point) != NULL)
				{
					removePath(point, point2);
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point2, point);
				}
			}
			case 2: // Both ways
			{
				createPath(point, point2);
				createPath(point2, point);
				
				client_print(0, print_chat, "Connect waypoints #%d <-> #%d.", point, point2);
			}
			case 4: // Jump path
			{
				if (~g_wayFlags[point] & WAYPOINT_JUMP)
				{
					client_print(id, print_chat, "Current waypoint is not a jump point.");
				}
				else
				{
					new i = createPath(point, point2);
					if (i != NULL)
					{
						addPathFlags(point, i, WAYPATH_JUMP);
						client_print(0, print_chat, "Connect waypoints with jump flag #%d -> #%d.", point, point2);
					}
				}
			}
		}
	}
	
	ShowWaypointMenu(id);
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
	static distances[] = {100, 120, 140, 160, 190, 220, 250};
	
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
	static distances[] = {100, 116, 132, 148, 164, 180, 200};
	
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
		menu_destroy(menu);
		return;
	}
	
	new info[4], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_autoDist = str_to_float(info);
	ShowWaypointMenu(id);
}

// Check whether a point is valid
stock bool:isPointValid(point)
{
	if (point < 0 || point >= MAX_POINTS)
		return false;
	
	return true;
}

// Create a waypoint
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

// Find the closest waypoint
stock findClosestPoint(Float:origin[3], Float:distance=999999.0)
{
	new point = NULL;
	new Float:minDist = distance;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		new Float:dist = get_distance_f(origin, g_wayPoint[i]);
		if (dist < minDist)
		{
			point = i;
			minDist = dist;
		}
	}
	
	return point;
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

// Remove flags for a path
stock removePathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] &= ~flags;
}

// Draw a line
stock drawLine(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, 
	sprite, frame=0, rate=0, life=10, width=10, noise=0, color[3]={255,255,255}, alpha=127, scroll=0)
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
	width=10, noise=0, color[3]={255,255,255}, alpha=127, scroll=0)
{
	drawLine(id, start[0], start[1], start[2], end[0], end[1], end[2],
		sprite, frame, rate, life, width, noise, color, alpha, scroll);
}