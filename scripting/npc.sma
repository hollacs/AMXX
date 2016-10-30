#include <amxmodx>
#include <engine>
#include <fakemeta>
//#include <hamsandwich>
#include <xs>

#include <waypoint>

#define NULL -1

#define ANIM_IDLE 1
#define ANIM_RUN 4
#define ANIM_JUMP 6

#define EV_INT_PREV EV_INT_iuser1
#define EV_INT_NEXT EV_INT_iuser2
#define EV_FL_LOCKTIME EV_FL_fuser1
#define EV_FL_PATHFIND_TIME EV_FL_fuser2

new g_sprBeam4;

new g_start = NULL;
new g_end = NULL;

public plugin_precache()
{
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
}

public plugin_init()
{
	register_plugin("NPC", "0.1", "penguinux");
	
	register_clcmd("create_npc", "CmdCreateNpc");
	
	register_clcmd("wp_start", "CmdStart");
	register_clcmd("wp_end", "CmdEnd");
	register_clcmd("wp_astar", "CmdAStar");
	register_clcmd("wp_test", "CmdTest");
	
	register_think("npc_test", "ThinkNpc");
	
	register_forward(FM_AddToFullPack, "OnAddToFullPack_Post", 1);
}

public CmdCreateNpc(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	origin[2] += 80.0;
	
	new ent = create_entity("info_target");
	if (is_valid_ent(ent))
	{
		entity_set_string(ent, EV_SZ_classname, "npc_test");
		
		entity_set_model(ent, "models/player/vip/vip.mdl");
		entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
		entity_set_origin(ent, origin);
		
		entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
		entity_set_float(ent, EV_FL_health, 100.0);
		
		entity_set_int(ent, EV_INT_gamestate, 1);
		entity_set_int(ent, EV_INT_deadflag, DEAD_NO);
		entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_STEP);
		
		entity_set_int(ent, EV_INT_PREV, NULL);
		entity_set_int(ent, EV_INT_NEXT, NULL);
		
		// animating
		entity_set_int(ent, EV_INT_sequence, ANIM_IDLE);
		entity_set_float(ent, EV_FL_animtime, get_gametime());
		entity_set_float(ent, EV_FL_framerate, 1.0);
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.1);
	}
}

public CmdStart(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	g_start = wp_GetCurrentPoint(origin);
	return PLUGIN_HANDLED;
}

public CmdEnd(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	g_end = wp_GetCurrentPoint(origin);
	return PLUGIN_HANDLED;
}

public CmdAStar(id)
{
	if (wp_IsValid(g_start) && wp_IsValid(g_end))
	{
		new Array:path = wp_AStar(g_start, g_end);
		if (path != Invalid_Array)
		{
			new Float:pos1[3], Float:pos2[3];
			new size = ArraySize(path);
			
			for (new i = 0; i < (size-1); i++)
			{
				wp_GetOrigin(ArrayGetCell(path, i), pos1);
				wp_GetOrigin(ArrayGetCell(path, i+1), pos2);
				
				drawLine2(0, pos1, pos2, g_sprBeam4, .life=100, .width=10, .color={0, 100, 255}, .alpha=255);
			}
		}
		else
		{
			client_print(id, print_chat, "No path found.");
		}
	}
	else
	{
		client_print(id, print_chat, "You need set start point and end point.");
	}
	
	return PLUGIN_HANDLED;
}

public CmdTest(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	new segment[2], Float:pos[3];
	getClosestPointBetweenPaths(origin, segment, pos);
		
	if (segment[0] != NULL && segment[1] != NULL)
	{
		new Float:pos1[3], Float:pos2[3];
		wp_GetOrigin(segment[0], pos1);
		wp_GetOrigin(segment[1], pos2);
		
		drawLine2(id, pos1, pos2, g_sprBeam4, .life=100, .width=20, .color={0, 100, 200}, .alpha=255);
		client_print(id, print_chat, "%d %d", segment[0], segment[1]);
	}
}

public OnAddToFullPack_Post(es, e, ent, host, flags, player, pset)
{
	if (get_es(es, ES_MoveType) == MOVETYPE_STEP)
	{
		set_es(es, ES_MoveType, MOVETYPE_PUSHSTEP);
	}
}

public ThinkNpc(npc)
{
	new Float:gameTime = get_gametime();
	
	new Float:origin[3];
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	new enemy = entity_get_edict(npc, EV_ENT_enemy);
	new oldEnemy = enemy;
	
	if (!is_user_alive(enemy))
	{
		enemy = findClosestPlayer(origin);
	}
	else if (gameTime >= entity_get_float(npc, EV_FL_LOCKTIME) + 15.0)
	{
		new player = findClosestPlayer(origin, 300.0);
		if (is_user_alive(player))
			enemy = player;
	}
	
	if (is_user_alive(enemy))
	{
		new Float:origin2[3], Float:target[3];
		entity_get_vector(enemy, EV_VEC_origin, origin2);
		
		if (gameTime >= entity_get_float(npc, EV_FL_PATHFIND_TIME) + 0.1)
		{
			new prev = entity_get_int(npc, EV_INT_PREV);
			new next = entity_get_int(npc, EV_INT_NEXT);
			new goal = wp_GetCurrentPoint(origin2);
			
			if (!wp_IsValid(prev) || !wp_IsValid(next))
			{
				new line[2], Float:pos[3];
				getClosestPointBetweenPaths(origin, line, pos);
				
				if (line[0] != NULL && line[1] != NULL && goal != NULL)
				{
					new Array:path = wp_AStar(line[0], goal);
					if (path != Invalid_Array)
					{
						new size = ArraySize(path);
						if (size >= 2)
						{
							new current = ArrayGetCell(path, 1);
							if (current != line[1])
							{
								ArrayInsertCellBefore(path, 0, line[1]);
								size = ArraySize(path);
							}
						}
						
						if (size <= 2)
						{
							target = origin2;
							prev = ArrayGetCell(path, 0);
							next = (size == 1) ? prev : ArrayGetCell(path, 1);
						}
						else
						{
							prev = ArrayGetCell(path, 0);
							next = ArrayGetCell(path, 1);
							
							wp_GetOrigin(next, pos);
							if (get_distance_f(origin, pos) <= wp_GetRange(next))
							{
								prev = next;
								next = ArrayGetCell(path, 2);
							}
						}
					}
				}
			}
			else
			{
				
			}
			
			entity_set_vector(npc, EV_VEC_oldorigin, target);
			entity_set_float(npc, EV_FL_PATHFIND_TIME, gameTime);
		}
		
		entity_get_vector(npc, EV_VEC_oldorigin, target);
		
		if (target[0] != -9999999.0)
		{
			new Float:steering[3];
			xs_vec_add(steering, seek(npc, target, 200.0), steering);
			
			new Float:avelocity[3];
			entity_get_vector(npc, EV_VEC_avelocity, avelocity);
			
			truncate(steering, 50.0);
			xs_vec_div_scalar(steering, 2.5, steering);
			xs_vec_add(avelocity, steering, avelocity);
			truncate(avelocity, 200.0);
			
			new Float:velocity[3];
			entity_get_vector(npc, EV_VEC_velocity, velocity);
			
			velocity[0] = avelocity[0];
			velocity[1] = avelocity[1];
			
			entity_set_vector(npc, EV_VEC_velocity, velocity);
			entity_set_vector(npc, EV_VEC_avelocity, velocity);
			
			new Float:angles[3];
			vector_to_angle(avelocity, angles);
			angles[0] = 0.0;
			entity_set_vector(npc, EV_VEC_angles, angles);
			
			engfunc(EngFunc_MoveToOrigin, npc, target, 0.5, MOVE_STRAFE);
		}
		
		if (enemy != oldEnemy)
		{
			entity_set_edict(npc, EV_ENT_enemy, enemy);
			entity_set_float(npc, EV_FL_LOCKTIME, gameTime);
		}
	}
	else
	{
		entity_set_edict(npc, EV_ENT_enemy, 0);
	}
	
	new Float:velocity[3];
	entity_get_vector(npc, EV_VEC_velocity, velocity);
	
	if (xs_vec_len(velocity) > 10)
		entity_set_int(npc, EV_INT_sequence, ANIM_RUN);
	else
		entity_set_int(npc, EV_INT_sequence, ANIM_IDLE);
	
	entity_set_float(npc, EV_FL_nextthink, gameTime + 0.05);
}

stock Float:getClosestPointBetweenPaths(Float:origin[3], path[2], Float:output[3], Float:distance=9999999.0)
{
	new a, b, i;
	new count = wp_GetCount();
	new found[MAX_POINTS >> 5];
	new Float:dist, Float:minDist = distance;
	new Float:pos[3], Float:pos1[3], Float:pos2[3];
	
	path[0] = NULL;
	path[1] = NULL;
	
	for (a = 0; a < count; a++)
	{
		for (i = 0; i < MAX_PATHS; i++)
		{
			b = wp_GetNeighbor(a, i);
			if (b == NULL)
				continue;
			
			if (getArrayBits(found, b))
				continue;
			
			wp_GetOrigin(a, pos1);
			wp_GetOrigin(b, pos2);
			
			dist = distPointSegment(origin, pos1, pos2, pos);
			if (dist < minDist && isReachable(origin, pos, IGNORE_MONSTERS))
			{
				path[0] = a;
				path[1] = b;
				output = pos;
				minDist = dist;
			}
		}
		
		setArrayBits(found, a);
	}
	
	return minDist;
}

stock Float:distPointPath(Float:origin[3], point1, point2, Float:output[3])
{
	new Float:pos1[3], Float:pos2[3];
	wp_GetOrigin(point1, pos1);
	wp_GetOrigin(point2, pos2);
	
	return distPointSegment(origin, pos1, pos2, output);
}

stock findClosestPlayer(Float:origin[3], Float:distance=9999999.0)
{
	new player = 0;
	new Float:dist, Float:minDist = distance;
	new Float:origin2[3];
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, distance)) != 0)
	{
		// Not player
		if (!is_user_alive(ent))
			continue;
		
		entity_get_vector(ent, EV_VEC_origin, origin2);
		
		dist = get_distance_f(origin, origin2);
		if (dist < minDist)
		{
			player = ent;
			minDist = dist;
		}
	}
	
	return player;
}

stock Float:seek(ent, Float:target[3], Float:maxspeed)
{
	new Float:origin[3];
	entity_get_vector(ent, EV_VEC_origin, origin);
	
	new Float:desired[3];
	xs_vec_sub(target, origin, desired);
	xs_vec_normalize(desired, desired);
	xs_vec_mul_scalar(desired, maxspeed, desired);
	
	new Float:velocity[3];
	entity_get_vector(ent, EV_VEC_avelocity, velocity);
	
	new Float:force[3];
	xs_vec_sub(desired, velocity, force);
	
	return force;
}

stock truncate(Float:vector[3], Float:max)
{
	new Float:i;
	i = max / vector_length(vector);
	i = (i < 1.0) ? i : 1.0;
	
	xs_vec_mul_scalar(vector, i, vector)
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

stock Float:distPointSegment(Float:origin[3], Float:begin[3], Float:end[3], Float:output[3])
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