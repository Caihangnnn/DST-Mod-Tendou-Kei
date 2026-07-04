local PowerStat = require("kei/stats/power")
local StabilityStat = require("kei/stats/stability")
local IntegrityStat = require("kei/stats/integrity")

local ProtocolSlotUnlocks = {}

-- 槽位解锁配方
ProtocolSlotUnlocks.UNLOCK_RECIPE_LIST = {
    {
        id = "kei_protocol_mk1",
        display_name = "协议槽扩展 Mk1",
        description = "解锁最左侧的一个锁定协议槽。",
        image = "kei_mk1",
        atlas = "images/inventoryimages/kei_mk1.xml",
        ingredients = { { "goldnugget", 10 } },
        route = "mk",
    },
    {
        id = "kei_protocol_mk2",
        display_name = "协议槽扩展 Mk2",
        description = "解锁最左侧的一个锁定协议槽。",
        image = "kei_mk2",
        atlas = "images/inventoryimages/kei_mk2.xml",
        ingredients = { { "gears", 2 }, { "transistor", 2 } },
        route = "mk",
    },
    {
        id = "kei_protocol_mk3",
        display_name = "协议槽扩展 Mk3",
        description = "解锁最左侧的一个锁定协议槽。",
        image = "kei_mk3",
        atlas = "images/inventoryimages/kei_mk3.xml",
        ingredients = { { "thulecite", 4 }, { "purplegem", 2 } },
        route = "mk",
    },
    {
        id = "kei_protocol_unlock_hermit",
        display_name = "协议槽扩展-寄居蟹",
        description = "使用寄居蟹路线材料，解锁最左侧的一个锁定协议槽。",
        image = "kei_mk1",
        atlas = "images/inventoryimages/kei_mk1.xml",
        ingredients = { { "hermit_pearl", 1 } },
        route = "hermit",
    },
    {
        id = "kei_protocol_unlock_trader",
        display_name = "协议槽扩展-流浪商人",
        description = "使用交易路线材料，解锁最左侧的一个锁定协议槽。",
        image = "kei_mk2",
        atlas = "images/inventoryimages/kei_mk2.xml",
        ingredients = { { "lucky_goldnugget", 12 } },
        route = "trader",
    },
    {
        id = "kei_protocol_unlock_ancient",
        display_name = "协议槽扩展-远古科技",
        description = "使用远古科技路线材料，解锁最左侧的一个锁定协议槽。",
        image = "kei_mk3",
        atlas = "images/inventoryimages/kei_mk3.xml",
        ingredients = { { "thulecite", 6 }, { "nightmarefuel", 4 } },
        route = "ancient",
    },
    {
        id = "kei_protocol_unlock_lunar",
        display_name = "协议槽扩展-月岛科技",
        description = "使用月岛科技路线材料，解锁最左侧的一个锁定协议槽。",
        image = "kei_mk3",
        atlas = "images/inventoryimages/kei_mk3.xml",
        ingredients = { { "moonrocknugget", 8 }, { "moonglass", 4 } },
        route = "lunar",
    },
}

ProtocolSlotUnlocks.UNLOCK_RECIPES = {}
for index, def in ipairs(ProtocolSlotUnlocks.UNLOCK_RECIPE_LIST) do
    def.index = index
    def.mask = 2 ^ (index - 1)
    ProtocolSlotUnlocks.UNLOCK_RECIPES[def.id] = def
end

function ProtocolSlotUnlocks.GetUnlockRecipe(recipe)
    local name = type(recipe) == "table" and (recipe.name or recipe.id) or recipe
    return name ~= nil and ProtocolSlotUnlocks.UNLOCK_RECIPES[name] or nil
end

-- 判断给定配方是否属于协议槽解锁配方
function ProtocolSlotUnlocks.IsUnlockRecipe(recipe)
    return ProtocolSlotUnlocks.GetUnlockRecipe(recipe) ~= nil
end

-- 获取当前配置允许的协议槽上限
function ProtocolSlotUnlocks.GetMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_MAX or 7
end

-- 获取模组内部允许的硬上限，避免配置超过系统支持范围
function ProtocolSlotUnlocks.GetHardMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_HARD_MAX or 7
end

-- 获取属性成长计算所用的基础初始槽位
function ProtocolSlotUnlocks.GetBaseInitialSlots()
    return TUNING.KEI_PROTOCOL_SLOT_BASE_INITIAL or 1
end

-- 获取角色开局实际可用的初始槽位
function ProtocolSlotUnlocks.GetInitialSlots()
    return TUNING.KEI_PROTOCOL_SLOT_INITIAL or ProtocolSlotUnlocks.GetBaseInitialSlots()
end

-- 根据超出基础初始槽位的部分计算总属性加成
function ProtocolSlotUnlocks.GetStatBonus(unlocked_slots)
    local extra_slots = math.max(0, unlocked_slots - ProtocolSlotUnlocks.GetBaseInitialSlots())
    return extra_slots * (TUNING.KEI_PROTOCOL_STAT_BONUS_PER_SLOT or TUNING.KEI_PROTOCOL_STAT_BONUS or 10)
end

-- 根据当前解锁槽位计算三维属性的最大值
function ProtocolSlotUnlocks.GetStatMaximums(unlocked_slots)
    local base_initial_slots = ProtocolSlotUnlocks.GetBaseInitialSlots()
    return {
        integrity = IntegrityStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
        power = PowerStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
        stability = StabilityStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
    }
end

-- 将解锁槽位数限制在当前允许的最小值与最大值之间
function ProtocolSlotUnlocks.ClampUnlockedSlots(unlocked_slots)
    return math.clamp(
        unlocked_slots,
        ProtocolSlotUnlocks.GetInitialSlots(),
        ProtocolSlotUnlocks.GetMaxSlots()
    )
end

-- 从组件或同步变量中读取角色当前已解锁的槽位数
function ProtocolSlotUnlocks.GetUnlockedSlots(builder)
    if builder == nil then
        return 0
    elseif builder.components ~= nil and builder.components.kei_protocolslots ~= nil then
        return builder.components.kei_protocolslots.unlocked_slots or ProtocolSlotUnlocks.GetInitialSlots()
    elseif builder._kei_unlocked_protocol_slots ~= nil then
        return builder._kei_unlocked_protocol_slots:value()
    end
    return ProtocolSlotUnlocks.GetInitialSlots()
end

-- 将已使用过的解锁配方集合编码为位掩码
function ProtocolSlotUnlocks.GetUsedRecipesMask(used_recipes)
    local mask = 0
    for _, def in ipairs(ProtocolSlotUnlocks.UNLOCK_RECIPE_LIST) do
        if used_recipes ~= nil and used_recipes[def.id] == true then
            mask = mask + (def.mask or 0)
        end
    end
    return mask
end

-- 判断某个位掩码中是否包含指定解锁配方
function ProtocolSlotUnlocks.MaskHasRecipe(mask, recipe)
    local def = ProtocolSlotUnlocks.GetUnlockRecipe(recipe)
    return def ~= nil and def.mask ~= nil and math.floor((mask or 0) / def.mask) % 2 >= 1
end

-- 从组件或同步变量中读取角色已使用解锁配方的位掩码
function ProtocolSlotUnlocks.GetBuilderUsedRecipesMask(builder)
    if builder == nil then
        return 0
    elseif builder.components ~= nil and builder.components.kei_protocolslots ~= nil then
        return builder.components.kei_protocolslots:GetUsedUnlockRecipesMask()
    elseif builder._kei_used_protocol_unlock_recipes ~= nil then
        return builder._kei_used_protocol_unlock_recipes:value()
    end
    return 0
end

-- 判断角色是否已经使用过指定的协议槽解锁配方
function ProtocolSlotUnlocks.BuilderHasUsedRecipe(builder, recipe)
    local def = ProtocolSlotUnlocks.GetUnlockRecipe(recipe)
    if def == nil then
        return false
    end
    local protocolslots = builder ~= nil and builder.components ~= nil and builder.components.kei_protocolslots or nil
    if protocolslots ~= nil then
        return protocolslots:HasUsedUnlockRecipe(def.id)
    end
    return ProtocolSlotUnlocks.MaskHasRecipe(ProtocolSlotUnlocks.GetBuilderUsedRecipesMask(builder), def.id)
end

-- 检查角色当前是否允许制作指定的协议槽解锁配方
function ProtocolSlotUnlocks.CanBuildUnlockRecipe(recipe, builder)
    local def = ProtocolSlotUnlocks.GetUnlockRecipe(recipe)
    if def == nil or builder == nil or not builder:HasTag("kei") then
        return false
    end
    if ProtocolSlotUnlocks.GetUnlockedSlots(builder) >= ProtocolSlotUnlocks.GetMaxSlots() then
        return false, "KEI_PROTOCOL_SLOTS_FULL"
    end
    if ProtocolSlotUnlocks.BuilderHasUsedRecipe(builder, def.id) then
        return false, "KEI_PROTOCOL_UNLOCK_RECIPE_USED"
    end
    return true
end

-- 将配方定义中的原材料表转换为制作系统使用的 Ingredient 列表
function ProtocolSlotUnlocks.MakeIngredients(def)
    local ingredients = {}
    for _, data in ipairs(def.ingredients or {}) do
        table.insert(ingredients, Ingredient(data[1], data[2]))
    end
    return ingredients
end

return ProtocolSlotUnlocks
