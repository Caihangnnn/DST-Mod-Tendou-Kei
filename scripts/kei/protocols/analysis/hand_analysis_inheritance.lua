local HandAnalysisInheritance = {}

local MODIFIER = "kei_analysis_hands"

-- 读取单个解析数据提供的伤害加成，优先使用固定加值，其次把倍率换算为裸手基础伤害的加值
local function GetAnalysisDamageBonus(data)
    if data.damage_bonus ~= nil then
        return data.damage_bonus
    end
    return data.damage_mult ~= nil and data.damage_mult > 1 and data.damage_mult * TUNING.UNARMED_DAMAGE or 0
end

-- 判断角色当前是否已经装备了手部物品，有手持装备时不会再临时注入工具动作
local function HasHandEquipment(inst)
    return inst.components.inventory ~= nil
        and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= nil
end

-- 根据继承到的伤害条目数量计算伤害缩放系数，使多条来源叠加时逐步趋于平滑而不是线性爆炸
local function GetDamageMultiplier(count)
    if count <= 0 then
        return 0
    end
    return 3.8 - 2.8 * math.exp(-0.25 * (count - 1))
end

-- 将累计的继承伤害总量结算为最终伤害加值
-- 这里先求平均值，再乘以数量衰减后的倍率，避免来源越多时收益失控
local function FinalizeDamage(stats)
    local count = stats.inherited_damage_count or 0
    if count <= 0 then
        stats.damage_bonus = 0
        return
    end

    local average = (stats.inherited_damage_total or 0) / count
    stats.damage_bonus = average * GetDamageMultiplier(count)
end

-- 把解析继承产生的伤害加值写入 combat.damagebonus，并先撤销旧值避免重复叠加
local function SetDamageBonus(protocolslots, amount)
    local combat = protocolslots.inst.components.combat
    local old = protocolslots.analysis_damage_bonus or 0
    amount = amount or 0

    if combat ~= nil then
        if old ~= 0 then
            combat.damagebonus = (combat.damagebonus or 0) - old
        end
        if amount ~= 0 then
            combat.damagebonus = (combat.damagebonus or 0) + amount
        end
    end

    protocolslots.analysis_damage_bonus = amount
end

-- 清理解析继承注入的工具动作、标签和临时 worker 组件，并恢复到应用前的原始状态
local function ClearToolActions(protocolslots)
    local worker = protocolslots.inst.components.worker
    if worker ~= nil then
        for action_id, old_value in pairs(protocolslots._kei_worker_action_old_values or {}) do
            local action = ACTIONS[action_id]
            if action ~= nil then
                worker.actions[action] = old_value
            end
        end
    end

    if protocolslots._kei_added_worker and protocolslots.inst.components.worker ~= nil then
        protocolslots.inst:RemoveComponent("worker")
    end

    for action_id, had_tag in pairs(protocolslots._kei_tool_action_old_tags or {}) do
        if not had_tag then
            local action = ACTIONS[action_id]
            local tag = action ~= nil and (action.id .. "_tool") or (action_id .. "_tool")
            protocolslots.inst:RemoveTag(tag)
        end
    end

    if protocolslots._kei_toughworker_old_tag ~= nil then
        if not protocolslots._kei_toughworker_old_tag then
            protocolslots.inst:RemoveTag("toughworker")
        end
        protocolslots._kei_toughworker_old_tag = nil
    end

    protocolslots._kei_added_worker = nil
    protocolslots._kei_worker_action_old_values = {}
    protocolslots._kei_tool_action_old_tags = {}
    protocolslots.analysis_tool_actions = {}
    protocolslots.analysis_tool_tough = nil
end

-- 将解析继承得到的工具动作写入角色
-- 只有在角色手上没有真实装备时，才会通过 worker 组件和 *_tool 标签模拟工具能力
local function SetToolActions(protocolslots, actions, tough)
    ClearToolActions(protocolslots)

    if HasHandEquipment(protocolslots.inst) then return end

    local has_actions = actions ~= nil and next(actions) ~= nil
    if not has_actions and not tough then return end

    if has_actions then
        if protocolslots.inst.components.worker == nil then
            protocolslots.inst:AddComponent("worker")
            protocolslots._kei_added_worker = true
        end

        local worker = protocolslots.inst.components.worker
        for action_id, effectiveness in pairs(actions) do
            local action = ACTIONS[action_id]
            if action ~= nil then
                protocolslots._kei_worker_action_old_values[action_id] = worker.actions[action]
                worker:SetAction(action, effectiveness or 1)

                local tag = action.id .. "_tool"
                protocolslots._kei_tool_action_old_tags[action_id] = protocolslots.inst:HasTag(tag)
                protocolslots.inst:AddTag(tag)
            end
        end
    end

    if tough then
        protocolslots._kei_toughworker_old_tag = protocolslots.inst:HasTag("toughworker")
        protocolslots.inst:AddTag("toughworker")
    end

    protocolslots.analysis_tool_actions = actions or {}
    protocolslots.analysis_tool_tough = tough or nil
end

-- 创建一份新的继承统计表，用于累计多个协议提供的手部解析结果
function HandAnalysisInheritance.NewStats()
    return {
        damage_bonus = 0,
        inherited_damage_total = 0,
        inherited_damage_count = 0,
        speed_mult = 1,
        planar_bonus = 0,
        tool_actions = {},
        tool_tough = false,
    }
end

-- 将单个协议的解析数据并入总统计
-- 包括伤害、移速、位面伤害，以及工具动作与 toughworker 能力
function HandAnalysisInheritance.AddStats(stats, data)
    stats.inherited_damage_total = stats.inherited_damage_total + GetAnalysisDamageBonus(data)
    stats.inherited_damage_count = stats.inherited_damage_count + 1
    stats.speed_mult = stats.speed_mult * (data.speed_mult or 1)
    stats.planar_bonus = stats.planar_bonus + (data.planar_bonus or 0)

    if data.tool_actions ~= nil then
        for action_id, effectiveness in pairs(data.tool_actions) do
            if ACTIONS[action_id] ~= nil then
                stats.tool_actions[action_id] = (stats.tool_actions[action_id] or 0) + (effectiveness or 1)
            end
        end
    end

    stats.tool_tough = stats.tool_tough or data.tool_tough == true
end

-- 把汇总后的解析继承结果应用到角色身上
-- 会统一处理伤害、位面伤害、移速和工具动作这几类能力
function HandAnalysisInheritance.Apply(protocolslots, stats)
    FinalizeDamage(stats)

    if protocolslots.inst.components.combat ~= nil then
        protocolslots.inst.components.combat.externaldamagemultipliers:RemoveModifier(protocolslots.inst, MODIFIER)
        SetDamageBonus(protocolslots, stats.damage_bonus)
    end

    if stats.planar_bonus > 0 then
        if protocolslots.inst.components.planardamage == nil then
            protocolslots.inst:AddComponent("planardamage")
        end
        protocolslots.inst.components.planardamage:AddBonus(protocolslots.inst, stats.planar_bonus, MODIFIER)
    elseif protocolslots.inst.components.planardamage ~= nil then
        protocolslots.inst.components.planardamage:RemoveBonus(protocolslots.inst, MODIFIER)
    end

    if protocolslots.inst.components.locomotor ~= nil then
        protocolslots.inst.components.locomotor:SetExternalSpeedMultiplier(protocolslots.inst, MODIFIER, stats.speed_mult)
    end

    SetToolActions(protocolslots, stats.tool_actions, stats.tool_tough)
end

-- 清空当前解析继承对角色施加的所有影响，恢复为未继承状态
function HandAnalysisInheritance.Clear(protocolslots)
    ClearToolActions(protocolslots)
    SetDamageBonus(protocolslots, 0)

    if protocolslots.inst.components.combat ~= nil then
        protocolslots.inst.components.combat.externaldamagemultipliers:RemoveModifier(protocolslots.inst, MODIFIER)
    end
    if protocolslots.inst.components.planardamage ~= nil then
        protocolslots.inst.components.planardamage:RemoveBonus(protocolslots.inst, MODIFIER)
    end
    if protocolslots.inst.components.locomotor ~= nil then
        protocolslots.inst.components.locomotor:RemoveExternalSpeedMultiplier(protocolslots.inst, MODIFIER)
    end
end

return HandAnalysisInheritance
