require("prefabutil")
local CombatProtocolDefs = require("kei/protocols/combat")
local TaskSummon = require("kei/task_summon")
local RecorderBoss = require("kei/recorder_boss")
local RecorderDragonfly = require("kei/recorder_dragonfly")
local RecorderEyeOfTerror = require("kei/recorder_eyeofterror")
local RecorderBearger = require("kei/recorder_bearger")
local RecorderBeeQueen = require("kei/recorder_beequeen")
local RecorderDeerclops = require("kei/recorder_deerclops")
local RecorderDaywalker = require("kei/recorder_daywalker")
local RecorderDaywalker2 = require("kei/recorder_daywalker2")

local assets = {
    Asset("ANIM", "anim/kei_data_recorder.zip"),
    Asset("ANIM", "anim/wx78_shadowdrone_debuffer.zip"),
    Asset("ANIM", "anim/wx78_shadowdrone_harvester.zip"),
}

local item_assets = {
    Asset("ANIM", "anim/kei_items.zip"),
    Asset("ATLAS", "images/inventoryimages/kei_items.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_items.tex"),
}

local RECORDER_BANK = "kei_data_recorder"
local RECORDER_BUILD = "kei_data_recorder"
local RECORDER_ANIM_OFF = "closed"
local RECORDER_ANIM_OFF_APPEAR = "closed"
local RECORDER_ANIM_ON = "opened"
local RECORDER_ANIM_ACTIVATE = "opened"
local RECORDER_ANIM_DEACTIVATE = "closed"
local RECORDER_WORLD_SCALE = 1
local RECORDER_SHADER_CUTOFF_HEIGHT = -0.125
local RECORDER_DISSOLVE_DURATION = 1.0
local RECORDER_NO_PLAYERS_CHECK_PERIOD = TUNING.KEI_RECORDER_NO_PLAYERS_CHECK_PERIOD or 3

local RECORDER_KIT_BANK = "kei_item"
local RECORDER_KIT_BUILD = "kei_items"
local RECORDER_KIT_ANIM = "kei_data_recorder_item_ground"
local RECORDER_SUMMON_DELAY = 3
local GetRecorderChallenge = CombatProtocolDefs.GetRecorderChallenge

local function GetCombatProtocolFromItem(item)
    if item == nil then
        return nil
    end
    return item.kei_combat_protocol
        or (CombatProtocolDefs.COMBAT_PROTOCOL_PREFABS ~= nil
            and CombatProtocolDefs.COMBAT_PROTOCOL_PREFABS[item.prefab]
            or nil)
end

local RECORDER_STATE = {
    idle = 0,
    recording = 1,
    complete = 2,
}

local RECORD_DRONE_COUNT = 3
local RECORD_DRONE_BASE_RADIUS = 3
local RECORD_DRONE_ROTATE_SPEED = 0.45
local CancelNoPlayersCheck

local function Say(doer, key)
    -- 记录仪动作的反馈仍由操作者 Kei 说出。
    if doer ~= nil and doer.components.talker ~= nil and STRINGS.CHARACTERS.KEI[key] ~= nil then
        doer.components.talker:Say(STRINGS.CHARACTERS.KEI[key])
    end
end

local function ClearRecordDrones(inst)
    if inst.kei_record_drones ~= nil then
        for _, drone in ipairs(inst.kei_record_drones) do
            if drone:IsValid() then
                drone:Remove()
            end
        end
        inst.kei_record_drones = nil
    end
end

local function SpawnRecordDrones(inst, target)
    ClearRecordDrones(inst)
    if target == nil or not target:IsValid() then
        return
    end

    inst.kei_record_drones = {}
    local base_angle = math.random() * TWOPI
    for i = 1, RECORD_DRONE_COUNT do
        local drone = SpawnPrefab("kei_record_drone")
        if drone ~= nil then
            drone:SetRecordTarget(target, i, base_angle)
            table.insert(inst.kei_record_drones, drone)
        end
    end
end

local function ClearForceField(inst)
    if inst.kei_forcefield_walls ~= nil then
        for _, wall in ipairs(inst.kei_forcefield_walls) do
            if wall:IsValid() then
                if wall.RetractWallWithJitter ~= nil then
                    wall:RetractWallWithJitter(0.4)
                    wall:DoTaskInTime(1, wall.Remove)
                else
                    wall:Remove()
                end
            end
        end
        inst.kei_forcefield_walls = nil
    end
    if inst.kei_forcefield_collision ~= nil and inst.kei_forcefield_collision:IsValid() then
        inst.kei_forcefield_collision:Remove()
        inst.kei_forcefield_collision = nil
    end
end

local function CreateForceField(inst)
    ClearForceField(inst)

    -- 力场资源不是所有服务器环境都提供；记录流程本身不应因此中断。
    if WAGPUNK_ARENA_COLLISION_DATA == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    inst.kei_forcefield_walls = {}
    for _, data in ipairs(WAGPUNK_ARENA_COLLISION_DATA) do
        local wall = SpawnPrefab("wagpunk_cagewall")
        if wall ~= nil then
            wall.persists = false
            wall.Transform:SetPosition(x + data[1], 0, z + data[2])
            wall.Transform:SetRotation(math.floor(data[3] / 90) * 90)
            wall.sfxlooper = data[4] or nil
            if wall.ExtendWallWithJitter ~= nil then
                wall:ExtendWallWithJitter(0.4)
            end
            table.insert(inst.kei_forcefield_walls, wall)
        end
    end

    inst.kei_forcefield_collision = SpawnPrefab("wagpunk_arena_collision")
    if inst.kei_forcefield_collision ~= nil then
        inst.kei_forcefield_collision.Transform:SetPosition(x, 0, z)
        inst.kei_forcefield_collision.Transform:SetRotation(0)
    end
end

local function SetRecorderState(inst, state)
    -- 记录仪状态同时驱动交互逻辑和动画表现。
    inst.kei_state = state
    if inst._kei_recorder_state ~= nil then
        inst._kei_recorder_state:set(RECORDER_STATE[state] or RECORDER_STATE.idle)
    end
    inst:RemoveTag("kei_recording")
    inst:RemoveTag("kei_record_complete")
    if state ~= "recording" then
        CancelNoPlayersCheck(inst)
    end
    if state == "recording" then
        inst:AddTag("kei_recording")
        inst.AnimState:PlayAnimation(RECORDER_ANIM_ACTIVATE)
        inst.AnimState:PushAnimation(RECORDER_ANIM_ON, true)
        CreateForceField(inst)
    elseif state == "complete" then
        inst:AddTag("kei_record_complete")
        inst.AnimState:PlayAnimation(RECORDER_ANIM_ON, true)
        ClearRecordDrones(inst)
        ClearForceField(inst)
    else
        inst.AnimState:PlayAnimation(RECORDER_ANIM_OFF, true)
        ClearRecordDrones(inst)
        ClearForceField(inst)
    end
end

local function CancelSummonTask(inst)
    if inst.kei_summon_task ~= nil then
        inst.kei_summon_task:Cancel()
        inst.kei_summon_task = nil
    end
end

CancelNoPlayersCheck = function(inst)
    if inst.kei_no_players_check_task ~= nil then
        inst.kei_no_players_check_task:Cancel()
        inst.kei_no_players_check_task = nil
    end
end

local function GiveProtocolCD(inst, doer, protocol)
    local cd_prefab = CombatProtocolDefs.GetProtocolPrefab(protocol)
    local cd = cd_prefab ~= nil and SpawnPrefab(cd_prefab) or nil
    if cd == nil then
        return false
    end

    if doer ~= nil and doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(cd, nil, doer:GetPosition())
    else
        cd.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    return true
end

local function ClearTargetListener(inst)
    -- 记录结束或中断时要解绑死亡监听，避免旧目标之后触发回调。
    if inst.kei_target ~= nil and inst.kei_target_death_fn ~= nil then
        inst:RemoveEventCallback("death", inst.kei_target_death_fn, inst.kei_target)
    end
    if inst.kei_target ~= nil and inst.kei_target_minhealth_fn ~= nil then
        inst:RemoveEventCallback("minhealth", inst.kei_target_minhealth_fn, inst.kei_target)
    end
    inst.kei_target = nil
    inst.kei_target_death_fn = nil
    inst.kei_target_minhealth_fn = nil
end

local function ClearOwnerListener(inst)
    local owner = inst.kei_recording_owner
    if owner ~= nil then
        if inst.kei_owner_death_fn ~= nil then
            inst:RemoveEventCallback("death", inst.kei_owner_death_fn, owner)
        end
        if inst.kei_owner_remove_fn ~= nil then
            inst:RemoveEventCallback("onremove", inst.kei_owner_remove_fn, owner)
        end
    end
    inst.kei_recording_owner = nil
    inst.kei_owner_death_fn = nil
    inst.kei_owner_remove_fn = nil
end

local function ClearChallengeSupport(inst)
    if inst.kei_target_support_entities ~= nil then
        for _, support in ipairs(inst.kei_target_support_entities) do
            if support ~= nil and support:IsValid() then
                support:Remove()
            end
        end
        inst.kei_target_support_entities = nil
    end
end

local StartRecorderDissolve

local function StopRecorderTransmission(target)
    if target == nil then
        return
    end
    if target.kei_recorder_transmission_task ~= nil then
        target.kei_recorder_transmission_task:Cancel()
        target.kei_recorder_transmission_task = nil
    end
    if target.AnimState ~= nil and target:IsValid() then
        target.AnimState:SetErosionParams(0, 0, 0)
    end
end

local function ClearChallengeTasks(target, reset_erosion)
    if target ~= nil then
        RecorderDragonfly.Remove(target)
        RecorderEyeOfTerror.Remove(target)
        RecorderBearger.Remove(target)
        RecorderBeeQueen.Remove(target)
        RecorderDeerclops.Remove(target)
        RecorderDaywalker.Remove(target)
        RecorderDaywalker2.Remove(target)
        RecorderBoss.Remove(target)
        TaskSummon.CleanupSpecialTarget(target)
        if target.kei_recorder_land_task ~= nil then
            target.kei_recorder_land_task:Cancel()
            target.kei_recorder_land_task = nil
        end
        if reset_erosion ~= false then
            StopRecorderTransmission(target)
        end
    end
end

local function ClearStaleRecorderDaywalkerEntities(inst)
    if inst == nil or not inst:IsValid() then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local stale_tags = {
        "kei_recorder_daywalker",
        "kei_recorder_daywalker2",
        "kei_recorder_junk_pile_big",
        "kei_recorder_pigelitefighter",
        "junkmob",
    }
    local stale_entities = TheSim:FindEntities(
        x,
        y,
        z,
        (TUNING.KEI_RECORDER_RANGE or 35) * 2,
        nil,
        { "INLIMBO" },
        stale_tags
    )

    for _, entity in ipairs(stale_entities) do
        if entity.kei_recorder_source == inst then
            if entity:HasTag("kei_recorder_daywalker")
                or entity:HasTag("kei_recorder_daywalker2")
            then
                ClearChallengeTasks(entity, false)
            end
            if entity:IsValid() then
                entity:Remove()
            end
        end
    end

    -- Also discard support references left by a previous interrupted spawn.
    ClearChallengeSupport(inst)
end

local function RemoveSummonedTarget(inst)
    local target = inst.kei_target
    ClearChallengeTasks(target, false)
    ClearOwnerListener(inst)
    ClearTargetListener(inst)
    ClearChallengeSupport(inst)
    if target ~= nil and target:IsValid() then
        StartRecorderDissolve(target)
    end
end

local function AggroRecorderChallenge(target, doer)
    if target ~= nil
        and target:IsValid()
        and target.components.combat ~= nil
        and doer ~= nil
        and doer:IsValid()
    then
        target.components.combat:SuggestTarget(doer)
    end
end

local function StartRecorderTransmission(target)
    if target == nil or target.AnimState == nil then
        return
    end

    local duration = 3.5
    local tick_time = math.max(TheSim:GetTickTime(), FRAMES)
    local elapsed = 0
    target.AnimState:SetErosionParams(1, RECORDER_SHADER_CUTOFF_HEIGHT, -1.0)
    target.kei_recorder_transmission_task = target:DoPeriodicTask(tick_time, function(inst)
        if not inst:IsValid() then
            return
        end

        elapsed = elapsed + tick_time
        local amount = math.max(0, 1 - elapsed / duration)
        inst.AnimState:SetErosionParams(amount, RECORDER_SHADER_CUTOFF_HEIGHT, -1.0)
        if amount <= 0 then
            StopRecorderTransmission(inst)
        end
    end)
end

-- 记录器强制删除 Boss 时先播放溶解消失，再移除实体，避免触发死亡奖励流程。
StartRecorderDissolve = function(target)
    if target == nil or not target:IsValid() then
        return
    end
    if target.kei_recorder_dissolving then
        return
    end
    target.kei_recorder_dissolving = true

    if target.kei_recorder_transmission_task ~= nil then
        target.kei_recorder_transmission_task:Cancel()
        target.kei_recorder_transmission_task = nil
    end
    if target.kei_recorder_dissolve_task ~= nil then
        target.kei_recorder_dissolve_task:Cancel()
        target.kei_recorder_dissolve_task = nil
    end

    if target.AnimState == nil then
        target:Remove()
        return
    end

    local tick_time = math.max(TheSim:GetTickTime(), FRAMES)
    local elapsed = 0
    target.AnimState:SetErosionParams(0, RECORDER_SHADER_CUTOFF_HEIGHT, -1.0)
    target.kei_recorder_dissolve_task = target:DoPeriodicTask(tick_time, function(inst)
        if not inst:IsValid() then
            return
        end

        elapsed = elapsed + tick_time
        local amount = math.min(1, elapsed / RECORDER_DISSOLVE_DURATION)
        inst.AnimState:SetErosionParams(amount, RECORDER_SHADER_CUTOFF_HEIGHT, -1.0)
        if amount >= 1 then
            if inst.kei_recorder_dissolve_task ~= nil then
                inst.kei_recorder_dissolve_task:Cancel()
                inst.kei_recorder_dissolve_task = nil
            end
            inst:Remove()
        end
    end)
end

local function PrepareRecorderChallenge(inst, target, doer)
    target.kei_recorder_spawned = true
    target.kei_recorder_source = inst

    RecorderBoss.Apply(target, inst)
    if target.prefab == "kei_recorder_dragonfly" then
        RecorderDragonfly.Apply(target)
    elseif target.prefab == "kei_recorder_eyeofterror" then
        RecorderEyeOfTerror.Apply(target)
    elseif target.prefab == "kei_recorder_bearger" then
        RecorderBearger.Apply(target)
    elseif target.prefab == "kei_recorder_daywalker" then
        RecorderDaywalker.Apply(target)
    end
    TaskSummon.PrepareSpecialTarget(target, doer, inst)

    StartRecorderTransmission(target)

    -- 初始仇恨指向召唤者，后续仍由原版 AI 处理换目标。
    AggroRecorderChallenge(target, doer)
    target:DoTaskInTime(0, function(inst)
        AggroRecorderChallenge(inst, doer)
    end)
end

local function AbortRecordingWithoutReward(inst)
    if inst.kei_state ~= "recording" then
        return
    end

    CancelSummonTask(inst)
    RemoveSummonedTarget(inst)
    inst.kei_recording_protocol = nil
    inst.kei_target_prefab = nil
    inst.kei_completed_protocol = nil
    SetRecorderState(inst, "idle")
end

local function WatchRecorderOwner(inst, owner)
    if owner == nil then
        return
    end

    inst.kei_recording_owner = owner
    inst.kei_owner_death_fn = function()
        AbortRecordingWithoutReward(inst)
    end
    inst.kei_owner_remove_fn = function()
        AbortRecordingWithoutReward(inst)
    end
    inst:ListenForEvent("death", inst.kei_owner_death_fn, owner)
    inst:ListenForEvent("onremove", inst.kei_owner_remove_fn, owner)
end

local function CompleteRecording(inst, target)
    -- 只有记录器召唤出的目标死亡，才会产出高级巨兽协议。
    if inst.kei_state ~= "recording" or target ~= inst.kei_target then
        return
    end

    local challenge = GetRecorderChallenge(inst.kei_recording_protocol)
    if challenge == nil then
        return
    end

    CancelSummonTask(inst)
    inst.kei_completed_protocol = challenge.advanced_protocol
    inst.kei_recording_protocol = nil
    ClearChallengeTasks(target)
    ClearOwnerListener(inst)
    ClearTargetListener(inst)
    ClearChallengeSupport(inst)
    SetRecorderState(inst, "complete")
    return true
end

local function SpawnRecorderChallenge(inst, doer)
    if inst.kei_state ~= "recording" or inst.kei_target ~= nil then
        return false
    end

    local challenge = GetRecorderChallenge(inst.kei_recording_protocol)
    if challenge == nil then
        return false
    end

    ClearStaleRecorderDaywalkerEntities(inst)

    local summon_prefab = challenge.summon_prefab == "dragonfly"
        and "kei_recorder_dragonfly"
        or challenge.summon_prefab == "deerclops"
        and "kei_recorder_deerclops"
        or challenge.summon_prefab == "eyeofterror"
        and "kei_recorder_eyeofterror"
        or challenge.summon_prefab == "bearger"
        and "kei_recorder_bearger"
        or challenge.summon_prefab == "beequeen"
        and "kei_recorder_beequeen"
        or challenge.summon_prefab == "daywalker"
        and "kei_recorder_daywalker"
        or challenge.summon_prefab == "daywalker2"
        and "kei_recorder_daywalker2"
        or challenge.summon_prefab
    local target = SpawnPrefab(summon_prefab)
    if target == nil then
        ClearOwnerListener(inst)
        GiveProtocolCD(inst, doer, challenge.basic_protocol)
        inst.kei_recording_protocol = nil
        SetRecorderState(inst, "idle")
        Say(doer, "ANNOUNCE_KEI_RECORD_STOPPED")
        return false
    end

    target.persists = false
    local x, y, z = inst.Transform:GetWorldPosition()
    if target.Physics ~= nil then
        target.Physics:Teleport(x, y, z)
    else
        target.Transform:SetPosition(x, y, z)
    end

    PrepareRecorderChallenge(inst, target, doer)

    inst.kei_target = target
    inst.kei_target_prefab = target.prefab
    inst.kei_target_death_fn = function(target_inst)
        if CompleteRecording(inst, target_inst) then
            Say(doer, "ANNOUNCE_KEI_RECORD_DONE")
        end
    end
    inst:ListenForEvent("death", inst.kei_target_death_fn, target)
    if target.prefab == "daywalker" or target.prefab == "daywalker2"
        or target.prefab == "kei_recorder_daywalker"
        or target.prefab == "kei_recorder_daywalker2"
    then
        inst.kei_target_minhealth_fn = function(target_inst)
            if CompleteRecording(inst, target_inst) then
                Say(doer, "ANNOUNCE_KEI_RECORD_DONE")
            end
        end
        inst:ListenForEvent("minhealth", inst.kei_target_minhealth_fn, target)
    end
    SpawnRecordDrones(inst, target)
    return true
end

local function StartKeiRecording(inst, cd, doer)
    -- 记录器只接受初级巨兽协议，不再接受空白 CD 或绑定目标。
    local protocol = GetCombatProtocolFromItem(cd)
    local challenge = GetRecorderChallenge(protocol)
    if inst.kei_state ~= "idle" or challenge == nil then
        return false
    end

    -- 提交成功后消耗初级协议，延迟三秒召唤对应巨兽。
    if cd.components.inventoryitem ~= nil and cd.components.inventoryitem.owner ~= nil then
        cd.components.inventoryitem:RemoveFromOwner(true)
    end
    cd:Remove()

    inst.kei_recording_protocol = challenge.basic_protocol
    WatchRecorderOwner(inst, doer)
    inst.kei_target_prefab = nil
    inst.kei_completed_protocol = nil
    SetRecorderState(inst, "recording")
    CancelNoPlayersCheck(inst)
    inst.kei_no_players_check_task = inst:DoPeriodicTask(
        RECORDER_NO_PLAYERS_CHECK_PERIOD,
        function(recorder)
            if recorder.kei_state ~= "recording" then
                CancelNoPlayersCheck(recorder)
                return
            end

            if #RecorderBoss.GetArenaPlayers(recorder) == 0 then
                recorder:StopKeiRecording(recorder.kei_recording_owner)
            end
        end
    )
    inst.kei_summon_task = inst:DoTaskInTime(RECORDER_SUMMON_DELAY, function()
        inst.kei_summon_task = nil
        SpawnRecorderChallenge(inst, doer)
    end)
    Say(doer, "ANNOUNCE_KEI_RECORDING")
    return true
end

local function StopKeiRecording(inst, doer)
    -- 主动停止记录会移除记录器召唤的巨兽，并返还原本的初级协议。
    if inst.kei_state ~= "recording" then
        return false
    end

    CancelNoPlayersCheck(inst)
    CancelSummonTask(inst)
    local protocol = inst.kei_recording_protocol
    RemoveSummonedTarget(inst)
    GiveProtocolCD(inst, doer, protocol)
    inst.kei_recording_protocol = nil
    inst.kei_target_prefab = nil
    inst.kei_completed_protocol = nil
    SetRecorderState(inst, "idle")
    Say(doer, "ANNOUNCE_KEI_RECORD_STOPPED")
    return true
end

local function HarvestKeiData(inst, doer)
    -- 收获时根据击败的巨兽生成高级巨兽协议 CD。
    if inst.kei_state ~= "complete" or inst.kei_completed_protocol == nil then
        return false
    end
    if not GiveProtocolCD(inst, doer, inst.kei_completed_protocol) then
        return false
    end
    inst.kei_completed_protocol = nil
    inst.kei_target_prefab = nil
    SetRecorderState(inst, "idle")
    return true
end

local function GiveRecorderKit(doer, x, y, z)
    local kit = SpawnPrefab("kei_data_recorder_item")
    if kit == nil then
        return false
    end
    if doer ~= nil and doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(kit, nil, Vector3(x, y, z))
    else
        kit.Transform:SetPosition(x, y, z)
    end
    return true
end

local function FinishPackUp(inst)
    if inst.kei_packup_task ~= nil then
        inst.kei_packup_task:Cancel()
        inst.kei_packup_task = nil
    end
    if inst.kei_packup_finish_fn ~= nil then
        inst:RemoveEventCallback("animqueueover", inst.kei_packup_finish_fn)
        inst.kei_packup_finish_fn = nil
    end
    if inst:IsValid() then
        inst:Remove()
    end
end

local function PlayPackUpAnimation(inst)
    inst.AnimState:PlayAnimation(RECORDER_ANIM_DEACTIVATE)
    inst.AnimState:PushAnimation(RECORDER_ANIM_OFF, false)

    inst.kei_packup_finish_fn = FinishPackUp
    inst:ListenForEvent("animqueueover", inst.kei_packup_finish_fn)
    inst.kei_packup_task = inst:DoTaskInTime(2, inst.kei_packup_finish_fn)
end

local function PackUpKeiRecorder(inst, doer)
    if inst.kei_state ~= "idle" or inst.kei_packing_up then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    if not GiveRecorderKit(doer, x, y, z) then
        return false
    end

    inst.kei_packing_up = true
    inst.persists = false
    inst:AddTag("NOCLICK")
    ClearRecordDrones(inst)
    ClearForceField(inst)
    CancelSummonTask(inst)
    ClearTargetListener(inst)
    PlayPackUpAnimation(inst)

    return true
end

local function OnHammered(inst)
    inst.components.workable:SetWorkLeft(999999)
    inst:PushEvent("workinghit")
end

local function OnHit(inst)
    inst:PushEvent("workinghit")
end

local function OnSave(inst, data)
    -- 记录中无法安全保存目标实体，因此读档后返还初级协议并回到 idle。
    data.kei_state = inst.kei_state
    data.kei_recording_protocol = inst.kei_recording_protocol
    data.kei_target_prefab = inst.kei_target_prefab
    data.kei_completed_protocol = inst.kei_completed_protocol
    data.return_recording_protocol = inst.kei_state == "recording"
        and inst.kei_recording_protocol
        or nil
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.kei_target_prefab = data.kei_target_prefab
        inst.kei_completed_protocol = data.kei_completed_protocol
        inst.kei_recording_protocol = nil
        SetRecorderState(inst, data.kei_state == "complete" and "complete" or "idle")
        if data.return_recording_protocol ~= nil then
            -- 延迟一帧生成，确保实体位置和世界状态已恢复。
            inst:DoTaskInTime(0, function()
                GiveProtocolCD(inst, nil, data.return_recording_protocol)
            end)
        end
    end
end

local function OnBuilt(inst)
    -- 部署完成但未提交 CD 时保持未激活外观。
    inst.AnimState:PlayAnimation(RECORDER_ANIM_OFF_APPEAR)
    inst.AnimState:PushAnimation(RECORDER_ANIM_OFF, true)
end

local function recorder_fn()
    local inst = CreateEntity()

    -- 记录仪是可部署结构，因此需要实体、声音、网络和八方向朝向。
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()
    inst.AnimState:SetBank(RECORDER_BANK)
    inst.AnimState:SetBuild(RECORDER_BUILD)
    inst.AnimState:SetScale(RECORDER_WORLD_SCALE, RECORDER_WORLD_SCALE, RECORDER_WORLD_SCALE)
    inst.AnimState:PlayAnimation(RECORDER_ANIM_OFF, true)

    inst:AddTag("structure")
    inst:AddTag("kei_data_recorder")

    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)
    inst._kei_recorder_state = net_tinybyte(inst.GUID, "kei_data_recorder._state", "kei_recorderstatedirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        -- 客户端只保留表现和标签，服务器负责状态机与交互。
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot({ "transistor" })

    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(999999)
    workable:SetOnFinishCallback(OnHammered)
    workable:SetOnWorkCallback(OnHit)

    inst.kei_state = "idle"
    -- 把记录仪交互函数挂到实例上，供 kei_actions.lua 的动作调用。
    inst.StartKeiRecording = StartKeiRecording
    inst.StopKeiRecording = StopKeiRecording
    inst.HarvestKeiData = HarvestKeiData
    inst.PackUpKeiRecorder = PackUpKeiRecorder

    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("onremove", ClearRecordDrones)
    inst:ListenForEvent("onremove", CancelSummonTask)
    inst:ListenForEvent("onremove", CancelNoPlayersCheck)
    inst:ListenForEvent("onremove", RemoveSummonedTarget)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

local function kit_postinit(inst)
    inst.components.inventoryitem.atlasname = "images/inventoryimages/kei_items.xml"
    inst.components.inventoryitem:ChangeImageName("kei_data_recorder_item")
end

local function UpdateRecordDronePosition(inst)
    local target = inst.kei_target
    if target == nil
        or not target:IsValid()
        or (target.components.health ~= nil and target.components.health:IsDead())
    then
        inst:Remove()
        return
    end

    local tx, ty, tz = target.Transform:GetWorldPosition()
    local radius = math.max(RECORD_DRONE_BASE_RADIUS, target:GetPhysicsRadius(0) + 2)
    local angle = (inst.kei_base_angle or 0)
        + GetTime() * RECORD_DRONE_ROTATE_SPEED
        + ((inst.kei_index or 1) - 1) * TWOPI / RECORD_DRONE_COUNT

    inst.Transform:SetPosition(tx + math.cos(angle) * radius, 0, tz + math.sin(angle) * radius)
    inst:FacePoint(tx, ty, tz)
end

local function RecordDroneOnRemove(inst)
    if inst.kei_target ~= nil and inst.kei_target_removed_fn ~= nil then
        inst:RemoveEventCallback("onremove", inst.kei_target_removed_fn, inst.kei_target)
    end
    inst.kei_target = nil
    inst.kei_target_removed_fn = nil
    if inst.kei_orbit_task ~= nil then
        inst.kei_orbit_task:Cancel()
        inst.kei_orbit_task = nil
    end
end

local function SetRecordTarget(inst, target, index, base_angle)
    RecordDroneOnRemove(inst)
    inst.kei_target = target
    inst.kei_index = index or 1
    inst.kei_base_angle = base_angle or 0
    inst.kei_target_removed_fn = function()
        if inst:IsValid() then
            inst:Remove()
        end
    end
    inst:ListenForEvent("onremove", inst.kei_target_removed_fn, target)
    UpdateRecordDronePosition(inst)
    inst.kei_orbit_task = inst:DoPeriodicTask(FRAMES, UpdateRecordDronePosition)
end

local function CreateRecordDroneShadowFx()
    local inst = CreateEntity()

    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst.AnimState:SetBank("wx78_shadowdrone_harvester")
    inst.AnimState:SetBuild("wx78_shadowdrone_harvester")
    inst.AnimState:PlayAnimation("fx_shadow_loop", true)
    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.AnimState:UsePointFiltering(true)

    return inst
end

local function record_drone_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()
    inst.DynamicShadow:SetSize(1.2, 0.75)

    inst.AnimState:SetBank("wx78_shadowdrone_debuffer")
    inst.AnimState:SetBuild("wx78_shadowdrone_debuffer")
    inst.AnimState:PlayAnimation("debuffscan_pre")
    inst.AnimState:PushAnimation("debuffscan_loop", true)
    inst.AnimState:SetSymbolLightOverride("fx_scan_parts", 0.15)
    inst.AnimState:OverrideSymbol("wx78_shadow_explode", "wx78_shadowdrone_harvester", "wx78_shadow_explode")

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("flying")
    inst:AddTag("shadow_aligned")
    inst:AddTag("kei_record_drone")

    if not TheNet:IsDedicated() then
        inst.fx = CreateRecordDroneShadowFx()
        inst.fx.entity:SetParent(inst.entity)
        inst.fx.Follower:FollowSymbol(inst.GUID, "FOLLOW_SHADOW", 0, 0, 0, true)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.SetRecordTarget = SetRecordTarget
    inst.OnRemoveEntity = RecordDroneOnRemove

    return inst
end

-- 同时返回结构 prefab、部署包 prefab 和 placer。
local prefab_deps = {
    "kei_record_drone",
    "wagpunk_cagewall",
    "wagpunk_arena_collision",
    "junk_pile_big",
    "kei_recorder_daywalker",
    "kei_recorder_daywalker2",
    "kei_recorder_junk_pile_big",
    "kei_recorder_pigelitefighter1",
    "kei_recorder_pigelitefighter2",
    "kei_recorder_pigelitefighter3",
    "kei_recorder_pigelitefighter4",
    "propsign",
}
for _, def in ipairs(CombatProtocolDefs.COMBAT_PROTOCOL_LIST) do
    table.insert(prefab_deps, def.prefab)
end

return Prefab("kei_data_recorder", recorder_fn, assets, prefab_deps),
    Prefab("kei_record_drone", record_drone_fn, assets),
    MakeDeployableKitItem(
        "kei_data_recorder_item",
        "kei_data_recorder",
        RECORDER_KIT_BANK,
        RECORDER_KIT_BUILD,
        RECORDER_KIT_ANIM,
        item_assets,
        { size = "small", y_offset = nil, scale = 0.8 },
        { "kei_data_recorder_item" },
        nil,
        { deploymode = DEPLOYMODE.DEFAULT, deployspacing = DEPLOYSPACING.DEFAULT },
        nil,
        kit_postinit
    ),
    MakePlacer("kei_data_recorder_item_placer", RECORDER_BANK, RECORDER_BUILD, RECORDER_ANIM_OFF, false, nil, nil, nil, nil, "eight")
