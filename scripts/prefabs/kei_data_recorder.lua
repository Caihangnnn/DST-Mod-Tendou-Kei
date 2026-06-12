require("prefabutil")
local CombatProtocolDefs = require("kei_combat_protocol_defs")

local assets = {
    Asset("ANIM", "anim/vault_decon_mister.zip"),
    Asset("INV_IMAGE", "vault_decon_mister"),
}

local item_assets = {
    Asset("ANIM", "anim/vault_decon_mister.zip"),
    Asset("INV_IMAGE", "wagstaff_item_2"),
}

local RECORDER_BANK = "vault_decon_mister"
local RECORDER_BUILD = "vault_decon_mister"
local RECORDER_ANIM_OFF = "misting_closed"
local RECORDER_ANIM_ON = "misting_loop"
local RECORDER_ANIM_ACTIVATE = "misting_activate"
local RECORDER_ANIM_DEACTIVATE = "misting_deactivated"

local VALID_RECORD_TARGETS = CombatProtocolDefs.VALID_RECORD_TARGETS

local RECORDER_STATE = {
    idle = 0,
    recording = 1,
    complete = 2,
}

local function Say(doer, key)
    -- 记录仪动作的反馈仍由操作者 Kei 说出。
    if doer ~= nil and doer.components.talker ~= nil and STRINGS.CHARACTERS.KEI[key] ~= nil then
        doer.components.talker:Say(STRINGS.CHARACTERS.KEI[key])
    end
end

local function GetBoundTarget(cd)
    -- 优先使用运行时实体引用；如果引用丢失，则用同局内保存的 GUID 找回。
    if cd == nil then
        return nil
    end
    if cd.kei_bound_target ~= nil and cd.kei_bound_target:IsValid() then
        return cd.kei_bound_target
    end
    if cd.kei_bound_guid ~= nil then
        local ent = Ents[cd.kei_bound_guid]
        if ent ~= nil and ent:IsValid() then
            cd.kei_bound_target = ent
            return ent
        end
    end
    return nil
end

local function IsPointInArena(inst, px, pz)
    if WAGPUNK_ARENA_COLLISION_DATA == nil then
        local range = TUNING.KEI_RECORDER_RANGE
        return inst:GetDistanceSqToPoint(px, 0, pz) <= range * range
    end

    local cx, cy, cz = inst.Transform:GetWorldPosition()
    local x = px - cx
    local z = pz - cz
    local inside = false
    local previous = WAGPUNK_ARENA_COLLISION_DATA[#WAGPUNK_ARENA_COLLISION_DATA]

    for _, current in ipairs(WAGPUNK_ARENA_COLLISION_DATA) do
        local x1, z1 = previous[1], previous[2]
        local x2, z2 = current[1], current[2]
        if (z1 > z) ~= (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1 then
            inside = not inside
        end
        previous = current
    end

    return inside
end

local function TargetInRange(inst, target)
    -- 目标必须一直处在记录仪工作半径内，死亡时才算记录成功。
    if target == nil or not target:IsValid() then
        return false
    end
    local x, y, z = target.Transform:GetWorldPosition()
    return IsPointInArena(inst, x, z)
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

local function EnableRecorderMistFx(inst)
    if inst.kei_mistfx == nil then
        inst.kei_mistfx = SpawnPrefab("vault_decon_mister_fx")
        if inst.kei_mistfx ~= nil then
            inst.kei_mistfx.entity:SetParent(inst.entity)
        end
    end
end

local function DisableRecorderMistFx(inst)
    if inst.kei_mistfx ~= nil then
        if inst.kei_mistfx:IsValid() then
            inst.kei_mistfx:Remove()
        end
        inst.kei_mistfx = nil
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
    if state == "recording" then
        inst:AddTag("kei_recording")
        inst.AnimState:PlayAnimation(RECORDER_ANIM_ACTIVATE)
        inst.AnimState:PushAnimation(RECORDER_ANIM_ON, true)
        EnableRecorderMistFx(inst)
        CreateForceField(inst)
    elseif state == "complete" then
        inst:AddTag("kei_record_complete")
        inst.AnimState:PlayAnimation(RECORDER_ANIM_ON, true)
        EnableRecorderMistFx(inst)
        ClearForceField(inst)
    else
        inst.AnimState:PlayAnimation(RECORDER_ANIM_OFF, true)
        DisableRecorderMistFx(inst)
        ClearForceField(inst)
    end
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

local function CompleteRecording(inst, target)
    -- 只有目标在记录范围内死亡，才会产出对应战斗协议。
    if inst.kei_state ~= "recording" then
        return
    end
    if TargetInRange(inst, target) then
        inst.kei_completed_protocol = inst.kei_target_prefab
        SetRecorderState(inst, "complete")
    else
        inst.kei_completed_protocol = nil
        SetRecorderState(inst, "idle")
    end
    ClearTargetListener(inst)
end

local function StartKeiRecording(inst, cd, doer)
    -- 提交 CD 时再次校验目标，防止绑定后目标离开、死亡或被替换。
    if inst.kei_state ~= "idle" or cd == nil or not cd:HasTag("kei_blank_cd") then
        return false
    end
    local target = GetBoundTarget(cd)
    if target == nil
        or cd.kei_bound_prefab == nil
        or not VALID_RECORD_TARGETS[cd.kei_bound_prefab]
        or target.prefab ~= cd.kei_bound_prefab
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.defeated
        or not TargetInRange(inst, target)
    then
        return false
    end

    -- 提交成功后消耗空白 CD，并监听目标死亡来完成记录。
    if cd.components.inventoryitem ~= nil and cd.components.inventoryitem.owner ~= nil then
        cd.components.inventoryitem:RemoveFromOwner(true)
    end
    cd:Remove()

    inst.kei_target = target
    inst.kei_target_prefab = target.prefab
    inst.kei_completed_protocol = nil
    inst.kei_target_death_fn = function(target_inst)
        CompleteRecording(inst, target_inst)
        Say(doer, "ANNOUNCE_KEI_RECORD_DONE")
    end
    inst:ListenForEvent("death", inst.kei_target_death_fn, target)
    if target.prefab == "daywalker" then
        inst.kei_target_minhealth_fn = function(target_inst)
            CompleteRecording(inst, target_inst)
            Say(doer, "ANNOUNCE_KEI_RECORD_DONE")
        end
        inst:ListenForEvent("minhealth", inst.kei_target_minhealth_fn, target)
    end
    SetRecorderState(inst, "recording")
    Say(doer, "ANNOUNCE_KEI_RECORDING")
    return true
end

local function StopKeiRecording(inst, doer)
    -- 主动停止记录视为取消任务，返还一张新的空白 CD。
    if inst.kei_state ~= "recording" then
        return false
    end
    local cd = SpawnPrefab("kei_blank_cd")
    if cd ~= nil then
        if doer ~= nil and doer.components.inventory ~= nil then
            doer.components.inventory:GiveItem(cd, nil, doer:GetPosition())
        else
            cd.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
    end
    ClearTargetListener(inst)
    inst.kei_target_prefab = nil
    inst.kei_completed_protocol = nil
    SetRecorderState(inst, "idle")
    Say(doer, "ANNOUNCE_KEI_RECORD_STOPPED")
    return true
end

local function HarvestKeiData(inst, doer)
    -- 收获时根据记录完成的巨兽类型生成战斗协议 CD。
    if inst.kei_state ~= "complete" or inst.kei_completed_protocol == nil then
        return false
    end
    local cd = SpawnPrefab("kei_combat_data_cd")
    if cd == nil then
        return false
    end
    cd:SetCombatData(inst.kei_completed_protocol)
    if doer ~= nil and doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(cd, nil, doer:GetPosition())
    else
        cd.Transform:SetPosition(inst.Transform:GetWorldPosition())
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
        DisableRecorderMistFx(inst)
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
    DisableRecorderMistFx(inst)
    ClearForceField(inst)
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
    -- 记录中无法安全保存目标实体，因此读档后返还空白 CD 并回到 idle。
    data.kei_state = inst.kei_state
    data.kei_target_prefab = inst.kei_target_prefab
    data.kei_completed_protocol = inst.kei_completed_protocol
    data.return_blank_cd = inst.kei_state == "recording" or nil
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.kei_target_prefab = data.kei_target_prefab
        inst.kei_completed_protocol = data.kei_completed_protocol
        SetRecorderState(inst, data.kei_state == "complete" and "complete" or "idle")
        if data.return_blank_cd then
            -- 延迟一帧生成，确保实体位置和世界状态已恢复。
            inst:DoTaskInTime(0, function()
                local cd = SpawnPrefab("kei_blank_cd")
                if cd ~= nil then
                    cd.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
            end)
        end
    end
end

local function OnBuilt(inst)
    -- 部署完成但未提交 CD 时保持未激活外观。
    inst.AnimState:PlayAnimation(RECORDER_ANIM_OFF, true)
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
    inst:ListenForEvent("onremove", DisableRecorderMistFx)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

local function kit_postinit(inst)
    inst.components.inventoryitem:ChangeImageName("wagstaff_item_2")
end

-- 同时返回结构 prefab、部署包 prefab 和 placer。
return Prefab("kei_data_recorder", recorder_fn, assets, { "kei_blank_cd", "kei_combat_data_cd", "vault_decon_mister_fx", "wagpunk_cagewall", "wagpunk_arena_collision" }),
    MakeDeployableKitItem(
        "kei_data_recorder_item",
        "kei_data_recorder",
        RECORDER_BANK,
        RECORDER_BUILD,
        RECORDER_ANIM_OFF,
        item_assets,
        { size = "small", y_offset = nil, scale = 0.8 },
        { "kei_data_recorder_item" },
        nil,
        { deploymode = DEPLOYMODE.DEFAULT, deployspacing = DEPLOYSPACING.DEFAULT },
        nil,
        kit_postinit
    ),
    MakePlacer("kei_data_recorder_item_placer", RECORDER_BANK, RECORDER_BUILD, RECORDER_ANIM_OFF, false, nil, nil, nil, nil, "eight")
