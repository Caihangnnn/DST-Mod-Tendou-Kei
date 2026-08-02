-- 旋翼调查仪控制器：手部装备，右键打开无人机控制轮盘。
local RotorSurveyRegistry = require("kei/rotor_survey_registry")

local DRONE_CONTROL_WHEEL_RADIUS = 100

local function IsDroneBoundToOwner(drone, owner)
    return drone ~= nil
        and drone:IsValid()
        and owner ~= nil
        and (drone._kei_drone_owner == owner
            or (owner.userid ~= nil and drone._kei_drone_owner_userid == owner.userid))
end

local function OnControlWheelClose(inst)
    if TheWorld.ismastersim or inst._kei_rotor_skill_casting then
        inst._kei_rotor_skill_casting = nil
        return
    end

    -- 驾驶无人机时，关闭轮盘只代表结束选项选择，不应退出驾驶状态。
    if ThePlayer ~= nil and ThePlayer.sg ~= nil then
        local state = ThePlayer.sg.currentstate
        local state_name = state ~= nil and state.name or nil
        if state_name == "kei_rotor_drone_pilot"
            or state_name == "kei_rotor_drone_pilot_wheel"
            or state_name == "kei_rotor_drone_pilot_action"
        then
            return
        end
    end

    if MOD_RPC ~= nil
        and MOD_RPC.TendouKei ~= nil
        and MOD_RPC.TendouKei.StopRotorControl ~= nil
    then
        SendModRPCToServer(MOD_RPC.TendouKei.StopRotorControl)
    end
end

local function FindBoundDrone(inst, owner)
    if IsDroneBoundToOwner(inst.linked_drone, owner) then
        return inst.linked_drone
    end

    if owner == nil or owner.userid == nil then
        return nil
    end

    local drone = RotorSurveyRegistry.Find(owner.userid, function(candidate)
        return IsDroneBoundToOwner(candidate, owner)
    end)
    if drone ~= nil then
        inst.linked_drone = drone
        if inst._kei_linked_drone_net ~= nil then
            inst._kei_linked_drone_net:set(drone)
        end
        return drone
    end

    return nil
end

local function SetBoundDrone(inst, drone, owner)
    local previous_drone = inst.linked_drone
    if previous_drone ~= nil and previous_drone ~= drone then
        if inst.components ~= nil and inst.components.kei_rotor_beam ~= nil then
            inst.components.kei_rotor_beam:Stop()
        end
        if previous_drone._kei_detach_owner_callbacks ~= nil then
            previous_drone._kei_detach_owner_callbacks(previous_drone)
        end
        RotorSurveyRegistry.Unregister(previous_drone)
        previous_drone._kei_drone_owner = nil
        previous_drone._kei_drone_owner_userid = nil
        if previous_drone._kei_drone_owner_userid_net ~= nil then
            previous_drone._kei_drone_owner_userid_net:set("")
        end
    end

        inst.linked_drone = drone
    if inst._kei_linked_drone_net ~= nil then
        inst._kei_linked_drone_net:set(drone)
    end
    inst.drone_owner_userid = owner ~= nil and owner.userid or inst._kei_controller_owner_userid

    if drone ~= nil then
        drone._kei_drone_owner = owner
        drone._kei_drone_owner_userid = inst.drone_owner_userid
        if drone._kei_drone_owner_userid_net ~= nil then
            drone._kei_drone_owner_userid_net:set(inst.drone_owner_userid or "")
        end
        drone._kei_drone_controller = inst
        RotorSurveyRegistry.Register(drone, inst.drone_owner_userid)
        drone.persists = false
        if owner ~= nil and drone.components ~= nil then
            local function RemoveDroneForOwnerLeave(drone_inst, data)
                local player = data ~= nil and data.player or data
                if player == owner and drone_inst:IsValid() then
                    drone_inst:Remove()
                end
            end

            local function RemoveDroneForOwnerRemove(drone_inst)
                if drone_inst:IsValid() then
                    drone_inst:Remove()
                end
            end

            drone._kei_owner_leave_fn = RemoveDroneForOwnerLeave
            drone._kei_owner_remove_fn = RemoveDroneForOwnerRemove
            drone._kei_detach_owner_callbacks = function(drone_inst)
                if owner ~= nil then
                    drone_inst:RemoveEventCallback("onremove", RemoveDroneForOwnerRemove, owner)
                end
                if TheWorld ~= nil then
                    drone_inst:RemoveEventCallback("ms_playerdespawn", RemoveDroneForOwnerLeave, TheWorld)
                    drone_inst:RemoveEventCallback("ms_playerdespawnanddelete", RemoveDroneForOwnerLeave, TheWorld)
                    drone_inst:RemoveEventCallback("ms_playerdespawnandmigrate", RemoveDroneForOwnerLeave, TheWorld)
                end
                drone_inst._kei_owner_leave_fn = nil
                drone_inst._kei_owner_remove_fn = nil
                drone_inst._kei_detach_owner_callbacks = nil
            end

            drone:ListenForEvent("onremove", RemoveDroneForOwnerRemove, owner)
            if TheWorld ~= nil then
                drone:ListenForEvent("ms_playerdespawn", RemoveDroneForOwnerLeave, TheWorld)
                drone:ListenForEvent("ms_playerdespawnanddelete", RemoveDroneForOwnerLeave, TheWorld)
                drone:ListenForEvent("ms_playerdespawnandmigrate", RemoveDroneForOwnerLeave, TheWorld)
            end

            if drone.components.globaltrackingicon ~= nil then
                drone.components.globaltrackingicon:StartTracking(owner, "kei_rotor_surveyor")
            end
            if drone.components.maprevealer ~= nil then
                drone.components.maprevealer:SetPrivateOwner(owner)
            end
        end
    end
end

local function GetOwnerUserId(inst)
    if inst._kei_controller_owner_userid ~= nil then
        return inst._kei_controller_owner_userid
    end
    if inst._kei_controller_owner_userid_net ~= nil then
        return inst._kei_controller_owner_userid_net:value()
    end
end

local function IsStoredByOwner(inst, owner)
    if inst == nil or owner == nil or owner.userid == nil or GetOwnerUserId(inst) ~= owner.userid then
        return false
    end

    local inventoryitem = inst.components ~= nil and inst.components.inventoryitem or nil
    local holder = inventoryitem ~= nil and inventoryitem.owner or nil
    if holder == owner then
        return true
    end
    if holder ~= nil and holder:HasTag("kei_mini_alice") then
        return inventoryitem:GetGrandOwner() == owner
    end
    return false
end

local function SetControllerOwner(inst, owner)
    local userid = owner ~= nil and owner.userid or nil
    inst._kei_controller_owner_userid = userid
    if inst._kei_controller_owner_userid_net ~= nil then
        inst._kei_controller_owner_userid_net:set(userid or "")
    end
    RotorSurveyRegistry.RegisterController(inst, userid)
end

local function OnBuilt(inst, data)
    local builder = data ~= nil and data.builder or nil
    if builder ~= nil and builder:HasTag("kei") then
        SetControllerOwner(inst, builder)
    end
end

local function OnSave(inst, data)
    if data == nil then
        return
    end

    data.kei_controller_owner_userid = inst._kei_controller_owner_userid
end

local function OnLoad(inst, data)
    inst._kei_controller_owner_userid = data ~= nil and data.kei_controller_owner_userid or nil
    if inst._kei_controller_owner_userid_net ~= nil then
        inst._kei_controller_owner_userid_net:set(inst._kei_controller_owner_userid or "")
    end
    RotorSurveyRegistry.RegisterController(inst, inst._kei_controller_owner_userid)
end

local function OnRemove(inst)
    if inst.components ~= nil and inst.components.kei_rotor_beam ~= nil then
        inst.components.kei_rotor_beam:Stop()
    end
    local drone = inst.linked_drone
    if drone ~= nil and drone._kei_drone_pilot ~= nil then
        local pilot = drone._kei_drone_pilot
        if pilot:IsValid() and pilot.sg ~= nil then
            pilot.sg:GoToState("kei_rotor_drone_pilot_stop", true)
        end
    end
    if drone ~= nil and drone:IsValid() then
        if drone._kei_detach_owner_callbacks ~= nil then
            drone._kei_detach_owner_callbacks(drone)
        end
        drone:Remove()
    end
    RotorSurveyRegistry.UnregisterController(inst)
end

local function StopPilotForOwner(inst, owner)
    local drone = inst.linked_drone
    if drone == nil or not drone:IsValid() then
        return
    end

    local was_piloting = drone._kei_drone_pilot == owner
        or (owner ~= nil and owner._kei_rotor_pilot_drone == drone)

    -- 电量耗尽可能发生在驾驶状态清理之后，此时无人机仍可能保留上一次的
    -- 自动驾驶速度。卸下控制器时始终清除速度，避免无人机继续移动。
    if drone.StopRotorMovement ~= nil then
        drone:StopRotorMovement()
    elseif drone.Physics ~= nil then
        local _, vy, _ = drone.Physics:GetMotorVel()
        drone.Physics:SetMotorVel(0, vy, 0)
    end

    drone._kei_drone_pilot = nil
    if inst._kei_pilot_active_net ~= nil then
        inst._kei_pilot_active_net:set(false)
    end
    if owner ~= nil then
        owner._kei_rotor_pilot_drone = nil
    end

    if not was_piloting then
        return
    end

    if owner ~= nil and owner.sg ~= nil then
        owner.sg:GoToState("kei_rotor_drone_pilot_stop", true)
    end
end

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol(
        "swap_object",
        "swap_wx78_drone_zap_remote",
        "swap_drone_zap_remote"
    )
    owner.AnimState:OverrideSymbol(
        "drone_zap_remote_parts",
        "swap_wx78_drone_zap_remote",
        "drone_zap_remote_parts"
    )
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    inst.components.inventoryitem:ChangeImageName("wx78_drone_zap_remote_held")
end

local function OnUnequip(inst, owner)
    StopPilotForOwner(inst, owner)
    owner.AnimState:ClearOverrideSymbol("drone_zap_remote_parts")
    owner.AnimState:ClearOverrideSymbol("swap_object")
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    inst.components.inventoryitem:ChangeImageName("wx78_drone_zap_remote")
end

local function ToggleBoundDrone(inst, doer)
    if not TheWorld.ismastersim or inst == nil or doer == nil then
        return false
    end

    local drone = FindBoundDrone(inst, doer)
    if drone ~= nil then
        if drone._kei_drone_pilot == doer then
            drone._kei_drone_pilot = nil
            if inst._kei_pilot_active_net ~= nil then
                inst._kei_pilot_active_net:set(false)
            end
            doer._kei_rotor_pilot_drone = nil
            if doer.sg ~= nil then
                doer.sg:GoToState("kei_rotor_drone_pilot_stop", true)
            end
        end
        SetBoundDrone(inst, nil, doer)
        drone:Remove()
        return true
    end

    local x, _, z = doer.Transform:GetWorldPosition()
    drone = SpawnPrefab("kei_rotor_surveyor")
    if drone == nil then
        return false
    end

    drone.Physics:Teleport(x, 1.5, z)
    SetBoundDrone(inst, drone, doer)
    drone.sg:GoToState("deploy")
    return true
end

local function EnsureBoundDrone(inst, doer)
    local drone = FindBoundDrone(inst, doer)
    if drone ~= nil then
        return drone
    end

    local x, _, z = doer.Transform:GetWorldPosition()
    drone = SpawnPrefab("kei_rotor_surveyor")
    if drone == nil then
        return nil
    end

    drone.Physics:Teleport(x, 1.5, z)
    SetBoundDrone(inst, drone, doer)
    drone.sg:GoToState("deploy")
    return drone
end

local function ToggleDronePilot(inst, doer)
    if not TheWorld.ismastersim or inst == nil or doer == nil then
        return false
    end

    local drone = FindBoundDrone(inst, doer)
    if drone == nil then
        -- 第二技能第一次使用只负责召唤无人机，下一次使用才进入驾驶。
        if not ToggleBoundDrone(inst, doer) then
            return false
        end
        drone = FindBoundDrone(inst, doer)
        if drone == nil then
            return false
        end
    end

    if drone._kei_drone_pilot == doer or doer._kei_rotor_pilot_drone == drone then
        if drone.StopRotorMovement ~= nil then
            drone:StopRotorMovement()
        else
            drone:PushEventImmediate("locomote")
        end
        drone._kei_drone_pilot = nil
        doer._kei_rotor_pilot_drone = nil
        if inst._kei_pilot_active_net ~= nil then
            inst._kei_pilot_active_net:set(false)
        end
        if doer.sg ~= nil then
            doer.sg:GoToState("kei_rotor_drone_pilot_stop", true)
        end
        return true
    end

    local previous_pilot = drone._kei_drone_pilot
    if previous_pilot ~= nil and previous_pilot ~= doer and previous_pilot:IsValid() then
        return false
    end

    drone._kei_drone_pilot = doer
    doer._kei_rotor_pilot_drone = drone
    if inst._kei_pilot_active_net ~= nil then
        inst._kei_pilot_active_net:set(true)
    end
    if doer.sg ~= nil then
        doer.sg:GoToState("kei_rotor_drone_pilot", drone)
    end
    return true
end

local function CastControllerSpell(inst)
    inst._kei_rotor_skill_casting = true
    if ThePlayer ~= nil and ThePlayer.replica.inventory ~= nil then
        ThePlayer.replica.inventory:CastSpellBookFromInv(inst)
    end
    inst:DoTaskInTime(0, function()
        if inst:IsValid() then
            inst._kei_rotor_skill_casting = nil
        end
    end)
end

local function CastToggleDrone(inst)
    CastControllerSpell(inst)
end

local function CastDronePilot(inst)
    CastControllerSpell(inst)
end

local function CastRotorBeam(inst)
    CastControllerSpell(inst)
end

local function ActivateRotorBeam(inst, doer, beam_name)
    if not TheWorld.ismastersim or inst == nil or doer == nil then
        return false
    end

    local drone = EnsureBoundDrone(inst, doer)
    if drone == nil or drone.SetSkillBeam == nil then
        return false
    end

    if drone.GetSkillBeam ~= nil and drone:GetSkillBeam() == beam_name then
        drone:SetSkillBeam(nil)
        if inst.components.kei_rotor_beam ~= nil then
            inst.components.kei_rotor_beam:Stop()
        end
    else
        if inst.components.kei_rotor_beam == nil
            or not inst.components.kei_rotor_beam:Start(beam_name, drone, doer)
        then
            return false
        end
        drone:SetSkillBeam(beam_name)
    end
    return true
end

local function MakeDroneControlSpell(label, icon, pilot)
    icon = "icon_target"
    local spell = {
        label = label,
        bank = "spell_icons_winona",
        build = "spell_icons_winona",
        anims = {
            idle = { anim = icon },
            focus = { anim = icon.."_focus", loop = true },
            down = { anim = icon.."_pressed" },
            disabled = { anim = icon.."_disabled" },
        },
        execute = pilot and CastDronePilot or function() return true end,
        widget_scale = 0.6,
    }
    if pilot then
        spell.onselect = function(inst)
            inst.components.spellbook:SetSpellAction(ACTIONS.KEI_ROTOR_PILOT)
            if TheWorld.ismastersim then
                inst.components.spellbook:SetSpellFn(inst.ToggleDronePilot)
            end
        end
    end
    return spell
end

local function MakeRotorBeamSpell(label, beam_name)
    local spell = MakeDroneControlSpell(label, "icon_target")
    spell.execute = CastRotorBeam
    spell.onselect = function(inst)
        inst.components.spellbook:SetSpellAction(ACTIONS.KEI_ROTOR_BEAM)
        if TheWorld.ismastersim then
            inst.components.spellbook:SetSpellFn(function(controller, doer)
                return ActivateRotorBeam(controller, doer, beam_name)
            end)
        end
    end
    return spell
end

local DRONE_CONTROL_WHEEL_ITEMS = {
    {
        label = "启用/关闭",
        onselect = function(inst)
            inst.components.spellbook:SetSpellAction(ACTIONS.KEI_ROTOR_CONTROL)
            if TheWorld.ismastersim then
                inst.components.spellbook:SetSpellFn(ToggleBoundDrone)
            end
        end,
        execute = CastToggleDrone,
        bank = "spell_icons_winona",
        build = "spell_icons_winona",
        anims = {
            idle = { anim = "icon_target" },
            focus = { anim = "icon_target_focus", loop = true },
            down = { anim = "icon_target_pressed" },
            disabled = { anim = "icon_target_disabled" },
        },
        widget_scale = 0.6,
    },
    MakeDroneControlSpell("驾驶", "icon_boost", true),
    MakeRotorBeamSpell("苏生光束", "resurrection"),
    MakeRotorBeamSpell("治愈光束", "heal"),
    MakeRotorBeamSpell("强化光束", "strengthen"),
    MakeRotorBeamSpell("禁锢光束", "confinement"),
    MakeRotorBeamSpell("死亡光束", "dead"),
    MakeRotorBeamSpell("调查光束", "survey"),
}

local function CanOpenDroneControlWheel(inst, user)
    if inst == nil or user == nil or not user:HasTag("kei") or user:HasTag("playerghost") then
        return false
    end

    local inventory = user.components ~= nil and user.components.inventory or nil
    if inventory == nil and user.replica ~= nil then
        inventory = user.replica.inventory
    end
    if inventory ~= nil and inventory.GetEquippedItem ~= nil then
        return inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst
    end

    return false
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "med", 0.27, { 0.85, 1, 1 })

    inst.AnimState:SetBank("wx78_drone_zap")
    inst.AnimState:SetBuild("wx78_drone_zap")
    inst.AnimState:PlayAnimation("drone_zap_bundle")

    inst:AddTag("kei_rotor_survey_controller")
    inst:AddTag("show_spoilage")
    inst:AddTag("fresh")
    inst:AddTag("donotautopick")
    inst:AddTag("nosteal")
    inst._kei_controller_owner_userid_net = net_string(inst.GUID, "kei_rotor_survey_controller.owner_userid")
    inst._kei_linked_drone_net = net_entity(inst.GUID, "kei_rotor_survey_controller.linked_drone")
    inst._kei_pilot_active_net = net_bool(inst.GUID, "kei_rotor_survey_controller.pilot_active")

    -- 复用 Willow 的 spellbook -> USESPELLBOOK -> HUD 技能轮盘流程。
    inst:AddComponent("spellbook")
    inst.components.spellbook:SetRadius(DRONE_CONTROL_WHEEL_RADIUS)
    inst.components.spellbook:SetFocusRadius(DRONE_CONTROL_WHEEL_RADIUS + 2)
    inst.components.spellbook:SetItems(DRONE_CONTROL_WHEEL_ITEMS)
    inst.components.spellbook:SetCanUseFn(CanOpenDroneControlWheel)
    inst.components.spellbook:SetSpellAction(ACTIONS.KEI_ROTOR_CONTROL)
    inst.components.spellbook:SetOnCloseFn(OnControlWheelClose)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("wx78_drone_zap_remote")

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.KEI_ROTOR_CONTROLLER_MAX_POWER or 240)

    inst:AddComponent("kei_rotor_power")
    inst:AddComponent("kei_rotor_beam")

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst.components.equippable.restrictedtag = "kei"
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst.components.spellbook:SetSpellFn(ToggleBoundDrone)

    inst.SetBoundDrone = SetBoundDrone
    inst.SetControllerOwner = SetControllerOwner
    inst.IsStoredByOwner = IsStoredByOwner
    inst.GetControllerOwnerUserId = GetOwnerUserId
    inst.FindBoundDrone = FindBoundDrone
    inst.ToggleBoundDrone = ToggleBoundDrone
    inst.ToggleDronePilot = ToggleDronePilot
    inst.StopPilotForOwner = StopPilotForOwner
    inst.onPreBuilt = function(item, builder)
        if builder ~= nil and builder:HasTag("kei") then
            SetControllerOwner(item, builder)
        end
    end
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("onremove", OnRemove)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("kei_rotor_survey_controller", fn, {
    Asset("ANIM", "anim/wx78_drone_zap.zip"),
    Asset("ANIM", "anim/swap_wx78_drone_zap_remote.zip"),
    Asset("ANIM", "anim/spell_icons_winona.zip"),
    Asset("INV_IMAGE", "wx78_drone_zap_remote"),
    Asset("INV_IMAGE", "wx78_drone_zap_remote_held"),
})
