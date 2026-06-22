-- 独眼晶体巨鹿协议：攻击后生成时缓圈，使范围内非友方单位时间流速减半。

local MUTATEDDEERCLOPS_AURA_SLOW_KEY = "kei_mutateddeerclops_aura"
local MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG = "kei_mutateddeerclops_sg_slow"
local MUTATEDDEERCLOPS_AURA_FOLLOW_PERIOD = FRAMES
local MUTATEDDEERCLOPS_AURA_UPDATE_PERIOD = 0.25
local MUTATEDDEERCLOPS_AURA_MUST_TAGS = { "_combat", "_health" }
local MUTATEDDEERCLOPS_AURA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }

local MutatedDeerclopsEffect = {}

-- ---------- 辅助函数 ----------

local function IsValidTarget(owner, target)
    if target == nil
        or target == owner
        or not target:IsValid()
        or target:IsInLimbo()
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
    then
        return false
    end
    local combat = owner.components.combat
    return combat == nil or not combat:IsAlly(target)
end

local function AddStategraphSlowSource(target, source)
    target._kei_mutateddeerclops_sg_slow_sources = target._kei_mutateddeerclops_sg_slow_sources or {}
    target._kei_mutateddeerclops_sg_slow_sources[source] = true
    target:AddTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
end

local function RemoveStategraphSlowSource(target, source)
    local sources = target._kei_mutateddeerclops_sg_slow_sources
    if sources == nil then
        target:RemoveTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
        return true
    end
    sources[source] = nil
    if next(sources) == nil then
        target._kei_mutateddeerclops_sg_slow_sources = nil
        target:RemoveTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
        return true
    end
    return false
end

-- ---------- 减速管理 ----------

local function ApplySlow(slots, inst, target)
    if slots._kei_mutateddeerclops_slowed[target] ~= nil then
        return
    end

    local data = {}
    data.onremove = function()
        slots._kei_mutateddeerclops_slowed[target] = nil
    end
    inst:ListenForEvent("onremove", data.onremove, target)
    slots._kei_mutateddeerclops_slowed[target] = data

    AddStategraphSlowSource(target, inst)
    if target.components.locomotor ~= nil then
        target.components.locomotor:SetExternalSpeedMultiplier(
            inst, MUTATEDDEERCLOPS_AURA_SLOW_KEY, TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
    end
    if target.AnimState ~= nil then
        target.AnimState:SetDeltaTimeMultiplier(TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
    end
end

local function ClearSlow(slots, inst, target)
    local data = slots._kei_mutateddeerclops_slowed[target]
    if data == nil then
        return
    end

    slots._kei_mutateddeerclops_slowed[target] = nil
    inst:RemoveEventCallback("onremove", data.onremove, target)

    if target:IsValid() then
        local no_sources = RemoveStategraphSlowSource(target, inst)
        if target.components.locomotor ~= nil then
            target.components.locomotor:RemoveExternalSpeedMultiplier(inst, MUTATEDDEERCLOPS_AURA_SLOW_KEY)
        end
        if no_sources and target.AnimState ~= nil then
            target.AnimState:SetDeltaTimeMultiplier(1)
        end
    end
end

local function ClearAllSlows(slots, inst)
    local targets = {}
    for target in pairs(slots._kei_mutateddeerclops_slowed or {}) do
        table.insert(targets, target)
    end
    for _, target in ipairs(targets) do
        ClearSlow(slots, inst, target)
    end
end

-- ---------- 接口方法 ----------

function MutatedDeerclopsEffect.OnHitOther(slots, inst, data)
    local now = GetTime()
    if (slots._kei_mutateddeerclops_aura_ready_time or 0) > now then
        return
    end
    slots._kei_mutateddeerclops_aura_ready_time = now + (TUNING.KEI_MUTATEDDEERCLOPS_AURA_COOLDOWN or 3)

    local fx = slots._kei_mutateddeerclops_aura
    if fx ~= nil and fx:IsValid() then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        -- 刷新持续时间
        if slots._kei_mutateddeerclops_aura_remove_task ~= nil then
            slots._kei_mutateddeerclops_aura_remove_task:Cancel()
        end
        slots._kei_mutateddeerclops_aura_remove_task = inst:DoTaskInTime(
            TUNING.KEI_MUTATEDDEERCLOPS_AURA_DURATION or 5, function()
                MutatedDeerclopsEffect.Disable(slots, inst)
            end)
        -- 更新减速范围
        local x, y, z = fx.Transform:GetWorldPosition()
        local radius = TUNING.KEI_MUTATEDDEERCLOPS_AURA_RADIUS or 5.5
        local in_range = {}
        for _, target in ipairs(TheSim:FindEntities(x, y, z, radius,
            MUTATEDDEERCLOPS_AURA_MUST_TAGS, MUTATEDDEERCLOPS_AURA_EXCLUDE_TAGS)) do
            if IsValidTarget(inst, target) then
                in_range[target] = true
                ApplySlow(slots, inst, target)
            end
        end
        for target in pairs(slots._kei_mutateddeerclops_slowed or {}) do
            if not in_range[target] then
                ClearSlow(slots, inst, target)
            end
        end
        return
    end

    -- 新建光环
    MutatedDeerclopsEffect.Disable(slots, inst)
    fx = SpawnPrefab("kei_mutateddeerclops_aura_fx")
    if fx == nil then
        return
    end

    slots._kei_mutateddeerclops_aura = fx
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    if fx.GrowFX ~= nil then
        fx:GrowFX()
    end

    slots._kei_mutateddeerclops_aura_follow_task = inst:DoPeriodicTask(
        MUTATEDDEERCLOPS_AURA_FOLLOW_PERIOD, function()
            if fx:IsValid() then
                fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            end
        end)
    slots._kei_mutateddeerclops_aura_task = inst:DoPeriodicTask(
        MUTATEDDEERCLOPS_AURA_UPDATE_PERIOD, function()
            if not fx:IsValid() then
                MutatedDeerclopsEffect.Disable(slots, inst)
                return
            end
            local ax, ay, az = fx.Transform:GetWorldPosition()
            local radius = TUNING.KEI_MUTATEDDEERCLOPS_AURA_RADIUS or 5.5
            local in_range = {}
            for _, target in ipairs(TheSim:FindEntities(ax, ay, az, radius,
                MUTATEDDEERCLOPS_AURA_MUST_TAGS, MUTATEDDEERCLOPS_AURA_EXCLUDE_TAGS)) do
                if IsValidTarget(inst, target) then
                    in_range[target] = true
                    ApplySlow(slots, inst, target)
                end
            end
            for target in pairs(slots._kei_mutateddeerclops_slowed or {}) do
                if not in_range[target] then
                    ClearSlow(slots, inst, target)
                end
            end
        end, 0)
    slots._kei_mutateddeerclops_aura_remove_task = inst:DoTaskInTime(
        TUNING.KEI_MUTATEDDEERCLOPS_AURA_DURATION or 5, function()
            MutatedDeerclopsEffect.Disable(slots, inst)
        end)
end

function MutatedDeerclopsEffect.Disable(slots, inst)
    if slots._kei_mutateddeerclops_aura_task ~= nil then
        slots._kei_mutateddeerclops_aura_task:Cancel()
        slots._kei_mutateddeerclops_aura_task = nil
    end
    if slots._kei_mutateddeerclops_aura_follow_task ~= nil then
        slots._kei_mutateddeerclops_aura_follow_task:Cancel()
        slots._kei_mutateddeerclops_aura_follow_task = nil
    end
    if slots._kei_mutateddeerclops_aura_remove_task ~= nil then
        slots._kei_mutateddeerclops_aura_remove_task:Cancel()
        slots._kei_mutateddeerclops_aura_remove_task = nil
    end
    if slots._kei_mutateddeerclops_aura ~= nil then
        if slots._kei_mutateddeerclops_aura:IsValid() then
            slots._kei_mutateddeerclops_aura:KillFX()
        end
        slots._kei_mutateddeerclops_aura = nil
    end
    ClearAllSlows(slots, inst)
end

return MutatedDeerclopsEffect
