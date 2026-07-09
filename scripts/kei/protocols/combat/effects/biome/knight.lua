-- 发条骑士协议（knight）：受击时反伤并释放霸道电流。

local KnightEffect = {}

local TARGET_MUST_TAGS = { "_combat", "_health" }
local TARGET_CANT_TAGS = {
    "INLIMBO",
    "FX",
    "NOCLICK",
    "DECOR",
    "notarget",
    "noattack",
    "wall",
    "playerghost",
}

local function IsValidShockTarget(owner, target)
    if target == nil
        or target == owner
        or not target:IsValid()
        or target:IsInLimbo()
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
    then
        return false
    end

    local combat = owner.components.combat
    return combat == nil or (combat:CanTarget(target) and not combat:IsAlly(target))
end

local function ShockTarget(owner, target, damage)
    if not IsValidShockTarget(owner, target) then
        return false
    end

    if SpawnElectricHitSparks ~= nil then
        SpawnElectricHitSparks(owner, target, true)
    end

    target:PushEventImmediate("electrocute", {
        attacker = owner,
        stimuli = "electric",
        noresist = true,
        numforks = 0,
    })
    target.components.combat:GetAttacked(owner, damage, nil, "electric")
    return true
end

local function SpawnShockArc(owner, target)
    if target == nil or not target:IsValid() then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local px, _, pz = target.Transform:GetWorldPosition()
    local arc = SpawnPrefab("shock_arc_fx")
    if arc ~= nil then
        arc.Transform:SetPosition((px + x) / 2, y, (pz + z) / 2)
        arc:ForceFacePoint(px, y, pz)
    end
end

-- 释放霸道电流：优先反击攻击者，并电击周围敌方单位；电流不会命中 Kei 自己。
function KnightEffect.ReleaseShock(slots, inst, attacker)
    if slots == nil or inst == nil or not inst:IsValid() then
        return
    end

    local damage = TUNING.KEI_KNIGHT_SHOCK_DAMAGE or 50
    local radius = TUNING.KEI_KNIGHT_SHOCK_RADIUS or 3
    local now = GetTime()

    if slots._kei_knight_next_shock_time ~= nil and now < slots._kei_knight_next_shock_time then
        return
    end
    slots._kei_knight_next_shock_time = now + (TUNING.KEI_KNIGHT_SHOCK_COOLDOWN or 0.1)

    local shocked = {}
    if ShockTarget(inst, attacker, damage) then
        shocked[attacker] = true
        SpawnShockArc(inst, attacker)
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, radius, TARGET_MUST_TAGS, TARGET_CANT_TAGS)
    for _, target in ipairs(ents) do
        if not shocked[target] and ShockTarget(inst, target, damage) then
            shocked[target] = true
            SpawnShockArc(inst, target)
        end
    end
end

-- Kei 受到攻击时，对攻击者和周围敌方单位释放电流。
function KnightEffect.OnAttacked(slots, inst, data)
    KnightEffect.ReleaseShock(slots, inst, data ~= nil and data.attacker or nil)
end

function KnightEffect.Disable(slots, inst)
    if slots ~= nil then
        slots._kei_knight_next_shock_time = nil
    end
end

return KnightEffect