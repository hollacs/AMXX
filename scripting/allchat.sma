#include <amxmodx>

#define VERSION "0.1"

new g_isFirstSay;
new g_msgSayText;

public plugin_init()
{
	register_plugin("All Chat", VERSION, "penguinux");
	
	register_clcmd("say", "CmdSay");
	register_clcmd("say_team", "CmdSay");
	
	g_msgSayText = get_user_msgid("SayText");
	register_message(g_msgSayText, "MsgSayText");
}

public CmdSay(id)
{
	g_isFirstSay = true;
}

public MsgSayText(msgId, msgDest, id)
{	
	new string1[32];
	get_msg_arg_string(2, string1, charsmax(string1));
	
	if (equal(string1, "#Cstrike_Chat", 13))
	{
		if (g_isFirstSay)
		{
			new sender = get_msg_arg_int(1);
			
			new bool:isTeamMsg = bool:!equal(string1, "#Cstrike_Chat_All", 17);
			new senderTeam = get_user_team(sender);
			new bool:isSenderSpec = bool:!(1 <= senderTeam <= 2);
			
			if (!(isSenderSpec && isTeamMsg))
			{
				new string2[128], string3[192];
				get_msg_arg_string(3, string2, charsmax(string2));
				get_msg_arg_string(4, string3, charsmax(string3));
				
				new flags[5], teamName[10];
				if (is_user_alive(sender))
					flags = "bc";
				else
					flags = "ac";
				
				if (isTeamMsg)
				{
					add(flags, charsmax(flags), "e");
					
					if (senderTeam == 1)
						teamName = "TERRORIST";
					else if (senderTeam == 2)
						teamName = "CT";
				}
				
				new players[32], num;
				get_players(players, num, flags, teamName);
				
				for (new i = 0; i < num; i++)
				{
					message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, players[i]);
					write_byte(sender);
					write_string(string1);
					write_string(string2);
					write_string(string3);
					message_end();
				}
			}
			
			g_isFirstSay = false;
		}
	}
}