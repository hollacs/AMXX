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
	register_clcmd("npc_follow", "CmdNpcFollow");
	
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

public ThinkNpc(npc)
{
	if (g_follow)
	{
		new Float:target[3];
		new Float:origin[3], Float:origin2[3];
		pev(npc, pev_origin, origin);
		pev(g_follow, pev_origin, origin2);
		
		if (get_gametime() >= entity_get_float(npc, EV_FL_ltime) + 0.25)
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
			
			entity_set_vector(npc, EV_VEC_oldorigin, target);
			entity_set_float(npc, EV_FL_ltime, get_gametime());
		}
		
		entity_get_vector(npc, EV_VEC_oldorigin, target);
		
		new Float:steering[3];
		xs_vec_add(steering, seek(npc, target, 200.0), steering);
		
		new Float:avelocity[3];
		pev(npc, pev_avelocity, avelocity);
		
		truncate(steering, 10.0);
		xs_vec_div_scalar(steering, 2.5, steering);
		xs_vec_add(avelocity, steering, avelocity);
		truncate(avelocity, 200.0);
		
		new Float:velocity[3];
		pev(npc, pev_velocity, velocity);
		
		velocity[0] = avelocity[0];
		velocity[1] = avelocity[1];
		
		set_pev(npc, pev_velocity, velocity);
		set_pev(npc, pev_avelocity, velocity);
		
		new Float:angles[3];
		vector_to_angle(avelocity, angles);
		angles[0] = 0.0;
		set_pev(npc, pev_angles, angles);
		
		engfunc(EngFunc_MoveToOrigin, npc, target, 0.1, MOVE_STRAFE);
		
		if (xs_vec_len(velocity) > 1)
			entity_set_int(npc, EV_INT_sequence, ANIM_RUN);
		else
			entity_set_int(npc, EV_INT_sequence, ANIM_IDLE);
	}
	
	entity_set_float(npc, EV_FL_nextthink, get_gametime() + 0.01);
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
	pev(ent, pev_origin, origin);
	
	new Float:desired[3];
	xs_vec_sub(target, origin, desired);
	xs_vec_normalize(desired, desired);
	xs_vec_mul_scalar(desired, maxspeed, desired);
	
	new Float:velocity[3];
	pev(ent, pev_avelocity, velocity);
	
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