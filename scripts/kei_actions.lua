local VALID_RECORD_TARGETS = {
    deerclops = true,
    bearger = true,
    dragonfly = true,
}

-- 兼容可堆叠物品和单件物品的统一消耗函数。
local function ConsumeOne(item)
    if item == nil or not item:IsValid() then
        return
    end
    if item.components.stackable ~= nil then
        item.components.stackable:Get():Remove()
    else
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

local function FindRecorderAndTarget(doer)
    -- 绑定空白 CD 时，寻找附近空闲记录仪以及记录仪范围内最近的有效巨兽。
    local x, y, z = doer.Transform:GetWorldPosition()
    local recorders = TheSim:FindEntities(x, y, z, TUNING.KEI_RECORDER_RANGE, { "kei_data_recorder" }, { "burnt" })
    local best_recorder = nil
    local best_target = nil
    local best_dsq = nil

    for _, recorder in ipairs(recorders) do
        if recorder.kei_state == "idle" then
            local rx, ry, rz = recorder.Transform:GetWorldPosition()
            local targets = TheSim:FindEntities(rx, ry, rz, TUNING.KEI_RECORDER_RANGE, { "epic", "_combat" }, { "INLIMBO", "playerghost" })
            for _, target in ipairs(targets) do
                if VALID_RECORD_TARGETS[target.prefab]
                    and target.components.health ~= nil
                    and not target.components.health:IsDead()
                then
                    local dsq = doer:GetDistanceSqToInst(target)
                    if best_dsq == nil or dsq < best_dsq then
                        best_dsq = dsq
                        best_recorder = recorder
                        best_target = target
                    end
                end
            end
        end
    end

    return best_recorder, best_target
end

-- 右键电池：把电池转化为 Kei 的电量，也就是 hunger 组件。
local charge_action = Action({ mount_valid = true })
charge_action.id = "KEI_CHARGE"
charge_action.str = "充电"
charge_action.fn = function(act)
    if not IsKei(act.doer) or act.invobject == nil then
        return false
    end
    if act.doer.components.hunger ~= nil then
        act.doer.components.hunger:DoDelta(TUNING.KEI_BATTERY_POWER)
    end
    ConsumeOne(act.invobject)
    Say(act.doer, "ANNOUNCE_KEI_CHARGED")
    return true
end
AddAction(charge_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_CHARGE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_CHARGE, "doshortaction"))

-- 右键修理工具：恢复机体完整度，也就是 health 组件。
local repair_action = Action({ mount_valid = true })
repair_action.id = "KEI_REPAIR"
repair_action.str = "修复"
repair_action.fn = function(act)
    if not IsKei(act.doer) or act.invobject == nil then
        return false
    end
    if act.doer.components.health ~= nil and not act.doer.components.health:IsDead() then
        act.doer.components.health:DoDelta(TUNING.KEI_REPAIR_VALUE, nil, "kei_repair_tool")
    end
    ConsumeOne(act.invobject)
    Say(act.doer, "ANNOUNCE_KEI_REPAIRED")
    return true
end
AddAction(repair_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_REPAIR, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_REPAIR, "doshortaction"))

-- 使用 Mk1/Mk2/Mk3 模块扩展协议槽数量：1 -> 3 -> 5 -> 7。
local unlock_action = Action({ mount_valid = true })
unlock_action.id = "KEI_UNLOCK_PROTOCOL"
unlock_action.str = "扩展协议槽"
unlock_action.fn = function(act)
    if not IsKei(act.doer) or act.invobject == nil or act.doer.components.kei_protocolslots == nil then
        return false
    end
    local tier = act.invobject.kei_unlock_tier
    if tier == nil then
        return false
    end
    if act.doer.components.kei_protocolslots:UnlockTier(tier) then
        ConsumeOne(act.invobject)
        Say(act.doer, "ANNOUNCE_KEI_PROTOCOL_UNLOCK")
        return true
    end
    return false
end
AddAction(unlock_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_UNLOCK_PROTOCOL, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_UNLOCK_PROTOCOL, "doshortaction"))

-- 空白 CD 先绑定目标，之后才能提交给数据记录仪开始记录。
local bind_cd_action = Action({ mount_valid = true })
bind_cd_action.id = "KEI_BIND_CD"
bind_cd_action.str = "绑定样本"
bind_cd_action.fn = function(act)
    if not IsKei(act.doer) or act.invobject == nil or not act.invobject:HasTag("kei_blank_cd") then
        return false
    end
    local recorder, target = FindRecorderAndTarget(act.doer)
    if recorder == nil then
        Say(act.doer, "ANNOUNCE_KEI_NO_RECORDER")
        return false
    end
    if target == nil then
        Say(act.doer, "ANNOUNCE_KEI_NO_TARGET")
        return false
    end
    act.invobject:SetBoundTarget(target)
    Say(act.doer, "ANNOUNCE_KEI_BOUND")
    return true
end
AddAction(bind_cd_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_BIND_CD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_BIND_CD, "doshortaction"))

-- 把已绑定目标的空白 CD 交给数据记录仪。
local submit_cd_action = Action({ mount_valid = true })
submit_cd_action.id = "KEI_SUBMIT_CD"
submit_cd_action.str = "提交记录"
submit_cd_action.fn = function(act)
    if not IsKei(act.doer) or act.target == nil or act.invobject == nil or act.target.StartKeiRecording == nil then
        return false
    end
    return act.target:StartKeiRecording(act.invobject, act.doer)
end
AddAction(submit_cd_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_SUBMIT_CD, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_SUBMIT_CD, "give"))

-- 记录中途取消会返还一张空白 CD，记录仪回到 idle。
local stop_record_action = Action({ mount_valid = true })
stop_record_action.id = "KEI_STOP_RECORD"
stop_record_action.str = "停止记录"
stop_record_action.fn = function(act)
    if not IsKei(act.doer) or act.target == nil or act.target.StopKeiRecording == nil then
        return false
    end
    return act.target:StopKeiRecording(act.doer)
end
AddAction(stop_record_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_STOP_RECORD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_STOP_RECORD, "doshortaction"))

-- 巨兽死亡后，从记录仪收获对应的战斗协议 CD。
local harvest_action = Action({ mount_valid = true })
harvest_action.id = "KEI_HARVEST_RECORD"
harvest_action.str = "收获数据"
harvest_action.fn = function(act)
    if not IsKei(act.doer) or act.target == nil or act.target.HarvestKeiData == nil then
        return false
    end
    return act.target:HarvestKeiData(act.doer)
end
AddAction(harvest_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_HARVEST_RECORD, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_HARVEST_RECORD, "doshortaction"))

local function AnalyzeEquipment(tool, target, doer)
    -- 只解析可装备物品；容器类物品即使可检查也不生成协议。
    if target.components.container ~= nil then
        return false
    end
    if target.components.equippable == nil then
        return false
    end

    local slot = target.components.equippable.equipslot
    local data = {
        source = target.prefab,
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
        data.damage_mult = damage > 0 and math.max(1, damage / TUNING.UNARMED_DAMAGE) or 1
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
    Say(doer, "ANNOUNCE_KEI_ANALYSIS_DONE")
    return true
end

-- 用解析工具点装备，生成可插入协议槽的解析 CD。
local analyze_action = Action({ mount_valid = true })
analyze_action.id = "KEI_ANALYZE_EQUIP"
analyze_action.str = "解析装备"
analyze_action.fn = function(act)
    if not IsKei(act.doer) or act.invobject == nil or act.target == nil then
        return false
    end
    if AnalyzeEquipment(act.invobject, act.target, act.doer) then
        return true
    end
    Say(act.doer, "ANNOUNCE_KEI_ANALYSIS_FAILED")
    ConsumeOne(act.invobject)
    return false
end
AddAction(analyze_action)
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_ANALYZE_EQUIP, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_ANALYZE_EQUIP, "give"))

-- INVENTORY：右键背包物品时添加 Kei 专属动作。
AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions, right)
    if not right or not IsKei(doer) then
        return
    end
    if inst:HasTag("kei_battery") then
        table.insert(actions, ACTIONS.KEI_CHARGE)
    elseif inst:HasTag("kei_repair_tool") then
        table.insert(actions, ACTIONS.KEI_REPAIR)
    elseif inst:HasTag("kei_protocol_unlocker") then
        table.insert(actions, ACTIONS.KEI_UNLOCK_PROTOCOL)
    elseif inst:HasTag("kei_blank_cd") and inst.kei_bound_prefab == nil then
        table.insert(actions, ACTIONS.KEI_BIND_CD)
    end
end)

-- USEITEM：拿着某个物品点另一个目标时添加动作，例如 CD -> 记录仪、解析工具 -> 装备。
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if not right or not IsKei(doer) or target == nil then
        return
    end
    if inst:HasTag("kei_blank_cd") and target:HasTag("kei_data_recorder") then
        table.insert(actions, ACTIONS.KEI_SUBMIT_CD)
    elseif inst:HasTag("kei_analysis_tool") and target.replica.equippable ~= nil then
        table.insert(actions, ACTIONS.KEI_ANALYZE_EQUIP)
    end
end)

-- SCENE：空手右键记录仪，根据状态显示停止记录或收获数据。
AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
    if not right or not IsKei(doer) or not inst:HasTag("kei_data_recorder") then
        return
    end
    if inst.kei_state == "recording" then
        table.insert(actions, ACTIONS.KEI_STOP_RECORD)
    elseif inst.kei_state == "complete" then
        table.insert(actions, ACTIONS.KEI_HARVEST_RECORD)
    end
end)
