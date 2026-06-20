local LIFE_PROTOCOLS = {
    map_teleport = {
        display_name = "折叠星图",
        description = "打开地图后右键可传送到指定位置。",
        stackable = false,
    },
    growth_acceleration = {
        display_name = "催芽时轮",
        description = "使附近实体的成长计时加速；每叠加一张，成长速度额外提高 2 倍。",
        stackable = true,
    },
    durability_restore = {
        display_name = "不息机杼",
        description = "定期修复物品栏与装备栏中的耐久物品。",
        stackable = true,
    },
}

return {
    LIFE_PROTOCOLS = LIFE_PROTOCOLS,
}
