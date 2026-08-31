local assets = {
    Asset("ANIM", "anim/wave.zip"),
}

local prefabs = {
    "wave_splash",
}

local UPDATE_PERIOD = TUNING.KEI_RECORDER_MALBATROSS_WAVE_UPDATE_PERIOD or 0.05
local WAVE_DAMAGE = TUNING.KEI_RECORDER_MALBATROSS_WAVE_DAMAGE or 20
local TOUCH_RADIUS = TUNING.KEI_RECORDER_MALBATROSS_WAVE_TOUCH_RADIUS or 1.25

local function OnDisappearAnimationOver(inst)
    if inst:IsValid() then
        inst:Remove()
    end
end

local function BeginDisappear(inst)
    if not inst:IsValid() or inst.kei_recorder_malbatross_wave_expiring then
        return
    end

    inst.kei_recorder_malbatross_wave_expiring = true
    if inst.kei_recorder_malbatross_wave_lifetime_task ~= nil then
        inst.kei_recorder_malbatross_wave_lifetime_task:Cancel()
        inst.kei_recorder_malbatross_wave_lifetime_task = nil
    end

    inst.AnimState:PlayAnimation("disappear")
    inst:ListenForEvent("animover", OnDisappearAnimationOver)
    inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.1, inst.Remove)
end

local function IsValidPlayer(player)
    return player ~= nil
        and player:IsValid()
        and not player:IsInLimbo()
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and player.components ~= nil
        and player.components.health ~= nil
end

local function HitPlayer(inst, player)
    if inst.kei_recorder_malbatross_wave_expiring
        or not inst.kei_recorder_malbatross_wave_damage
        or not IsValidPlayer(player)
    then
        return false
    end

    local health = player.components ~= nil and player.components.health or nil
    if health == nil or health:IsDead() then
        return false
    end

    inst.kei_recorder_malbatross_wave_damage = false
    local attacker = inst.kei_recorder_malbatross_owner
    if attacker == nil or not attacker:IsValid() then
        attacker = inst
    end
    health:DoDelta(
        -WAVE_DAMAGE,
        true,
        "kei_recorder_malbatross_wave",
        false,
        attacker ~= nil and attacker or inst
    )

    local splash = SpawnPrefab("wave_splash")
    if splash ~= nil then
        splash.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    BeginDisappear(inst)
    return true
end

local function DistanceToSegmentSq(px, pz, ax, az, bx, bz)
    local abx, abz = bx - ax, bz - az
    local length_sq = abx * abx + abz * abz
    if length_sq <= 0 then
        local dx, dz = px - ax, pz - az
        return dx * dx + dz * dz
    end

    local apx, apz = px - ax, pz - az
    local t = (apx * abx + apz * abz) / length_sq
    t = math.max(0, math.min(1, t))
    local closest_x = ax + abx * t
    local closest_z = az + abz * t
    local dx, dz = px - closest_x, pz - closest_z
    return dx * dx + dz * dz
end

local function CheckForPlayerTouch(inst)
    if not inst:IsValid()
        or inst.kei_recorder_malbatross_wave_expiring
        or not inst.kei_recorder_malbatross_wave_damage
    then
        return
    end

    local x, _, z = inst.Transform:GetWorldPosition()
    -- Do not rely on the wave's disabled physics collider or spatial query tags.
    -- AllPlayers is authoritative on the master sim and also covers players on boats.
    local players = AllPlayers or {}
    for _, player in pairs(players) do
        if IsValidPlayer(player) then
            local px, _, pz = player.Transform:GetWorldPosition()
            local player_radius = player.GetPhysicsRadius ~= nil
                and player:GetPhysicsRadius(0)
                or 0
            local radius = TOUCH_RADIUS + player_radius
            if DistanceToSegmentSq(
                px,
                pz,
                inst.kei_recorder_malbatross_wave_previous_x ~= nil
                    and inst.kei_recorder_malbatross_wave_previous_x
                    or x,
                inst.kei_recorder_malbatross_wave_previous_z ~= nil
                    and inst.kei_recorder_malbatross_wave_previous_z
                    or z,
                x,
                z
            ) <= radius * radius then
                if HitPlayer(inst, player) then
                    return true
                end
            end
        end
    end
    inst.kei_recorder_malbatross_wave_previous_x = x
    inst.kei_recorder_malbatross_wave_previous_z = z
    return false
end

local function UpdateRing(inst)
    if inst.kei_recorder_malbatross_owner == nil
        or not inst.kei_recorder_malbatross_owner:IsValid()
    then
        inst:Remove()
        return
    end

    local angle = inst.kei_recorder_malbatross_wave_start_angle
        + (GetTime() - inst.kei_recorder_malbatross_wave_start_time)
        * inst.kei_recorder_malbatross_wave_angular_speed
    local x = inst.kei_recorder_malbatross_wave_center_x
        + math.cos(angle) * inst.kei_recorder_malbatross_wave_radius
    local z = inst.kei_recorder_malbatross_wave_center_z
        - math.sin(angle) * inst.kei_recorder_malbatross_wave_radius
    inst.Transform:SetPosition(x, 0, z)
    inst.Transform:SetRotation(angle / DEGREES + (inst.kei_recorder_malbatross_wave_angular_speed > 0 and 90 or -90))

    if inst.kei_recorder_malbatross_wave_damage
        and CheckForPlayerTouch(inst)
    then
        return
    end

    inst.kei_recorder_malbatross_wave_previous_x = x
    inst.kei_recorder_malbatross_wave_previous_z = z
end

local function UpdateLinear(inst)
    local owner = inst.kei_recorder_malbatross_owner
    if owner == nil or not owner:IsValid() then
        inst:Remove()
        return
    end

    local elapsed = math.max(0, GetTime() - inst.kei_recorder_malbatross_wave_start_time)
    local distance = math.min(
        elapsed * inst.kei_recorder_malbatross_wave_speed,
        inst.kei_recorder_malbatross_wave_travel_distance
    )
    local x = inst.kei_recorder_malbatross_wave_start_x
        + math.cos(inst.kei_recorder_malbatross_wave_angle) * distance
    local z = inst.kei_recorder_malbatross_wave_start_z
        - math.sin(inst.kei_recorder_malbatross_wave_angle) * distance
    inst.Transform:SetPosition(x, 0, z)

    if inst.kei_recorder_malbatross_wave_damage then
        if CheckForPlayerTouch(inst) then
            return
        end
    end

    inst.kei_recorder_malbatross_wave_previous_x = x
    inst.kei_recorder_malbatross_wave_previous_z = z

    if distance >= inst.kei_recorder_malbatross_wave_travel_distance then
        BeginDisappear(inst)
    end
end

local function OnPhysicsCollision(inst, other)
    if other ~= nil and other:IsValid() and other:HasTag("player") then
        HitPlayer(inst, other)
    end
end

local function OnRemoveEntity(inst)
    if inst.kei_recorder_malbatross_wave_update_task ~= nil then
        inst.kei_recorder_malbatross_wave_update_task:Cancel()
        inst.kei_recorder_malbatross_wave_update_task = nil
    end
    if inst.kei_recorder_malbatross_wave_lifetime_task ~= nil then
        inst.kei_recorder_malbatross_wave_lifetime_task:Cancel()
        inst.kei_recorder_malbatross_wave_lifetime_task = nil
    end
end

local SetLinearMotion
local SetRingMotion

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddPhysics()
    inst.entity:SetCanSleep(TheWorld.ismastersim)

    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.SMALLOBSTACLES)
    inst.Physics:SetCollisionMask(COLLISION.CHARACTERS)
    inst.Physics:SetSphere(1)
    inst.Physics:SetCollides(false)

    inst.Transform:SetEightFaced()
    inst.AnimState:SetBuild("wave")
    inst.AnimState:SetBank("wave_ripple")
    inst.AnimState:PlayAnimation("appear")
    inst.AnimState:PushAnimation("idle", true)

    inst:AddTag("wave")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.Physics:SetCollisionCallback(OnPhysicsCollision)
    inst.OnRemoveEntity = OnRemoveEntity
    inst.BeginDisappear = BeginDisappear
    inst.CheckForPlayerTouch = CheckForPlayerTouch
    inst.SetLinearMotion = SetLinearMotion
    inst.SetRingMotion = SetRingMotion
    return inst
end

SetLinearMotion = function(inst, angle, speed, lifetime, owner, damage, travel_distance)
    inst.kei_recorder_malbatross_owner = owner
    inst.kei_recorder_malbatross_wave_damage = damage == true
    inst.kei_recorder_malbatross_wave_angle = angle * DEGREES
    inst.kei_recorder_malbatross_wave_speed = speed
    inst.kei_recorder_malbatross_wave_travel_distance = travel_distance or speed * lifetime
    inst.kei_recorder_malbatross_wave_start_time = GetTime()
    inst.Transform:SetRotation(angle)
    local x, _, z = inst.Transform:GetWorldPosition()
    inst.kei_recorder_malbatross_wave_start_x = x
    inst.kei_recorder_malbatross_wave_start_z = z
    inst.kei_recorder_malbatross_wave_previous_x = x
    inst.kei_recorder_malbatross_wave_previous_z = z
    inst.kei_recorder_malbatross_wave_expire_time = GetTime() + lifetime
    inst.UpdateLinearMotion = UpdateLinear
    inst.Physics:Stop()
    UpdateLinear(inst)
    inst.kei_recorder_malbatross_wave_update_task = inst:DoPeriodicTask(UPDATE_PERIOD, UpdateLinear)
    inst.kei_recorder_malbatross_wave_lifetime_task = inst:DoTaskInTime(lifetime, BeginDisappear)
end

SetRingMotion = function(inst, center_x, center_z, radius, start_angle, angular_speed, lifetime, owner, damage)
    inst.kei_recorder_malbatross_owner = owner
    inst.kei_recorder_malbatross_wave_damage = damage == true
    inst.kei_recorder_malbatross_wave_center_x = center_x
    inst.kei_recorder_malbatross_wave_center_z = center_z
    inst.kei_recorder_malbatross_wave_radius = radius
    inst.kei_recorder_malbatross_wave_start_angle = start_angle
    inst.kei_recorder_malbatross_wave_angular_speed = angular_speed
    inst.kei_recorder_malbatross_wave_start_time = GetTime()
    inst.kei_recorder_malbatross_wave_expire_time = GetTime() + lifetime
    inst.UpdateRingMotion = UpdateRing
    inst.Physics:Stop()
    UpdateRing(inst)
    inst.kei_recorder_malbatross_wave_update_task = inst:DoPeriodicTask(UPDATE_PERIOD, UpdateRing)
    inst.kei_recorder_malbatross_wave_lifetime_task = inst:DoTaskInTime(lifetime, BeginDisappear)
end

return Prefab("kei_recorder_malbatross_wave", fn, assets, prefabs)
