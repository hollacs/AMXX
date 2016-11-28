#include <amxmodx>
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

new g_status[MAX_PLAYERS + 1] = {USER_UNSIGNED, ...};
new g_name[MAX_PLAYERS + 1][32];
new g_username[MAX_PLAYERS + 1][MAX_USERNAME_LENGTH];
new g_password[MAX_PLAYERS + 1][40];
new Float:g_timer[33] = {-999999.0, ...};
new Float:g_antiFlood[33] = {-999999.0, ...};

public plugin_init()
{
	register_plugin("LogMeIn", VERSION, "penguinux");
	
	register_clcmd("amx_register", "CmdRegister", _, "Register");
	register_clcmd("amx_login", "CmdLogin", _, "Login");
	
	register_message(get_user_msgid("SayText"), "MsgSayText");
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
		client_print(id, print_console, "[LogMeIn] Please enter again (amx_register ^"your_password^") to confirm, you have 30 seconds to confirm.");
		client_print(id, print_console, "* All passwords are encrypted with SHA1 *");
		
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
		
		g_timer[id] = -999999.0;
		g_status[id] = USER_SIGNED_IN;
		
		saveUser(id);
		changeName(id);
		
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
	
	new data[128];
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
	
	g_status[id] = USER_SIGNED_IN;
	
	g_name[id] = name;
	g_username[id] = arg1;
	g_password[id] = hash;
	
	changeName(id);
	
	client_print(id, print_console, "[LogMeIn] You have successfully logged in.");
	return PLUGIN_HANDLED;
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

stock saveUser(id)
{
	new address[16];
	get_user_ip(id, address, charsmax(address), 1);
	
	new dateTime[32];
	get_time("%Y/%m/%d %H:%M:%S", dateTime, charsmax(dateTime));
	
	new data[128];
	formatex(data, charsmax(data), "%%%s%% %s %s %%%s%%", g_name[id], g_password[id], address, dateTime);
	
	fvault_set_data(VAULT_NAME, g_username[id], data);
}

stock changeName(id)
{
	new player = get_user_index(g_name[id]);
	if (player && player != id)
	{
		set_user_info(player, "name", TEMP_PLAYER_NAME);
		set_user_info(id, "name", g_name[id]);
		set_user_info(player, "name", g_name[id]);
		
		client_print(id, print_chat, "why?");
	}
	else if (!player)
	{
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
	new Array:datas = ArrayCreate(128);

	new name2[32], data[128];
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