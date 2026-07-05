-- 独眼巨鹿协议功能实现

local DeerclopsCommon = {}

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

local function ClampColdTemperature(inst)
    if inst.components.temperature ~= nil
        and inst.components.temperature:GetCurrent() < TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE
    then
        inst.components.temperature:SetTemperature(TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE)
    end
end

function DeerclopsCommon.EnableFreezeImmunity(slots, inst, source)
    source = source or "deerclops"
    slots._kei_deerclops_freeze_sources = slots._kei_deerclops_freeze_sources or {}
    if slots._kei_deerclops_freeze_sources[source] then
        ClampColdTemperature(inst)
        return
    end

    if not HasAnySource(slots._kei_deerclops_freeze_sources) then
        inst:AddTag("kei_nofreezing")

        local freezable = inst.components.freezable
        slots._kei_deerclops_had_freezable = freezable ~= nil
        if freezable ~= nil then
            if freezable:IsFrozen() then
                freezable:Unfreeze()
            else
                freezable:Reset()
            end
            inst:RemoveComponent("freezable")
        end
    end

    slots._kei_deerclops_freeze_sources[source] = true
    ClampColdTemperature(inst)
end

function DeerclopsCommon.DisableFreezeImmunity(slots, inst, source)
    source = source or "deerclops"
    local sources = slots._kei_deerclops_freeze_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if HasAnySource(sources) then
        return
    end

    inst:RemoveTag("kei_nofreezing")

    if slots._kei_deerclops_had_freezable
        and inst.components.freezable == nil
        and not inst:HasTag("playerghost")
    then
        MakeLargeFreezableCharacter(inst, "torso")
        inst.components.freezable:SetResistance(4)
        inst.components.freezable:SetDefaultWearOffTime(TUNING.PLAYER_FREEZE_WEAR_OFF_TIME)
    end

    slots._kei_deerclops_had_freezable = nil
    slots._kei_deerclops_freeze_sources = nil
    slots._kei_had_freezable = nil
    slots._kei_freeze_immune = nil
end

function DeerclopsCommon.AddColdnessOnHit(data, coldness)
    local target = data ~= nil and data.target or nil
    if target ~= nil and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(coldness or 1)
        target.components.freezable:SpawnShatterFX()
    end
end

return DeerclopsCommon