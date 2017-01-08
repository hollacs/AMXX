#include <amxmodx>
#include <logmein>

public Logmein_Login(id)
{
	new username[32];
	logmein_GetUsername(id, username, charsmax(username));
	
	client_print(id, print_chat, "Why login? You %s", username);
}

public Logmein_Logout(id)
{
	client_print(id, print_chat, "hehe you log out do what 7?");
}