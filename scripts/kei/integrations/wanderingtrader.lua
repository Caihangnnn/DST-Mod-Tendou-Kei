-- Kei's personal wandering trader stock. Vanilla trader recipes remain on
-- the native shared craftingstation path.

local RECIPE_PREFIX = "kei_wanderingtradershop_"
local REFRESH_INTERVAL_DAYS = 5
local REFRESH_DELAY = 15
local EXPERIENCE_ATLAS = "images/inventoryimages/kei_exp.xml"
local EXPERIENCE_IMAGE = "kei_exp.tex"

local CD_ITEMS = {
    {
        recipe = RECIPE_PREFIX .. "blank_cd_random",
        product = "kei_blank_cd_random",
        display_name = "白色CD礼盒",
        description = "消耗1个空白CD和递增的经验值购买。",
        stock = 3,
        experience = 250,
        image = "kei_blank_cd_random.tex",
    },
    {
        recipe = RECIPE_PREFIX .. "combat_cd_blue_random",
        product = "kei_combat_cd_blue_random",
        display_name = "蓝色CD礼盒",
        description = "消耗1个空白CD和递增的经验值购买。",
        stock = 2,
        experience = 500,
        image = "kei_combat_cd_blue_random.tex",
    },
    {
        recipe = RECIPE_PREFIX .. "combat_cd_golden_random",
        product = "kei_combat_cd_golden_random",
        display_name = "金色CD礼盒",
        description = "消耗1个空白CD和递增的经验值购买。",
        stock = 1,
        experience = 1000,
        image = "kei_combat_cd_golden_random.tex",
    },
}

local TRADE_BOOST_RECIPE = RECIPE_PREFIX .. "trade_boost"
local TRADE_BOOST_PRODUCT = "kei_life_cd_trade_boost"
local TRADE_BOOST_EXPERIENCE = 100

local SHOP_ITEMS_BY_RECIPE = {}
for _, item in ipairs(CD_ITEMS) do
    SHOP_ITEMS_BY_RECIPE[item.recipe] = item
end
SHOP_ITEMS_BY_RECIPE[TRADE_BOOST_RECIPE] = {
    recipe = TRADE_BOOST_RECIPE,
    product = TRADE_BOOST_PRODUCT,
    display_name = "伶牙俐齿",
    description = "三种 CD 商品全部售空后解锁，仅可购买一次。",
    stock = 1,
    experience = TRADE_BOOST_EXPERIENCE,
    image = "kei_life_cd.tex",
    is_trade_boost = true,
}

local function IsShopRecipe(recipename)
    return SHOP_ITEMS_BY_RECIPE[recipename] ~= nil
end

local function GetShopCycle()
    return math.floor((TheWorld.state.cycles or 0) / REFRESH_INTERVAL_DAYS)
end

local function NewShopState()
    local stock = {}
    for _, item in ipairs(CD_ITEMS) do
        stock[item.recipe] = item.stock
    end
    return {
        cycle = GetShopCycle(),
        stock = stock,
        trade_boost_purchased = false,
    }
end

local function GetShopState(player)
    local cycle = GetShopCycle()
    local state = player._kei_wanderingtrader_shop_state
    if state == nil or state.cycle ~= cycle then
        state = NewShopState()
        player._kei_wanderingtrader_shop_state = state
    end
    if state.stock == nil then
        state.stock = {}
    end
    for _, item in ipairs(CD_ITEMS) do
        if state.stock[item.recipe] == nil then
            state.stock[item.recipe] = item.stock
        end
    end
    return state
end

local function IsKeiWanderingTrader(prototyper)
    return prototyper ~= nil
        and prototyper:IsValid()
        and prototyper.prefab == "wanderingtrader"
        and prototyper.components ~= nil
        and prototyper.components.craftingstation ~= nil
end

local function IsKeiShopBuilder(builder)
    return builder ~= nil
        and builder.inst ~= nil
        and builder.inst:HasTag("kei")
        and IsKeiWanderingTrader(builder.current_prototyper)
end

local function AreAllCDsSold(state)
    for _, item in ipairs(CD_ITEMS) do
        if (state.stock[item.recipe] or 0) > 0 then
            return false
        end
    end
    return true
end

local function GetServerRemaining(builder, item)
    local state = GetShopState(builder.inst)
    return math.max(0, tonumber(state.stock[item.recipe]) or 0)
end

local function GetClientRemaining(builder, item)
    local replica = builder ~= nil and builder.replica ~= nil and builder.replica.builder or nil
    if replica ~= nil and replica.GetAllRecipeCraftingLimits ~= nil then
        local limits = replica:GetAllRecipeCraftingLimits()
        if limits ~= nil and limits[item.recipe] ~= nil then
            return math.max(0, tonumber(limits[item.recipe]) or 0)
        end
    end
    return item.stock
end

local function GetShopExperienceCostForItem(builder, item)
    local remaining
    if builder ~= nil and builder.components ~= nil and builder.components.builder ~= nil then
        remaining = GetServerRemaining(builder.components.builder, item)
    else
        remaining = GetClientRemaining(builder, item)
    end

    local purchased = math.max(0, item.stock - remaining)
    return item.experience * (2 ^ purchased)
end

local function GetShopExperienceCost(ingredient, builder)
    local item = ingredient ~= nil
        and SHOP_ITEMS_BY_RECIPE[ingredient.kei_wanderingtrader_recipe]
        or nil
    return item ~= nil and GetShopExperienceCostForItem(builder, item) or 0
end

local function MakeExperienceIngredient(recipe, item)
    local ingredient = Ingredient(
        CHARACTER_INGREDIENT.KEI_EXPERIENCE,
        5,
        EXPERIENCE_ATLAS,
        nil,
        EXPERIENCE_IMAGE
    )
    ingredient.kei_experience_cost_fn = GetShopExperienceCost
    ingredient.kei_wanderingtrader_recipe = recipe
    return ingredient
end

local function MakeFixedExperienceIngredient(amount)
    local ingredient = Ingredient(
        CHARACTER_INGREDIENT.KEI_EXPERIENCE,
        5,
        EXPERIENCE_ATLAS,
        nil,
        EXPERIENCE_IMAGE
    )
    ingredient.kei_experience_cost = amount
    return ingredient
end

local function SetRecipeStrings(item)
    local key = string.upper(item.recipe)
    STRINGS.NAMES[key] = item.display_name
    STRINGS.RECIPE_DESC[key] = item.description
end

local function AddShopRecipe(item)
    SetRecipeStrings(item)

    local ingredients
    if item.is_trade_boost then
        ingredients = { MakeFixedExperienceIngredient(TRADE_BOOST_EXPERIENCE) }
    else
        ingredients = {
            Ingredient(
                "kei_blank_cd",
                1,
                "images/inventoryimages/kei_items.xml",
                nil,
                "kei_blank_cd.tex"
            ),
            MakeExperienceIngredient(item.recipe, item),
        }
    end

    AddRecipe2(
        item.recipe,
        ingredients,
        TECH.LOST,
        {
            limitedamount = true,
            nounlock = true,
            builder_tag = "kei",
            manufactured = true,
            actionstr = "WANDERINGTRADERSHOP",
            sg_state = "give",
            product = item.product,
            nameoverride = item.recipe,
            description = item.recipe,
            atlas = item.is_trade_boost
                and "images/inventoryimages/kei_life_cd_item.xml"
                or "images/inventoryimages/kei_items.xml",
            image = item.image,
        }
    )
end

for _, item in ipairs(CD_ITEMS) do
    AddShopRecipe(item)
end
AddShopRecipe(SHOP_ITEMS_BY_RECIPE[TRADE_BOOST_RECIPE])

local function AddShopWare(inst, item)
    if inst.AddWares == nil then
        return
    end

    inst:AddWares({
        [item.product] = {
            recipe = item.recipe,
            min = item.stock,
            max = item.stock,
            limit = item.stock,
        },
    })
end

local function ClearShopWares(inst)
    local craftingstation = inst.components ~= nil and inst.components.craftingstation or nil
    if craftingstation == nil then
        return
    end

    for recipename in pairs(SHOP_ITEMS_BY_RECIPE) do
        craftingstation:ForgetRecipe(recipename)
    end
end

local function HasShopWares(inst)
    local craftingstation = inst.components ~= nil and inst.components.craftingstation or nil
    if craftingstation == nil then
        return false
    end

    -- A previous shared-station purchase can remove only one recipe. Check
    -- every Kei shop recipe so the next refresh repairs partial state.
    for recipename in pairs(SHOP_ITEMS_BY_RECIPE) do
        if not craftingstation:KnowsRecipe(recipename) then
            return false
        end
    end
    return true
end

local function RefreshShopWares(inst, force)
    local cycles = TheWorld.state.cycles or 0
    if not force and inst.kei_wanderingtrader_last_kei_refresh_cycle == cycles then
        return
    end

    ClearShopWares(inst)
    for _, item in ipairs(CD_ITEMS) do
        AddShopWare(inst, item)
    end
    AddShopWare(inst, SHOP_ITEMS_BY_RECIPE[TRADE_BOOST_RECIPE])

    inst.kei_wanderingtrader_last_kei_refresh_cycle = cycles
    if inst.EnablePrototyper ~= nil and inst:HasTag("revealed") then
        inst:EnablePrototyper(true)
    end
end

local function CancelRefreshTask(inst)
    if inst.kei_wanderingtrader_kei_refresh_task ~= nil then
        inst.kei_wanderingtrader_kei_refresh_task:Cancel()
        inst.kei_wanderingtrader_kei_refresh_task = nil
    end
end

local function DoScheduledRefresh(inst)
    inst.kei_wanderingtrader_kei_refresh_task = nil
    if (TheWorld.state.cycles or 0) % REFRESH_INTERVAL_DAYS == 0 then
        RefreshShopWares(inst)
    end
end

local function ScheduleRefresh(inst)
    CancelRefreshTask(inst)

    local cycles = TheWorld.state.cycles or 0
    if cycles % REFRESH_INTERVAL_DAYS ~= 0
        or inst.kei_wanderingtrader_last_kei_refresh_cycle == cycles
    then
        return
    end

    local elapsed = (TheWorld.state.time or 0) * TUNING.TOTAL_DAY_TIME
    local delay = REFRESH_DELAY - elapsed
    inst.kei_wanderingtrader_kei_refresh_task = inst:DoTaskInTime(
        math.max(0, delay),
        DoScheduledRefresh
    )
end

local function SyncShopLimits(builder)
    if not IsKeiShopBuilder(builder) then
        return
    end

    local state = GetShopState(builder.inst)
    local all_sold = AreAllCDsSold(state)
    local trade_recipe_available = all_sold and not state.trade_boost_purchased

    for _, item in ipairs(CD_ITEMS) do
        if builder.station_recipes[item.recipe] ~= nil then
            builder.station_recipes[item.recipe] = GetServerRemaining(builder, item)
        end
    end

    if trade_recipe_available and builder.station_recipes[TRADE_BOOST_RECIPE] ~= nil then
        builder.station_recipes[TRADE_BOOST_RECIPE] = 1
        builder.inst.replica.builder:AddRecipe(TRADE_BOOST_RECIPE)
    else
        builder.station_recipes[TRADE_BOOST_RECIPE] = nil
        builder.inst.replica.builder:RemoveRecipe(TRADE_BOOST_RECIPE)
    end

    local limit_data = {}
    for recipename, amount in pairs(builder.station_recipes) do
        if amount ~= true then
            table.insert(limit_data, { recipe = recipename, amount = amount })
        end
    end
    table.sort(limit_data, function(left, right)
        return left.recipe < right.recipe
    end)

    local limit_count = CRAFTINGSTATION_LIMITED_RECIPES_COUNT or #limit_data
    for index = 1, limit_count do
        local data = limit_data[index]
        builder.inst.replica.builder:SetRecipeCraftingLimit(
            index,
            data ~= nil and data.recipe or nil,
            data ~= nil and data.amount or nil
        )
    end
end

local function ConsumeShopItemIngredients(builder, item)
    local inventory = builder.inst.components ~= nil and builder.inst.components.inventory or nil
    if inventory == nil then
        return false
    end

    if not inventory:Has("kei_blank_cd", 1, true) then
        return false
    end
    local experience = builder.inst.components.kei_experience
    local cost = item.is_trade_boost
        and TRADE_BOOST_EXPERIENCE
        or GetShopExperienceCostForItem(builder.inst, item)
    if experience == nil or experience.current < cost then
        return false
    end

    inventory:ConsumeByName("kei_blank_cd", 1)
    experience:DoDelta(-cost)
    return true
end

local function SpawnShopProduct(builder, item)
    return SpawnPrefab(item.product, nil, nil, builder.inst.userid)
end

local function DoShopBuild(builder, recipename)
    local item = SHOP_ITEMS_BY_RECIPE[recipename]
    if item == nil or not IsKeiShopBuilder(builder) then
        return false
    end

    local state = GetShopState(builder.inst)
    if item.is_trade_boost then
        if not AreAllCDsSold(state) or state.trade_boost_purchased then
            return false
        end
    elseif (state.stock[item.recipe] or 0) <= 0 then
        return false
    end

    local recipe = GetValidRecipe(recipename)
    if recipe == nil or not builder:HasIngredients(recipe) then
        return false
    end

    local product = SpawnShopProduct(builder, item)
    if product == nil then
        return false
    end

    if not item.is_trade_boost and not ConsumeShopItemIngredients(builder, item) then
        product:Remove()
        return false
    elseif item.is_trade_boost then
        local experience = builder.inst.components.kei_experience
        if experience == nil or experience.current < TRADE_BOOST_EXPERIENCE then
            product:Remove()
            return false
        end
        experience:DoDelta(-TRADE_BOOST_EXPERIENCE)
    end

    builder.inst.components.inventory:GiveItem(product, nil, builder.inst:GetPosition())

    if item.is_trade_boost then
        state.trade_boost_purchased = true
    else
        state.stock[item.recipe] = math.max(0, (state.stock[item.recipe] or 0) - 1)
    end

    builder.inst:PushEvent("refreshcrafting")
    builder:EvaluateTechTrees()
    return true
end

local function ActivateShopTraderWithoutConsumingSharedStock(builder, recipe)
    local prototyper = builder ~= nil and builder.current_prototyper or nil
    local prototyper_component = prototyper ~= nil
        and prototyper.components ~= nil
        and prototyper.components.prototyper
        or nil

    -- The normal activation path calls CraftingStation:RecipeCrafted first.
    -- Kei shop stock is player-specific, so keep only the trader callback.
    if prototyper_component ~= nil and prototyper_component.onactivate ~= nil then
        prototyper_component.onactivate(prototyper, builder.inst, recipe)
    end
end

AddComponentPostInit("builder", function(builder)
    local old_DoBuild = builder.DoBuild
    local old_ActivateCurrentResearchMachine = builder.ActivateCurrentResearchMachine
    builder.DoBuild = function(self, recipename, ...)
        if IsShopRecipe(recipename) then
            return DoShopBuild(self, recipename, ...)
        end
        return old_DoBuild(self, recipename, ...)
    end

    builder.ActivateCurrentResearchMachine = function(self, recipe, ...)
        local recipename = type(recipe) == "string"
            and recipe
            or recipe ~= nil and recipe.name
            or nil
        if IsShopRecipe(recipename) then
            ActivateShopTraderWithoutConsumingSharedStock(self, recipe)
            return
        end
        return old_ActivateCurrentResearchMachine(self, recipe, ...)
    end

    local old_EvaluateTechTrees = builder.EvaluateTechTrees
    builder.EvaluateTechTrees = function(self, ...)
        local result = { old_EvaluateTechTrees(self, ...) }
        SyncShopLimits(self)
        return unpack(result)
    end
end)

AddPlayerPostInit(function(player)
    if not TheWorld.ismastersim then
        return
    end

    local old_OnSave = player.OnSave
    player.OnSave = function(inst, data)
        if old_OnSave ~= nil then
            old_OnSave(inst, data)
        end
        local state = inst._kei_wanderingtrader_shop_state
        if state ~= nil then
            data.kei_wanderingtrader_shop_state = deepcopy(state)
        end
    end

    local old_OnLoad = player.OnLoad
    player.OnLoad = function(inst, data)
        if old_OnLoad ~= nil then
            old_OnLoad(inst, data)
        end
        inst._kei_wanderingtrader_shop_state = data ~= nil
            and data.kei_wanderingtrader_shop_state
            or nil
    end
end)

AddPrefabPostInit("wanderingtrader", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    local old_OnSave = inst.OnSave
    inst.OnSave = function(entity, data)
        if old_OnSave ~= nil then
            old_OnSave(entity, data)
        end
        data.kei_wanderingtrader_last_kei_refresh_cycle = entity.kei_wanderingtrader_last_kei_refresh_cycle
    end

    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(entity, data, ...)
        if old_OnLoad ~= nil then
            old_OnLoad(entity, data, ...)
        end
        entity.kei_wanderingtrader_last_kei_refresh_cycle = data ~= nil
            and data.kei_wanderingtrader_last_kei_refresh_cycle
            or nil
    end

    inst:WatchWorldState("cycles", ScheduleRefresh)
    inst:DoTaskInTime(0, function(entity)
        if not HasShopWares(entity) then
            RefreshShopWares(entity, true)
        end
        ScheduleRefresh(entity)
    end)
    inst:ListenForEvent("onremove", CancelRefreshTask)
end)
