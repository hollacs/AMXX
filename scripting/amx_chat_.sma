#include <amxmodx>

#define VERSION "0.1"

#define Cstrike_Chat_All "%s1 ^1:  %s2"

#define get_pcv_i(%0) get_pcvar_num(g_pCvars[%0])

#define MAX_TAGS 22
#define MAXCLIENT 32

new g_szNick[MAXCLIENT+1][32]
new g_szName[MAXCLIENT+1][32]

new Array:g_aAdminTags, Array:g_aAdminFlags
new g_iAdminNums

/* 1,32,2,3,32,3,32 = 105 */
new g_szFormatted[105]
new bool:g_bFormatted
new bool:g_bFirstSay

new g_Msg_SayText

enum pCvars
{
	cvar_nick,
	cvar_minlen,
	cvar_maxlen
}
new g_pCvars[pCvars]

enum Colors
{
	print_default,
	print_team,
	print_green
}

public plugin_init( )
{
	register_plugin( "AMX Simple Chat", VERSION, "HKGSE" )
	
	register_srvcmd( "amx_chat_addtag", "ServerCommand_SetTag" )
	
	register_clcmd( "say", "ClientCommand_Say" )
	register_clcmd( "say_team", "ClientCommand_Say" )
	
	g_Msg_SayText = get_user_msgid( "SayText" )
	register_message( g_Msg_SayText, "Message_SayText" )
	
	g_pCvars[cvar_nick] = register_cvar( "amx_chat_nick_enable", "1" )
	g_pCvars[cvar_minlen] = register_cvar( "amx_chat_nick_minlen", "3" )
	g_pCvars[cvar_maxlen] = register_cvar( "amx_chat_nick_maxlen", "16" )

	g_aAdminTags = ArrayCreate( 32, 1 )
	g_aAdminFlags = ArrayCreate( 1, 1 )
}

public plugin_end( )
{
	ArrayDestroy( g_aAdminTags )
	ArrayDestroy( g_aAdminFlags )
}

public client_putinserver( id )
{
	g_szNick[id][0] = '^0'
	get_user_name( id, g_szName[id], 31 )
}

public client_infochanged( id )
{
	get_user_info( id, "name", g_szName[id], 31 )
}

public ServerCommand_SetTag( )
{
	static szArg[32], iFlags
	read_argv( 1, szArg, 31 )
	if( !(iFlags = read_flags(szArg)) )
	{
		server_print( "[AMX Chat] Cannot read flags (%s)", szArg )
		return PLUGIN_HANDLED;
	}
	
	read_argv( 2, szArg, 31 )
	if( !strlen(szArg) )
	{
		server_print( "[AMX Chat] Cannot set tag with an empty name" )
		return PLUGIN_HANDLED;
	}
	
	if( EqualFlags(iFlags) )
	{
		server_print( "[AMX Chat] Flags (%s) is already registered", szArg )
		return PLUGIN_HANDLED;
	}
	
	if( g_iAdminNums >= MAX_TAGS )
	{
		server_print( "[AMX Chat] Max tags exceeded" )
		return PLUGIN_HANDLED;
	}
	
	ArrayPushString( g_aAdminTags, szArg )
	ArrayPushCell( g_aAdminFlags, iFlags )
	g_iAdminNums ++
	return PLUGIN_HANDLED;
}

public ClientCommand_Say( id )
{
	static szArg[38]
	read_argv( 1, szArg, 37 )
	if( !szArg[0] )
		return PLUGIN_HANDLED;
	
	if( get_pcv_i(cvar_nick) )
	{
		static szCommand[6], szNick[32]
		argbreak( szArg, szCommand, 5, szNick, 31 )
		if( equal(szCommand, "/nick") || equal(szCommand, "/msg") )
		{
			static iLen; iLen = strlen( szNick );
			if( g_szNick[id][0] && !iLen )
			{
				g_szNick[id][0] = '^0'
				client_printc( id, print_green, "[AMX Chat]^1 你的個人稱號已經重設" )
				return PLUGIN_HANDLED;
			}
			
			static iMinLen; iMinLen = get_pcv_i(cvar_minlen);
			if( iLen < iMinLen )
			{
				client_printc( id, print_green, "[AMX Chat]^1 請使用最少^4 %d ^1個字元作為稱號", iMinLen )
				return PLUGIN_HANDLED;
			}
			
			if( equal(szNick, g_szNick[id]) )
			{
				client_printc( id, print_green, "[AMX Chat]^1 請使用一個新的稱號" )
				return PLUGIN_HANDLED;
			}
			
			while( replace(szNick, 31, "%", "％") ) {}
			
			copy( g_szNick[id], clamp(get_pcv_i(cvar_maxlen), 1, 31), szNick )
			client_printc( id, print_green, "[AMX Chat]^1 你的個人稱號設定為 ^1'^4%s^1'", g_szNick[id] )
			return PLUGIN_HANDLED;
		}
	}
	
	FormatSays( id )
	g_bFirstSay = true;
	return PLUGIN_CONTINUE;
}

public Message_SayText( iMsgId, iMsgDest, id )
{
	static szString1[32]
	get_msg_arg_string( 2, szString1, 31 )
	
	if( !equal(szString1, "#Cstrike_Chat", 13) )
		return;
	
	if( g_bFormatted )
	{
		// Fix the color
		if( equal(szString1, "#Cstrike_Chat_All") )
			set_msg_arg_string( 2, Cstrike_Chat_All )
		
		set_msg_arg_string( 3, g_szFormatted )
	}
	
	// Not team message
	if ( g_bFirstSay && equal(szString1, "#Cstrike_Chat_All", 17) )
	{
		new iSender = get_msg_arg_int( 1 )
		
		static szString2[192], szString3[192]
		get_msg_arg_string( 3, szString2, 191 )
		get_msg_arg_string( 4, szString3, 191 )
		
		new iPlayers[32], iNum
		get_players( iPlayers, iNum, is_user_alive( iSender ) ? "b" : "a" )
			
		for ( new i = 0; i < iNum; i++ )
		{
			new iPlayer = iPlayers[i]
			
			message_begin( MSG_ONE_UNRELIABLE, g_Msg_SayText, _, iPlayer )
			write_byte( iSender )
			write_string( szString1 )
			write_string( szString2 )
			write_string( szString3 )
			message_end( )
		}
	}
	
	g_bFirstSay = false;
}

FormatSays( id )
{
	static iNum
	iNum = CheckFlags(id) + 1
	if( iNum )
	{
		g_szFormatted[0] = '^4'
		ArrayGetString( g_aAdminTags, iNum-1, g_szFormatted[1], 103 )
		iNum = add( g_szFormatted, 104, " ^3" )
	}
	if( get_pcv_i(cvar_nick) && g_szNick[id][0] )
		iNum += formatex( g_szFormatted[iNum], 104-iNum, "^3[^1%s^3] ", g_szNick[id] )

	if( iNum )
	{
		g_bFormatted = true
		add( g_szFormatted, 104, g_szName[id] )
		return true;
	}
	
	g_bFormatted = false
	return false;
}

stock CheckFlags( id )
{
	for( new i = 0; i < g_iAdminNums; i ++ )
		if( get_user_flags(id) & ArrayGetCell(g_aAdminFlags, i) )
			return i;
	
	return -1;
}

stock EqualFlags( iFlags )
{
	for( new i = 0; i < g_iAdminNums; i ++ )
		if( iFlags == ArrayGetCell(g_aAdminFlags, i) )
			return true;

	return false;
}

stock client_printc( index, Colors:type, const message[], any:... )
{
	static szBuffer[192]

	switch( type )
	{
		case print_default:	szBuffer[0] = '^1';
		case print_team:	szBuffer[0] = '^2';
		case print_green:	szBuffer[0] = '^4';
	}
	
	if( numargs() < 4 )
		copy( szBuffer[1], 190, message );
	else
		vformat( szBuffer[1], 190, message, 4 );

	message_begin( index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, g_Msg_SayText, .player=index )
	write_byte( index )
	write_string( szBuffer )
	message_end( )
}