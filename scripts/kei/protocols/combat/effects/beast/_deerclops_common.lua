-- 独眼巨鹿协议公共实现：冰冻免疫与攻击附加冰冻值。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local DeerclopsCommon = {}

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function DeerclopsCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "deerclops")
end

-- 参考 fumo 的实现：10℃是“开始过冷”的安全边界，不把体温压在边界
-- 本身，而是至少保持在边界以上 1℃，避免其它温度修正造成临界值抖动。
function DeerclopsCommon.GetSafeTemperature(inst)
    local temperature = inst ~= nil
        and inst.components ~= nil
        and inst.components.temperature
        or nil
    if temperature == nil then
        return nil
    end

    local min_temperature = tonumber(temperature.mintemp) or TUNING.MIN_ENTITY_TEMP
    local cold_boundary = math.max(
        min_temperature,
        tonumber(TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE) or 10
    )
    local safe_temperature = cold_boundary + 1
    local max_temperature = tonumber(temperature.maxtemp) or TUNING.MAX_ENTITY_TEMP
    return math.min(safe_temperature, max_temperature)
end

local function ClampColdTemperature(inst)
    local temperature = inst ~= nil
        and inst.components ~= nil
        and inst.components.temperature
        or nil
    local safe_temperature = DeerclopsCommon.GetSafeTemperature(inst)
    if temperature ~= nil
        and safe_temperature ~= nil
        and temperature:GetCurrent() < safe_temperature
    then
        temperature:SetTemperature(safe_temperature)
    end
end

local function StopTemperatureCorrection(slots)
    if slots ~= nil and slots._kei_deerclops_temperature_task ~= nil then
        slots._kei_deerclops_temperature_task:Cancel()
        slots._kei_deerclops_temperature_task = nil
    end
end

local function StartTemperatureCorrection(slots, inst)
    if slots == nil or inst == nil or slots._kei_deerclops_temperature_task ~= nil then
        return
    end

    -- SetTemperature 的拦截可以覆盖原版路径；这个周期校正用于兜底处理
    -- 直接写 temperature.current、缓存旧方法等绕过组件入口的其它 MOD。
    slots._kei_deerclops_temperature_task = inst:DoPeriodicTask(
        TUNING.KEI_BEAST_TEMPERATURE_CHECK_PERIOD or 0.1,
        function()
            if not DeerclopsCommon.HasFreezeImmunity(slots) then
                StopTemperatureCorrection(slots)
                return
            end
            ClampColdTemperature(inst)
        end
    )
end

-- 查询独眼巨鹿协议当前是否仍提供冰冻/过冷免疫。
-- 免疫状态由协议槽组件持有，不依赖角色标签，避免被外部限时 Buff 清理。
function DeerclopsCommon.HasFreezeImmunity(slots)
    return slots ~= nil
        and BeastCommon.HasAnySource(slots._kei_deerclops_freeze_sources)
end

-- 添加冰冻免疫来源，并清理当前的冻结状态。
function DeerclopsCommon.EnableFreezeImmunity(slots, inst, source)
    source = source or "deerclops"
    slots._kei_deerclops_freeze_sources = slots._kei_deerclops_freeze_sources or {}
    local sources = slots._kei_deerclops_freeze_sources
    if sources[source] then
        StartTemperatureCorrection(slots, inst)
        ClampColdTemperature(inst)
        return
    end

    local had_source = BeastCommon.HasAnySource(sources)
    if not had_source then
        local freezable = inst.components.freezable
        if freezable ~= nil then
            if freezable:IsFrozen() then
                freezable:Unfreeze()
            else
                freezable:Reset()
            end
        end
    end

    BeastCommon.AddSource(sources, source)
    StartTemperatureCorrection(slots, inst)
    ClampColdTemperature(inst)
end

-- 移除冰冻免疫来源；freezable 组件始终保留，免疫查询恢复为无来源状态。
function DeerclopsCommon.DisableFreezeImmunity(slots, inst, source)
    source = source or "deerclops"
    local sources = slots._kei_deerclops_freeze_sources
    if sources ~= nil and BeastCommon.RemoveSource(sources, source) then
        return
    end

    slots._kei_deerclops_freeze_sources = nil
    StopTemperatureCorrection(slots)
end

-- 在攻击命中时向目标附加冰冻值。
function DeerclopsCommon.AddColdnessOnHit(data, coldness)
    local target = data ~= nil and data.target or nil
    if target ~= nil and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(coldness or 1)
        target.components.freezable:SpawnShatterFX()
    end
end

return DeerclopsCommon
