#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1
#define MAX_POINTS 1024
#define MAX_PATHS 8

#define getBits(%1,%2) (%1[%2 >> 5] &  (1 << (%2 & 31)))
#define setBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define unsetBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

new Float:g_wayPoint[MAX_POINTS][3];
new g_wayPath[MAX_POINTS][MAX_PATHS];
new g_wayCount;

new g_editor;
new bool:g_auto;
new Float:g_autoDist = 150.0;

new g_sprBeam1, g_sprBeam4, g_sprArrow;

public plugin_precache()
{
	g_sprBeam1 = precache_model("sprites/zbeam1.spr");
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
	g_sprArrow = precache_model("sprites/arrow1.spr");
}

public plugin_init()
{
	register_plugin("Way Point", "0.1", "Colgate");
	
	register_clcmd("wp_menu", "cmdWayPointMenu");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	
	set_task(0.5, "drawWayPoints", .flags="b");
	
	loadPoints();
}

public plugin_natives()
{
	register_library("waypoint");
	
	register_native("wp_dijkstra", "native_dijkstra");
	register_native("wp_get_origin", "native_get_origin");
	register_native("wp_find_closest", "native_find_closest");
}

public native_dijkstra()
{
	return dijkstra(get_param(1), get_param(2), get_param(3));
}

public native_get_origin()
{
	new point = get_param(1);
	set_array_f(2, g_wayPoint[point], 3);
}

public native_find_closest()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new Float:dist = get_param_f(2);
	
	return findClosestPoint(origin, dist);
}

public cmdWayPointMenu(id)
{
	new text[64];
	new menu = menu_create("Waypoint menu", "handleWayPointMenu");
	
	menu_additem(menu, "建立路點");
	menu_additem(menu, "移除路點");
	menu_additem(menu, "連接路徑");
	menu_additem(menu, "連接雙向路徑");
	menu_additem(menu, "移除路徑");
	
	if (g_auto)
		menu_additem(menu, "自動路點模式: \y開");
	else
		menu_additem(menu, "自動路點模式: \r關");
	
	formatex(text, charsmax(text), "自動路點距離: %.f", g_autoDist);
	menu_additem(menu, text);
	
	menu_additem(menu, "儲存路徑點");
	menu_additem(menu, "載入路徑點");
	
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
	pev(id, pev_origin, origin);
	
	switch (item)
	{
		case 0:
		{
			new point = createPoint(origin);
			if (point == NULL)
				client_print(0, print_chat, "* 無法建立路點.");
			else
			{
				autoMakePaths(point);
				client_print(0, print_chat, "* 建立路點 #%d.", point);
			}
		}
		case 1:
		{
			new point = getCurrentPoint(origin);
			if (point == NULL)
				client_print(0, print_chat, "* 找不到路點.");
			else
			{
				removePoint(point);
				client_print(0, print_chat, "* 刪除路點 #%d.", point);
			}
		}
		case 2:
		{
			new point = getCurrentPoint(origin);
			new point2 = getAimPoint(id);
			
			if (point == NULL || point2 == NULL)
				client_print(0, print_chat, "* 找不到路點.");
			else
			{
				makePath(point, point2);
				client_print(0, print_chat, "* 連接路點 #%d -> #%d.", point, point2);
			}
		}
		case 3:
		{
			new point = getCurrentPoint(origin);
			new point2 = getAimPoint(id);
			
			if (point == NULL || point2 == NULL)
				client_print(0, print_chat, "* 找不到路點.");
			else
			{
				makePaths(point, point2);
				client_print(0, print_chat, "* 連接路點 #%d <-> #%d.", point, point2);
			}
		}
		case 4:
		{
			new point = getCurrentPoint(origin);
			new point2 = getAimPoint(id);
			
			if (point == NULL || point2 == NULL)
				client_print(0, print_chat, "* 找不到路點.");
			else
			{
				removePaths(point, point2);
				client_print(0, print_chat, "* 移除路徑 #%d - #%d.", point, point2);
			}
		}
		case 5:
		{
			g_auto = !g_auto;
		}
		case 6:
		{
			if (g_autoDist >= 200)
				g_autoDist = 100.0;
			else
				g_autoDist += 10.0;
		}
		case 7:
		{
			savePoints();
			client_print(0, print_chat, "* 儲存路徑點.");
		}
		case 8:
		{
			loadPoints();
			client_print(0, print_chat, "* 載入路徑點.");
		}
	}
	
	cmdWayPointMenu(id);
}

public OnPlayerPreThink(id)
{
	if (g_auto && g_editor == id && (pev(id, pev_flags) & FL_ONGROUND))
	{
		static Float:origin[3];
		pev(id, pev_origin, origin);
		
		new point = findClosestPoint(origin, g_autoDist);
		if (point == NULL)
		{
			point = createPoint(origin);
			autoMakePaths(point);
		}
	}
}

public drawWayPoints()
{
	if (!g_editor)
		return;
	
	static Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
	// Prepare for sorting
	static points[MAX_POINTS], Float:dists[MAX_POINTS];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		points[i] = i;
		dists[i] = get_distance_f(origin, g_wayPoint[i]);
	}
	
	new drawCount = 0;
	new current = getCurrentPoint(origin);
	new aimPoint = getAimPoint(g_editor);
	
	if (aimPoint != NULL)
		drawLine2(g_editor, origin, g_wayPoint[aimPoint],
			g_sprArrow, .life=4, .width=15, .color={255, 255, 255}, .alpha=255, .scroll=10);
	
	// Draw waypoints
	for (new i = 0; i < g_wayCount; i++)
	{
		if (drawCount >= 70)
			break;
		
		new min = i;
		
		// Find the closest point
		if (i < g_wayCount)
		{
			for (new j = i+1; j < g_wayCount; j++)
			{
				if (dists[j] < dists[min])
					min = j
			}
		}
		
		new index = points[min];
		
		// Current point
		if (current == index)
		{
			drawLine(g_editor, 
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-32.0,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+32.0,
					g_sprBeam4, .life=5, .width=25, .color={255, 0, 0}, .alpha=255);
			
			// Draw paths
			for (new j = 0; j < MAX_PATHS; j++)
			{
				new point = g_wayPath[index][j];
				if (point == NULL)
					continue;
				
				if (getPath(point, index))
					drawLine2(g_editor, g_wayPoint[index], g_wayPoint[point],
						g_sprBeam1, .life=3, .width=10, .noise=3, .color={0, 150, 255}, .alpha=255);
				else
					drawLine2(g_editor, g_wayPoint[index], g_wayPoint[point],
						g_sprBeam1, .life=3, .width=10, .noise=3, .color={0, 50, 255}, .alpha=255);
				
				drawCount++;
			}
		}
		else
			drawLine(g_editor, 
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-32.0,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+32.0,
					g_sprBeam4, .life=5, .width=20, .color={0, 255, 0}, .alpha=255);
		
		drawCount++;
		
		if (min != i)
		{
			points[min] = points[i];
			dists[min] = dists[i];
		}
	}
}

stock dijkstra(ent, source, target)
{
	new Float:dist[MAX_POINTS] = {9999.0, ...};
	new prev[MAX_POINTS] = {NULL, ...};
	new openSet[MAX_POINTS >> 5];
	
	for (new v = 0; v < g_wayCount; v++)
	{
		setBits(openSet, v);
	}
	
	dist[source] = 0.0;
	
	while (isArraySet(openSet, sizeof openSet))
	{
		new u = NULL;
		for (new i = 0; i < g_wayCount; i++)
		{
			if (!getBits(openSet, i))
				continue;
			
			if (u == NULL || dist[i] < dist[u])
				u = i;
		}
		
		if (u == target)
		{
			while (prev[u] != NULL && prev[u] != source)
			{
				u = prev[u];
			}
			
			return u;
		}
		
		unsetBits(openSet, u);
		
		for (new i = 0; i < MAX_PATHS; i++)
		{
			new v = g_wayPath[u][i];
			if (v == NULL)
				continue;
			
			new Float:alt = dist[u] + get_distance_f(g_wayPoint[u], g_wayPoint[v]);
			if (alt < dist[v])
			{
				dist[v] = alt;
				prev[v] = u;
			}
		}
	}
	
	return NULL;
}

stock bool:isArraySet(const bits[], size)
{
	for (new i = 0; i < size; i++)
	{
		if (bits[i])
			return true;
	}
	
	return false;
}

stock createPoint(Float:origin[3])
{
	new index = g_wayCount;
	
	g_wayPoint[index] = origin;
	arrayset(g_wayPath[index], NULL, MAX_PATHS);
	
	g_wayCount++;
	return g_wayCount - 1;
}

stock removePoint(point)
{
	g_wayCount--;
	g_wayPoint[point] = g_wayPoint[g_wayCount];
	g_wayPath[point] = g_wayPath[g_wayCount];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		for (new j = 0; j < MAX_PATHS; j++)
		{
			if (g_wayPath[i][j] == point)
				g_wayPath[i][j] = NULL;
			if (g_wayPath[i][j] == g_wayCount)
				g_wayPath[i][j] = point;
		}
	}
}

stock autoMakePaths(point)
{
	for (new i = 0; i < g_wayCount; i++)
	{
		if (get_distance_f(g_wayPoint[point], g_wayPoint[i]) < (g_autoDist * 1.7))
		{
			if (canWayPass(g_wayPoint[point], g_wayPoint[i]))
				makePaths(point, i);
		}
	}
}

stock bool:getPath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new index = g_wayPath[point][i];
		if (index == point2)
			return true;
	}
	
	return false
}

stock bool:makePath(point, point2)
{
	if (point == point2)
		return false;
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPath[point][i] == point2)
			return false;
	}
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPath[point][i] == NULL)
		{
			g_wayPath[point][i] = point2;
			return true;
		}
	}
	
	return false;
}

stock bool:removePath(point, point2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_wayPath[point][i] == point2)
		{
			g_wayPath[point][i] = NULL;
			return true;
		}
	}
	
	return false;
}

stock makePaths(pt1, pt2)
{
	makePath(pt1, pt2);
	makePath(pt2, pt1);
}

stock removePaths(pt1, pt2)
{
	removePath(pt1, pt2);
	removePath(pt2, pt1);
}

stock isWayReachable(ent, start, end)
{
	engfunc(EngFunc_TraceLine, g_wayPoint[start], g_wayPoint[end], DONT_IGNORE_MONSTERS, ent, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock bool:canWayPass(Float:start[3], Float:end[3])
{
	engfunc(EngFunc_TraceHull, start, end, IGNORE_MONSTERS, HULL_HEAD, 0, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock getAimPoint(id, Float:distance=9999.0)
{	
	new Float:start[3], Float:end[3];
	pev(id, pev_origin, start);
	
	new point = findClosestPoint(start, 64.0);
	pev(id, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(id, 9999, end);
	xs_vec_add(end, start, end);
	
	new best = NULL;
	new Float:minDist = distance;
	
	for (new i = 0; i < g_wayCount; i++)
	{
		new Float:dist = distLinePoint(g_wayPoint[i], start, end);
		if (point != i && dist < minDist)
		{
			best = i;
			minDist = dist;
		}
	}
	
	return best;
}

stock savePoints()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/waypoint/%s.txt", filePath, mapName);
	
	new fp = fopen(filePath, "w");
	
	for (new i = 0; i < g_wayCount; i++)
	{
		fprintf(fp, "%f %f %f ", g_wayPoint[i][0], g_wayPoint[i][1], g_wayPoint[i][2]);
		
		for (new j = 0; j < MAX_PATHS; j++)
		{
			fprintf(fp, "%d ", g_wayPath[i][j]);
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
	format(filePath, charsmax(filePath), "%s/waypoint/%s.txt", filePath, mapName);
	
	new fp = fopen(filePath, "r");
	
	while (!feof(fp))
	{
		static buffer[100];
		fgets(fp, buffer, charsmax(buffer));
		
		if (!buffer[0])
			continue;
		
		static string[16], Float:origin[3];
		for (new i = 0; i < 3; i++)
		{
			argbreak(buffer, string, 15, buffer, 99);
			server_print(string);
			origin[i] = str_to_float(string);
		}
		
		new point = createPoint(origin);
		for (new i = 0; i < MAX_PATHS; i++)
		{
			argbreak(buffer, string, 15, buffer, 99);
			
			g_wayPath[point][i] = str_to_num(string);
		}
	}
	
	fclose(fp);
}

getCurrentPoint(Float:origin[3])
{
	return findClosestPoint(origin, 64.0);
}

stock Float:distLinePoint(Float:p0[3], Float:p1[3], Float:p2[3])
{
	new Float:v[3], Float:w[3];
	xs_vec_sub(p1, p2, v);
	xs_vec_sub(p0, p1, w);
	
	new Float:c1 = xs_vec_dot(w, v);
	new Float:c2 = xs_vec_dot(v, v);
	new Float:b = c1 / c2;
	
	new Float:origin[3];
	xs_vec_mul_scalar(v, b, origin);
	xs_vec_add(p1, origin, origin);
	
	return get_distance_f(p0, origin);
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