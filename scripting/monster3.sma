#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define VERSION "0.1"

#define NULL -1

#define WP_RADIUS 50.0
#define PEV_NEXT pev_iuser1
#define PEV_PREV pev_iuser2

native wp_get_origin(index, Float:origin[3]);
native Array:wp_astar(start, goal);
native wp_get_current(Float:origin[3], Float:distance=9999.0);

new const Float:VEC_HUMAN_HULL_MIN[3] = {-16.0, -16.0, 0.0};
new const Float:VEC_HUMAN_HULL_MAX[3] = {16.0, 16.0, 72.0};

new g_follow;
new g_sprBeam4;

public plugin_precache()
{
	g_sprBeam4 = precache_model("sprites/zbeam4.spr");
}

public plugin_init()
{
	register_plugin("Monster", VERSION, "Colgate");
	
	register_clcmd("say /monster", "CmdSayMonster");
	register_clcmd("say /follow", "CmdSayFollow");
	register_clcmd("say /stay", "CmdSayStay");
	
	register_think("monster_test", "ThinkMonster");
}

public client_disconnected(id)
{
	if (g_follow == id)
		g_follow = 0;
}

public CmdSayMonster(id)
{
	new Float:origin[3];
	pev(id, pev_origin, origin);
	origin[2] += 80.0;
	
	new ent = create_entity("info_target");
	if (pev_valid(ent))
	{
		set_pev(ent, pev_classname, "monster_test");
		
		entity_set_model(ent, "models/player/vip/vip.mdl");
		entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
		entity_set_origin(ent, origin);
		
		set_pev(ent, pev_takedamage, DAMAGE_YES);
		set_pev(ent, pev_health, 500.0);
		set_pev(ent, pev_max_health, pev(ent, pev_health));
		
		set_pev(ent, pev_gamestate, 1); // No shield
		set_pev(ent, pev_deadflag, DEAD_NO);
		set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_MONSTER);
		
		set_pev(ent, pev_solid, SOLID_SLIDEBOX);
		set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
		
		set_pev(ent, PEV_NEXT, NULL);
		set_pev(ent, PEV_PREV, NULL);
		
		set_pev(ent, pev_sequence, 4);
		set_pev(ent, pev_animtime, get_gametime());
		set_pev(ent, pev_framerate, 1.0);
		
		set_pev(ent, pev_nextthink, get_gametime() + 0.1);
	}
}

public CmdSayFollow(id)
{
	g_follow = id;
}

public CmdSayStay(id)
{
	g_follow = 0;
}

public ThinkMonster(ent)
{
	if (g_follow)
	{
		new Float:origin[3], Float:target[3];
		pev(ent, pev_origin, origin);
		pev(g_follow, pev_origin, target);
		
		new next = pev(ent, PEV_NEXT);
		if (next == NULL)
		{
			new start = wp_get_current(origin);
			new goal = wp_get_current(target);
				
			if (start != NULL && goal != NULL)
			{
				new Array:path = wp_astar(start, goal);
				if (path != Invalid_Array)
				{
					new n = max(ArraySize(path) - 2, 0);
					next = ArrayGetCell(path, n);
						
					set_pev(ent, PEV_NEXT, next);
					set_pev(ent, PEV_PREV, NULL);
						
					wp_get_origin(next, target);
				}
			}
		}
		else
		{
			new Float:origin2[3], Float:origin3[3];
			wp_get_origin(next, origin2);
			
			new goal = wp_get_current(target);
			wp_get_origin(goal, origin3);
				
			// We're close enough
			if (get_distance_f(origin, origin2) <= WP_RADIUS)
			{
				if (goal != NULL)
				{
					new Array:path = wp_astar(next, goal);
					if (path != Invalid_Array)
					{
						new n = max(ArraySize(path) - 2, 0);
						
						new prev = next;
						next = ArrayGetCell(path, n);
						set_pev(ent, PEV_NEXT, next);
						
						if (prev != next)
							set_pev(ent, PEV_PREV, prev);
						
						wp_get_origin(next, target);
					}
				}
				
				set_pev(ent, pev_ltime, get_gametime());
			}
			else
			{
				new Float:time;
				pev(ent, pev_ltime, time);
				
				if (get_gametime() >= time + 7.5)
				{
					new prev = next;
					
					next = pev(ent, PEV_PREV);
					if (next == NULL)
						next = wp_get_current(origin);
					
					set_pev(ent, PEV_PREV, prev);
					set_pev(ent, PEV_NEXT, next);
					set_pev(ent, pev_ltime, get_gametime());
				}
				
				wp_get_origin(next, target);
			}
		}
		
		new Float:vector[3];
		xs_vec_sub(target, origin, vector);
		xs_vec_normalize(vector, vector);
		
		xs_vec_mul_scalar(vector, 200.0, vector);
		
		new Float:velocity[3];
		pev(ent, pev_velocity, velocity);
		velocity[0] = vector[0]; velocity[1] = vector[1];
		set_pev(ent, pev_velocity, velocity);
		
		new Float:angles[3];
		vector_to_angle(vector, angles);
		angles[0] = 0.0;
		set_pev(ent, pev_angles, angles);
		
		//engfunc(EngFunc_WalkMove, ent, angles[1], 1.0, WALKMOVE_NORMAL);
		engfunc(EngFunc_MoveToOrigin, ent, target, 1.0, MOVE_STRAFE);
	}
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

stock bool:IsReachable(ent, Float:origin[3])
{
	new Float:start[3], Float:end[3];
	pev(ent, pev_origin, start);
	end = origin;
	
	if (!IsVisible(start, end, IGNORE_MONSTERS, ent))
		return false;
	
	new Float:start2[3], Float:end2[3];
	
	new Float:vector[3];
	xs_vec_sub(end, start, vector);
	xs_vec_normalize(vector, vector);
	vector_to_angle(vector, vector);
	angle_vector(vector, ANGLEVECTOR_RIGHT, vector);
	
	// Right
	xs_vec_mul_scalar(vector, 10.0, start2);
	xs_vec_add(start, start2, start2);
	xs_vec_mul_scalar(vector, 10.0, end2);
	xs_vec_add(end, end2, end2);
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	// Left
	xs_vec_mul_scalar(vector, -10.0, start2);
	xs_vec_add(start, start2, start2);
	xs_vec_mul_scalar(vector, -10.0, end2);
	xs_vec_add(end, end2, end2);
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	// Up right
	xs_vec_mul_scalar(vector, 10.0, start2);
	xs_vec_add(start, start2, start2);
	start2[2] += 20.0;
	xs_vec_mul_scalar(vector, 10.0, end2);
	xs_vec_add(end, end2, end2);
	end2[2] += 20.0;
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	// Up left
	xs_vec_mul_scalar(vector, -10.0, start2);
	xs_vec_add(start, start2, start2);
	start2[2] += 20.0;
	xs_vec_mul_scalar(vector, -10.0, end2);
	xs_vec_add(end, end2, end2);
	end2[2] += 20.0;
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	// Down right
	xs_vec_mul_scalar(vector, 10.0, start2);
	xs_vec_add(start, start2, start2);
	start2[2] -= 20.0;
	xs_vec_mul_scalar(vector, 10.0, end2);
	xs_vec_add(end, end2, end2);
	end2[2] -= 20.0;
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	// Down left
	xs_vec_mul_scalar(vector, -10.0, start2);
	xs_vec_add(start, start2, start2);
	start2[2] -= 20.0;
	xs_vec_mul_scalar(vector, -10.0, end2);
	xs_vec_add(end, end2, end2);
	end2[2] -= 20.0;
	
	if (!IsVisible(start2, end2, IGNORE_MONSTERS, ent))
		return false;
	
	DrawLine2(0, start2, end2, 
		g_sprBeam4, .life=1, .width=10, .color={0, 255, 0}, .alpha=255);
	
	return true;
}

stock bool:IsVisible(Float:start[3], Float:end[3], noMonsters=IGNORE_MONSTERS, skipEnt=0)
{
	engfunc(EngFunc_TraceLine, start, end, noMonsters, skipEnt, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	
	return bool:(fraction >= 1.0);
}

stock DrawLine(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, 
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

stock DrawLine2(id, Float:start[3], Float:end[3], sprite, frame=0, rate=0, life=10, width=10, noise=0, color[3]={255,255,255}, alpha=127, scroll=0)
{
	DrawLine(id, start[0], start[1], start[2], end[0], end[1], end[2], sprite, frame, rate, life, width, noise, color, alpha, scroll);
}

stock bool:IsMonster(ent)
{
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));
	
	return bool:equal(classname, "monster_test");
}