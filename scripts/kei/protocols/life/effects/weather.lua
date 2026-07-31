-- 生活协议-晴雨配方：制作后在晴天与降水天气之间切换。

local WeatherRecipe = {}
local GrowthRecipes = require("kei/growth_recipes")
local RecipeUnlocks = require("kei/protocols/life/recipe_unlocks")

local PROTOCOL = "weather"
local RECIPE = "kei_weather_spell"
local EXPERIENCE_COST = TUNING.KEI_LIFE_WEATHER_EXPERIENCE_COST or 50

local function AddRecipeToBuilder(inst)
    RecipeUnlocks.Enable(inst, PROTOCOL, RECIPE)
end

local function RemoveRecipeFromBuilder(inst)
    RecipeUnlocks.Disable(inst, RECIPE)
end

local function PlayBookRainFx(reader)
    local ismount = reader.components.rider ~= nil and reader.components.rider:IsRiding()
    local fx = SpawnPrefab(ismount and "fx_book_rain_mount" or "fx_book_rain")
    if fx ~= nil then
        if ismount then
            fx.Transform:SetSixFaced()
        end
        fx.Transform:SetPosition(reader.Transform:GetWorldPosition())
        fx.Transform:SetRotation(reader.Transform:GetRotation())
    end
end

-- 复刻 book_rain 的额外效果：降雨/降雪切换时补满附近农田土壤湿度。
local function MoisturizeNearbyFarmSoil(reader)
    if TheWorld.components.farming_manager == nil then
        return
    end

    local x, y, z = reader.Transform:GetWorldPosition()
    local size = TILE_SCALE

    for i = x - size, x + size do
        for j = z - size, z + size do
            if TheWorld.Map:GetTileAtPoint(i, 0, j) == WORLD_TILES.FARMING_SOIL then
                TheWorld.components.farming_manager:AddSoilMoistureAtPoint(i, y, j, 100)
            end
        end
    end
end

function WeatherRecipe.Cast(reader)
    if reader == nil or not reader:IsValid() then
        return false
    end

    local was_precipitating = TheWorld.state.precipitation ~= "none"
    TheWorld:PushEvent("ms_forceprecipitation", not was_precipitating)
    PlayBookRainFx(reader)
    MoisturizeNearbyFarmSoil(reader)

    if reader.components.talker ~= nil then
        local key = was_precipitating and "ANNOUNCE_KEI_WEATHER_CLEAR" or "ANNOUNCE_KEI_WEATHER_WET"
        local line = STRINGS.CHARACTERS.KEI[key]
        if line ~= nil then
            reader.components.talker:Say(line)
        end
    end

    return true
end

function WeatherRecipe.DoBuild(builder, recname, pt, rotation, skin)
    local inst = builder ~= nil and builder.inst or nil
    local recipe = GetValidRecipe(recname)
    if inst == nil
        or recipe == nil
        or not RecipeUnlocks.CanUse(inst, PROTOCOL, RECIPE)
        or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
    then
        return false
    end

    if not GrowthRecipes.HasEnoughExperienceAmount(inst, EXPERIENCE_COST) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    if not (builder:IsBuildBuffered(recname) or builder:HasIngredients(recipe)) then
        return false
    end

    local is_buffered_build = builder.buffered_builds[recname] ~= nil
    if is_buffered_build then
        builder.buffered_builds[recname] = nil
        inst.replica.builder:SetIsBuildBuffered(recname, false)
    end

    inst:PushEvent("refreshcrafting")

    local casted, reason = WeatherRecipe.Cast(inst)
    if not casted then
        return false, reason
    end
    if not GrowthRecipes.TrySpendExperience(inst, EXPERIENCE_COST) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    if not RecipeUnlocks.UnlockAfterBuild(inst, PROTOCOL, RECIPE) then
        return false, "KEI_PROTOCOL_CONSUME_FAILED"
    end
    return true
end

function WeatherRecipe.Enable(slots, inst)
    AddRecipeToBuilder(inst)
end

function WeatherRecipe.Disable(slots, inst)
    RemoveRecipeFromBuilder(inst)
end

return WeatherRecipe
