-- 织影者协议：攻击命中时概率触发影袭，造成额外伤害。

local SHADOWSTRIKE_START_DISTANCE = 5
local SHADOWSTRIKE_LUNGE_SPEED = 30
local SHADOWSTRIKE_COUNT = 5
local SHADOWSTRIKE_SPAWN_DELAY = 0.1

local function IsValidTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.combat ~= nil
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and owner.components.combat:IsValidTarget(target)
end

local function GetShadowStrikeOffset(index, base_angle)
    local angle = base_angle + (TWOPI / SHADOWSTRIKE_COUNT) * index * 2
    return Vector3(
        SHADOWSTRIKE_START_DISTANCE * math.sin(angle),
        0,
        SHADOWSTRIKE_START_DISTANCE * math.cos(angle)
    )
end

local function SpawnShadowStrikeSlash(target, rotation)
    local fx = SpawnPrefab(math.random(2) == 1 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.Transform:SetRotation(rotation or 0)
    end
end

local function SpawnStalkerShadowStrike(slots, inst, target, damage, offset)
    if not IsValidTarget(inst, target) then
        return
    end

    local targetpos = target:GetPosition()
    local shadow = SpawnPrefab("waxwell_shadowstriker")
    if shadow == nil then
        SpawnShadowStrikeSlash(target, inst.Transform:GetRotation())
        slots._doing_shadowstrike = true
        target.components.combat:GetAttacked(inst, damage)
        slots._doing_shadowstrike = nil
        return
    end

    local transition = SpawnPrefab("statue_transition_2")
    if transition ~= nil then
        transition.Transform:SetPosition((targetpos + offset):Get())
    end

    shadow.persists = false
    shadow:Show()
    shadow.Transform:SetPosition((targetpos + offset):Get())
    shadow:FacePoint(targetpos)
    shadow.AnimState:PlayAnimation("lunge_pre")
    shadow.AnimState:PushAnimation("lunge_loop")
    shadow.AnimState:PushAnimation("lunge_pst")

    shadow:DoTaskInTime(12 * FRAMES, function(s)
        if s:IsValid() and s.Physics ~= nil then
            s.Physics:SetMotorVel(SHADOWSTRIKE_LUNGE_SPEED, 0, 0)
        end
    end)
    shadow:DoTaskInTime(15 * FRAMES, function(s)
        if not IsValidTarget(inst, target) then
            return
        end
        SpawnShadowStrikeSlash(target, s.Transform:GetRotation())
        slots._doing_shadowstrike = true
        target.components.combat:GetAttacked(inst, damage)
        slots._doing_shadowstrike = nil
    end)
    shadow:DoTaskInTime(22 * FRAMES, function(s)
        if s:IsValid() and s.Physics ~= nil then
            s.Physics:ClearMotorVelOverride()
        end
    end)
    shadow:DoTaskInTime(30 * FRAMES, function(s)
        if s:IsValid() then
            s:Remove()
        end
    end)
end

local StalkerEffect = {}

function StalkerEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    local damage = data and (data.damageresolved or 0)
    if slots._doing_shadowstrike
        or math.random() >= (TUNING.KEI_STALKER_SHADOWSTRIKE_CHANCE or 0.30)
        or (damage or 0) <= 0
        or not IsValidTarget(inst, target)
    then
        return
    end

    slots._doing_shadowstrike = true
    local shadow_damage = damage * (TUNING.KEI_STALKER_SHADOWSTRIKE_DAMAGE_MULT or 0.5)
    local base_angle = math.random() * TWOPI
    for i = 1, SHADOWSTRIKE_COUNT do
        local offset = GetShadowStrikeOffset(i, base_angle)
        inst:DoTaskInTime(SHADOWSTRIKE_SPAWN_DELAY * (i - 1), function()
            SpawnStalkerShadowStrike(slots, inst, target, shadow_damage, offset)
        end)
    end
    slots._doing_shadowstrike = nil
end

return StalkerEffect
