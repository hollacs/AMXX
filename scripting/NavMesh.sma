#include <amxmodx>
#include <fakemeta>

#define MAX_VERTS 1024
new Float:g_vert[MAX_VERTS][3];
new g_vertCount;

#define MAX_EDGES 512
new g_edge[MAX_EDGES][2];
new g_eFace[MAX_EDGES][2];
new g_edgeCount;

#define MAX_FACES 320
new g_face[MAX_FACES][3];
new g_faceCount;

new g_selectMode;
new g_menuPage;
new g_editor;

public plugin_init()
{
	register_plugin("Navigation Mesh", "0.1", "colga");
	
	register_clcmd("navmesh_menu", "cmdNavMeshMenu");
}

public cmdNavMeshMenu(id)
{
	new menu = menu_create("Navmesh Menu", "handleNavMeshMenu");
	
	switch (g_selectMode)
	{
		case 0: menu_additem(menu, "Select: \yVertex");
		case 1: menu_additem(menu, "Select: \yEdge");
		case 2: menu_additem(menu, "Select: \yFace");
	}
	
	menu_additem(menu, "Create Vertex");
	menu_additem(menu, "Create Triangle");
	
	g_editor = id;
	menu_display(id, menu, g_menuPage);
}

public handleNavMeshMenu(id, menu, item)
{
	
}