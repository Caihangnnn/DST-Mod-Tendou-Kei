-- 生活协议-新月配方：解锁一次性新月魔法制作入口。

local NewmoonRecipe = {}
local GrowthRecipes = require("kei/growth_recipes")

local PROTOCOL = "newmoon_recipe"
local RECIPE = "kei_newmoon_spell"
local EXPERIENCE_COST = TUNING.KEI_LIFE_NEWMOON_EXPERIENCE_COST or 100

local function HasNewmoonProtocol(inst)
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

local function PlayReverseBookMoonFx(reader)
    local ismount = reader.components.rider ~= nil and reader.components.rider:IsRiding()
    local anim = ismount and "play_fx_mount" or "play_fx"
    local fx = SpawnPrefab(ismount and "fx_book_moon_mount" or "fx_book_moon")
    if fx ~= nil then
        if ismount then
            fx.Transform:SetSixFaced()
        end
        fx.Transform:SetPosition(reader.Transform:GetWorldPosition())
        fx.Transform:SetRotation(reader.Transform:GetRotation())
        if fx.AnimState ~= nil then
            fx.AnimState:PlayAnimation(anim)
            local length = fx.AnimState:GetCurrentAnimationLength()
            fx.AnimState:SetTime(math.max(0, length - FRAMES))
            fx.AnimState:SetDeltaTimeMultiplier(-1)
        end
    end
end

function NewmoonRecipe.Cast(reader)
    if reader == nil or not reader:IsValid() then
        return false
    end

    if TheWorld:HasTag("cave") then
        return false, "NOMOONINCAVES"
    elseif TheWorld.state.moonphase == "new" then
        return false, "ALREADYNEWMOON"
    end

    TheWorld:PushEvent("ms_setmoonphase", { moonphase = "new", iswaxing = true })
    PlayReverseBookMoonFx(reader)

    if reader.components.talker ~= nil and STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_NEWMOON_SPELL ~= nil then
        reader.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_NEWMOON_SPELL)
    end

    return true
end

function NewmoonRecipe.DoBuild(builder, recname, pt, rotation, skin)
    local inst = builder ~= nil and builder.inst or nil
    local recipe = GetValidRecipe(recname)
    if inst == nil
        or recipe == nil
        or not HasNewmoonProtocol(inst)
        or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
    then
        return false
    end

    if TheWorld:HasTag("cave") then
        return false, "NOMOONINCAVES"
    elseif TheWorld.state.moonphase == "new" then
        return false, "ALREADYNEWMOON"
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

    local casted, reason = NewmoonRecipe.Cast(inst)
    if not casted then
        return false, reason
    end
    if not GrowthRecipes.TrySpendExperience(inst, EXPERIENCE_COST) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end
    return true
end

function NewmoonRecipe.Enable(slots, inst)
    AddRecipeToBuilder(inst)
end

function NewmoonRecipe.Disable(slots, inst)
    RemoveRecipeFromBuilder(inst)
end

return NewmoonRecipe
