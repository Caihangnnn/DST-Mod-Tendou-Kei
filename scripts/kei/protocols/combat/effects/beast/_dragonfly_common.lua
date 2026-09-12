-- 龙蝇协议公共实现：过热免疫、火焰伤害免疫的 source 追踪

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local DragonflyCommon = {}
local FIRE_IMMUNITY_KEY = "kei_dragonfly_fire_immunity"

local function ClampHotTemperature(inst)
    local temperature = inst ~= nil
        and inst.components ~= nil
        and inst.components.temperature
        or nil
    local max_temperature = tonumber(TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        or (temperature ~= nil and temperature.overheattemp or TUNING.OVERHEAT_TEMP)
    if temperature ~= nil and temperature:GetCurrent() > max_temperature then
        temperature:SetTemperature(max_temperature)
    end
end

local function StopTemperatureCorrection(slots)
    if slots ~= nil and slots._kei_dragonfly_temperature_task ~= nil then
        slots._kei_dragonfly_temperature_task:Cancel()
        slots._kei_dragonfly_temperature_task = nil
    end
end

local function StartTemperatureCorrection(slots, inst)
    if slots == nil or inst == nil or slots._kei_dragonfly_temperature_task ~= nil then
        return
    end

    slots._kei_dragonfly_temperature_task = inst:DoPeriodicTask(
        TUNING.KEI_BEAST_TEMPERATURE_CHECK_PERIOD or 0.1,
        function()
            if not DragonflyCommon.HasOverheatImmunity(slots) then
                StopTemperatureCorrection(slots)
                return
            end
            ClampHotTemperature(inst)
        end
    )
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function DragonflyCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "dragonfly")
end

-- 查询龙蝇协议当前是否仍提供过热免疫。
-- 温度 Hook 直接读取协议槽状态，不依赖可被外部 Buff 清理的角色标签。
function DragonflyCommon.HasOverheatImmunity(slots)
    return slots ~= nil
        and BeastCommon.HasAnySource(slots._kei_dragonfly_sources)
end

function DragonflyCommon.EnableFireImmunity(slots, inst, source)
    source = source or "dragonfly"
    slots._kei_dragonfly_sources = slots._kei_dragonfly_sources or {}
    local sources = slots._kei_dragonfly_sources
    if sources[source] then
        StartTemperatureCorrection(slots, inst)
        ClampHotTemperature(inst)
        if inst.components.health ~= nil then
            inst.components.health.externalfiredamagemultipliers:SetModifier(
                inst,
                0,
                FIRE_IMMUNITY_KEY
            )
        end
        return
    end

    local had_source = BeastCommon.HasAnySource(sources)
    -- 先登记来源，再校正温度，使本次 SetTemperature 也能经过动态免疫判断。
    BeastCommon.AddSource(sources, source)
    StartTemperatureCorrection(slots, inst)
    if not had_source then
        ClampHotTemperature(inst)
        if inst.components.health ~= nil then
            inst.components.health.externalfiredamagemultipliers:SetModifier(
                inst,
                0,
                FIRE_IMMUNITY_KEY
            )
        end
    elseif inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:SetModifier(
            inst,
            0,
            FIRE_IMMUNITY_KEY
        )
    end
end

function DragonflyCommon.DisableFireImmunity(slots, inst, source)
    source = source or "dragonfly"
    local sources = slots._kei_dragonfly_sources
    if sources ~= nil and BeastCommon.RemoveSource(sources, source) then
        return
    end

    if inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:RemoveModifier(
            inst,
            FIRE_IMMUNITY_KEY
        )
    end

    slots._kei_dragonfly_sources = nil
    StopTemperatureCorrection(slots)
end

return DragonflyCommon
