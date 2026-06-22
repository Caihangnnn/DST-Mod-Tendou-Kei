-- 远古守卫者协议：攻击命中时概率召唤暗影触手 + 概率释放暗影囚牢。

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function IsValidTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and owner.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

local function IsNearShadowPillar(pt, pillars)
    for _, pillarpt in pairs(pillars) do
        if distsq(pt.x, pt.z, pillarpt.x, pillarpt.z) < 1 then
            return true
        end
    end
    return false
end

local function SpawnMinotaurTentacle(slots, inst, target)
    if not IsValidTarget(inst, target) then
        return false
    end

    local pt = target:GetPosition()
    local offset = FindWalkableOffset(pt, math.random() * TWOPI, 2, 3, false, true, NoHoles, false, true, true)
    if offset == nil then
        return false
    end

    local tentacle = SpawnPrefab("bigshadowtentacle")
    if tentacle == nil then
        return false
    end

    tentacle.kei_owner = inst
    tentacle.kei_target = target
    tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
    tentacle:DoTaskInTime(TUNING.KEI_MINOTAUR_TENTACLE_LIFETIME or 30, function(t)
        if t:IsValid() then
            t:Remove()
        end
    end)
    if tentacle.components.combat ~= nil then
        tentacle.components.combat:SetRetargetFunction(0.5, function(t)
            return IsValidTarget(t.kei_owner, t.kei_target) and t.kei_target or nil
        end)
        tentacle.components.combat:SetKeepTargetFunction(function(t, current_target)
            return current_target == t.kei_target
                and IsValidTarget(t.kei_owner, current_target)
                and current_target:IsNear(t, TUNING.TENTACLE_STOPATTACK_DIST)
        end)
        tentacle.components.combat:SetTarget(target)
    end
    tentacle:PushEvent("arrive")
    return true
end

local function SpawnShadowPrison(slots, inst, target, weapon)
    if target.components.locomotor == nil or not IsValidTarget(inst, target) then
        return
    end

    target:PushEvent("dispell_shadow_pillars")

    local map = TheWorld.Map
    local x0, y0, z0 = target.Transform:GetWorldPosition()
    if not map:IsPassableAtPoint(x0, y0, z0, true) then
        return
    end

    local padding = (target:HasTag("epic") and 1) or (target:HasTag("smallcreature") and 0) or 0.75
    local radius = math.max(1, target:GetPhysicsRadius(0) + padding)
    local num = math.floor(TWOPI * radius / 1.4 + 0.5)
    local period = 1 / num
    local delays = {}
    for i = 0, num - 1 do
        table.insert(delays, i * period)
    end

    local platform = target:GetCurrentPlatform()
    local flying = platform == nil and target:HasTag("flying")
    local target_marker = SpawnPrefab("shadow_pillar_target")
    if target_marker ~= nil then
        target_marker.Transform:SetPosition(x0, 0, z0)
        target_marker:SetDelay(delays[#delays])
        target_marker:SetTarget(target, radius, platform ~= nil)
    end

    local pillars = {}
    local theta = math.random() * TWOPI
    local delta = TWOPI / num
    for i = 1, num do
        local pt = Vector3(x0 + math.cos(theta) * radius, 0, z0 - math.sin(theta) * radius)
        if not IsNearShadowPillar(pt, pillars)
            and map:IsPassableAtPoint(pt.x, 0, pt.z, true)
            and (flying or (map:GetPlatformAtPoint(pt.x, pt.z) == platform and not map:IsGroundTargetBlocked(pt)))
        then
            local pillar = SpawnPrefab("shadow_pillar")
            if pillar ~= nil then
                pillar.Transform:SetPosition(pt:Get())
                pillar:SetDelay(table.remove(delays, math.random(#delays)))
                pillar:SetTarget(target, platform ~= nil)
                pillars[pillar] = pt
            end
        end
        theta = theta + delta
    end

    if not (target.sg ~= nil and target.sg:HasStateTag("noattack")) then
        target:PushEvent("attacked", { attacker = inst, damage = 0, weapon = weapon })
    end
end

local MinotaurEffect = {}

function MinotaurEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    local weapon = data and data.weapon
    local now = GetTime()

    if (slots._kei_minotaur_tentacle_ready_time or 0) <= now
        and math.random() < (TUNING.KEI_MINOTAUR_TENTACLE_CHANCE or 0.30)
        and SpawnMinotaurTentacle(slots, inst, target)
    then
        slots._kei_minotaur_tentacle_ready_time = now + (TUNING.KEI_MINOTAUR_TENTACLE_COOLDOWN or 0.5)
    end
    if math.random() < (TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE or 0.15) then
        SpawnShadowPrison(slots, inst, target, weapon)
    end
end

return MinotaurEffect
