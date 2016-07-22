#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <zombiemode>

#define VERSION "0.1"

new const SOUND_LEAP[][] = {"fai_zombie/Hunter_LJump1.wav", "fai_zombie/Hunter_LJump2.wav"}

new const ZOMBIE_NAME[] = "Hunter"
new const ZOMBIE_INFO[] = "Long jump, Wall jump"
new const ZOMBIE_MODEL[] = "fai_hunter"
new const ZOMBIE_VMODEL[] = "fai_zombie/v_knife_zombie_hunter.mdl"
const ZOMBIE_HEALTH = 500;
const ZOMBIE_SPEED = 240
const Float:ZOMBIE_GRAVITY = 0.5;
const Float:ZOMBIE_KNOCKBACK = 2.0;

new g_hunter;

new Float:g_lastTouchTime[33];
new Float:g_lastLeapTime[33];

public plugin_precache()
{
	for (new i = 0; i < sizeof(SOUND_LEAP); i++)
	{
		precache_sound(SOUND_LEAP[i]);
	}
	
	g_hunter = zb_register_zombie_class(ZOMBIE_NAME, ZOMBIE_INFO, ZOMBIE_MODEL, ZOMBIE_VMODEL, ZOMBIE_HEALTH, ZOMBIE_SPEED, ZOMBIE_GRAVITY, ZOMBIE_KNOCKBACK);
}

public plugin_init()
{
	register_plugin("[FxG] Zombie Hunter", VERSION, "penguinux");
	
	register_touch("player", "*", "OnPlayerTouch");
	RegisterHam(Ham_Player_Jump, "player", "OnPlayerJump");
}

public OnPlayerTouch(id, touched)
{
	g_lastTouchTime[id] = get_gametime();
}

public OnPlayerJump(id)
{
	if (!zb_get_user_zombie(id) || zb_get_user_zombie_class(id) != g_hunter)
		return;
	
	if ((pev(id, pev_button) & IN_DUCK) && !(pev(id, pev_oldbuttons) & IN_JUMP))
	{
		if (((pev(id, pev_flags) & FL_ONGROUND) && get_gametime() >= g_lastLeapTime[id] + 1.5) 
		|| (get_gametime() < g_lastTouchTime[id] + 0.25 && get_gametime() >= g_lastLeapTime[id] + 0.3))
		{
			new Float:velocity[3], Float:angles[3], Float:vector[3];
			pev(id, pev_velocity, velocity);
			pev(id, pev_v_angle, angles);
			if (angles[0] > -25.0)
				angles[0] = -25.0;
			
			angle_vector(angles, ANGLEVECTOR_FORWARD, vector);
			xs_vec_mul_scalar(vector, 500.0, vector);
			xs_vec_add(velocity, vector, velocity);
			
			set_pev(id, pev_velocity, velocity);
			
			if (get_gametime() - g_lastLeapTime[id] >= 1.5)
				emit_sound(id, CHAN_VOICE, SOUND_LEAP[random(sizeof SOUND_LEAP)], 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			g_lastLeapTime[id] = get_gametime();
		}
	}
}

public zb_user_infected_post(id, infector)
{
	if (zb_get_user_zombie_class(id) != g_hunter)
		return;
	
	client_print(id, print_chat, "[Hunter] 按CTRL+SPACE使用長跳, 在牆上可以彈牆跳");
}  
