#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

new g_follow;

native Array:node_dijkstra(start, goal);
native node_find_closest(Float:origin[3], Float:distance);
native node_get_origin(node, Float:origin[3]);

public plugin_init()
{
	register_plugin("NPC", "0.1", "Colgate");
	
	register_clcmd("say /zombie", "cmdZombie");
	register_clcmd("say /follow", "cmdFollow");
	
	register_think("monster_test", "thinkMonster");
}

public plugin_precache()
{
	precache_model("models/zombie.mdl");
}

public cmdZombie(id)
{
	new Float:origin[3];
	pev(id, pev_origin, origin);
	origin[2] += 80.0;
	
	new ent = create_entity("info_target");
	
	entity_set_model(ent, "models/zombie.mdl");
	entity_set_size(ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 72.0});
	entity_set_origin(ent, origin);
	
	set_pev(ent, pev_endpos, origin);
	
	set_pev(ent, pev_classname, "monster_test");
	
	set_pev(ent, pev_takedamage, DAMAGE_YES);
	set_pev(ent, pev_health, 100.0);
	set_pev(ent, pev_solid, SOLID_SLIDEBOX);
	set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_MONSTER);
	
	set_pev(ent, pev_sequence, 11);
	set_pev(ent, pev_animtime, 2.0);
	set_pev(ent, pev_framerate, 1.0);
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

public client_disconnected(id)
{
	if (g_follow == id)
		g_follow = 0;
}

public cmdFollow(id)
{
	g_follow = id;
}

public thinkMonster(npc)
{
	new Float:currentTime = get_gametime();
	
	if (g_follow)
	{
		new Float:start[3], Float:end[3];
		pev(npc, pev_origin, start);
		pev(g_follow, pev_origin, end);
		
		new source = node_find_closest(start, 9999.0);
		new target = node_find_closest(end, 9999.0);
		
		new Float:source_origin[3], Float:target_origin[3];
		node_get_origin(source, source_origin);
		node_get_origin(target, target_origin);
		
		if (isPathReachable(npc, source_origin, target_origin) && isPathReachable(npc, start, target_origin) && isPathReachable(npc, start, end))
		{
			set_pev(npc, pev_endpos, start);
		}
		else
		{
			new Float:origin[3], Float:oldorigin[3];
			pev(npc, pev_endpos, origin);
			pev(npc, pev_oldorigin, oldorigin);
			
			if (!xs_vec_equal(start, oldorigin))
			{
				set_pev(npc, pev_ltime, currentTime);
			}
			
			new Float:timeStuck;
			pev(npc, pev_ltime, timeStuck);
			set_pev(npc, pev_oldorigin, start);
			
			if (timeStuck + 5.0 >= currentTime || get_distance_f(start, origin) <= 64.0)
			{
				new Array:path = node_dijkstra(source, target);
				
				if (path != Invalid_Array)
				{
					new size = ArraySize(path);
					new node = ArrayGetCell(path, (size > 1) ? (size - 2) : 0);
					
					node_get_origin(node, origin);
					set_pev(npc, pev_endpos, origin);
				}
			}
			
			end = origin;
		}
		
		new Float:steering[3];
		xs_vec_add(steering, seek(npc, end), steering);
		//xs_vec_add(steering, separation(ent, 75.0), steering);
		
		new Float:velocity[3];
		pev(npc, pev_avelocity, velocity);
		
		truncate(steering, 50.0);
		xs_vec_add(velocity, steering, velocity);
		truncate(velocity, 220.0);
		
		// set velocity
		new Float:old_velocity[3];
		pev(npc, pev_velocity, old_velocity);
		old_velocity[0] = velocity[0];
		old_velocity[1] = velocity[1];
		
		set_pev(npc, pev_velocity, old_velocity);
		set_pev(npc, pev_avelocity, old_velocity);
		
		// set angles
		new Float:angles[3];
		vector_to_angle(velocity, angles);
		angles[0] = 0.0;
		
		set_pev(npc, pev_angles, angles);
		
		engfunc(EngFunc_WalkMove, npc, angles[1], 1.0, WALKMOVE_NORMAL);
	}
	
	set_pev(npc, pev_nextthink, currentTime + 0.1);
}

stock truncate(Float:vector[3], Float:max)
{
	new Float:i;
	i = max / vector_length(vector);
	i = (i < 1.0) ? i : 1.0;
	xs_vec_mul_scalar(vector, i, vector)
}

stock Float:seek(ent, Float:target[3])
{
	new Float:origin[3];
	pev(ent, pev_origin, origin);
	
	new Float:desired[3];
	xs_vec_sub(target, origin, desired);
	xs_vec_normalize(desired, desired);
	xs_vec_mul_scalar(desired, 220.0, desired);
	
	new Float:velocity[3];
	pev(ent, pev_avelocity, velocity);
	
	new Float:force[3];
	xs_vec_sub(desired, velocity, force);
	
	return force;
}

stock Float:separation(npc, Float:force)
{
	new Float:v[3];
	new count = 0;
	
	new Float:origin[3];
	pev(npc, pev_origin, origin);
	
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, 80.0)))
	{
		if (~pev(ent, pev_flags) & FL_MONSTER)
			continue;
		
		if (npc == ent)
			continue;
		
		new Float:origin2[3];
		pev(ent, pev_origin, origin2);
		
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

bool:isPathReachable(ent, Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, hull=HULL_HEAD)
{
	engfunc(EngFunc_TraceHull, start, end, noMonsters, hull, ent, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	engfunc(EngFunc_TraceLine, start, end, noMonsters, ent, 0);
	
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

set_angles(ent, Float:angles[3], Float:max)
{
	new Float:angles2[3];
	pev(ent, pev_angles, angles2);
 
	new Float:a = compare_angles(angles, angles2);
	if (floatabs(a) > max)
	{
		a = angles2[1] + floatclamp(a, -max, max);
		angles2[1] = fixed_angles(a);
	}
	else
	{
		angles2[1] = angles[1];
	}
 
	angles2[0] = angles[0], angles2[2] = angles[2];
	set_pev(ent, pev_angles, angles2);
}

Float:compare_angles(Float:angles[3], Float:angles2[3])
{
	return fixed_angles(angles[1] - angles2[1]);
}

Float:fixed_angles(Float:a)
{
	return a + ((a > 180) ? -360.0 : (a < -180) ? 360.0 : 0.0);
}