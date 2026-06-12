local CombatProtocolDefs = require("kei_combat_protocol_defs")
local EyeOfTerrorDash = require("kei_eyeofterror_dash")
local SpDamageUtil = require("components/spdamageutil")

local VALID_RECORD_TARGETS = CombatProtocolDefs.VALID_RECORD_TARGETS

local ANALYSIS_BLACKLIST = {
    armorwagpunk = true,
    batnosehat = true,
    wagpunkhat = true,
}

local RECORDER_STATE = {
    idle = 0,
    recording = 1,
    complete = 2,
}

local function GetRecorderState(inst)
    if inst == nil then
        return RECORDER_STATE.idle
    end
    if inst._kei_recorder_state ~= nil then
        return inst._kei_recorder_state:value()
    end
    if inst.kei_state == "recording" then
        return RECORDER_STATE.recording
    elseif inst.kei_state == "complete" then
        return RECORDER_STATE.complete
    end
    return RECORDER_STATE.idle
end

-- 兼容可堆叠物品和单件物品的统一消耗函数。
local function ConsumeOne(item)
    if item == nil or not item:IsValid() then
        return
    end
    if item.components.stackable ~= nil then
        local one = item.components.stackable:Get()
        if one ~= nil then
            one:Remove()
        end
    else
        if item.components.inventoryitem ~= nil and item.components.inventoryitem.owner ~= nil then
            item.components.inventoryitem:RemoveFromOwner(true)
        end
        item:Remove()
    end
end

local function Say(doer, key)
    -- 所有提示都走 Kei 的角色语音表，避免在动作里散落硬编码文本。
    if doer ~= nil and doer.components.talker ~= nil and STRINGS.CHARACTERS.KEI[key] ~= nil then
        doer.components.talker:Say(STRINGS.CHARACTERS.KEI[key])
    end
end

local function IsKei(doer)
    return doer ~= nil and doer:HasTag("kei")
end

local DASH_DAMAGE_MUST_TAGS = { "_combat" }
local DASH_DAMAGE_CANT_TAGS = { "INLIMBO", "wall", "companion", "flight", "invisible", "notarget", "noattack", "playerghost" }
local DASH_DAMAGE_SIDE_RANGE = 1
local DASH_DAMAGE_PHYSICS_PADDING = 3

local function GetEquippedWeapon(doer)
    return doer.components.inventory ~= nil and doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

local function IsDashDamageTarget(doer, target)
    return target ~= doer
        and target:IsValid()
        and not target:IsInLimbo()
        and target.components.combat ~= nil
        and doer.components.combat ~= nil
        and doer.components.combat:IsValidTarget(target)
        and not (target.components.health ~= nil and target.components.health:IsDead())
end

local function HitDashTarget(doer, target, weapon)
    if not IsDashDamageTarget(doer, target) then
        return
    end

    local damage, spdamage = doer.components.combat:CalcDamage(target, weapon)
    damage = damage * 2
    spdamage = SpDamageUtil.ApplyMult(spdamage, 2)
    target.components.combat:GetAttacked(doer, damage, weapon, nil, spdamage)
end

local function DoEyeOfTerrorDashDamage(doer, startpt, endpt)
    if doer.components.combat == nil or startpt == nil or endpt == nil then
        return
    end

    local p1 = { x = startpt.x, y = startpt.z }
    local p2 = { x = endpt.x, y = endpt.z }
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local dist = dx * dx + dy * dy
    local weapon = GetEquippedWeapon(doer)
    local hit = {}
    local pv = {}

    if dist > 0 then
        dist = math.sqrt(dist)
        local radius = (dist + doer.components.combat.hitrange * 0.5 + DASH_DAMAGE_PHYSICS_PADDING) * 0.5
        dx = dx / dist
        dy = dy / dist
        local cx = p1.x + dx * radius
        local cz = p1.y + dy * radius

        local targets = TheSim:FindEntities(cx, 0, cz, radius, DASH_DAMAGE_MUST_TAGS, DASH_DAMAGE_CANT_TAGS)
        for _, target in ipairs(targets) do
            if IsDashDamageTarget(doer, target) then
                pv.x, pv._, pv.y = target.Transform:GetWorldPosition()
                local range = DASH_DAMAGE_SIDE_RANGE + target:GetPhysicsRadius(0.5)
                if DistPointToSegmentXYSq(pv, p1, p2) < range * range then
                    hit[target] = true
                    HitDashTarget(doer, target, weapon)
                end
            end
        end
    end

    local angle = (doer.Transform:GetRotation() + 90) * DEGREES
    local p3 = {
        x = p2.x + doer.components.combat.hitrange * math.sin(angle),
        y = p2.y + doer.components.combat.hitrange * math.cos(angle),
    }
    local targets = TheSim:FindEntities(p2.x, 0, p2.y, doer.components.combat.hitrange + DASH_DAMAGE_PHYSICS_PADDING, DASH_DAMAGE_MUST_TAGS, DASH_DAMAGE_CANT_TAGS)
    for _, target in ipairs(targets) do
        if not hit[target] and IsDashDamageTarget(doer, target) then
            pv.x, pv._, pv.y = target.Transform:GetWorldPosition()
            local radius = target:GetPhysicsRadius(0.5)
            local range = doer.components.combat.hitrange + radius
            if distsq(pv.x, pv.y, p2.x, p2.y) < range * range then
                range = DASH_DAMAGE_SIDE_RANGE + radius
                if DistPointToSegmentXYSq(pv, p2, p3) < range * range then
                    HitDashTarget(doer, target, weapon)
                end
            end
        end
    end
end

local function DoEyeOfTerrorDash(doer, targetpos)
    local pt = EyeOfTerrorDash.GetTargetPoint(doer, targetpos)
    if pt == nil then
        return false
    end

    local startpt = doer:GetPosition()
    doer:ForceFacePoint(pt)
    local fx = SpawnPrefab("spear_wathgrithr_lightning_lunge_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(pt:Get())
        fx.Transform:SetRotation(doer:GetRotation())
    end
    if doer.SoundEmitter ~= nil then
        doer.SoundEmitter:PlaySound("meta3/wigfrid/spear_lighting_lunge")
    end

    DoEyeOfTerrorDashDamage(doer, startpt, pt)
    doer.Physics:Teleport(pt.x, 0, pt.z)
    return true
end

local function IsValidRecordTarget(target)
    return target ~= nil
        and target:IsValid()
        and VALID_RECORD_TARGETS[target.prefab]
        and target:HasTag("epic")
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and not target:HasTag("INLIMBO")
end

local function IsAnalysisBlacklisted(target)
    return target ~= nil and ANALYSIS_BLACKLIST[target.prefab]
end

local function GetPrefabDisplayName(prefab)
    return prefab ~= nil and (STRINGS.NAMES[string.upper(prefab)] or prefab) or nil
end

local function GetTargetDisplayName(target)
    if target == nil then
        return nil
    end
    return target:GetDisplayName() or GetPrefabDisplayName(target.prefab)
end

local WORLD_ANIM_CANDIDATES = {
    "anim",
    "idle",
    "idle_loop",
    "idle1",
    "idle2",
    "idle3",
    "idle4",
}

local function GetTargetWorldAnim(target, slot)
    if target ~= nil and target.AnimState ~= nil then
        for _, anim in ipairs(WORLD_ANIM_CANDIDATES) do
            if target.AnimState:IsCurrentAnimation(anim) then
                return anim
            end
        end
    end
    return slot == EQUIPSLOTS.HANDS and "idle" or "anim"
end

local function FindRecorderForTarget(target)
    -- 手持空白 CD 点巨兽时，寻找能覆盖该巨兽的空闲记录仪。
    if not IsValidRecordTarget(target) then
        return nil
    end
    local x, y, z = target.Transform:GetWorldPosition()
    local recorders = TheSim:FindEntities(x, y, z, TUNING.KEI_RECORDER_RANGE, { "kei_data_recorder" }, { "burnt" })
    local best_recorder = nil
    local best_dsq = nil

    for _, recorder in ipairs(recorders) do
        if GetRecorderState(recorder) == RECORDER_STATE.idle
            and recorder:GetDistanceSqToInst(target) <= TUNING.KEI_RECORDER_RANGE * TUNING.KEI_RECORDER_RANGE
        then
            local dsq = recorder:GetDistanceSqToInst(target)
            if best_dsq == nil or dsq < best_dsq then
                best_dsq = dsq
                best_recorder = recorder
            end
        end
    end

    return best_recorder
end

-- 右键电池：把电池转化为 Kei 的电量，也就是 hunger 组件。
local charge_action = AddAction("KEI_CHARGE", "充电", function(act)
    if not IsKei(act.doer) or act.invobject == nil then
        return false
    end
    if act.doer.components.hunger ~= nil then
        act.doer.components.hunger:DoDelta(TUNING.KEI_BATTERY_POWER)
    end
    ConsumeOne(act.invobject)
    Say(act.doer, "ANNOUNCE_KEI_CHARGED")
    return true
end)
charge_action.mount_valid = true
charge_action.rmb = true
charge_action.priority = 2
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_CHARGE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_CHARGE, "doshortaction"))

-- 右键修理工具：恢复机体完整度，也就是 health 组件。
local repair_action = AddAction("KEI_REPAIR", "修复", function(act)
    if not IsKei(act.doer) or act.invobject == nil then
        return false
    end
    if act.doer.components.health ~= nil and not act.doer.components.health:IsDead() then
        act.doer.components.health:DoDelta(TUNING.KEI_REPAIR_VALUE, nil, "kei_repair_tool")
    end
    ConsumeOne(act.invobject)
    Say(act.doer, "ANNOUNCE_KEI_REPAIRED")
    return true
end)
repair_action.mount_valid = true
repair_action.rmb = true
repair_action.priority = 2
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_REPAIR, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_REPAIR, "doshortaction"))

local EYEOFTERROR_DASH_ANIM_SPEED = 2

-- 恐怖之眼战斗数据：右键点地选择方向，确认后冲锋到鼠标指定位置，最多 12 距离单位且不造成伤害。
local eyeofterror_dash_action = AddAction("KEI_EYEOFTERROR_DASH", "冲锋", function(act)
    if not IsKei(act.doer) or not EyeOfTerrorDash.HasProtocol(act.doer) then
        return false
    end
    local pt = act:GetActionPoint()
    return pt ~= nil and DoEyeOfTerrorDash(act.doer, pt) or false
end)
eyeofterror_dash_action.mount_valid = true
eyeofterror_dash_action.rmb = true
eyeofterror_dash_action.distance = math.huge
eyeofterror_dash_action.priority = 3
eyeofterror_dash_action.invalid_hold_action = true

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_EYEOFTERROR_DASH, "kei_eyeofterror_dash_pre"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_EYEOFTERROR_DASH, "kei_eyeofterror_dash_pre"))

AddStategraphState("wilson", State{
    name = "kei_eyeofterror_dash_pre",
    tags = { "aoe", "doing", "busy", "nointerrupt", "nomorph" },

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:SetDeltaTimeMultiplier(EYEOFTERROR_DASH_ANIM_SPEED)
        inst.AnimState:PlayAnimation("lunge_pre")
    end,

    timeline =
    {
        TimeEvent(4 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/twirl", nil, nil, true)
        end),
    },

    events =
    {
        EventHandler("animover", function(inst)
            if not inst.AnimState:AnimDone() then
                return
            end
            if inst.AnimState:IsCurrentAnimation("lunge_pre") then
                if inst:PerformBufferedAction() then
                    inst.AnimState:SetDeltaTimeMultiplier(EYEOFTERROR_DASH_ANIM_SPEED)
                    inst.AnimState:PlayAnimation("lunge_pst")
                    if inst.components.bloomer ~= nil then
                        inst.components.bloomer:PushBloom("kei_eyeofterror_dash", "shaders/anim.ksh", -2)
                    end
                    if inst.components.colouradder ~= nil then
                        inst.components.colouradder:PushColour("kei_eyeofterror_dash", 1, 0.2, 0.2, 0)
                    end
                else
                    inst.sg:GoToState("idle")
                end
            else
                inst.sg:GoToState("idle")
            end
        end),
    },

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
        if inst.components.bloomer ~= nil then
            inst.components.bloomer:PopBloom("kei_eyeofterror_dash")
        end
        if inst.components.colouradder ~= nil then
            inst.components.colouradder:PopColour("kei_eyeofterror_dash")
        end
    end,
})

AddStategraphState("wilson_client", State{
    name = "kei_eyeofterror_dash_pre",
    tags = { "doing", "busy", "nointerrupt" },
    server_states = { "kei_eyeofterror_dash_pre" },

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:SetDeltaTimeMultiplier(EYEOFTERROR_DASH_ANIM_SPEED)
        inst.AnimState:PlayAnimation("lunge_pre")
        inst.AnimState:PushAnimation("lunge_lag", false)
        inst:PerformPreviewBufferedAction()
        inst.sg:SetTimeout(2)
    end,

    timeline =
    {
        TimeEvent(4 * FRAMES, function(inst)
            inst.sg.statemem.twirled = true
            inst.SoundEmitter:PlaySound("dontstarve/common/twirl", nil, nil, true)
        end),
    },

    onupdate = function(inst)
        if inst.sg:ServerStateMatches() then
            if inst.entity:FlattenMovementPrediction() then
                if not inst.sg.statemem.twirled then
                    inst.SoundEmitter:PlaySound("dontstarve/common/twirl", nil, nil, true)
                end
                inst.sg:GoToState("idle", "noanim")
            end
        elseif inst.bufferedaction == nil then
            inst.sg:GoToState("idle")
        end
    end,

    ontimeout = function(inst)
        inst:ClearBufferedAction()
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
})

-- 空白 CD 先绑定目标，之后才能提交给数据记录仪开始记录。
local bind_cd_action = AddAction("KEI_BIND_CD", "绑定样本", function(act)
    if not IsKei(act.doer) or act.invobject == nil or not act.invobject:HasTag("kei_blank_cd") then
        return false
    end
    local target = act.target
    if not IsValidRecordTarget(target) then
        Say(act.doer, "ANNOUNCE_KEI_NO_TARGET")
        return false
    end
    local recorder = FindRecorderForTarget(target)
    if recorder == nil then
        Say(act.doer, "ANNOUNCE_KEI_NO_RECORDER")
        return false
    end
    act.invobject:SetBoundTarget(target)
    Say(act.doer, "ANNOUNCE_KEI_BOUND")
    return true
end)
bind_cd_action.mount_valid = true
bind_cd_action.rmb = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_BIND_CD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_BIND_CD, "doshortaction"))

-- 把已绑定目标的空白 CD 交给数据记录仪。
local submit_cd_action = AddAction("KEI_SUBMIT_CD", "提交记录", function(act)
    if not IsKei(act.doer) or act.target == nil or act.invobject == nil or act.target.StartKeiRecording == nil then
        return false
    end
    if act.invobject.kei_bound_prefab == nil then
        Say(act.doer, "ANNOUNCE_KEI_CD_NOT_BOUND")
        return false
    end
    return act.target:StartKeiRecording(act.invobject, act.doer)
end)
submit_cd_action.mount_valid = true
submit_cd_action.rmb = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_SUBMIT_CD, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_SUBMIT_CD, "give"))

-- 记录中途取消会返还一张空白 CD，记录仪回到 idle。
local stop_record_action = AddAction("KEI_STOP_RECORD", "停止记录", function(act)
    if not IsKei(act.doer) or act.target == nil or act.target.StopKeiRecording == nil then
        return false
    end
    return act.target:StopKeiRecording(act.doer)
end)
stop_record_action.mount_valid = true
stop_record_action.rmb = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_STOP_RECORD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_STOP_RECORD, "doshortaction"))

-- 巨兽死亡后，从记录仪收获对应的战斗协议 CD。
local harvest_action = AddAction("KEI_HARVEST_RECORD", "收获数据", function(act)
    if not IsKei(act.doer) or act.target == nil or act.target.HarvestKeiData == nil then
        return false
    end
    return act.target:HarvestKeiData(act.doer)
end)
harvest_action.mount_valid = true
harvest_action.rmb = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_HARVEST_RECORD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_HARVEST_RECORD, "doshortaction"))

-- 未激活的数据记录器可以空手右键收回为部署包。
local packup_record_action = AddAction("KEI_PACKUP_RECORDER", "收回", function(act)
    if not IsKei(act.doer) or act.target == nil or act.target.PackUpKeiRecorder == nil then
        return false
    end
    return act.target:PackUpKeiRecorder(act.doer)
end)
packup_record_action.mount_valid = true
packup_record_action.rmb = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_PACKUP_RECORDER, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_PACKUP_RECORDER, "doshortaction"))

local function AnalyzeEquipment(tool, target, doer)
    if IsAnalysisBlacklisted(target) then
        return false
    end

    -- 只解析可装备物品；容器类物品即使可检查也不生成协议。
    if target.components.container ~= nil then
        return false
    end
    if target.components.equippable == nil then
        return false
    end

    local slot = target.components.equippable.equipslot
    local inventoryitem = target.components.inventoryitem
    local data = {
        source = target.prefab,
        display_name = GetTargetDisplayName(target),
        icon_image = inventoryitem ~= nil and (inventoryitem.imagename or target.prefab) or target.prefab,
        icon_atlas = inventoryitem ~= nil and inventoryitem.atlasname or nil,
        visual_bank = target.AnimState ~= nil and target.AnimState:GetBankHash() or nil,
        visual_build = target.AnimState ~= nil and target.AnimState:GetBuild() or nil,
        visual_anim = GetTargetWorldAnim(target, slot),
    }

    -- 头部和身体装备提取护甲吸收率；手部装备提取武器、移速和平面伤害信息。
    if slot == EQUIPSLOTS.HEAD then
        data.kind = "analysis"
        data.slot = "head"
        data.absorb = target.components.armor ~= nil and target.components.armor.absorb_percent or 0
    elseif slot == EQUIPSLOTS.BODY then
        data.kind = "analysis"
        data.slot = "body"
        data.absorb = target.components.armor ~= nil and target.components.armor.absorb_percent or 0
    elseif slot == EQUIPSLOTS.HANDS then
        data.kind = "analysis"
        data.slot = "hands"
        local damage = target.components.weapon ~= nil and FunctionOrValue(target.components.weapon.damage, target, doer, nil) or 0
        data.damage_bonus = damage
        data.speed_mult = target.components.equippable.walkspeedmult or 1
        data.planar_bonus = target.components.planardamage ~= nil and target.components.planardamage:GetDamage() or 0
    else
        return false
    end

    local cd = SpawnPrefab("kei_analysis_cd")
    if cd == nil then
        return false
    end
    -- 解析结果写入新生成的 CD，协议槽组件会在背包中读取这些数据。
    cd:SetAnalysisData(data)
    if doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(cd, nil, doer:GetPosition())
    else
        cd.Transform:SetPosition(doer.Transform:GetWorldPosition())
    end
    ConsumeOne(tool)
    if TUNING.KEI_ANALYSIS_CONSUME_EQUIPMENT then
        ConsumeOne(target)
    end
    Say(doer, "ANNOUNCE_KEI_ANALYSIS_DONE")
    return true
end

-- 用解析工具点装备，生成可插入协议槽的解析 CD。
local analyze_action = AddAction("KEI_ANALYZE_EQUIP", "解析装备", function(act)
    if not IsKei(act.doer) or act.invobject == nil or act.target == nil then
        return false
    end
    if AnalyzeEquipment(act.invobject, act.target, act.doer) then
        return true
    end
    Say(act.doer, "ANNOUNCE_KEI_ANALYSIS_FAILED")
    ConsumeOne(act.invobject)
    return false
end)
analyze_action.mount_valid = true
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_ANALYZE_EQUIP, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_ANALYZE_EQUIP, "give"))

-- USEITEM：拿着某个物品点另一个目标时添加动作，例如 CD -> 记录仪、解析工具 -> 装备。
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if not right or not IsKei(doer) or target == nil then
        return
    end
    if inst:HasTag("kei_blank_cd") and target:HasTag("kei_data_recorder") then
        table.insert(actions, ACTIONS.KEI_SUBMIT_CD)
    elseif inst:HasTag("kei_blank_cd") and inst.kei_bound_prefab == nil and target:HasTag("epic") then
        table.insert(actions, ACTIONS.KEI_BIND_CD)
    elseif inst:HasTag("kei_analysis_tool") and target.replica.equippable ~= nil and not IsAnalysisBlacklisted(target) then
        table.insert(actions, ACTIONS.KEI_ANALYZE_EQUIP)
    end
end)

-- SCENE：空手右键记录仪，根据状态显示停止记录或收获数据。
AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
    if not right or not IsKei(doer) or not inst:HasTag("kei_data_recorder") then
        return
    end
    local state = GetRecorderState(inst)
    if state == RECORDER_STATE.recording then
        table.insert(actions, ACTIONS.KEI_STOP_RECORD)
    elseif state == RECORDER_STATE.complete then
        table.insert(actions, ACTIONS.KEI_HARVEST_RECORD)
    elseif state == RECORDER_STATE.idle then
        local activeitem = doer.replica.inventory ~= nil and doer.replica.inventory:GetActiveItem() or nil
        if activeitem == nil and not inst:HasTag("NOCLICK") then
            table.insert(actions, ACTIONS.KEI_PACKUP_RECORDER)
        end
    end
end)
