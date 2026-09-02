-- 通用组件和实体钩子。保持这里的顺序，便于阅读和定位注册逻辑。

local HOOKS = {
    "wanderingtrader_map",
    "dormant",
    "containers",
    "combat",
    "storm",
    "inventory",
    "inventorybar",
    "itemtile",
    "experience",
    "hermitcrab",
    "task_targets",
    "network",
}

for _, name in ipairs(HOOKS) do
    modimport("scripts/kei/hooks/" .. name .. ".lua")
end
