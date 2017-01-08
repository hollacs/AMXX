#include <amxmodx>
#include <fakemeta>
#include <regex>
#include <fvault>

#define VERSION "0.1"

#define VAULT_NAME "logmein"
#define TEMP_PLAYER_NAME "kI862Ghaqo8iAzmiq0Poe73lq"
#define SALT "201611280323TheLazyFoxJumpsOverTheQuickBrownDog"

#define MAX_PLAYERS 32
#define MAX_USERNAME_LENGTH 16
#define MAX_PASSWORD_LENGTH 32

enum
{
	USER_UNSIGNED = 0,
	USER_SIGNED_IN,
};

new bool:g_changingName[MAX_PLAYERS + 1];
new g_status[MAX_PLAYERS + 1] = {USER_UNSIGNED, ...};
new g_name[MAX_PLAYERS + 1][32];
new g_username[MAX_PLAYERS + 1][MAX_USERNAME_LENGTH];
new g_password[MAX_PLAYERS + 1][40];
new Float:g_timer[MAX_PLAYERS + 1] = {-999999.0, ...};
new Float:g_antiFlood[MAX_PLAYERS + 1] = {-999999.0, ...};
new Float:g_antiFloodName[MAX_PLAYERS + 1] = {-999999.0, ...};

public plugin_init()
{
	register_plugin("LogMeIn", VERSION, "penguinux");
	
	register_menucmd(register_menuid("LogMeIn Menu"), 1023, "HandleRegisterMenu");
	
	register_clcmd("amx_register", "CmdRegister", _, "Register");
	register_clcmd("amx_login", "CmdLogin", _, "Login");
	register_clcmd("logmein_change", "CmdChange", _, "Change password");
	register_clcmd("say /reg", "CmdSayRegister");
	
	register_message(get_user_msgid("SayText"), "MsgSayText");
	
	register_forward(FM_ClientUserInfoChanged, "OnClientUserInfoChanged");
}

public CmdRegister(id)
{
	if (get_gametime() < g_antiFlood[id] + 0.5)
	{
		client_print(id, print_console, "* Please don't send the command too quickly.");
		return PLUGIN_HANDLED;
	}
	
	g_antiFlood[id] = get_gametime();
	
	if (g_status[id] == USER_SIGNED_IN)
	{
		client_print(id, print_console, "[LogMeIn] You have already logged in.");
		return PLUGIN_HANDLED;
	}
	
	if (get_gametime() >= g_timer[id] + 30.0)
	{
		new arg1[MAX_USERNAME_LENGTH], arg2[MAX_PASSWORD_LENGTH];
		read_argv(1, arg1, charsmax(arg1));
		read_argv(2, arg2, charsmax(arg2));
		
		if (!arg1[0] || !arg2[0] || read_argc() > 3)
		{
			client_print(id, print_console, "[LogMeIn] Please follow this format: amx_register ^"username^" ^"password^"");
			return PLUGIN_HANDLED;
		}
		
		if (!isUsernameValid(arg1))
		{
			client_print(id, print_console, "[LogMeIn] A username must have 3 to %d characters and it can only contain alphanumeric characters (A-Z 0-9 _) with no spaces.", MAX_USERNAME_LENGTH);
			return PLUGIN_HANDLED;
		}	
		
		if (!isPasswordValid(arg2))
		{
			client_print(id, print_console, "[LogMeIn] A password must have at least 8 characters and a mix of letters and numbers with no spaces.");
			return PLUGIN_HANDLED;
		}
		
		if (isUsernameExists(arg1))
		{
			client_print(id, print_console, "[LogMeIn] Your username already exists.");
			return PLUGIN_HANDLED;
		}
		
		new name[32];
		get_user_name(id, name, charsmax(name));
		
		if (isNameExists(name))
		{
			client_print(id, print_console, "[LogMeIn] Your player name has already been taken, please rename and retry.");
			return PLUGIN_HANDLED;
		}
		
		new fakePassword[MAX_PASSWORD_LENGTH];
		new len = strlen(arg2);
		for (new i = 0; i < len; i++)
		{
			fakePassword[i] = '*';
		}
		
		client_print(id, print_console, "[LogMeIn] Your registeration infomations:");
		client_print(id, print_console, " - Name: %s", name);
		client_print(id, print_console, " - Username: %s", arg1);
		client_print(id, print_console, " - Password: %s", fakePassword);
		client_print(id, print_console, "* All passwords are encrypted with SHA1 *");
		client_print(id, print_console, "[LogMeIn] Please enter again (amx_register ^"your_password^") to confirm, you have 30 seconds to confirm.");
		
		g_name[id] = name;
		g_username[id] = arg1;
		g_timer[id] = get_gametime();
		
		passwordHash(arg2, SALT, g_password[id], charsmax(g_password[]));
	}
	else
	{
		new arg[MAX_PASSWORD_LENGTH];
		read_argv(1, arg, charsmax(arg));
		
		if (!arg[0] || read_argc() > 2)
		{
			client_print(id, print_console, "[LogMeIn] Please enter again (amx_register ^"your_password^") to confirm, you have %.f seconds to confirm.", g_timer[id] + 30.0 - get_gametime());
			return PLUGIN_HANDLED;
		}
		
		if (!passwordVerify(arg, g_password[id], SALT))
		{
			client_print(id, print_console, "[LogMeIn] Incorrect password.");
			return PLUGIN_HANDLED;
		}
		
		if (isUsernameExists(g_username[id]))
		{
			g_timer[id] = -999999.0;
			client_print(id, print_console, "[LogMeIn] Your username already exists.");
			return PLUGIN_HANDLED;
		}
		
		if (isNameExists(g_name[id]))
		{
			g_timer[id] = -999999.0;
			client_print(id, print_console, "[LogMeIn] Your player name has already been taken, please rename and retry.");
			return PLUGIN_HANDLED;
		}
		
		saveUser(id);
		changeName(id);
		
		g_timer[id] = -999999.0;
		g_status[id] = USER_SIGNED_IN;
		
		client_print(id, print_console, "[LogMeIn] You have successfully registered and logged in.");
	}
	
	return PLUGIN_HANDLED;
}

public CmdLogin(id)
{
	if (get_gametime() < g_antiFlood[id] + 0.5)
	{
		client_print(id, print_console, "* Please don't send the command too quickly.");
		return PLUGIN_HANDLED;
	}
	
	g_antiFlood[id] = get_gametime();
	
	if (g_status[id] == USER_SIGNED_IN)
	{
		client_print(id, print_console, "[LogMeIn] You have already logged in.");
		return PLUGIN_HANDLED;
	}
	
	new arg1[MAX_USERNAME_LENGTH], arg2[MAX_PASSWORD_LENGTH];
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	
	if (!arg1[0] || !arg2[0] || read_argc() > 3)
	{
		client_print(id, print_console, "[LogMeIn] Please follow this format: amx_login ^"username^" ^"password^"");
		return PLUGIN_HANDLED;
	}
	
	new data[256];
	if (!fvault_get_data(VAULT_NAME, arg1, data, charsmax(data)))
	{
		client_print(id, print_console, "[LogMeIn] Username doesn't exists.");
		return PLUGIN_HANDLED;
	}
	
	replace_string(data, charsmax(data), "%", "^"");
	
	new name[32], hash[40];
	parse(data, name, charsmax(name), hash, charsmax(hash));
	
	if (!passwordVerify(arg2, hash, SALT))
	{
		client_print(id, print_console, "[LogMeIn] Incorrect password.");
		return PLUGIN_HANDLED;
	}
	
	g_name[id] = name;
	g_username[id] = arg1;
	g_password[id] = hash;
	
	changeName(id);
	
	g_status[id] = USER_SIGNED_IN;
	
	client_print(id, print_console, "[LogMeIn] You have successfully logged in.");
	return PLUGIN_HANDLED;
}

public CmdChange(id)
{
	if (g_status[id] == USER_UNSIGNED)
	{
		client_print(id, print_console, "[LogMeIn] You must logged in to change password.");
		return PLUGIN_HANDLED;
	}
	
	new arg1[MAX_PASSWORD_LENGTH], arg2[MAX_PASSWORD_LENGTH], arg3[MAX_PASSWORD_LENGTH];
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	read_argv(3, arg3, charsmax(arg3));
	
	if (!arg1[0] || !arg2[0] || !arg3[0] || read_argc() > 4)
	{
		client_print(id, print_console, "[LogMeIn] Please follow this format: logmein_change ^"old_password^" ^"new_password^" ^"new_password^"");
		return PLUGIN_HANDLED;
	}
	
	if (!passwordVerify(arg1, g_password[id], SALT))
	{
		client_print(id, print_console, "[LogMeIn] Your old password is incorrect.");
		return PLUGIN_HANDLED;
	}
	
	if (!isPasswordValid(arg2))
	{
		client_print(id, print_console, "[LogMeIn] A password must have at least 8 characters and a mix of letters and numbers with no spaces.");
		return PLUGIN_HANDLED;
	}	
	
	if (!equal(arg2, arg3))
	{
		client_print(id, print_console, "[LogMeIn] Your new password doesn't match the confirmation password.");
		return PLUGIN_HANDLED;
	}
	
	new hash[40];
	passwordHash(arg2, SALT, hash, charsmax(hash));
	
	if (equal(hash, g_password[id]))
	{
		client_print(id, print_console, "[LogMeIn] Please enter a different password.");
		return PLUGIN_HANDLED;
	}
	
	g_password[id] = hash;
	updateUser(id);
	
	client_print(id, print_console, "[LogMeIn] Your password has been updated.");
	return PLUGIN_HANDLED;
}

public CmdSayRegister(id)
{
	new menu[512], len = 0;
	
	len = formatex(menu, charsmax(menu), "\yLogMeIn Menu^n^n");
	
	len += formatex(menu[len], 511-len, "\y1. \wRegister^n");
	len += formatex(menu[len], 511-len, "\y2. \wLogin^n");
	len += formatex(menu[len], 511-len, "\y3. \wChange password^n");
	
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "LogMeIn Menu");
	return PLUGIN_HANDLED;
}

public HandleRegisterMenu(id, key)
{
	switch (key)
	{
		case 0:
		{
			show_motd(id, "logmein/register.txt", "如何註冊?");
		}
		case 1:
		{
			show_motd(id, "logmein/login.txt", "如何登入?");
		}
		case 2:
		{
			show_motd(id, "logmein/change_password.txt", "如何更改密碼?");
		}
	}
}

public client_disconnected(id)
{
	g_changingName[id] = false;
	g_status[id] = USER_UNSIGNED;
	
	g_name[id][0] = 0;
	g_username[id][0] = 0;
	g_password[id][0] = 0;
	
	g_timer[id] = -999999.0;
	g_antiFlood[id] = -999999.0;
	g_antiFloodName[id] = -999999.0;
}

public MsgSayText(msgId, msgDest, id)
{
	new info[32];
	get_msg_arg_string(2, info, charsmax(info));
	
	if (equal(info, "#Cstrike_Name_Change"))
	{
		get_msg_arg_string(3, info, charsmax(info));
		if (equal(info, TEMP_PLAYER_NAME, strlen(TEMP_PLAYER_NAME)))
			return PLUGIN_HANDLED;
			
		get_msg_arg_string(4, info, charsmax(info));
		if (equal(info, TEMP_PLAYER_NAME, strlen(TEMP_PLAYER_NAME)))
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public OnClientUserInfoChanged(id)
{	
	new oldName[32];
	pev(id, pev_netname, oldName, charsmax(oldName));
	
	if (oldName[0])
	{
		new newName[32];
		get_user_info(id, "name", newName, charsmax(newName));
		
		if (!equal(oldName, newName))
		{	
			if (g_changingName[id])
			{
				g_changingName[id] = false;
				return FMRES_IGNORED;
			}
			
			if (get_gametime() < g_antiFloodName[id] + 10.0)
			{
				client_print(id, print_chat, "* Please don't change name too quickly.");
				set_user_info(id, "name", oldName);
				return FMRES_HANDLED;
			}
			
			if (g_status[id] == USER_SIGNED_IN)
			{
				if (isNameExists(newName))
				{
					client_print(id, print_chat, "* This name has already been taken.");
					set_user_info(id, "name", oldName);
					return FMRES_HANDLED;
				}
				
				g_name[id] = newName;
				updateUser(id);
			}
			
			g_antiFloodName[id] = get_gametime();
		}
	}
	
	return FMRES_IGNORED;
}

stock saveUser(id)
{
	new address[16];
	get_user_ip(id, address, charsmax(address), 1);
	
	new dateTime[32];
	get_time("%Y/%m/%d %H:%M:%S", dateTime, charsmax(dateTime));
	
	new data[256];
	formatex(data, charsmax(data), "%%%s%% %s %s %%%s%%", g_name[id], g_password[id], address, dateTime);
	
	fvault_set_data(VAULT_NAME, g_username[id], data);
}

stock updateUser(id)
{
	new data[256];
	fvault_get_data(VAULT_NAME, g_username[id], data, charsmax(data));
	replace_string(data, charsmax(data), "%", "^"");
	
	new left[2];
	argbreak(data, left, charsmax(left), data, charsmax(data));
	argbreak(data, left, charsmax(left), data, charsmax(data));
	
	new string[256];
	formatex(string, charsmax(string), "^"%s^" %s ", g_name[id], g_password[id]);
	add(string, charsmax(string), data);
	
	replace_string(string, charsmax(string), "^"", "%");
	
	fvault_set_data(VAULT_NAME, g_username[id], string);
}

stock changeName(id)
{
	new player = get_user_index(g_name[id]);
	if (player && player != id)
	{
		g_changingName[id] = true;
		g_changingName[player] = true;
		
		set_user_info(player, "name", TEMP_PLAYER_NAME);
		set_user_info(id, "name", g_name[id]);
		set_user_info(player, "name", g_name[id]);
		
		client_print(id, print_chat, "why?");
	}
	else if (!player)
	{
		g_changingName[id] = true;
		set_user_info(id, "name", g_name[id]);
	}
}

stock passwordHash(const password[], const salt[], output[], len)
{
	new string[64];
	copy(string, charsmax(string), password);
	add(string, charsmax(string), salt);
	
	hash_string(string, Hash_Sha1, output, len);
}

stock bool:passwordVerify(const password[], const hash[], const salt[])
{
	new hash2[40];
	passwordHash(password, salt, hash2, charsmax(hash2));
	
	if (equal(hash, hash2))
		return true;
	
	return false;
}

stock bool:isUsernameValid(const username[])
{
	new ret, error[64];
	new Regex:regex = regex_match(username, "^^[a-zA-Z0-9_]{3,}$", ret, error, charsmax(error));
	if (regex > REGEX_NO_MATCH)
		return true;
	
	return false;
}

stock bool:isPasswordValid(const password[])
{
	new ret, error[64];
	new Regex:regex = regex_match(password, "^^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$", ret, error, charsmax(error));
	if (regex > REGEX_NO_MATCH)
		return true;
	
	return false;
}

stock bool:isUsernameExists(const username[])
{
	new data[2];
	if (fvault_get_data(VAULT_NAME, username, data, charsmax(data)))
		return true;
	
	return false;
}

stock bool:isNameExists(const name[])
{
	new bool:ret = false;
	new Array:datas = ArrayCreate(256);

	new name2[32], data[256];
	new size = fvault_load(VAULT_NAME, _, datas);

	for(new i = 0; i < size; i++)
	{
		ArrayGetString(datas, i, data, charsmax(data));
		
		replace_string(data, charsmax(data), "%", "^"");
		argbreak(data, name2, charsmax(name2), data, charsmax(data));
		
		if (equal(name, name2))
		{
			ret = true;
			break;
		}
	}
	
	ArrayDestroy(datas);
	return ret;
}