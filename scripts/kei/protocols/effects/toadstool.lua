-- 蟾蜍协议：催眠免疫（grogginess + sleeper）。

local ToadstoolEffect = {}

function ToadstoolEffect.Enable(slots, inst)
    if slots._kei_toadstool_enabled then
        return
    end

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

    slots._kei_toadstool_enabled = true
end

function ToadstoolEffect.Disable(slots, inst)
    if not slots._kei_toadstool_enabled then
        return
    end

    if inst.components.grogginess ~= nil then
        inst.components.grogginess:RemoveImmunitySource(inst)
    end

    slots._kei_toadstool_enabled = nil
end

function ToadstoolEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    local now = GetTime()
    if (slots._kei_toadstool_sleepbomb_ready_time or 0) > now
        or math.random() >= (TUNING.KEI_TOADSTOOL_SLEEPBOMB_CHANCE or 0.15)
        or target == nil
        or not target:IsValid()
        or target:IsInLimbo()
    then
        return
    end

    local sleepbomb = SpawnPrefab("sleepbomb")
    if sleepbomb == nil or sleepbomb.components.complexprojectile == nil then
        if sleepbomb ~= nil then
            sleepbomb:Remove()
        end
        return
    end

    sleepbomb.persists = false
    sleepbomb.Transform:SetPosition(inst.Transform:GetWorldPosition())
    if inst.components.combat ~= nil and inst.components.combat:IsValidTarget(target) then
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
        sleepbomb.components.complexprojectile:Launch(target:GetPosition(), inst, sleepbomb)
        slots._kei_toadstool_sleepbomb_ready_time = now + (TUNING.KEI_TOADSTOOL_SLEEPBOMB_COOLDOWN or 0.5)
    else
        sleepbomb:Remove()
    end
end

return ToadstoolEffect
