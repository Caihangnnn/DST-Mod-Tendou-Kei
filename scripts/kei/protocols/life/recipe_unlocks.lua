-- Life protocol recipe unlocks: temporary access becomes permanent after a successful cast.
local LifeRecipeUnlocks = {}

local function GetProtocolSlots(inst)
    return inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_protocolslots
        or nil
end

local function GetPermanentRecipes(inst)
    local slots = GetProtocolSlots(inst)
    if slots == nil then
        return nil
    end

    slots.permanent_life_recipes = slots.permanent_life_recipes or {}
    return slots.permanent_life_recipes
end

function LifeRecipeUnlocks.IsUnlocked(inst, recipe)
    local recipes = GetPermanentRecipes(inst)
    return recipes ~= nil and recipes[recipe] == true
end

function LifeRecipeUnlocks.CanUse(inst, protocol, recipe)
    local slots = GetProtocolSlots(inst)
    return slots ~= nil
        and (LifeRecipeUnlocks.IsUnlocked(inst, recipe) or slots:HasLifeProtocol(protocol))
end

function LifeRecipeUnlocks.Enable(inst, protocol, recipe)
    if inst == nil or inst.components == nil or inst.components.builder == nil then
        return
    end

    if LifeRecipeUnlocks.CanUse(inst, protocol, recipe) then
        inst.components.builder:AddRecipe(recipe)
    end
end

function LifeRecipeUnlocks.Disable(inst, recipe)
    if inst == nil or inst.components == nil or inst.components.builder == nil then
        return
    end

    if not LifeRecipeUnlocks.IsUnlocked(inst, recipe) then
        inst.components.builder:RemoveRecipe(recipe)
    end
end

function LifeRecipeUnlocks.MarkUnlocked(inst, recipe)
    local recipes = GetPermanentRecipes(inst)
    if recipes == nil or recipe == nil then
        return false
    end

    recipes[recipe] = true
    if inst.components.builder ~= nil then
        inst.components.builder:AddRecipe(recipe)
    end
    return true
end

function LifeRecipeUnlocks.UnlockAfterBuild(inst, protocol, recipe)
    if LifeRecipeUnlocks.IsUnlocked(inst, recipe) then
        return true
    end

    local slots = GetProtocolSlots(inst)
    if slots == nil or not slots:ConsumeLifeProtocol(protocol) then
        return false
    end

    return LifeRecipeUnlocks.MarkUnlocked(inst, recipe)
end

function LifeRecipeUnlocks.Sync(inst)
    local recipes = GetPermanentRecipes(inst)
    if recipes == nil or inst.components == nil or inst.components.builder == nil then
        return
    end

    for recipe, unlocked in pairs(recipes) do
        if unlocked then
            inst.components.builder:AddRecipe(recipe)
        end
    end
end

return LifeRecipeUnlocks
