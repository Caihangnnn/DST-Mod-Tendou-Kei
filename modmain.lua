-- Lightweight entrypoint: each subsystem is loaded in dependency order.
GLOBAL.setmetatable(env, {
    __index = function(_, key)
        return GLOBAL.rawget(GLOBAL, key)
    end,
})

--- 角色 prefab 名称。
---@type string
local char_prefab = 'kei'

-- 将模组环境暴露为全局 API，便于其他模组或外部脚本访问。
GLOBAL.TENDOU_KEI_API = env

PrefabFiles = { char_prefab .. "__all_prefabs" }

-- 资源清单单独维护，避免入口文件同时承担资源和逻辑注册。
modimport("scripts/kei/assets.lua")
-- Load voice events before the larger Kei feature tree.
modimport("scripts/kei/sounds.lua")
modimport("scripts/kei/config.lua")
modimport("scripts/kei/hooks/init.lua")
modimport("scripts/kei/init.lua")

AddModCharacter(char_prefab, "FEMALE")
