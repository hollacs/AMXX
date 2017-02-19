#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define MAX_FORCE 50.0
#define MAX_SEE_AHEAD 

new spr_bloodDrop;
new	spr_bloodSpray;
new spr_Beam4;

public plugin_precache()
{
	spr_Beam4 = precache_model("sprites/zbeam4.spr");
	spr_bloodDrop = precache_model("sprites/blood.spr");
	spr_bloodSpray = precache_model("sprites/bloodspray.spr");
}

public plugin_init()
{
	register_plugin("NPC", "0.1", "penguinux");
	
	register_clcmd("npc", "CmdNpc");
	register_clcmd("obj", "CmdObj");
	register_clcmd("test", "CmdTest");

	register_think("monster_test", "ThinkMonster");

	register_forward(FM_AddToFullPack, "OnAddToFullPack_Post", 1);
	
	RegisterHam(Ham_TraceAttack, "info_target", "OnTraceAttack");
	RegisterHam(Ham_TakeDamage, "info_target", "OnTakeDamage");
}

public CmdTest(id)
{
	new Float:haha[3];
	collisionAvoidance(id, 999.0, haha);
}

public CmdNpc(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	origin[2] += 80.0;
	
	new ent = create_entity("info_target");
	if (is_valid_ent(ent))
	{
		entity_set_string(ent, EV_SZ_classname, "monster_test");
		
		entity_set_model(ent, "models/player/vip/vip.mdl");
		entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
		entity_set_origin(ent, origin);
		
		entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
		entity_set_float(ent, EV_FL_health, 1000.0);
		entity_set_float(ent, EV_FL_max_health, 1000.0);
		entity_set_float(ent, EV_FL_maxspeed, 200.0);
		entity_set_int(ent, EV_INT_weaponanim, 1); // mass
		
		entity_set_int(ent, EV_INT_gamestate, 1); // no shield
		entity_set_int(ent, EV_INT_deadflag, DEAD_NO);
		entity_set_int(ent, EV_INT_flags, entity_get_int(ent, EV_INT_flags) | FL_MONSTER);
		
		entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_STEP);
		
		entity_set_int(ent, EV_INT_sequence, 4);
		entity_set_float(ent, EV_FL_animtime, get_gametime());
		entity_set_float(ent, EV_FL_framerate, 1.0);
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.1);
	}
}

public CmdObj(id)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	new ent = create_entity("info_target");
	if (is_valid_ent(ent))
	{
		entity_set_model(ent, "models/player/sas/sas.mdl");
		entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
		entity_set_origin(ent, origin);
		
		entity_set_float(ent, EV_FL_health, 100.0);
		
		entity_set_int(ent, EV_INT_gamestate, 1);
		entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_STEP);
		
		entity_set_int(ent, EV_INT_sequence, 1);
		entity_set_float(ent, EV_FL_animtime, get_gametime());
		entity_set_float(ent, EV_FL_framerate, 1.0);
	}
	
	origin[2]+=80.0;
	entity_set_origin(id, origin);
}

public ThinkMonster(npc)
{
	new Float:currentTime = get_gametime();
	
	new Float:origin[3];
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	new enemy = entity_get_edict(npc, EV_ENT_enemy);
	
	if (!is_user_alive(enemy))
	{
		enemy = getClosestPlayer(npc, origin, 1000.0);
		
		// set enemy
		entity_set_edict(npc, EV_ENT_enemy, enemy);
		//entity_set_float(npc, EV_FL_idealpitch, currentTime);
	}
	
	updateMovement(npc);
	
	entity_set_float(npc, EV_FL_nextthink, currentTime + 0.1);
}

public OnTraceAttack(npc, attacker, Float:damage, Float:direction[3], tr, damageBits)
{
	if (!isEntNpc(npc))
		return;
	
	new hitGroup = get_tr2(tr, TR_iHitgroup);
	set_ent_data(npc, "CBaseMonster", "m_LastHitGroup", hitGroup);
	
	new Float:damage2 = applyHitGroupDamage(hitGroup, damage);
	
	if (damage2 > 0.0)
	{
		new Float:hitPos[3];
		get_tr2(tr, TR_vecEndPos, hitPos);
		
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, hitPos);
		write_byte(TE_BLOODSPRITE);
		write_coord_f(hitPos[0]);
		write_coord_f(hitPos[1]);
		write_coord_f(hitPos[2]);
		write_short(spr_bloodSpray);
		write_short(spr_bloodDrop);
		write_byte(248);
		write_byte(clamp(floatround(damage2 * 0.1), 3, 15));
		message_end();
	}
}

public OnTakeDamage(npc, inflictor, attacker, Float:damage, damageBits)
{
	if (!isEntNpc(npc))
		return;
	
	if (is_user_connected(attacker))
	{
		damage = applyHitGroupDamage(get_ent_data(npc, "CBaseMonster", "m_LastHitGroup"), damage);
		client_print(0, print_chat, "damage is %f", damage);
		SetHamParamFloat(4, damage);
	}
}

public OnAddToFullPack_Post(es, e, ent, host, flags, player, pset)
{
	if (get_es(es, ES_MoveType) == MOVETYPE_STEP)
	{
		set_es(es, ES_MoveType, MOVETYPE_PUSHSTEP);
	}
}

stock bool:isEntNpc(ent)
{
	new classname[32];
	entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
	
	if (equal(classname, "monster_test"))
		return true;
	
	return false;
}

stock Float:applyHitGroupDamage(hitGroup, Float:damage)
{
	switch (hitGroup)
	{
		case HIT_HEAD:
			damage *= 4.0;
		case HIT_CHEST:
			damage *= 1.0;
		case HIT_STOMACH:
			damage *= 1.25;
		case HIT_LEFTLEG, HIT_RIGHTLEG:
			damage *= 0.75;
	}
	
	return damage;
}

stock updateMovement(npc)
{
	new enemy = entity_get_edict(npc, EV_ENT_enemy);
	if (is_user_alive(enemy))
	{
		new Float:steering[3];
		
		new Float:origin[3];
		entity_get_vector(enemy, EV_VEC_origin, origin);
		
		// do steer
		doSeek(npc, origin, 64.0, steering);
		collisionAvoidance(npc, 50.0, steering);
		updateSteering(npc, steering);
		
		new Float:velocity[3];
		entity_get_vector(npc, EV_VEC_velocity, velocity);
		
		// set npc angles
		new Float:angles[3];
		vector_to_angle(velocity, angles);
		angles[0] = 0.0;
		entity_set_vector(npc, EV_VEC_angles, angles);
		
		// let npc up stairs
		new Float:target[3];
		entity_get_vector(npc, EV_VEC_origin, origin);
		xs_vec_add(origin, velocity, target);
		
		engfunc(EngFunc_MoveToOrigin, npc, target, 0.5, MOVE_STRAFE);
	}
}

stock updateSteering(npc, Float:steering[3])
{	
	truncate(steering, MAX_FORCE);
	xs_vec_mul_scalar(steering, 1.0 / float(entity_get_int(npc, EV_INT_weaponanim)), steering);

	new Float:velocity[3];
	entity_get_vector(npc, EV_VEC_avelocity, velocity);
	
	xs_vec_add(velocity, steering, velocity);
	truncate(velocity, entity_get_float(npc, EV_FL_maxspeed));
	
	//client_print(0, print_center, "len = %f", xs_vec_len(velocity));
	entity_set_vector(npc, EV_VEC_velocity, velocity);
	entity_set_vector(npc, EV_VEC_avelocity, velocity);
}

stock Float:doSeek(npc, const Float:target[3], Float:slowingRadius = 100.0, Float:output[3])
{
	new Float:origin[3]
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	new Float:desired[3];
	xs_vec_sub(target, origin, desired);
	
	new Float:distance = xs_vec_len(desired);
	xs_vec_normalize(desired, desired);
	
	if (distance <= slowingRadius)
		xs_vec_mul_scalar(desired, entity_get_float(npc, EV_FL_maxspeed) * distance / slowingRadius, desired);
	else
		xs_vec_mul_scalar(desired, entity_get_float(npc, EV_FL_maxspeed), desired);
	
	new Float:velocity[3];
	entity_get_vector(npc, EV_VEC_avelocity, velocity);
	
	new Float:force[3];
	xs_vec_sub(desired, velocity, force);
	xs_vec_add(force, output, output);
}

stock collisionAvoidance(npc, Float:force, Float:output[3])
{
	new enemy = entity_get_edict(npc, EV_ENT_enemy);
	
	new Float:origin[3], Float:origin2[3];
	entity_get_vector(npc, EV_VEC_origin, origin);
	
	// get npc velocity
	new Float:velocity[3]
	entity_get_vector(npc, EV_VEC_velocity, velocity);
	
	new Float:angles[3], Float:direction[3];
	entity_get_vector(npc, EV_VEC_angles, angles);
	angle_vector(angles, ANGLEVECTOR_FORWARD, direction);
	
	// see ahead
	new Float:aHead[3];
	xs_vec_mul_scalar(direction, floatmax(xs_vec_len(velocity), 100.0), aHead);
	xs_vec_add(origin, aHead, aHead);
	
	new obstacle = FM_NULLENT;
	new Float:near, Float:far, Float:minDist = 999999.0;
	new Float:radius = get_distance_f(origin, aHead) + 150.0;
	new solid;
	
	new ent = FM_NULLENT;

	while ((ent = find_ent_in_sphere(ent, origin, radius)) != 0)
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (npc == ent || ent == enemy)
			continue;

		if (entity_get_int(ent, EV_INT_movetype) == MOVETYPE_PUSHSTEP)
			continue;

		// check solid
		solid = entity_get_int(ent, EV_INT_solid);
		if (solid == SOLID_BSP || solid == SOLID_NOT || solid == SOLID_TRIGGER)
			continue;

		if (isEntBlockingNpc(origin, direction, ent, near, far))
		{
			if (near < minDist)
			{
				obstacle = ent;
				minDist = near;
			}
		}
	}
	
	new Float:avoidance[3];
	
	if (obstacle != FM_NULLENT)
	{
		entity_get_vector(obstacle, EV_VEC_origin, origin2);
		
		new Float:pos[3];
		distPointLine(origin2, origin, aHead, pos);
		
		xs_vec_sub(pos, origin2, avoidance);
		xs_vec_normalize(avoidance, avoidance);
		xs_vec_mul_scalar(avoidance, force, avoidance);

		//new classname[32];
		//entity_get_string(obstacle, EV_SZ_classname, classname, 31);
		//client_print(0, print_chat, "%d(%s) is blocking npc!! trying to avoid...", obstacle, classname);
	}
	
	xs_vec_add(output, avoidance, output);
}

stock isEntBlockingNpc(Float:origin[3], Float:direction[3], ent, &Float:near, &Float:far)
{	
	new Float:mins[3], Float:maxs[3];
	entity_get_vector(ent, EV_VEC_absmin, mins);
	entity_get_vector(ent, EV_VEC_absmax, maxs);
	
	// the center ray
	if (intersectRayBox(origin, direction, mins, maxs, near, far))
		return true;
	
	// get the right direction
	new Float:direction2[3];
	vector_to_angle(direction, direction2);
	angle_vector(direction2, ANGLEVECTOR_RIGHT, direction2);
	
	// move right from npc position a little bit
	new Float:point[3];
	xs_vec_mul_scalar(direction2, 16.0, point);
	xs_vec_add(origin, point, point);
	
	// make the point inside the box
	//makePointInsideBox(point, mins, maxs);
	
	// the right ray
	if (intersectRayBox(point, direction, mins, maxs, near, far))
		return true;
	
	// move left from npc position a little bit
	xs_vec_mul_scalar(direction2, -16.0, point);
	xs_vec_add(origin, point, point);
	
	// make the point inside the box
	//makePointInsideBox(point, mins, maxs);

	// the left ray
	if (intersectRayBox(point, direction, mins, maxs, near, far))
		return true;
	
	return false;
}

stock makePointInsideBox(Float:point[3], const Float:mins[3], const Float:maxs[3])
{
	point[0] = floatclamp(point[0], mins[0], maxs[0]);
	point[1] = floatclamp(point[1], mins[1], maxs[1]);
	point[2] = floatclamp(point[2], mins[2], maxs[2]);
}

stock bool:intersectRayBox(const Float:orig[3], const Float:dir[3], const Float:mins[3], const Float:maxs[3], &Float:tNear, &Float:tFar)
{
	new Float:t1[3], Float:t2[3]; // vectors to hold the T-values for every direction
	tNear = -9999999.0; // maximums defined in float.h
	tFar = 9999999.0;

	// we test slabs in every direction
	for (new i = 0; i < 3; i++)
	{ 
		// ray parallel to planes in this direction
		if (dir[i] == 0.0)
		{ 
			if ((orig[i] < mins[i]) || (orig[i] > maxs[i]))
				return false; // parallel AND outside box : no intersection possible
		}
		else // ray not parallel to planes in this direction
		{ 
			t1[i] = (mins[i] - orig[i]) / dir[i];
			t2[i] = (maxs[i] - orig[i]) / dir[i];

			// we want t1 to hold values for intersection with near plane
			if(t1[i] > t2[i])
			{
				new Float:tmp[3];
				tmp = t1;
				t1 = t2;
				t2 = tmp;
			}
			
			if (t1[i] > tNear)
				tNear = t1[i];

			if (t2[i] < tFar)
				tFar = t2[i];

			if((tNear > tFar) || (tFar < 0))
				return false;
		}
	}
	
	return true; // if we made it here, there was an intersection - YAY
}

stock Float:distPointLine(Float:p[3], Float:lp0[3], Float:lp1[3], Float:output[3])
{
	new Float:v[3], Float:w[3];
	xs_vec_sub(lp1, lp0, v);
	xs_vec_sub(p, lp0, w);
	
	new Float:c1 = xs_vec_dot(w, v);
	new Float:c2 = xs_vec_dot(v, v);
	new Float:b = c1 / c2;
	
	xs_vec_mul_scalar(v, b, output);
	xs_vec_add(lp0, output, output);
	
	return get_distance_f(p, output);
}

stock truncate(Float:vector[3], Float:max)
{
	new Float:i;
	i = max / vector_length(vector);
	i = (i < 1.0) ? i : 1.0;
	
	xs_vec_mul_scalar(vector, i, vector)
}

stock getClosestPlayer(npc, const Float:origin[3], Float:radius)
{
	new closest = 0;
	new player = FM_NULLENT;
	
	while ((player = find_ent_in_sphere(player, origin, radius)) != 0)
	{
		if (!is_user_alive(player))
			continue;
		
		if (entity_range(npc, player) < entity_range(npc, closest) || !closest)
		{
			closest = player;
		}
	}
	
	return closest;
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