#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

new Trie:g_classnames;

public plugin_precache()
{
	g_classnames = TrieCreate();
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "OnTraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "player", "OnTraceAttack_Post", 1);
	
	TrieSetCell(g_classnames, "worldspawn", 1);
	TrieSetCell(g_classnames, "player", 1);
	
	register_forward(FM_Spawn, "OnSpawn_Post", 1);
}

public OnSpawn_Post(ent)
{
	if (pev_valid(ent))
	{
		new classname[32];
		pev(ent, pev_classname, classname, charsmax(classname));
		
		if (!TrieKeyExists(g_classnames, classname))
		{
			RegisterHam(Ham_TraceAttack, classname, "OnTraceAttack_Post", 1);
			TrieSetCell(g_classnames, classname, 1);
		}
	}
}

public plugin_init()
{
	register_plugin("Weapon Dynamic Light", "0.1", "Colgate");
}

public OnTraceAttack_Post(ent, attacker, Float:damage, Float:direction[3], tr, damageType)
{
	if (get_user_weapon(attacker) == CSW_KNIFE)
		return;
	
	new Float:origin[3], Float:angles[3];
	engfunc(EngFunc_GetAttachment, attacker, 1, origin, angles);
	
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_DLIGHT);
	write_coord_f(origin[0]); // x
	write_coord_f(origin[1]); // y
	write_coord_f(origin[2]); // z
	write_byte(random_num(10, 25)); // radius
	write_byte(random_num(200, 255)); // r
	write_byte(random_num(150, 220)); // g
	write_byte(random_num(0, 50)); // b
	write_byte(10); // life
	write_byte(random_num(70, 100)); // decay rate
	message_end();
}