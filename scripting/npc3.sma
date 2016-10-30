#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <waypoint>

#define NULL -1

#define ANIM_IDLE 1
#define ANIM_RUN 4
#define ANIM_JUMP 6

new g_follow;

new g_sprBeam4;

public plugin_precache()
{
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
}

public plugin_init()
{
	register_plugin("NPC", "0.1", "penguinux");
	
	register_clcmd("create_npc", "CmdCreateNpc");
	register_clcmd("create_obs", "CmdCreateObs");
	register_clcmd("say /follow", "CmdNpcFollow");
	register_clcmd("intersect", "CmdIntersect");
	
	register_think("npc_test", "ThinkNpc");
	
	register_forward(FM_AddToFullPack, "OnAddToFullPack_Post", 1);
	
	//RegisterHam(Ham_Killed, "info_target", "OnNpcKilled_Post", 1);
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
		
		entity_set_int(ent, EV_INT_iuser1, NULL);
		
		// animating
		entity_set_int(ent, EV_INT_sequence, ANIM_IDLE);
		entity_set_float(ent, EV_FL_animtime, get_gametime());
		entity_set_float(ent, EV_FL_framerate, 1.0);
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.1);
	}
}

public CmdCreateObs(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	new ent = create_entity("info_target");
	if (is_valid_ent(ent))
	{
		entity_set_model(ent, "models/player/sas/sas.mdl");
		entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
		entity_set_origin(ent, origin);
		
		entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
		entity_set_float(ent, EV_FL_health, 100.0);
		
		entity_set_int(ent, EV_INT_gamestate, 1);
		entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_STEP);
		
		entity_set_int(ent, EV_INT_sequence, ANIM_IDLE);
		entity_set_float(ent, EV_FL_animtime, get_gametime());
		entity_set_float(ent, EV_FL_framerate, 1.0);
	}
	
	origin[2]+=80.0;
	entity_set_origin(id, origin);
}

public CmdNpcFollow(id)
{
	if (g_follow)
	{
		g_follow = 0;
		client_print(id, print_chat, "NPC stop following.");
	}
	else
	{
		g_follow = id;
		client_print(id, print_chat, "NPC will follow %n.", id);
	}
}

public CmdIntersect(id)
{
	new Float:start[3], Float:end[3];
	pev(id, pev_origin, start);
	
	pev(id, pev_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(id, 500, end);
	xs_vec_add(end, start, end);
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, start, 500.0)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP || entity_get_int(ent, EV_INT_solid) == SOLID_BSP)
			continue;
		
		if (entity_get_float(ent, EV_FL_takedamage) == DAMAGE_NO)
			continue;
		
		if (id == ent)
			continue;
		
		static Float:origin[3], Float:mins[3], Float:maxs[3];
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		
		xs_vec_add(origin, mins, mins);
		xs_vec_add(origin, maxs, maxs);
		
		static Float:intersection[3];
		if (intersectSegmentBox2(start, end, mins, maxs, intersection))
		{
			drawLine(id, 
				intersection[0], intersection[1], intersection[2]-5.0, 
				intersection[0], intersection[1], intersection[2]+5.0, 
				g_sprBeam4, .life=100, .width=10, .color={255, 0, 0}, .alpha=255);
			
			client_print(id, print_chat, "intersect");
			break;
		}
		else
		{
			client_print(id, print_chat, "no intersect");
		}
	}
}

public ThinkNpc(npc)
{
	if (g_follow)
	{
		new Float:target[3];
		new Float:origin[3], Float:origin2[3];
		entity_get_vector(npc, EV_VEC_origin, origin);
		entity_get_vector(g_follow, EV_VEC_origin, origin2);
		
		if (get_gametime() >= entity_get_float(npc, EV_FL_ltime) + 0.2)
		{
			new start = entity_get_int(npc, EV_INT_iuser1);
			new goal = wp_GetCurrentPoint(origin2);
			
			if (!wp_IsValid(start))
			{
				start = wp_GetCurrentPoint(origin);
			}
			else
			{
				new Float:origin3[3];
				wp_GetOrigin(start, origin3);
				
				if (get_distance_f(origin, origin3) > 300)
				{
					start = wp_GetCurrentPoint(origin);
					entity_set_int(npc, EV_INT_iuser1, start);
				}
			}
			
			if (wp_IsValid(start) && wp_IsValid(goal))
			{
				new Array:path = wp_AStar(start, goal);
				if (path != Invalid_Array)
				{
					new size = ArraySize(path);
					if (size <= 2)
					{
						target = origin2;
						entity_set_int(npc, EV_INT_iuser1, NULL);
					}
					else
					{
						new current = ArrayGetCell(path, 1);
						
						new Float:origin3[3];
						wp_GetOrigin(current, origin3);
						
						if (get_distance_f(origin, origin3) <= wp_GetRange(current))
						{
							entity_set_int(npc, EV_INT_iuser1, current);
						}
						
						target = origin3;
					}
					
					new Float:origin3[3], Float:origin4[3];
					
					for (new i = 0; i < (size-1); i++)
					{
						wp_GetOrigin(ArrayGetCell(path, i), origin3);
						wp_GetOrigin(ArrayGetCell(path, i+1), origin4);
						
						drawLine2(0, origin3, origin4, g_sprBeam4, .life=2, .width=10, .color={0, 100, 255}, .alpha=255);
					}
					
					ArrayDestroy(path);
				}
				else
				{
					target = origin;
				}
			}
			else
			{
				target = origin;
			}
			
			entity_set_vector(npc, EV_VEC_oldorigin, target);
			entity_set_float(npc, EV_FL_ltime, get_gametime());
		}
		
		entity_get_vector(npc, EV_VEC_oldorigin, target);
		
		if (!xs_vec_equal(origin, target))
		{
			new Float:steering[3];
			xs_vec_add(steering, seek(npc, target, 200.0), steering);
			//xs_vec_add(steering, collisionAvoidance(npc, 200.0, 100.0), steering);
			//xs_vec_add(steering, separation(npc, 100.0, 50.0), steering);
			
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
	}
	
	new Float:velocity[3];
	entity_get_vector(npc, EV_VEC_velocity, velocity);
	
	if (xs_vec_len(velocity) > 1)
		entity_set_int(npc, EV_INT_sequence, ANIM_RUN);
	else
		entity_set_int(npc, EV_INT_sequence, ANIM_IDLE);
	
	entity_set_float(npc, EV_FL_nextthink, get_gametime() + 0.05);
}

public OnAddToFullPack_Post(es, e, ent, host, flags, player, pset)
{
	if (get_es(es, ES_MoveType) == MOVETYPE_STEP)
	{
		set_es(es, ES_MoveType, MOVETYPE_PUSHSTEP);
	}
}

public client_disconnected(id)
{
	if (g_follow == id)
		g_follow = 0;
}

stock bool:isEntNpc(ent)
{
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));
	
	return bool:equal(classname, "npc_test");
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

stock Float:separation(npc, Float:radius, Float:force)
{
	new Float:v[3];
	new count = 0;
	
	new Float:origin[3];
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, radius)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP || entity_get_int(ent, EV_INT_solid) == SOLID_BSP)
			continue;
		
		if (entity_get_float(ent, EV_FL_takedamage) == DAMAGE_NO)
			continue;
		
		if (npc == ent)
			continue;
		
		new Float:origin2[3];
		entity_get_vector(ent, EV_VEC_origin, origin2);
		
		v[0] += origin2[0] - origin[0];
		v[1] += origin2[1] - origin[1];
		v[2] += origin2[2] - origin[2];
		count++;
	}
	
	if (count == 0)
		return v;
	
	xs_vec_div_scalar(v, float(count), v);
	xs_vec_mul_scalar(v, -1.0, v);
	xs_vec_normalize(v, v);
	xs_vec_mul_scalar(v, force, v);
	
	return v;
}

stock truncate(Float:vector[3], Float:max)
{
	new Float:i;
	i = max / vector_length(vector);
	i = (i < 1.0) ? i : 1.0;
	
	xs_vec_mul_scalar(vector, i, vector)
}

stock Float:collisionAvoidance(npc, Float:maxspeed, Float:force)
{
	new Float:position[3], Float:velocity[3], Float:angles[3];
	entity_get_vector(npc, EV_VEC_origin, position);
	entity_get_vector(npc, EV_VEC_velocity, velocity);
	entity_get_vector(npc, EV_VEC_angles, angles);
	
	new Float:ahead[3];
	angle_vector(angles, ANGLEVECTOR_FORWARD, ahead);
	xs_vec_mul_scalar(ahead, floatmax(vector_length(velocity), 50.0), ahead);
	xs_vec_add(position, ahead, ahead);
	
	drawLine2(0, position, ahead, g_sprBeam4, .life=1, .width=10, .color={255, 0, 0}, .alpha=255);
	
	new obstacle = NULL;
	new Float:minDist = 999999.0;
	new Float:radius = get_distance_f(position, ahead) + 100.0;
	new Float:intersect[3];
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, position, radius)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP || entity_get_int(ent, EV_INT_solid) == SOLID_BSP)
			continue;
		
		if (entity_get_float(ent, EV_FL_takedamage) == DAMAGE_NO)
			continue;
		
		if (npc == ent)
			continue;
		
		static Float:origin[3], Float:mins[3], Float:maxs[3];
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		
		xs_vec_add(origin, mins, mins);
		xs_vec_add(origin, maxs, maxs);
		
		static Float:intersect2[3];
		if (intersectSegmentBox2(position, ahead, mins, maxs, intersect2))
		{
			new Float:dist = get_distance_f(position, origin);
			if (dist < minDist)
			{
				obstacle = ent;
				minDist = dist;
				intersect = intersect2;
			}
		}
	}
	
	new Float:avoidance[3];
	if (obstacle != NULL)
	{
		new Float:center[3];
		entity_get_vector(obstacle, EV_VEC_origin, center);
		
		//distPointSegment(center, position, ahead, intersect);
		
		xs_vec_sub(intersect, center, avoidance);
		xs_vec_normalize(avoidance, avoidance);
		xs_vec_mul_scalar(avoidance, force, avoidance);
		
		//client_print(0, print_chat, "obstacle = %d", obstacle);
	}
	
	return avoidance;
}

stock bool:intersectSegmentBox(Float:begin[3], Float:end[3], Float:mins[3], Float:maxs[3], Float:output[3])
{
	new Float:beginToEnd[3], Float:beginToMin[3], Float:beginToMax[3];
	xs_vec_sub(end, begin, beginToEnd);
	xs_vec_sub(mins, begin, beginToMin);
	xs_vec_sub(maxs, begin, beginToMax);
	
	new Float:tNear = -99999999.0;
	new Float:tFar = 99999999.0;
	
	for (new i = 0; i < 3; i++)
	{
		if (beginToEnd[i] == 0.0)
		{
			if (beginToMin[i] > 0.0 || beginToMax[i] < 0.0)
				return false;
		}
		else
		{
			new Float:t1 = beginToMin[i] / beginToEnd[i];
			new Float:t2 = beginToMax[i] / beginToEnd[i];
			new Float:tMin = floatmin(t1, t2);
			new Float:tMax = floatmin(t1, t2);
			
			if (tMin > tNear) tNear = tMin;
			if (tMax < tFar) tFar = tMax;
			if (tNear > tFar || tFar < 0.0)
				return false;
		}
	}
	
	if (tNear >= 0.0 && tNear <= 1.0)
	{
		xs_vec_mul_scalar(output, tNear, output);
		xs_vec_add(begin, output, output);
		return true;
	}
	
	if (tFar >= 0.0 && tFar <= 1.0)
	{
		xs_vec_mul_scalar(output, tFar, output);
		xs_vec_add(begin, output, output);
		return true;
	}
	
	return false;
}

stock bool:intersectSegmentBox2(Float:begin[3], Float:end[3], Float:mins[3], Float:maxs[3], Float:output[3])
{
	new Float:st, Float:et, Float:fst = 0.0, Float:fet = 1.0;
	new Float:bmin, Float:bmax;
	new Float:si, Float:ei;
	
	for (new i = 0; i < 3; i++)
	{
		bmin = mins[i];
		bmax = maxs[i];
		si = begin[i];
		ei = end[i];
		
		if (si < ei)
		{
			if (si > bmax || ei < bmin)
				return false;
			
			new Float:di = ei - si;
			st = (si < bmin) ? (bmin - si) / di : 0.0;
			et = (ei > bmax) ? (bmax - si) / di : 1.0;
		}
		else
		{
			if (ei > bmax || si < bmin)
				return false;
			
			new Float:di = ei - si;
			st = (si > bmax) ? (bmax - si) / di : 0.0;
			et = (ei < bmin) ? (bmin - si) / di : 1.0;
		}
		
		if (st > fst) fst = st;
		if (et < fet) fet = et;
		if (fet < fst)
			return false;
	}
	
	xs_vec_sub(end, begin, output);
	xs_vec_mul_scalar(output, fst, output);
	xs_vec_add(begin, output, output);
	return true;
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