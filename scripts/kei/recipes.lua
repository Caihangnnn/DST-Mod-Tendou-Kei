local KEI_FILTER = "KEI_PROTOCOLS"
local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")

-- 独立配方筛选栏，方便把 Kei 的协议/工具类物品集中展示。
AddRecipeFilter({
    name = KEI_FILTER,
    atlas = GetInventoryItemAtlas("wagstaff_item_2.tex"),
    image = "wagstaff_item_2.tex",
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
    cfg.builder_tag = "kei"
    return cfg
end

local function can_build_protocol_unlock(recipe, builder)
    return ProtocolSlotUnlocks.CanBuildUnlockRecipe(recipe, builder)
end

-- 同时挂到角色专属栏和 Kei 自己的协议栏。
local filters = { "CHARACTER", KEI_FILTER }

-- 空白 CD：用于绑定巨兽样本并提交到记录仪。
AddRecipe2(
    "kei_blank_cd",
    { Ingredient("charcoal", 10) },
    TECH.NONE,
    kei_config({
        atlas = "images/inventoryimages/kei_blank_cd.xml",
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
        atlas = "images/inventoryimages/kei_data_recorder_item.xml",
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
        atlas = "images/inventoryimages/kei_battery.xml",
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
        atlas = "images/inventoryimages/kei_repair_tool.xml",
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
        atlas = "images/inventoryimages/kei_analysis_tool.xml",
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

-- 协议槽解锁配方：每个配方只能使用一次，每次解锁最左侧的一个锁定槽位。
for _, def in ipairs(ProtocolSlotUnlocks.UNLOCK_RECIPE_LIST) do
    AddRecipe2(
        def.id,
        ProtocolSlotUnlocks.MakeIngredients(def),
        TECH.NONE,
        kei_config({
            atlas = def.atlas,
            image = def.image .. ".tex",
            canbuild = can_build_protocol_unlock,
        }),
        filters
    )
end