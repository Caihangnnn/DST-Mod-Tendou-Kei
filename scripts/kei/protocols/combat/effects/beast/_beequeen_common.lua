-- 蜂后协议公共实现：恐慌目标

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local BeequeenCommon = {}

-- 判断目标是否可以被蜂后尖啸恐慌。
function BeequeenCommon.IsValidScareTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and target ~= nil
        and target:IsValid()
        and target ~= owner
        and target.entity:IsVisible()
        and not target:IsInLimbo()
        and not target:HasTag("player")
        and not target:HasTag("playerghost")
        and not target:HasTag("epic")
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

-- 对目标施加恐慌，并打断其对 Kei 的仇恨目标。
function BeequeenCommon.ScareTarget(owner, target, duration)
    if not BeequeenCommon.IsValidScareTarget(owner, target) then
        return
    end

    target:PushEvent("epicscare", { scarer = owner, duration = duration })

    if target.components.hauntable ~= nil and target.components.hauntable.panicable then
        target.components.hauntable:Panic(duration)
    end

    if target.components.combat ~= nil and target.components.combat:TargetIs(owner) then
        target.components.combat:SetTarget(nil)
    end
end

local function GetCooldownKey(key)
    return key or "_kei_beequeen_panic_ready_time"
end

-- 判断该协议的冷却是否已经结束。
function BeequeenCommon.CooldownReady(slots, key)
    return BeastCommon.CooldownReady(slots, GetCooldownKey(key))
end

-- 写入该协议的下一次可触发时间。
function BeequeenCommon.StartCooldown(slots, cooldown, key)
    BeastCommon.StartCooldown(slots, GetCooldownKey(key), cooldown or TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN or 3)
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function BeequeenCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "beequeen")
end

return BeequeenCommon
