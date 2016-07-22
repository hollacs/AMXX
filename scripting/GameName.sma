#include <amxmodx>
#include <fakemeta>

#define VERSION "0.1"

new cvarGameName;

public plugin_init()
{ 
	register_plugin("Game Name", VERSION, "penguinux");
	
	register_forward(FM_GetGameDescription, "OnGetGameDescription");
	
	cvarGameName = register_cvar("amx_gamename", "Counter-Strike");
}
 
public OnGetGameDescription()
{
	new name[32]; 
	get_pcvar_string(cvarGameName, name, charsmax(name));
	
	forward_return(FMV_STRING, name); 
	return FMRES_SUPERCEDE; 
}