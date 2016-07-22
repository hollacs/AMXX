#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#include <zombiemode>

#define VERSION "0.1"

#define WEAPON_CLASS "weapon_deagle"
#define WEAPON_EVENT "events/deagle.sc"
#define WEAPON_ID CSW_DEAGLE
#define WEAPON_MAXCLIP 6
#define WEAPON_DEFAULT_GIVE 0
#define WEAPON_MAXSPEED 240.0
#define WEAPON_MAXSPEED_ZOOM 220.0
#define WEAPON_DAMAGE 100.0

#define WEAPON_ATTACK_TIME 0.3
#define WEAPON_ATTACK_ANIM_TIME 2.0 
#define WEAPON_ATTACK_TIME_ZOOM 0.15
#define WEAPON_RELOAD_DELAY 3.0

#define REMOVE_SECONDARY_ATTACK

#define DEFAULT_FOV 90

// Animations

// See all animations from HLMV
enum
{
	ANIM_IDLE,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT_EMPTY,
	ANIM_RELOAD,
	ANIM_DRAW
};

// Set animation id
const WEAPON_ANIM_IDLE = ANIM_IDLE;
const WEAPON_ANIM_DRAW = ANIM_DRAW;
const WEAPON_ANIM_RELOAD = ANIM_RELOAD;
new const WEAPON_ANIM_SHOOT[] = {ANIM_SHOOT1, ANIM_SHOOT2}

// Models
new const MODEL_W[] = "models/fai_zombie/weapons/w_rosesnake.mdl";
new const MODEL_V[] = "models/fai_zombie/weapons/v_rosesnake.mdl";
new const MODEL_P[] = "models/fai_zombie/weapons/p_rosesnake.mdl";

// Sound
new const SOUND_FIRE[][] = {"weapons/rosesnake-1.wav", "weapons/rosesnake-2.wav"};

// Variables
new g_eventId;
new g_clip;
new Float:g_prevPrimaryAttack;
new Float:g_lastFireTime;
new Float:g_punchAngle[3];

new Trie:g_classNames;
new g_fnPrecacheEvent;

// Functions
public plugin_precache()
{
	precache_model(MODEL_W);
	precache_model(MODEL_V);
	precache_model(MODEL_P);
	
	//precache_sound("weapons/zoom.wav");
	
	for (new i = 0; i < sizeof SOUND_FIRE; i++)
		precache_sound(SOUND_FIRE[i]);
	
	// Precache other sound here
	precache_sound("weapons/rosesnake_clipout.wav");
	precache_sound("weapons/rosesnake_deploy.wav");
	
	g_classNames = TrieCreate();
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "OnTraceAttack");
	TrieSetCell(g_classNames, "worldspawn", 1);

	register_forward(FM_Spawn, "OnSpawn", 1);
	
	g_fnPrecacheEvent = register_forward(FM_PrecacheEvent, "OnPrecacheEvent_Post", 1);
}

public OnSpawn(ent)
{
	if (pev_valid(ent))
	{
		new className[32];
		pev(ent, pev_classname, className, charsmax(className));
		
		if (!TrieKeyExists(g_classNames, className))
		{
			RegisterHam(Ham_TraceAttack, className, "OnTraceAttack")
			TrieSetCell(g_classNames, className, 1)
		}
	}
}

public OnPrecacheEvent_Post(type, const name[])
{
	if (equal(name, WEAPON_EVENT))
	{
		g_eventId = get_orig_retval();
	}
}

public plugin_init()
{
	register_plugin("[ZB] Resesnake", VERSION, "Colgate");
	
	unregister_forward(FM_PrecacheEvent, g_fnPrecacheEvent, 1);
	register_forward(FM_SetModel, "OnSetModel_Post", 1);
	register_forward(FM_UpdateClientData, "OnUpdateClientData_Post", 1);
	register_forward(FM_PlaybackEvent, "OnPlaybackEvent");
	
	RegisterHam(Ham_Spawn, WEAPON_CLASS, "OnWeaponSpawn_Post", 1);
	RegisterHam(Ham_CS_Item_GetMaxSpeed, WEAPON_CLASS, "OnWeaponGetMaxSpeed");
	RegisterHam(Ham_Item_Deploy, WEAPON_CLASS, "OnWeaponDeploy_Post", 1);
	RegisterHam(Ham_Weapon_Reload, WEAPON_CLASS, "OnWeaponReload");
	RegisterHam(Ham_Weapon_Reload, WEAPON_CLASS, "OnWeaponReload_Post", 1);
	RegisterHam(Ham_Item_PostFrame, WEAPON_CLASS, "OnWeaponPostFrame");
	RegisterHam(Ham_Item_Holster, WEAPON_CLASS, "OnWeaponHolster");
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_CLASS, "OnWeaponPrimaryAttack");
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_CLASS, "OnWeaponPrimaryAttack_Post", 1);
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_CLASS, "OnWeaponSecondaryAttack");
}

public OnSetModel_Post(ent, const model[])
{
	new className[32];
	pev(ent, pev_classname, className, charsmax(className));
	
	if (equal(className, "weaponbox"))
	{
		new weapon = get_ent_data_entity(ent, "CWeaponBox", "m_rgpPlayerItems", 2);
		if (pev_valid(weapon))
		{
			new weaponId = get_ent_data(weapon, "CBasePlayerItem", "m_iId");
			if (weaponId == WEAPON_ID)
			{
				// Change model for weapon box
				entity_set_model(ent, MODEL_W);
			}
		}
	}
}

public OnUpdateClientData_Post(id, sendWeapons, cd)
{
	if (is_user_alive(id) && get_user_weapon(id) == WEAPON_ID)
	{
		new activeItem = get_ent_data_entity(id, "CBasePlayer", "m_pActiveItem");
		if (pev_valid(activeItem))
		{
			// Block client weapon fire sound
			set_cd(cd, CD_flNextAttack, get_gametime() + 0.001);
		}
	}
}

public OnPlaybackEvent(flags, invoker, eventId)
{
	if (is_user_connected(invoker) && eventId == g_eventId)
	{
		new activeItem = get_ent_data_entity(invoker, "CBasePlayer", "m_pActiveItem");
		
		// Block client weapon fire sound for other players
		if (pev_valid(activeItem))
			return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public OnTraceAttack(ent, attacker, Float:damage, Float:direction[3], tr, damageBits)
{
	if (is_user_connected(attacker) && get_user_weapon(attacker) == WEAPON_ID)
	{
		new activeItem = get_ent_data_entity(attacker, "CBasePlayer", "m_pActiveItem");
		if (pev_valid(activeItem))
		{
			// Remake gun shot effects
			new Float:endPos[3], Float:planeNormal[3];
			get_tr2(tr, TR_vecEndPos, endPos);
			get_tr2(tr, TR_vecPlaneNormal, planeNormal);
					
			message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY);
			write_byte(TE_GUNSHOTDECAL);
			write_coord_f(endPos[0]);
			write_coord_f(endPos[1]);
			write_coord_f(endPos[2]);
			write_short(ent);
			write_byte(random_num(41, 45));
			message_end();
			
			message_begin_f(MSG_PVS, SVC_TEMPENTITY, endPos);
			write_byte(TE_STREAK_SPLASH);
			write_coord_f(endPos[0]);
			write_coord_f(endPos[1]);
			write_coord_f(endPos[2]);
			write_coord_f(planeNormal[0]);
			write_coord_f(planeNormal[1]);
			write_coord_f(planeNormal[2]);
			write_byte(5);
			write_short(22);
			write_short(25);
			write_short(65);
			message_end();
			
			// Change weapon damage
			SetHamParamFloat(3, WEAPON_DAMAGE);
		}
	}
}

public OnWeaponSpawn_Post(ent)
{
	// Change default ammo give
	setWeaponData(ent, "m_iDefaultAmmo", WEAPON_DEFAULT_GIVE);
}

public OnWeaponGetMaxSpeed(ent)
{
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	// Change weapon max speed
	if (pev(player, pev_fov) == DEFAULT_FOV)
		SetHamReturnFloat(WEAPON_MAXSPEED);
	else
		SetHamReturnFloat(WEAPON_MAXSPEED_ZOOM);
	
	return HAM_OVERRIDE;
}

public OnWeaponDeploy_Post(ent)
{
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	// Change weapon model for player
	set_pev(player, pev_viewmodel2, MODEL_V);
	set_pev(player, pev_weaponmodel2, MODEL_P);
	
	// Change draw animation
	sendWeaponAnim(player, WEAPON_ANIM_DRAW);
}

public OnWeaponPrimaryAttack(ent)
{
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	g_clip = getWeaponData(ent, "m_iClip");
	g_prevPrimaryAttack = getWeaponDataF(ent, "m_flPrevPrimaryAttack");
	g_lastFireTime = getWeaponDataF(ent, "m_flLastFireTime");
	
	pev(player, pev_punchangle, g_punchAngle);
}

public OnWeaponPrimaryAttack_Post(ent)
{
	if (g_clip <= 0)
		return;
	
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	// Set back old values
	set_pev(player, pev_punchangle, g_punchAngle);
	
	setWeaponDataF(ent, "m_flPrevPrimaryAttack", g_prevPrimaryAttack);
	setWeaponDataF(ent, "m_flLastFireTime", g_lastFireTime);
	
	// Change weapon attack time
	new Float:delay = WEAPON_ATTACK_TIME;
	if (pev(player, pev_fov) != DEFAULT_FOV)
		delay = WEAPON_ATTACK_TIME_ZOOM;
	
	// Change weapon attack time
	delay = getNextAttackDelay(ent, delay);
	setWeaponDataF(ent, "m_flNextPrimaryAttack", delay);
	setWeaponDataF(ent, "m_flNextSecondaryAttack", delay);
	setWeaponDataF(ent, "m_flTimeWeaponIdle", get_gametime() + WEAPON_ATTACK_ANIM_TIME);
	
	// Change shoot animation
	sendWeaponAnim(player, WEAPON_ANIM_SHOOT[random(sizeof WEAPON_ANIM_SHOOT)]);
	
	// Play weapon fire sound
	emit_sound(ent, CHAN_WEAPON, SOUND_FIRE[random(sizeof SOUND_FIRE)], 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	// Change weapon recoil here
#if WEAPON_ID == CSW_AWP || WEAPON_ID == CSW_SCOUT
	new Float:punchAngle[3];
	pev(player, pev_punchangle, punchAngle);
	punchAngle[0] -= 2.0;
	
	set_pev(player, pev_punchangle, punchAngle);
	
#elseif WEAPON_ID == CSW_G3SG1 || WEAPON_ID == CSW_SG550
	new Float:punchAngle[3];
	pev(player, pev_punchangle, punchAngle);
	punchAngle[0] -= random_float(0.75, 1.25) + punchAngle[0] * 0.25;
	punchAngle[1] += random_float(-0.75, 0.75);
	
	set_pev(player, pev_punchangle, punchAngle);
	
#elseif WEAPON_ID == CSW_GLOCK18 || WEAPON_ID == CSW_USP || WEAPON_ID == CSW_P228 || WEAPON_ID == CSW_DEAGLE || WEAPON_ID == CSW_FIVESEVEN || WEAPON_ID == CSW_ELITE
	new Float:punchAngle[3];
	pev(player, pev_punchangle, punchAngle);
	punchAngle[0] -= 2.0
	
	set_pev(player, pev_punchangle, punchAngle);

#else
	new Float:velocity[3];
	pev(player, pev_velocity, velocity);
	velocity[2] = 0.0;
	
	if (xs_vec_len(velocity) > 0.0)
		kickBack(ent, 1.0, 0.45, 0.28, 0.045, 3.75, 3.0, 7);
	else if (~pev(player, pev_flags) & FL_ONGROUND)
		kickBack(ent, 1.2, 0.5, 0.23, 0.15, 5.5, 3.5, 6);
	else if (pev(player, pev_flags) & FL_DUCKING)
		kickBack(ent, 0.6, 0.3, 0.2, 0.0125, 3.25, 2.0, 7);
	else
		kickBack(ent, 0.60, 0.30, 0.24, 0.014, 3.6, 2.3, 7);
	
	//kickBack(ent, Float:upBase, Float:lateralBase, Float:upModifier, Float:lateralModifier, Float:upMax, Float:lateralMax, directionChange)
	
#endif
}

public OnWeaponSecondaryAttack(ent)
{
#if defined REMOVE_SECONDARY_ATTACK
	return HAM_SUPERCEDE;
#else
	return HAM_IGNORED;
#endif
}

public OnWeaponReload(ent)
{	
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	new ammoType = getWeaponData(ent, "m_iPrimaryAmmoType");
	new ammoAmount = getPlayerData(player, "m_rgAmmo", ammoType);
	new clip = getWeaponData(ent, "m_iClip");
	
	new j = min(WEAPON_MAXCLIP - clip, ammoAmount);
	if (j == 0)
		return HAM_SUPERCEDE;
	
	g_clip = clip;
	setWeaponData(ent, "m_iClip", 0);
	return HAM_IGNORED;
}

public OnWeaponReload_Post(ent)
{
	if (getWeaponData(ent, "m_fInReload"))
	{
		new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
		
		// Set back old clip
		setWeaponData(ent, "m_iClip", g_clip);
		
		// Change reload animation
		sendWeaponAnim(player, WEAPON_ANIM_RELOAD);
		
		// Change reload time
		set_ent_data_float(player, "CBaseMonster", "m_flNextAttack", WEAPON_RELOAD_DELAY);
		setWeaponDataF(ent, "m_flTimeWeaponIdle", WEAPON_RELOAD_DELAY + 0.5);
	}
}

public OnWeaponPostFrame(ent)
{
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	// Apply custom max clip
	if (getWeaponData(ent, "m_fInReload") && get_ent_data_float(player, "CBaseMonster", "m_flNextAttack") <= get_gametime())
	{
		new ammoType = getWeaponData(ent, "m_iPrimaryAmmoType");
		new ammoAmount = getPlayerData(player, "m_rgAmmo", ammoType);
		new clip = getWeaponData(ent, "m_iClip")
		
		new j = min(WEAPON_MAXCLIP - clip, ammoAmount);
		
		setWeaponData(ent, "m_iClip", clip + j);
		setPlayerData(player, "m_rgAmmo", ammoAmount - j, ammoType);
		setWeaponData(ent, "m_fInReload", false);
	}
}

public OnWeaponHolster(ent)
{
	if (ExecuteHamB(Ham_Item_CanHolster, ent))
	{
		new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
		
		setPlayerData(player, "m_iFOV", DEFAULT_FOV);
		set_pev(player, pev_fov, DEFAULT_FOV);
	}
}

stock giveWeapon(id)
{
	new ent = create_entity(WEAPON_CLASS);
	
	if (pev_valid(ent))
	{
		new Float:origin[3];
		pev(id, pev_origin, origin);
		
		set_pev(ent, pev_origin, origin);
		set_pev(ent, pev_spawnflags, pev(ent, pev_spawnflags) | SF_NORESPAWN);
		//set_pev(ent, pev_iuser4, WEAPON_CODE);
		
		DispatchSpawn(ent);
		fake_touch(ent, id);
	}
}

stock kickBack(ent, Float:upBase, Float:lateralBase, Float:upModifier, Float:lateralModifier, Float:upMax, Float:lateralMax, directionChange)
{
	new Float:kickUp;
	new Float:kickLateral;
	
	new shotsFired = getWeaponData(ent, "m_iShotsFired");
	if (shotsFired == 1)
	{
		kickUp = upBase;
		kickLateral = lateralBase;
	}
	else
	{
		kickUp = shotsFired * upModifier + upBase;
		kickLateral = shotsFired * lateralModifier + lateralBase;
	}
	
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	
	new Float:punchAngle[3];
	pev(player, pev_punchangle, punchAngle);
	
	punchAngle[0] -= kickUp;
	
	if (punchAngle[0] < -upMax)
	{
		punchAngle[0] = -upMax;
	}
	
	if (getWeaponData(ent, "m_iDirection"))
	{
		punchAngle[1] += kickLateral;
		
		if (punchAngle[1] > lateralMax)
			punchAngle[1] = lateralMax;
	}
	else
	{
		punchAngle[1] -= kickLateral;
		
		if (punchAngle[1] < -lateralMax)
			punchAngle[1] = -lateralMax;
	}
	
	if (!random_num(0, directionChange))
	{
		setWeaponData(ent, "m_iDirection", !getWeaponData(ent, "m_iDirection"));
	}
	
	set_pev(player, pev_punchangle, punchAngle);
}

stock sendWeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id);
	write_byte(anim);
	write_byte(pev(id, pev_body));
	message_end();
}

// From Arkshine's CSSDK. Don't know why REGAMEDLL's code doesn't work correctly.
stock Float:getNextAttackDelay(ent, Float:delay)
{
	if (getWeaponDataF(ent, "m_flLastFireTime") == 0.0 || getWeaponDataF(ent, "m_flNextPrimaryAttack") == -1.0)
	{
		setWeaponDataF(ent, "m_flLastFireTime", get_gametime());
		setWeaponDataF(ent, "m_flPrevPrimaryAttack", delay);
	}
	
	new Float:elapsedFireTime = get_gametime() - getWeaponDataF(ent, "m_flLastFireTime");
	new Float:timeOffset = 0.0;
	
	if (elapsedFireTime > 0.0)
	{
		timeOffset = elapsedFireTime - getWeaponDataF(ent, "m_flPrevPrimaryAttack");
	}
	
	new Float:nextDelay = delay - timeOffset;
	
	setWeaponDataF(ent, "m_flLastFireTime", get_gametime());
	setWeaponDataF(ent, "m_flPrevPrimaryAttack", nextDelay);
	
	return nextDelay;
}

stock getPlayerData(ent, const member[], element = 0)
{
	return get_ent_data(ent, "CBasePlayer", member, element);
}

stock setPlayerData(ent, const member[], value, element = 0)
{
	set_ent_data(ent, "CBasePlayer", member, value, element);
}

stock getPlayerDataEnt(player, const member[], element = 0)
{
	return get_ent_data_entity(player, "CBasePlayer", member, element);
}

stock setPlayerDataF(ent, const member[], Float:value, element = 0)
{
	set_ent_data_float(ent, "CBasePlayer", member, value, element);
}

stock getWeaponData(ent, const member[], element = 0)
{
	return get_ent_data(ent, "CBasePlayerWeapon", member, element);
}

stock setWeaponData(ent, const member[], value, element = 0)
{
	set_ent_data(ent, "CBasePlayerWeapon", member, value, element);
}

stock Float:getWeaponDataF(ent, const member[], element = 0)
{
	return get_ent_data_float(ent, "CBasePlayerWeapon", member, element);
}

stock setWeaponDataF(ent, const member[], Float:value, element = 0)
{
	set_ent_data_float(ent, "CBasePlayerWeapon", member, value, element);
}

stock getWeaponDataEnt(ent, const member[], element = 0)
{
	return get_ent_data_entity(ent, "CBasePlayerWeapon", member, element);
}

stock setWeaponDataEnt(ent, const member[], value, element = 0)
{
	set_ent_data_entity(ent, "CBasePlayerWeapon", member, value, element);
}

stock dropSlotItems(id, slot=0)
{
	for (new i = 1; i <= 5; i++)
	{
		if (slot && slot != i)
			continue;
		
		new weapon = getPlayerDataEnt(id, "m_rgpPlayerItems", i);
		
		while (pev_valid(weapon))
		{
			if (ExecuteHamB(Ham_CS_Item_CanDrop, weapon))
			{
				static class[32];
				pev(weapon, pev_classname, class, charsmax(class));
				
				engclient_cmd(id, "drop", class);
			}
			
			// Find next weapon
			weapon = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pNext");
		}
	}
}