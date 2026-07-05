-- 蟾蜍协议公共实现：催眠免疫的 source 追踪

local ToadstoolCommon = {}

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

function ToadstoolCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.toadstool == true
end

function ToadstoolCommon.EnableSleepImmunity(slots, inst, source)
    source = source or "toadstool"
    slots._kei_toadstool_sleep_sources = slots._kei_toadstool_sleep_sources or {}
    if slots._kei_toadstool_sleep_sources[source] then
        return
    end

    if not HasAnySource(slots._kei_toadstool_sleep_sources) then
        local grogginess = inst.components.grogginess
        if grogginess ~= nil then
            grogginess:ResetGrogginess()
            grogginess:AddImmunitySource(inst)
            if grogginess:IsKnockedOut() then
                grogginess:ComeTo()
            end
        end

        local sleeper = inst.components.sleeper
        if sleeper ~= nil then
            sleeper.sleepiness = 0
            if sleeper:IsAsleep() then
                sleeper:WakeUp()
            end
        end
    end

    slots._kei_toadstool_sleep_sources[source] = true
end

function ToadstoolCommon.DisableSleepImmunity(slots, inst, source)
    source = source or "toadstool"
    local sources = slots._kei_toadstool_sleep_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if HasAnySource(sources) then
        return
    end

    if inst.components.grogginess ~= nil then
        inst.components.grogginess:RemoveImmunitySource(inst)
    end

    slots._kei_toadstool_sleep_sources = nil
end

return ToadstoolCommon