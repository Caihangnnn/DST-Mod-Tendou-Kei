local assets = {
    Asset("ANIM", "anim/honey_trail.zip"),
}

local TRAIL_SPEED_KEY = "kei_recorder_green_honey_trail"
local TRAIL_UPDATE_PERIOD = 0.25

local function IsValidPlayer(player)
    return player ~= nil
        and player:IsValid()
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and not player:HasTag("INLIMBO")
        and player.components ~= nil
        and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local function RemovePlayerEffect(inst, player)
    if player ~= nil and player:IsValid() and player.components ~= nil then
        if player.components.locomotor ~= nil then
            player.components.locomotor:RemoveExternalSpeedMultiplier(inst, TRAIL_SPEED_KEY)
        end
    end
    inst.affected_players[player] = nil
    inst.next_damage_time[player] = nil
end

local function ApplyPlayerEffect(inst, player)
    if not IsValidPlayer(player) then
        RemovePlayerEffect(inst, player)
        return
    end

    if player.components.locomotor ~= nil then
        player.components.locomotor:SetExternalSpeedMultiplier(
            inst,
            TRAIL_SPEED_KEY,
            TUNING.KEI_RECORDER_BEEGUARD_TRAIL_SPEED_MULT or 0.5
        )
    end
    inst.affected_players[player] = true

    local now = GetTime()
    if inst.next_damage_time[player] == nil or now >= inst.next_damage_time[player] then
        player.components.health:DoDelta(
            -(TUNING.KEI_RECORDER_BEEGUARD_TRAIL_DAMAGE or 10),
            true,
            "kei_recorder_green_honey_trail",
            nil,
            inst
        )
        inst.next_damage_time[player] = now + (TUNING.KEI_RECORDER_BEEGUARD_TRAIL_DAMAGE_INTERVAL or 1)
    end
end

local function UpdateServer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = TUNING.KEI_RECORDER_BEEGUARD_TRAIL_RADIUS or 2.5
    local current_players = {}

    for _, player in ipairs(TheSim:FindEntities(x, y, z, radius, { "player" }, { "playerghost", "INLIMBO" })) do
        if IsValidPlayer(player) then
            current_players[player] = true
            ApplyPlayerEffect(inst, player)
        end
    end

    for player in pairs(inst.affected_players) do
        if not current_players[player] then
            RemovePlayerEffect(inst, player)
        end
    end
end

local function UpdateClient(inst)
    local player = ThePlayer
    local radius = TUNING.KEI_RECORDER_BEEGUARD_TRAIL_RADIUS or 2.5
    local in_range = IsValidPlayer(player)
        and player:GetDistanceSqToPoint(inst.Transform:GetWorldPosition()) <= radius * radius

    if in_range then
        if player.components.locomotor ~= nil then
            player.components.locomotor:SetExternalSpeedMultiplier(
                inst,
                TRAIL_SPEED_KEY,
                TUNING.KEI_RECORDER_BEEGUARD_TRAIL_SPEED_MULT or 0.5
            )
        end
    elseif inst.client_player ~= nil then
        if inst.client_player:IsValid() then
            if inst.client_player.components.locomotor ~= nil then
                inst.client_player.components.locomotor:RemoveExternalSpeedMultiplier(inst, TRAIL_SPEED_KEY)
            end
        end
        inst.client_player = nil
    end

    if in_range then
        inst.client_player = player
    end
end

local function Cleanup(inst)
    if inst.update_task ~= nil then
        inst.update_task:Cancel()
        inst.update_task = nil
    end
    if inst.fade_task ~= nil then
        inst.fade_task:Cancel()
        inst.fade_task = nil
    end

    if TheWorld.ismastersim then
        for player in pairs(inst.affected_players) do
            RemovePlayerEffect(inst, player)
        end
    elseif inst.client_player ~= nil then
        local player = inst.client_player
        if player:IsValid() and player.components ~= nil and player.components.locomotor ~= nil then
            player.components.locomotor:RemoveExternalSpeedMultiplier(inst, TRAIL_SPEED_KEY)
        end
        inst.client_player = nil
    end
end

local function BeginFade(inst)
    inst.fade_task = nil
    if inst:IsValid() and inst.trailname ~= nil then
        inst.AnimState:PlayAnimation(inst.trailname .. "_pst")
    end
end

local function OnAnimOver(inst)
    if inst.trailname == nil then
        return
    elseif inst.AnimState:IsCurrentAnimation(inst.trailname .. "_pre") then
        inst.AnimState:PlayAnimation(inst.trailname)
    elseif inst.AnimState:IsCurrentAnimation(inst.trailname .. "_pst") then
        inst:Remove()
    end
end

local function SetVariation(inst, rand, scale, duration)
    if inst.trailname ~= nil then
        return
    end

    if inst.remove_task ~= nil then
        inst.remove_task:Cancel()
        inst.remove_task = nil
    end
    inst.Transform:SetScale(scale or 1, scale or 1, scale or 1)
    inst.trailname = "trail" .. tostring(math.clamp(tonumber(rand) or 1, 1, 7))
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/honey_drip")
    inst.AnimState:PlayAnimation(inst.trailname .. "_pre")
    inst.fade_task = inst:DoTaskInTime(duration or 240, BeginFade)
    if TheWorld.ismastersim then
        UpdateServer(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst.AnimState:SetBank("honey_trail")
    inst.AnimState:SetBuild("honey_trail")
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetMultColour(0.2, 1, 0.2, 1)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst.client_player = nil
        inst.update_task = inst:DoPeriodicTask(TRAIL_UPDATE_PERIOD, UpdateClient, 0)
        inst:ListenForEvent("onremove", Cleanup)
        inst:ListenForEvent("animover", OnAnimOver)
        return inst
    end

    inst.persists = false
    inst.affected_players = {}
    inst.next_damage_time = {}
    inst.update_task = inst:DoPeriodicTask(TRAIL_UPDATE_PERIOD, UpdateServer, 0)
    inst:ListenForEvent("onremove", Cleanup)
    inst:ListenForEvent("animover", OnAnimOver)
    inst.SetVariation = SetVariation
    inst.remove_task = inst:DoTaskInTime(0, inst.Remove)

    return inst
end

return Prefab("kei_recorder_green_honey_trail", fn, assets)
