-- 宠物协议出战：按具体 CD 管理召唤、收回与死亡复活冷却。
local PetData = require("kei/protocols/pet/data")
local PetStats = require("kei/protocols/pet/stats")

local PetDeployment = {}

local TARGET_CANT_TAGS = {
    "INLIMBO",
    "playerghost",
    "notarget",
    "noattack",
    "companion",
    "kei_protocol_pet",
}

local function IsValidTarget(owner, target)
    return owner ~= nil
        and target ~= nil
        and target:IsValid()
        and target ~= owner
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and owner.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

local function FindPetTarget(pet)
    local owner = pet.kei_pet_owner
    if owner == nil or not owner:IsValid() then
        return nil
    end

    local owner_target = owner.components.combat ~= nil and owner.components.combat.target or nil
    if IsValidTarget(owner, owner_target) then
        return owner_target
    end

    return FindEntity(owner, TUNING.KEI_PET_TARGET_RANGE or 12, function(target)
        return not target:HasTag("player") and IsValidTarget(owner, target)
    end, { "_combat" }, TARGET_CANT_TAGS)
end

local function KeepPetTarget(pet, target)
    local owner = pet.kei_pet_owner
    return IsValidTarget(owner, target)
        and owner:GetDistanceSqToInst(target) <= (TUNING.KEI_PET_TARGET_RANGE or 12) ^ 2
end

local function UpdatePetFollow(pet)
    local owner = pet.kei_pet_owner
    if owner == nil or not owner:IsValid() or owner:HasTag("playerghost") then
        return
    end

    local distance_sq = pet:GetDistanceSqToInst(owner)
    local teleport_distance = TUNING.KEI_PET_TELEPORT_DISTANCE or 30
    if distance_sq > teleport_distance * teleport_distance then
        local offset = FindWalkableOffset(owner:GetPosition(), math.random() * TWOPI, 2, 8, true, false)
        local pt = owner:GetPosition() + (offset or Vector3(0, 0, 0))
        if pet.Physics ~= nil then
            pet.Physics:Teleport(pt:Get())
        else
            pet.Transform:SetPosition(pt:Get())
        end
        return
    end

    local combat = pet.components.combat
    if distance_sq > (TUNING.KEI_PET_FOLLOW_DISTANCE or 6) ^ 2
        and pet.components.locomotor ~= nil
        and (combat == nil or combat.target == nil)
    then
        pet.components.locomotor:GoToPoint(owner:GetPosition())
    end
end

local function SuppressPetLoot(pet)
    local lootdropper = pet.components.lootdropper
    if lootdropper ~= nil then
        lootdropper:SetLoot({})
        lootdropper.chanceloot = nil
        lootdropper.randomloot = nil
        lootdropper.numrandomloot = nil
    end
end

local function StopPetTasks(pet)
    if pet._kei_pet_follow_task ~= nil then
        pet._kei_pet_follow_task:Cancel()
        pet._kei_pet_follow_task = nil
    end
    if pet._kei_pet_growth_task ~= nil then
        pet._kei_pet_growth_task:Cancel()
        pet._kei_pet_growth_task = nil
    end
end

local function ConfigurePet(slots, cd, pet)
    local owner = slots.inst
    pet.persists = false
    pet.kei_pet_owner = owner
    pet.kei_pet_cd = cd
    pet:AddTag("kei_protocol_pet")
    pet:AddTag("companion")
    PetStats.ApplyToPet(pet, PetData.GetBaseStats(cd))

    if pet.components.follower == nil then
        pet:AddComponent("follower")
    end
    pet.components.follower:SetLeader(owner)

    if pet.components.combat ~= nil then
        pet.components.combat:SetRetargetFunction(1, FindPetTarget)
        pet.components.combat:SetKeepTargetFunction(KeepPetTarget)
    end
    SuppressPetLoot(pet)

    pet._kei_pet_follow_task = pet:DoPeriodicTask(0.5, UpdatePetFollow)
    local growth_period = TUNING.KEI_PET_COMPANION_GROWTH_PERIOD or 1
    pet._kei_pet_growth_task = pet:DoPeriodicTask(growth_period, function()
        if pet:IsValid()
            and pet.components.health ~= nil
            and not pet.components.health:IsDead()
            and cd ~= nil
            and cd:IsValid()
        then
            local stats = PetData.GetBaseStats(cd)
            PetData.AddFriendship(cd, stats.experience_growth_rate * growth_period)
        end
    end)
    pet:ListenForEvent("death", function()
        StopPetTasks(pet)
        if cd ~= nil and cd:IsValid() then
            PetData.StartReviveCooldown(cd)
        end
        if slots._kei_active_pets ~= nil then
            slots._kei_active_pets[cd] = nil
        end
    end)
    pet:ListenForEvent("onremove", function()
        if not pet._kei_pet_recalling
            and pet.components.health ~= nil
            and not pet.components.health:IsDead()
            and cd ~= nil
            and cd:IsValid()
        then
            PetData.StartReviveCooldown(cd)
        end
        if slots._kei_active_pets ~= nil and slots._kei_active_pets[cd] == pet then
            slots._kei_active_pets[cd] = nil
        end
    end)
end

local function SpawnPet(slots, cd)
    if not PetData.IsReady(cd) then
        return nil
    end
    local data = cd.kei_protocol_data
    local success, pet = pcall(SpawnPrefab, data ~= nil and data.pet_prefab or nil)
    if not success or pet == nil then
        print("[Tendou-Kei] Failed to spawn protocol pet: " .. tostring(data ~= nil and data.pet_prefab or nil))
        return nil
    end

    local owner = slots.inst
    local offset = FindWalkableOffset(owner:GetPosition(), math.random() * TWOPI, 2, 8, true, false)
    local pt = owner:GetPosition() + (offset or Vector3(0, 0, 0))
    pet.Transform:SetPosition(pt:Get())
    local configured, err = pcall(ConfigurePet, slots, cd, pet)
    if not configured then
        print("[Tendou-Kei] Failed to configure protocol pet: " .. tostring(err))
        pet:Remove()
        return nil
    end
    return pet
end

local function RemovePet(slots, cd, pet, start_cooldown)
    if pet ~= nil and pet:IsValid() then
        pet._kei_pet_recalling = true
        StopPetTasks(pet)
        pet:Remove()
    end
    slots._kei_active_pets[cd] = nil
    if start_cooldown and cd ~= nil and cd:IsValid() then
        PetData.StartRecallCooldown(cd)
    end
end

function PetDeployment.Refresh(slots, entries)
    slots._kei_active_pets = slots._kei_active_pets or {}
    local desired = {}
    for _, entry in ipairs(entries or {}) do
        desired[entry.item] = true
    end

    for cd, pet in pairs(slots._kei_active_pets) do
        if not desired[cd] then
            RemovePet(slots, cd, pet, true)
        elseif pet == nil or not pet:IsValid() or (pet.components.health ~= nil and pet.components.health:IsDead()) then
            slots._kei_active_pets[cd] = nil
        end
    end

    for _, entry in ipairs(entries or {}) do
        local cd = entry.item
        if slots._kei_active_pets[cd] == nil and PetData.IsReady(cd) then
            slots._kei_active_pets[cd] = SpawnPet(slots, cd)
        end
    end
end

function PetDeployment.Clear(slots, start_cooldown)
    slots._kei_active_pets = slots._kei_active_pets or {}
    local active = slots._kei_active_pets
    slots._kei_active_pets = {}
    for cd, pet in pairs(active) do
        if pet ~= nil and pet:IsValid() then
            pet._kei_pet_recalling = true
            StopPetTasks(pet)
            pet:Remove()
        end
        if start_cooldown and cd ~= nil and cd:IsValid() then
            PetData.StartRecallCooldown(cd)
        end
    end
end

return PetDeployment
