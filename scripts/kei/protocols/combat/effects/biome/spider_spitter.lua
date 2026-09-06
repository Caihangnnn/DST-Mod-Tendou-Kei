-- 喷吐蜘蛛协议：伤害敌方单位时降低目标 50% 移速。

local SpiderSpitterEffect = {}
local SLOW_MODIFIER = 'kei_spider_spitter_hit_slow'
local SlowSources = require('kei/slow_sources')

local function IsValidTarget(owner, target)
    if target == nil
        or target == owner
        or not target:IsValid()
        or target:IsInLimbo()
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
        or target.components.locomotor == nil
    then
        return false
    end

    local combat = owner.components.combat
    return combat == nil or not combat:IsAlly(target)
end

local function ClearSlow(slots, inst, target)
    local data = slots._kei_spider_spitter_slowed ~= nil and slots._kei_spider_spitter_slowed[target] or nil
    if data == nil then
        return
    end

    slots._kei_spider_spitter_slowed[target] = nil
    if data.task ~= nil then
        data.task:Cancel()
    end
    inst:RemoveEventCallback('onremove', data.onremove, target)
    inst:RemoveEventCallback('death', data.ondeath, target)

    if target:IsValid() and target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(inst, SLOW_MODIFIER)
    end
end

-- 对单个目标施加减速；重复命中时刷新持续时间。
local function ApplySlow(slots, inst, target)
    slots._kei_spider_spitter_slowed = slots._kei_spider_spitter_slowed or {}

    local old = slots._kei_spider_spitter_slowed[target]
    if old ~= nil then
        if old.task ~= nil then
            old.task:Cancel()
        end
        inst:RemoveEventCallback('onremove', old.onremove, target)
        inst:RemoveEventCallback('death', old.ondeath, target)
    end

    if not SlowSources.TryApply(
        target,
        SLOW_MODIFIER,
        inst,
        TUNING.KEI_SPIDER_SPITTER_SLOW_MULT or 0.5,
        nil,
        true
    ) then
        return
    end

    local data = {}
    data.onremove = function()
        slots._kei_spider_spitter_slowed[target] = nil
    end
    data.ondeath = function()
        ClearSlow(slots, inst, target)
    end
    data.task = inst:DoTaskInTime(TUNING.KEI_SPIDER_SPITTER_SLOW_DURATION or 10, function()
        ClearSlow(slots, inst, target)
    end)

    slots._kei_spider_spitter_slowed[target] = data
    inst:ListenForEvent('onremove', data.onremove, target)
    inst:ListenForEvent('death', data.ondeath, target)
end

local function ClearAllSlows(slots, inst)
    local targets = {}
    for target in pairs(slots._kei_spider_spitter_slowed or {}) do
        table.insert(targets, target)
    end
    for _, target in ipairs(targets) do
        ClearSlow(slots, inst, target)
    end
end

-- 命中敌方单位且造成伤害时，降低目标移速。
function SpiderSpitterEffect.OnHitOther(slots, inst, data)
    local target = data ~= nil and data.target or nil
    if not IsValidTarget(inst, target) then
        return
    end
    if data ~= nil and data.damage ~= nil and data.damage <= 0 then
        return
    end

    ApplySlow(slots, inst, target)
end

-- 协议失效时清理所有由本协议施加的目标减速。
function SpiderSpitterEffect.Disable(slots, inst)
    ClearAllSlows(slots, inst)
end

return SpiderSpitterEffect
