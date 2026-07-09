-- 蟾蜍高级协议：免疫催眠并攻击概率生成睡袋效果。
local ToadstoolCommon = require("kei/protocols/combat/effects/beast/_toadstool_common")

local ToadstoolEffect = {}
local SOURCE = "toadstool"

-- 启用协议效果，并注册该协议提供的持续能力。
function ToadstoolEffect.Enable(slots, inst)
    ToadstoolCommon.EnableSleepImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function ToadstoolEffect.Disable(slots, inst)
    ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
end

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
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
