-- 宠物协议数据：每张 CD 独立保存被捕捉生物、成长数据与召唤冷却。
local PetPersonality = require("kei/protocols/pet/personality")
local PetStats = require("kei/protocols/pet/stats")

local PetData = {}

PetData.RECALL_TIMER = "kei_pet_recall_cooldown"
PetData.REVIVE_TIMER = "kei_pet_revive_cooldown"

local function CopyArray(values)
    local result = {}
    for i, value in ipairs(values or {}) do
        result[i] = value
    end
    return result
end

local function GetPetDisplayName(prefab, fallback)
    return fallback or (prefab ~= nil and STRINGS.NAMES[string.upper(prefab)] or nil) or prefab
end

local function ApplyName(inst)
    local data = inst.kei_protocol_data
    local pet_name = data ~= nil and GetPetDisplayName(data.pet_prefab, data.pet_name) or nil
    if inst.components.named ~= nil then
        inst.components.named:SetName(pet_name ~= nil and (pet_name .. "宠物协议 CD") or "未绑定的宠物协议 CD")
    end
end

local function NormalizeLevel(level)
    return math.max(TUNING.KEI_PET_INITIAL_LEVEL or 1, math.floor(tonumber(level) or 1))
end

function PetData.GetFriendshipThreshold(inst)
    local data = inst ~= nil and inst.kei_protocol_data or nil
    local level = NormalizeLevel(data ~= nil and data.level or nil)
    local base = TUNING.KEI_PET_BASE_FRIENDSHIP_THRESHOLD or 1000
    local step = math.max(1, TUNING.KEI_PET_FRIENDSHIP_LEVEL_STEP or 10)
    local increment = TUNING.KEI_PET_FRIENDSHIP_THRESHOLD_INCREMENT or 1000
    return base + math.floor(level / step) * increment
end

local function PushGrowthEvent(inst, old_level)
    local data = inst.kei_protocol_data
    if data == nil then
        return
    end
    inst:PushEvent("kei_pet_growth_dirty", {
        level = data.level,
        old_level = old_level,
        friendship = data.friendship,
        threshold = PetData.GetFriendshipThreshold(inst),
    })
end

function PetData.AddLevels(inst, amount)
    if not PetData.IsBound(inst) then
        return 0
    end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        return 0
    end
    local data = inst.kei_protocol_data
    local old_level = NormalizeLevel(data.level)
    data.level = old_level + amount
    ApplyName(inst)
    PushGrowthEvent(inst, old_level)
    return amount
end

function PetData.AddFriendship(inst, amount)
    if not PetData.IsBound(inst) then
        return 0
    end
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then
        return 0
    end

    local data = inst.kei_protocol_data
    local old_level = NormalizeLevel(data.level)
    data.level = old_level
    data.friendship = math.max(0, tonumber(data.friendship) or 0) + amount

    while data.friendship >= PetData.GetFriendshipThreshold(inst) do
        data.friendship = data.friendship - PetData.GetFriendshipThreshold(inst)
        data.level = data.level + 1
    end

    if data.level ~= old_level then
        ApplyName(inst)
    end
    PushGrowthEvent(inst, old_level)
    return data.level - old_level
end

function PetData.IsInserted(inst)
    local inventoryitem = inst ~= nil and inst.components.inventoryitem or nil
    local owner = inventoryitem ~= nil and inventoryitem.owner or nil
    return owner ~= nil and owner:HasTag("kei_protocol_slot")
end

function PetData.GetBaseStats(inst)
    local data = inst ~= nil and inst.kei_protocol_data or nil
    return PetStats.Normalize(data ~= nil and data.base_stats or nil)
end

function PetData.GetPersonality(inst)
    local data = inst ~= nil and inst.kei_protocol_data or nil
    return PetPersonality.Get(data ~= nil and data.personality or nil)
end

function PetData.Initialize(inst, def)
    inst.kei_protocol_definition = def
    inst.kei_pet_protocol = def.protocol
    inst.kei_protocol_data = {
        kind = "pet",
        protocol = def.protocol,
        display_name = def.display_name,
        implemented = true,
        level = TUNING.KEI_PET_INITIAL_LEVEL or 1,
        friendship = 0,
        personality = PetPersonality.GetDefaultId(),
        base_stats = PetStats.Normalize(nil),
        talents = {},
        affixes = {},
    }
    ApplyName(inst)
end

function PetData.SetCapturedPet(inst, captured)
    captured = captured or {}
    local data = inst.kei_protocol_data or {}
    data.kind = "pet"
    data.protocol = "pet"
    data.display_name = "宠物协议"
    data.implemented = true
    data.pet_prefab = captured.pet_prefab
    data.pet_name = GetPetDisplayName(captured.pet_prefab, captured.pet_name)
    data.pet_id = captured.pet_id or (tostring(inst.GUID) .. "-" .. tostring(math.floor(GetTime() * 1000)))
    data.level = NormalizeLevel(captured.level or data.level)
    data.friendship = math.max(0, tonumber(captured.friendship or data.friendship) or 0)
    data.personality = PetPersonality.NormalizeId(captured.personality or data.personality)
    data.base_stats = PetStats.Normalize(captured.base_stats or data.base_stats)
    data.talents = CopyArray(captured.talents or data.talents)
    data.affixes = CopyArray(captured.affixes or data.affixes)
    inst.kei_protocol_data = data
    ApplyName(inst)
end

function PetData.IsBound(inst)
    return inst ~= nil
        and inst.kei_protocol_data ~= nil
        and inst.kei_protocol_data.kind == "pet"
        and inst.kei_protocol_data.pet_prefab ~= nil
end

function PetData.IsTimerActive(inst, timer_name)
    local timer = inst ~= nil and inst.components.timer or nil
    return timer ~= nil and timer:TimerExists(timer_name)
end

function PetData.IsReady(inst)
    return PetData.IsBound(inst)
        and not PetData.IsTimerActive(inst, PetData.RECALL_TIMER)
        and not PetData.IsTimerActive(inst, PetData.REVIVE_TIMER)
end

local function StartTimer(inst, timer_name, duration)
    local timer = inst ~= nil and inst.components.timer or nil
    if timer == nil then
        return
    end
    if timer:TimerExists(timer_name) then
        timer:StopTimer(timer_name)
    end
    timer:StartTimer(timer_name, duration)
end

function PetData.StartRecallCooldown(inst)
    if not PetData.IsTimerActive(inst, PetData.REVIVE_TIMER) then
        StartTimer(inst, PetData.RECALL_TIMER, TUNING.KEI_PET_RECALL_COOLDOWN or 60)
    end
end

function PetData.StartReviveCooldown(inst)
    local timer = inst ~= nil and inst.components.timer or nil
    if timer ~= nil and timer:TimerExists(PetData.RECALL_TIMER) then
        timer:StopTimer(PetData.RECALL_TIMER)
    end
    StartTimer(inst, PetData.REVIVE_TIMER, TUNING.KEI_PET_REVIVE_COOLDOWN or 480)
end

function PetData.OnSave(inst, data)
    local pet = inst.kei_protocol_data
    if pet == nil then
        return
    end
    data.kei_pet_data = {
        pet_prefab = pet.pet_prefab,
        pet_name = pet.pet_name,
        pet_id = pet.pet_id,
        level = pet.level,
        friendship = pet.friendship,
        personality = pet.personality,
        base_stats = PetStats.Copy(pet.base_stats),
        talents = CopyArray(pet.talents),
        affixes = CopyArray(pet.affixes),
    }
end

function PetData.OnLoad(inst, data)
    if data ~= nil and data.kei_pet_data ~= nil then
        PetData.SetCapturedPet(inst, data.kei_pet_data)
    else
        ApplyName(inst)
    end
end

return PetData
