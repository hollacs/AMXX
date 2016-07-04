#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

stock const m_pPlayer = 41;
stock const m_flNextPrimaryAttack = 46;
stock const m_flNextSecondaryAttack = 47;

enum
{
	KNIFE_IDLE,
	KNIFE_ATTACK1HIT,
	KNIFE_ATTACK2HIT,
	KNIFE_DRAW,
	KNIFE_STABHIT,
	KNIFE_STABMISS,
	KNIFE_MIDATTACK1HIT,
	KNIFE_MIDATTACK2HIT
};

new g_block;

public plugin_init()
{
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "OnKnifeStab");
}

public OnKnifeStab(ent)
{
	if (!g_block)
	{
		new player = get_pdata_cbase(ent, m_pPlayer);
		sendWeaponAnim(player, KNIFE_STABMISS);
		
		set_pdata_float(ent, m_flNextPrimaryAttack, 1.0);
		set_pdata_float(ent, m_flNextSecondaryAttack, 1.0);
		
		if (random_num(0, 1))
			emit_sound(player, CHAN_WEAPON, "weapons/knife_slash1.wav", VOL_NORM, ATTN_NORM, 0, 94);
		else
			emit_sound(player, CHAN_WEAPON, "weapons/knife_slash2.wav", VOL_NORM, ATTN_NORM, 0, 94);
		
		new param[2];
		param[0] = ent;
		
		set_task(0.5, "MakeAttack", player, param, sizeof(param));
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public MakeAttack(param[], id)
{
	new ent = param[0];
	client_print(0, print_chat, "%d", ent);
	
	if (pev_valid(ent))
	{
		g_block = true;
		ExecuteHamB(Ham_Weapon_SecondaryAttack, ent);
		g_block = false;
	}
}

stock sendWeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id);
	write_byte(anim);
	write_byte(pev(id, pev_body));
	message_end();
}