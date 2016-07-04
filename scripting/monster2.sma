#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

native wp_dijkstra(ent, source, target);
native wp_get_origin(point, Float:origin[3]);
native wp_find_closest(Float:origin[3], Float:distance);

new g_come;

public plugin_precache()
{
	precache_model("models/scientist.mdl");
}

public plugin_init()
{
	register_plugin("Monster", "0.1", "Colgate");
	
	register_clcmd("say /monster", "cmdMonster");
	register_clcmd("say /come", "cmdCome");
	register_clcmd("say /stop", "cmdStop");
	register_think("monster_test", "thinkMonster");
}

public client_disconnected(id)
{
	if (g_come == id)
		g_come = 0;
}

public cmdMonster(id)
{
	new Float:origin[3];
	pev(id, pev_origin, origin);
	origin[2] += 72.0;
	
	new ent = create_entity("info_target");
	
	entity_set_model(ent, "models/scientist.mdl");
	entity_set_size(ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 72.0});
	entity_set_origin(ent, origin);
	set_pev(ent, pev_oldorigin, origin);
	
	set_pev(ent, pev_classname, "monster_test");
	
	set_pev(ent, pev_takedamage, DAMAGE_YES);
	set_pev(ent, pev_health, 100.0);
	set_pev(ent, pev_solid, SOLID_SLIDEBOX);
	set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_MONSTER);
	
	set_pev(ent, pev_sequence, 2);
	set_pev(ent, pev_animtime, get_gametime());
	set_pev(ent, pev_framerate, 1.0);
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

public cmdCome(id)
{
	g_come = id;
}

public cmdStop(id)
{
	g_come = 0;
}

public thinkMonster(ent)
{
	new Float:currentTime = get_gametime();
	
	if (g_come)
	{
		new Float:start[3], Float:end[3];
		pev(ent, pev_origin, start);
		pev(g_come, pev_origin, end);
		
		new Float:source_origin[3], Float:target_origin[3];
		
		new source = wp_find_closest(start, 9999.0);
		new target = wp_find_closest(end, 9999.0);
		
		wp_get_origin(source, source_origin);
		wp_get_origin(target, target_origin);
		
		if (isHullFree(ent, source_origin, target_origin) && isHullFree(ent, start, target_origin))
		{
			set_pev(ent, pev_oldorigin, start);
		}
		else
		{
			new Float:origin[3];
			pev(ent, pev_oldorigin, origin);
			
			if (!isWayReachable(ent, start, origin) || get_distance_f(start, origin) <= 50.0)
			{
				source = wp_find_closest(start, 9999.0);
				target = wp_find_closest(end, 9999.0);
				new result = wp_dijkstra(ent, source, target);
				
				if (result != -1)
				{
					wp_get_origin(result, origin);
					set_pev(ent, pev_oldorigin, origin);
					
					end = origin;
				}
			}
			else
			{
				end = origin;
			}
		}
		
		new Float:steering[3];
		xs_vec_add(steering, seek(ent, end), steering);
		xs_vec_add(steering, separation(ent, 75.0), steering);
		
		new Float:velocity[3];
		pev(ent, pev_avelocity, velocity);
		
		truncate(steering, 40.0);
		xs_vec_add(velocity, steering, velocity);
		truncate(velocity, 220.0);
		
		// set velocity
		new Float:old_velocity[3];
		pev(ent, pev_velocity, old_velocity);
		old_velocity[0] = velocity[0];
		old_velocity[1] = velocity[1];
		
		set_pev(ent, pev_velocity, old_velocity);
		set_pev(ent, pev_avelocity, old_velocity);
		
		// set angles
		new Float:angles[3];
		vector_to_angle(velocity, angles);
		angles[0] = 0.0;
		
		set_pev(ent, pev_angles, angles);
		
		// make monster can upstair
		engfunc(EngFunc_WalkMove, ent, angles[1], 2.0, WALKMOVE_NORMAL);
		
		/*
		new Float:vector[3];
		xs_vec_sub(end, start, vector);
		xs_vec_normalize(vector, vector);
		xs_vec_mul_scalar(vector, 200.0, vector);
		
		new Float:velocity[3];
		pev(ent, pev_avelocity, velocity);
		
		new Float:steering[3];
		xs_vec_sub(vector, velocity, steering);
		
		truncate(steering, 40.0);
		
		xs_vec_add(velocity, steering, velocity);
		truncate(velocity, 200.0);
		
		pev(ent, pev_velocity, vector);
		vector[0] = velocity[0];
		vector[1] = velocity[1];
		
		set_pev(ent, pev_velocity, vector);
		set_pev(ent, pev_avelocity, vector);
		
		new Float:angles[3];
		vector_to_angle(velocity, angles);
		angles[0] = 0.0;
		
		set_pev(ent, pev_angles, angles);
		
		engfunc(EngFunc_WalkMove, ent, angles[1], 1.0, WALKMOVE_NORMAL);*/
	}
	
	set_pev(ent, pev_nextthink, currentTime + 0.1);
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

stock truncate(Float:vector[3], Float:max)
{
	new Float:i;
	i = max / vector_length(vector);
	i = (i < 1.0) ? i : 1.0;
	xs_vec_mul_scalar(vector, i, vector)
}

stock isWayReachable(ent, Float:start[3], Float:end[3])
{
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, ent, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}

stock bool:isHullFree(ent, Float:start[3], Float:end[3])
{
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	new Float:source[3], Float:target[3];
	
	source = start;
	target = end;
	
	source[2] += 16.0;
	target[2] += 16.0;
	
	engfunc(EngFunc_TraceLine, source, target, IGNORE_MONSTERS, ent, 0);
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	source = start;
	target = end;
	
	source[2] -= 16.0;
	target[2] -= 16.0;
	
	engfunc(EngFunc_TraceLine, source, target, IGNORE_MONSTERS, ent, 0);
	get_tr2(0, TR_flFraction, fraction);
	
	if (fraction < 1.0)
		return false;
	
	return true;
}