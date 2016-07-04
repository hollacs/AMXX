#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <orpheu>

#define GUN_DEFAULT_GIVE 30
#define GUN_AMMO_NAME "762Nato"
#define GUN_MAX_AMMO 90
#define GUN_MAX_CLIP 30
#define GUN_WEIGHT 25

enum
{
	PLAYER_IDLE,
	PLAYER_WALK,
	PLAYER_JUMP,
	PLAYER_SUPERJUMP,
	PLAYER_DIE,
	PLAYER_ATTACK1,
	PLAYER_ATTACK2,
	PLAYER_FLINCH,
	PLAYER_LARGE_FLINCH,
	PLAYER_RELOAD,
	PLAYER_HOLDBOMB
}

enum
{
	BULLET_NONE,
	BULLET_PLAYER_9MM,
	BULLET_PLAYER_MP5,
	BULLET_PLAYER_357,
	BULLET_PLAYER_BUCKSHOT,
	BULLET_PLAYER_CROWBAR,
	BULLET_MONSTER_9MM,
	BULLET_MONSTER_MP5,
	BULLET_MONSTER_12MM,
	BULLET_PLAYER_45ACP,
	BULLET_PLAYER_338MAG,
	BULLET_PLAYER_762MM,
	BULLET_PLAYER_556MM,
	BULLET_PLAYER_50AE,
	BULLET_PLAYER_57MM,
	BULLET_PLAYER_357SIG,
};

enum
{
	AK47_IDLE1,
	AK47_RELOAD,
	AK47_DRAW,
	AK47_SHOOT1,
	AK47_SHOOT2,
	AK47_SHOOT3
};

public plugin_init()
{
	register_plugin("Knife Gun", "0.1", "Colgate");
	
	RegisterHam(Ham_Spawn, "weapon_knife", "OnKnifeSpawn_Post", 1);
	RegisterHam(Ham_Item_GetItemInfo, "weapon_knife", "OnKnifeGetItemInfo_Post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "OnKnifePrimaryAttack");
}

public OnKnifeSpawn_Post(ent)
{
	set_ent_data(ent, "CBasePlayerWeapon", "m_iDefaultAmmo", GUN_DEFAULT_GIVE);
	set_ent_data_float(ent, "CBasePlayerWeapon", "m_flAccuracy", 0.2);
	set_ent_data(ent, "CBasePlayerWeapon", "m_iShotsFired", 0);
}

public OnKnifeGetItemInfo_Post(ent, itemInfoHandle)
{
	SetHamItemInfo(itemInfoHandle, Ham_ItemInfo_pszAmmo1, GUN_AMMO_NAME);
	SetHamItemInfo(itemInfoHandle, Ham_ItemInfo_iMaxAmmo1, GUN_MAX_AMMO);
	SetHamItemInfo(itemInfoHandle, Ham_ItemInfo_iMaxClip, GUN_MAX_CLIP);
	SetHamItemInfo(itemInfoHandle, Ham_ItemInfo_iWeight, AK47_WEIGHT);
}

public OnKnifeDeploy_Post(ent)
{
	new player = get_ent_data(ent, "CBasePlayerItem", "m_pPlayer");
	
	set_ent_data_float(ent, "CBasePlayerWeapon", "m_flAccuracy", 0.2);
	set_ent_data(ent, "CBasePlayerWeapon", "m_iShotsFired", 0);
	
	SendWeaponAnim(player, AK47_DRAW);
	
	set_pev(player, pev_viewmodel2, "models/v_ak47.mdl");
	set_pev(player, pev_weaponmodel2, "models/p_ak47.mdl");
}

public OnKnifePrimaryAttack(ent)
{
	new player = get_ent_data(ent, "CBasePlayerItem", "m_pPlayer");
	new Float:accuracy = Float:get_ent_data_float(ent, "CBasePlayerWeapon", "m_flAccuracy"); 
	new Float:velocity[3];
	pev(player, pev_velocity, velocity);
	velocity[2] = 0.0;
	
	if (!(pev(player, pev_flags) & FL_ONGROUND))
	{
		GunFire(ent, 0.04 + (0.4 * accuracy), 0.0955);
	}
	else if (vector_length(velocity) > 140.0)
	{
		GunFire(ent, 0.04 + (0.07 * accuracy), 0.0955);
	}
	else
	{
		GunFire(ent, 0.0275 * accuracy, 0.0955);
	}
}

public GunFire(ent, Float:spread, Float:cycleTime)
{
	new player = get_ent_data(ent, "CBasePlayerItem", "m_pPlayer");
	new shotsFired = get_ent_data(ent, "CBasePlayerWeapon", "m_iShotsFired");
	
	set_ent_data(ent, "CBasePlayerWeapon", "m_bDelayFire", true);
	set_ent_data(ent, "CBasePlayerWeapon", "m_iShotsFired", shotsFired + 1);
	
	new Float:accuracy = ((shotsFired * shotsFired * shotsFired) / 200.0) + 0.35;
	if (accuracy > 1.25)
		accuracy = 1.25;
	
	set_ent_data_float(ent, "CBasePlayerWeapon", "m_flAccuracy", accuracy);
	
	if (get_ent_data(ent, "CBasePlayerWeapon", "m_iClip") <= 0)
	{
		if (get_ent_data(ent, "CBasePlayerWeapon", "m_fFireOnEmpty"))
		{
			PlayEmptySound(ent);
			set_ent_data_float(ent, "CBasePlayerWeapon", "m_flNextPrimaryAttack", GetNextAttackDelay(ent, 0.2));
		}
	}
	
	set_ent_data(ent, "CBasePlayerWeapon", "m_iClip", get_ent_data(ent, "CBasePlayerWeapon", "m_iClip") - 1);
	
	set_pev(player, pev_effects, pev(player, pev_effects) |= EF_MUZZLEFLASH);
	SetAnimation(player, PLAYER_ATTACK1);
	
	new Float:v_angle[3], Float:punchangle[3];
	pev(player, pev_v_angle, v_angle);
	pev(player, pev_punchangle, punchangle);
	
	new Float:vector[3];
	xs_vec_add(v_angle, punchangle, vector);
	
	engfunc(EngFunc_MakeVectors, vector);
	
	new Float:vecSrc[3], Float:vecAiming[3];
	ExecuteHam(Ham_Player_GetGunPosition, player, vecSrc);
	global_get(glb_v_forward, vecAiming);
}

PlayEmptySound(ent)
{
	new player = get_ent_data(ent, "CBasePlayerItem", "m_pPlayer");
	emit_sound(player, CHAN_WEAPON, "weapons/dryfire_rifle.wav", 0.8, ATTN_NORM, 0, PITCH_NORM);
}

Float:GetNextAttackDelay(ent, Float:delay)
{
	if (get_ent_data_float(ent, "CBasePlayerWeapon", "m_flLastFireTime") == 0.0 
	|| get_ent_data_float(ent, "CBasePlayerWeapon", "m_flNextPrimaryAttack") == -1.0)
	{
		set_ent_data_float(ent, "CBasePlayerWeapon", "m_flPrevPrimaryAttack", delay);
		set_ent_data_float(ent, "CBasePlayerWeapon", "m_flLastFireTime", get_gametime());
	}
	
	new Float:timeBetweenFires = get_gametime() - get_ent_data_float(ent, "CBasePlayerWeapon", "m_flLastFireTime");
	new Float:creep = 0.0;
	
	if (timeBetweenFires > 0.0)
	{
		creep = timeBetweenFires - get_ent_data_float(ent, "CBasePlayerWeapon", "m_flPrevPrimaryAttack");
	}
	
	new Float:nextAttack = get_gametime() + delay - creep;
	
	set_ent_data_float(ent, "CBasePlayerWeapon", "m_flLastFireTime", get_gametime());
	set_ent_data_float(ent, "CBasePlayerWeapon", "m_flPrevPrimaryAttack", nextAttack - get_gametime());
	
	return nextAttack;
}

SetAnimation(player, anim)
{
	static func;
	func || (func = OrpheuGetFunction("CBasePlayer", "SetAnimation"));
	
	OrpheuCall(func, player, anim)
}

FireBullets3(ent, Float:vecSrc[3], Float:vecDirShooting[3], Float:spread, Float:distance, penetration, bulletType, damage, Float:rangeModifier, attacker, bool:isPistol, shared_rand)
{
	new originalPenetration = penetration;
	new penetrationPower;
	new Float:penetrationDistance;
	new currentDamage = damage;
	new Float:currentDistance;
	
	new tr, tr2;
	new Float:vecRight[3], Float:vecUp[3];
	
	new bool:hitMetal = false;
	new sparksAmount = 1;
	
	global_get(glb_v_right, vecRight);
	global_get(glb_v_up, vecUp);
	
	switch (bulletType)
	{
		case BULLET_MONSTER_9MM:
		{
			penetrationPower = 21;
			penetrationDistance = 800;
		}
		case BULLET_PLAYER_45ACP:
		{
			penetrationPower = 15;
			penetrationDistance = 500;
		}
		case BULLET_PLAYER_50AE:
		{
			penetrationPower = 30;
			penetrationDistance = 1000;
		}
		case BULLET_PLAYER_762MM:
		{
			penetrationPower = 39;
			penetrationDistance = 5000;
		}
		case BULLET_PLAYER_556MM:
		{
			penetrationPower = 35;
			penetrationDistance = 4000;
		}
		case BULLET_PLAYER_338MAG:
		{
			penetrationPower = 45;
			penetrationDistance = 8000;
		}
		case BULLET_PLAYER_57MM:
		{
			penetrationPower = 30;
			penetrationDistance = 2000;
		}
		case BULLET_PLAYER_357SIG:
		{
			penetrationPower = 25;
			penetrationDistance = 800;
		}
		default:
		{
			penetrationPower = 0;
			penetrationDistance = 0;
		}
	}
	
	if (!attacker)
	{
		attacker = ent;
	}
	
	new Float:x, Float:y, Float:z;
	do
	{
		x = random_float(-0.5, 0.5) + random_float(-0.5, 0.5);
		y = random_float(-0.5, 0.5) + random_float(-0.5, 0.5);
		z = x * x + y * y;
	}
	while (z > 1.0);
	
	new Float:vecDir[3], Float:vecEnd[3];
	new Float:vecOldSrc[3], Float:vecNewSrc[3];
	
	new Float:vector[3];
	xs_vec_mul_scalar(vecRight, x * spread, vector);
	xs_vec_add(vecDirShooting, vector, vecDirShooting);
	
	xs_vec_mul_scalar(vecUp, y * spread, vector);
	xs_vec_add(vecDirShooting, vector, vecDirShooting);
	
	xs_vec_mul_scalar(vecDir, distance, vector);
	xs_vec_add(vecSrc, vecDir, vecEnd);
	
	while (penetration != 0)
	{
		engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, ent, tr);
		
		
	}
}

SendWeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim);
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, NULL, id);
	write_byte(anim);
	write_byte(pev(id, pev_body));
	message_end();
}