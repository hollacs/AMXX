#include <amxmodx>
#include <fakemeta>

public plugin_init()
{
	register_plugin("Movetype Step", "0.1", "Colgate");
	
	register_forward(FM_AddToFullPack, "OnAddToFullPack_Post", 1);
}

public OnAddToFullPack_Post(es, e, ent, host, flags, player, pset)
{
	if (!player && get_es(es, ES_MoveType) == MOVETYPE_STEP)
	{
		set_es(es, ES_MoveType, MOVETYPE_PUSHSTEP);
	}
}