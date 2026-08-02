-- Growth recipes consume experience and perform their operation directly.

local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")
local MiniAlice = require("kei/mini_alice")

local GrowthRecipes = {
    SLOT_UNLOCK_RECIPE = "kei_protocol_slot_unlock",
    DEEP_IMPLANT_RECIPE = "kei_deep_implant",
    POTENTIAL_RECIPE = "kei_potential_activation",
    MINI_ALICE_PAGE_RECIPE = "kei_mini_alice_page_unlock",
}

function GrowthRecipes.IsExperienceIngredient(ingredient)
    return ingredient ~= nil
        and (ingredient.kei_growth_recipe ~= nil
            or ingredient.kei_experience_cost ~= nil)
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

    if recname == GrowthRecipes.SLOT_UNLOCK_RECIPE then
        slot_count = GetUnlockedSlots(builder)
    elseif recname == GrowthRecipes.DEEP_IMPLANT_RECIPE
        or recname == GrowthRecipes.POTENTIAL_RECIPE
    then
        slot_count = ProtocolSlotUnlocks.GetMaxSlots()
    elseif recname == GrowthRecipes.MINI_ALICE_PAGE_RECIPE then
        return TUNING.KEI_EXPERIENCE_COST_PER_SLOT or 1000, false
    else
        return 0, true
    end

    return math.max(0, slot_count * cost_per_slot), true
end

function GrowthRecipes.GetExperienceIngredientAmount(ingredient, builder)
    if not GrowthRecipes.IsExperienceIngredient(ingredient) then
        return 0
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

function GrowthRecipes.HasEnoughExperienceAmount(builder, amount)
    amount = math.max(0, tonumber(amount) or 0)
    return builder ~= nil
        and builder:HasTag("kei")
        and amount > 0
        and GrowthRecipes.GetExperienceCurrent(builder) >= amount
end

function GrowthRecipes.HasEnoughExperienceIngredient(builder, ingredient)
    return GrowthRecipes.HasEnoughExperienceAmount(
        builder,
        GrowthRecipes.GetExperienceIngredientAmount(ingredient, builder)
    )
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

function GrowthRecipes.IsGrowthRecipe(recname)
    return recname == GrowthRecipes.SLOT_UNLOCK_RECIPE
        or recname == GrowthRecipes.DEEP_IMPLANT_RECIPE
        or recname == GrowthRecipes.POTENTIAL_RECIPE
        or recname == GrowthRecipes.MINI_ALICE_PAGE_RECIPE
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
    if slots == nil then
        return false, "KEI_EXPERIENCE_NOT_FULL"
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
