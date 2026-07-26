-- 宠物捕捉：校验目标并把生物转换为一张独立的宠物协议 CD。
local PetPersonality = require("kei/protocols/pet/personality")
local PetStats = require("kei/protocols/pet/stats")

local PetCapture = {}

local INVALID_TAGS = {
    "INLIMBO",
    "NOCLICK",
    "FX",
    "DECOR",
    "player",
    "playerghost",
    "epic",
    "structure",
    "wall",
    "kei_protocol_pet",
}

local function HasAnyTag(inst, tags)
    for _, tag in ipairs(tags) do
        if inst:HasTag(tag) then
            return true
        end
    end
    return false
end

function PetCapture.GetEquippedTool(doer)
    local inventory = doer ~= nil and doer.components.inventory or nil
    return inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

function PetCapture.IsPotentialTarget(target)
    return target ~= nil
        and target:IsValid()
        and target.prefab ~= nil
        and not HasAnyTag(target, INVALID_TAGS)
end

function PetCapture.IsValidTarget(target)
    if not PetCapture.IsPotentialTarget(target)
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.inventoryitem ~= nil
        or target.components.stackable ~= nil
        or target.persists == false
    then
        return false
    end

    local follower = target.components.follower
    return follower == nil or follower:GetLeader() == nil
end

local function GivePetCD(doer, cd, target)
    if doer ~= nil and doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(cd, nil, doer:GetPosition())
    else
        cd.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

function PetCapture.TryCapture(doer, target)
    if doer == nil or not doer:IsValid() or not PetCapture.IsValidTarget(target) then
        return false
    end

    local cd = SpawnPrefab("kei_pet_cd")
    if cd == nil or cd.SetCapturedPet == nil then
        if cd ~= nil then
            cd:Remove()
        end
        return false
    end

    local personality = PetPersonality.GetDefaultId()
    cd:SetCapturedPet({
        pet_prefab = target.prefab,
        pet_name = target:GetDisplayName(),
        personality = personality,
        base_stats = PetStats.Capture(target, personality),
    })
    GivePetCD(doer, cd, target)

    target:AddTag("INLIMBO")
    target.persists = false
    target:Remove()
    return true
end

return PetCapture
