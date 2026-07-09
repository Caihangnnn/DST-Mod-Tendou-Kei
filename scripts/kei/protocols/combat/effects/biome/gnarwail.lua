-- 一角鲸协议（gnarwail）：攻击时概率触发水波冲击。

local GnarwailEffect = {}

local DAMAGE_MUST_TAGS = { '_combat', '_health' }
local EFFECT_CANT_TAGS = { 'INLIMBO', 'FX', 'NOCLICK', 'DECOR' }
local COOLDOWN_KEY = '_kei_gnarwail_next_wave_time'
local TEMP_WET_TAG = 'kei_gnarwail_wet'
local TEMP_WET_TASK = '_kei_gnarwail_wet_task'

local function InstallTemporaryWetHooks()
    if EntityScript == nil or EntityScript._kei_gnarwail_wet_hooks_installed then
        return
    end
    EntityScript._kei_gnarwail_wet_hooks_installed = true

    local old_get_is_wet = EntityScript.GetIsWet
    function EntityScript:GetIsWet()
        if self:HasTag(TEMP_WET_TAG)
            and self.components.moisture == nil
            and not self:HasTag('moistureimmunity')
        then
            local replica = self.replica ~= nil and (self.replica.inventoryitem or self.replica.moisture) or nil
            if replica == nil then
                return true
            end
        end
        return old_get_is_wet(self)
    end

    local old_get_wet_multiplier = EntityScript.GetWetMultiplier
    function EntityScript:GetWetMultiplier()
        if self:HasTag(TEMP_WET_TAG)
            and self.components.moisture == nil
            and not self:HasTag('moistureimmunity')
        then
            local replica = self.replica ~= nil and (self.replica.inventoryitem or self.replica.moisture) or nil
            if replica == nil then
                return 1
            end
        end
        return old_get_wet_multiplier(self)
    end
end

InstallTemporaryWetHooks()

local function IsLivingTarget(target)
    return target ~= nil
        and target:IsValid()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

local function IsEnemy(owner, target)
    if owner == nil
        or target == nil
        or target == owner
        or owner.components.combat == nil
        or target.components.combat == nil
    then
        return false
    end

    return owner.components.combat:IsValidTarget(target)
        and not owner.components.combat:IsAlly(target)
end

local function AddMoisture(target, amount)
    if target == nil or amount <= 0 then
        return
    end

    if DoDeltaMoistureToEntity ~= nil then
        DoDeltaMoistureToEntity(target, amount)
    elseif target.components.moisture ~= nil then
        local waterproofness = target.components.moisture:GetWaterproofness()
        if waterproofness > 1 then
            waterproofness = 1
        end
        target.components.moisture:DoDelta(amount * (1 - waterproofness))
    elseif target.components.inventoryitem ~= nil then
        target.components.inventoryitem:AddMoisture(amount)
    end
end

local function AddPlayerMoisture(target, amount)
    if target == nil or amount <= 0 or target.components.moisture == nil then
        return
    end
    target.components.moisture:DoDelta(amount, true)
end

local function ApplyTemporaryWetTag(target)
    if target == nil or not target:IsValid() or target:HasTag('moistureimmunity') then
        return
    end

    if target[TEMP_WET_TASK] ~= nil then
        target[TEMP_WET_TASK]:Cancel()
        target[TEMP_WET_TASK] = nil
    end

    target:AddTag(TEMP_WET_TAG)
    target[TEMP_WET_TASK] = target:DoTaskInTime(TUNING.KEI_GNARWAIL_WET_DURATION or 5, function(inst)
        inst:RemoveTag(TEMP_WET_TAG)
        inst[TEMP_WET_TASK] = nil
    end)
end

-- 参考 mygo 的“壱雫空”：有 moisture 的目标直接加湿，没有 moisture 的目标短时视为潮湿。
local function WetEnemy(target, amount)
    if target == nil or amount <= 0 then
        return
    end

    if target.components.moisture ~= nil then
        local waterproofness = target.components.moisture:GetWaterproofness()
        if waterproofness > 1 then
            waterproofness = 1
        end
        target.components.moisture:DoDelta(amount * (1 - waterproofness))
    elseif target.components.inventoryitem ~= nil then
        target.components.inventoryitem:AddMoisture(amount)
    else
        ApplyTemporaryWetTag(target)
    end
end

-- 参考刺耳三叉戟右键施法，在范围边缘生成水波视觉。
local function SpawnWaterWaveFx(x, y, z, radius)
    local splash = SpawnPrefab('waterballoon_splash')
    if splash ~= nil then
        splash.Transform:SetPosition(x, y, z)
    end

    local fx_radius = radius * 0.65
    local angle = GetRandomWithVariance(-45, 20)
    for _ = 1, 4 do
        angle = angle + 90
        local rad = angle * DEGREES
        local fx = SpawnPrefab('crab_king_waterspout')
        if fx ~= nil then
            fx.Transform:SetPosition(x + fx_radius * math.cos(rad), y, z - fx_radius * math.sin(rad))
        end
    end
end

local function IsCooldownReady(slots)
    return slots == nil
        or slots[COOLDOWN_KEY] == nil
        or GetTime() >= slots[COOLDOWN_KEY]
end

local function StartCooldown(slots)
    if slots ~= nil then
        slots[COOLDOWN_KEY] = GetTime() + TUNING.KEI_GNARWAIL_WAVE_COOLDOWN
    end
end

local function ApplyWaterImpact(inst, target)
    local x, y, z = target.Transform:GetWorldPosition()
    local radius = TUNING.KEI_GNARWAIL_WAVE_RADIUS
    local damage = TUNING.KEI_GNARWAIL_WAVE_DAMAGE
    local wetness = TUNING.KEI_GNARWAIL_WAVE_WETNESS
    SpawnWaterWaveFx(x, y, z, radius)

    for _, entity in ipairs(TheSim:FindEntities(x, y, z, radius, nil, EFFECT_CANT_TAGS)) do
        if entity:HasTag('player') and not entity:HasTag('playerghost') then
            AddPlayerMoisture(entity, wetness)
        elseif IsLivingTarget(entity) and IsEnemy(inst, entity) then
            WetEnemy(entity, wetness)
        else
            AddMoisture(entity, wetness)
        end
    end

    for _, entity in ipairs(TheSim:FindEntities(x, y, z, radius, DAMAGE_MUST_TAGS, EFFECT_CANT_TAGS)) do
        if IsLivingTarget(entity) and IsEnemy(inst, entity) then
            entity.components.combat:GetAttacked(inst, damage)
        end
    end

    if TheWorld ~= nil and TheWorld.components.farming_manager ~= nil then
        TheWorld.components.farming_manager:AddSoilMoistureAtPoint(x, y, z, wetness)
    end
end

-- 攻击命中时有概率触发水波冲击，成功触发后进入固定内置冷却。
function GnarwailEffect.OnHitOther(slots, inst, data)
    local target = data ~= nil and data.target or nil
    if not IsLivingTarget(target)
        or not IsCooldownReady(slots)
        or math.random() >= TUNING.KEI_GNARWAIL_WAVE_CHANCE
    then
        return
    end

    StartCooldown(slots)
    ApplyWaterImpact(inst, target)
end

-- 协议失效时清理内部触发冷却。
function GnarwailEffect.Disable(slots, inst)
    if slots ~= nil then
        slots[COOLDOWN_KEY] = nil
    end
end

return GnarwailEffect