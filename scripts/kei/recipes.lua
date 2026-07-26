local KEI_FILTER = "KEI_PROTOCOLS"
local GrowthRecipes = require("kei/growth_recipes")

-- 独立配方筛选栏，方便把 Kei 的协议/工具类物品集中展示。
AddRecipeFilter({
    name = KEI_FILTER,
    atlas = GetInventoryItemAtlas("goldnugget.tex") or "images/inventoryimages1.xml",
    image = "goldnugget.tex",
    image_size = 64,
})

STRINGS.UI.CRAFTING_FILTERS[KEI_FILTER] = "Kei"

local function image(tex)
    -- AddRecipe2 需要 atlas + image 成对传入。
    return {
        atlas = GetInventoryItemAtlas(tex),
        image = tex,
    }
end

local function kei_config(tex, extra)
    -- 未显式指定图标的配方仍回退到通用 Kei 分类图标。
    local cfg
    if type(tex) == "table" then
        -- 如果第一个参数是 table，说明传入了完整的配置
        cfg = tex
    else
        -- 否则，使用传统的 tex + extra 方式
        cfg = image(tex or "wagstaff_item_2.tex")
        if extra ~= nil then
            for k, v in pairs(extra) do
                cfg[k] = v
            end
        end
    end

    -- AddCharacterRecipe 的配置经常只包含 product/nameoverride，必须给
    -- 没有专用图标的配方补充合法的原版金块图标。
    if cfg.atlas == nil or cfg.image == nil then
        cfg.atlas = cfg.atlas or GetInventoryItemAtlas("goldnugget.tex") or "images/inventoryimages1.xml"
        cfg.image = cfg.image or "goldnugget.tex"
    end
    cfg.builder_tag = "kei"
    return cfg
end

local function experience_ingredient(recname)
    -- SANITY is an already registered character ingredient. The private
    -- marker lets Kei replace its check without consuming sanity.
    local ingredient = Ingredient(
        CHARACTER_INGREDIENT.SANITY,
        5,
        "images/inventoryimages/kei_exp.xml",
        nil,
        "kei_exp.tex"
    )
    ingredient.kei_growth_recipe = recname
    return ingredient
end

local function fixed_experience_ingredient(amount)
    -- 复用已注册的 SANITY 角色材料分类，实际检查和扣除由 Kei 经验系统接管。
    local ingredient = Ingredient(
        CHARACTER_INGREDIENT.SANITY,
        5,
        "images/inventoryimages/kei_exp.xml",
        nil,
        "kei_exp.tex"
    )
    ingredient.kei_experience_cost = amount
    return ingredient
end

-- 同时挂到角色专属栏和 Kei 自己的协议栏。
local filters = { "CHARACTER", KEI_FILTER }

-- 友友球：宠物协议的可重复使用捕捉工具，暂用数据记录器部署包图标。
AddRecipe2(
    "kei_pet_capture_ball",
    { Ingredient("goldnugget", TUNING.KEI_PET_RECIPE_GOLD or 1) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_data_recorder_item.tex",
    }),
    filters
)

-- 三档宠物经验书：右键给予未插入协议槽的宠物 CD。
for tier = 1, 3 do
    AddRecipe2(
        "kei_pet_exp" .. tostring(tier),
        { Ingredient("goldnugget", TUNING.KEI_PET_RECIPE_GOLD or 1) },
        TECH.NONE,
        kei_config({
            atlas = "images/inventoryimages/kei_items.xml",
            image = "kei_pet_exp" .. tostring(tier) .. ".tex",
        }),
        filters
    )
end

-- 空白 CD：用于绑定巨兽样本并提交到记录仪。
AddRecipe2(
    "kei_blank_cd",
    { Ingredient("charcoal", 10) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_blank_cd.tex",
    }),
    filters
)

-- 数据记录仪部署包：部署后创建场景中的记录仪结构。
AddRecipe2(
    "kei_data_recorder_item",
    { Ingredient("transistor", 2), Ingredient("gears", 1) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_data_recorder_item.tex",
    }),
    filters
)

-- 便携电池：直接补充电量。
AddRecipe2(
    "kei_battery",
    { Ingredient("transistor", 1), Ingredient("glommerfuel", 1) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_battery.tex",
        numtogive = 3,
    }),
    filters
)

-- 修理工具：恢复机体完整度，一次配方给多份便于测试。
AddRecipe2(
    "kei_repair_tool",
    { Ingredient("gears", 1), Ingredient("transistor", 1), Ingredient("butter", 1) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_repair_tool.tex",
        numtogive = 3,
    }),
    filters
)

-- 装备解析工具：把装备属性转换为解析协议 CD。
AddRecipe2(
    "kei_analysis_tool",
    { Ingredient("goldnugget", 10) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_items.xml",
        image = "kei_analysis_tool.tex",
    }),
    filters
)

-- 协议预设盒：保存一组协议 CD，并可与当前已解锁协议槽一键交换。
AddRecipe2(
    "kei_protocol_binder",
    { Ingredient("boards", 2), Ingredient("transistor", 2) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_protocol_binder.xml",
        image = "kei_protocol_binder.tex",
    }),
    filters
)

-- 唤鱼魔法：大霜鲨生活协议插入时临时解锁；制作时直接施法，不生成物品。
AddRecipe2(
    "kei_fish_call_spell",
    { fixed_experience_ingredient(TUNING.KEI_LIFE_FISH_CALL_EXPERIENCE_COST or 50) },
    TECH.LOST,
    kei_config({
        atlas = GetInventoryItemAtlas("book_fish.tex"),
        image = "book_fish.tex",
        product = "kei_fish_call_spell",
        nounlock = true,
    }),
    filters
)
-- 满月魔法：满月生活协议插入时临时解锁；制作时直接施法，不生成物品。
AddRecipe2(
    "kei_fullmoon_spell",
    { fixed_experience_ingredient(TUNING.KEI_LIFE_FULLMOON_EXPERIENCE_COST or 100) },
    TECH.LOST,
    kei_config({
        atlas = GetInventoryItemAtlas("book_moon.tex"),
        image = "book_moon.tex",
        product = "kei_fullmoon_spell",
        nounlock = true,
    }),
    filters
)
-- 新月魔法：新月生活协议插入时临时解锁；制作时直接施法，不生成物品。
AddRecipe2(
    "kei_newmoon_spell",
    { fixed_experience_ingredient(TUNING.KEI_LIFE_NEWMOON_EXPERIENCE_COST or 100) },
    TECH.LOST,
    kei_config({
        atlas = GetInventoryItemAtlas("book_moon.tex"),
        image = "book_moon.tex",
        product = "kei_newmoon_spell",
        nounlock = true,
    }),
    filters
)
-- 催熟魔法：催熟生活协议插入时临时解锁；制作时直接施法，不生成物品。
AddRecipe2(
    "kei_ripen_spell",
    { fixed_experience_ingredient(TUNING.KEI_LIFE_RIPEN_EXPERIENCE_COST or 50) },
    TECH.LOST,
    kei_config({
        atlas = GetInventoryItemAtlas("book_horticulture_upgraded.tex"),
        image = "book_horticulture_upgraded.tex",
        product = "kei_ripen_spell",
        nounlock = true,
    }),
    filters
)

-- 晴雨魔法：晴雨生活协议插入时临时解锁；制作时直接切换晴天与降水，不生成物品。
AddRecipe2(
    "kei_weather_spell",
    { fixed_experience_ingredient(TUNING.KEI_LIFE_WEATHER_EXPERIENCE_COST or 50) },
    TECH.LOST,
    kei_config({
        atlas = GetInventoryItemAtlas("book_rain.tex"),
        image = "book_rain.tex",
        product = "kei_weather_spell",
        nounlock = true,
    }),
    filters
)
-- Kei can build Winona's portable engineering chain without inheriting Winona's tags.
local winona_recipes = {
    {
        name = "kei_sewing_tape",
        ingredients = { Ingredient("silk", 1), Ingredient("cutgrass", 3) },
        tech = TECH.NONE,
        config = { product = "sewing_tape", nameoverride = "sewing_tape", description = "sewing_tape" },
    },
    {
        name = "kei_winona_catapult_item",
        ingredients = { Ingredient("sewing_tape", 1), Ingredient("twigs", 3), Ingredient("rocks", 15) },
        tech = TECH.NONE,
        config = { product = "winona_catapult_item", nameoverride = "winona_catapult", description = "winona_catapult" },
    },
    {
        name = "kei_winona_spotlight_item",
        ingredients = { Ingredient("sewing_tape", 1), Ingredient("goldnugget", 2), Ingredient("fireflies", 1) },
        tech = TECH.NONE,
        config = { product = "winona_spotlight_item", nameoverride = "winona_spotlight", description = "winona_spotlight" },
    },
    {
        name = "kei_winona_battery_low_item",
        ingredients = { Ingredient("sewing_tape", 1), Ingredient("log", 2), Ingredient("nitre", 2) },
        tech = TECH.NONE,
        config = { product = "winona_battery_low_item", nameoverride = "winona_battery_low", description = "winona_battery_low" },
    },
    {
        name = "kei_winona_battery_high_item",
        ingredients = { Ingredient("sewing_tape", 1), Ingredient("boards", 2), Ingredient("transistor", 2) },
        tech = TECH.NONE,
        config = { product = "winona_battery_high_item", nameoverride = "winona_battery_high", description = "winona_battery_high" },
    },
    {
        name = "kei_winona_storage_robot",
        ingredients = { Ingredient("wagpunk_bits", 8), Ingredient("transistor", 4) },
        tech = TECH.NONE,
        config = { product = "winona_storage_robot", nameoverride = "winona_storage_robot", description = "winona_storage_robot" },
    },
    {
        name = "kei_winona_remote",
        ingredients = { Ingredient("transistor", 1) },
        tech = TECH.NONE,
        config = { product = "winona_remote", nameoverride = "winona_remote", description = "winona_remote" },
    },
}

for _, data in ipairs(winona_recipes) do
    AddCharacterRecipe(
        data.name,
        data.ingredients,
        data.tech,
        kei_config(data.config),
        { KEI_FILTER }
    )
end

-- Growth recipes consume the current full experience value.
AddRecipe2(
    GrowthRecipes.SLOT_UNLOCK_RECIPE,
    { experience_ingredient(GrowthRecipes.SLOT_UNLOCK_RECIPE) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_protocol_slot_states.xml",
        image = "kei_protocol_slot_openable.tex",
        product = GrowthRecipes.SLOT_UNLOCK_RECIPE,
        nounlock = true,
        canbuild = GrowthRecipes.CanBuildSlotUnlock,
    }),
    filters
)

AddRecipe2(
    GrowthRecipes.DEEP_IMPLANT_RECIPE,
    { experience_ingredient(GrowthRecipes.DEEP_IMPLANT_RECIPE) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_implant.xml",
        image = "kei_implant.tex",
        product = GrowthRecipes.DEEP_IMPLANT_RECIPE,
        nounlock = true,
        canbuild = GrowthRecipes.CanBuildDeepImplant,
    }),
    filters
)

AddRecipe2(
    GrowthRecipes.POTENTIAL_RECIPE,
    { experience_ingredient(GrowthRecipes.POTENTIAL_RECIPE) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_potential.xml",
        image = "kei_potential.tex",
        product = GrowthRecipes.POTENTIAL_RECIPE,
        nounlock = true,
        canbuild = GrowthRecipes.CanBuildPotential,
    }),
    filters
)
