-- 远古守卫者协议公共实现：暗影囚笼、暗影触手。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local MinotaurCommon = {}

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function IsValidTarget(owner, target)
    return BeastCommon.IsValidCombatTarget(owner, target)
end

local function IsNearShadowPillar(pt, pillars)
    for _, pillarpt in pairs(pillars) do
        if distsq(pt.x, pt.z, pillarpt.x, pillarpt.z) < 1 then
            return true
        end
    end
    return false
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function MinotaurCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "minotaur")
end

-- 在目标周围生成暗影囚笼。
function MinotaurCommon.SpawnShadowPrison(inst, target, weapon)
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

-- 在目标附近生成并绑定暗影触手。
function MinotaurCommon.SpawnMinotaurTentacle(inst, target)
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

return MinotaurCommon
