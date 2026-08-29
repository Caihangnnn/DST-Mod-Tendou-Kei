local RecorderBoss = require("kei/recorder_boss")

local IMPRISON_TIMER = "kei_recorder_imprison_cd"
local CHECK_PERIOD = 0.25
local PILLAR_SIDE_DISTANCE = TUNING.KEI_RECORDER_DAYWALKER_IMPRISON_PILLAR_DISTANCE or 9
local PILLAR_RING_RADIUS = PILLAR_SIDE_DISTANCE / math.sqrt(3)
local BOUNDARY_SPEED_KEY = "kei_recorder_daywalker_imprison_boundary"
local BOUNDARY_SOFT_ZONE = TUNING.KEI_RECORDER_DAYWALKER_IMPRISON_BOUNDARY_SOFT_ZONE or 1.5
local PLAYER_ACTIVITY_RADIUS = TUNING.KEI_RECORDER_DAYWALKER_IMPRISON_PLAYER_RADIUS or 12

local RecorderDaywalker = {}

local function RegisterSupport(owner, entity)
    if owner == nil or entity == nil then
        return
    end
    owner.kei_target_support_entities = owner.kei_target_support_entities or {}
    table.insert(owner.kei_target_support_entities, entity)
end

local function IsValidPlayer(player)
    return player ~= nil
        and player:IsValid()
        and not player:IsInLimbo()
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and player.components ~= nil
        and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local function ClearBoundaryConstraint(binding)
    local player = binding ~= nil and binding.player or nil
    local owner = binding ~= nil and binding.owner or nil
    if player ~= nil
        and player:IsValid()
        and player.components ~= nil
        and player.components.locomotor ~= nil
        and owner ~= nil
    then
        player.components.locomotor:RemoveExternalSpeedMultiplier(owner, BOUNDARY_SPEED_KEY)
    end
end

local function HasActivePillar(binding)
    for _, pillar in ipairs(binding.pillars or {}) do
        if pillar ~= nil and pillar:IsValid() and not pillar.kei_recorder_destroyed then
            return true
        end
    end
    return false
end

local function IsPlayerAlreadyBound(inst, player)
    for _, binding in ipairs(inst.kei_recorder_daywalker_bindings or {}) do
        if binding.player == player and HasActivePillar(binding) then
            return true
        end
    end
    return false
end

local function RemovePillarLink(inst, binding, pillar)
    if pillar == nil then
        return
    end

    if pillar.kei_recorder_binding == binding then
        pillar.kei_recorder_binding = nil
    end
    if pillar:IsValid() and pillar.SetPrisoner ~= nil then
        pillar:SetPrisoner(nil)
    end

    for i = #binding.pillars, 1, -1 do
        if binding.pillars[i] == pillar then
            table.remove(binding.pillars, i)
            break
        end
    end
    if #binding.pillars == 0 then
        ClearBoundaryConstraint(binding)
    end
end

local function RemoveBinding(inst, binding)
    ClearBoundaryConstraint(binding)
    for _, pillar in ipairs(binding.pillars) do
        if pillar ~= nil then
            if pillar.kei_recorder_binding == binding then
                pillar.kei_recorder_binding = nil
            end
            if pillar:IsValid() and pillar.SetPrisoner ~= nil then
                pillar:SetPrisoner(nil)
            end
        end
    end
    binding.pillars = {}

    if inst.kei_recorder_daywalker_bindings ~= nil then
        for i = #inst.kei_recorder_daywalker_bindings, 1, -1 do
            if inst.kei_recorder_daywalker_bindings[i] == binding then
                table.remove(inst.kei_recorder_daywalker_bindings, i)
                break
            end
        end
    end
end

local function OnPillarRemoved(pillar)
    local binding = pillar.kei_recorder_binding
    if binding ~= nil and binding.owner ~= nil and binding.owner:IsValid() then
        RemovePillarLink(binding.owner, binding, pillar)
    end
end

local function DestroyPillar(pillar)
    if pillar == nil or not pillar:IsValid() or pillar.kei_recorder_destroyed then
        return
    end
    pillar.kei_recorder_destroyed = true

    local binding = pillar.kei_recorder_binding
    if binding ~= nil and binding.owner ~= nil and binding.owner:IsValid() then
        RemovePillarLink(binding.owner, binding, pillar)
    end

    if pillar.components.workable ~= nil then
        pillar.components.workable:SetWorkable(false)
    end
    pillar.persists = false
    pillar:AddTag("NOCLICK")
    if pillar.base ~= nil and pillar.base:IsValid() then
        pillar.base:Remove()
    end
    pillar.AnimState:PlayAnimation("pillar_fall")
    pillar.SoundEmitter:PlaySound("daywalker/pillar/destroy")
    pillar:DoTaskInTime(22 * FRAMES, function(inst)
        if inst:IsValid() then
            inst:Remove()
        end
    end)
end

local function OnPillarWorkFinished(pillar)
    DestroyPillar(pillar)
end

local function PlayPillarSpawnAnimation(pillar)
    pillar.AnimState:PlayAnimation("hit")
    pillar.AnimState:PushAnimation("idle", true)
    if pillar.base ~= nil and pillar.base:IsValid() then
        pillar.base.AnimState:PlayAnimation("hit")
        pillar.base.AnimState:PushAnimation("idle", true)
    end
end

local function UpdatePlayerBoundary(binding)
    local player = binding.player
    if not IsValidPlayer(player) then
        return false
    end

    for i = #binding.pillars, 1, -1 do
        local pillar = binding.pillars[i]
        if pillar == nil or not pillar:IsValid() or pillar.kei_recorder_destroyed then
            table.remove(binding.pillars, i)
        end
    end
    if #binding.pillars == 0 then
        return false
    end

    local x, _, z = player.Transform:GetWorldPosition()
    local player_radius = player.GetPhysicsRadius ~= nil and player:GetPhysicsRadius(0) or 0
    local allowed_radius = math.max(0, binding.radius - player_radius - 0.05)

    -- Use a soft, directional boundary instead of teleporting the player
    -- back after every overshoot. Outward movement slows near the edge and
    -- is stopped at the edge, while inward movement remains available.
    local speed_multiplier = 1
    local outward_blocked = false
    local vx, _, vz = 0, 0, 0
    if player.Physics ~= nil then
        vx, _, vz = player.Physics:GetVelocity()
    end

    for _, pillar in ipairs(binding.pillars) do
        local px, _, pz = pillar.Transform:GetWorldPosition()
        local dx, dz = x - px, z - pz
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 0 then
            local gap = allowed_radius - distance
            local outward_velocity = (vx * dx + vz * dz) / distance
            if gap < BOUNDARY_SOFT_ZONE and outward_velocity > 0 then
                if gap <= 0 then
                    outward_blocked = true
                    speed_multiplier = 0
                else
                    speed_multiplier = math.min(
                        speed_multiplier,
                        math.max(0, gap / BOUNDARY_SOFT_ZONE)
                    )
                end
            end
        end
    end

    if player.components.locomotor ~= nil then
        if speed_multiplier < 1 then
            player.components.locomotor:SetExternalSpeedMultiplier(
                binding.owner,
                BOUNDARY_SPEED_KEY,
                speed_multiplier
            )
        else
            player.components.locomotor:RemoveExternalSpeedMultiplier(
                binding.owner,
                BOUNDARY_SPEED_KEY
            )
        end
        if outward_blocked then
            player.components.locomotor:StopMoving()
        end
    end
    return true
end

local function EnforceBindings(inst)
    if inst.kei_recorder_daywalker_bindings == nil then
        return
    end

    for i = #inst.kei_recorder_daywalker_bindings, 1, -1 do
        local binding = inst.kei_recorder_daywalker_bindings[i]
        if not UpdatePlayerBoundary(binding) then
            RemoveBinding(inst, binding)
        end
    end
end

local function GetPillarPoint(center, theta)
    local offset = FindWalkableOffset(
        center,
        theta,
        PILLAR_RING_RADIUS,
        8,
        false,
        true
    )
    if offset ~= nil then
        return center.x + offset.x, center.z + offset.z
    end
    return center.x + math.cos(theta) * PILLAR_RING_RADIUS,
        center.z + math.sin(theta) * PILLAR_RING_RADIUS
end

local function SpawnPillar(inst, binding, x, z)
    local pillar = SpawnPrefab("daywalker_pillar")
    if pillar == nil then
        return nil
    end

    pillar.persists = false
    pillar.kei_recorder_source = inst.kei_recorder_source
    pillar.kei_recorder_binding = binding
    pillar.Transform:SetPosition(x, 0, z)

    -- Keep the pillar at its default full level. It remains non-persistent so
    -- the vanilla work-finished callback cannot drop the normal pillar loot.
    if pillar.SetPrisoner ~= nil then
        pillar:SetPrisoner(binding.player)
    end
    PlayPillarSpawnAnimation(pillar)

    pillar:ListenForEvent("workfinished", OnPillarWorkFinished)
    pillar:ListenForEvent("onremove", OnPillarRemoved)
    RegisterSupport(inst.kei_recorder_source, pillar)
    table.insert(binding.pillars, pillar)
    return pillar
end

local function ImprisonPlayer(inst, player)
    local center = player:GetPosition()
    local binding = {
        owner = inst,
        player = player,
        radius = PLAYER_ACTIVITY_RADIUS,
        pillars = {},
    }

    inst.kei_recorder_daywalker_bindings = inst.kei_recorder_daywalker_bindings or {}
    table.insert(inst.kei_recorder_daywalker_bindings, binding)

    local start_angle = math.random() * TWOPI
    for i = 0, 2 do
        local angle = start_angle + i * TWOPI / 3
        SpawnPillar(inst, binding, GetPillarPoint(center, angle))
    end

    if #binding.pillars == 0 then
        RemoveBinding(inst, binding)
    end
end

function RecorderDaywalker.ImprisonArenaPlayers(inst)
    local source = inst ~= nil and inst.kei_recorder_source or nil
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if not IsPlayerAlreadyBound(inst, player) then
            ImprisonPlayer(inst, player)
        end
    end
end

function RecorderDaywalker.CanUseImprison(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.kei_recorder_source ~= nil
        and inst.kei_recorder_source:IsValid()
        and inst.components ~= nil
        and inst.components.timer ~= nil
        and not inst.components.timer:TimerExists(IMPRISON_TIMER)
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
        and not inst.defeated
        and not inst.chained
        and inst.sg ~= nil
        and not inst.sg:HasStateTag("busy")
        and #RecorderBoss.GetArenaPlayers(inst.kei_recorder_source) > 0
end

function RecorderDaywalker.Apply(inst)
    if inst == nil
        or not inst:IsValid()
        or inst.prefab ~= "kei_recorder_daywalker"
        or inst.components == nil
        or inst.components.timer == nil
    then
        return false
    end

    RecorderDaywalker.Remove(inst)
    inst.kei_recorder_daywalker_bindings = {}
    inst.kei_recorder_daywalker_imprison_task = inst:DoPeriodicTask(
        CHECK_PERIOD,
        function(daywalker)
            if not daywalker:IsValid() then
                return
            end
            EnforceBindings(daywalker)
            if RecorderDaywalker.CanUseImprison(daywalker) then
                daywalker.sg:GoToState("kei_recorder_imprison")
            end
        end
    )
    return true
end

function RecorderDaywalker.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_daywalker_imprison_task ~= nil then
        inst.kei_recorder_daywalker_imprison_task:Cancel()
        inst.kei_recorder_daywalker_imprison_task = nil
    end

    if inst.kei_recorder_daywalker_bindings ~= nil then
        local bindings = inst.kei_recorder_daywalker_bindings
        inst.kei_recorder_daywalker_bindings = {}
        for _, binding in ipairs(bindings) do
            for _, pillar in ipairs(binding.pillars) do
                if pillar ~= nil and pillar:IsValid() then
                    pillar.kei_recorder_binding = nil
                    if pillar.SetPrisoner ~= nil then
                        pillar:SetPrisoner(nil)
                    end
                    pillar:Remove()
                end
            end
            binding.pillars = {}
        end
    end
end

return RecorderDaywalker
