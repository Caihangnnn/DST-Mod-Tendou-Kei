-- 模组在游戏列表中的基础信息。
name = "Tendou Kei"
description = "First playable code pass for Tendou Kei."
author = "StellarVoyage"
version = "0.1.0"

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
}
