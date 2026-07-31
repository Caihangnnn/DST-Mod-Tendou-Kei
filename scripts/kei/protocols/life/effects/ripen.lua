-- 生活协议-催熟配方：制作后推进周围可生长实体一个阶段，并让农作物强制巨大化。

local RipenRecipe = {}
local GrowthRecipes = require("kei/growth_recipes")
local RecipeUnlocks = require("kei/protocols/life/recipe_unlocks")

local PROTOCOL = "ripen"
local RECIPE = "kei_ripen_spell"
local EXPERIENCE_COST = TUNING.KEI_LIFE_RIPEN_EXPERIENCE_COST or 50
local GROW_TIMER_NAME = "grow"
local RIPEN_CANT_TAGS = { "INLIMBO", "FX", "player", "playerghost", "stump", "withered", "barren" }

local function AddRecipeToBuilder(inst)
    RecipeUnlocks.Enable(inst, PROTOCOL, RECIPE)
end

local function RemoveRecipeFromBuilder(inst)
    RecipeUnlocks.Disable(inst, RECIPE)
end

local function HasGrowTimer(inst)
    local timer = inst ~= nil and inst.components ~= nil and inst.components.timer or nil
    return timer ~= nil
        and timer.TimerExists ~= nil
        and timer:TimerExists(GROW_TIMER_NAME)
end

local function CanBeRipened(inst)
    if inst == nil or not inst:IsValid() or inst:IsInLimbo() then
        return false
    end

    if inst.components == nil then
        return false
    end

    return inst.components.growable ~= nil
        or inst.components.pickable ~= nil
        or inst.components.crop ~= nil
        or inst.components.harvestable ~= nil
        or HasGrowTimer(inst)
end

local function GetFarmPlantStageName(inst)
    local growable = inst.components ~= nil and inst.components.growable or nil
    local stagedata = growable ~= nil and growable.GetCurrentStageData ~= nil and growable:GetCurrentStageData() or nil
    return stagedata ~= nil and stagedata.name or nil
end

-- 农作物成熟前标记为强制巨大化；若已经成熟，则立刻刷新为巨大作物状态。
local function PrepareFarmPlantOversized(inst, doer)
    if inst.components == nil or inst.components.farmplantstress == nil then
        return false
    end

    inst.force_oversized = true

    if inst.components.farmplanttendable ~= nil then
        inst.components.farmplanttendable:TendTo(doer)
    end

    local stage_name = GetFarmPlantStageName(inst)
    local pickable = inst.components.pickable
    if stage_name == "full" or (pickable ~= nil and pickable.CanBePicked ~= nil and pickable:CanBePicked()) then
        inst.is_oversized = true
        if inst.components.growable ~= nil and inst.components.growable.SetStage ~= nil then
            inst.components.growable:SetStage(inst.components.growable:GetStage())
        end
        return true
    end

    return false
end

local function TryAdvanceGrowable(inst, doer)
    local growable = inst.components ~= nil and inst.components.growable or nil
    if growable == nil or growable.stages == nil then
        return false
    end

    local current = growable.GetStage ~= nil and growable:GetStage() or growable.stage
    if current == nil or (current >= #growable.stages and not growable.loopstages) then
        return false
    end

    if growable.DoGrowth ~= nil then
        local grew = growable:DoGrowth()
        local after = growable.GetStage ~= nil and growable:GetStage() or growable.stage
        if grew == true or after ~= current then
            return true
        end
    end

    if growable.DoMagicGrowth ~= nil and growable.domagicgrowthfn ~= nil and growable:DoMagicGrowth(doer) == true then
        return true
    end

    return false
end

-- 原版树苗、萌芽石、大理石豌豆树苗等不使用 growable，而是用名为 grow 的 timer 推进到下一形态。
local function TryAdvanceGrowTimer(inst)
    local timer = inst.components ~= nil and inst.components.timer or nil
    if timer == nil or timer.TimerExists == nil or not timer:TimerExists(GROW_TIMER_NAME) then
        return false
    end

    local timeleft = timer.GetTimeLeft ~= nil and timer:GetTimeLeft(GROW_TIMER_NAME) or nil
    if timeleft ~= nil and timeleft <= 1 then
        return false
    end

    if timer.SetTimeLeft ~= nil then
        timer:SetTimeLeft(GROW_TIMER_NAME, 1)
        return true
    end

    return false
end

local function TryAdvancePickable(inst)
    local pickable = inst.components ~= nil and inst.components.pickable or nil
    if pickable == nil then
        return false
    end

    if pickable.CanBePicked ~= nil and pickable:CanBePicked() then
        return false
    end

    if pickable.FinishGrowing == nil then
        return false
    end

    local grew = pickable:FinishGrowing()
    return grew == true
        or (pickable.CanBePicked ~= nil and pickable:CanBePicked())
end

local function TryAdvanceCrop(inst)
    local crop = inst.components ~= nil and inst.components.crop or nil
    if crop == nil or crop.DoGrow == nil or crop.IsReadyForHarvest == nil or crop:IsReadyForHarvest() then
        return false
    end

    local rate = crop.rate or 0
    if rate <= 0 then
        return false
    end

    local was_ready = crop:IsReadyForHarvest()
    local grew = crop:DoGrow(1 / rate, true)
    return grew == true or (not was_ready and crop:IsReadyForHarvest())
end

local function TryAdvanceHarvestable(inst)
    local harvestable = inst.components ~= nil and inst.components.harvestable or nil
    if harvestable == nil then
        return false
    end

    if harvestable.IsMagicGrowable ~= nil and harvestable:IsMagicGrowable() and harvestable.DoMagicGrowth ~= nil then
        harvestable:DoMagicGrowth()
        return true
    end

    if harvestable.Grow == nil then
        return false
    end

    local can_harvest_before = harvestable.CanBeHarvested ~= nil and harvestable:CanBeHarvested() or nil
    local grew = harvestable:Grow()
    local can_harvest_after = harvestable.CanBeHarvested ~= nil and harvestable:CanBeHarvested() or nil

    return grew == true
        or (can_harvest_before ~= nil and can_harvest_after ~= can_harvest_before)
end

local function TryRipenTarget(inst, doer)
    if not CanBeRipened(inst) then
        return false
    end

    if inst.components.witherable ~= nil and inst.components.witherable:IsWithered() then
        return false
    end

    if PrepareFarmPlantOversized(inst, doer) then
        return true
    end

    return TryAdvanceGrowable(inst, doer)
        or TryAdvanceGrowTimer(inst)
        or TryAdvancePickable(inst)
        or TryAdvanceCrop(inst)
        or TryAdvanceHarvestable(inst)
end

local function CollectRipenTargets(reader)
    local x, y, z = reader.Transform:GetWorldPosition()
    local radius = TUNING.KEI_LIFE_RIPEN_RADIUS or 30
    local max_targets = TUNING.KEI_LIFE_RIPEN_MAX_TARGETS or 999
    local targets = {}

    for _, target in ipairs(TheSim:FindEntities(x, y, z, radius, nil, RIPEN_CANT_TAGS)) do
        if target ~= reader and CanBeRipened(target) then
            table.insert(targets, target)
            if #targets >= max_targets then
                break
            end
        end
    end

    return targets
end

local function PlayRipenFx(reader)
    if reader.SoundEmitter ~= nil then
        reader.SoundEmitter:PlaySound("dontstarve/common/book_spell")
    end

    local x, y, z = reader.Transform:GetWorldPosition()
    local fx = SpawnPrefab("green_leaves")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y + 1, z)
    end
end

function RipenRecipe.Cast(reader, targets)
    if reader == nil or not reader:IsValid() then
        return false
    end

    targets = targets or CollectRipenTargets(reader)
    if #targets <= 0 then
        return false, "NOHORTICULTURE"
    end

    local changed = 0
    for _, target in ipairs(targets) do
        if target:IsValid() and TryRipenTarget(target, reader) then
            changed = changed + 1
        end
    end

    if changed <= 0 then
        return false, "NOHORTICULTURE"
    end

    PlayRipenFx(reader)
    if reader.components.talker ~= nil and STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_RIPEN_SPELL ~= nil then
        reader.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_RIPEN_SPELL)
    end

    return true
end

function RipenRecipe.DoBuild(builder, recname, pt, rotation, skin)
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

    local targets = CollectRipenTargets(inst)
    if #targets <= 0 then
        return false, "NOHORTICULTURE"
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

    local casted, reason = RipenRecipe.Cast(inst, targets)
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

function RipenRecipe.Enable(slots, inst)
    AddRecipeToBuilder(inst)
end

function RipenRecipe.Disable(slots, inst)
    RemoveRecipeFromBuilder(inst)
end

return RipenRecipe
