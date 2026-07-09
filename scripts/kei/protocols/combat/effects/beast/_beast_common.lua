-- 巨兽战斗协议通用工具：集中处理协议状态、冷却和目标判定。

local BeastCommon = {}

-- 判断指定战斗协议当前是否处于激活状态。
function BeastCommon.HasProtocol(slots, protocol)
    if slots == nil or protocol == nil then
        return false
    end
    if slots.HasCombatProtocol ~= nil then
        return slots:HasCombatProtocol(protocol)
    end
    return slots.active_combat ~= nil and slots.active_combat[protocol] == true
end

-- 判断指定冷却键是否已经就绪。
function BeastCommon.CooldownReady(owner, key)
    return owner ~= nil
        and key ~= nil
        and (owner[key] == nil or GetTime() >= owner[key])
end

-- 写入指定冷却键的下一次可触发时间。
function BeastCommon.StartCooldown(owner, key, cooldown)
    if owner ~= nil and key ~= nil then
        owner[key] = GetTime() + (cooldown or 0)
    end
end

-- 判断来源表中是否还存在任意一个有效来源。
function BeastCommon.HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

-- 判断目标是否仍是可见且未死亡的生命体。
function BeastCommon.IsVisibleLivingTarget(target)
    return target ~= nil
        and target:IsValid()
        and target.entity ~= nil
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

-- 判断目标是否可由 owner 的 combat 组件合法攻击。
function BeastCommon.IsValidCombatTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and BeastCommon.IsVisibleLivingTarget(target)
        and target.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

return BeastCommon
