local assets = {
    Asset("ANIM", "anim/sleepcloud.zip"),
    Asset("ANIM", "anim/sporecloud_base.zip"),
}

local prefabs = {
    "sleepcloud_overlay",
    "kei_recorder_sporecloud_fx",
}

local RecorderBoss = require("kei/recorder/boss")
local CLOUD_RADIUS = 3.5
local DROWSY_INTERVAL = 1
local DROWSY_VALUE = 1
local DROWSY_TIME = 4

local function DoRecorderDrowsy(inst)
    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() or source.kei_state ~= "recording" then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local radius_sq = CLOUD_RADIUS * CLOUD_RADIUS
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if player:IsValid()
            and player.components ~= nil
            and player.components.health ~= nil
            and not player.components.health:IsDead()
            and inst:GetDistanceSqToPoint(player.Transform:GetWorldPosition()) <= radius_sq
        then
            if player.components.grogginess ~= nil then
                player.components.grogginess:AddGrogginess(DROWSY_VALUE, DROWSY_TIME)
            elseif player.components.sleeper ~= nil then
                player.components.sleeper:AddSleepiness(DROWSY_VALUE, DROWSY_TIME)
            end
        end
    end
end

local function BeginDisperse(inst, immediate)
    if not inst:IsValid() then
        return
    end

    if immediate then
        if inst._recorder_disperse_task ~= nil then
            inst._recorder_disperse_task:Cancel()
            inst._recorder_disperse_task = nil
        end
        inst:Remove()
        return
    end

    if inst._recorder_dispersing then
        return
    end
    inst._recorder_dispersing = true

    local x, y, z = inst.Transform:GetWorldPosition()

    -- Remove the networked gameplay cloud first. A separate visual-only FX
    -- avoids sleepcloud's state dirty callback switching the cloud back to
    -- its loop animation for a frame after the disperse animation.
    inst:Remove()

    local fx = SpawnPrefab("kei_recorder_sporecloud_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
end

local function fn(sim)
    local original = Prefabs["sleepcloud"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_sporecloud")
    inst:SetPrefabNameOverride("sleepcloud")
    inst:AddTag("kei_recorder_sporecloud")
    inst:AddTag("kei_recorder_support")
    inst.persists = false

    if TheWorld.ismastersim then
        -- The cloud is owned by its recorder sprout, so it must not disperse
        -- on the normal sleepbomb timer. Its effect ticks once per second.
        if inst.components.timer ~= nil then
            inst.components.timer:StopTimer("disperse")
        end
        if inst._drowsytask ~= nil then
            inst._drowsytask:Cancel()
        end
        inst._drowsytask = inst:DoPeriodicTask(DROWSY_INTERVAL, DoRecorderDrowsy)
        inst.BeginDisperse = BeginDisperse
    end

    return inst
end

return Prefab("kei_recorder_sporecloud", fn, assets, prefabs)
