#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

#define NULL -1

#define ANIM_IDLE 1
#define ANIM_RUN 4

native Array:wp_aStar(start, goal);
native wp_getOrigin(point, Float:origin[3]);
native Float:wp_getRange(point);
native wp_findClosestPoint(Float:origin[3], Float:distance=999999.0);
native Float:wp_distPointSegment(Float:p[3], Float:sp1[3], Float:sp2[3], Float:output[3]);
native Float:wp_findClosestPointBetweenPaths(Float:origin[3], path[2], Float:output[3]);

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
	register_clcmd("say /intersect", "CmdIntersect");
	
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
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	new Float:start[3], Float:end[3];
	start = origin;
	entity_get_vector(id, EV_VEC_view_ofs, end);
	xs_vec_add(start, end, start);
	
	velocity_by_aim(id, 9999, end);
	xs_vec_add(end, start, end);
	
	new Float:hit[3];
	new ent = -1;
	
	while ((ent = find_ent_in_sphere(ent, origin, 500.0)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP || entity_get_int(ent, EV_INT_solid) == SOLID_BSP)
			continue;
		
		if (id == ent)
			continue;
		
		static Float:pos[3], Float:mins[3], Float:maxs[3];
		entity_get_vector(ent, EV_VEC_origin, pos);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		
		if (intersectLineBox(mins, maxs, start, end, hit))
			break;
	}
	
	drawLine(id, 
			hit[0], hit[1], hit[2]-5.0,
			hit[0], hit[1], hit[2]+5.0,
			g_sprBeam4, .life=100, .width=20, .color={255, 0, 0}, .alpha=255);
}

public ThinkNpc(npc)
{
	new Float:velocity[3];
	if (g_follow)
	{
		new Float:target[3];
		new Float:origin[3], Float:origin2[3];
		entity_get_vector(npc, EV_VEC_origin, origin);
		entity_get_vector(g_follow, EV_VEC_origin, origin2);
		
		if (get_gametime() >= entity_get_float(npc, EV_FL_ltime) + 0.2)
		{
			new start = entity_get_int(npc, EV_INT_iuser1);
			if (start == NULL)
				start = wp_findClosestPoint(origin);
			else
			{
				new Float:origin3[3];
				wp_getOrigin(start, origin3);
				
				if (get_distance_f(origin, origin3) > 350)
					start = wp_findClosestPoint(origin);
			}
			
			new goal = wp_findClosestPoint(origin2);
			
			new Array:path = wp_aStar(start, goal);
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
					new p = ArrayGetCell(path, 1);

					new Float:origin3[3];
					wp_getOrigin(p, origin3);
					
					if (get_distance_f(origin, origin3) <= wp_getRange(p))
					{
						entity_set_int(npc, EV_INT_iuser1, p);
					}
					
					target = origin3;
				}
				
				ArrayDestroy(path);
			}
			else
			{
				target = Float:{999999.0, 0.0, 0.0};
			}
			
			entity_set_vector(npc, EV_VEC_oldorigin, target);
			entity_set_float(npc, EV_FL_ltime, get_gametime());
		}
		
		entity_get_vector(npc, EV_VEC_oldorigin, target);
		
		if (target[0] != 999999.0)
		{
			new Float:steering[3];
			xs_vec_add(steering, seek(npc, target, 200.0), steering);
			//xs_vec_add(steering, separation(npc, 125.0), steering);
			
			new Float:avelocity[3];
			entity_get_vector(npc, EV_VEC_avelocity, avelocity);
			
			truncate(steering, 50.0);
			xs_vec_div_scalar(steering, 2.5, steering);
			xs_vec_add(avelocity, steering, avelocity);
			truncate(avelocity, 200.0);
			
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

stock findClosestLine(Float:origin[3], Array:path, indexes[2], Float:output[3])
{
	new size = ArraySize(path);
	if (size < 2)
		return false;
	
	new Float:minDist = 999999.0;
	
	for (new i = 0; i < (size-1); i++)
	{
		new p1 = ArrayGetCell(path, i);
		new p2 = ArrayGetCell(path, i+1);
		
		new Float:origin1[3], Float:origin2[3];
		wp_getOrigin(p1, origin1);
		wp_getOrigin(p2, origin2);
		
		new Float:origin3[3];
		new Float:dist = wp_distPointSegment(origin, origin1, origin2, origin3);
		if (dist < minDist)
		{
			indexes[0] = i;
			indexes[1] = i+1;
			output = origin3;
			minDist = dist;
		}
	}
	
	return true;
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

stock Float:separation(npc, Float:force)
{
	new Float:v[3];
	new count = 0;
	
	new Float:origin[3];
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, 80.0)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP || entity_get_int(ent, EV_INT_solid) == SOLID_BSP)
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
	
	client_print(0, print_chat, "count = %d", count);
	
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

stock intersectLineBox(Float:b1[3], Float:b2[3], Float:l1[3], Float:l2[3], Float:output[3])
{
	if (l2[0] < b1[0] && l1[0] < b1[0]) return false;
	if (l2[0] > b2[0] && l1[0] > b2[0]) return false;
	if (l2[1] < b1[1] && l1[1] < b1[1]) return false;
	if (l2[1] > b2[1] && l1[1] > b2[1]) return false;
	if (l2[2] < b1[2] && l1[2] < b1[2]) return false;
	if (l2[2] > b2[2] && l1[2] > b2[2]) return false;
	
	if (l1[0] > b1[0] && l1[0] < b2[0] && l1[1] > b1[1] && l1[1] < b2[1] && l1[2] > b1[2] && l1[2] < b2[2]) 
	{
		output = l1;
		return true;
	}
	
	if ( (intersection(l1[0]-b1[0], l2[0]-b1[0], l1, l2, output) && isInBox(output, b1, b2, 1))
	|| (intersection(l1[1]-b1[1], l2[1]-b1[1], l1, l2, output) && isInBox(output, b1, b2, 2)) 
	|| (intersection(l1[2]-b1[2], l2[2]-b1[2], l1, l2, output) && isInBox(output, b1, b2, 3)) 
	|| (intersection(l1[0]-b2[0], l2[0]-b2[0], l1, l2, output) && isInBox(output, b1, b2, 1)) 
	|| (intersection(l1[1]-b2[1], l2[1]-b2[1], l1, l2, output) && isInBox(output, b1, b2, 2)) 
	|| (intersection(l1[2]-b2[2], l2[2]-b2[2], l1, l2, output) && isInBox(output, b1, b2, 3)) )
		return true;
	
	return false;
}

stock intersection(Float:dst1, Float:dst2, Float:p1[3], Float:p2[3], Float:output[3])
{
	if ((dst1 * dst2) >= 0.0)
		return 0;
		
	if (dst1 == dst2)
		return 0;
	
	new Float:mul = (-dst1 / (dst2 - dst1));
	output[0] = p1[0] + (p2[0] - p1[0]) * mul;
	output[1] = p1[1] + (p2[1] - p1[1]) * mul;
	output[2] = p1[2] + (p2[2] - p1[2]) * mul;
	
	return 1;
}

stock isInBox(Float:hit[3], Float:b1[3], Float:b2[3], axis)
{
	if (axis == 1 && hit[2] > b1[2] && hit[2] < b2[2] && hit[1] > b1[1] && hit[1] < b2[1]) return 1;
	if (axis == 2 && hit[2] > b1[2] && hit[2] < b2[2] && hit[0] > b1[0] && hit[0] < b2[0]) return 1;
	if (axis == 3 && hit[0] > b1[0] && hit[0] < b2[0] && hit[1] > b1[1] && hit[1] < b2[1]) return 1;
	
	return 0;
}