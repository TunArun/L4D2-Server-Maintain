// 放置建筑物（支持角度 + 抬高）此时ShopItem中command为实体类名，item为皮肤
void TryPlaceBuild(int client, ShopItem si){
    //点数处理
    if (g_points.client[client] < si.price){
        PrintToChat(client, "点数不足！当前点数: %d", g_points.client[client]);
        return;
    }
    g_points.client[client] -= si.price;
    //生成实体

    TeleportEntity(ent, endPos, ang, NULL_VECTOR);//传送到指定坐标+角度
    SetEntityMoveType(ent, MOVETYPE_NONE);  // 禁止物理移动
    PrintToChat(client, "建造成功,剩余%d点", g_points.client[client]);
}
void CalcuPosAngle( int client, int ent){
    // 视线角度
    float vEye[3], vAng[3];
    GetClientEyePosition(client, vEye);
    GetClientEyeAngles(client, vAng);
    float player_forward[3];
    GetAngleVectors(vAng, player_forward, NULL_VECTOR, NULL_VECTOR);
    // 坐标玩家前方 100 单位
    float startPos[3];
    startPos[0] = vEye[0] + player_forward[0] * 100.0;
    startPos[1] = vEye[1] + player_forward[1] * 100.0;
    startPos[2] = vEye[2] - 32.0;
    float endTrace[3];
    endTrace[0] = startPos[0];
    endTrace[1] = startPos[1];
    endTrace[2] = startPos[2] - 256.0 ;
    //射线碰撞检测
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
}
public bool TraceEntityFilterPlayers(int entity, int contentsMask, any data)
{
    return entity != data;
}
// 创建易碎建筑或机枪
int CreateNormal(int client, ShopItem si,){
    int ent = CreateEntityByName(si.command);
    if (ent == -1){
        PrintToChat(client, "创建建筑失败！");
        return;
    }
    if (StrContains(si.item , "weapons") != -1){
        DispatchKeyValue(ent, "MaxYaw", "170");
        DispatchKeyValue(ent, "MinPitch", "-10");
        DispatchKeyValue(ent, "MaxPitch", "20");
    }
    DispatchKeyValue(ent, "model", si.item);
    DispatchSpawn(ent);
    SetEntityMoveType(ent, MOVETYPE_NONE);
    if(si.hp != -1)
    {
        SetEntProp(ent, Prop_Data, "m_iHealth", si.hp);
        SDKHook(ent, SDKHook_OnTakeDamage, OnBuildTakeDamage);
    }
    return ent;
}
// 创建不可破坏建筑(变成可被小僵尸破坏)
int CreateBreakable(int health = 999, int material = 6){
   // 创建不可见 breakable
    int ent = CreateEntityByName("func_breakable");
    char healthStr[16], materialStr[16];
    IntToString(si.hp, healthStr, sizeof(healthStr));
    IntToString(6, materialStr, sizeof(materialStr));
    DispatchKeyValue(ent, "health", healthStr);
    DispatchKeyValue(ent, "material", materialStr);
    DispatchKeyValue(ent, "ExplodeDamage", "0");
    DispatchKeyValue(ent, "ExplodeRadius", "0");
    DispatchKeyValue(ent, "spawnflags", "0"); // 可被攻击
    DispatchSpawn(ent);
    SetEntityMoveType(ent, MOVETYPE_NONE);
    // 创建可见 prop
    if (!StrEqual(si.item, "null"))
    {
        int prop = CreateEntityByName("prop_dynamic_override");
        DispatchKeyValue(prop, "model", si.item);
        DispatchSpawn(prop);
        TeleportEntity(prop, endPos, ang, NULL_VECTOR);
        // 绑定到 breakable
        AcceptEntityInput(prop, "SetParent", ent);
    }
    return ent;
}