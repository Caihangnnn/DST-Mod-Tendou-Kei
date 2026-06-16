local COMBAT_PROTOCOLS = {
    deerclops = {
        kind = "combat",
        protocol = "deerclops",
        description = "独眼巨鹿数据：攻击附带冰冻，并免疫冻结与过冷。",
    },
    mutateddeerclops = {
        kind = "combat",
        protocol = "mutateddeerclops",
        display_name = "独眼晶体巨鹿",
        description = "独眼晶体巨鹿数据：攻击后在脚下生成寒冷圈，使范围内非友方单位动画与移速减半。",
    },
    mutatedwarg = {
        kind = "combat",
        protocol = "mutatedwarg",
        display_name = "附身座狼",
        description = "附身座狼数据：按 R 消耗 10 点数据稳定性，向鼠标方向喷出冷火，持续 5 秒，每 0.5 秒造成 50 点伤害，冷却 10 秒。",
    },
    bearger = {
        kind = "combat",
        protocol = "bearger",
        description = "熊獾数据：攻击会扩散冲击，造成群体伤害。",
    },
    mutatedbearger = {
        kind = "combat",
        protocol = "mutatedbearger",
        display_name = "装甲熊獾",
        description = "装甲熊獾数据：攻击速度提高 30%。",
    },
    dragonfly = {
        kind = "combat",
        protocol = "dragonfly",
        description = "龙蝇数据：攻击会点燃目标，并免疫过热与火焰伤害。",
    },
    moose = {
        kind = "combat",
        protocol = "moose",
        display_name = "麋鹿鹅",
        description = "麋鹿鹅数据：获得带电攻击，并免疫潮湿。",
    },
    eyeofterror = {
        kind = "combat",
        protocol = "eyeofterror",
        display_name = "克眼",
        record_prefabs = { "twinofterror1", "twinofterror2" },
        description = "克眼数据：右键冲锋到鼠标指定位置。",
    },
    daywalker = {
        kind = "combat",
        protocol = "daywalker",
        display_name = "梦魇疯猪",
        description = "梦魇疯猪数据：右键跳劈到鼠标指定位置，落地造成范围伤害并减速目标。",
    },
    daywalker2 = {
        kind = "combat",
        protocol = "daywalker2",
        display_name = "拾荒疯猪",
        description = "拾荒疯猪数据：免疫受击僵直、击飞、击退，但仍会正常承受伤害。",
    },
    lordfruitfly = {
        kind = "combat",
        protocol = "lordfruitfly",
        display_name = "果蝇王",
        description = "果蝇王数据：战斗协议和解析协议不再额外消耗电量与数据稳定性。",
    },
    minotaur = {
        kind = "combat",
        protocol = "minotaur",
        display_name = "远古守卫者",
        description = "远古守卫者数据：攻击有概率召唤友方守护者暗影触手，并有概率对目标释放暗影囚牢。",
    },
    vault_pillar_guard = {
        kind = "combat",
        protocol = "vault_pillar_guard",
        display_name = "远古戍卫塔",
        description = "远古戍卫塔数据：攻击速度提高 20%；手持攻击距离为 1 的武器时，普通攻击变为旋转攻击，并伤害旋转范围内的敌对生物。",
    },
    wagboss_robot = {
        kind = "combat",
        protocol = "wagboss_robot",
        display_name = "战争瓦器人",
        description = "战争瓦器人数据：攻击时对目标触发会追踪目标的月能轨道打击，冷却 20 秒。",
    },
    malbatross = {
        kind = "combat",
        protocol = "malbatross",
        display_name = "邪天翁",
        description = "邪天翁数据：无视海岸线，在海上行走。",
    },
    klaus = {
        kind = "combat",
        protocol = "klaus",
        display_name = "克劳斯",
        description = "克劳斯数据：攻击有概率从目标身上抽落灵魂，灵魂会立刻消散并治疗周围玩家。",
    },
    toadstool = {
        kind = "combat",
        protocol = "toadstool",
        display_name = "蟾蜍",
        record_prefabs = { "toadstool_dark" },
        description = "蟾蜍数据：攻击有概率向目标脚下投掷睡袋，并免疫催眠。",
    },
    antlion = {
        kind = "combat",
        protocol = "antlion",
        display_name = "蚁狮",
        description = "蚁狮数据：攻击有概率在目标脚下生成高大的沙刺，中心刺后接三角形顶点刺。",
    },
    beequeen = {
        kind = "combat",
        protocol = "beequeen",
        display_name = "蜂后",
        description = "蜂后数据：获得被动技能威压，生物攻击 Kei 时会立即陷入恐慌状态。",
    },
    stalker_atrium = {
        kind = "combat",
        protocol = "stalker_atrium",
        display_name = "织影者",
        description = "织影者数据：数据稳定性为 0 时，战斗协议不再失效；攻击有 30% 概率触发影袭，造成本次伤害一半的额外伤害。",
    },
    alterguardian = {
        kind = "combat",
        protocol = "alterguardian",
        display_name = "天体英雄",
        record_prefabs = { "alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3" },
        description = "天体英雄数据：电量为 0 时，解析协议不再失效；每 10 秒回复 10 点电量。",
    },
    alterguardian_phase4_lunarrift = {
        kind = "combat",
        protocol = "alterguardian_phase4_lunarrift",
        display_name = "天体后裔",
        description = "天体后裔数据：五个天体宝珠环绕 Kei；攻击时宝珠加速旋转，并造成本次伤害 20% 的额外伤害。",
    },
}

local VALID_RECORD_TARGETS = {}
local RECORD_TARGET_PROTOCOLS = {}

for prefab, def in pairs(COMBAT_PROTOCOLS) do
    VALID_RECORD_TARGETS[prefab] = true
    RECORD_TARGET_PROTOCOLS[prefab] = prefab
    if def.record_prefabs ~= nil then
        for _, record_prefab in ipairs(def.record_prefabs) do
            VALID_RECORD_TARGETS[record_prefab] = true
            RECORD_TARGET_PROTOCOLS[record_prefab] = prefab
        end
    end
end

local function GetRecordProtocol(prefab)
    return RECORD_TARGET_PROTOCOLS[prefab]
end

return {
    COMBAT_PROTOCOLS = COMBAT_PROTOCOLS,
    VALID_RECORD_TARGETS = VALID_RECORD_TARGETS,
    RECORD_TARGET_PROTOCOLS = RECORD_TARGET_PROTOCOLS,
    GetRecordProtocol = GetRecordProtocol,
}
