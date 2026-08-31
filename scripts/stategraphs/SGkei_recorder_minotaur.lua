require("stategraphs/commonstates")

local RecorderBoss = require("kei/recorder_boss")
local original = require("stategraphs/SGminotaur")

local states = {}
for _, state in pairs(original.states) do
    states[state.name] = state
end

local events = {}
for _, event in pairs(original.events or {}) do
    table.insert(events, event)
end

local RAM_MUST_TAGS = { "player" }
local RAM_CANT_TAGS = { "INLIMBO", "playerghost", "ghost", "dead" }
local RAM_DURATION = 30
local RAM_HIT_COOLDOWN = .9
local RAM_TURN_RATE = 480 -- degrees per second; keeps the charge car-like
local RAM_LOOP_RADIUS = 8

local function GetRamTarget(inst)
    local target = inst.components.combat ~= nil and inst.components.combat.target or nil
    return target ~= nil and target:IsValid() and target or nil
end

local function GetRamPlayers(inst)
    local source = inst.kei_recorder_source
    if source ~= nil and source:IsValid() then
        return RecorderBoss.GetArenaPlayers(source)
    end
    return AllPlayers or {}
end

local function DoRecorderRamAOE(inst)
    if inst.components.combat == nil then
        return {}
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = inst.Physics ~= nil and inst.Physics:GetRadius() or inst:GetPhysicsRadius(0)
    radius = radius or inst.physicsradius or 2.2
    local now = GetTime()
    local hits = inst.sg.statemem.ram_hit_targets
    local hit_targets = {}

    if hits == nil then
        hits = {}
        inst.sg.statemem.ram_hit_targets = hits
    end

    local arena_players = {}
    for _, player in ipairs(GetRamPlayers(inst)) do
        arena_players[player] = true
    end

    local nearby_players = TheSim:FindEntities(x, y, z, radius + 2, RAM_MUST_TAGS, RAM_CANT_TAGS)
    local current_target = GetRamTarget(inst)
    table.sort(nearby_players, function(a, b)
        return (a == current_target and 0 or 1) < (b == current_target and 0 or 1)
    end)

    for _, player in ipairs(nearby_players) do
        if arena_players[player]
            and player:IsValid()
            and player.components.health ~= nil
            and not player.components.health:IsDead()
        then
            local player_radius = player.GetPhysicsRadius ~= nil and player:GetPhysicsRadius(0) or 0
            local hit_radius = radius + player_radius
            if inst:GetDistanceSqToInst(player) <= hit_radius * hit_radius
                and (hits[player] == nil or now - hits[player] >= RAM_HIT_COOLDOWN)
            then
                hits[player] = now
                inst.components.combat.ignorehitrange = true
                inst.components.combat:DoAttack(player)
                inst.components.combat.ignorehitrange = false
                table.insert(hit_targets, player)
            end
        end
    end

    return hit_targets
end

local function RestoreRamPhysics(inst)
    inst.Physics:ClearMotorVelOverride()
    inst.Physics:Stop()
    inst.components.locomotor:StopMoving()
    inst.Physics:SetCollisionMask(
        COLLISION.WORLD,
        COLLISION.OBSTACLES,
        COLLISION.CHARACTERS,
        COLLISION.GIANTS
    )
end

local function SteerRamToAngle(inst, desired_rotation, dt)
    local current_rotation = inst.Transform:GetRotation()
    local delta = desired_rotation - current_rotation

    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end

    local max_turn = RAM_TURN_RATE * dt
    delta = math.clamp(delta, -max_turn, max_turn)
    inst.Transform:SetRotation(current_rotation + delta)
end

local function SteerRamTowardTarget(inst, target, dt)
    SteerRamToAngle(inst, inst:GetAngleToPoint(target.Transform:GetWorldPosition()), dt)
end

local function BeginRamLoop(inst, target)
    local x, y, z = target.Transform:GetWorldPosition()
    local rotation = inst.Transform:GetRotation() * DEGREES

    -- Put the loop's centre to the side of the player's crossing point. The
    -- current forward direction is tangent to the circle at its first hit.
    inst.sg.statemem.ram_loop_target = target
    inst.sg.statemem.ram_loop_target_pos = Vector3(x, y, z)
    inst.sg.statemem.ram_loop_center = Vector3(
        x + math.sin(rotation) * RAM_LOOP_RADIUS,
        y,
        z + math.cos(rotation) * RAM_LOOP_RADIUS
    )
end

local function ClearRamLoop(inst)
    inst.sg.statemem.ram_loop_target = nil
    inst.sg.statemem.ram_loop_target_pos = nil
    inst.sg.statemem.ram_loop_center = nil
end

local function SwitchRamTargets(inst, hit_targets)
    if hit_targets == nil or #hit_targets == 0 then
        return
    end

    local hit_set = {}
    for _, player in ipairs(hit_targets) do
        hit_set[player] = true
    end

    local next_target = nil
    local nearest_distsq = math.huge
    local x, y, z = inst.Transform:GetWorldPosition()

    for _, player in ipairs(GetRamPlayers(inst)) do
        if not hit_set[player]
            and player:IsValid()
            and player.components.health ~= nil
            and not player.components.health:IsDead()
            and not player:HasTag("playerghost")
            and inst.components.combat:CanTarget(player)
        then
            local px, py, pz = player.Transform:GetWorldPosition()
            local dist_sq = distsq(x, z, px, pz)
            if dist_sq < nearest_distsq then
                nearest_distsq = dist_sq
                next_target = player
            end
        end
    end

    if next_target ~= nil then
        inst.components.combat:SetTarget(next_target)
        ClearRamLoop(inst)
    else
        -- When there is no untouched player, keep looping through the first
        -- hit player's collision point.
        local loop_target = hit_targets[1]
        inst.components.combat:SetTarget(loop_target)
        BeginRamLoop(inst, loop_target)
    end
end

local function UpdateRamLoopTarget(inst)
    local target = inst.sg.statemem.ram_loop_target
    local center = inst.sg.statemem.ram_loop_center
    local previous = inst.sg.statemem.ram_loop_target_pos
    if target == nil or not target:IsValid() or center == nil or previous == nil then
        return false
    end

    local x, y, z = target.Transform:GetWorldPosition()
    center.x = center.x + x - previous.x
    center.y = y
    center.z = center.z + z - previous.z
    previous.x, previous.y, previous.z = x, y, z
    return true
end

local function SteerRamAroundLoop(inst, dt)
    local center = inst.sg.statemem.ram_loop_center
    if center == nil then
        return false
    end

    -- The angle from the rhino to the loop centre plus 90 degrees is the
    -- tangent that carries it around the crossing point.
    local desired_rotation = inst:GetAngleToPoint(center.x, center.y, center.z) + 90
    SteerRamToAngle(inst, desired_rotation, dt)
    return true
end

states.run_start = State{
    name = "run_start",
    tags = { "moving", "running", "busy", "atk_pre", "recorder_ram" },

    onenter = function(inst)
        inst.Physics:Stop()
        inst.components.locomotor:StopMoving()
        inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/scuff")
        inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/voice")
        inst.AnimState:PlayAnimation("atk_pre")
        inst.AnimState:PushAnimation("paw_loop")
        local target = GetRamTarget(inst)
        if target ~= nil then
            -- The wind-up lines up the initial charge. Direction changes are
            -- limited only after the actual charge begins.
            inst:ForceFacePoint(target.Transform:GetWorldPosition())
        end
        inst.sg:SetTimeout(1.5)
        inst.chargecount = 0
        inst.components.timer:StartTimer("kei_recorder_ram_cd", 6)
    end,

    timeline = {
        TimeEvent(12 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/scuff")
        end),
        TimeEvent(30 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/scuff")
        end),
    },

    onupdate = function(inst, dt)
        inst.chargecount = inst.chargecount + dt
    end,

    ontimeout = function(inst)
        inst.sg:GoToState("run")
    end,

    onexit = function(inst)
        if not inst.sg:HasStateTag("recorder_ram") then
            RestoreRamPhysics(inst)
        end
    end,
}

states.run = State{
    name = "run",
    tags = { "moving", "running", "busy", "recorder_ram" },

    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("atk", true)
        inst.sg:SetTimeout(RAM_DURATION)
        inst.sg.statemem.ram_speed = inst.components.locomotor.runspeed or 17
        inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.GIANTS
        )
        inst.Physics:SetMotorVelOverride(inst.sg.statemem.ram_speed, 0, 0)
        local hit_targets = DoRecorderRamAOE(inst)
        if #hit_targets > 0 then
            SwitchRamTargets(inst, hit_targets)
        end
    end,

    onupdate = function(inst, dt)
        local target = GetRamTarget(inst)
        if target == nil or target.components.health == nil or target.components.health:IsDead() then
            inst.sg:GoToState("run_stop")
            return
        end

        -- Steer like a vehicle: keep a constant forward speed and only turn
        -- by a bounded angle each tick. After the first hit, the vehicle
        -- follows a smooth loop whose crossing point is the target.
        if not UpdateRamLoopTarget(inst) then
            SteerRamTowardTarget(inst, target, dt)
        else
            SteerRamAroundLoop(inst, dt)
        end

        inst.Physics:SetMotorVelOverride(inst.sg.statemem.ram_speed, 0, 0)
        local hit_targets = DoRecorderRamAOE(inst)
        if #hit_targets > 0 then
            SwitchRamTargets(inst, hit_targets)
        end
    end,

    timeline = {
        TimeEvent(5 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("ancientguardian_rework/minotaur2/step")
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("run_stop")
    end,

    onexit = RestoreRamPhysics,
}

return StateGraph(
    "kei_recorder_minotaur",
    states,
    events,
    original.defaultstate,
    original.actionhandlers
)
