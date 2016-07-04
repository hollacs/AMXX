#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#define VERSION "0.0.4"

#define CSW_FAKE_SHIELD 2

// CWeaponBox pdata
const XO_CWEAPONBOX = 4;
new const m_rgpPlayerItems_CWeaponBox[4] = {35, 36, 38, 39};

// CBasePlayerItem pdata
const XO_CBASEPLAYERITEM = 4;
const m_iId = 43;

new g_WeaponBoxBits;
new Float:g_WeaponBoxLife[CSW_P90+1];

new HamHook:g_HookShield, HamHook:g_HookWeapon;

new bool:g_IsGameCzero;

public plugin_init()
{
	register_plugin("WeaponBox Life", VERSION, "11922911");
	
	register_concmd("weaponbox_life", "ConCmd_SetLife", ADMIN_CFG, "<weapon short name> <remove time>");
	
	DisableHamForward(g_HookShield = RegisterHam(Ham_Touch, "weapon_shield", "OnShieldTouch"));
	DisableHamForward(g_HookWeapon = RegisterHam(Ham_Touch, "weaponbox", 	 "OnWeaponTouch"));
	
	checkMod();
}

public ConCmd_SetLife(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new arg[17] = "weapon_";
	read_argv(1, arg[7], charsmax(arg) - 7);
	
	if (arg[7] == '*' && !arg[8]) // All weapons
	{
		read_argv(2, arg, charsmax(arg));
		
		new Float:value = str_to_float(arg);
		
		for (new i = CSW_P228; i < CSW_P90; i++)
		{
			g_WeaponBoxLife[i] = value;
			g_WeaponBoxBits |= (1 << i);
		}
		
		if (value >= 0.0)
		{
			g_WeaponBoxBits &= ~(1 << CSW_KNIFE);
			EnableHamForward(g_HookShield);
			EnableHamForward(g_HookWeapon);
		}
		else
		{
			g_WeaponBoxBits = 0;
			DisableHamForward(g_HookShield);
			DisableHamForward(g_HookWeapon);
		}
	}
	else
	{
		new weaponId = CSW_FAKE_SHIELD, HamHook:hook = g_HookShield;
		
		if (!equal(arg[7], "shield"))
		{
			weaponId = get_weaponid(arg);
			
			if (!weaponId || weaponId == CSW_KNIFE)
				return PLUGIN_HANDLED;
			
			if (!g_IsGameCzero && (weaponId == CSW_HEGRENADE || weaponId == CSW_FLASHBANG || weaponId == CSW_SMOKEGRENADE))
				return PLUGIN_HANDLED;
			
			hook = g_HookWeapon;
		}
		
		read_argv(2, arg, charsmax(arg));
		g_WeaponBoxLife[weaponId] = str_to_float(arg);
		
		if (g_WeaponBoxLife[weaponId] >= 0.0)
		{
			g_WeaponBoxBits |= (1 << weaponId);
			EnableHamForward(hook);
		}
		else
		{
			g_WeaponBoxBits &= ~(1 << weaponId);
			if (weaponId == CSW_FAKE_SHIELD || !g_WeaponBoxBits || g_WeaponBoxBits == (1 << CSW_FAKE_SHIELD))
				DisableHamForward(hook);
		}
	}
	
	return PLUGIN_HANDLED;
}

public OnWeaponTouch(weaponBox)
{
	if (!pev_valid(weaponBox))
		return;
	
	new weaponId = getWeaponBoxType(weaponBox);
	if (weaponId && (g_WeaponBoxBits & (1 << weaponId)) && pev(weaponBox, pev_bInDuck) != 1)
	{
		set_pev(weaponBox, pev_bInDuck, 1);
		set_pev(weaponBox, pev_nextthink, get_gametime() + g_WeaponBoxLife[weaponId]);
	}
}

public OnShieldTouch( weaponBox )
{
	if (!pev_valid(weaponBox))
		return;
	
	if (pev(weaponBox, pev_bInDuck) != 1)
	{
		set_pev(weaponBox, pev_bInDuck, 1);
		set_pev(weaponBox, pev_nextthink, get_gametime() + g_WeaponBoxLife[CSW_FAKE_SHIELD]);
	}
}

checkMod()
{
	new modName[10]
	get_modname(modName, charsmax(modName));
	
	g_IsGameCzero = bool:equal(modName, "czero");
}

stock getWeaponBoxType(weaponBox)
{	
	new weapon;
	
	for (new i = 0; i < 4; i++)
	{
		weapon = get_pdata_cbase(weaponBox, m_rgpPlayerItems_CWeaponBox[i], XO_CWEAPONBOX);
		
		if(weapon > 0)
			return get_pdata_int(weapon, m_iId, XO_CBASEPLAYERITEM);
	}
	
	return 0;
}