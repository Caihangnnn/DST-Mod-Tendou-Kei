local KEI_FILTER = "KEI_PROTOCOLS"

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
    -- 未指定图标时，按设计要求统一回退到 wagstaff_item_2。
    local cfg = image(tex or "wagstaff_item_2.tex")
    cfg.builder_tag = "kei"
    if extra ~= nil then
        for k, v in pairs(extra) do
            cfg[k] = v
        end
    end
    return cfg
end

-- 同时挂到角色专属栏和 Kei 自己的协议栏。
local filters = { "CHARACTER", KEI_FILTER }

-- 空白 CD：用于绑定巨兽样本并提交到记录仪。
AddRecipe2(
    "kei_blank_cd",
    { Ingredient("charcoal", 10) },
    TECH.NONE,
    kei_config("record.tex"),
    filters
)

-- 数据记录仪部署包：部署后创建场景中的记录仪结构。
AddRecipe2(
    "kei_data_recorder_item",
    { Ingredient("transistor", 2), Ingredient("gears", 1) },
    TECH.NONE,
    kei_config("wagstaff_item_2.tex"),
    filters
)

-- 便携电池：直接补充电量。
AddRecipe2(
    "kei_battery",
    { Ingredient("transistor", 1) },
    TECH.NONE,
    kei_config("transistor.tex"),
    filters
)

-- 修理工具：恢复机体完整度，一次配方给多份便于测试。
AddRecipe2(
    "kei_repair_tool",
    { Ingredient("gears", 1), Ingredient("transistor", 1), Ingredient("butter", 1) },
    TECH.NONE,
    kei_config("sewing_tape.tex", { numtogive = 5 }),
    filters
)

-- 装备解析工具：把装备属性转换为解析协议 CD。
AddRecipe2(
    "kei_analysis_tool",
    { Ingredient("goldnugget", 10) },
    TECH.NONE,
    kei_config("wagstaff_tool_5.tex"),
    filters
)

-- 三个解锁模块共用同一套初版材料；实际解锁数量由模组配置决定。
for i = 1, 3 do
    AddRecipe2(
        "kei_protocol_mk" .. tostring(i),
        { Ingredient("goldnugget", 10) },
        TECH.NONE,
        kei_config("wx78module_stacksize.tex"),
        filters
    )
end
