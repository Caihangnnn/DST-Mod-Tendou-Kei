-- Lightweight entrypoint: each subsystem is loaded in dependency order.
GLOBAL.setmetatable(env, {
    __index = function(_, key)
        return GLOBAL.rawget(GLOBAL, key)
    end,
})

--- 模组唯一标识符，用于全局命名空间隔离。
---@type string
local modid = 'tendou_kei'

--- 角色 prefab 名称。
---@type string
local char_prefab = 'kei'

-- 将模组环境暴露为全局 API，便于其他模组或外部脚本访问。
GLOBAL.TENDOU_KEI_API = env

PrefabFiles = { char_prefab .. "__all_prefabs" }

Assets = {
    Asset("ANIM", "anim/kei_exp.zip"),  -- Experience status animation
    Asset("ANIM", "anim/kei.zip"),  --人物模型
    Asset("ANIM", "anim/ghost_kei_build.zip"),  --人物灵魂状态模型
    Asset("ANIM", "anim/kei_items.zip"),  -- 通用物品与通用CD地面动画图集
    Asset("ANIM", "anim/kei_life_cd.zip"),  -- 生活协议CD地面动画
    Asset("ANIM", "anim/kei_biome_cd.zip"),  -- 群系协议CD地面动画
    Asset("ANIM", "anim/kei_beast_purple_cd.zip"),  -- 巨兽协议紫色CD地面动画
    Asset("ANIM", "anim/kei_beast_golden_cd.zip"),  -- 巨兽协议金色CD地面动画
    Asset("ANIM", "anim/kei_data_recorder.zip"),  -- 数据记录器动画
    Asset("ANIM", "anim/kei_protocol_binder.zip"),  --协议预设盒动画
    Asset("ANIM", "anim/kei_protocol_popup.zip"),  --协议弹出动画
    Asset("ANIM", "anim/ui_kei_protocol_box_7x1.zip"),  --协议预设盒UI动画
    Asset("ANIM", "anim/ui_kei_mini_alice_box_8x1.zip"),  --娇小爱丽丝容器UI动画
    Asset("ANIM", "anim/wx_chassis.zip"),  --WX底盘动画
    Asset("ANIM", "anim/kei_status_power.zip"),  --状态功率动画
    Asset("ANIM", "anim/kei_status_stability.zip"),  --状态稳定性动画
    Asset("ANIM", "anim/kei_status_integrity.zip"),  --状态完整性动画
    Asset("ANIM", "anim/kei_status_power_meter.zip"),  --电量状态框动画
    Asset("ANIM", "anim/kei_status_stability_meter.zip"),  --稳定性状态框动画
    Asset("ANIM", "anim/kei_status_integrity_meter.zip"),  --完整性状态框动画
    Asset("ANIM", "anim/status_meter_wx_shield.zip"),  --WX立场动画

    Asset("ATLAS", "bigportraits/kei.xml"),  --人物大图
    Asset("IMAGE", "bigportraits/kei.tex"),

    Asset("ATLAS", "bigportraits/kei_none.xml"),  --人物立绘
    Asset("IMAGE", "bigportraits/kei_none.tex"),

    Asset("ATLAS", "images/names_kei.xml"),  --人物名称
    Asset("IMAGE", "images/names_kei.tex"),

    Asset("ATLAS", "images/avatars/avatar_kei.xml"),  --tab键人物列表显示的头像
    Asset("IMAGE", "images/avatars/avatar_kei.tex"),

    Asset("ATLAS", "images/avatars/avatar_ghost_kei.xml"),  --tab键人物列表显示的头像（死亡）
    Asset("IMAGE", "images/avatars/avatar_ghost_kei.tex"),

    Asset("ATLAS", "images/avatars/self_inspect_kei.xml"),  --人物检查按钮
    Asset("IMAGE", "images/avatars/self_inspect_kei.tex"),

    Asset("ATLAS", "images/map_icons/kei.xml"),  --人物地图图标
    Asset("IMAGE", "images/map_icons/kei.tex"),

    Asset("ATLAS", "images/map_icons/wandering_trader.xml"), --流浪商人图标
    Asset("IMAGE", "images/map_icons/wandering_trader.tex"),

    Asset("ATLAS", "images/saveslot_portraits/kei.xml"),  -- 存档图片
    Asset("IMAGE", "images/saveslot_portraits/kei.tex"),
    Asset("ATLAS", "images/inventoryimages/kei_items.xml"), -- 通用物品与通用CD图集
    Asset("IMAGE", "images/inventoryimages/kei_items.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_exp.xml"), -- 经验配方材料图标
    Asset("IMAGE", "images/inventoryimages/kei_exp.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_implant.xml"), -- 深度植入配方图标
    Asset("IMAGE", "images/inventoryimages/kei_implant.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_potential.xml"), -- 潜能激发配方图标
    Asset("IMAGE", "images/inventoryimages/kei_potential.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_life_cd_item.xml"), -- 生活协议CD图集
    Asset("IMAGE", "images/inventoryimages/kei_life_cd_item.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_biome_cd_item.xml"), -- 群系协议CD图集
    Asset("IMAGE", "images/inventoryimages/kei_biome_cd_item.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_beast_purple_cd_item.xml"), -- 巨兽协议紫色CD图集
    Asset("IMAGE", "images/inventoryimages/kei_beast_purple_cd_item.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_beast_golden_cd_item.xml"), -- 巨兽协议金色CD图集
    Asset("IMAGE", "images/inventoryimages/kei_beast_golden_cd_item.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_protocol_binder.xml"), -- 协议预设盒图集
    Asset("IMAGE", "images/inventoryimages/kei_protocol_binder.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_mini_alice.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_mini_alice.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_protocol_slot_states.xml"), -- 协议槽状态图集
    Asset("IMAGE", "images/inventoryimages/kei_protocol_slot_states.tex"),

    Asset("ATLAS", "images/inventoryimages/transparent_slot.xml"), -- 透明槽
    Asset("IMAGE", "images/inventoryimages/transparent_slot.tex"),

    Asset("ATLAS", "images/inventoryimages/kei_alice_slot.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_alice_slot.tex"),

    Asset("ATLAS", "images/inventoryimages/analysis_cd_slot.xml"),
    Asset("IMAGE", "images/inventoryimages/analysis_cd_slot.tex"),
}

PreloadAssets = {
    Asset("ANIM", "anim/kei_status_power.zip"),
    Asset("ANIM", "anim/kei_status_stability.zip"),
    Asset("ANIM", "anim/kei_status_integrity.zip"),
    Asset("ANIM", "anim/kei_status_power_meter.zip"),
    Asset("ANIM", "anim/kei_status_stability_meter.zip"),
    Asset("ANIM", "anim/kei_status_integrity_meter.zip"),
}

AddMinimapAtlas("images/map_icons/kei.xml")
AddMinimapAtlas("images/map_icons/wandering_trader.xml")

modimport("scripts/kei/config.lua")
modimport("scripts/kei/hooks/wanderingtrader_map.lua")
modimport("scripts/kei/hooks/dormant.lua")
modimport("scripts/kei/hooks/containers.lua")
modimport("scripts/kei/hooks/combat.lua")
modimport("scripts/kei/hooks/storm.lua")
modimport("scripts/kei/hooks/inventory.lua")
modimport("scripts/kei/hooks/itemtile.lua")
modimport("scripts/kei/hooks/experience.lua")
modimport("scripts/kei/init.lua")
modimport("scripts/kei/hooks/network.lua")

AddModCharacter(char_prefab, "FEMALE")
