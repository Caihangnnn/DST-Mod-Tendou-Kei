-- 蜂后协议公共实现：恐慌目标

local BeequeenCommon = {}

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

function BeequeenCommon.CooldownReady(slots, key)
    if slots == nil then
        return false
    end

    local now = GetTime()
    local cooldown_key = GetCooldownKey(key)
    return slots[cooldown_key] == nil or now >= slots[cooldown_key]
end

function BeequeenCommon.StartCooldown(slots, cooldown, key)
    if slots == nil then
        return
    end

    local cooldown_key = GetCooldownKey(key)
    slots[cooldown_key] = GetTime() + (cooldown or TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN or 3)
end

function BeequeenCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.beequeen == true
end

return BeequeenCommon