local function CombatPrefab(protocol)
    return "kei_combat_data_cd_" .. protocol
end

local COMBAT_PROTOCOL_LIST = {}

local function AddProtocol(data)
    data.kind = data.kind or "combat"
    data.protocol = data.protocol or data.id
    data.prefab = data.prefab or CombatPrefab(data.protocol)
    table.insert(COMBAT_PROTOCOL_LIST, data)
    return data
end

local function AddRows(rows, defaults)
    for _, row in ipairs(rows) do
        local data = {}
        for k, v in pairs(defaults or {}) do
            data[k] = v
        end
        data.id = row[1]
        data.display_name = row[2]
        data.description = row[3]
        if row[4] ~= nil then
            for k, v in pairs(row[4]) do
                data[k] = v
            end
        end
        AddProtocol(data)
    end
end

-- XMind: 群系协议 CD。当前先提供稳定 prefab 和元数据，效果后续逐项接入。
AddRows({
    { "spider_black", "黑蜘蛛", "在蜘蛛网上移动不会减速。" },
    { "spider_yellow", "黄蜘蛛", "在蜘蛛网上移动不会减速，并获得加速；可强化蜘蛛女王协议随从移速。" },
    { "spider_white", "白蜘蛛", "在蜘蛛网上攻击力提高；可强化蜘蛛女王协议随从攻击力。" },
    { "spider_cave", "洞穴蜘蛛", "在蜘蛛网上获得减伤；可强化蜘蛛女王协议随从减伤。" },
    { "spider_spitter", "喷吐蜘蛛", "伤害敌方单位时降低目标移速；可强化蜘蛛女王协议随从攻速。" },
    { "spider_shattered", "破碎蜘蛛", "受到攻击时反伤；可强化蜘蛛女王协议随从位面实体抵抗。" },
    { "spider_healer", "护士蜘蛛", "可以受到护士蜘蛛治疗；可强化蜘蛛女王协议随从治疗效果。" },
    { "spiderqueen", "蜘蛛女王", "角色附近视为蜘蛛网区域，并可吸收、召唤和强化蜘蛛随从。" },
}, { category = "biome", family = "spider", implemented = false, recordable = false })

AddRows({
    { "gnarwail", "一角鲸", "攻击有概率触发水波，造成附加伤害并打湿周围单位。" },
    { "sharkboi", "岩石大白鲨", "获得潮湿装甲，受伤时优先以潮湿度抵扣完整度损失。" },
    { "otter", "水獭掠夺者", "攻击敌方单位时有概率偷取其战利品中的肉类物品。" },
    { "grassgator", "草鳄鱼", "身上有潮湿度时自然恢复机体完整度。" },
}, { category = "biome", family = "aquatic", implemented = false, recordable = false })

AddRows({
    { "bishop", "发条主教", "攻击附带电击效果。" },
    { "rook", "发条战车", "右键短暂格挡，成功格挡时完全豁免本次伤害。" },
    { "knight", "发条骑士", "受到攻击时反伤并附带电击效果。" },
}, { category = "biome", family = "mechanical", implemented = false, recordable = false })

-- XMind: 初级巨兽协议 CD。为后续初级/高级分流预留独立 prefab；暂不改变现有记录器产物。
AddRows({
    { "deerclops_basic", "独眼巨鹿初级", "免疫过冷和冰冻。", { source_protocol = "deerclops" , implemented = true } },
    { "bearger_basic", "熊獾初级", "攻击造成衰减性群体伤害。", { source_protocol = "bearger" , implemented = true } },
    { "moose_basic", "麋鹿鹅初级", "免疫潮湿。", { source_protocol = "moose" , implemented = true } },
    { "antlion_basic", "蚁狮初级", "免疫沙尘暴、月亮风暴的减速和滤镜。", { source_protocol = "antlion", implemented = true } },
    { "eyeofterror_basic", "克眼初级", "获得右键冲刺能力，冷却 1 秒；冲刺不造成伤害。", { source_protocol = "eyeofterror", implemented = true } },
    { "daywalker_basic", "梦魇疯猪初级", "获得右键跳劈能力，冷却 3 秒；造成 150 点范围伤害，并生成持续 3 秒的陷坑。", { source_protocol = "daywalker" , implemented = true } },
    { "daywalker2_basic", "拾荒疯猪初级", "获得霸体，免疫僵直和击飞。", { source_protocol = "daywalker2" , implemented = true } },
    { "lordfruitfly_basic", "果蝇王初级", "战斗协议和解析协议的固定消耗减半。", { source_protocol = "lordfruitfly" , implemented = true } },
    { "minotaur_basic", "远古守卫者初级", "攻击有概率对目标触发暗影囚笼。", { source_protocol = "minotaur" , implemented = true } },
    { "vault_pillar_guard_basic", "远古戍卫塔初级", "使用攻击距离为 1 的武器时，普通攻击变为旋转攻击。", { source_protocol = "vault_pillar_guard" , implemented = true } },
    { "dragonfly_basic", "龙蝇初级", "免疫燃烧和过热。", { source_protocol = "dragonfly" , implemented = true } },
    { "malbatross_basic", "邪天翁初级", "在水面上会快速增加潮湿度。", { source_protocol = "malbatross" } },
    { "klaus_basic", "克劳斯初级", "攻击有概率从目标身上抽落灵魂，治疗友方单位。", { source_protocol = "klaus" , implemented = true } },
    { "toadstool_basic", "蟾蜍初级", "免疫催眠。", { source_protocol = "toadstool" , implemented = true } },
    { "beequeen_basic", "蜂后初级", "受到攻击时恐惧攻击者 5 秒。", { source_protocol = "beequeen" , implemented = true } },
    { "stalker_atrium_basic", "织影者初级", "稳定性为 0 时，战斗协议不再失效。", { source_protocol = "stalker_atrium" , implemented = true } },
    { "alterguardian_basic", "天体英雄初级", "电量为 0 时，解析协议不再失效，也不会带来移速惩罚。", { source_protocol = "alterguardian" , implemented = true } },
}, { category = "beast", tier = "basic", implemented = false, recordable = false })
-- 当前已实现的一组协议保留原 protocol id；按 XMind 语义视为高级/特殊巨兽协议。
AddRows({
    { "deerclops", "独眼巨鹿高级", "攻击附带冰冻，并免疫冰冻与过冷。", { short_name = "独眼巨鹿" } },
    { "mutateddeerclops", "独眼晶体巨鹿", "攻击后在脚下生成时缓圈，使范围内非友方单位时间流速减半。", { tier = "special", implemented = true } },
    { "mutatedwarg", "附身座狼", "按 R 触发喷火技能，冷却 10 秒。", { tier = "special", implemented = true } },
    { "bearger", "熊獾高级", "攻击造成无衰减群体伤害。", { short_name = "熊獾", planned_update = true } },
    { "mutatedbearger", "装甲熊獾", "独立乘区攻击速度提高 30%。", { tier = "special", implemented = true } },
    { "dragonfly", "龙蝇高级", "攻击会点燃目标，每秒造成最大生命值 0.1% 的伤害，并免疫过热与火焰伤害。", { short_name = "龙蝇", implemented = true } },
    { "moose", "麋鹿鹅高级", "免疫潮湿；攻击有 20% 概率附带旋风。", { short_name = "麋鹿鹅" } },
    { "eyeofterror", "克眼高级", "获得右键冲刺能力，冲刺会伤害路径上的敌方单位。", { short_name = "克眼", record_prefabs = { "twinofterror1", "twinofterror2" } } },
    { "daywalker", "梦魇疯猪高级", "右键跳劈到鼠标指定位置；造成 150 点加目标最大生命值 4% 的范围伤害，生成持续 3 秒的陷坑，并使目标 3 秒内移速降至 10%。", { short_name = "梦魇疯猪" } },
    { "daywalker2", "拾荒疯猪高级", "获得霸体，并获得 25% 免伤。", { short_name = "拾荒疯猪", implemented = true } },
    { "lordfruitfly", "果蝇王高级", "战斗协议和解析协议不再额外消耗电量与数据稳定性。", { short_name = "果蝇王", implemented = true } },
    { "minotaur", "远古守卫者高级", "攻击有概率触发暗影囚笼与暗影触手。", { short_name = "远古守卫者", implemented = true } },
    { "vault_pillar_guard", "远古戍卫塔高级", "独立乘区攻击速度提高 20%；手持攻击距离为 1 的武器时，普通攻击变为旋转攻击。", { short_name = "远古戍卫塔", implemented = true } },
    { "wagboss_robot", "战争瓦器人", "攻击时对目标触发月能轨道打击，冷却 20 秒。", { tier = "special", implemented = true } },
    { "malbatross", "邪天翁高级", "在水面上行动时增加伤害与移动速度。", { short_name = "邪天翁", planned_update = true } },
    { "klaus", "克劳斯高级", "攻击有概率抽落灵魂治疗友方，并追加目标最大生命值伤害。", { short_name = "克劳斯", planned_update = true } },
    { "toadstool", "蟾蜍高级", "攻击有概率向目标脚下投掷睡袋，并免疫催眠。", { short_name = "蟾蜍", implemented = true, record_prefabs = { "toadstool_dark" } } },
    { "antlion", "蚁狮高级", "免疫沙尘暴、月亮风暴；攻击有概率在目标脚下生成中心大沙刺和三枚小沙刺。", { short_name = "蚁狮" } },
    { "beequeen", "蜂后高级", "获得被动技能威压，受到攻击时释放恐惧光环。", { short_name = "蜂后", implemented = true } },
    { "stalker_atrium", "织影者高级", "数据稳定性为 0 时，战斗协议不再失效；攻击有 30% 概率触发影袭，造成本次伤害 50% 的额外伤害。", { short_name = "织影者", implemented = true } },
    { "alterguardian", "天体英雄高级", "电量为 0 时，解析协议不再失效；每 10 秒回复 10 点电量。", { short_name = "天体英雄", implemented = true, record_prefabs = { "alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3" } } },
    { "alterguardian_phase4_lunarrift", "天体后裔", "天体宝珠环绕 Kei；攻击时宝珠加速旋转，并造成本次伤害 50% 的额外伤害。", { tier = "special", implemented = true } },
}, { category = "beast", tier = "advanced", implemented = true })

local COMBAT_PROTOCOLS = {}
local COMBAT_PROTOCOL_PREFABS = {}
local VALID_RECORD_TARGETS = {}
local RECORD_TARGET_PROTOCOLS = {}

for _, def in ipairs(COMBAT_PROTOCOL_LIST) do
    COMBAT_PROTOCOLS[def.protocol] = def
    COMBAT_PROTOCOL_PREFABS[def.prefab] = def.protocol

    if def.recordable ~= false then
        VALID_RECORD_TARGETS[def.protocol] = true
        RECORD_TARGET_PROTOCOLS[def.protocol] = def.protocol
        if def.record_prefabs ~= nil then
            for _, record_prefab in ipairs(def.record_prefabs) do
                VALID_RECORD_TARGETS[record_prefab] = true
                RECORD_TARGET_PROTOCOLS[record_prefab] = def.protocol
            end
        end
    end
end

local function GetRecordProtocol(prefab)
    return RECORD_TARGET_PROTOCOLS[prefab]
end

local function GetProtocolPrefab(protocol)
    local def = protocol ~= nil and COMBAT_PROTOCOLS[protocol] or nil
    return def ~= nil and def.prefab or nil
end

return {
    COMBAT_PROTOCOLS = COMBAT_PROTOCOLS,
    COMBAT_PROTOCOL_LIST = COMBAT_PROTOCOL_LIST,
    COMBAT_PROTOCOL_PREFABS = COMBAT_PROTOCOL_PREFABS,
    VALID_RECORD_TARGETS = VALID_RECORD_TARGETS,
    RECORD_TARGET_PROTOCOLS = RECORD_TARGET_PROTOCOLS,
    GetRecordProtocol = GetRecordProtocol,
    GetProtocolPrefab = GetProtocolPrefab,
}
