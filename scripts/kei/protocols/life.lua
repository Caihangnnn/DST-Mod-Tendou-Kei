local LIFE_PROTOCOL_LIST = {
    {
        protocol = "map_teleport",
        prefab = "kei_life_cd_map_teleport",
        display_name = "折叠星图",
        description = "打开地图后右键可传送到指定位置。",
        source = "hermitcrab",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "durability_restore",
        prefab = "kei_life_cd_durability_restore",
        display_name = "不息机杼",
        description = "定期修复物品栏与装备栏中的耐久物品。",
        source = "hermitcrab",
        stackable = true,
        implemented = true,
    },
    {
        protocol = "growth_acceleration",
        prefab = "kei_life_cd_growth_acceleration",
        display_name = "催芽时轮",
        description = "使附近实体的成长计时加速；每叠加一张，成长速度额外提高 2 倍。",
        source = "monkeyqueen",
        stackable = true,
        implemented = true,
    },
    {
        protocol = "trade_boost",
        prefab = "kei_life_cd_trade_boost",
        display_name = "交易增强",
        description = "流浪商人路线规划协议；用于强化交易与制作收益。",
        source = "wanderingtrader",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "fish_call",
        prefab = "kei_life_cd_fish_call",
        display_name = "唤鱼",
        description = "大霜鲨路线规划协议；用于召唤或引导鱼群。",
        source = "sharkboi",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "fast_pick",
        prefab = "kei_life_cd_fast_pick",
        display_name = "快速采集",
        description = "采集经验路线规划协议；用于提升采集效率。",
        source = "work_pick",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "fast_craft",
        prefab = "kei_life_cd_fast_craft",
        display_name = "快速制作",
        description = "制作经验路线规划协议；用于提升制作效率。",
        source = "work_craft",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "plant_affinity",
        prefab = "kei_life_cd_plant_affinity",
        display_name = "植物亲和",
        description = "收获经验路线规划协议；用于改善植物互动。",
        source = "work_harvest",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "fullmoon_recipe",
        prefab = "kei_life_cd_fullmoon_recipe",
        display_name = "满月配方",
        description = "满月调查月台获得的特异现象协议。",
        source = "moonbase_fullmoon",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "newmoon_recipe",
        prefab = "kei_life_cd_newmoon_recipe",
        display_name = "新月配方",
        description = "新月调查三基佬雕像获得的特异现象协议。",
        source = "shadow_triad_newmoon",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "monkey_neutral",
        prefab = "kei_life_cd_monkey_neutral",
        display_name = "猴类中立",
        description = "调查非自然传送门获得的特异现象协议。",
        source = "monkey_portal",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "water_walk",
        prefab = "kei_life_cd_water_walk",
        display_name = "踏水",
        description = "调查未激活帝王蟹获得的特异现象协议。",
        source = "crabking",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "ripen",
        prefab = "kei_life_cd_ripen",
        display_name = "催熟配方",
        description = "调查大树干获得的特异现象协议。",
        source = "deciduoustree_tall",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "weather",
        prefab = "kei_life_cd_weather",
        display_name = "晴雨配方",
        description = "调查绿洲获得的特异现象协议。",
        source = "oasislake",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "lunar_affinity",
        prefab = "kei_life_cd_lunar_affinity",
        display_name = "月亮亲和",
        description = "辉煌裂隙调查路线协议；用于月亮亲和与辉煌科技。",
        source = "lunarrift",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "ancient_tech",
        prefab = "kei_life_cd_ancient_tech",
        display_name = "远古科技",
        description = "完整远古塔调查路线协议；用于远古科技。",
        source = "ancient_station",
        stackable = false,
        implemented = false,
    },
    {
        protocol = "shadow_affinity",
        prefab = "kei_life_cd_shadow_affinity",
        display_name = "暗影亲和",
        description = "暗影裂隙调查路线协议；用于暗影亲和与暗影术科技。",
        source = "shadowrift",
        stackable = false,
        implemented = false,
    },
}

local LIFE_PROTOCOLS = {}
local LIFE_PROTOCOL_PREFABS = {}

for _, def in ipairs(LIFE_PROTOCOL_LIST) do
    def.kind = "life"
    LIFE_PROTOCOLS[def.protocol] = def
    LIFE_PROTOCOL_PREFABS[def.prefab] = def.protocol
end

local function GetProtocolPrefab(protocol)
    local def = protocol ~= nil and LIFE_PROTOCOLS[protocol] or nil
    return def ~= nil and def.prefab or nil
end

return {
    LIFE_PROTOCOLS = LIFE_PROTOCOLS,
    LIFE_PROTOCOL_LIST = LIFE_PROTOCOL_LIST,
    LIFE_PROTOCOL_PREFABS = LIFE_PROTOCOL_PREFABS,
    GetProtocolPrefab = GetProtocolPrefab,
}
