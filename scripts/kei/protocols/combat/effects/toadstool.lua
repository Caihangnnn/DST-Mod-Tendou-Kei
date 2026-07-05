local ToadstoolCommon = require("kei/protocols/combat/effects/_toadstool_common")

local ToadstoolEffect = {}
local SOURCE = "toadstool"

function ToadstoolEffect.Enable(slots, inst)
    ToadstoolCommon.EnableSleepImmunity(slots, inst, SOURCE)
end

function ToadstoolEffect.Disable(slots, inst)
    ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
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