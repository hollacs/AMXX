#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1
#define MAX_POINTS 2048
#define MAX_PATHS 10

#define getBits(%1,%2) (%1[%2 >> 5] &  (1 << (%2 & 31)))
#define setBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define unsetBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

new const WAYPOINT_TYPES[][] = 
{
	"Normal",
	"Jump"
}

new Float:g_wayPoint[MAX_POINTS][3];
new Float:g_wayRange[MAX_POINTS];
new g_wayPaths[MAX_POINTS][MAX_PATHS];
new g_wayType[MAX_POINTS];
new g_wayCount;

new g_editor;
new Float:g_range = 40.0;
new g_type;
new g_paths = 10;
new g_auto;
new Float:g_autoDist = 130.0;
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
	
	register_clcmd("wp_menu", "CmdWayPointMenu");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	
	set_task(0.5, "DrawWaypoints", 0, .flags="b");
	
	loadPoints();
}

public plugin_natives()
{
	register_library("waypoint");
	
	register_native("wp_aStar", "native_aStar");
	register_native("wp_dijkstra", "native_dijkstra");
	register_native("wp_getOrigin", "native_getOrigin");
	register_native("wp_getType", "native_getType");
	register_native("wp_getRange", "native_getRange");
	register_native("wp_getPath", "native_getPath");
	register_native("wp_getPaths", "native_getPaths");
	register_native("wp_isValid", "native_isValid");
	register_native("wp_findClosestPoint", "native_findClosestPoint");
	register_native("wp_findClosestPointBetweenPaths", "native_findClosestPointBetweenPaths");
	register_native("wp_distPointSegment", "native_distPointSegment");
}

public Array:native_aStar()
{
	new start = get_param(1);
	new goal = get_param(2);
	
	if (!isPointValid(start) || !isPointValid(goal))
	{
		log_error(AMX_ERR_NATIVE, "Invalid start or goal point.");
		return Invalid_Array;
	}
	
	return aStar(start, goal);
}

public Array:native_dijkstra()
{
	new start = get_param(1);
	new goal = get_param(2);
	
	if (!isPointValid(start) || !isPointValid(goal))
	{
		log_error(AMX_ERR_NATIVE, "Invalid start or goal point.");
		return Invalid_Array;
	}
	
	return dijkstra(start, goal);
}

public native_getOrigin()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return false;
	}
	
	set_array_f(2, g_wayPoint[point], 3);
	return true;
}

public native_getType()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return NULL;
	}
	
	return g_wayType[point];
}

public Float:native_getRange()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return -1.0;
	}
	
	return g_wayRange[point];
}

public native_getPath()
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
		log_error(AMX_ERR_NATIVE, "Invalid waypoint path id.");
		return NULL;
	}
	
	return g_wayPaths[point][i];
}

public native_getPaths()
{
	new point = get_param(1);
	if (!isPointValid(point))
	{
		log_error(AMX_ERR_NATIVE, "Invalid waypoint.");
		return false;
	}
	
	set_array(2, g_wayPaths[point], MAX_PATHS);
	return true;
}

public bool:native_isValid()
{
	new point = get_param(1);
	
	return isPointValid(point);
}

public native_findClosestPoint()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new Float:distance = get_param_f(2);
	
	return findClosestPoint(origin, distance);
}

public Float:native_findClosestPointBetweenPaths()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new path[2], Float:output[3];
	new Float:dist = findClosestPointBetweenPaths(origin, path, output);
	
	set_array(2, path, 2);
	set_array_f(3, output, 3);
	return dist;
}

public Float:native_distPointSegment()
{
	new Float:p[3], Float:sp1[3], Float:sp2[3], Float:output[3];
	get_array_f(1, p, 3);
	get_array_f(2, sp1, 3);
	get_array_f(3, sp2, 3);
	
	new Float:dist = distPointSegment(p, sp1, sp2, output);
	set_array_f(4, output, 3);
	
	return dist;
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
		static Float:origin[3];
		pev(id, pev_origin, origin);
		
		new point = findClosestPoint(origin, g_autoDist);
		if (point == NULL)
		{
			point = createPoint(origin, g_range, g_type);
			if (point != NULL)
				makePaths(point);
		}
	}
}

public CmdWayPointMenu(id)
{
	ShowWayPointMenu(id);
	return PLUGIN_HANDLED;
}

public ShowWayPointMenu(id)
{
	new text[64];
	new menu = menu_create("Waypoint Menu", "HandleWayPointMenu");
	
	formatex(text, charsmax(text), "Waypoint type:\y %s", WAYPOINT_TYPES[g_type]);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Waypoint range:\y %.f", g_range);
	menu_additem(menu, text);
	
	menu_additem(menu, "Create point");
	menu_additem(menu, "Remove point");
	menu_additem(menu, "Create one-way path");
	menu_additem(menu, "Create two-way path");
	menu_additem(menu, "Remove path");
	menu_additem(menu, "Edit point");
	
	formatex(text, charsmax(text), "Auto waypoint: %s", g_auto ? "\yOn" : "\dOff");
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Auto waypoint distance: %.f", g_autoDist);
	menu_additem(menu, text);
	
	formatex(text, charsmax(text), "Show paths: %d", g_paths);
	menu_additem(menu, text);
	
	menu_additem(menu, "Save");
	menu_additem(menu, "Load");
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu, g_menuPage);
	g_editor = id;
}

public HandleWayPointMenu(id, menu, item)
{
	if (is_user_connected(id))
	{
		new dummy;
		player_menu_info(id, dummy, dummy, g_menuPage);
	}
	
	menu_destroy(menu);
	
	if (item == MENU_EXIT)
	{
		g_editor = 0;
		return;
	}
	
	if (g_editor != id)
		return;
	
	switch (item)
	{
		case 0:
		{
			ShowTypeMenu(id);
			return;
		}
		case 1:
		{
			ShowRangeMenu(id);
			return;
		}
		case 2:
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new point = createPoint(origin, g_range, g_type);
			if (point == NULL)
				client_print(0, print_chat, "You cannot create more points.");
			else
			{
				makePaths(point);
				client_print(0, print_chat, "Create point #%d.", point);
			}
		}
		case 3:
		{
			new point = g_currentPoint;
			if (!isPointValid(point))
				client_print(0, print_chat, "Cannot find current point.");
			else
			{
				removePoint(point);
				client_print(0, print_chat, "Remove point #%d.", point);
			}
		}
		case 4:
		{
			new point = g_currentPoint;
			new point2 = g_aimPoint;
			
			if (!isPointValid(point) || !isPointValid(point2))
				client_print(0, print_chat, "Cannot find current point or aim point.");
			else
			{
				createPath(point, point2);
				client_print(0, print_chat, "Connect point #%d -> #%d.", point, point2);
			}
		}
		case 5:
		{
			new point = g_currentPoint;
			new point2 = g_aimPoint;
			
			if (!isPointValid(point) || !isPointValid(point2))
				client_print(0, print_chat, "Cannot find current point or aim point.");
			else
			{
				createPaths(point, point2);
				client_print(0, print_chat, "Connect points #%d <-> #%d.", point, point2);
			}
		}
		case 6:
		{
			new point = g_currentPoint;
			new point2 = g_aimPoint;
			
			if (!isPointValid(point) || !isPointValid(point2))
				client_print(0, print_chat, "Cannot find current point or aim point.");
			else
			{
				removePaths(point, point2);
				client_print(0, print_chat, "Disconnect points #%d - #%d.", point, point2);
			}
		}
		case 7:
		{
			new point = g_currentPoint;
			if (!isPointValid(point))
				client_print(0, print_chat, "Cannot find current point.");
			else
			{
				g_wayRange[point] = g_range;
				g_wayType[point] = g_type;
				
				client_print(0, print_chat, "Edit point #%d.", point);
			}
		}
		case 8:
		{
			g_auto = !g_auto;
		}
		case 9:
		{
			ShowDistanceMenu(id);
			return;
		}
		case 10:
		{
			if (g_paths >= 30)
				g_paths = 0;
			else
				g_paths	+= 2;
		}
		case 11:
		{
			savePoints();
			client_print(0, print_chat, "Saved %d waypoints.", g_wayCount);
		}
		case 12:
		{
			loadPoints();
			client_print(0, print_chat, "Loaded %d waypoints.", g_wayCount);
		}
	}
	
	ShowWayPointMenu(id);
}

public ShowTypeMenu(id)
{
	new menu = menu_create("Waypoint Type", "HandleTypeMenu");
	
	for (new i = 0; i < sizeof(WAYPOINT_TYPES); i++)
	{
		menu_additem(menu, WAYPOINT_TYPES[i]);
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleTypeMenu(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT || g_editor != id)
		return;
	
	g_type = item;
	ShowWayPointMenu(id);
}

public ShowRangeMenu(id)
{
	new menu = menu_create("Waypoint Range", "HandleRangeMenu");
	
	new range = 0;
	while (range <= 200)
	{
		static text[32], info[6];
		formatex(text, charsmax(text), "%d", range);
		num_to_str(range, info, charsmax(info));
		menu_additem(menu, text, info)
		range += 20;
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
	
	new info[6], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_range = str_to_float(info);
	ShowWayPointMenu(id);
}

public ShowDistanceMenu(id)
{
	new menu = menu_create("Auto Waypoint Distance", "HandleDistanceMenu");
	
	new dist = 100;
	while (dist <= 200)
	{
		static text[32], info[6];
		formatex(text, charsmax(text), "%d", dist);
		num_to_str(dist, info, charsmax(info));
		menu_additem(menu, text, info)
		dist += 10;
	}
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleDistanceMenu(id, menu, item)
{
	if (item == MENU_EXIT || g_editor != id)
	{
		menu_destroy(menu);
		return;
	}
	
	new info[6], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);
	
	g_autoDist = str_to_float(info);
	ShowWayPointMenu(id);
}

public DrawWaypoints()
{
	if (!g_editor)
		return;
	
	new Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
	g_currentPoint = findClosestPoint(origin, 64.0);
	
	static pointIndexs[MAX_POINTS], Float:pointDists[MAX_POINTS];
	
	// prepare for sorting
	for (new i = 0; i < g_wayCount; i++)
	{
		pointIndexs[i] = i;
		pointDists[i] = get_distance_f(origin, g_wayPoint[i]);
	}
	
	new drawCount = 0;
	new drawn[MAX_POINTS >> 5];
	new numPaths = 0;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (drawCount >= 70)
			break;
		
		new min = i;
		
		// find the waypoint having lowest distance
		if (i < g_wayCount)
		{
			for (new j = i+1; j < g_wayCount; j++)
			{
				if (pointDists[j] < pointDists[min])
					min = j;
			}
		}
		
		new index = pointIndexs[min];
		new color[3];
		
		// current waypoint
		if (index == g_currentPoint)
		{
			color = {255, 0, 0};
			
			set_hudmessage(255, 0, 0, -1.0, 0.25, 0, 0.0, 0.5, 0.0, 0.0, 4);
			show_hudmessage(g_editor, "Waypoint #%d^nXYZ: {%.1f, %.1f, %.1f}^nType: %s^nRange: %.f^nPaths: {%d,%d,%d,%d,%d,%d,%d,%d,%d,%d}", 
							index, 
							g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2],
							WAYPOINT_TYPES[g_wayType[index]],
							g_wayRange[index],
							g_wayPaths[index][0], g_wayPaths[index][1], g_wayPaths[index][2], g_wayPaths[index][3], g_wayPaths[index][4],
							g_wayPaths[index][5], g_wayPaths[index][6], g_wayPaths[index][7], g_wayPaths[index][8], g_wayPaths[index][9]);
			
			// draw circle
			new Float:polygon[6][3];
			for (new j = 1; j <= 6; j++)
			{
				new k = j-1;
				polygon[k][0] = floatcos(360 / 6 * float(j) - 180.0, degrees) * g_wayRange[index] + g_wayPoint[index][0];
				polygon[k][1] = floatsin(360 / 6 * float(j) - 180.0, degrees) * g_wayRange[index] + g_wayPoint[index][1];
				polygon[k][2] = g_wayPoint[index][2] - 16.0;
			}
			
			for (new j = 0, k = 6-1; j < 6; k=j++)
			{
				drawLine2(g_editor, polygon[j], polygon[k],
						g_sprBeam4, .life=5, .width=10, .color={200, 0, 0}, .alpha=255);
			}
		}
		else
		{
			switch (g_wayType[index])
			{
				case 1: color = {0, 200, 100};
				default: color = {0, 255, 0};
			}
		}
		
		drawLine(g_editor, 
				g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-32.0,
				g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+32.0,
				g_sprBeam4, .life=5, .width=20, .color=color, .alpha=255);
		
		for (new j = 0; j < MAX_PATHS; j++)
		{
			if (numPaths >= g_paths && index != g_currentPoint)
				break;
			
			new point = g_wayPaths[index][j]
			if (point == NULL)
				continue;
			
			if (getBits(drawn, point))
				continue;
			
			if (getWayPath(point, index))
				drawLine2(g_editor, g_wayPoint[index], g_wayPoint[point],
					g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 100, 0}, .alpha=255);
			else
				drawLine2(g_editor, g_wayPoint[index], g_wayPoint[point],
					g_sprBeam1, .life=5, .width=10, .noise=5, .color={200, 0, 0}, .alpha=255);
			
			numPaths++;
			drawCount++;
		}
		
		// add to drawn bits
		setBits(drawn, index);
		drawCount++;
		
		// swap space
		if (min != i)
		{
			pointIndexs[min] = pointIndexs[i];
			pointDists[min] = pointDists[i];
		}
	}
	
	g_aimPoint = getAimPoint(g_editor, drawn);
	if (g_aimPoint > NULL)
	{
		drawLine2(g_editor, origin, g_wayPoint[g_aimPoint],
			g_sprArrow, .life=5, .width=20, .color={200, 200, 200}, .alpha=255);
	}
}

stock Array:aStar(start, goal)
{
	new closedSet[MAX_POINTS >> 5];
	
	static openSet[MAX_POINTS];
	static numOpens; numOpens = 0;
	
	static cameFrom[MAX_POINTS];
	static Float:gScore[MAX_POINTS], Float:fScore[MAX_POINTS];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		cameFrom[i] = NULL;
		gScore[i] = 999999.0;
		fScore[i] = 999999.0;
	}
	
	gScore[start] = 0.0;
	fScore[start] = heuristic(start, goal);
	openSet[numOpens++] = start;
	
	while (numOpens)
	{
		new current, index;
		new Float:score = 999999.0;
		
		for (new i = 0; i < numOpens; i++)
		{
			new point = openSet[i];
			if (fScore[point] < score)
			{
				current = point;
				index = i;
				score = fScore[point];
			}
		}
		
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
		
		openSet[index] = openSet[--numOpens];
		setBits(closedSet, current);
		
		for (new i = 0; i < MAX_PATHS; i++)
		{
			new neighbor = g_wayPaths[current][i];
			if (neighbor == NULL)
				continue;
			
			if (getBits(closedSet, neighbor))
				continue;
			
			if (!isReachable(g_wayPoint[current], g_wayPoint[neighbor]))
				continue;
			
			score = gScore[current] + get_distance_f(g_wayPoint[current], g_wayPoint[neighbor]);
			if (!isInArray(neighbor, openSet, numOpens))
				openSet[numOpens++] = neighbor;
			else if (score >= gScore[neighbor])
				continue;
			
			cameFrom[neighbor] = current;
			gScore[neighbor] = score;
			fScore[neighbor] = score + heuristic(neighbor, goal);
		}
	}
	
	return Invalid_Array;
}

stock Array:dijkstra(start, goal)
{
	static queue[MAX_POINTS];
	static numQueue; numQueue = 0;
	
	static Float:distance[MAX_POINTS];
	static previous[MAX_POINTS];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		distance[i] = 999999.0;
		previous[i] = NULL;
		queue[numQueue++] = i;
	}
	
	distance[start] = 0.0;
	
	while (numQueue)
	{
		new current;
		new Float:dist = 999999.0;
		
		for (new i = 0; i < numQueue; i++)
		{
			new point = queue[i];
			if (distance[point] < dist)
			{
				current = point;
				dist = distance[point];
			}
		}
		
		if (current == goal)
		{
			new Array:path = ArrayCreate(1);
			ArrayPushCell(path, current);
			
			while (previous[current] != NULL)
			{
				current = previous[current];
				ArrayInsertCellBefore(path, 0, current);
			}
			
			return path;
		}
		
		queue[current] = queue[--numQueue];
		
		for (new i = 0; i < MAX_PATHS; i++)
		{
			new neighbor = g_wayPaths[current][i];
			if (neighbor == NULL)
				continue;
			
			dist = distance[current] + get_distance_f(g_wayPoint[current], g_wayPoint[neighbor]);
			if (dist < distance[neighbor])
			{
				distance[neighbor] = dist;
				previous[neighbor] = current;
			}
		}
	}
	
	return Invalid_Array;
}

stock Float:heuristic(start, end)
{
	return get_distance_f(g_wayPoint[start], g_wayPoint[end]);
}

stock bool:isInArray(value, const array[], size)
{
	for (new i = 0; i < size; i++)
	{
		if (array[i] == value)
			return true;
	}
	
	return false;
}

stock bool:isPointValid(point)
{
	if (point < 0 || point >= g_wayCount)
		return false;
	
	return true;
}

stock createPoint(Float:origin[3], Float:range=0.0, type=0)
{
	new index = g_wayCount;
	if (index >= MAX_POINTS)
		return NULL;
	
	g_wayPoint[index] = origin;
	g_wayRange[index] = range;
	g_wayType[index] = type;
	arrayset(g_wayPaths[index], NULL, MAX_PATHS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock removePoint(index)
{
	g_wayCount--;
	g_wayPoint[index] = g_wayPoint[g_wayCount];
	g_wayRange[index] = g_wayRange[g_wayCount];
	g_wayPaths[index] = g_wayPaths[g_wayCount];
	g_wayType[index] = g_wayType[g_wayCount];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		for (new j = 0; j < MAX_PATHS; j++)
		{
			if (g_wayPaths[i][j] == index)
				g_wayPaths[i][j] = NULL;
			else if (g_wayPaths[i][j] == g_wayCount)
				g_wayPaths[i][j] = index;
		}
	}
}

stock savePoints()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/waypoints/%s.wp", filePath, mapName);
	
	new fp = fopen(filePath, "w");
	
	for (new i = 0; i < g_wayCount; i++)
	{
		fprintf(fp, "%f %f %f ", g_wayPoint[i][0], g_wayPoint[i][1], g_wayPoint[i][2]);
		
		fprintf(fp, "%f %d ", g_wayRange[i], g_wayType[i]);
		
		for (new j = 0; j < MAX_PATHS; j++)
		{
			fprintf(fp, "%d ", g_wayPaths[i][j]);
		}
		
		fprintf(fp, "^n");
	}
	
	fclose(fp);
}

stock loadPoints()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/waypoints/%s.wp", filePath, mapName);
	
	new fp = fopen(filePath, "r");
	
	while (!feof(fp))
	{
		static buffer[100];
		fgets(fp, buffer, charsmax(buffer));
		
		if (!buffer[0]) continue;
		
		static string[16], Float:origin[3];
		for (new i = 0; i < 3; i++)
		{
			argbreak(buffer, string, 15, buffer, 99);
			origin[i] = str_to_float(string);
		}
		
		new point = createPoint(origin);
		
		// get range
		argbreak(buffer, string, 15, buffer, 99);
		g_wayRange[point] = str_to_float(string);
		
		// get type
		argbreak(buffer, string, 15, buffer, 99);
		g_wayType[point] = str_to_num(string);
		
		// get paths
		for (new i = 0; i < MAX_PATHS; i++)
		{
			argbreak(buffer, string, 15, buffer, 99);
			g_wayPaths[point][i] = str_to_num(string);
		}
	}
	
	fclose(fp);
}

stock bool:getWayPath(p1, p2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new index = g_wayPaths[p1][i];
		if (index == p2)
			return true;
	}
	
	return false
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

stock createPaths(point, point2)
{
	createPath(point, point2);
	createPath(point2, point);
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

stock removePaths(point, point2)
{
	removePath(point, point2);
	removePath(point2, point);
}

stock makePaths(point)
{
	for (new i = 0; i < g_wayCount; i++)
	{
		if (get_distance_f(g_wayPoint[point], g_wayPoint[i]) < (g_autoDist * 1.6))
		{
			if (isReachableHull(g_wayPoint[point], g_wayPoint[i]))
				createPaths(point, i);
		}
	}
}

stock bool:isReachable(Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, skipEnt=0)
{
	engfunc(EngFunc_TraceLine, start, end, noMonsters, skipEnt, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock bool:isReachableHull(Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, hull=HULL_HEAD, skipEnt=0)
{
	engfunc(EngFunc_TraceHull, start, end, noMonsters, hull, skipEnt, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock findClosestPoint(Float:origin[3], Float:distance=9999.0)
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

stock Float:findClosestPointBetweenPaths(Float:origin[3], path[2], Float:output[3])
{
	new found[MAX_POINTS >> 5];
	new Float:minDist = 999999.0;
	
	path[0] = NULL;
	path[1] = NULL;
	
	for (new a = 0; a < g_wayCount; a++)
	{
		for (new j = 0; j < MAX_PATHS; j++)
		{
			new b = g_wayPaths[a][j];
			if (b == NULL)
				continue;
			
			if (getBits(found, b))
				continue;
			
			static Float:pos[3];
			new Float:dist = distPointSegment(origin, g_wayPoint[a], g_wayPoint[b], pos);
			if (dist < minDist)
			{
				path[0] = a;
				path[1] = b;
				output = pos;
				minDist = dist;
			}
		}
		
		setBits(found, a);
	}
	
	return minDist;
}

stock getAimPoint(ent, points[MAX_POINTS >> 5]={-1, ...}, Float:distance=9999.0)
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	
	pev(ent, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(ent, 9999, end);
	xs_vec_add(end, start, end);
	
	new min = NULL;
	new Float:minDist = distance;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (!getBits(points, i))
			continue;
		
		static Float:pos[3];
		distPointSegment(g_wayPoint[i], start, end, pos);
		
		static Float:start2[3], Float:end2[3];
		start2 = g_wayPoint[i];
		start2[2] -= 32.0;
		end2 = g_wayPoint[i];
		end2[2] += 32.0;
		
		new Float:dist = distPointSegment(pos, start2, end2, Float:{0.0, 0.0, 0.0});
		if (dist < minDist)
		{
			min = i;
			minDist = dist;
		}
	}
	
	return min;
}

stock Float:distPointSegment(Float:p[3], Float:sp1[3], Float:sp2[3], Float:output[3])
{
	new Float:v[3], Float:w[3];
	xs_vec_sub(sp2, sp1, v);
	xs_vec_sub(p, sp1, w);
	
	new Float:c1 = xs_vec_dot(w, v);
	if (c1 <= 0)
	{
		output = sp1;
		return get_distance_f(p, sp1);
	}
	
	new Float:c2 = xs_vec_dot(v, v);
	if (c2 <= c1)
	{
		output = sp2;
		return get_distance_f(p, sp2);
	}
	
	new Float:b = c1 / c2;
	new Float:pB[3];
	xs_vec_mul_scalar(v, b, pB);
	xs_vec_add(sp1, pB, pB);
	
	output = pB;
	return get_distance_f(p, pB);
}

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

stock drawLine2(id, Float:start[3], Float:end[3], sprite, frame=0, rate=0, life=10,
	width=10, noise=0, color[3]={255,255,255}, alpha=127, scroll=0)
{
	drawLine(id, start[0], start[1], start[2], end[0], end[1], end[2],
		sprite, frame, rate, life, width, noise, color, alpha, scroll);
}