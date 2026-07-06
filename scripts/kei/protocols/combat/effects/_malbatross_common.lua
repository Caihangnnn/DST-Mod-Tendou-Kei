-- 邪天翁协议公共实现：水面涨潮湿度，高级水面增伤/加速。

local MalbatrossCommon = {}
local WATER_BONUS_MODIFIER = "kei_malbatross_ocean"

local function HasAnySource(sources)
    if sources ~= nil then
        for _ in pairs(sources) do
            return true
        end
    end
    return false
end

local function HasAdvancedSource(slots)
    local sources = slots ~= nil and slots._kei_malbatross_sources or nil
    if sources ~= nil then
        for _, data in pairs(sources) do
            if data.advanced == true then
                return true
            end
        end
    end
    return false
end

local function IsOnOcean(inst)
    if TheWorld:HasTag("cave") or inst:HasTag("playerghost") then
        return false
    end

    local map = TheWorld.Map
    if map == nil or map.IsOceanAtPoint == nil then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    return map:IsOceanAtPoint(x, y, z)
end

local function AddOceanMoisture(inst)
    local moisture = inst.components.moisture
    if moisture == nil then
        return
    end

    if moisture:GetMoisture() >= moisture:GetMaxMoisture() then
        return
    end

    local amount = TUNING.KEI_MALBATROSS_OCEAN_MOISTURE_PER_SECOND or 1
    moisture:DoDelta(amount)
end

local function ApplyWaterBonuses(slots, inst, enabled)
    if enabled then
        if slots._kei_malbatross_water_bonus_active then
            return
        end

        local mult = TUNING.KEI_MALBATROSS_OCEAN_DAMAGE_MULT or 1.5
        if inst.components.combat ~= nil then
            inst.components.combat.externaldamagemultipliers:SetModifier(inst, mult, WATER_BONUS_MODIFIER)
        end
        if inst.components.locomotor ~= nil then
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, WATER_BONUS_MODIFIER, TUNING.KEI_MALBATROSS_OCEAN_SPEED_MULT or 1.5)
        end
        slots._kei_malbatross_water_bonus_active = true
    elseif slots._kei_malbatross_water_bonus_active then
        if inst.components.combat ~= nil then
            inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, WATER_BONUS_MODIFIER)
        end
        if inst.components.locomotor ~= nil then
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, WATER_BONUS_MODIFIER)
        end
        slots._kei_malbatross_water_bonus_active = nil
    end
end

function MalbatrossCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.malbatross == true
end

function MalbatrossCommon.Update(slots, inst)
    if slots == nil or inst == nil or not HasAnySource(slots._kei_malbatross_sources) then
        return
    end

    local on_ocean = IsOnOcean(inst)
    ApplyWaterBonuses(slots, inst, on_ocean and HasAdvancedSource(slots))

    if on_ocean then
        local now = GetTime()
        if slots._kei_malbatross_next_moisture_time == nil or now >= slots._kei_malbatross_next_moisture_time then
            AddOceanMoisture(inst)
            slots._kei_malbatross_next_moisture_time = now + (TUNING.KEI_MALBATROSS_OCEAN_MOISTURE_INTERVAL or 1)
        end
    end
end

function MalbatrossCommon.Enable(slots, inst, source, advanced)
    source = source or "malbatross"
    slots._kei_malbatross_sources = slots._kei_malbatross_sources or {}
    slots._kei_malbatross_sources[source] = { advanced = advanced == true }

    if slots._kei_malbatross_task == nil then
        slots._kei_malbatross_task = inst:DoPeriodicTask(TUNING.KEI_MALBATROSS_OCEAN_CHECK_PERIOD or 0.25, function()
            MalbatrossCommon.Update(slots, inst)
        end)
    end
    MalbatrossCommon.Update(slots, inst)
end

function MalbatrossCommon.Disable(slots, inst, source)
    source = source or "malbatross"
    if slots._kei_malbatross_sources ~= nil then
        slots._kei_malbatross_sources[source] = nil
    end

    if HasAnySource(slots._kei_malbatross_sources) then
        MalbatrossCommon.Update(slots, inst)
        return
    end

    if slots._kei_malbatross_task ~= nil then
        slots._kei_malbatross_task:Cancel()
        slots._kei_malbatross_task = nil
    end
    slots._kei_malbatross_sources = nil
    slots._kei_malbatross_next_moisture_time = nil
    ApplyWaterBonuses(slots, inst, false)
end

return MalbatrossCommon