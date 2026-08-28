local assets = {
    Asset("ANIM", "anim/deerclops_icespike.zip"),
}

local prefabs = {
    "deerclops_icespike_fx",
}

local SPIKE_RADIUS = 1
local SPIKE_LIFETIME = 30

local function BreakOnPlayerTouch(inst, player)
    if inst.kei_recorder_deerclops_icespike_broken
        or inst._disappearing
        or player == nil
        or not player:IsValid()
        or not player:HasTag("player")
        or player:HasTag("playerghost")
    then
        return
    end

    inst.kei_recorder_deerclops_icespike_broken = true
    local freezable = player.components ~= nil and player.components.freezable or nil
    if freezable ~= nil and not (player.components.health ~= nil and player.components.health:IsDead()) then
        freezable:AddColdness(10)
    end

    local shatter = SpawnPrefab("deerclops_icespike_fx")
    if shatter ~= nil then
        shatter.Transform:SetPosition(inst.Transform:GetWorldPosition())
        shatter:SetFXOwner(nil)
        shatter:RestartFX(inst.big, inst.variation)
        shatter.SoundEmitter:PlaySound("dontstarve/common/break_iceblock")
    else
        inst.SoundEmitter:PlaySound("dontstarve/common/break_iceblock")
    end
    inst:Remove()
end

-- SetCollides(false) keeps the physics shape as a sensor: it can still receive
-- collision callbacks, but it never pushes players or blocks the deerclops.
local function OnPhysicsCollision(inst, other)
    if other ~= nil and other:IsValid() and other:HasTag("player") then
        BreakOnPlayerTouch(inst, other)
    end
end

local function CheckForPlayerTouch(inst)
    if not inst:IsValid() or inst.kei_recorder_deerclops_icespike_broken or inst._disappearing then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local players = TheSim:FindEntities(x, y, z, SPIKE_RADIUS + 0.75, { "player" }, { "INLIMBO", "playerghost" })
    for _, player in ipairs(players) do
        if player:IsValid() and inst:GetDistanceSqToPoint(player.Transform:GetWorldPosition()) <= (SPIKE_RADIUS + player:GetPhysicsRadius(0)) ^ 2 then
            BreakOnPlayerTouch(inst, player)
            return
        end
    end
end

local function OnDisappearAnimOver(inst)
    if inst:IsValid() then
        inst:Remove()
    end
end

local function BeginDisappear(inst)
    if not inst:IsValid() or inst._disappearing or inst.kei_recorder_deerclops_icespike_broken then
        return
    end

    inst._disappearing = true
    if inst._hold_expanded_task ~= nil then
        inst._hold_expanded_task:Cancel()
        inst._hold_expanded_task = nil
    end
    inst:ListenForEvent("animover", OnDisappearAnimOver)
    inst.AnimState:Resume()
end

local function SetVariation(inst, big, variation)
    inst.big = big == true
    inst.variation = variation or math.random(4)
    inst.AnimState:PlayAnimation(
        (inst.big and "spike_big" or "spike") .. tostring(inst.variation)
    )

    -- The original animation retracts after the spike is fully extended.
    -- Hold the last fully extended frame so the persistent obstacle remains visible.
    local extended_frame = (inst.variation == 4 or (inst.big and inst.variation == 1)) and 2 or 3
    inst._hold_expanded_task = inst:DoTaskInTime(extended_frame * FRAMES, function(spike)
        if spike:IsValid() then
            spike.AnimState:SetFrame(extended_frame)
            spike.AnimState:Pause()
        end
    end)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddPhysics()

    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.SMALLOBSTACLES)
    inst.Physics:SetCollisionMask(COLLISION.CHARACTERS)
    inst.Physics:SetSphere(SPIKE_RADIUS)
    inst.Physics:SetCollides(false)

    inst.Transform:SetFourFaced()
    inst.AnimState:SetBank("deerclops_icespike")
    inst.AnimState:SetBuild("deerclops_icespike")
    inst.AnimState:PlayAnimation("spike1")

    inst:AddTag("groundspike")
    inst:AddTag("frozen")
    inst:AddTag("kei_recorder_deerclops_icespike")
    inst.persists = false

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.SetVariation = SetVariation
    inst.BeginDisappear = BeginDisappear
    inst.Physics:SetCollisionCallback(OnPhysicsCollision)
    -- Cover the case where a player is already overlapping the spike when it
    -- is spawned; subsequent touches are handled by the physics callback.
    inst:DoTaskInTime(0, CheckForPlayerTouch)
    inst:DoTaskInTime(SPIKE_LIFETIME, function(spike)
        BeginDisappear(spike)
    end)

    return inst
end

return Prefab("kei_recorder_deerclops_icespike", fn, assets, prefabs)
