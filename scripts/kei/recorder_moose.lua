local RecorderBoss = require("kei/recorder_boss")

local SPEED_KEY = "kei_recorder_moose_moisture"
local COOLDOWN = TUNING.KEI_RECORDER_MOOSE_VORTEX_COOLDOWN or 60
local COOLDOWN_TICK = 0.25
local VORTEX_PREFAB = "kei_recorder_moose_vortex"
local CLOCKWISE_ROTATION_STEP = 45 * DEGREES

local RecorderMoose = {}

local function IsLiving(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.components ~= nil
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
end

local function RemovePlayerSpeed(inst, player)
    if player ~= nil
        and player:IsValid()
        and player.components ~= nil
        and player.components.locomotor ~= nil
    then
        player.components.locomotor:RemoveExternalSpeedMultiplier(inst, SPEED_KEY)
    end
end

local function UpdateMoistureSpeed(inst)
    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return false
    end

    local previous = inst.kei_recorder_moose_speed_players or {}
    local current = {}
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        local moisture = player.components.moisture
        local locomotor = player.components.locomotor
        if moisture ~= nil and locomotor ~= nil then
            -- Moisture is represented as 0..1. Clamp the result so 80%+
            -- moisture always leaves the player at 20% movement speed.
            local multiplier = math.max(0.2, 1 - moisture:GetMoisturePercent())
            locomotor:SetExternalSpeedMultiplier(inst, SPEED_KEY, multiplier)
            current[player] = true
        end
    end

    for player in pairs(previous) do
        if not current[player] then
            RemovePlayerSpeed(inst, player)
        end
    end
    inst.kei_recorder_moose_speed_players = current
    return true
end

local function PruneVortices(inst)
    local vortices = inst.kei_recorder_moose_vortices or {}
    for i = #vortices, 1, -1 do
        if vortices[i] == nil or not vortices[i]:IsValid() then
            table.remove(vortices, i)
        end
    end
    inst.kei_recorder_moose_vortices = vortices
end

local function SpawnVortices(inst)
    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return
    end

    PruneVortices(inst)
    local count = TUNING.KEI_RECORDER_MOOSE_VORTEX_COUNT or 4
    local recorder_x, _, recorder_z = source.Transform:GetWorldPosition()
    -- Rotate the fixed layout by 90 degrees clockwise after each cast.
    local base_rotation = inst.kei_recorder_moose_vortex_rotation or 0
    local distance = TUNING.KEI_RECORDER_MOOSE_VORTEX_SPAWN_DISTANCE or 16
    for direction = 0, count - 1 do
        local angle = base_rotation + direction * (TWOPI / count)
        local x = recorder_x + math.cos(angle) * distance
        local z = recorder_z - math.sin(angle) * distance
        local vortex = SpawnPrefab(VORTEX_PREFAB)
        if vortex ~= nil then
            vortex.kei_recorder_source = source
            vortex.Transform:SetRotation(0)
            vortex.Transform:SetPosition(x, 0, z)
            table.insert(inst.kei_recorder_moose_vortices, vortex)

            source.kei_target_support_entities = source.kei_target_support_entities or {}
            table.insert(source.kei_target_support_entities, vortex)
        end
    end
    inst.kei_recorder_moose_vortex_rotation =
        (base_rotation + CLOCKWISE_ROTATION_STEP) % TWOPI
end

local function CanUseVortex(inst)
    return IsLiving(inst)
        and inst.kei_recorder_source ~= nil
        and inst.kei_recorder_source:IsValid()
        and inst.sg ~= nil
        and not inst.sg:HasAnyStateTag("busy", "flight", "frozen", "electrocute")
        and (inst.kei_recorder_moose_vortex_remaining or 0) <= 0
end

local function TryUseVortex(inst)
    if not CanUseVortex(inst) then
        return
    end

    SpawnVortices(inst)
    -- Subsequent casts observe the configured one-minute cooldown.
    inst.kei_recorder_moose_vortex_remaining = COOLDOWN

    -- The vanilla taunt is the wing-flapping action and does not perform an
    -- attack. The vortex effect is intentionally created before the animation.
    if inst.sg:HasState("taunt") then
        inst.sg:GoToState("taunt")
    end
end

function RecorderMoose.Apply(inst)
    if not IsLiving(inst) then
        return false
    end

    RecorderMoose.Remove(inst)
    inst.kei_recorder_moose_speed_players = {}
    inst.kei_recorder_moose_vortices = {}
    inst.kei_recorder_moose_vortex_rotation = 0
    -- The first cast is ready when the recorder moose is created.
    inst.kei_recorder_moose_vortex_remaining = 0
    UpdateMoistureSpeed(inst)

    inst.kei_recorder_moose_task = inst:DoPeriodicTask(COOLDOWN_TICK, function(moose)
        if not moose:IsValid() then
            return
        end

        if not UpdateMoistureSpeed(moose) then
            RecorderMoose.Remove(moose)
            return
        end

        moose.kei_recorder_moose_vortex_remaining = math.max(
            0,
            (moose.kei_recorder_moose_vortex_remaining or 0) - COOLDOWN_TICK
        )
        TryUseVortex(moose)
    end)
    return true
end

function RecorderMoose.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_moose_task ~= nil then
        inst.kei_recorder_moose_task:Cancel()
        inst.kei_recorder_moose_task = nil
    end

    for player in pairs(inst.kei_recorder_moose_speed_players or {}) do
        RemovePlayerSpeed(inst, player)
    end
    inst.kei_recorder_moose_speed_players = nil

    for _, vortex in ipairs(inst.kei_recorder_moose_vortices or {}) do
        if vortex ~= nil and vortex:IsValid() then
            vortex:Remove()
        end
    end
    inst.kei_recorder_moose_vortices = nil
    inst.kei_recorder_moose_vortex_remaining = nil
end

return RecorderMoose
