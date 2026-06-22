--[[
Character-skin registration and ownership checks for Tendou-Kei.

Derived from the open-level character skin registration API in DST-Sora,
`main/skinapi.lua`, and the user-ID whitelist extension in xuelu's
`scripts/api_skins/avatar_setsuro_skins.lua`.

Copyright 2022 [FL]. DST-Sora / MySora (Steam Workshop 1638724235).
The upstream Sora API requires its copyright notice to be preserved.
No Sora or xuelu art, animation, or game content is included here.
]]

local SKIN_AFFINITY_INFO = require("skin_affinity_info")
local Unlocks = require("kei/skins/unlock_ids")
local GLOBAL_TABLE = _G

local registered_skins = {}
local next_release_group = -100
local next_display_order = -1000

local function InsertUnique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

local function RegisterString(table_name, skin_name, value)
    STRINGS[table_name] = STRINGS[table_name] or {}
    STRINGS[table_name][skin_name] = value or ""
end

local function IsSkinUnlocked(skin_name, user_id)
    return Unlocks.IsUnlocked(skin_name, user_id)
end

local function AddOwnershipChecks(skin_name, data)
    if not data.requires_unlock then
        return
    end

    local old_checkfn = data.checkfn
    data.checkfn = function(inventory, checked_skin_name, ...)
        local user_id = TheNet ~= nil and TheNet:GetUserID() or nil
        return IsSkinUnlocked(skin_name, user_id)
            and (old_checkfn == nil or old_checkfn(inventory, checked_skin_name, ...))
    end

    local old_checkclientfn = data.checkclientfn
    data.checkclientfn = function(inventory, user_id, checked_skin_name, ...)
        return IsSkinUnlocked(skin_name, user_id)
            and (old_checkclientfn == nil or old_checkclientfn(inventory, user_id, checked_skin_name, ...))
    end
end

local function InstallOwnershipHooks()
    local inventory_api = rawget(GLOBAL_TABLE, "TheInventory")
    if rawget(GLOBAL_TABLE, "KEI_SKIN_OWNERSHIP_HOOKS_INSTALLED") or inventory_api == nil then
        return
    end
    rawset(GLOBAL_TABLE, "KEI_SKIN_OWNERSHIP_HOOKS_INSTALLED", true)

    local metatable = getmetatable(inventory_api)
    if metatable == nil or metatable.__index == nil then
        return
    end

    local old_check_ownership = inventory_api.CheckOwnership
    metatable.__index.CheckOwnership = function(inventory, skin_name, ...)
        local data = registered_skins[skin_name]
        if data ~= nil then
            return data.checkfn == nil or data.checkfn(inventory, skin_name, ...)
        end
        return old_check_ownership(inventory, skin_name, ...)
    end

    local old_check_latest = inventory_api.CheckOwnershipGetLatest
    metatable.__index.CheckOwnershipGetLatest = function(inventory, skin_name, ...)
        local data = registered_skins[skin_name]
        if data ~= nil then
            return data.checkfn == nil or data.checkfn(inventory, skin_name, ...), 0
        end
        return old_check_latest(inventory, skin_name, ...)
    end

    local old_check_client = inventory_api.CheckClientOwnership
    metatable.__index.CheckClientOwnership = function(inventory, user_id, skin_name, ...)
        local data = registered_skins[skin_name]
        if data ~= nil then
            return data.checkclientfn == nil or data.checkclientfn(inventory, user_id, skin_name, ...)
        end
        return old_check_client(inventory, user_id, skin_name, ...)
    end
end

local function MakeKeiCharacterSkin(skin_name, data)
    assert(type(skin_name) == "string" and skin_name ~= "", "skin_name is required")
    assert(type(data) == "table", "skin data is required")

    next_release_group = next_release_group - 1
    next_display_order = next_display_order + 1

    data.base_prefab = "kei"
    data.type = "base"
    data.rarity = data.rarity or "Character"
    data.release_group = data.release_group or next_release_group
    data.display_order = data.display_order or next_display_order
    data.build_name_override = data.build_name_override or skin_name

    AddOwnershipChecks(skin_name, data)
    registered_skins[skin_name] = data

    RegisterString("SKIN_NAMES", skin_name, data.name or skin_name)
    RegisterString("SKIN_DESCRIPTIONS", skin_name, data.description or data.des)
    RegisterString("SKIN_QUOTES", skin_name, data.quote or data.quotes)

    PREFAB_SKINS.kei = PREFAB_SKINS.kei or {}
    InsertUnique(PREFAB_SKINS.kei, skin_name)
    SKIN_AFFINITY_INFO.kei = SKIN_AFFINITY_INFO.kei or {}
    InsertUnique(SKIN_AFFINITY_INFO.kei, skin_name)

    InstallOwnershipHooks()
    return CreatePrefabSkin(skin_name, data)
end

return MakeKeiCharacterSkin
