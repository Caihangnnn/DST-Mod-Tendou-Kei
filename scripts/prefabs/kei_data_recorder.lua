require("prefabutil")

local assets = {
    Asset("ANIM", "anim/wagpunk_cagewall.zip"),
}

local item_assets = {
    Asset("ANIM", "anim/wagstaff_personal_items.zip"),
}

local VALID_RECORD_TARGETS = {
    deerclops = true,
    bearger = true,
    dragonfly = true,
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

local function TargetInRange(inst, target)
    -- 目标必须一直处在记录仪工作半径内，死亡时才算记录成功。
    return target ~= nil
        and target:IsValid()
        and inst:GetDistanceSqToInst(target) <= TUNING.KEI_RECORDER_RANGE * TUNING.KEI_RECORDER_RANGE
end

local function SetRecorderState(inst, state)
    -- 记录仪状态同时驱动交互逻辑和动画表现。
    inst.kei_state = state
    if state == "recording" then
        inst.AnimState:PlayAnimation("activate")
        inst.AnimState:PushAnimation("idle_on", true)
    elseif state == "complete" then
        inst.AnimState:PlayAnimation("idle_on", true)
    else
        inst.AnimState:PlayAnimation("idle_off", true)
    end
end

local function ClearTargetListener(inst)
    -- 记录结束或中断时要解绑死亡监听，避免旧目标之后触发回调。
    if inst.kei_target ~= nil and inst.kei_target_death_fn ~= nil then
        inst:RemoveEventCallback("death", inst.kei_target_death_fn, inst.kei_target)
    end
    inst.kei_target = nil
    inst.kei_target_death_fn = nil
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

local function OnHammered(inst)
    -- 被锤毁时掉落基础材料；若正在记录，先走取消逻辑返还空白 CD。
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:DropLoot()
    end
    if inst.kei_state == "recording" then
        StopKeiRecording(inst)
    end
    SpawnPrefab("collapse_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
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
    -- 部署完成时播放一次启动动画。
    inst.AnimState:PlayAnimation("activate")
    inst.AnimState:PushAnimation("idle_off", true)
end

local function recorder_fn()
    local inst = CreateEntity()

    -- 记录仪是可部署结构，因此需要实体、声音、网络和八方向朝向。
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()
    inst.AnimState:SetBank("wagpunk_fence")
    inst.AnimState:SetBuild("wagpunk_cagewall")
    inst.AnimState:PlayAnimation("idle_off", true)

    inst:AddTag("structure")
    inst:AddTag("kei_data_recorder")

    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)

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
    workable:SetWorkLeft(3)
    workable:SetOnFinishCallback(OnHammered)
    workable:SetOnWorkCallback(OnHit)

    inst.kei_state = "idle"
    -- 把记录仪交互函数挂到实例上，供 kei_actions.lua 的动作调用。
    inst.StartKeiRecording = StartKeiRecording
    inst.StopKeiRecording = StopKeiRecording
    inst.HarvestKeiData = HarvestKeiData

    inst:ListenForEvent("onbuilt", OnBuilt)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

local function kit_postinit(inst)
    -- 设计未指定部署包图标时，统一使用 wagstaff_item_2 占位。
    inst.components.inventoryitem:ChangeImageName("wagstaff_item_2")
end

-- 同时返回结构 prefab、部署包 prefab 和 placer。
return Prefab("kei_data_recorder", recorder_fn, assets, { "collapse_small", "kei_blank_cd", "kei_combat_data_cd" }),
    MakeDeployableKitItem(
        "kei_data_recorder_item",
        "kei_data_recorder",
        "wagstaff_personal_items",
        "wagstaff_personal_items",
        "clipboard",
        item_assets,
        { size = "small", y_offset = nil, scale = 0.8 },
        { "kei_data_recorder_item" },
        nil,
        { deploymode = DEPLOYMODE.DEFAULT, deployspacing = DEPLOYSPACING.DEFAULT },
        TUNING.STACK_SIZE_SMALLITEM,
        kit_postinit
    ),
    MakePlacer("kei_data_recorder_item_placer", "wagpunk_fence", "wagpunk_cagewall", "idle_off", false, nil, nil, nil, nil, "eight")
