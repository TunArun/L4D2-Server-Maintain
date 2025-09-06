#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
public Plugin myinfo =  
{ 
	name = "[L4D2]Building Points Shop", 
	author = "TunArund,奈", 
	description = "塔防积分商店", 
	version = "2.2", 
	url = "https://github.com/NanakaNeko/l4d2_plugins_coop" 
}

new g_iPoints[MAXPLAYERS+1];
// 奖励点数
ConVar g_hPointsCommon, g_hPointsSpecial, g_hPointsTank, g_hPointsWitch;
//物资价格
ConVar g_hPriceMedkit, g_hPricePills, g_hPriceAdrenaline, g_hPriceDefib;
ConVar g_hPriceMolotov, g_hPricePipe, g_hPriceVomit;
ConVar g_hPriceAmmo, g_hPriceInc, g_hPriceExp, g_hPriceLaser;
//建筑物models路径
ConVar g_hModelWoodDoor, g_hModelCheckDoor, g_hModelBoard, g_hModelFence;
//建筑物价格
ConVar g_hPriceWoodDoor, g_hPriceCheckDoor, g_hPriceBoard, g_hPriceFence;
//建筑物血量
ConVar g_hHPWoodDoor, g_hHPCheckDoor, g_hHPBoard, g_hHPFence;
// ---- 插件初始化 ----
public void OnPluginStart()
{
    RegConsoleCmd("sm_shop", Command_Shop);
    HookEvent("infected_death", Event_InfectedDeath); 
    HookEvent("player_death", Event_PlayerDeath); 
    // 积分奖励
    g_hPointsCommon  = CreateConVar("sm_td_points_common",  "1",  "普通丧尸击杀获得的点数");
    g_hPointsSpecial = CreateConVar("sm_td_points_special", "5",  "特感击杀获得的点数");
    g_hPointsWitch   = CreateConVar("sm_td_points_witch",   "7", "巫女击杀获得的点数");
    g_hPointsTank    = CreateConVar("sm_td_points_tank",    "10", "坦克击杀获得的点数");

    // 医疗物资
    g_hPriceMedkit     = CreateConVar("sm_td_price_medkit", "30", "医疗包价格");
    g_hPricePills      = CreateConVar("sm_td_price_pills", "15", "止痛药价格");
    g_hPriceAdrenaline = CreateConVar("sm_td_price_adrenaline", "20", "肾上腺素价格");
    g_hPriceDefib      = CreateConVar("sm_td_price_defib", "40", "电击器价格");
    // 投掷物
    g_hPriceMolotov = CreateConVar("sm_td_price_molotov", "15", "燃烧瓶价格");
    g_hPricePipe    = CreateConVar("sm_td_price_pipe",    "15", "土制炸弹价格");
    g_hPriceVomit   = CreateConVar("sm_td_price_vomit",   "15", "胆汁瓶价格");
    // 升级
    g_hPriceAmmo  = CreateConVar("sm_td_price_ammo",    "25", "弹药价格");
    g_hPriceInc   = CreateConVar("sm_td_price_incendiary", "25", "燃烧弹药价格");
    g_hPriceExp   = CreateConVar("sm_td_price_explosive",  "25", "爆炸弹药价格");
    g_hPriceLaser = CreateConVar("sm_td_price_laser",      "25", "激光瞄准器价格");
    // 建筑物models路径
    g_hModelWoodDoor  = CreateConVar("sm_td_model_wooddoor",  "models/props_doors/doormain_rural01_small.mdl", "木门模型路径");
    g_hModelCheckDoor = CreateConVar("sm_td_model_checkdoor", "models/props_doors/doormainmetal01_dm01.mdl", "检查点门模型路径");
    g_hModelBoard     = CreateConVar("sm_td_model_board",     "models/props_debris/wood_board04a.mdl", "木板模型路径");
    g_hModelFence     = CreateConVar("sm_td_model_fence",     "models/props_urban/wood_fence001_64.mdl", "栅栏模型路径");
    // 建筑物价格
    g_hPriceWoodDoor  = CreateConVar("sm_td_price_wooddoor",   "20", "木门价格");
    g_hPriceCheckDoor = CreateConVar("sm_td_price_checkdoor",  "40", "检查点门价格");
    g_hPriceBoard     = CreateConVar("sm_td_price_board",      "10", "木板价格");
    g_hPriceFence     = CreateConVar("sm_td_price_fence",      "25", "栅栏门价格");
    // 建筑物血量（仅对非原生可破坏模型生效）
    g_hHPWoodDoor  = CreateConVar("sm_td_hp_wooddoor",  "300",  "木门血量");
    g_hHPCheckDoor = CreateConVar("sm_td_hp_checkdoor", "800",  "检查点门血量");
    g_hHPBoard     = CreateConVar("sm_td_hp_board",     "200",  "木板血量");
    g_hHPFence     = CreateConVar("sm_td_hp_fence",     "400",  "铁栅栏血量");

    AutoExecConfig(true, "l4d2_towerdefense_shop"); // 自动生成配置文件
}
public void OnMapStart()
{
    char modelPath[PLATFORM_MAX_PATH];
    int size = sizeof(modelPath);

    GetConVarString(g_hModelWoodDoor, modelPath, size);
    PrecacheModel(modelPath, true);
    GetConVarString(g_hModelCheckDoor, modelPath, size);
    PrecacheModel(modelPath, true);
    GetConVarString(g_hModelBoard, modelPath, size);
    PrecacheModel(modelPath, true);
    GetConVarString(g_hModelFence, modelPath, size);
    PrecacheModel(modelPath, true);
}

// ---- 玩家加入游戏 初始化积分 ----
public void OnClientPutInServer(int client)
{
    g_iPoints[client] = 0;
}

void ClearPoints()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        g_iPoints[i] = 0;
    }
}
// 普通丧尸死亡
public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker <= 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
        return Plugin_Continue;
    g_iPoints[attacker] += g_hPointsCommon.IntValue; //普通感染者
    //PrintToChat(attacker, "击杀普通感染者，获得%d点(目前%d点)", g_hPointsCommon.IntValue, g_iPoints[attacker]);
    return Plugin_Continue;
}

// 特感死亡（Tank / Witch / Eta）
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if( client <= 0 || attacker <= 0 || !IsClientInGame(client) || !IsClientInGame(attacker) ) return Plugin_Continue;
    bool survivorDeath = true;
    if(GetClientTeam(client) == 3 && GetClientTeam(attacker) == 2) survivorDeath = false;
    if(survivorDeath){
        PrintToChat(client, "你已死亡，清空%d点", g_iPoints[client]);
        g_iPoints[client] = 0;
        return Plugin_Continue;
    }
    int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    //PrintToChat(attacker, "击杀%d号特感", zombieClass);//Debug
    switch(zombieClass){
        case 1,2,3,4,5,6:{
            g_iPoints[attacker] += g_hPointsSpecial.IntValue; //特殊感染者
            PrintToChat(attacker, "击杀特感，获得%d点(目前%d点)", g_hPointsSpecial.IntValue, g_iPoints[attacker]);
        }
        case 7:{//Witch
            g_iPoints[attacker] += g_hPointsWitch.IntValue; 
            PrintToChat(attacker, "击杀Witch，获得%d点(目前%d点)", g_hPointsWitch.IntValue, g_iPoints[attacker]);
        }
        case 8:{//tank
            g_iPoints[attacker] += g_hPointsTank.IntValue; //Tank
            PrintToChat(attacker, "击杀Tank，获得%d点(目前%d点)", g_hPointsTank.IntValue, g_iPoints[attacker]);
        }
    }
    return Plugin_Continue;
}

// 主商店菜单
public Action Command_Shop(int client, int args)
{
    if(!IsClientInGame(client)) return Plugin_Handled;

    Menu menu = new Menu(ShopMainHandler);
    menu.SetTitle("塔防商店 - 点数:%d", g_iPoints[client]);
    menu.AddItem("med", "医疗物资");
    menu.AddItem("throw", "投掷物");
    menu.AddItem("upgrade", "升级&弹药");
    menu.AddItem("build", "建筑物");
    menu.Display(client, 10);

    return Plugin_Handled;
}

public int ShopMainHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if(StrEqual(info, "med"))
            OpenMedMenu(client);
        else if(StrEqual(info, "throw"))
            OpenThrowMenu(client);
        else if(StrEqual(info, "upgrade"))
            OpenUpgradeMenu(client);
        else if(StrEqual(info, "build"))
            OpenBuildMenu(client);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// 医疗物资菜单
void OpenMedMenu(int client)
{
    Menu menu = new Menu(MedHandler);
    menu.SetTitle("医疗物资 - 点数:%d", g_iPoints[client]);
    menu.AddItem("medkit", "医疗包 (%d点)", g_hPriceMedkit.IntValue);
    menu.AddItem("pills",  "止痛药 (%d点)", g_hPricePills.IntValue);
    menu.AddItem("adrenaline", "肾上腺素 (%d点)", g_hPriceAdrenaline.IntValue);
    menu.AddItem("defib",  "电击器 (%d点)", g_hPriceDefib.IntValue);
    menu.Display(client, 10);
}

public int MedHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char info[32]; menu.GetItem(item, info, sizeof(info));
        if(StrEqual(info,"medkit"))     TryGiveItem(client, "give weapon_first_aid_kit", g_hPriceMedkit);
        else if(StrEqual(info,"pills")) TryGiveItem(client, "give weapon_pain_pills", g_hPricePills);
        else if(StrEqual(info,"adrenaline")) TryGiveItem(client, "give weapon_adrenaline", g_hPriceAdrenaline);
        else if(StrEqual(info,"defib")) TryGiveItem(client, "give weapon_defibrillator", g_hPriceDefib);
    }
    else if(action == MenuAction_End) delete menu;
    return 0;
}

// 投掷物菜单
void OpenThrowMenu(int client)
{
    Menu menu = new Menu(ThrowHandler);
    menu.SetTitle("投掷物 - 点数:%d", g_iPoints[client]);
    menu.AddItem("molotov",  "燃烧瓶 (%d点)", g_hPriceMolotov.IntValue);
    menu.AddItem("pipe",     "土质炸弹 (%d点)", g_hPricePipe.IntValue);
    menu.AddItem("vomitjar", "胆汁瓶 (%d点)",  g_hPriceVomit.IntValue);
    menu.Display(client, 10);
}

public int ThrowHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char info[32]; menu.GetItem(item, info, sizeof(info));
        if(StrEqual(info,"molotov"))  TryGiveItem(client, "give weapon_molotov", g_hPriceMolotov);
        else if(StrEqual(info,"pipe")) TryGiveItem(client, "give weapon_pipe_bomb", g_hPricePipe);
        else if(StrEqual(info,"vomitjar")) TryGiveItem(client, "give weapon_vomitjar", g_hPriceVomit);
    }
    else if(action == MenuAction_End) delete menu;
    return 0;
}



// 武器升级菜单
void OpenUpgradeMenu(int client)
{
    Menu menu = new Menu(UpgradeHandler);
    menu.SetTitle("升级&弹药 - 点数:%d", g_iPoints[client]);
    menu.AddItem("ammo",  "弹药 (%d点)", g_hPriceAmmo.IntValue);
    menu.AddItem("inc",  "燃烧弹药 (%d点)", g_hPriceInc.IntValue);
    menu.AddItem("exp",  "爆炸弹药 (%d点)", g_hPriceExp.IntValue);
    menu.AddItem("laser","激光瞄准器 (%d点)", g_hPriceLaser.IntValue);
    menu.Display(client, 10);
}

public int UpgradeHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char info[32]; menu.GetItem(item, info, sizeof(info));
        if(StrEqual(info,"inc"))  TryGiveItem(client, "upgrade_add incendiary_ammo", g_hPriceInc);
        else if(StrEqual(info,"exp")) TryGiveItem(client, "upgrade_add explosive_ammo", g_hPriceExp);
        else if(StrEqual(info,"laser")) TryGiveItem(client, "upgrade_add laser_sight", g_hPriceLaser);
    }
    else if(action == MenuAction_End) delete menu;
    return 0;
}
// -----通用Give------
void TryGiveItem(int client, const char[] command, ConVar priceCvar)
{
    int price = priceCvar.IntValue;
    if(g_iPoints[client] < price)
    {
        PrintToChat(client, "点数不足！");
        return;
    }
    g_iPoints[client] -= price;
    PrintToChat(client, "购买成功,剩余%d点)", g_iPoints[client]);
    //临时去除command的FCVAR_CHEAT标志
    char cmd[32];
	if (SplitString(command, " ", cmd, sizeof cmd) == -1)
		strcopy(cmd, sizeof cmd, command);
    int flags = GetCommandFlags(cmd);
    SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
    //可以执行cheat command
    FakeClientCommand(client, command);
    //恢复command的FCVAR_CHEAT标志
    SetCommandFlags(cmd, flags);
}
// 建筑物菜单
void OpenBuildMenu(int client)
{
    Menu menu = new Menu(BuildHandler);
    menu.SetTitle("建筑物 - 点数:%d", g_iPoints[client]);
    menu.AddItem("wooddoor","木门 (20点)");
    menu.AddItem("checkdoor","铁门 (40点)");
    menu.AddItem("woodboard","木板 (10点)");
    menu.AddItem("fence","铁栅栏 (25点)");
    menu.Display(client, 10);
}

new String:g_sBuildModel[MAXPLAYERS+1][128];
new g_iBuildPrice[MAXPLAYERS+1];
public int BuildHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_End || action != MenuAction_Select){
        delete menu;
        return 0;
    }
    char info[32]; 
    BuildType type;
    menu.GetItem(item, info, sizeof(info));
    
    if(StrEqual(info,"wooddoor"))
    {
        type = BUILD_WOODDOOR;
        GetConVarString(g_hModelWoodDoor, g_sBuildModel[client], sizeof(g_sBuildModel[]));
        g_iBuildPrice[client] = g_hPriceWoodDoor.IntValue;
    }
    else if(StrEqual(info,"checkdoor"))
    {
        type = BUILD_CHECKDOOR;
        GetConVarString(g_hModelCheckDoor, g_sBuildModel[client], sizeof(g_sBuildModel[]));
        g_iBuildPrice[client] = g_hPriceCheckDoor.IntValue;
    }
    else if(StrEqual(info,"woodboard"))
    {
        type = BUILD_BOARD;
        GetConVarString(g_hModelBoard, g_sBuildModel[client], sizeof(g_sBuildModel[]));
        g_iBuildPrice[client] = g_hPriceBoard.IntValue;
    }
    else if(StrEqual(info,"fence"))
    {
        type = BUILD_FENCE;
        GetConVarString(g_hModelFence, g_sBuildModel[client], sizeof(g_sBuildModel[]));
        g_iBuildPrice[client] = g_hPriceFence.IntValue;
    }
    // 直接放置建造物，朝向为玩家视角
    TryPlaceBuild(client, g_sBuildModel[client], g_iBuildPrice[client], type);
    return 0;
}

// -------------------- 通用函数 ----------------------
// 建筑物标识
enum BuildType
{
    BUILD_WOODDOOR,
    BUILD_CHECKDOOR,
    BUILD_BOARD,
    BUILD_FENCE
};
public bool TraceEntityFilterPlayers(int entity, int contentsMask, any data)
{
    return entity != data;
}
// 放置建筑物（支持角度 + 抬高）
void TryPlaceBuild(int client, const char[] model, int price, BuildType type)
{
    //点数处理
    if (g_iPoints[client] < price)
    {
        PrintToChat(client, "点数不足！当前点数: %d", g_iPoints[client]);
        return;
    }
    g_iPoints[client] -= price;
    // 创建实体
    int ent = StrContains(model, "door") != -1
        ? CreateEntityByName("prop_door_rotating")
        : CreateEntityByName("prop_physics_override");
    if (ent == -1)
    {
        PrintToChat(client, "创建建筑失败！");
        return;
    }
    DispatchKeyValue(ent, "model", model);
    DispatchSpawn(ent);
    // 血量
    int hp = 200;
    switch (type)
    {
        case BUILD_WOODDOOR: hp = g_hHPWoodDoor.IntValue;
        case BUILD_CHECKDOOR: hp = g_hHPCheckDoor.IntValue;
        case BUILD_BOARD: hp = g_hHPBoard.IntValue;
        case BUILD_FENCE: hp = g_hHPFence.IntValue;
    }
    SetEntProp(ent, Prop_Data, "m_iHealth", hp);
    SDKHook(ent, SDKHook_OnTakeDamage, OnBuildTakeDamage);
    // 视线角度
    float vEye[3], vAng[3];
    GetClientEyePosition(client, vEye);
    GetClientEyeAngles(client, vAng);

    float player_forward[3];
    GetAngleVectors(vAng, player_forward, NULL_VECTOR, NULL_VECTOR);
    // 玩家前方 100 单位
    float startPos[3];
    startPos[0] = vEye[0] + player_forward[0] * 100.0;
    startPos[1] = vEye[1] + player_forward[1] * 100.0;
    startPos[2] = vEye[2] - 32.0;
    float endTrace[3];
    endTrace[0] = startPos[0];
    endTrace[1] = startPos[1];
    endTrace[2] = startPos[2] - 256.0 ;
    Handle trace = TR_TraceRayFilterEx(startPos, endTrace, MASK_SOLID, RayType_EndPoint, TraceEntityFilterPlayers, client);
    if (!TR_DidHit(trace))
    {
        PrintToChat(client, "无法在该位置建造！");
        CloseHandle(trace);
        return;
    }
    float endPos[3];
    TR_GetEndPosition(endPos, trace);
    CloseHandle(trace);
    // 抬高
    float mins[3], maxs[3];
    GetEntPropVector(ent, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxs);
    endPos[2] -= mins[2];

    float ang[3] = { 0.0, 0.0, 0.0 };
    ang[1] = vAng[1];
    TeleportEntity(ent, endPos, ang, NULL_VECTOR);

    

    PrintToChat(client, "建造成功,剩余%d点", g_iPoints[client]);
}


// 建筑物受伤逻辑
public Action OnBuildTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if(!IsValidEntity(entity)) return Plugin_Continue;

    int hp = GetEntProp(entity, Prop_Data, "m_iHealth");
    hp -= RoundToNearest(damage);

    if(hp <= 0)
    {
        AcceptEntityInput(entity, "Kill");
        return Plugin_Continue;
    }
    SetEntProp(entity, Prop_Data, "m_iHealth", hp);
    return Plugin_Continue;
}

