-- 破碎蜘蛛协议：受到攻击时对攻击者造成固定反伤。

local SpiderShatteredEffect = {}

local function IsValidAttacker(owner, attacker)
    if attacker == nil
        or attacker == owner
        or not attacker:IsValid()
        or attacker:IsInLimbo()
        or attacker.components.health == nil
        or attacker.components.health:IsDead()
        or attacker.components.combat == nil
    then
        return false
    end

    local combat = owner.components.combat
    return combat == nil or not combat:IsAlly(attacker)
end

-- Kei 受到攻击时，对有效攻击者造成固定伤害。
function SpiderShatteredEffect.OnAttacked(slots, inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if not IsValidAttacker(inst, attacker) then
        return
    end

    attacker.components.combat:GetAttacked(
        inst,
        TUNING.KEI_SPIDER_SHATTERED_REFLECT_DAMAGE or 25
    )
end

return SpiderShatteredEffect