local CombatProtocols = require("kei/protocols/combat")
local BasicAttributeProtocols = require("kei/protocols/basic_attributes")

local TaskBook = {}

TaskBook.RARITY_ORDER = { white = 1, blue = 2, gold = 3, purple = 4 }
TaskBook.TASK_RARITIES = {
    [1] = { lifetime_days = 3, min_count = 6, max_count = 9, active_limit = 15 },
    [2] = { lifetime_days = 6, min_count = 3, max_count = 6, active_limit = 9 },
    [3] = { lifetime_days = 9, min_count = 1, max_count = 3, active_limit = 4 },
}
TaskBook.TASK_VERSION = 14

-- These prefabs are valid game entities but should never be selected as
-- random task targets.
TaskBook.TASK_TARGET_EXCLUSIONS = {
    crabking_cannontower = true,
}

-- Task targets define presentation and eligibility only. Their exchange loot
-- is captured from the actual server-side lootdropper configuration.
TaskBook.TASK_TARGETS = {
    pigman = {
        name = "猪人",
        rarity = 1,
        bank = "pigman",
        build = "pigman_basic",
        idle_anim = "idle_loop",
    },
    spider = {
        name = "蜘蛛",
        rarity = 1,
        bank = "spider",
        build = "spider",
        idle_anim = "idle",
    },
}

function TaskBook.MakeId(kind, protocol)
    return kind ~= nil and protocol ~= nil and tostring(kind) .. ":" .. tostring(protocol) or nil
end

function TaskBook.ParseId(id)
    if type(id) ~= "string" then
        return nil, nil
    end
    return id:match("^([^:]+):(.+)$")
end

function TaskBook.IsRecordableKind(kind)
    return kind == "combat" or kind == "basic_attribute"
end

local function GetCombatVisual(protocol)
    return CombatProtocols.GetProtocolVisual ~= nil and CombatProtocols.GetProtocolVisual(protocol) or nil
end

function TaskBook.GetRarity(kind, protocol)
    if kind == "combat" then
        local visual = GetCombatVisual(protocol)
        local atlas = visual ~= nil and visual.atlas or nil
        if atlas == "images/inventoryimages/kei_beast_golden_cd_item.xml" then return "gold" end
        if atlas == "images/inventoryimages/kei_beast_purple_cd_item.xml" then return "purple" end
        if atlas == "images/inventoryimages/kei_biome_cd_item.xml" then return "blue" end
    end
    return "white"
end

function TaskBook.GetDefinition(kind, protocol, prefab)
    local def = kind == "combat" and CombatProtocols.COMBAT_PROTOCOLS[protocol]
        or kind == "basic_attribute" and BasicAttributeProtocols.BASIC_ATTRIBUTE_PROTOCOLS[protocol]
    local visual = kind == "combat" and GetCombatVisual(protocol)
        or kind == "basic_attribute" and { atlas = "images/inventoryimages/kei_items.xml", image = "kei_blank_cd" }
        or { atlas = "images/inventoryimages/kei_items.xml", image = "kei_analysis_cd" }

    -- Analysis and life protocols are intentionally excluded from the data
    -- page. Only combat and basic-attribute protocols are recorded here.
    if type(def) ~= "table" then
        def = nil
    end
    if type(visual) ~= "table" then
        visual = { atlas = "images/inventoryimages/kei_items.xml", image = "kei_analysis_cd" }
    end

    if def == nil or not TaskBook.IsRecordableKind(kind) then
        return nil
    end

    local category
    if kind == "basic_attribute" then
        category = "基础属性协议"
    elseif def.category == "biome" then
        category = "战斗协议 · 群系"
    elseif def.category == "beast" then
        local tier = def.tier == "basic" and "初级" or def.tier == "special" and "特殊" or "高级"
        category = "战斗协议 · 巨兽 · " .. tier
    else
        category = "战斗协议"
    end

    local acquisition
    if kind == "basic_attribute" then
        acquisition = "白色战斗协议CD礼盒"
    elseif def.category == "biome" then
        acquisition = "蓝色战斗协议CD礼盒"
    elseif def.tier == "basic" then
        acquisition = "金色战斗协议CD礼盒\n或使用对应材料和 1 个空白 CD 制作"
    else
        acquisition = "紫色战斗协议CD礼盒\n使用数据记录器完成对应巨兽的数据记录"
    end

    local effect = def.description or "暂无能力效果说明。"
    if kind == "basic_attribute" and def.range_min ~= nil and def.range_max ~= nil then
        local suffix = def.is_percent and "%" or ""
        effect = effect .. "\n数值范围：" .. tostring(def.range_min) .. suffix
            .. " 至 " .. tostring(def.range_max) .. suffix
    end

    return {
        id = TaskBook.MakeId(kind, protocol), kind = kind, protocol = protocol,
        prefab = prefab or (def ~= nil and def.prefab) or "kei_analysis_cd",
        name = def ~= nil and def.display_name or protocol or prefab or "unknown",
        rarity = TaskBook.GetRarity(kind, protocol), atlas = visual.atlas, image = visual.image,
        category = category, acquisition = acquisition, effect = effect,
    }
end

function TaskBook.NormalizeProtocolData(data, prefab)
    if type(data) ~= "table" then return nil end
    local kind = data.kind or "analysis"
    local protocol = data.protocol or (kind == "analysis" and (data.source_prefab or data.source or data.prefab or prefab))
    return protocol ~= nil and TaskBook.GetDefinition(kind, protocol, prefab) or nil
end

function TaskBook.EncodeRecords(records)
    local ids = {}
    for id in pairs(records or {}) do table.insert(ids, id) end
    table.sort(ids)
    return table.concat(ids, ",")
end

function TaskBook.DecodeRecords(encoded)
    local records = {}
    if type(encoded) == "string" then
        for id in encoded:gmatch("[^,]+") do records[id] = true end
    end
    return records
end

function TaskBook.GetEntries(inst)
    local records = TaskBook.DecodeRecords(inst ~= nil and inst._kei_taskbook_records ~= nil and inst._kei_taskbook_records:value() or "")
    local implanted = TaskBook.DecodeRecords(inst ~= nil and inst._kei_taskbook_implanted ~= nil and inst._kei_taskbook_implanted:value() or "")
    local entries = {}
    for id in pairs(records) do
        local kind, protocol = TaskBook.ParseId(id)
        if TaskBook.IsRecordableKind(kind) then
            local entry = TaskBook.GetDefinition(kind, protocol)
            if entry ~= nil then
                entry.implanted = implanted[id] == true
                table.insert(entries, entry)
            end
        end
    end
    return entries
end

function TaskBook.GetAllEntries(inst)
    local implanted = TaskBook.DecodeRecords(inst ~= nil and inst._kei_taskbook_implanted ~= nil and inst._kei_taskbook_implanted:value() or "")
    local entries = {}

    local function AddDefinitions(kind, definitions)
        for _, definition in ipairs(definitions or {}) do
            local entry = TaskBook.GetDefinition(kind, definition.protocol)
            if entry ~= nil then
                entry.implanted = implanted[entry.id] == true
                table.insert(entries, entry)
            end
        end
    end

    AddDefinitions("combat", CombatProtocols.COMBAT_PROTOCOL_LIST)
    AddDefinitions("basic_attribute", BasicAttributeProtocols.BASIC_ATTRIBUTE_PROTOCOL_LIST)
    return entries
end

local function IsAtlasTexture(atlas, texture)
    return atlas ~= nil and texture ~= nil and TheSim ~= nil and TheSim:AtlasContains(atlas, texture)
end

-- Original-game icons may live in an inventory or recipe atlas.
function TaskBook.GetPrefabIcon(prefab)
    if type(prefab) ~= "string" then return nil, nil end
    local texture = prefab:gsub("%.tex$", "") .. ".tex"
    local atlas = GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(texture) or nil
    if IsAtlasTexture(atlas, texture) then return atlas, texture end

    local recipe = AllRecipes ~= nil and AllRecipes[prefab] or nil
    if recipe ~= nil and recipe.image ~= nil then
        atlas = recipe.atlas or (GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(recipe.image) or nil)
        if IsAtlasTexture(atlas, recipe.image) then return atlas, recipe.image end
    end

    local prefab_data = Prefabs ~= nil and Prefabs[prefab] or nil
    for _, asset in ipairs(prefab_data ~= nil and prefab_data.assets or {}) do
        if asset.type == "INV_IMAGE" then
            texture = asset.file .. ".tex"
            atlas = GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(texture) or nil
            if IsAtlasTexture(atlas, texture) then return atlas, texture end
        elseif asset.type == "IMAGE" then
            texture = asset.file:match("[^/]+$") or asset.file
        elseif asset.type == "ATLAS" and IsAtlasTexture(asset.file, texture) then
            return asset.file, texture
        end
    end

    -- Most chesspiece_*_sketch prefabs are variants made by sketch.lua. They
    -- inherit sketch's inventory image instead of owning a matching texture.
    if prefab:match("^chesspiece_.+_sketch$") then
        texture = "sketch.tex"
        atlas = GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(texture) or nil
        if IsAtlasTexture(atlas, texture) then return atlas, texture end
    end

    return nil, nil
end

local ScrapbookData = nil

local function GetScrapbookData()
    if ScrapbookData == nil then
        local success, data = pcall(require, "screens/redux/scrapbookdata")
        ScrapbookData = success and data or false
    end
    return ScrapbookData or nil
end

function TaskBook.GetScrapbookPrefabIcon(prefab)
    if type(prefab) ~= "string" then return nil, nil end
    local entry = (GetScrapbookData() or {})[prefab]
    local texture = type(entry) == "table" and entry.tex or prefab:gsub("%.tex$", "") .. ".tex"
    local atlas = GetScrapbookIconAtlas ~= nil and GetScrapbookIconAtlas(texture) or nil
    if atlas ~= nil then return atlas, texture end
    for index = 1, 3 do
        atlas = "images/scrapbook_icons" .. tostring(index) .. ".xml"
        if IsAtlasTexture(atlas, texture) then return atlas, texture end
    end
    return TaskBook.GetPrefabIcon(prefab)
end

-- This is a visual fallback only. Task target discovery remains based on
-- actual loaded entities and never scans the Scrapbook catalogue.
function TaskBook.GetScrapbookVisual(prefab)
    local entry = type(prefab) == "string" and (GetScrapbookData() or {})[prefab] or nil
    if type(entry) ~= "table" or type(entry.bank) ~= "string" or type(entry.build) ~= "string" then
        return nil
    end
    return {
        bank = entry.bank,
        build = entry.build,
        facing = tonumber(entry.facing) or 0,
        anim = type(entry.anim) == "string" and entry.anim or "idle_loop",
    }
end

function TaskBook.GetPrefabName(prefab)
    local name = STRINGS ~= nil and STRINGS.NAMES ~= nil and STRINGS.NAMES[string.upper(prefab or "")]
    return name or prefab or "未知物品"
end

function TaskBook.GetTaskTarget(prefab)
    return TaskBook.TASK_TARGETS[prefab]
end

local RuntimeLootCache = {}
local RuntimeTaskTargets = {}
local RuntimeTargetRarityCache = {}
local AllScrapbookTargetsDiscovered = false
local ExcludedScrapbookTargets = {}
local FoodRewardCache = nil

local function CopyDrops(drops)
    local copy = {}
    for _, drop in ipairs(drops or {}) do
        table.insert(copy, { prefab = drop.prefab, chance = drop.chance, expected = drop.expected })
    end
    return copy
end

local function CopyVisual(visual)
    return type(visual) == "table" and {
        bank = visual.bank,
        build = visual.build,
        facing = visual.facing,
        anim = visual.anim,
    } or nil
end

local function AddExpectedLoot(expected, prefab, amount)
    if type(prefab) == "string" and type(amount) == "number" and amount > 0 then
        expected[prefab] = (expected[prefab] or 0) + amount
    end
end

local function MakeDropsFromExpected(expected)
    local total, drops = 0, {}
    for _, amount in pairs(expected) do total = total + amount end
    if total <= 0 then return drops end
    for prefab, amount in pairs(expected) do
        table.insert(drops, { prefab = prefab, chance = amount / total, expected = amount })
    end
    table.sort(drops, function(a, b) return a.prefab < b.prefab end)
    return drops
end

local function ReadLootdropper(dropper)
    local expected = {}
    if dropper ~= nil then
        for _, item in ipairs(dropper.loot or {}) do AddExpectedLoot(expected, item, 1) end
        local no_chance_loot = 1
        for _, entry in ipairs(dropper.chanceloot or {}) do
            local chance = math.clamp(entry.chance or 0, 0, 1)
            AddExpectedLoot(expected, entry.prefab, chance)
            no_chance_loot = no_chance_loot * (1 - chance)
        end
        local source = LootTables ~= nil and LootTables[dropper.chanceloottable] or nil
        for _, entry in ipairs(type(source) == "table" and source or {}) do
            local chance = math.clamp(entry[2] or 0, 0, 1)
            AddExpectedLoot(expected, entry[1], chance)
            no_chance_loot = no_chance_loot * (1 - chance)
        end
        for _, entry in ipairs(dropper.ifnotchanceloot or {}) do
            AddExpectedLoot(expected, entry.prefab, no_chance_loot)
        end

        local randomloot = dropper.randomloot or {}
        local total_weight = dropper.totalrandomweight or 0
        local rolls = dropper.numrandomloot or 0
        if total_weight > 0 and rolls > 0 then
            local random_chance = math.clamp(dropper.chancerandomloot or 1, 0, 1)
            for _, entry in ipairs(randomloot) do
                AddExpectedLoot(expected, entry.prefab, random_chance * rolls * entry.weight / total_weight)
            end
        end
    end
    return MakeDropsFromExpected(expected)
end

function TaskBook.GetLootdropperLoot(dropper)
    return ReadLootdropper(dropper)
end

local function ReadRuntimeLoot(prefab)
    if RuntimeLootCache[prefab] ~= nil then return CopyDrops(RuntimeLootCache[prefab]) end
    if SpawnPrefab == nil or TheWorld == nil or not TheWorld.ismastersim then return {} end

    -- Creating a temporary instance runs all enabled prefab post-inits, so the
    -- snapshot includes vanilla data and active mods' lootdropper changes.
    local inst = SpawnPrefab(prefab)
    local dropper = inst ~= nil and inst.components ~= nil and inst.components.lootdropper or nil
    local drops = ReadLootdropper(dropper)
    if inst ~= nil and inst:IsValid() then inst:Remove() end
    RuntimeLootCache[prefab] = drops
    return CopyDrops(RuntimeLootCache[prefab])
end

function TaskBook.GetTargetLoot(prefab, snapshot)
    if type(snapshot) == "table" and #snapshot > 0 then return snapshot end
    return ReadRuntimeLoot(prefab)
end

function TaskBook.IsTaskSubmitPrefab(prefab)
    if type(prefab) ~= "string" then return false end
    return prefab:find("blueprint", 1, true) == nil
        and prefab:find("sketch", 1, true) == nil
end

local function HasSubmittableTaskLoot(drops)
    for _, drop in ipairs(drops or {}) do
        if TaskBook.IsTaskSubmitPrefab(drop.prefab) then return true end
    end
    return false
end

function TaskBook.EncodeLoot(drops)
    local encoded = {}
    for _, drop in ipairs(drops or {}) do
        table.insert(encoded, drop.prefab .. ":" .. tostring(drop.chance))
    end
    return table.concat(encoded, ",")
end

function TaskBook.DecodeLoot(encoded)
    local drops = {}
    if type(encoded) == "string" then
        for entry in encoded:gmatch("[^,]+") do
            local prefab, chance = entry:match("^([^:]+):(.+)$")
            chance = tonumber(chance)
            if prefab ~= nil and chance ~= nil and chance > 0 then
                table.insert(drops, { prefab = prefab, chance = chance })
            end
        end
    end
    return drops
end

function TaskBook.RegisterTaskTarget(prefab, rarity, loot, visual)
    rarity = tonumber(rarity)
    if type(prefab) ~= "string" or TaskBook.TASK_RARITIES[rarity] == nil
        or TaskBook.TASK_TARGET_EXCLUSIONS[prefab] then
        return false
    end
    if type(loot) == "table" and #loot > 0 then
        RuntimeLootCache[prefab] = CopyDrops(loot)
    end
    if #TaskBook.GetTargetLoot(prefab) < 1 then return false end
    RuntimeTaskTargets[prefab] = { rarity = rarity, visual = CopyVisual(visual) }
    return true
end

local function GetRuntimeTargetRarity(prefab, fallback_rarity)
    if RuntimeTargetRarityCache[prefab] ~= nil then return RuntimeTargetRarityCache[prefab] end
    local rarity = fallback_rarity
    if SpawnPrefab ~= nil and TheWorld ~= nil and TheWorld.ismastersim then
        local inst = SpawnPrefab(prefab)
        if inst ~= nil then
            if inst:HasTag("epic") then
                rarity = 3
            elseif inst:HasTag("largecreature") then
                rarity = 2
            elseif inst:HasTag("monster") or inst:HasTag("animal") or inst:HasTag("smallcreature") then
                rarity = 1
            end
            if inst:IsValid() then inst:Remove() end
        end
    end
    RuntimeTargetRarityCache[prefab] = rarity
    return rarity
end

local function DiscoverAllScrapbookTargets()
    if AllScrapbookTargetsDiscovered or SpawnPrefab == nil or TheWorld == nil or not TheWorld.ismastersim then return end
    local prefabs = {}
    for key, entry in pairs(GetScrapbookData() or {}) do
        if type(entry) == "table" and (entry.type == "creature" or entry.type == "giant") then
            local prefab = type(entry.prefab) == "string" and entry.prefab or key
            if type(prefab) == "string" then
                prefabs[prefab] = entry.type == "giant" and 3 or 1
            end
        end
    end
    for prefab, fallback_rarity in pairs(prefabs) do
        local loot = TaskBook.GetTargetLoot(prefab)
        if #loot >= 1 then
            TaskBook.RegisterTaskTarget(prefab, GetRuntimeTargetRarity(prefab, fallback_rarity), loot)
        else
            table.insert(ExcludedScrapbookTargets, prefab)
        end
    end
    table.sort(ExcludedScrapbookTargets)
    print("[Tendou-Kei] Task targets excluded because they have no loot: "
        .. (#ExcludedScrapbookTargets > 0 and table.concat(ExcludedScrapbookTargets, ", ") or "none"))
    AllScrapbookTargetsDiscovered = true
end

function TaskBook.GetExcludedTaskTargets()
    local targets = {}
    for _, prefab in ipairs(ExcludedScrapbookTargets) do table.insert(targets, prefab) end
    return targets
end

function TaskBook.GetTaskVisual(prefab, snapshot)
    local visual = snapshot or (RuntimeTaskTargets[prefab] ~= nil and RuntimeTaskTargets[prefab].visual)
    return CopyVisual(visual) or TaskBook.GetScrapbookVisual(prefab)
end

function TaskBook.GetTaskTargets(rarity, excluded_prefabs)
    DiscoverAllScrapbookTargets()
    local targets = {}
    -- Targets are populated from entities that the server actually loads.
    -- Prefab definitions cannot expose tags or animation state without being
    -- instantiated, so this avoids an unsafe scan of every registered Prefab.
    for prefab, target in pairs(RuntimeTaskTargets) do
        if target.rarity == rarity and not TaskBook.TASK_TARGET_EXCLUSIONS[prefab]
            and (excluded_prefabs == nil or not excluded_prefabs[prefab])
            and HasSubmittableTaskLoot(TaskBook.GetTargetLoot(prefab)) then
            table.insert(targets, prefab)
        end
    end
    table.sort(targets)
    return targets
end

local function PickWeighted(drops)
    local roll, sum = math.random(), 0
    for _, drop in ipairs(drops) do
        sum = sum + drop.chance
        if roll <= sum then return drop end
    end
    return drops[#drops]
end

local function SetRewardChances(candidates, shares)
    table.sort(candidates, function(a, b) return a.chance > b.chance end)
    if #candidates == 1 then
        candidates[1].reward_chance = 1
        return candidates
    end

    shares = math.clamp(tonumber(shares) or 1, 1, 3)
    if shares == 2 then
        for _, candidate in ipairs(candidates) do
            candidate.reward_chance = 1 / #candidates
        end
        return candidates
    end

    -- Two candidates keep the former 80% peak. More possible rewards lower
    -- the peak toward 60%. Three-share selection mirrors the full rarity
    -- order, including every non-peak candidate.
    local max_chance = math.max(.6, .8 - .05 * (#candidates - 2))
    local max_index = shares == 3 and #candidates or 1
    local remaining_weight = 0
    for index, candidate in ipairs(candidates) do
        if index ~= max_index then
            local source_index = shares == 3 and #candidates - index + 1 or index
            remaining_weight = remaining_weight + candidates[source_index].chance
        end
    end
    for index, candidate in ipairs(candidates) do
        if index == max_index then
            candidate.reward_chance = max_chance
        elseif remaining_weight > 0 then
            local source_index = shares == 3 and #candidates - index + 1 or index
            candidate.reward_chance = (1 - max_chance) * candidates[source_index].chance / remaining_weight
        else
            candidate.reward_chance = (1 - max_chance) / (#candidates - 1)
        end
    end
    return candidates
end

local function PickReward(candidates, shares)
    SetRewardChances(candidates, shares)
    local roll, sum = math.random(), 0
    for index, candidate in ipairs(candidates) do
        sum = sum + candidate.reward_chance
        if roll <= sum then return candidate end
    end
    return candidates[#candidates]
end

local function GetFoodRewards()
    if FoodRewardCache ~= nil then return FoodRewardCache end
    FoodRewardCache = {}
    local ok, cooking = pcall(require, "cooking")
    local recipes = ok and cooking ~= nil and cooking.recipes ~= nil and cooking.recipes.cookpot or nil
    for _, recipe in pairs(recipes or {}) do
        if type(recipe) == "table" and type(recipe.name) == "string" then
            table.insert(FoodRewardCache, recipe.name)
        end
    end
    table.sort(FoodRewardCache)
    return FoodRewardCache
end

function TaskBook.BuildTaskOffers(task)
    local drops = TaskBook.GetTargetLoot(task ~= nil and task.target_prefab, task ~= nil and task.loot)
    if #drops < 1 then return nil end
    local submit_drops = {}
    for _, drop in ipairs(drops) do
        if TaskBook.IsTaskSubmitPrefab(drop.prefab) then table.insert(submit_drops, drop) end
    end
    if #submit_drops < 1 then return nil end
    if #drops == 1 then
        local foods = GetFoodRewards()
        if #foods < 1 then return nil end
        local submit = submit_drops[1]
        local base_count = math.random(1, 3)
        local offers = {}
        for shares = 1, 3 do
            offers[shares] = {
                shares = shares,
                submit_prefab = submit.prefab,
                submit_count = base_count * shares,
                reward_prefab = foods[math.random(#foods)],
                reward_count = math.random(1, 3),
            }
        end
        return offers
    end
    local submit = PickWeighted(submit_drops)
    local candidates = {}
    for _, drop in ipairs(drops) do
        if drop.prefab ~= submit.prefab then table.insert(candidates, { prefab = drop.prefab, chance = drop.chance }) end
    end
    -- Rarer submitted loot requires fewer items: 50% -> 5, 30% -> 3,
    -- 20% -> 2. One share never asks for more than ten items.
    local base_count = math.max(1, math.min(10, math.floor(submit.chance * 10 + .5)))
    local offers = {}
    for shares = 1, 3 do
        local reward = PickReward(candidates, shares)
        local reward_count = math.random(1, 3)
        if reward.chance < submit.chance then reward_count = math.min(3, reward_count + 1) end
        offers[shares] = {
            shares = shares,
            submit_prefab = submit.prefab,
            submit_count = base_count * shares,
            reward_prefab = reward.prefab,
            reward_count = reward_count,
        }
    end
    return offers
end

function TaskBook.BuildTaskOffer(task, shares)
    shares = math.clamp(tonumber(shares) or 1, 1, 3)
    local offers = task ~= nil and task.offers or nil
    return offers ~= nil and offers[shares] or nil
end

-- This is a client-safe preview of the weights used when the task offer was
-- generated. It intentionally does not disclose the reward already fixed on
-- a multi-drop task; single-drop food rewards remain visible by design.
function TaskBook.GetTaskOfferRewardPreview(task)
    local offer = task ~= nil and task.offer or nil
    local drops = TaskBook.GetTargetLoot(task ~= nil and task.target_prefab, task ~= nil and task.loot)
    if offer == nil or #drops < 1 then return {} end
    if #drops == 1 then
        return {{ prefab = offer.reward_prefab, count = offer.reward_count, is_food = true }}
    end

    local candidates = {}
    for _, drop in ipairs(drops) do
        if drop.prefab ~= offer.submit_prefab then
            table.insert(candidates, { prefab = drop.prefab, chance = drop.chance })
        end
    end
    return SetRewardChances(candidates, offer.shares)
end

function TaskBook.MakeTask(rarity, serial, created_day, excluded_prefabs)
    local rarity_data = TaskBook.TASK_RARITIES[rarity]
    local targets = TaskBook.GetTaskTargets(rarity, excluded_prefabs)
    if rarity_data == nil or #targets == 0 then return nil end
    local prefab = targets[math.random(#targets)]
    local task = {
        id = prefab .. "_" .. tostring(serial),
        target_prefab = prefab,
        loot = TaskBook.GetTargetLoot(prefab),
        rarity = rarity,
        created_day = created_day,
        expires_day = created_day + rarity_data.lifetime_days,
        completed = false,
        visual = TaskBook.GetTaskVisual(prefab),
    }
    task.offers = TaskBook.BuildTaskOffers(task)
    if task.offers == nil then return nil end
    task.offer = task.offers[1]
    return task
end

function TaskBook.EncodeVisual(visual)
    if type(visual) ~= "table" or type(visual.bank) ~= "number" or type(visual.build) ~= "string"
        or type(visual.facing) ~= "number" or type(visual.anim) ~= "string" then
        return "-"
    end
    return table.concat({ visual.bank, visual.build, visual.facing, visual.anim }, ":")
end

function TaskBook.DecodeVisual(encoded)
    if type(encoded) ~= "string" then return nil end
    local bank, build, facing, anim = encoded:match("^([%-]?%d+):([^:]+):([%-]?%d+):([^:]+)$")
    bank, facing = tonumber(bank), tonumber(facing)
    return bank ~= nil and build ~= nil and facing ~= nil and anim ~= nil and {
        bank = bank, build = build, facing = facing, anim = anim,
    } or nil
end

function TaskBook.EncodeOffers(offers)
    local encoded = {}
    for shares = 1, 3 do
        local offer = offers ~= nil and offers[shares] or nil
        if offer ~= nil then
            table.insert(encoded, table.concat({
                offer.shares, offer.submit_prefab, offer.submit_count,
                offer.reward_prefab, offer.reward_count,
            }, ":"))
        end
    end
    return #encoded > 0 and table.concat(encoded, ",") or "-"
end

function TaskBook.DecodeOffers(encoded)
    local offers = {}
    if type(encoded) == "string" then
        for entry in encoded:gmatch("[^,]+") do
            local shares, submit_prefab, submit_count, reward_prefab, reward_count = entry:match("^(%d+):([^:]+):(%d+):([^:]+):(%d+)$")
            shares, submit_count, reward_count = tonumber(shares), tonumber(submit_count), tonumber(reward_count)
            if shares ~= nil and shares >= 1 and shares <= 3 and submit_count ~= nil and reward_count ~= nil then
                offers[shares] = {
                    shares = shares, submit_prefab = submit_prefab, submit_count = submit_count,
                    reward_prefab = reward_prefab, reward_count = reward_count,
                }
            end
        end
    end
    return offers
end

function TaskBook.EncodeTasks(tasks)
    local encoded = {}
    for _, task in ipairs(tasks or {}) do
        table.insert(encoded, table.concat({
            task.id, task.target_prefab, task.rarity, task.created_day,
            task.expires_day, task.completed and 1 or 0,
            task.offer ~= nil and task.offer.shares or 0,
            task.offer ~= nil and task.offer.submit_prefab or "-",
            task.offer ~= nil and task.offer.submit_count or 0,
            task.offer ~= nil and task.offer.reward_prefab or "-",
            task.offer ~= nil and task.offer.reward_count or 0,
            TaskBook.EncodeLoot(task.loot),
            TaskBook.EncodeOffers(task.offers),
            TaskBook.EncodeVisual(task.visual),
        }, "|"))
    end
    return table.concat(encoded, ";")
end

function TaskBook.DecodeTasks(encoded)
    local tasks = {}
    if type(encoded) ~= "string" then return tasks end
    for record in encoded:gmatch("[^;]+") do
        local values = {}
        for value in record:gmatch("[^|]+") do table.insert(values, value) end
        local rarity, created_day, expires_day = tonumber(values[3]), tonumber(values[4]), tonumber(values[5])
        if #values == 14 and rarity ~= nil and created_day ~= nil and expires_day ~= nil
        then
            local shares, submit_count, reward_count = tonumber(values[7]), tonumber(values[9]), tonumber(values[11])
            local offers = TaskBook.DecodeOffers(values[13])
            table.insert(tasks, {
                id = values[1], target_prefab = values[2], rarity = rarity,
                created_day = created_day, expires_day = expires_day,
                completed = values[6] == "1",
                offer = shares ~= nil and offers[shares] or nil,
                offers = offers,
                loot = TaskBook.DecodeLoot(values[12]),
                visual = TaskBook.DecodeVisual(values[14]),
            })
        elseif #values == 13 and rarity ~= nil and created_day ~= nil and expires_day ~= nil
        then
            local shares = tonumber(values[7])
            local offers = TaskBook.DecodeOffers(values[13])
            table.insert(tasks, {
                id = values[1], target_prefab = values[2], rarity = rarity,
                created_day = created_day, expires_day = expires_day,
                completed = values[6] == "1",
                offer = shares ~= nil and offers[shares] or nil,
                offers = offers,
                loot = TaskBook.DecodeLoot(values[12]),
            })
        elseif #values == 12 and rarity ~= nil and created_day ~= nil and expires_day ~= nil
        then
            local shares, submit_count, reward_count = tonumber(values[7]), tonumber(values[9]), tonumber(values[11])
            table.insert(tasks, {
                id = values[1], target_prefab = values[2], rarity = rarity,
                created_day = created_day, expires_day = expires_day,
                completed = values[6] == "1",
                offer = shares ~= nil and shares > 0 and {
                    shares = shares, submit_prefab = values[8], submit_count = submit_count,
                    reward_prefab = values[10], reward_count = reward_count,
                } or nil,
                loot = TaskBook.DecodeLoot(values[12]),
            })
        elseif #values == 11 then
            table.insert(tasks, {
                id = values[1], target_prefab = values[2], rarity = tonumber(values[3]) or 1,
                created_day = tonumber(values[4]) or 0, expires_day = tonumber(values[5]) or 0,
                completed = values[6] == "1",
                offer = tonumber(values[7]) ~= nil and tonumber(values[7]) > 0 and {
                    shares = tonumber(values[7]), submit_prefab = values[8], submit_count = tonumber(values[9]),
                    reward_prefab = values[10], reward_count = tonumber(values[11]),
                } or nil,
            })
        elseif #values == 10 then
            -- Legacy net values are retained as target-only tasks until the
            -- server reload performs the version-3 migration.
            table.insert(tasks, {
                id = values[1], target_prefab = values[2], rarity = tonumber(values[3]) or 1,
                created_day = tonumber(values[8]) or 0, expires_day = tonumber(values[9]) or 0,
                completed = values[10] == "1",
            })
        end
    end
    return tasks
end

function TaskBook.GetTasks(inst)
    local value = inst ~= nil and inst._kei_taskbook_tasks ~= nil and inst._kei_taskbook_tasks:value() or ""
    return TaskBook.DecodeTasks(value)
end

return TaskBook
