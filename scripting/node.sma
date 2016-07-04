#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1
#define MAX_NODES 1024
#define MAX_PATHS 8

#define getBits(%1,%2) (%1[%2 >> 5] &  (1 << (%2 & 31)))
#define setBits(%1,%2) (%1[%2 >> 5] |= (1 << (%2 & 31)))
#define unsetBits(%1,%2) (%1[%2 >> 5] &= ~(1 << (%2 & 31)))

new Float:g_nodePos[MAX_NODES][3];
new g_nodePath[MAX_NODES][MAX_PATHS];
new g_nodeCount;

new g_editor;
new g_currentNode, g_aimingNode;
new bool:g_autoMode, Float:g_autoDist = 100.0;

new g_sprBeam1, g_sprBeam4, g_sprArrow;

public plugin_precache()
{
	g_sprBeam1 = precache_model("sprites/zbeam1.spr");
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
	g_sprArrow = precache_model("sprites/arrow1.spr");
}

public plugin_init()
{
	register_clcmd("wp_menu", "cmdWayPointMenu");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	
	set_task(0.5, "drawNodes", 0, .flags="b");
	
	loadNodes();
}

public plugin_natives()
{
	register_native("node_dijkstra", "native_dijkstra");
	register_native("node_find_closest", "native_find_closest");
	register_native("node_get_origin", "native_get_origin");
}

public native_dijkstra()
{
	new source = get_param(1);
	new target = get_param(2);
	
	return dijkstra(source, target);
}

public native_find_closest()
{
	new Float:origin[3];
	get_array_f(1, origin, 3);
	
	new Float:distance = get_param_f(2);
	
	return findClosestNode(origin, distance);
}

public native_get_origin()
{
	new node = get_param(1);
	set_array_f(2, g_nodePos[node], 3);
}

public client_disconnected(id)
{
	if (g_editor == id)
		g_editor = 0;
}

public cmdWayPointMenu(id)
{
	new menu = menu_create("Waypoint Menu", "handleWayPointMenu");
	
	menu_additem(menu, "Create node");
	menu_additem(menu, "Remove node");
	menu_additem(menu, "Create path");
	menu_additem(menu, "Create two-way path");
	menu_additem(menu, "Remove path");
	
	if (g_autoMode)
		menu_additem(menu, "Auto waypoint: \yOn");
	else
		menu_additem(menu, "Auto waypoint: \rOff");
	
	new text[32];
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
	
	switch (item)
	{
		case 0:
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new node = createNode(origin);
			if (node == NULL)
				client_print(0, print_chat, "Can't create more nodes.");
			else
			{
				autoMakePaths(node);
				client_print(0, print_chat, "Create node #%d", node);
			}
		}
		case 1:
		{
			new node = g_currentNode;
			if (!isNodeValid(node))
				client_print(0, print_chat, "Can't find current node.");
			else
			{
				removeNode(node);
				client_print(0, print_chat, "Remove node #%d.", node);
			}
		}
		case 2:
		{
			new node = g_currentNode;
			new node2 = g_aimingNode;
			
			if (!isNodeValid(node) || !isNodeValid(node2))
				client_print(0, print_chat, "Can't find current or aim node.");
			else
			{
				createPath(node, node2);
				client_print(0, print_chat, "Connect node #%d -> #%d.", node, node2);
			}
		}
		case 3:
		{
			new node = g_currentNode;
			new node2 = g_aimingNode;
			
			if (!isNodeValid(node) || !isNodeValid(node2))
				client_print(0, print_chat, "Can't find current or aim node.");
			else
			{
				createPaths(node, node2);
				client_print(0, print_chat, "Connect two-way node #%d <-> #%d.", node, node2);
			}
		}
		case 4:
		{
			new node = g_currentNode;
			new node2 = g_aimingNode;
			
			if (!isNodeValid(node) || !isNodeValid(node2))
				client_print(0, print_chat, "Can't find current or aim node.");
			else
			{
				removePaths(node, node2);
				client_print(0, print_chat, "Remove path #%d - #%d.", node, node2);
			}
		}
		case 5:
		{
			g_autoMode = !g_autoMode;
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
			saveNodes();
			client_print(0, print_chat, "Save nodes.");
		}
		case 8:
		{
			loadNodes();
			client_print(0, print_chat, "Load nodes.");
		}
	}
	
	cmdWayPointMenu(id);
}

public OnPlayerPreThink(id)
{
	if (g_autoMode && g_editor == id && (pev(id, pev_flags) & FL_ONGROUND))
	{
		static Float:origin[3];
		pev(id, pev_origin, origin);
		
		new node = findClosestNode(origin, g_autoDist);
		if (node == NULL)
		{
			node = createNode(origin);
			if (node != NULL)
				autoMakePaths(node);
		}
	}
}

public drawNodes()
{
	if (!g_editor)
		return;
	
	new Float:origin[3];
	pev(g_editor, pev_origin, origin);
	
	g_currentNode = findClosestNode(origin, 64.0);
	
	static nodeIndex[MAX_NODES], Float:nodeDist[MAX_NODES];
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		nodeIndex[i] = i;
		nodeDist[i] = get_distance_f(origin, g_nodePos[i]);
	}
	
	new drawCount = 0;
	new drawed[MAX_NODES / 32];
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		if (drawCount >= 70)
			break
		
		new min = i;
		
		if (i < g_nodeCount)
		{
			for (new j = i+1; j < g_nodeCount; j++)
			{
				if (nodeDist[j] < nodeDist[min])
					min = j;
			}
		}
		
		new index = nodeIndex[min];
		if (index == g_currentNode)
		{
			drawLine(g_editor, 
					g_nodePos[index][0], g_nodePos[index][1], g_nodePos[index][2]-32.0,
					g_nodePos[index][0], g_nodePos[index][1], g_nodePos[index][2]+32.0,
					g_sprBeam4, .life=5, .width=20, .color={255, 0, 0}, .alpha=255);
			
			for (new j = 0; j < MAX_PATHS; j++)
			{
				new node = g_nodePath[index][j]
				if (node == NULL)
					continue;
				
				if (getPath(node, index))
					drawLine2(g_editor, g_nodePos[index], g_nodePos[node],
						g_sprBeam1, .life=3, .width=10, .noise=3, .color={0, 150, 255}, .alpha=255);
				else
					drawLine2(g_editor, g_nodePos[index], g_nodePos[node],
						g_sprBeam1, .life=3, .width=10, .noise=3, .color={0, 50, 255}, .alpha=255);
			}
		}
		else
		{
			drawLine(g_editor, 
					g_nodePos[index][0], g_nodePos[index][1], g_nodePos[index][2]-32.0,
					g_nodePos[index][0], g_nodePos[index][1], g_nodePos[index][2]+32.0,
					g_sprBeam4, .life=5, .width=20, .color={0, 255, 0}, .alpha=255);
		}
		
		setBits(drawed, index);
		drawCount++;
		
		if (min != i)
		{
			nodeIndex[min] = nodeIndex[i];
			nodeDist[min] = nodeDist[i];
		}
	}
	
	g_aimingNode = getAimNode(g_editor, drawed);
	if (g_aimingNode != NULL)
	{
		drawLine2(g_editor, origin, g_nodePos[g_aimingNode], g_sprArrow, 
				.life=4, .width=15, .color={255, 255, 255}, .alpha=255, .scroll=10);
	}
}

stock Array:aStar(start, goal)
{
	new closed[MAX_NODES / 32];
	new open[MAX_NODES / 32];
	new prev[MAX_NODES] = {NULL, ...};
	
	setBits(open, start);
	
	new Float:score_g[MAX_NODES] = {99999.0, ...};
	new Float:score_f[MAX_NODES] = {99999.0, ...};
	
	score_g[start] = 0.0;
	score_f[start] = dijkstra(start, goal);
	
	while (isArraySet(open, sizeof open))
	{
		new current = NULL;
		for (new i = 0; i < g_nodeCount; i++)
		{
			if (!getBits(open, i))
				continue;
			
			if (current == NULL || score_f[i] < score_f[current])
				current = i;
		}
		
		if (current == goal)
		{
			new Array:path = ArrayCreate(1);
			
			ArrayPushCell(path, current);
			
			while (prev[current] != NULL)
			{
				current = prev[current];
				ArrayPushCell(path, current);
			}
			
			return path;
		}
		
		unsetBits(open, current);
		setBits(closed, current);
		
		for (new i = 0; i < MAX_PATHS; i++)
		{
			new neighbor = g_nodePath[current][i];
			if (neighbor == NULL)
				continue;
			
			if (getBits(closed, neighbor))
				continue;
			
			new Float:score = score_g[current] + get_distance_f(g_nodePos[current], g_nodePos[neighbor]);
			
			if (!getBits(open, neighbor))
				setBits(open, neighbor);
			else if (score >= score_g[neighbor])
				continue;
			
			prev[neighbor] = current;
			score_g[neighbor] = score;
			score_f[neighbor] = score_g[neighbor] + dijkstra(neighbor, goal);
		}
	}
	
	return Invalid_Array;
}

stock Array:dijkstra(source, target)
{
	new open[MAX_NODES / 32];
	new prev[MAX_NODES] = {NULL, ...}
	new Float:dist[MAX_NODES] = {99999.0, ...};
	
	for(new i = 0; i < g_nodeCount; i++)
	{
		setBits(open, i);
	}
	
	dist[source] = 0.0;
	
	while (isArraySet(open, sizeof open))
	{
		new u = NULL;
		for (new i = 0; i < g_nodeCount; i++)
		{
			if (!getBits(open, i))
				continue;
			
			if (u == NULL || dist[i] < dist[u])
				u = i;
		}
		
		if (u == target)
		{
			new Array:path = ArrayCreate(1);
			
			ArrayPushCell(path, u);
			
			while (prev[u] != NULL)
			{
				u = prev[u];
				ArrayPushCell(path, u);
			}
			
			return path;
		}
		
		unsetBits(open, u);
		
		for (new i = 0; i < MAX_PATHS; i++)
		{
			new v = g_nodePath[u][i];
			if (v == NULL)
				continue;
			
			new Float:alt = dist[u] + get_distance_f(g_nodePos[u], g_nodePos[v]);
			if (alt < dist[v])
			{
				dist[v] = alt;
				prev[v] = u;
			}
		}
	}
	
	return Invalid_Array;
}

stock bool:isArraySet(const array[], size)
{
	for (new i = 0; i < size; i++)
	{
		if (array[i])
			return true;
	}
	
	return false;
}

stock bool:isNodeValid(node)
{
	if (node < 0 || node >= g_nodeCount)
		return false;
	
	return true;
}

stock createNode(Float:origin[3])
{
	new index = g_nodeCount;
	if (index >= MAX_NODES)
		return NULL;
	
	g_nodePos[index] = origin;
	arrayset(g_nodePath[index], NULL, MAX_PATHS);
	
	g_nodeCount++;
	return g_nodeCount - 1;
}

stock removeNode(node)
{
	g_nodeCount--;
	g_nodePos[node] = g_nodePos[g_nodeCount];
	g_nodePath[node] = g_nodePath[g_nodeCount];
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		for (new j = 0; j < MAX_PATHS; j++)
		{
			if (g_nodePath[i][j] == node)
				g_nodePath[i][j] = NULL;
			if (g_nodePath[i][j] == g_nodeCount)
				g_nodePath[i][j] = node;
		}
	}
}

stock saveNodes()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/nodes/%s.txt", filePath, mapName);
	
	new fp = fopen(filePath, "w");
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		fprintf(fp, "%f %f %f ", g_nodePos[i][0], g_nodePos[i][1], g_nodePos[i][2]);
		
		for (new j = 0; j < MAX_PATHS; j++)
		{
			fprintf(fp, "%d ", g_nodePath[i][j]);
		}
		
		fprintf(fp, "^n");
	}
	
	fclose(fp);
}

stock loadNodes()
{
	new mapName[32];
	get_mapname(mapName, charsmax(mapName));
	
	new filePath[100];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/nodes/%s.txt", filePath, mapName);
	
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
			origin[i] = str_to_float(string);
		}
		
		new node = createNode(origin);
		for (new i = 0; i < MAX_PATHS; i++)
		{
			argbreak(buffer, string, 15, buffer, 99);
			g_nodePath[node][i] = str_to_num(string);
		}
	}
	
	fclose(fp);
}

stock bool:getPath(node, node2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		new index = g_nodePath[node][i];
		if (index == node2)
			return true;
	}
	
	return false
}

stock bool:createPath(node, node2)
{
	if (node == node2)
		return false;
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_nodePath[node][i] == node2)
			return false;
	}
	
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_nodePath[node][i] == NULL)
		{
			g_nodePath[node][i] = node2;
			return true;
		}
	}
	
	return false;
}

stock bool:removePath(node, node2)
{
	for (new i = 0; i < MAX_PATHS; i++)
	{
		if (g_nodePath[node][i] == node2)
		{
			g_nodePath[node][i] = NULL;
			return true;
		}
	}
	
	return false;
}

stock createPaths(node1, node2)
{
	createPath(node1, node2);
	createPath(node2, node1);
}

stock removePaths(node1, node2)
{
	removePath(node1, node2);
	removePath(node2, node1);
}

stock autoMakePaths(node)
{
	for (new i = 0; i < g_nodeCount; i++)
	{
		if (get_distance_f(g_nodePos[node], g_nodePos[i]) < (g_autoDist * 1.6))
		{
			if (isWayReachable(g_nodePos[node], g_nodePos[i]))
				createPaths(node, i);
		}
	}
}

stock bool:isWayReachable(Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, hull=HULL_HEAD, skipEnt=0)
{
	engfunc(EngFunc_TraceHull, start, end, noMonsters, hull, skipEnt, 0);
			
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock findClosestNode(Float:origin[3], Float:distance=9999.0)
{
	new node = NULL;
	new Float:minDist = distance;
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		new Float:dist = get_distance_f(origin, g_nodePos[i]);
		if (dist < minDist)
		{
			node = i;
			minDist = dist;
		}
	}
	
	return node;
}

stock getAimNode(ent, bits[MAX_NODES / 32], Float:distance=9999.0)
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	
	pev(ent, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(ent, 9999, end);
	xs_vec_add(end, start, end);
	
	new min = NULL;
	new Float:minDist = distance;
	
	for (new i = 0; i < g_nodeCount; i++)
	{
		if (!getBits(bits, i))
			continue;
		
		new Float:dist = distPointSegment(g_nodePos[i], start, end);
		if (dist < minDist)
		{
			min = i;
			minDist = dist;
		}
	}
	
	return min;
}

stock Float:distPointSegment(Float:p0[3], Float:p1[3], Float:p2[3])
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