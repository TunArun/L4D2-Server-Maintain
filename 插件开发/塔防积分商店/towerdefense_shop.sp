#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
public Plugin myinfo =  
{ 
	name = "[L4D2]Building Points Shop", 
	author = "TunArund,奈", 
	description = "塔防积分商店", 
	version = "2.2", 
	url = "https://github.com/TunArun" 
}

// 全局存储
ConVar g_hConfigPath;
enum struct Points{
    //存储奖励点数
    int common;
    int special;
    int witch;
    int tank;
    int client[MAXPLAYERS+1];//存储玩家积分
}
enum struct ShopItem
{
    char id[32];        // 物品内部 ID
    char name[64];      // 展示名称
    char item[64];      // 实体/物品 ID
    char command[32];   // give 或 upgrade_add
    int price;          // 价格
    char category[32];  // 一级分类，例如 medical / throwable / upgrade / building
    int hp;             // 建筑血量，仅建筑有效，其他置 0
}
enum struct ShopCategory{
    char id[32];
    char name[64];
}
Points g_points; // 存储奖励和玩家点数
ArrayList g_items;   // 存储所有物品
ArrayList g_categories;  // 存储一级分类名称

// ---- 插件初始化 ----
public void OnPluginStart()
{
    //配置文件
    g_hConfigPath = CreateConVar("sm_td_config_path", "cfg/sourcemod/towerdefense_shop.cfg", "塔防商店菜单配置");
    AutoExecConfig(true, "l4d2_towerdefense_shop"); // 自动生成配置文件
    g_items = new ArrayList(sizeof(ShopItem));
    g_categories = new ArrayList(sizeof(ShopCategory));
    if(!LoadShopConfig())return;// 加载商店配置文件
    LoadPoints(); // 加载点数
    // 注册命令
    RegAdminCmd("sm_shop_admin", Command_ShopAdmin, ADMFLAG_ROOT, "重载商店配置文件");
    RegConsoleCmd("sm_shop", Command_Shop);
    HookEvent("infected_death", Event_InfectedDeath); 
    HookEvent("witch_killed", Event_WitchKilled); 
    HookEvent("player_death", Event_PlayerDeath); 
    HookEvent("mission_lost", Event_MissionLost); // 战役模式结束
    HookEvent("survival_round_start", Event_MissionLost);// Survival 模式结束

}
public void OnMapStart(){
    ShopItem item;
    for(int i=FindItemByCategory("building"); i != -1; i = FindItemByCategory("building", i+1)){
        g_items.GetArray(i, item, sizeof(item));
        PrecacheModel(item.item, true);
    }
}
// ---- 玩家加入游戏 初始化积分 ----
public void OnClientPutInServer(int client){
    g_points.client[client] = 0;
}
// ---- 生还团灭，清除所有积分 ----
public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    ClearPoints(-1);
}
//清除所有/指定人的积分
void ClearPoints(int client =-1){
    if(client != -1){
        g_points.client[client] = 0;
        return;
    }
    for(int i = 1; i <= MaxClients; i++){
        g_points.client[i] = 0;
    }
    return;
    
}
// 从g_items加载击杀奖励点数g_points
int GetPointPrice(const char[] id, int defaultValue) {
    int idx = FindItemById(id);
    if (idx != -1) {
        ShopItem tmp;
        g_items.GetArray(idx, tmp, sizeof(tmp));
        return tmp.price;
    }
    return defaultValue;
}
void LoadPoints() {
    g_points.common  = GetPointPrice("common", 1);
    g_points.special = GetPointPrice("special", 5);
    g_points.witch   = GetPointPrice("witch", 7);
    g_points.tank    = GetPointPrice("tank", 10);
}
// 普通丧尸死亡
public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker <= 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
        return Plugin_Continue;
    g_points.client[attacker] += g_points.common; //普通感染者
    //PrintToChat(attacker, "击杀普通感染者，获得%d点(目前%d点)", g_points.common, g_points.client[attacker]);
    return Plugin_Continue;
}
// 生还或特感死亡（tank / Eta）不含witch，witch单独处理
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if( client <= 0 || attacker <= 0 || !IsClientInGame(client) || !IsClientInGame(attacker) ) return Plugin_Continue;

    bool survivorDeath = GetClientTeam(client)==2; //生还者死亡
    if(survivorDeath){
        PrintToChat(client, "你已死亡，扣除%d点", g_points.client[client]);
        g_points.client[client] = 0;
        return Plugin_Continue;
    }
    //特感被生还击杀
    bool specialDeath = GetClientTeam(attacker) == 2 ;
    if(!specialDeath) return Plugin_Continue;

    int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    //PrintToChat(attacker, "击杀%d号特感", zombieClass);//Debug
    switch(zombieClass){
        case 1,2,3,4,5,6:{
            g_points.client[attacker] += g_points.special; //特殊感染者
            PrintToChat(attacker, "击杀特感，获得%d点(目前%d点)", g_points.special, g_points.client[attacker]);
        }
        case 8:{//tank
            g_points.client[attacker] += g_points.tank; //tank
            PrintToChat(attacker, "击杀tank，获得%d点(目前%d点)", g_points.tank, g_points.client[attacker]);
        }
    }
    return Plugin_Continue;
}
// Witch死亡
public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
    if( client <= 0 || !IsClientInGame(client) || !(GetClientTeam(client) == 2) ) return;

	g_points.client[client] += g_points.witch;
    PrintToChat(client, "击杀witch，获得%d点(目前%d点)", g_points.witch, g_points.client[client]);
}
// ------------管理员菜单-------------
public Action Command_ShopAdmin(int client, int args)
{
    //修改点数
    //保存修改到kv文件
    //重载kv文件
    return Plugin_Handled;
}
// ------------主菜单-------------
public Action Command_Shop(int client, int args)
{
    // 检查客户端索引是否有效
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Handled;

    Menu menu = new Menu(ShopMainHandler);
    menu.SetTitle("塔防商店 - 点数:%d", g_points.client[client]);
    ShopCategory tmp;
    for(int i=0;i<g_categories.Length;i++){
        g_categories.GetArray(i, tmp, sizeof(tmp));
        //跳过points商品item
        if(strcmp(tmp.id,"points")!=0 )menu.AddItem(tmp.id, tmp.name);
    }
    menu.Display(client, 10);

    return Plugin_Handled;
}

public int ShopMainHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char choice[32];
        menu.GetItem(item, choice, sizeof(choice));
        if(StrEqual(choice,"building")){ 
            OpenBuildMenu(client);
        } else {
            OpenItemMenu(client, choice);
        }
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// 物资菜单
void OpenItemMenu(int client, const char[] choice)
{
    //id->类别名
    int i = FindCategoryById(choice);
    if(i==-1) return;
    ShopCategory tmp;
    g_categories.GetArray(i, tmp, sizeof(tmp));
    //设置标题：类别名 - 当前点数
    char title[128];
    Format(title, sizeof(title), "%s - 点数:%d", tmp.name, g_points.client[client]);
    Menu menu = new Menu(ItemHandler);
    menu.SetTitle(title);
    //添加选项:id 物品name - 价格
    char display[128];
    ShopItem item;
    for(i=FindItemByCategory(choice);i!=-1;i=FindItemByCategory(choice,i+1)){
        g_items.GetArray(i, item, sizeof(item));
        Format(display, sizeof(display), "%s (%d点)", item.name, item.price);
        menu.AddItem(item.id, display);
    }
    menu.ExitBackButton=true;
    menu.Display(client, 10);
}

public int ItemHandler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        //获取选项id
        char info[32]; menu.GetItem(item, info, sizeof(info));
        //获取物品信息
        int i= FindItemById(info);
        if(i==-1) return 0;
        ShopItem tmp;
        g_items.GetArray(i, tmp, sizeof(tmp));
        //构造指令
        char cmd[64];
        Format(cmd, sizeof(cmd), "%s %s", tmp.command, tmp.item); //e.g. give weapon_first_aid_kit
        TryGiveItem(client, cmd, tmp.price);
    }
    else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack) Command_Shop(client, 0);
    else if(action == MenuAction_End) delete menu;
    return 0;
}
// -----通用Give------
void TryGiveItem(int client, const char[] command, int price)
{
    //点数检测
    if(g_points.client[client] < price)
    {
        PrintToChat(client, "点数不足！");
        return;
    }
    g_points.client[client] -= price;
    PrintToChat(client, "购买成功,剩余%d点)", g_points.client[client]);
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
// ---------建筑物----------
void OpenBuildMenu(int client)
{
    Menu menu = new Menu(BuildHandler);
    menu.SetTitle("建筑物 - 点数:%d", g_points.client[client]);
    char display[128];
    ShopItem item;
    for(int i=FindItemByCategory("building");i!=-1;i=FindItemByCategory("building",i+1)){
        g_items.GetArray(i, item, sizeof(item));
        Format(display, sizeof(display), "%s (%d点)", item.name, item.price);
        menu.AddItem(item.id, display);
    }
    menu.ExitBackButton=true;
    menu.Display(client, 10);
}

public int BuildHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) {
        delete menu;
    } else if(action == MenuAction_Select){
        char id[32]; 
        menu.GetItem(item, id, sizeof(id));
        int i = FindItemById(id);
        if(i==-1)return 0;
        ShopItem tmp;
        g_items.GetArray(i, tmp, sizeof(tmp));
        // 放置建造物，限制100单位内朝向玩家
        TryPlaceBuild(client, tmp);
    }else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack){
        Command_Shop(client, 0);
    }
    return 0;
}

// -------------------- 建筑物通用函数 ----------------------

// 放置建筑物（支持角度 + 抬高）此时ShopItem中command为实体类名，item为皮肤
void TryPlaceBuild(int client, ShopItem si)
{
    //点数处理
    if (g_points.client[client] < si.price)
    {
        PrintToChat(client, "点数不足！当前点数: %d", g_points.client[client]);
        return;
    }
    g_points.client[client] -= si.price;
    // 创建逻辑实体
    int ent = CreateEntityByName(si.command);
    if (ent == -1){
        PrintToChat(client, "创建建筑失败！");
        return;
    }
    // weapons设置属性
    if(StrContains(si.item , "weapons")!=-1){
        DispatchKeyValue(ent, "MaxYaw", "170");    // 可旋转最大角
        DispatchKeyValue(ent, "MinPitch", "-10");  // 最大仰角
        DispatchKeyValue(ent, "MaxPitch", "20");   // 最大俯角
    }
    // 设置model（皮肤）
    DispatchKeyValue(ent, "model", si.item);
    // 生成实体
    DispatchSpawn(ent);
    if(StrContains(si.item , "weapons")!=-1)AcceptEntityInput(ent, "Enable");

    if(si.hp != -1){// 其他物品看hp,-1表示无限，不用绑定扣血逻辑，游戏内自行处理
        SetEntProp(ent, Prop_Data, "m_iHealth", si.hp);
        SDKHook(ent, SDKHook_OnTakeDamage, OnBuildTakeDamage);
    }
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
    if(StrContains(si.item , "weapons")!=-1)ang[1] += 180.0;
        
    TeleportEntity(ent, endPos, ang, NULL_VECTOR);//传送到指定坐标+角度
    SetEntityMoveType(ent, MOVETYPE_NONE);  // 禁止物理移动

    PrintToChat(client, "建造成功,剩余%d点", g_points.client[client]);
}
public bool TraceEntityFilterPlayers(int entity, int contentsMask, any data)
{
    return entity != data;
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
// -------------------- 配置文件 ----------------------
// Category->index，startIndex=-1时未找到
int FindItemByCategory(const char[] category, int startIndex=0){
    ShopItem tmp;
    int len = g_items.Length;

    for(int i = startIndex; i < len; i++){
        g_items.GetArray(i, tmp , sizeof(tmp));
        if(StrEqual(tmp.category, category)){
            return i;
        }
    }

    return -1;
}
// id->item
int FindItemById(const char[] id){
    ShopItem tmp;
    int len = g_items.Length;
    for(int i=0; i < len; i++){
        g_items.GetArray(i, tmp , sizeof(tmp));
        if(StrEqual(tmp.id, id)){
            return i;
        }
    }
    return -1;
}
int FindCategoryById(const char[] id){
    ShopCategory tmp;
    int len = g_categories.Length;
    for(int i=0; i < len; i++){
        g_categories.GetArray(i, tmp , sizeof(tmp));
        if(StrEqual(tmp.id, id)){
            return i;
        }
    }
    return -1;
}
// 创建默认配置文件
void ResetShopConfig()
{
    KeyValues kv = new KeyValues("TowerDefenseShop");
    // 创建categories部分
    kv.JumpToKey("categories", true);
        kv.SetString("points", "点数");
        kv.SetString("medical", "医疗物资");
        kv.SetString("throwable", "投掷物");
        kv.SetString("upgrade", "升级&弹药");
        kv.SetString("building", "建筑");
    kv.GoBack();
    // 创建Points部分
    kv.JumpToKey("points", true);
        kv.JumpToKey("common", true);
        kv.SetString("name", "普通感染者");
        kv.SetString("price", "1");
        kv.GoBack();

        kv.JumpToKey("special", true);
        kv.SetString("name", "特殊感染者");
        kv.SetString("price", "5");
        kv.GoBack();

        kv.JumpToKey("witch", true);
        kv.SetString("name", "witch");
        kv.SetString("price", "7");
        kv.GoBack();

        kv.JumpToKey("tank", true);
        kv.SetString("name", "tank");
        kv.SetString("price", "10");
        kv.GoBack();
    kv.GoBack();
    // 创建medical部分
    kv.JumpToKey("medical", true);
        kv.JumpToKey("adrenaline", true);
        kv.SetString("name", "肾上腺素");
        kv.SetString("item", "weapon_adrenaline");
        kv.SetString("command", "give");
        kv.SetString("price", "10");
        kv.GoBack();

        kv.JumpToKey("pills", true);
        kv.SetString("name", "止痛药");
        kv.SetString("item", "weapon_pain_pills");
        kv.SetString("command", "give");
        kv.SetString("price", "15");
        kv.GoBack();

        kv.JumpToKey("medkit", true);
        kv.SetString("name", "医疗包");
        kv.SetString("item", "weapon_first_aid_kit");
        kv.SetString("command", "give");
        kv.SetString("price", "30");
        kv.GoBack();

        kv.JumpToKey("defib", true);
        kv.SetString("name", "电击器");
        kv.SetString("item", "weapon_defibrillator");
        kv.SetString("command", "give");
        kv.SetString("price", "30");
        kv.GoBack();
    kv.GoBack();
    // 创建throwable部分
    kv.JumpToKey("throwable", true);
        kv.JumpToKey("molotov", true);
        kv.SetString("name", "燃烧瓶");
        kv.SetString("item", "weapon_molotov");
        kv.SetString("command", "give");
        kv.SetString("price", "15");
        kv.GoBack();

        kv.JumpToKey("pipebomb", true);
        kv.SetString("name", "土制炸弹");
        kv.SetString("item", "weapon_pipe_bomb");
        kv.SetString("command", "give");
        kv.SetString("price", "15");
        kv.GoBack();

        kv.JumpToKey("vomitjar", true);
        kv.SetString("name", "胆汁瓶");
        kv.SetString("item", "weapon_vomitjar");
        kv.SetString("command", "give");
        kv.SetString("price", "15");
        kv.GoBack();
    kv.GoBack();
    // 创建upgrade部分
    kv.JumpToKey("upgrade", true);
        kv.JumpToKey("ammo", true);
        kv.SetString("name", "弹药");
        kv.SetString("item", "ammo");
        kv.SetString("command", "give");
        kv.SetString("price", "10");
        kv.GoBack();

        kv.JumpToKey("incendiary_ammo", true);
        kv.SetString("name", "燃烧弹药");
        kv.SetString("item", "incendiary_ammo");
        kv.SetString("command", "upgrade_add");
        kv.SetString("price", "10");
        kv.GoBack();

        kv.JumpToKey("explosive_ammo", true);
        kv.SetString("name", "爆炸弹药");
        kv.SetString("item", "explosive_ammo");
        kv.SetString("command", "upgrade_add");
        kv.SetString("price", "10");
        kv.GoBack();

        kv.JumpToKey("laser", true);
        kv.SetString("name", "激光瞄准器");
        kv.SetString("item", "laser_sight");
        kv.SetString("command", "upgrade_add");
        kv.SetString("price", "25");
        kv.GoBack();
    kv.GoBack();
    // 创建building部分
    kv.JumpToKey("building", true);
        kv.JumpToKey("irondoor", true);
        kv.SetString("name", "铁门");
        kv.SetString("item", "models/props_doors/doormainmetal01_dm01.mdl");
        kv.SetString("command", "prop_door_rotating");
        kv.SetNum("price", 30);
        kv.SetNum("hp", -1);
        kv.GoBack();

        kv.JumpToKey("fence", true);
        kv.SetString("name", "栅栏");
        kv.SetString("item", "models/props_urban/wood_fence001_64.mdl");
        kv.SetString("command", "prop_physics_override");
        kv.SetNum("price", 50);
        kv.SetNum("hp", 2000);
        kv.GoBack();

        kv.JumpToKey("50cal", true);
        kv.SetString("name", ".50机枪");
        kv.SetString("item", "models/w_models/weapons/50cal.mdl");
        kv.SetString("command", "prop_mounted_machine_gun");
        kv.SetNum("price", 100);
        kv.SetNum("hp", 7000);
        kv.GoBack();

        kv.JumpToKey("gatling", true);
        kv.SetString("name", "加特林机枪");
        kv.SetString("item", "models/w_models/weapons/w_minigun.mdl");
        kv.SetString("command", "prop_minigun_l4d1");
        kv.SetNum("price", 100);
        kv.SetNum("hp", 7000);
        kv.GoBack();

        kv.JumpToKey("gascan", true);
        kv.SetString("name", "白色大油桶");
        kv.SetString("item", "models/props_industrial/barrel_fuel.mdl");
        kv.SetString("command", "prop_fuel_barrel");
        kv.SetNum("price", 50);
        kv.SetNum("hp", -1);
        kv.GoBack();
    kv.GoBack();
    //导出到文件
    char path[PLATFORM_MAX_PATH];
    g_hConfigPath.GetString(path, sizeof(path));
    if (!kv.ExportToFile(path))
        PrintToServer("[塔防商店] 生成默认配置失败: %s", path);
    else
        PrintToServer("[塔防商店] 默认配置已生成: %s", path);

    delete kv;
}
// 读取商店配置到g_items和g_categories
bool LoadShopConfig()
{
    // 读取kv
    KeyValues kv = new KeyValues("TowerDefenseShop");
    char path[PLATFORM_MAX_PATH];
    g_hConfigPath.GetString(path, sizeof(path));
    if (!kv.ImportFromFile(path))
    {
        PrintToServer("[塔防商店] 未找到配置文件: %s,生成默认配置", path);
        ResetShopConfig();
        kv.ImportFromFile(path);
    }
    
    g_items.Clear();
    g_categories.Clear();
    // --- 判断能否读取元分类 ---
    if (!kv.JumpToKey("categories") || !kv.GotoFirstSubKey(false)){
        PrintToServer("[塔防商店] 未找到 categories 节点");
        PrintToServer("[塔防商店] 尝试重新生成并读取kv文件");
        ResetShopConfig();
        kv.ImportFromFile(path);
        if (!kv.JumpToKey("categories") || !kv.GotoFirstSubKey(false) ){
            PrintToServer("[塔防商店] 仍无法读取categories节点，插件退出");
            delete kv;
            return false;
        }
    }
    // --- 能读取元分类 ---
    ShopCategory cat;
    do{
        kv.GetSectionName(cat.id, sizeof(cat.id));      // 英文 ID
        kv.GetString(NULL_STRING, cat.name, sizeof(cat.name), "未知分类"); // 中文名
        g_categories.PushArray(cat);
        PrintToServer("读取到分类%s:%s",cat.id,cat.name);
    } while (kv.GotoNextKey(false));
    // --- 回到根节点 ---
    kv.Rewind();
    // --- 遍历各个分类节点 ---
    for(int i=0;i<g_categories.Length;i++){
        g_categories.GetArray(i, cat, sizeof(cat));
        // PrintToServer("从分类数组中取第%d个分类%s:%s",i,cat.id,cat.name);
        //跳转到对应分类节点
        if (!kv.JumpToKey(cat.id, false)) {
            PrintToServer("未在kv找到分类 %s",cat.id);
            continue;
        }
        // 遍历分类下所有物品
        if (kv.GotoFirstSubKey(true)) do {
            ShopItem item;
            kv.GetSectionName(item.id, sizeof(item.id));
            kv.GetString("name", item.name, sizeof(item.name), "未知物品");
            kv.GetString("item", item.item, sizeof(item.item), "unknown_item");
            kv.GetString("command", item.command, sizeof(item.command), "give");
            item.price = kv.GetNum("price", 999);
            item.hp    = kv.GetNum("hp", 1);
            strcopy(item.category, sizeof(item.category), cat.id);
            g_items.PushArray(item);
            // PrintToServer("读取到物品Category:%s\nid:%s\nname:%s\nitem:%s\ncommand:%s\nprice:%d\nhp:%d",
            //     item.category,item.id,item.name,item.item,item.command,item.price,item.hp
            // );
        } while (kv.GotoNextKey(true));
        // 回到根节点，查看下一个分类
        kv.Rewind();
    }
    PrintToServer("[塔防商店] 成功加载%d 个大类共%d 个物品，", g_categories.Length, g_items.Length);
    delete kv;return true;
}


