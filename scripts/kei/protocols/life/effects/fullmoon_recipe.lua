-- 生活协议-满月配方：解锁一次性满月魔法制作入口。

local FullmoonRecipe = {}
local GrowthRecipes = require("kei/growth_recipes")

local PROTOCOL = "fullmoon_recipe"
local RECIPE = "kei_fullmoon_spell"
local EXPERIENCE_COST = TUNING.KEI_LIFE_FULLMOON_EXPERIENCE_COST or 100

local function HasFullmoonProtocol(inst)
    return inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_protocolslots ~= nil
        and inst.components.kei_protocolslots:HasLifeProtocol(PROTOCOL)
end

local function AddRecipeToBuilder(inst)
    if inst ~= nil and inst.components ~= nil and inst.components.builder ~= nil then
        inst.components.builder:AddRecipe(RECIPE)
    end
end

local function RemoveRecipeFromBuilder(inst)
    if inst ~= nil and inst.components ~= nil and inst.components.builder ~= nil then
        inst.components.builder:RemoveRecipe(RECIPE)
    end
end


function FullmoonRecipe.Cast(reader)
    if reader == nil or not reader:IsValid() then
        return false
    end

    if TheWorld:HasTag("cave") then
        return false, "NOMOONINCAVES"
    end

    -- 参考 Takanashi Hoshino「春风」的「启迪」：直接把当天设为全天月圆之夜。
    TheWorld:PushEvent("ms_setclocksegs", { day = 0, dusk = 0, night = 16 })
    TheWorld:PushEvent("ms_setmoonphase", { moonphase = "full", iswaxing = false })

    if reader.components.talker ~= nil and STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_FULLMOON_SPELL ~= nil then
        reader.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_FULLMOON_SPELL)
    end

    return true
end
function FullmoonRecipe.DoBuild(builder, recname, pt, rotation, skin)
    local inst = builder ~= nil and builder.inst or nil
    local recipe = GetValidRecipe(recname)
    if inst == nil
        or recipe == nil
        or not HasFullmoonProtocol(inst)
        or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
    then
        return false
    end

    if TheWorld:HasTag("cave") then
        return false, "NOMOONINCAVES"
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

    local casted, reason = FullmoonRecipe.Cast(inst)
    if not casted then
        return false, reason
    end
    if not GrowthRecipes.TrySpendExperience(inst, EXPERIENCE_COST) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function FullmoonRecipe.Enable(slots, inst)
    AddRecipeToBuilder(inst)
end

function FullmoonRecipe.Disable(slots, inst)
    RemoveRecipeFromBuilder(inst)
end

return FullmoonRecipe
