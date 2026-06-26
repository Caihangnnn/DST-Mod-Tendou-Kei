-- 独眼巨鹿协议：冰冻免疫 + 温度下限（免疫过冷）。

local DeerclopsEffect = {}

function DeerclopsEffect.Enable(slots, inst)
    if slots._kei_freeze_immune then
        return
    end

    inst:AddTag("kei_nofreezing")

    local freezable = inst.components.freezable
    slots._kei_had_freezable = freezable ~= nil
    if freezable ~= nil then
        if freezable:IsFrozen() then
            freezable:Unfreeze()
        else
            freezable:Reset()
        end
        inst:RemoveComponent("freezable")
    end
    slots._kei_freeze_immune = true

    if inst.components.temperature ~= nil
        and inst.components.temperature:GetCurrent() < TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE
    then
        inst.components.temperature:SetTemperature(TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE)
    end
end

function DeerclopsEffect.Disable(slots, inst)
    inst:RemoveTag("kei_nofreezing")

    if not slots._kei_freeze_immune then
        return
    end

    if slots._kei_had_freezable
        and inst.components.freezable == nil
        and not inst:HasTag("playerghost")
    then
        MakeLargeFreezableCharacter(inst, "torso")
        inst.components.freezable:SetResistance(4)
        inst.components.freezable:SetDefaultWearOffTime(TUNING.PLAYER_FREEZE_WEAR_OFF_TIME)
    end
    slots._kei_had_freezable = nil
    slots._kei_freeze_immune = nil
end

function DeerclopsEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    if target ~= nil and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(1)
        target.components.freezable:SpawnShatterFX()
    end
end

return DeerclopsEffect
