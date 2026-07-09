-- 龙蝇协议公共实现：过热免疫、火焰伤害免疫的 source 追踪

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local DragonflyCommon = {}

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function DragonflyCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "dragonfly")
end

function DragonflyCommon.EnableFireImmunity(slots, inst, source)
    source = source or "dragonfly"
    slots._kei_dragonfly_sources = slots._kei_dragonfly_sources or {}
    if slots._kei_dragonfly_sources[source] then
        return
    end

    if not BeastCommon.HasAnySource(slots._kei_dragonfly_sources) then
        inst:AddTag("kei_nooverheat")

        if inst.components.temperature ~= nil
            and inst.components.temperature:GetCurrent() > TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE
        then
            inst.components.temperature:SetTemperature(TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        end
        if inst.components.health ~= nil then
            inst.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
        end
    end

    slots._kei_dragonfly_sources[source] = true
end

function DragonflyCommon.DisableFireImmunity(slots, inst, source)
    source = source or "dragonfly"
    local sources = slots._kei_dragonfly_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if BeastCommon.HasAnySource(sources) then
        return
    end

    inst:RemoveTag("kei_nooverheat")

    if inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
    end

    slots._kei_dragonfly_sources = nil
end

return DragonflyCommon
