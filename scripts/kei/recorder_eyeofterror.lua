local RecorderBoss = require("kei/recorder_boss")

local GAZE_LOCK_KEY = "kei_recorder_eyeofterror_gaze"
local GAZE_FX_PREFAB = "ghostlyelixir_player_shadow_fx"
local GAZE_RANGE = TUNING.KEI_RECORDER_EYEOFTERROR_GAZE_RANGE or 12
local GAZE_HALF_ANGLE = (TUNING.KEI_RECORDER_EYEOFTERROR_GAZE_HALF_ANGLE or 45) * DEGREES
local GAZE_UPDATE_PERIOD = 0.1

local RecorderEyeOfTerror = {}

local function RemoveGazeFX(inst, player)
    local effects = inst.kei_recorder_eyeofterror_gaze_fxs
    local fx = effects ~= nil and effects[player] or nil
    if effects ~= nil then
        effects[player] = nil
    end
    if fx ~= nil and fx:IsValid() then
        fx:Remove()
    end
end

local function SpawnGazeFX(inst, player)
    local effects = inst.kei_recorder_eyeofterror_gaze_fxs
    if effects == nil or effects[player] ~= nil then
        return
    end

    local fx = SpawnPrefab(GAZE_FX_PREFAB)
    if fx ~= nil then
        player:AddChild(fx)
        effects[player] = fx
    end
end

local function ClearLockedPlayers(inst)
    for player in pairs(inst.kei_recorder_eyeofterror_locked_players or {}) do
        if player:IsValid()
            and player.components ~= nil
            and player.components.locomotor ~= nil
        then
            player.components.locomotor:RemoveExternalSpeedMultiplier(inst, GAZE_LOCK_KEY)
        end
        RemoveGazeFX(inst, player)
    end
    inst.kei_recorder_eyeofterror_locked_players = {}
    inst.kei_recorder_eyeofterror_gaze_fxs = {}
end

local function IsInGaze(inst, player)
    local x, _, z = inst.Transform:GetWorldPosition()
    local px, _, pz = player.Transform:GetWorldPosition()
    local dx, dz = px - x, pz - z
    local distance_sq = dx * dx + dz * dz
    if distance_sq <= 0 or distance_sq > GAZE_RANGE * GAZE_RANGE then
        return false
    end

    local distance = math.sqrt(distance_sq)
    local facing = inst.Transform:GetRotation() * DEGREES
    local forward_x = math.cos(facing)
    local forward_z = -math.sin(facing)
    local direction_dot = (dx * forward_x + dz * forward_z) / distance
    return direction_dot >= math.cos(GAZE_HALF_ANGLE)
end

local function UpdateGaze(inst)
    if not inst:IsValid() then
        return
    end

    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        RecorderEyeOfTerror.Remove(inst)
        return
    end

    local locked_players = inst.kei_recorder_eyeofterror_locked_players or {}
    local gaze_fxs = inst.kei_recorder_eyeofterror_gaze_fxs or {}
    local in_gaze = {}
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if IsInGaze(inst, player) and player.components.locomotor ~= nil then
            in_gaze[player] = true
            if not locked_players[player] then
                player.components.locomotor:StopMoving()
                SpawnGazeFX(inst, player)
            end
            player.components.locomotor:SetExternalSpeedMultiplier(inst, GAZE_LOCK_KEY, 0)
        end
    end

    for player in pairs(locked_players) do
        if not in_gaze[player]
            and player:IsValid()
            and player.components ~= nil
            and player.components.locomotor ~= nil
        then
            player.components.locomotor:RemoveExternalSpeedMultiplier(inst, GAZE_LOCK_KEY)
            RemoveGazeFX(inst, player)
        end
    end

    inst.kei_recorder_eyeofterror_locked_players = in_gaze
    inst.kei_recorder_eyeofterror_gaze_fxs = gaze_fxs
end

function RecorderEyeOfTerror.Apply(inst)
    RecorderEyeOfTerror.Remove(inst)
    inst.kei_recorder_eyeofterror_locked_players = {}
    inst.kei_recorder_eyeofterror_gaze_fxs = {}
    inst.kei_recorder_eyeofterror_gaze_task = inst:DoPeriodicTask(
        GAZE_UPDATE_PERIOD,
        UpdateGaze
    )
end

function RecorderEyeOfTerror.Remove(inst)
    if inst == nil then
        return
    end
    if inst.kei_recorder_eyeofterror_gaze_task ~= nil then
        inst.kei_recorder_eyeofterror_gaze_task:Cancel()
        inst.kei_recorder_eyeofterror_gaze_task = nil
    end
    ClearLockedPlayers(inst)
end

return RecorderEyeOfTerror
