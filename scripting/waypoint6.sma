#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1

#define MAX_WAYPOINTS 1024
#define MAX_PATHS 10

#define MAX_POINTS_TO_SHOW 50

#define WAYPOINT_DUCK (1 << 0)
#define WAYPATH_JUMP  (1 << 0)

#define GetArrayBits(%1,%2) (%1[%2 >> 5] & (1 << (%2 & 31)))
#define SetArrayBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define UnsetArrayBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

new Float:g_wayPoint[MAX_WAYPOINTS][3];
new Float:g_wayRange[MAX_WAYPOINTS];
new g_wayFlags[MAX_WAYPOINTS];
new g_wayPaths[MAX_WAYPOINTS][MAX_PATHS];
new g_wayPathFlags[MAX_WAYPOINTS][MAX_PATHS];
new g_wayCount;

new g_editor;
new bool:g_show;
new bool:g_auto;
new Float:g_autoDist = 124.0;
new Float:g_autoPathDist = 190.0;
new Float:g_range = 32.0;
new g_flags;

new g_currentPoint;
new g_aimPoint;

new g_menuPage;

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

public OnPlayerPreThink(id)
{
	if (g_auto && g_editor == id && is_user_alive(id) && (pev(id, pev_flags) & FL_ONGROUND))
	{
		new Float:origin[3];
		pev(id, pev_origin, origin);
		
		new point = GetClosestWaypoint(origin, g_autoDist);
		if (point == NULL)
		{
			point = CreateWaypoint(origin, 0, g_range);
			if (point != NULL)
			{
				ConnectWaypoint(point);
				client_print(0, print_chat, "Create waypoint #%d", point);
			}
		}
	}
}

public ShowWaypointMenu(id)
{
	new menu = menu_create("Waypoint Menu", "HandleWaypointMenu");
	
	menu_additem(menu, "Create waypoint");
	menu_additem(menu, "Remove waypoint");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Remove path");
	menu_additem(menu, "Set waypoint flags");
	
	new text[64];
	formatex(text, charsmax(text), "Waypoint range: \y%.f", g_range);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto connect distance: \y%.f", g_autoPathDist);
	menu_additem(menu, text);

	formatex(text, charsmax(text), "Auto waypoint: \y%s", g_auto ? "\yOn" : "\dOff");
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
			
			new point = CreateWaypoint(origin, g_flags, g_range);
			if (point == NULL)
				client_print(id, print_chat, "Maximum number of waypoints exceeded.");
			else
			{
				ConnectWaypoint(point);
				client_print(0, print_chat, "Create waypoint #%d.", point);
			}
		}
		case 1: // Remove waypoint
		{
			new point = g_currentPoint;
			if (!IsWaypointValid(point))
				client_print(id, print_chat, "Cannot find current waypoint.");
			else
			{
				RemoveWaypoint(point);
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
			
			if (!IsWaypointValid(point))
			{
				client_print(id, print_chat, "Cannot find current waypoint.");
			}
			else if (!IsWaypointValid(point2))
			{
				client_print(id, print_chat, "Cannot find aim waypoint.");
			}
			else
			{
				if (GetPath(point2, point) != NULL)
				{
					RemovePath(point2, point);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point2, point);
				}
				else if (GetPath(point, point2) != NULL)
				{
					RemovePath(point, point2);
					client_print(0, print_chat, "Disconnect waypoints #%d -> #%d.", point, point2);
				}
			}
		}
		case 4: // Set waypoint flags
		{
			return;
		}
		case 5: // Waypoint range
		{
			ShowRangeMenu(id);
			return;
		}
		case 6:
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
		case 9: // Show waypoints On/Off
		{
			g_show = !g_show;
		}
	}
	
	ShowWaypointMenu(id);
}

public ShowPathMenu(id)
{
	new menu = menu_create("Create Path", "HandlePathMenu");
	
	menu_additem(menu, "Outgoing path");
	menu_additem(menu, "Incoming path");
	menu_additem(menu, "Both ways");
	
	menu_additem(menu, "Jump path (Outgoing)");

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
	
	if (!IsWaypointValid(point))
	{
		client_print(id, print_chat, "Cannot find current waypoint.");
	}
	else if (!IsWaypointValid(point2))
	{
		client_print(id, print_chat, "Cannot find aim waypoint.");
	}
	else
	{
		switch (item)
		{
			case 0: // Outgoing
			{
				RemovePath(point2, point);
				
				if (CreatePath(point, point2) != NULL)
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point, point2);
			}
			case 1: // Incoming
			{
				RemovePath(point, point2);
				
				if (CreatePath(point2, point) != NULL)
					client_print(0, print_chat, "Connect waypoints #%d -> #%d.", point2, point);
			}
			case 2: // Both ways
			{
				CreatePath(point, point2);
				CreatePath(point2, point);
				
				client_print(0, print_chat, "Connect waypoints #%d <-> #%d.", point, point2);
			}
			case 3: // Jump path
			{
				if (!AddPathFlags2(point, point2, WAYPATH_JUMP))
				{
					client_print(0, print_chat, "Both points are not connected.");
				}
				else
				{
					RemovePathFlags2(point2, point, WAYPATH_JUMP);
					client_print(0, print_chat, "Add jump flag to path #%d -> #%d.", point, point2);
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
	
	g_range = str_to_float(info);
	
	new point = g_currentPoint;
	if (IsWaypointValid(point))
	{
		g_wayRange[point] = g_range;
		client_print(0, print_chat, "Change waypoint #%d range to %.f.", point, g_range);
	}
	
	ShowWaypointMenu(id);
}

public ShowPathDistMenu(id)
{
	static dists[] = {100, 120, 140, 160, 190, 220, 250};
	
	new menu = menu_create("Auto Path Distance", "HandlePathDistMenu");
	new info[4];
	
	for (new i = 0; i < sizeof dists; i++)
	{
		num_to_str(dists[i], info, charsmax(info));
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
		menu_destroy(menu);
		return;
	}
	
	new info[4], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_autoDist = str_to_float(info);
	ShowWaypointMenu(id);
}

public ShowWaypoints()
{
	if (!g_editor || !g_show)
		return;
	
	new Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
	static points[MAX_WAYPOINTS], Float:dists[MAX_WAYPOINTS];
	{
		new p, Float:d;
		for (new i, j; i < g_wayCount; i++)
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
	
	g_currentPoint = GetClosestWaypoint(origin, 64.0);
	
	new shown[MAX_WAYPOINTS >> 5];
	{
		new maxPoints = min(g_wayCount, MAX_POINTS_TO_SHOW);
		
		new point;
		new Float:range;
		new Float:pos[3], Float:pos1[3], Float:pos2[3];
		
		for (new i, j, k; i < maxPoints; i++)
		{
			point = points[i];
			pos = g_wayPoint[point];
			
			if (point == g_currentPoint)
			{
				range = g_wayRange[point];
				
				if (range <= 0.0)
				{
					DrawLine(g_editor, 
						pos[0]+16.0, pos[1], pos[2]-18.0,
						pos[0]-16.0, pos[1], pos[2]-18.0,
						g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
					
					DrawLine(g_editor, 
						pos[0], pos[1]+16.0, pos[2]-18.0,
						pos[0], pos[1]-16.0, pos[2]-18.0,
						g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
				}
				else
				{
					pos2[0] = floatcos(360 / 6 * 6.0 - 180.0, degrees) * range + g_wayPoint[point][0];
					pos2[1] = floatsin(360 / 6 * 6.0 - 180.0, degrees) * range + g_wayPoint[point][1];
					pos2[2] = g_wayPoint[point][2] - 18.0;
					
					for (j = 1; j <= 6; j++)
					{
						pos1[0] = floatcos(360 / 6 * float(j) - 180.0, degrees) * range + g_wayPoint[point][0];
						pos1[1] = floatsin(360 / 6 * float(j) - 180.0, degrees) * range + g_wayPoint[point][1];
						pos1[2] = g_wayPoint[point][2] - 18.0;
						
						DrawLine2(g_editor, pos1, pos2, g_sprBeam4, .life=5, .width=10, .color={0, 0, 255}, .alpha=255);
						
						pos2 = pos1;
					}
				}
				
				// Show paths for current waypoint
				for (j = 0; j < MAX_PATHS; j++)
				{
					k = g_wayPaths[point][j];
					if (k == NULL)
						continue;
					
					pos2 = g_wayPoint[k];
					if (GetPath(k, point) != NULL) // Both way
					{
						DrawLine2(g_editor, pos, pos2,
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 200, 0}, .alpha=255, .scroll=5);
					}
					else // Outcoming
					{
						DrawLine2(g_editor, pos, pos2,
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 50, 0}, .alpha=255, .scroll=5);
					}
				}

				// Draw incoming paths
				for (j = 0; j < g_wayCount; j++)
				{
					if (GetPath(j, point) != NULL && GetPath(point, j) == NULL)
					{
						DrawLine2(g_editor, pos, g_wayPoint[j],
							g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 0, 0}, .alpha=255, .scroll=5);
					}
				}
			}
			
			DrawLine(g_editor,
				g_wayPoint[point][0], g_wayPoint[point][1], g_wayPoint[point][2]-36.0,
				g_wayPoint[point][0], g_wayPoint[point][1], g_wayPoint[point][2]+36.0,
				g_sprBeam4, .life=5, .width=20, .color={0, 255, 0}, .alpha=255);
			
			SetArrayBits(shown, point);
		}
	}

	g_aimPoint = GetAimWaypoint(g_editor, 16.0, shown);
	if (IsWaypointValid(g_aimPoint))
	{
		DrawLine2(g_editor, origin, g_wayPoint[g_aimPoint],
			g_sprArrow, .life=5, .width=20, .color={200, 200, 200}, .alpha=255);
	}
}

stock bool:IsWaypointValid(point)
{
	if (point < 0 || point >= MAX_WAYPOINTS)
		return false;
	
	return true;
}

stock CreateWaypoint(Float:origin[3], flags=0, Float:range=0.0)
{
	new point = g_wayCount;
	if (point >= MAX_WAYPOINTS)
		return NULL;
	
	g_wayPoint[point] = origin;
	g_wayRange[point] = range;
	g_wayFlags[point] = flags;
	arrayset(g_wayPaths[point], NULL, MAX_PATHS);
	arrayset(g_wayPathFlags[point], 0, MAX_PATHS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock RemoveWaypoint(point)
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

stock GetPath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new p = g_wayPaths[point][i];
		if (p == point2)
			return i;
	}
	
	return NULL;
}

// Create a neighbor for a waypoint
stock CreatePath(point, point2)
{
	if (point == point2)
		return NULL;
	
	if (GetPath(point, point2) != NULL)
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
stock RemovePath(point, point2)
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

stock GetPathFlags(point, point2)
{
	new i = GetPath(point, point2);
	if (i != NULL)
		return g_wayPathFlags[point][i];
	
	return 0;
}

stock SetPathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] = flags;
}

stock AddPathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] |= flags;
}

stock AddPathFlags2(point, point2, flags)
{
	new i = GetPath(point, point2);
	if (i != NULL)
	{
		AddPathFlags(point, i, flags);
		return 1;
	}
	
	return 0;
}

stock RemovePathFlags(point, i, flags)
{
	g_wayPathFlags[point][i] &= ~flags;
}

stock RemovePathFlags2(point, point2, flags)
{
	new i = GetPath(point, point2);
	if (i != NULL)
	{
		RemovePathFlags(point, i, flags);
		return 1;
	}
	
	return 0;
}

// Get aiming waypoint
stock GetAimWaypoint(ent, Float:distance=9999999.0, bits[MAX_WAYPOINTS >> 5]={NULL, ...})
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	
	pev(ent, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(ent, 9999, end);
	xs_vec_add(end, start, end);
	
	new best = NULL;
	new Float:minDist = distance;
	new Float:dist;
	
	new Float:pos1[3], Float:pos2[3];
	new Float:output[3];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (!GetArrayBits(bits, i))
			continue;
		
		// Get the closest point from a ray(start, end) to waypoint center
		DistPointSegment(g_wayPoint[i], start, end, output);
		
		pos1 = g_wayPoint[i];
		pos1[2] -= 36.0;
		pos2 = g_wayPoint[i];
		pos2[2] += 36.0;
		
		// Get the closest point from output to a waypoint(line segments)
		dist = DistPointSegment(output, pos1, pos2, Float:{0.0, 0.0, 0.0});
		if (dist < minDist)
		{
			best = i;
			minDist = dist;
		}
	}
	
	return best;
}

stock ConnectWaypoint(point)
{
	for (new i = 0; i < g_wayCount; i++)
	{
		if (get_distance_f(g_wayPoint[point], g_wayPoint[i]) <= g_autoPathDist)
		{
			if (IsReachable(g_wayPoint[point], g_wayPoint[i]))
			{
				CreatePath(point, i);
				CreatePath(i, point);
			}
		}
	}
}

stock bool:IsReachable(Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, skipEnt=0)
{
	engfunc(EngFunc_TraceLine, start, end, noMonsters, skipEnt, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

// Get the closest waypoint
stock GetClosestWaypoint(Float:origin[3], Float:distance=9999999.0)
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

stock Float:DistPointSegment(Float:origin[3], Float:begin[3], Float:end[3], Float:output[3])
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
stock DrawLine(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, 
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
stock DrawLine2(id, Float:start[3], Float:end[3], sprite, frame=0, rate=0, life=10,
	width=10, noise=0, color[3]={255,255,255}, alpha=127, scroll=0)
{
	DrawLine(id, start[0], start[1], start[2], end[0], end[1], end[2],
		sprite, frame, rate, life, width, noise, color, alpha, scroll);
}