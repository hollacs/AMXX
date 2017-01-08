#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <engine>

const WEAPONS = (1 << CSW_AK47)|(1 << CSW_M4A1)|(1 << CSW_SG552)|(1 << CSW_AUG)|(1 << CSW_G3SG1)|(1 << CSW_SG550)|(1 << CSW_DEAGLE)|(1 << CSW_M249)|(1 << CSW_AWP);

new g_fwSpawn;

public plugin_precache()
{
	g_fwSpawn = register_forward(FM_Spawn, "OnSpawn");
}

public plugin_init()
{
	register_plugin("Armoury Entity", "0.1", "penguinux");
	
	unregister_forward(FM_Spawn, g_fwSpawn);
}

public OnSpawn(ent)
{
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));
	
	if (equal(classname, "armoury_entity"))
	{
		if ((1 << cs_get_armoury_type(ent)) & WEAPONS)
		{
			remove_entity(ent);
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}