-- =============================================================================
--                               🌸 特别声明 🌸
-- =============================================================================
--   本模组代码完全开源，仅供学习交流与参考使用。
--   严禁二次上传、二次修改或将本代码直接复制用于新模组。原则上不允许添加本模组的任意补丁。
--   如需调整或添加补丁并上传与朋友联机游玩，请将您的模组权限优先设置为【仅好友】或【非公开】。
--   饥荒MOD的良好环境需要我们每一个人来维护，切勿做一个小偷MODER，感谢您的尊重与合作！

--                               感谢您的支持！
-- =============================================================================

-- 模组在游戏列表中的基础信息。
author = "StellarVoyage"
version = "0.1.2"
name = "Tendou Kei"
description = "First playable code pass for Tendou Kei."

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
                hover = "数据化装备使用统一使用 CD 显示。",
                data = false,
            },
        },
        default = true,
    },
    {
        name = "KEI_ALLOW_DATA_COPY",
        label = "允许拷贝协议数据",
        hover = "开启后，可用空白数据记录 CD 拷贝战斗数据 CD，也可用装备解析工具拷贝数据化装备。",
        options = {
            {
                description = "允许",
                hover = "允许消耗对应材料复制已有协议 CD。",
                data = true,
            },
            {
                description = "禁止",
                hover = "禁止通过右键拷贝已有协议 CD。",
                data = false,
            },
        },
        default = true,
    },
    {
        name = "KEI_PROTOCOL_DRAIN_SOUND",
        label = "协议消耗音效",
        hover = "设置战斗协议和解析协议每 10 秒扣除电量/数据稳定性时，是否播放资源下降音效。",
        options = {
            {
                description = "开启",
                hover = "协议周期扣除资源时播放电量/数据稳定性下降音效。",
                data = true,
            },
            {
                description = "关闭",
                hover = "协议周期扣除资源时不播放资源下降音效。",
                data = false,
            },
        },
        default = true,
    },
    {
        name = "KEI_PROTOCOL_INITIAL_EXTRA_SLOTS",
        label = "初始额外协议槽",
        hover = "设置 Kei 初始额外解锁的协议槽数量。每个额外槽位也会提高三维上限。",
        options = {
            { description = "0", data = 0 },
            { description = "1", data = 1 },
            { description = "2", data = 2 },
            { description = "3", data = 3 },
            { description = "4", data = 4 },
            { description = "5", data = 5 },
            { description = "6", data = 6 },
        },
        default = 0,
    },
    {
        name = "KEI_WANDERING_TRADER_MAP_MARKER",
        label = "流浪商人地图标记",
        hover = "设置是否在地图上显示流浪商人的专属标记。",
        options = {
            {
                description = "开启",
                hover = "在地图上显示流浪商人的专属标记。",
                data = true,
            },
            {
                description = "关闭",
                hover = "不为流浪商人添加地图标记。",
                data = false,
            },
        },
        default = true,
    },
}
