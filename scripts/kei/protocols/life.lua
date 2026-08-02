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
        description = "与猪王/蚁狮交易时提升金子/石头价值；与鱼人王/寄居蟹奶奶/大霜鲨交易时鱼视为大鱼。",
        source = "wanderingtrader",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "fish_call",
        prefab = "kei_life_cd_fish_call",
        display_name = "唤鱼",
        description = "解锁唤鱼魔法；制作时在附近水域召唤鱼群，并强化池钓与海钓。",
        source = "sharkboi",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "fullmoon_recipe",
        prefab = "kei_life_cd_fullmoon_recipe",
        display_name = "满月配方",
        description = "插入后解锁满月魔法；制作时触发 book_moon 的月圆效果。",
        source = "moonbase_fullmoon",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "newmoon_recipe",
        prefab = "kei_life_cd_newmoon_recipe",
        display_name = "新月配方",
        description = "插入后解锁新月魔法；制作时触发 book_moon 类似的新月效果。",
        source = "shadow_triad_newmoon",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "water_walk",
        prefab = "kei_life_cd_water_walk",
        display_name = "踏水",
        description = "允许 Kei 在海面上行走。",
        source = "crabking",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "ripen",
        prefab = "kei_life_cd_ripen",
        display_name = "催熟配方",
        description = "插入后解锁催熟魔法；制作时推进周围可生长实体一个阶段，并使农作物强制巨大化。",
        source = "watertree_pillar",
        stackable = false,
        implemented = true,
    },
    {
        protocol = "weather",
        prefab = "kei_life_cd_weather",
        display_name = "晴雨配方",
        description = "插入后解锁晴雨魔法；制作时在晴天与雨/雪之间切换。",
        source = "oasislake",
        stackable = false,
        implemented = true,
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
