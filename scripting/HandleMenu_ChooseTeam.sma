#include <amxmodx>
#include <orpheu>

public plugin_init()
{
	OrpheuRegisterHook(OrpheuGetFunction("HandleMenu_ChooseTeam"), "HandleMenu_ChooseTeam_Post", OrpheuHookPost);
}

public HandleMenu_ChooseTeam_Post(id, slot)
{
	server_print("HandleMenu_ChooseTeam(%d, %d) -> return %d;", id, slot, OrpheuGetReturn());
	client_print(0, print_chat, "HandleMenu_ChooseTeam(%d, %d) -> return %d;", id, slot, OrpheuGetReturn());
}