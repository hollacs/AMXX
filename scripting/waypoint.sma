#include <amxmodx>
#include <fakemeta>
#include <xs>

#define NULL -1
#define MAX_POINTS 1024
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
new Float:g_range;
new g_type;
new g_auto;
new Float:g_autoDist;

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
	register_clcmd("wp_menu", "CmdWayPointMenu");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	
	set_task(0.5, "DrawWaypoints", 0, .flags="b");
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
	
	menu_additem(menu, "Save");
	menu_additem(menu, "Load");
	
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
	g_editor = id;
}

public HandleWayPointMenu(id, menu, item)
{
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
		}
		case 1:
		{
			ShowRangeMenu(id);
		}
		case 2:
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new point = createPoint(origin, g_range, g_type);
			if (point == NULL)
				client_print(0, print_chat, "You cannot create more points.");
			else
				client_print(0, print_chat, "Create point #%d", point);
		}
		case 3:
		{
			new point = g_currentPoint;
			if (!isPointValid(point))
				client_print(0, print_chat, "Cannot find current point.");
			else
			{
				removePoint(point);
				client_print(0, print_chat, "Remove point #%d", point);
			}
		}
	}
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
		
		// current waypoint
		if (index == g_currentPoint)
		{
			drawLine(g_editor, 
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-32.0,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+32.0,
					g_sprBeam4, .life=5, .width=20, .color={255, 0, 0}, .alpha=255);
			
			// draw paths
			for (new i = 0; i < MAX_PATHS; i++)
			{
				new p = g_wayPaths[index][i];
				if (p == NULL)
					continue;
				
				// two-way path
				if (getWayPath(p, index))
					drawLine2(g_editor, g_wayPoint[index], g_wayPoint[p],
							g_sprBeam1, .life=5, .width=10, .noise=3, .color={200, 100, 0}, .alpha=255);
				// one-way path
				else
					drawLine2(g_editor, g_wayPoint[index], g_wayPoint[p],
							g_sprBeam1, .life=5, .width=10, .noise=3, .color={255, 0, 0}, .alpha=255);
				
				drawCount++;
			}
			
			// draw circle
			new Float:polygon[8][3];
			for (new i = 1; i <= 8; i++)
			{
				new j = i-1;
				polygon[j][0] = floatcos(360 / 8 * float(i) - 180.0, degrees) * g_wayRange[index] + g_wayPoint[index][0];
				polygon[j][1] = floatsin(360 / 8 * float(i) - 180.0, degrees) * g_wayRange[index] + g_wayPoint[index][1];
				polygon[j][2] = g_wayPoint[index][2] - 16.0;
			}
			
			for (new i = 0, j = 8-1; i < 8; j=i++)
			{
				drawLine2(g_editor, polygon[i], polygon[j],
						g_sprBeam4, .life=5, .width=10, .color={200, 0, 0}, .alpha=255);
			}
		}
		else
		{
			drawLine(g_editor, 
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]-32.0,
					g_wayPoint[index][0], g_wayPoint[index][1], g_wayPoint[index][2]+32.0,
					g_sprBeam4, .life=5, .width=20, .color={0, 255, 0}, .alpha=255);
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

stock bool:isPointValid(point)
{
	if (point < 0 || point >= g_wayCount)
		return false;
	
	return true;
}

stock createPoint(Float:origin[3], Float:range, type)
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

stock getAimPoint(ent, points[MAX_POINTS >> 5], Float:distance=9999.0)
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	
	pev(ent, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(ent, 9999, end);
	xs_vec_add(end, start, end);
	
	new min = NULL;
	new Float:minDist = distance;
	new Float:pos[3], Float:pos2[3];
	new Float:fuck[3], Float:fuck2[3];
	
	for (new i = 0; i < g_wayCount; i++)
	{
		if (!getBits(points, i))
			continue;
		
		distPointSegment(g_wayPoint[i], start, end, pos);
		
		start = g_wayPoint[i];
		end = g_wayPoint[i];
		start[2] -= 32.0;
		end[2] += 32.0;
		
		new Float:dist = distPointSegment(pos, start, end, pos2);
		if (dist < minDist)
		{
			min = i;
			minDist = dist;
			fuck = pos;
			fuck2 = pos2;
		}
	}
	
	if (min > NULL)
	{
		drawLine2(g_editor, fuck, fuck2,
				g_sprBeam4, .life=5, .width=20, .color={200, 200, 200}, .alpha=255);
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