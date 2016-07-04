
#include <amxmodx>
#include <orpheu>

new g_pGameRules

public plugin_precache()
{    
	OrpheuRegisterHook(OrpheuGetFunction("InstallGameRules"),"OnInstallGameRules",OrpheuHookPost)
}
public OnInstallGameRules()
{
	g_pGameRules = OrpheuGetReturn() 
}
