local LifeRecipeUnlocks = require("kei/protocols/life/recipe_unlocks")

local DURABILITY_RESTORE_RECIPE = "kei_life_cd_durability_restore"
local MAP_TELEPORT_RECIPE = "kei_life_cd_map_teleport"

local hermitcrabs = {}

local function GetFriendLevel(hermitcrab)
    local friendlevels = hermitcrab ~= nil
        and hermitcrab.components ~= nil
        and hermitcrab.components.friendlevels
        or nil

    if friendlevels == nil then
        return 0
    end

    if friendlevels.GetLevel ~= nil then
        return friendlevels:GetLevel() or 0
    end

    return friendlevels.level or 0
end

local function IsKeiPlayer(player)
    return player ~= nil
        and player:IsValid()
        and player:HasTag("kei")
        and player.components ~= nil
        and player.components.kei_protocolslots ~= nil
        and player.components.builder ~= nil
end

local function SyncPlayerRecipes(player, hermitcrab)
    if not IsKeiPlayer(player) or hermitcrab == nil or not hermitcrab:IsValid() then
        return
    end

    local level = GetFriendLevel(hermitcrab)
    if level >= 6 then
        LifeRecipeUnlocks.MarkUnlocked(player, DURABILITY_RESTORE_RECIPE)
    end
    if level >= 10 then
        LifeRecipeUnlocks.MarkUnlocked(player, MAP_TELEPORT_RECIPE)
    end
end

local function SyncAllPlayers(hermitcrab)
    for _, player in ipairs(AllPlayers or {}) do
        SyncPlayerRecipes(player, hermitcrab)
    end
end

local function TrackHermitCrab(inst)
    if TheWorld == nil or not TheWorld.ismastersim then
        return
    end

    hermitcrabs[inst] = true

    inst:ListenForEvent("friend_level_changed", function()
        SyncAllPlayers(inst)
    end)

    inst:ListenForEvent("onremove", function()
        hermitcrabs[inst] = nil
    end)

    inst:DoTaskInTime(0, function()
        if inst:IsValid() then
            SyncAllPlayers(inst)
        end
    end)
end

local function SyncPlayerFromTrackedHermitCrabs(player)
    if not IsKeiPlayer(player) then
        return
    end

    for hermitcrab in pairs(hermitcrabs) do
        if hermitcrab ~= nil and hermitcrab:IsValid() then
            SyncPlayerRecipes(player, hermitcrab)
        else
            hermitcrabs[hermitcrab] = nil
        end
    end
end

AddPrefabPostInit("hermitcrab", TrackHermitCrab)

AddPlayerPostInit(function(player)
    if TheWorld == nil or not TheWorld.ismastersim then
        return
    end

    player:DoTaskInTime(0, function()
        SyncPlayerFromTrackedHermitCrabs(player)
    end)
end)
