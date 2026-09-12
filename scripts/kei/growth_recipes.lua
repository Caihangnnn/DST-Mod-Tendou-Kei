-- Growth recipes consume experience and perform their operation directly.

local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")
local MiniAlice = require("kei/mini_alice")
local RotorSurveySkills = require("kei/drone/skills")
local RotorUpgrades = require("kei/drone/upgrades")
local AnalysisArmorUpgrade = require("kei/analysis_armor_upgrade")
local CombatProtocolDefs = require("kei/protocols/combat")

local KEI_EXPERIENCE_INGREDIENT = "kei_experience"
CHARACTER_INGREDIENT.KEI_EXPERIENCE = KEI_EXPERIENCE_INGREDIENT

-- Keep experience separate from built-in character resources such as sanity.
-- This module is loaded through require(), whose environment does not expose
-- the modmain-only GLOBAL alias. Wrap the existing global function directly.
local old_is_character_ingredient = IsCharacterIngredient
if old_is_character_ingredient ~= nil then
    local is_character_ingredient = function(ingredienttype)
        if ingredienttype == KEI_EXPERIENCE_INGREDIENT then
            return true
        end
        return old_is_character_ingredient(ingredienttype)
    end
    IsCharacterIngredient = is_character_ingredient
end

STRINGS.NAMES[string.upper(KEI_EXPERIENCE_INGREDIENT)] = "经验"

local GrowthRecipes = {
    SLOT_UNLOCK_RECIPE = "kei_protocol_slot_unlock",
    DEEP_IMPLANT_RECIPE = "kei_deep_implant",
    POTENTIAL_RECIPE = "kei_potential_activation",
    MINI_ALICE_PAGE_RECIPE = "kei_mini_alice_page_unlock",
    ANALYSIS_ARMOR_UPGRADE_RECIPE = AnalysisArmorUpgrade.RECIPE,
    PROTOCOL_CD_RECYCLE_RECIPE = "kei_protocol_cd_recycle",
    ROTOR_SKILL_EXPERIENCE_COST = 1000,
    ROTOR_UPGRADE_EXPERIENCE_COST = 1000,
}

function GrowthRecipes.IsExperienceIngredient(ingredient)
    return ingredient ~= nil
        and (ingredient.type == KEI_EXPERIENCE_INGREDIENT
            or ingredient.kei_growth_recipe ~= nil
            or ingredient.kei_experience_cost ~= nil
            or ingredient.kei_experience_cost_fn ~= nil)
end

function GrowthRecipes.HasExperienceIngredient(inst)
    return inst ~= nil and inst:HasTag("kei")
end

local function GetUnlockedSlots(builder)
    return ProtocolSlotUnlocks.GetUnlockedSlots(builder)
end

function GrowthRecipes.GetExperienceCost(recname, experience, builder)
    builder = builder or (experience ~= nil and experience.inst or nil)
    local cost_per_slot = TUNING.KEI_EXPERIENCE_COST_PER_SLOT or 1000
    local slot_count

    if RotorSurveySkills.IsSkillRecipe(recname) then
        return TUNING.KEI_ROTOR_SKILL_EXPERIENCE_COST
            or GrowthRecipes.ROTOR_SKILL_EXPERIENCE_COST,
            false
    elseif RotorUpgrades.IsUpgradeRecipe(recname) then
        local upgrade = RotorUpgrades.GetUpgradeForRecipe(recname)
        return RotorUpgrades.GetExperienceCost(upgrade)
            or TUNING.KEI_ROTOR_UPGRADE_EXPERIENCE_COST
            or GrowthRecipes.ROTOR_UPGRADE_EXPERIENCE_COST,
            false
    elseif AnalysisArmorUpgrade.IsRecipe(recname) then
        return AnalysisArmorUpgrade.GetExperienceCost(builder), false
    elseif recname == GrowthRecipes.SLOT_UNLOCK_RECIPE then
        slot_count = GetUnlockedSlots(builder)
    elseif recname == GrowthRecipes.DEEP_IMPLANT_RECIPE
        or recname == GrowthRecipes.POTENTIAL_RECIPE
    then
        slot_count = ProtocolSlotUnlocks.GetMaxSlots()
    elseif recname == GrowthRecipes.MINI_ALICE_PAGE_RECIPE then
        -- Kei starts with one Alice page. Each purchase unlocks the next
        -- page, so the first costs 1000 and each following page costs one
        -- additional 1000 experience.
        return MiniAlice.GetUnlockedPages(builder)
            * (TUNING.KEI_EXPERIENCE_COST_PER_SLOT or 1000), false
    else
        return 0, true
    end

    return math.max(0, slot_count * cost_per_slot), true
end

function GrowthRecipes.GetExperienceIngredientAmount(ingredient, builder)
    if not GrowthRecipes.IsExperienceIngredient(ingredient) then
        return 0
    end

    if ingredient.kei_experience_cost_fn ~= nil then
        return math.max(
            0,
            tonumber(ingredient.kei_experience_cost_fn(ingredient, builder)) or 0
        )
    end

    if ingredient.kei_experience_cost ~= nil then
        return math.max(0, tonumber(ingredient.kei_experience_cost) or 0)
    end

    return GrowthRecipes.GetExperienceCost(
        ingredient.kei_growth_recipe,
        builder ~= nil and builder.components ~= nil and builder.components.kei_experience or nil,
        builder
    )
end

function GrowthRecipes.ConsumeExperienceIngredients(builder, recipe)
    if builder == nil or builder.freebuildmode then
        return 0
    end

    local experience = builder.components ~= nil and builder.components.kei_experience or nil
    if experience == nil then
        return 0
    end

    if type(recipe) == "string" then
        recipe = GetValidRecipe(recipe)
    end
    if recipe == nil or recipe.character_ingredients == nil then
        return 0
    end

    local amount = 0
    for _, ingredient in ipairs(recipe.character_ingredients) do
        if GrowthRecipes.IsExperienceIngredient(ingredient) then
            amount = amount + GrowthRecipes.GetExperienceIngredientAmount(ingredient, builder)
        end
    end

    if amount <= 0 or experience.current < amount then
        return 0
    end

    experience:DoDelta(-amount)
    return amount
end

function GrowthRecipes.HasEnoughExperienceAmount(builder, amount)
    amount = math.max(0, tonumber(amount) or 0)
    return builder ~= nil
        and builder:HasTag("kei")
        and amount > 0
        and GrowthRecipes.GetExperienceCurrent(builder) >= amount
end

function GrowthRecipes.HasEnoughExperienceIngredient(builder, ingredient)
    local amount = GrowthRecipes.GetExperienceIngredientAmount(ingredient, builder)
    -- A zero-cost experience ingredient is used by the CD recycle recipe.
    -- Treat it as satisfied for ingredient validation without changing the
    -- meaning of HasEnoughExperienceAmount(0) for other callers.
    if amount <= 0 then
        return builder ~= nil and builder:HasTag("kei")
    end
    return GrowthRecipes.HasEnoughExperienceAmount(builder, amount)
end

function GrowthRecipes.GetExperienceCurrent(builder)
    if builder == nil then
        return 0
    end

    local experience = builder.components ~= nil and builder.components.kei_experience or nil
    if experience ~= nil then
        return experience.current or 0
    end

    return builder._kei_experience_current ~= nil
        and builder._kei_experience_current:value()
        or 0
end

function GrowthRecipes.HasEnoughExperience(builder, recname)
    if builder == nil or not builder:HasTag("kei") then
        return false
    end

    local amount = GrowthRecipes.GetExperienceCost(
        recname,
        builder.components ~= nil and builder.components.kei_experience or nil,
        builder
    )
    return amount > 0 and GrowthRecipes.GetExperienceCurrent(builder) >= amount
end

local function ConsumeConfiguredExperience(inst, recname)
    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience == nil then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    local amount, requires_full = GrowthRecipes.GetExperienceCost(recname, experience, inst)
    if requires_full and not experience:IsFull() then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    if amount <= 0 or experience.current < amount then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    experience:DoDelta(-amount)
    return true
end

local function IsKeiBuilder(builder)
    return builder ~= nil and builder:HasTag("kei")
end

function GrowthRecipes.CanBuildSlotUnlock(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end
    if GetUnlockedSlots(builder) >= ProtocolSlotUnlocks.GetMaxSlots() then
        return false, "KEI_PROTOCOL_SLOTS_FULL"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, GrowthRecipes.SLOT_UNLOCK_RECIPE) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function GrowthRecipes.CanBuildRotorSkill(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end

    local recname = type(recipe) == "string"
        and recipe
        or recipe ~= nil and recipe.name
        or nil
    local skill = RotorSurveySkills.GetSkillForRecipe(recname)
    if skill == nil then
        return false, "KEI_ROTOR_SKILL_INVALID"
    end
    local skill_level = RotorSurveySkills.GetSkillLevel(builder, skill)
    local max_level = skill == "collect" and 2 or 1
    if skill_level >= max_level then
        return false, "KEI_ROTOR_SKILL_ALREADY_UNLOCKED"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, recname) then
        return false, "KEI_EXPERIENCE_NOT_ENOUGH"
    end
    return true
end

function GrowthRecipes.CanBuildRotorUpgrade(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end

    local recname = type(recipe) == "string"
        and recipe
        or recipe ~= nil and recipe.name
        or nil
    local upgrade = RotorUpgrades.GetUpgradeForRecipe(recname)
    if upgrade == nil then
        return false, "KEI_ROTOR_UPGRADE_INVALID"
    end
    if RotorUpgrades.GetLevel(builder, upgrade) >= RotorUpgrades.GetMaxLevel(upgrade) then
        return false, "KEI_ROTOR_UPGRADE_MAX"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, recname) then
        return false, "KEI_EXPERIENCE_NOT_ENOUGH"
    end
    return true
end

function GrowthRecipes.CanBuildAnalysisArmorUpgrade(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end

    -- The protocol slot component exists only on the server. The crafting
    -- screen runs this callback on the client too, so use the replicated
    -- upgrade level rather than treating a missing server component as maxed.
    if AnalysisArmorUpgrade.GetLevel(builder) >= AnalysisArmorUpgrade.MAX_LEVEL then
        return false, "KEI_ANALYSIS_ARMOR_UPGRADE_MAX"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, AnalysisArmorUpgrade.RECIPE) then
        return false, "KEI_EXPERIENCE_NOT_ENOUGH"
    end
    return true
end

function GrowthRecipes.GetRotorUpgradeRecipeCount(recipe, builder)
    if not IsKeiBuilder(builder) then
        return 0
    end

    local recname = type(recipe) == "string"
        and recipe
        or recipe ~= nil and recipe.name
        or nil
    local upgrade = RotorUpgrades.GetUpgradeForRecipe(recname)
    if upgrade == nil then
        return 0
    end

    -- This callback is the recipe's remaining lifetime count. Each build
    -- raises the upgrade by exactly one level, so return the remaining levels
    -- instead of a boolean availability flag.
    return math.max(
        0,
        RotorUpgrades.GetMaxLevel(upgrade) - RotorUpgrades.GetLevel(builder, upgrade)
    )
end

function GrowthRecipes.GetRotorSkillRecipeCount(recipe, builder)
    if not IsKeiBuilder(builder) then
        return 0
    end

    local recname = type(recipe) == "string"
        and recipe
        or recipe ~= nil and recipe.name
        or nil
    local skill = RotorSurveySkills.GetSkillForRecipe(recname)
    if skill == nil then
        return 0
    end
    local max_level = skill == "collect" and 2 or 1
    return math.max(0, max_level - RotorSurveySkills.GetSkillLevel(builder, skill))
end

function GrowthRecipes.GetAnalysisArmorUpgradeRecipeCount(recipe, builder)
    if not IsKeiBuilder(builder) then
        return 0
    end
    return math.max(
        0,
        AnalysisArmorUpgrade.MAX_LEVEL - AnalysisArmorUpgrade.GetLevel(builder)
    )
end

function GrowthRecipes.CanBuildDeepImplant(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end
    if GetUnlockedSlots(builder) < ProtocolSlotUnlocks.GetMaxSlots() then
        return false, "KEI_PROTOCOL_SLOTS_NOT_FULL"
    end
    local slots = builder.components ~= nil and builder.components.kei_protocolslots or nil
    if slots ~= nil then
        local can_implant, reason = slots:CanDeepImplantFirst()
        if not can_implant then
            return false, reason
        end
    end
    if not GrowthRecipes.HasEnoughExperience(builder, GrowthRecipes.DEEP_IMPLANT_RECIPE) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function GrowthRecipes.CanBuildPotential(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end
    if GetUnlockedSlots(builder) < ProtocolSlotUnlocks.GetMaxSlots() then
        return false, "KEI_PROTOCOL_SLOTS_NOT_FULL"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, GrowthRecipes.POTENTIAL_RECIPE) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function GrowthRecipes.CanBuildMiniAlicePage(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end

    if MiniAlice.GetUnlockedPages(builder) >= MiniAlice.GetMaxPages() then
        return false, "KEI_MINI_ALICE_PAGES_FULL"
    end
    if not GrowthRecipes.HasEnoughExperience(builder, GrowthRecipes.MINI_ALICE_PAGE_RECIPE) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function GrowthRecipes.GetMiniAlicePageRecipeCount(recipe, builder)
    if not IsKeiBuilder(builder) then
        return 0
    end

    return math.max(
        0,
        MiniAlice.GetMaxPages() - MiniAlice.GetUnlockedPages(builder)
    )
end

-- 协议槽中的 CD 不能通过普通配方材料系统表达，因此回收配方使用
-- canbuild + DoBuild 直接读取第一格协议槽。客户端通过 prefab 映射补齐
-- 服务端才会写入的 kei_protocol_data，以便配方按钮能够正确显示。
local function GetBuilderEntity(builder)
    return builder ~= nil and builder.inst or builder
end

local function GetFirstProtocolSlotItem(builder)
    local owner = GetBuilderEntity(builder)
    local inventory = owner ~= nil and owner.components ~= nil and owner.components.inventory or nil
    if inventory == nil then
        inventory = owner ~= nil and owner.replica ~= nil and owner.replica.inventory or nil
    end
    if inventory == nil or inventory.GetItemInSlot == nil then
        return nil, nil, nil
    end

    local protocol_container = inventory:GetItemInSlot(1)
    if protocol_container == nil or not protocol_container:HasTag("kei_protocol_slot") then
        return nil, nil, nil
    end

    local container = protocol_container.components ~= nil and protocol_container.components.container or nil
    if container == nil and protocol_container.replica ~= nil then
        container = protocol_container.replica.container
    end
    if container == nil or container.GetItemInSlot == nil then
        return nil, nil, nil
    end

    local item = container:GetItemInSlot(1)
    if item == nil or not item:HasTag("kei_protocol_cd") then
        return nil, nil, nil
    end

    local data = item.kei_protocol_data
    if type(data) == "table" then
        return item, data, container
    end

    -- Arbitrary Lua fields are not replicated to clients. Combat CD prefabs
    -- are stable, so recover the same category/tier from the shared registry.
    if item:HasTag("kei_basic_attribute_protocol") then
        return item, { kind = "basic_attribute" }, container
    end
    if item:HasTag("kei_combat_protocol") then
        local protocol = item.kei_combat_protocol
            or CombatProtocolDefs.COMBAT_PROTOCOL_PREFABS[item.prefab]
        local def = protocol ~= nil and CombatProtocolDefs.COMBAT_PROTOCOLS[protocol] or nil
        if def ~= nil then
            return item, {
                kind = "combat",
                protocol = def.protocol,
                category = def.category,
                tier = def.tier,
            }, container
        end
    end

    return nil, nil, nil
end

local function GetProtocolCDRecycleReward(data)
    if data == nil then
        return 0
    end
    if data.kind == "basic_attribute" then
        return 50
    end
    if data.kind ~= "combat" then
        return 0
    end
    if data.category == "biome" then
        return 100
    end
    if data.category == "beast" then
        return data.tier == "basic" and 250 or 500
    end
    return 0
end

function GrowthRecipes.GetProtocolCDRecycleReward(builder)
    local _, data = GetFirstProtocolSlotItem(builder)
    return GetProtocolCDRecycleReward(data)
end

function GrowthRecipes.CanBuildProtocolCDRecycle(recipe, builder)
    if not IsKeiBuilder(builder) then
        return false
    end
    if GrowthRecipes.GetProtocolCDRecycleReward(builder) <= 0 then
        return false, "KEI_PROTOCOL_CD_RECYCLE_NO_CD"
    end
    return true
end

function GrowthRecipes.IsGrowthRecipe(recname)
    return recname == GrowthRecipes.SLOT_UNLOCK_RECIPE
        or recname == GrowthRecipes.DEEP_IMPLANT_RECIPE
        or recname == GrowthRecipes.POTENTIAL_RECIPE
        or recname == GrowthRecipes.MINI_ALICE_PAGE_RECIPE
        or recname == GrowthRecipes.PROTOCOL_CD_RECYCLE_RECIPE
        or AnalysisArmorUpgrade.IsRecipe(recname)
        or RotorSurveySkills.IsSkillRecipe(recname)
        or RotorUpgrades.IsUpgradeRecipe(recname)
end

local function PrepareDirectBuild(builder, recname, pt, rotation, skin)
    local inst = builder ~= nil and builder.inst or nil
    local recipe = GetValidRecipe(recname)
    if inst == nil
        or recipe == nil
        or not IsKeiBuilder(inst)
        or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
    then
        return nil, nil, "INVALID"
    end

    local is_rotor_recipe = RotorSurveySkills.IsSkillRecipe(recname)
        or RotorUpgrades.IsUpgradeRecipe(recname)
    if is_rotor_recipe and recipe.canbuild ~= nil then
        local canbuild, canbuild_reason = recipe.canbuild(
            recipe,
            inst,
            pt,
            rotation,
            builder.current_prototyper,
            skin
        )
        if not canbuild then
            return nil, nil, canbuild_reason
        end
    end

    if not (builder:IsBuildBuffered(recname) or builder:HasIngredients(recipe)) then
        return nil, nil, "INGREDIENTS"
    end

    if recipe.canbuild ~= nil then
        local canbuild, reason = recipe.canbuild(recipe, inst, pt, rotation, builder.current_prototyper, skin)
        if not canbuild then
            return nil, nil, reason
        end
    end

    if builder.buffered_builds[recname] ~= nil then
        builder.buffered_builds[recname] = nil
        inst.replica.builder:SetIsBuildBuffered(recname, false)
    end

    inst:PushEvent("refreshcrafting")
    return inst, recipe
end

function GrowthRecipes.DoBuild(builder, recname, pt, rotation, skin)
    local inst, recipe, reason = PrepareDirectBuild(builder, recname, pt, rotation, skin)
    if inst == nil then
        return false, reason
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    local slots = inst.components ~= nil and inst.components.kei_protocolslots or nil
    local skill = RotorSurveySkills.GetSkillForRecipe(recname)
    if skill ~= nil then
        local skills = inst.components ~= nil and inst.components["drone/skills"] or nil
        if skills == nil then
            return false, "KEI_ROTOR_SKILL_INVALID"
        end
        local skill_to_unlock = skill
        if skill == "collect" and skills:HasSkill("collect") then
            skill_to_unlock = "collect_harvest"
        end
        if skills:HasSkill(skill_to_unlock) then
            return false, "KEI_ROTOR_SKILL_ALREADY_UNLOCKED"
        end

        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end

        local unlocked, unlock_reason = skills:UnlockSkill(skill_to_unlock)
        if not unlocked then
            return false, unlock_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_ROTOR_SKILL_UNLOCKED)
        end
        return true
    end
    local upgrade = RotorUpgrades.GetUpgradeForRecipe(recname)
    if upgrade ~= nil then
        local upgrades = inst.components ~= nil and inst.components["drone/upgrades"] or nil
        if upgrades == nil then
            return false, "KEI_ROTOR_UPGRADE_INVALID"
        end
        if not upgrades:CanUpgrade(upgrade) then
            return false, "KEI_ROTOR_UPGRADE_MAX"
        end

        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end

        local upgraded, upgrade_reason = upgrades:Upgrade(upgrade)
        if not upgraded then
            return false, upgrade_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_ROTOR_UPGRADE)
        end
        return true
    end
    if AnalysisArmorUpgrade.IsRecipe(recname) then
        if slots == nil then
            return false, "KEI_ANALYSIS_ARMOR_UPGRADE_MAX"
        end
        local can_upgrade, upgrade_reason = slots:CanUpgradeAnalysisArmor()
        if not can_upgrade then
            return false, upgrade_reason
        end

        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end

        local upgraded, actual_reason = slots:UpgradeAnalysisArmor()
        if not upgraded then
            return false, actual_reason or upgrade_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_ANALYSIS_ARMOR_UPGRADE)
        end
        return true
    end
    if slots == nil then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    if recname == GrowthRecipes.PROTOCOL_CD_RECYCLE_RECIPE then
        local item, data, container = GetFirstProtocolSlotItem(inst)
        local reward = GetProtocolCDRecycleReward(data)
        if item == nil or container == nil or reward <= 0 then
            return false, "KEI_PROTOCOL_CD_RECYCLE_NO_CD"
        end
        if experience == nil then
            return false, "KEI_EXPERIENCE_NOT_ENOUGH"
        end

        local removed = container:RemoveItemBySlot(1, true)
        if removed == nil then
            return false, "KEI_PROTOCOL_CD_RECYCLE_NO_CD"
        end
        if removed:IsValid() then
            removed:Remove()
        end

        experience:DoDelta(reward)
        slots._protocol_state_dirty = true
        slots:Refresh()
        return true
    end

    if recname == GrowthRecipes.SLOT_UNLOCK_RECIPE then
        if slots.unlocked_slots >= ProtocolSlotUnlocks.GetMaxSlots() then
            return false, "KEI_PROTOCOL_SLOTS_FULL"
        end
        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end
        local unlocked, unlock_reason = slots:UnlockNextSlot()
        if not unlocked then
            return false, unlock_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_PROTOCOL_UNLOCK)
        end
        return true
    elseif recname == GrowthRecipes.DEEP_IMPLANT_RECIPE then
        if GetUnlockedSlots(inst) < ProtocolSlotUnlocks.GetMaxSlots() then
            return false, "KEI_PROTOCOL_SLOTS_NOT_FULL"
        end
        local can_implant, implant_reason = slots:CanDeepImplantFirst()
        if not can_implant then
            return false, implant_reason
        end
        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end
        local implanted, actual_reason = slots:DeepImplantFirst()
        if not implanted then
            return false, actual_reason or implant_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_DEEP_IMPLANT)
        end
        return true
    elseif recname == GrowthRecipes.POTENTIAL_RECIPE then
        if slots.unlocked_slots < ProtocolSlotUnlocks.GetMaxSlots() then
            return false, "KEI_PROTOCOL_SLOTS_NOT_FULL"
        end
        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end
        experience:StartPotential(TUNING.KEI_POTENTIAL_DURATION or 240)
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_POTENTIAL)
        end
        return true
    elseif recname == GrowthRecipes.MINI_ALICE_PAGE_RECIPE then
        local can_unlock, unlock_reason = slots:CanUnlockMiniAlicePage()
        if not can_unlock then
            return false, unlock_reason
        end

        local spent, spend_reason = ConsumeConfiguredExperience(inst, recname)
        if not spent then
            return false, spend_reason
        end

        local unlocked, actual_reason = slots:UnlockMiniAlicePage()
        if not unlocked then
            return false, actual_reason or unlock_reason
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_MINI_ALICE_PAGE_UNLOCK)
        end
        return true
    end

    return false
end

-- Future item synthesis recipes can use this shared experience spender.
function GrowthRecipes.TrySpendExperience(builder, amount)
    local experience = builder ~= nil
        and builder.components ~= nil
        and builder.components.kei_experience
        or nil
    amount = tonumber(amount) or 0
    if experience == nil or amount <= 0 or experience.current < amount then
        return false
    end
    experience:DoDelta(-amount)
    return true
end

return GrowthRecipes
