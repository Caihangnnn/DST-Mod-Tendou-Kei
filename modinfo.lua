-- 模组在游戏列表中的基础信息。
name = "Tendou Kei"
description = "First playable code pass for Tendou Kei."
author = "StellarVoyage"
version = "0.1.1"

-- DST 模组基础兼容配置。
api_version = 10
priority = 0

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true

-- 服务器筛选标签，方便玩家按角色 / Kei / Tendou 关键词检索。
server_filter_tags = {
    "character",
    "kei",
    "tendou",
}

configuration_options = {
    {
        name = "KEI_PROTOCOL_SLOT_MODE",
        label = "Kei 协议槽位",
        hover = "设置 Kei 的最大协议槽数量，以及每次使用 Mk 模块解锁的槽位数量。",
        options = {
            {
                description = "7 槽 / 每次 +2",
                hover = "初始 1 个槽位，Mk1/Mk2/Mk3 分别解锁到 3/5/7 个槽位。",
                data = "7_2",
            },
            {
                description = "4 槽 / 每次 +1",
                hover = "初始 1 个槽位，Mk1/Mk2/Mk3 分别解锁到 2/3/4 个槽位。",
                data = "4_1",
            },
        },
        default = "7_2",
    },
    {
        name = "KEI_ANALYSIS_CONSUME_EQUIPMENT",
        label = "解析装备消耗",
        hover = "设置装备解析成功后，是否消耗被解析的原装备。",
        options = {
            {
                description = "不消耗",
                hover = "解析成功后保留原装备。",
                data = false,
            },
            {
                description = "消耗",
                hover = "解析成功后消耗被解析的原装备。",
                data = true,
            },
        },
        default = false,
    },
    {
        name = "KEI_ANALYSIS_USE_EQUIPMENT_VISUAL",
        label = "数据化装备显示",
        hover = "设置解析协议是否使用原装备的背包贴图和掉落动画。",
        options = {
            {
                description = "原装备显示",
                hover = "数据化装备按照被解析的原装备显示（可能会导致部分模组装备地面动画消失）。",
                data = true,
            },
            {
                description = "默认显示",
                hover = "数据化装备使用统一使用瓦格斯塔夫的剪切板显示。",
                data = false,
            },
        },
        default = true,
    },
    {
        name = "KEI_BEEQUEEN_PRESTIGE_MODE",
        label = "蜂后协议威压",
        hover = "设置蜂后战斗协议威压被动的触发方式。",
        options = {
            {
                description = "嘶吼领域",
                hover = "受到生物攻击时，在 Kei 位置触发蜂后嘶吼，对周围 12 范围内的生物施加 5 秒恐慌，并有 3 秒触发冷却。",
                data = "area",
            },
            {
                description = "反制攻击者",
                hover = "保留原方案：受到生物攻击时，仅让本次攻击者陷入恐慌。",
                data = "retaliate",
            },
        },
        default = "area",
    },
}
