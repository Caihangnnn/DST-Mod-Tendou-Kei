-- 龙蝇协议公共实现：过热免疫、火焰伤害免疫的 source 追踪

local DragonflyCommon = {}

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

function DragonflyCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.dragonfly == true
end

function DragonflyCommon.EnableFireImmunity(slots, inst, source)
    source = source or "dragonfly"
    slots._kei_dragonfly_sources = slots._kei_dragonfly_sources or {}
    if slots._kei_dragonfly_sources[source] then
        return
    end

    if not HasAnySource(slots._kei_dragonfly_sources) then
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

    if HasAnySource(sources) then
        return
    end

    inst:RemoveTag("kei_nooverheat")

    if inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
    end

    slots._kei_dragonfly_sources = nil
end

return DragonflyCommon