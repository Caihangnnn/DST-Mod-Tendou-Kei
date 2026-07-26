-- 宠物捕捉动作注册：装备捕捉器后右键生物，以投掷动作发起捕捉。
local PetCapture = require("kei/protocols/pet/capture")
local PetData = require("kei/protocols/pet/data")

local function IsKei(inst)
    return inst ~= nil and inst.prefab == "kei" and not inst:HasTag("playerghost")
end

local function GetEquippedCaptureTool(doer)
    if doer == nil then
        return nil
    end
    if doer.components.inventory ~= nil then
        local item = doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        return item ~= nil and item:HasTag("kei_pet_capture_tool") and item or nil
    end
    if doer.replica ~= nil and doer.replica.inventory ~= nil then
        local item = doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        return item ~= nil and item:HasTag("kei_pet_capture_tool") and item or nil
    end
    return nil
end

local capture_action = AddAction("KEI_CAPTURE_PET", "捕捉", function(act)
    if not IsKei(act.doer) or not PetCapture.IsValidTarget(act.target) then
        return false
    end
    local tool = GetEquippedCaptureTool(act.doer)
    return tool ~= nil and tool.LaunchCapture ~= nil and tool:LaunchCapture(act.doer, act.target) or false
end)
capture_action.rmb = true
capture_action.mount_valid = true
capture_action.distance = TUNING.KEI_PET_CAPTURE_RANGE or 12
capture_action.priority = 5

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_CAPTURE_PET, "throw"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_CAPTURE_PET, "throw"))

AddComponentAction("SCENE", "health", function(inst, doer, actions, right)
    if right and IsKei(doer) and GetEquippedCaptureTool(doer) ~= nil and PetCapture.IsPotentialTarget(inst) then
        table.insert(actions, ACTIONS.KEI_CAPTURE_PET)
    end
end)

local function ConsumeOne(inst)
    if inst.components.stackable ~= nil then
        inst.components.stackable:Get():Remove()
    else
        inst:Remove()
    end
end

local feed_exp_action = AddAction("KEI_FEED_PET_EXP", "喂经验书", function(act)
    local book = act.invobject
    local cd = act.target
    if not IsKei(act.doer)
        or book == nil
        or not book:HasTag("kei_pet_exp_book")
        or cd == nil
        or not cd:HasTag("kei_pet_protocol")
        or not PetData.IsBound(cd)
        or PetData.IsInserted(cd)
    then
        return false
    end

    local value = tonumber(book.kei_pet_exp_value) or 0
    if value <= 0 then
        return false
    end
    PetData.AddFriendship(cd, value)
    ConsumeOne(book)
    return true
end)
feed_exp_action.rmb = true
feed_exp_action.mount_valid = true
feed_exp_action.priority = 4

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.KEI_FEED_PET_EXP, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.KEI_FEED_PET_EXP, "give"))

AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if right
        and IsKei(doer)
        and inst:HasTag("kei_pet_exp_book")
        and target ~= nil
        and target:HasTag("kei_pet_protocol")
    then
        table.insert(actions, ACTIONS.KEI_FEED_PET_EXP)
    end
end)
