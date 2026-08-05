-- 旋翼调查仪控制器状态图：按 cookbook 的持续阅读状态管理操控动作。

local CONTROLLER_TAG = "kei_rotor_survey_controller"
local RotorSurveyRegistry = require("kei/rotor_survey_registry")
local RotorUpgrades = require("kei/rotor_upgrades")
local CONTROL_PRE = "kei_rotor_control_pre"
local CONTROL_LOOP = "kei_rotor_control_loop"
local CONTROL_STOP = "kei_rotor_control_stop"
local PILOT_ACTION = "kei_rotor_drone_pilot_action"
local PILOT_LOOP = "kei_rotor_drone_pilot"
local PILOT_WHEEL = "kei_rotor_drone_pilot_wheel"
local PILOT_STOP = "kei_rotor_drone_pilot_stop"

local REMOTE_USE_PRE = "drone_zap_remote_use_pre"
local REMOTE_USE_LOOP = "drone_zap_remote_use_loop"
local REMOTE_USE_PST = "drone_zap_remote_use_pst"

local CONTROL_START_TIMEOUT = 4
local CONTROL_LOOP_TIMEOUT = 60
local PILOT_WHEEL_TIMEOUT = 60
local ROTOR_RPC_NAMESPACE = "TendouKei"
local ROTOR_CAMERA_START_RPC = "StartRotorPilotCamera"
local ROTOR_CAMERA_STOP_RPC = "StopRotorPilotCamera"

local function IsController(item)
    return item ~= nil and item:HasTag(CONTROLLER_TAG)
end

local function IsControllerOwnedBy(controller, player)
    if not IsController(controller) or player == nil then
        return false
    end

    if controller.components ~= nil and controller.components.inventoryitem ~= nil then
        return controller.components.inventoryitem:GetGrandOwner() == player
    end

    return controller.replica ~= nil
        and controller.replica.inventoryitem ~= nil
        and controller.replica.inventoryitem:IsGrandOwner(player)
end

local function RememberController(inst, controller)
    if IsControllerOwnedBy(controller, inst) then
        inst._kei_rotor_controller = controller
        return true
    end
    return false
end

local function GetOwnedController(inst)
    local controller = inst ~= nil and inst._kei_rotor_controller or nil
    return IsControllerOwnedBy(controller, inst) and controller or nil
end

local function GetPilotController(inst)
    local inventory = inst ~= nil and inst.components ~= nil
        and inst.components.inventory or nil
    if inventory == nil and inst ~= nil and inst.replica ~= nil then
        inventory = inst.replica.inventory
    end
    if inventory ~= nil and inventory.GetEquippedItem ~= nil then
        local equipped = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if IsController(equipped) then
            return equipped
        end
    end

    local controller = GetOwnedController(inst)
    if controller ~= nil then
        return controller
    end
    return RotorSurveyRegistry.FindControllerInOwner(inst)
end

local function GetPilotDrone(inst)
    if inst == nil then
        return nil
    end

    if inst._kei_rotor_pilot_drone ~= nil and inst._kei_rotor_pilot_drone:IsValid() then
        return inst._kei_rotor_pilot_drone
    end

    local controller = GetPilotController(inst)
    if controller ~= nil and controller._kei_linked_drone_net ~= nil then
        local drone = controller._kei_linked_drone_net:value()
        if drone ~= nil and drone:IsValid() then
            return drone
        end
    end

    if TheWorld ~= nil and TheWorld.ismastersim and inst.userid ~= nil then
        return RotorSurveyRegistry.Find(inst.userid, function(candidate)
            return candidate._kei_drone_owner == inst
        end)
    end
end

AddModRPCHandler(ROTOR_RPC_NAMESPACE, "MoveRotorPilot", function(player, dir, auto_drive)
    if player == nil
        or not player:HasTag("kei")
        or player._kei_rotor_pilot_drone == nil
        or not player._kei_rotor_pilot_drone:IsValid()
        or player._kei_rotor_pilot_drone._kei_drone_pilot ~= player
    then
        return
    end

    if dir ~= false and (type(dir) ~= "number" or dir ~= dir or math.abs(dir) > 360) then
        return
    end
    if auto_drive ~= nil and type(auto_drive) ~= "boolean" then
        return
    end

    player._kei_rotor_pilot_drone:PushEventImmediate("locomote", {
        dir = dir ~= false and dir or nil,
        auto_drive = auto_drive == true,
    })
end)

local function IsPilotState(inst)
    local state = inst ~= nil and inst.sg ~= nil and inst.sg.currentstate or nil
    local name = state ~= nil and state.name or nil
    return name == PILOT_ACTION or name == PILOT_LOOP or name == PILOT_WHEEL
end

local function IsLocalPlayer(inst)
    if ThePlayer == nil or inst == nil then
        return false
    end

    -- 状态图中的客户端实体与 ThePlayer 通常是同一引用，但重连和状态同步期间
    -- 可能只保证 userid 一致。使用两者兼容，避免驾驶相机因为引用不同而不生效。
    return inst == ThePlayer
        or (inst.userid ~= nil and ThePlayer.userid ~= nil and inst.userid == ThePlayer.userid)
end

local function ApplyPilotCameraTarget(drone, camera)
    camera = camera or TheCamera
    if drone == nil or not drone:IsValid() or camera == nil then
        return false
    end

    -- 参考 ob 的相机实现直接替换 target。SetTarget 只在目标发生变化时调用，
    -- 这样不会反复重置镜头的平滑位置，同时手动同步 targetpos 以立即锁定无人机。
    if camera.target ~= drone then
        camera:SetTarget(drone)
    end

    return true
end

local function StartPilotCamera(inst, drone)
    if TheWorld.ismastersim then
        if inst ~= nil
            and inst.userid ~= nil
            and drone ~= nil
            and drone:IsValid()
            and drone.Network ~= nil
            and not inst._kei_rotor_camera_rpc_active
        then
            inst._kei_rotor_camera_rpc_active = true
            SendModRPCToClient(
                GetClientModRPC(ROTOR_RPC_NAMESPACE, ROTOR_CAMERA_START_RPC),
                inst.userid,
                drone.Network:GetNetworkID()
            )
        end
        return
    end

    if false then
        if not IsLocalPlayer(inst) or drone == nil or not drone:IsValid() then
        return
        end

    if TheNet ~= nil and TheNet:IsDedicated() then
        return
    end

    inst._kei_rotor_camera_drone = drone
    if inst._kei_rotor_camera_task ~= nil then
        inst._kei_rotor_camera_task:Cancel()
        inst._kei_rotor_camera_task = nil
    end

    ApplyPilotCameraTarget(drone)

    -- 驾驶状态的客户端状态图可能被同步、地图界面或其他相机逻辑刷新。
    -- 持续维护目标，保证镜头真正跟随无人机，而不是只改变一次高度后仍跟随 Kei。
    inst._kei_rotor_camera_task = inst:DoPeriodicTask(PILOT_CAMERA_REFRESH, function(owner)
        local target = owner._kei_rotor_camera_drone
        if target == nil or not target:IsValid() or not IsLocalPlayer(owner) then
            if owner._kei_rotor_camera_task ~= nil then
                owner._kei_rotor_camera_task:Cancel()
                owner._kei_rotor_camera_task = nil
            end
            return
        end
        ApplyPilotCameraTarget(target)
        end)
    end
end

local function StopPilotCamera(inst)
    if TheWorld.ismastersim then
        if inst ~= nil and inst.userid ~= nil and inst._kei_rotor_camera_rpc_active then
            SendModRPCToClient(
                GetClientModRPC(ROTOR_RPC_NAMESPACE, ROTOR_CAMERA_STOP_RPC),
                inst.userid
            )
            inst._kei_rotor_camera_rpc_active = nil
        end
        return
    end

    if false then
        if inst ~= nil and inst._kei_rotor_camera_task ~= nil then
        inst._kei_rotor_camera_task:Cancel()
        inst._kei_rotor_camera_task = nil
        end
    if inst ~= nil then
        inst._kei_rotor_camera_drone = nil
    end

    if not IsLocalPlayer(inst) or (TheNet ~= nil and TheNet:IsDedicated()) or TheCamera == nil then
        return
    end

    local player = ThePlayer or inst
    TheCamera:SetTarget(player)
    TheCamera.targetoffset.x = 0
    TheCamera.targetoffset.y = 1.5
    TheCamera.targetoffset.z = 0
    local x, y, z = player.Transform:GetWorldPosition()
    if x ~= nil and y ~= nil and z ~= nil then
        TheCamera.targetpos.x = x + TheCamera.targetoffset.x
        TheCamera.targetpos.y = y + TheCamera.targetoffset.y
        TheCamera.targetpos.z = z + TheCamera.targetoffset.z
    end
        RestorePilotCameraView(TheCamera)
    end
end

local function CancelRotorCameraTasks(player)
    if player == nil then
        return
    end
    if player._kei_rotor_camera_start_task ~= nil then
        player._kei_rotor_camera_start_task:Cancel()
        player._kei_rotor_camera_start_task = nil
    end
    if player._kei_rotor_camera_resolve_task ~= nil then
        player._kei_rotor_camera_resolve_task:Cancel()
        player._kei_rotor_camera_resolve_task = nil
    end
    if player._kei_rotor_input_task ~= nil then
        player._kei_rotor_input_task:Cancel()
        player._kei_rotor_input_task = nil
        if ThePlayer == player and MOD_RPC[ROTOR_RPC_NAMESPACE] ~= nil then
            SendModRPCToServer(MOD_RPC[ROTOR_RPC_NAMESPACE].MoveRotorPilot, false)
        end
    end
end

local function RestoreRotorCameraClient()
    local player = ThePlayer
    CancelRotorCameraTasks(player)
    if player ~= nil then
        player._kei_rotor_camera_drone = nil
    end

    if TheCamera == nil then
        return
    end

    TheCamera:SetTarget(TheFocalPoint or player)
end

local function FindRotorDroneByNetworkID(networkid)
    if ThePlayer == nil or networkid == nil then
        return nil
    end

    local x, y, z = ThePlayer.Transform:GetWorldPosition()
    -- 调查仪的飞行范围可配置到远大于默认实体搜索半径，搜索范围必须覆盖
    -- 无人机的最大飞行半径，否则无人机仍存在时客户端也会误判为已丢失。
    local radius = RotorUpgrades.GetControlRange(ThePlayer) + 32
    local ents = TheSim:FindEntities(x, y, z, radius)
    for _, ent in ipairs(ents) do
        if ent ~= nil
            and ent:IsValid()
            and ent:HasTag("kei_rotor_surveyor")
            and ent.Network ~= nil
            and ent.Network:GetNetworkID() == networkid
        then
            return ent
        end
    end
end

local function GetRotorInputDirection()
    if TheInput == nil or TheCamera == nil then
        return nil
    end

    -- 驾驶阶段只读取键盘状态，保证松开按键时能稳定得到空输入。
    local xdir = (TheInput:IsControlPressed(CONTROL_MOVE_RIGHT) and 1 or 0)
        - (TheInput:IsControlPressed(CONTROL_MOVE_LEFT) and 1 or 0)
    local ydir = (TheInput:IsControlPressed(CONTROL_MOVE_UP) and 1 or 0)
        - (TheInput:IsControlPressed(CONTROL_MOVE_DOWN) and 1 or 0)
    local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS or 0.05
    if math.abs(xdir) < deadzone and math.abs(ydir) < deadzone then
        return nil, nil
    end

    -- 与 fishing 的 clientcontrolpuppet 保持相同的相机坐标换算。
    -- 只取相机方向在地面的投影，避免相机俯仰角改变输入方向。
    local right = TheCamera:GetRightVec()
    local down = TheCamera:GetDownVec()
    local direction_x = right.x * xdir - down.x * ydir
    local direction_z = right.z * xdir - down.z * ydir
    local length = math.sqrt(direction_x * direction_x + direction_z * direction_z)
    if length <= 0.0001 then
        return nil, nil
    end

    direction_x = direction_x / length
    direction_z = direction_z / length
    local direction = -math.atan2(direction_z, direction_x) / DEGREES
    return direction, xdir + ydir * 3
end

local function StartRotorInputControl(player, drone)
    if player == nil or drone == nil then
        return
    end

    if player._kei_rotor_input_task ~= nil then
        player._kei_rotor_input_task:Cancel()
    end

    local last_dir = false
    local last_signature = nil
    local last_pressed_signature = nil
    local last_pressed_time = -math.huge
    local auto_drive = false
    local auto_drive_dir = nil
    local double_tap_time = 0.35
    local regular_move_heartbeat = 0.1
    local last_move_send_time = -math.huge

    local function SendMove(dir, is_auto, force)
        local rpc_dir = dir or false
        if not force
            and last_dir == rpc_dir
            and (not is_auto or auto_drive_dir == dir)
        then
            return
        end

        SendModRPCToServer(
            MOD_RPC[ROTOR_RPC_NAMESPACE].MoveRotorPilot,
            rpc_dir,
            is_auto == true
        )
        last_dir = rpc_dir
        auto_drive_dir = is_auto and dir or nil
        last_move_send_time = GetTime()
    end

    player._kei_rotor_input_task = player:DoPeriodicTask(FRAMES, function()
        if not IsLocalPlayer(player)
            or drone == nil
            or not drone:IsValid()
            or player._kei_rotor_camera_drone ~= drone
        then
            if player._kei_rotor_input_task ~= nil then
                player._kei_rotor_input_task:Cancel()
                player._kei_rotor_input_task = nil
            end
            if IsLocalPlayer(player) then
                SendModRPCToServer(MOD_RPC[ROTOR_RPC_NAMESPACE].MoveRotorPilot, false, false)
            end
            return
        end

        local dir, signature = GetRotorInputDirection()
        local now = GetTime()

        if signature ~= nil then
            if signature ~= last_signature then
                local is_double_tap = signature == last_pressed_signature
                    and now - last_pressed_time <= double_tap_time

                last_pressed_signature = signature
                last_pressed_time = now
                last_signature = signature

                if is_double_tap then
                    auto_drive = true
                    SendMove(dir, true)
                else
                    -- 普通按键会接管自动驾驶；按住时持续移动，松开后停止。
                    auto_drive = false
                    SendMove(dir, false)
                end
            elseif not auto_drive
                and last_dir ~= false
                and dir ~= nil
                and (math.abs(dir - last_dir) > 0.01
                    or now - last_move_send_time >= regular_move_heartbeat)
            then
                SendMove(dir, false, true)
            end
        else
            last_signature = nil
            if not auto_drive then
                SendMove(nil, false)
            end
        end
    end)
end

local function StartRotorCameraClient(networkid)
    local player = ThePlayer
    if player == nil or TheCamera == nil or networkid == nil then
        return
    end

    CancelRotorCameraTasks(player)
    player._kei_rotor_camera_generation = (player._kei_rotor_camera_generation or 0) + 1
    local generation = player._kei_rotor_camera_generation
    local attempts = 0

    local function ResolveDrone()
        if not IsLocalPlayer(player) or generation ~= player._kei_rotor_camera_generation then
            CancelRotorCameraTasks(player)
            return
        end

        local drone = FindRotorDroneByNetworkID(networkid)
        if drone ~= nil then
            player._kei_rotor_camera_drone = drone
            ApplyPilotCameraTarget(drone)
            StartRotorInputControl(player, drone)
            if player._kei_rotor_camera_resolve_task ~= nil then
                player._kei_rotor_camera_resolve_task:Cancel()
                player._kei_rotor_camera_resolve_task = nil
            end
            drone:ListenForEvent("onremove", RestoreRotorCameraClient)
            return true
        end

        attempts = attempts + 1
        if attempts >= 90 then
            CancelRotorCameraTasks(player)
        end
        return false
    end

    player._kei_rotor_camera_start_task = player:DoTaskInTime(0.5, function()
        player._kei_rotor_camera_start_task = nil
        local resolved = ResolveDrone()
        if not resolved and player._kei_rotor_camera_resolve_task == nil then
            player._kei_rotor_camera_resolve_task = player:DoPeriodicTask(FRAMES, ResolveDrone)
        end
    end)
end

AddClientModRPCHandler(ROTOR_RPC_NAMESPACE, ROTOR_CAMERA_START_RPC, StartRotorCameraClient)
AddClientModRPCHandler(ROTOR_RPC_NAMESPACE, ROTOR_CAMERA_STOP_RPC, RestoreRotorCameraClient)

local function ForwardPilotLocomote(inst, data)
    -- 驾驶期间由客户端根据相机方向采样输入并通过 MoveRotorPilot RPC 转发。
    -- 玩家自身 locomote 事件的 dir 属于角色 locomotor 坐标，不应直接复用。
    return true
end

local function GetActionItem(action)
    return action ~= nil and (action.invobject or action.target) or nil
end

local function IsControlWheelOpen(inst)
    if inst == nil or inst.HUD == nil or not inst.HUD:IsSpellWheelOpen() then
        return false
    end

    local spellbook = inst.HUD:GetCurrentOpenSpellBook()
    return spellbook ~= nil and spellbook:HasTag(CONTROLLER_TAG)
end

local function CloseControlWheel(inst)
    if IsControlWheelOpen(inst) then
        inst.HUD:CloseSpellWheel()
    end
end

-- USESPELLBOOK opens the wheel, while the custom spell action closes the control state.
-- Both are ordinary buffered actions, so the server state is authoritative and the
-- client only predicts it through server_states.
local function GetRotorActionState(inst, action, controller_state)
    local controller = GetActionItem(action)
    if controller_state == CONTROL_STOP and IsPilotState(inst) then
        return PILOT_WHEEL
    end
    if IsController(controller) then
        if controller_state == CONTROL_PRE and IsPilotState(inst) then
            return PILOT_WHEEL
        end
        return controller_state
    end

    -- CLOSESPELLBOOK 在部分客户端路径中没有携带 invobject；
    -- 此时使用打开轮盘时记录在状态图实例上的控制器引用。
    if controller_state == CONTROL_STOP and GetOwnedController(inst) ~= nil then
        return controller_state
    end

    return "doshortaction"
end

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.USESPELLBOOK, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_PRE)
end))

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.USESPELLBOOK, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_PRE)
end))

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.CLOSESPELLBOOK, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.CLOSESPELLBOOK, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_ROTOR_CONTROL, function(inst, action)
    if IsPilotState(inst) and IsController(GetActionItem(action)) then
        return PILOT_ACTION
    end
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_ROTOR_CONTROL, function(inst, action)
    if IsPilotState(inst) and IsController(GetActionItem(action)) then
        return PILOT_ACTION
    end
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_ROTOR_BEAM, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_ROTOR_BEAM, function(inst, action)
    return GetRotorActionState(inst, action, CONTROL_STOP)
end))

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_ROTOR_PILOT, PILOT_ACTION))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_ROTOR_PILOT, PILOT_ACTION))

-- Vanilla does not send CLOSESPELLBOOK through the remote character-wheel RPC.
-- The controller needs one small server notification because its pose is a
-- server-owned state rather than only a HUD state.
AddModRPCHandler("TendouKei", "StopRotorControl", function(player)
    if player == nil
        or not player:HasTag("kei")
        or player.components.inventory == nil
        or player.sg == nil
    then
        return
    end

    if GetOwnedController(player) == nil then
        return
    end

    local state = player.sg.currentstate
    local state_name = state ~= nil and state.name or nil
    if state_name == CONTROL_PRE or state_name == CONTROL_LOOP then
        player.sg:GoToState(CONTROL_STOP, true)
    end
end)

local function PerformStateAction(inst, is_client)
    if is_client then
        return inst:PerformPreviewBufferedAction()
    end
    return inst:PerformBufferedAction()
end

local function StopControlState(inst, locomoting)
    if inst == nil or inst.sg == nil then
        return
    end

    local state = inst.sg.currentstate
    local state_name = state ~= nil and state.name or nil
    if state_name == CONTROL_PRE or state_name == CONTROL_LOOP then
        CloseControlWheel(inst)
        inst.sg:GoToState(CONTROL_STOP, locomoting)
    end
end

local function AddControlInterruptEvents(events)
    events = events or {}

    events[#events + 1] = EventHandler("locomote", function(inst)
        StopControlState(inst, true)
        return true
    end)

    events[#events + 1] = EventHandler("equip", function(inst)
        StopControlState(inst, true)
    end)

    events[#events + 1] = EventHandler("unequip", function(inst)
        StopControlState(inst, true)
    end)

    events[#events + 1] = EventHandler("attacked", function(inst)
        StopControlState(inst, true)
    end)

    return events
end

local function MakeControlStates(is_client)
    local states = {}

    states[#states + 1] = State{
        name = CONTROL_PRE,
        tags = { "doing", "busy" },
        server_states = is_client and { CONTROL_PRE, CONTROL_LOOP, CONTROL_STOP } or nil,

        onenter = function(inst)
            local action = inst.bufferedaction
            local controller = GetActionItem(action)
            if not RememberController(inst, controller) then
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end

            inst.AnimState:PlayAnimation(REMOTE_USE_PRE)
            PerformStateAction(inst, is_client)
            inst.sg:SetTimeout(CONTROL_START_TIMEOUT)
        end,

        events = AddControlInterruptEvents({
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(CONTROL_LOOP)
                end
            end),
        }),

        onupdate = function(inst)
            if GetOwnedController(inst) == nil then
                StopControlState(inst)
            elseif is_client and inst.sg:ServerStateMatches() then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState(CONTROL_LOOP)
                end
            elseif is_client and inst.bufferedaction == nil then
                inst.AnimState:PlayAnimation(REMOTE_USE_PST)
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation(REMOTE_USE_PST)
            inst.sg:GoToState("idle", true)
        end,
    }

    states[#states + 1] = State{
        name = CONTROL_LOOP,
        -- 与 cookbook 的 peruse 状态相同，由状态图持有持续动作，避免 idle 覆盖。
        tags = { "doing", "busy", "overridelocomote" },
        server_states = is_client and { CONTROL_PRE, CONTROL_LOOP, CONTROL_STOP } or nil,

        onenter = function(inst)
            if GetOwnedController(inst) == nil then
                inst.sg:GoToState("idle", true)
                return
            end

            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end
            if is_client then
                inst.entity:SetIsPredictingMovement(false)
            end
            inst.AnimState:PlayAnimation(REMOTE_USE_LOOP, true)
            inst.sg:SetTimeout(CONTROL_LOOP_TIMEOUT)
        end,

        events = AddControlInterruptEvents({
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation(REMOTE_USE_LOOP, true)
                end
            end),
        }),

        onupdate = function(inst)
            if GetOwnedController(inst) == nil then
                StopControlState(inst)
            elseif is_client and not IsControlWheelOpen(inst) then
                inst.sg:GoToState(CONTROL_STOP)
            end
        end,

        ontimeout = function(inst)
            StopControlState(inst)
        end,

        onexit = function(inst)
            if is_client then
                CloseControlWheel(inst)
                inst.entity:SetIsPredictingMovement(true)
            end
        end,
    }

    states[#states + 1] = State{
        name = CONTROL_STOP,
        -- 退出动画播放完毕前仍由状态图接管姿势，避免过早回到 idle。
        tags = { "doing", "busy", "overridelocomote" },
        server_states = is_client and { CONTROL_STOP } or nil,

        onenter = function(inst, locomoting)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end

            if not locomoting then
                PerformStateAction(inst, is_client)
            end

            CloseControlWheel(inst)
            inst.AnimState:PlayAnimation(REMOTE_USE_PST)
            if locomoting and inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePredictOverrideLocomote()
            end
            inst.sg:SetTimeout(2)
        end,

        timeline = {
            TimeEvent(8 * FRAMES, function(inst)
                if inst.sg:HasStateTag("overridelocomote") then
                    inst.sg:RemoveStateTag("overridelocomote")
                end
            end),
        },

        events = {
            EventHandler("locomote", function(inst)
                return inst.sg:HasStateTag("overridelocomote")
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,

        onexit = function(inst)
            if is_client then
                inst.entity:SetIsPredictingMovement(true)
            end
            inst._kei_rotor_controller = nil
        end,
    }

    return states
end

for _, state in ipairs(MakeControlStates(false)) do
    AddStategraphState("wilson", state)
end

for _, state in ipairs(MakeControlStates(true)) do
    AddStategraphState("wilson_client", state)
end

-- 无人机驾驶状态。驾驶状态与控制轮盘状态分开，轮盘关闭后无人机仍由玩家操控。
local function ConfigurePilot(inst, drone)
    if drone == nil or not drone:IsValid() then
        return false
    end

    inst.sg.statemem.drone = drone
    inst._kei_rotor_was_piloting = true
    inst:AddTag("using_drone_remote")

    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:EnableMapControls(false)
        if inst.components.playercontroller.SetIsOverrideAttack ~= nil then
            inst.components.playercontroller:SetIsOverrideAttack(true)
        end
    end
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
    end
    StartPilotCamera(inst, drone)
    return true
end

local function ClearPilotOwner(inst)
    local drone = inst.sg.statemem.drone or GetPilotDrone(inst)
    if drone ~= nil and drone:IsValid() and drone._kei_drone_pilot == inst then
        if drone.StopRotorMovement ~= nil then
            drone:StopRotorMovement()
        else
            drone:PushEventImmediate("locomote")
        end
        drone._kei_drone_pilot = nil
    end

    local controller = GetPilotController(inst)
    if controller ~= nil and controller._kei_pilot_active_net ~= nil then
        controller._kei_pilot_active_net:set(false)
    end
    inst._kei_rotor_pilot_drone = nil
    inst._kei_rotor_was_piloting = nil
end

-- 强制动作会直接离开驾驶状态。延迟一帧确认目标状态后再清理，避免
-- PILOT_LOOP、PILOT_WHEEL 等驾驶子状态切换时误清除绑定。
local function SchedulePilotCleanup(inst)
    if inst == nil then
        return
    end

    if inst._kei_rotor_pilot_cleanup_task ~= nil then
        inst._kei_rotor_pilot_cleanup_task:Cancel()
    end

    inst._kei_rotor_pilot_cleanup_task = inst:DoTaskInTime(0, function(owner)
        owner._kei_rotor_pilot_cleanup_task = nil
        if not IsPilotState(owner) then
            ClearPilotOwner(owner)
        end
    end)
end

local function ExitPilotPresentation(inst)
    StopPilotCamera(inst)
    inst:RemoveTag("using_drone_remote")
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:EnableMapControls(true)
        if inst.components.playercontroller.SetIsOverrideAttack ~= nil then
            inst.components.playercontroller:SetIsOverrideAttack(false)
        end
    end
end

local function MakePilotActionStates(is_client)
    local states = {}

    states[#states + 1] = State{
        name = PILOT_ACTION,
        tags = { "doing", "busy" },
        server_states = is_client and { PILOT_ACTION, PILOT_LOOP, PILOT_WHEEL, PILOT_STOP } or nil,

        onenter = function(inst)
            local controller = GetActionItem(inst.bufferedaction)
            if not RememberController(inst, controller) then
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            inst.AnimState:PlayAnimation(REMOTE_USE_PRE)
            PerformStateAction(inst, is_client)
            if inst.sg.currentstate.name == PILOT_ACTION then
                inst.sg:SetTimeout(2)
            end
        end,

        onupdate = function(inst)
            local controller = GetPilotController(inst)
            local active = controller ~= nil
                and controller._kei_pilot_active_net ~= nil
                and controller._kei_pilot_active_net:value()

            if active then
                if inst.sg:HasStateTag("busy") and is_client then
                    inst.sg:GoToState(PILOT_LOOP)
                end
            elseif is_client and inst.bufferedaction == nil then
                if inst._kei_rotor_was_piloting then
                    inst.sg:GoToState(PILOT_STOP)
                else
                    inst.sg:GoToState("idle", true)
                end
            end
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() and inst.sg.currentstate.name == PILOT_ACTION then
                    if is_client then
                        inst.sg:GoToState("idle", true)
                    else
                        inst.sg:GoToState("idle")
                    end
                end
            end),
        },

        ontimeout = function(inst)
            if inst.sg.currentstate.name == PILOT_ACTION then
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
            end
        end,

        onexit = function(inst)
            ExitPilotPresentation(inst)
            SchedulePilotCleanup(inst)
        end,
    }

    states[#states + 1] = State{
        name = PILOT_LOOP,
        tags = { "overridelocomote", "nodragwalk", "overrideattack" },
        server_states = is_client and { PILOT_LOOP, PILOT_WHEEL, PILOT_STOP } or nil,

        onenter = function(inst, drone)
            drone = drone or GetPilotDrone(inst)
            if not ConfigurePilot(inst, drone) then
                inst.sg:GoToState(PILOT_STOP, true)
                return
            end
            inst.AnimState:PlayAnimation(REMOTE_USE_LOOP, true)
        end,

        events = {
            EventHandler("locomote", function(inst, data)
                return ForwardPilotLocomote(inst, data)
            end),
            EventHandler("attacked", function(inst)
                inst.sg:GoToState(PILOT_STOP, true)
            end),
        },

        onupdate = function(inst)
            local drone = inst.sg.statemem.drone or GetPilotDrone(inst)
            local controller = GetPilotController(inst)
            local active = controller ~= nil
                and controller._kei_pilot_active_net ~= nil
                and controller._kei_pilot_active_net:value()

            if drone == nil or not drone:IsValid() or not active then
                inst.sg:GoToState(PILOT_STOP, true)
            end
        end,

        onexit = function(inst)
            ExitPilotPresentation(inst)
            SchedulePilotCleanup(inst)
        end,
    }

    states[#states + 1] = State{
        name = PILOT_WHEEL,
        tags = { "overridelocomote", "nodragwalk", "overrideattack" },
        server_states = is_client and { PILOT_WHEEL, PILOT_LOOP, PILOT_ACTION, PILOT_STOP } or nil,

        onenter = function(inst)
            local drone = GetPilotDrone(inst)
            if not ConfigurePilot(inst, drone) then
                inst.sg:GoToState(PILOT_STOP, true)
                return
            end
            inst.AnimState:PlayAnimation(REMOTE_USE_LOOP, true)
            PerformStateAction(inst, is_client)
            inst.sg:SetTimeout(PILOT_WHEEL_TIMEOUT)
        end,

        onupdate = function(inst)
            if is_client and not IsControlWheelOpen(inst) then
                inst.sg:GoToState(PILOT_LOOP)
            end
        end,

        events = {
            EventHandler("locomote", function(inst, data)
                return ForwardPilotLocomote(inst, data)
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState(PILOT_LOOP)
        end,

        onexit = function(inst)
            ExitPilotPresentation(inst)
            SchedulePilotCleanup(inst)
        end,
    }

    states[#states + 1] = State{
        name = PILOT_STOP,
        tags = { "doing", "busy" },
        server_states = is_client and { PILOT_STOP } or nil,

        onenter = function(inst)
            ClearPilotOwner(inst)
            ExitPilotPresentation(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end
            inst.AnimState:PlayAnimation(REMOTE_USE_PST)
            inst.sg:SetTimeout(2)
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    }

    return states
end

for _, state in ipairs(MakePilotActionStates(false)) do
    AddStategraphState("wilson", state)
end

for _, state in ipairs(MakePilotActionStates(true)) do
    AddStategraphState("wilson_client", state)
end

local function GetActivePilotDrone()
    return nil
end

-- 直接接管 FollowCamera.Update，避免驾驶状态同步或其他客户端逻辑把相机目标
-- 恢复为 Kei。驾驶期间使用固定距离与 90 度俯视角，目标始终为绑定无人机。
if false then
    local _Update = self.Update
    self.Update = function(camera, dt, dontupdatepos)
        local drone = GetActivePilotDrone()
        if drone ~= nil then
            SetPilotCameraView(camera)
            ApplyPilotCameraTarget(drone, camera)
        elseif camera._kei_rotor_camera_view ~= nil and ThePlayer ~= nil then
            camera:SetTarget(ThePlayer)
            camera.targetoffset.x = 0
            camera.targetoffset.y = 1.5
            camera.targetoffset.z = 0
            RestorePilotCameraView(camera)
        end

        _Update(camera, dt, dontupdatepos)

        -- 某些相机模式会在 Update 内部重新设置 target，Update 结束后再校正一次。
        if drone ~= nil and drone:IsValid() then
            SetPilotCameraView(camera)
            ApplyPilotCameraTarget(drone, camera)
        end
    end
end
