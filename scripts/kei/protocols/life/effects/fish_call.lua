-- 生活协议-大霜鲨：解锁唤鱼魔法，并强化池钓与海钓。

local FishCall = {}
local GrowthRecipes = require("kei/growth_recipes")
local RecipeUnlocks = require("kei/protocols/life/recipe_unlocks")

local PROTOCOL = "fish_call"
local RECIPE = "kei_fish_call_spell"
local EXPERIENCE_COST = TUNING.KEI_LIFE_FISH_CALL_EXPERIENCE_COST or 50
local POND_MAX_WAIT = 2
local OCEAN_HOOK_RADIUS = 20
local FISH_SPAWN_OFFSET = 10
local MAX_FAILED_ATTEMPTS = 36
local OCEANFISH_MUST_TAGS = { "oceanfish", "oceanfishable" }
local OCEANFISH_CANT_TAGS = { "INLIMBO" }

local FishingRod = require("components/fishingrod")
local OceanFishingHook = require("components/oceanfishinghook")
local FISH_DATA = require("prefabs/oceanfishdef")

local function HasFishCallProtocol(inst)
    return inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_protocolslots ~= nil
        and inst.components.kei_protocolslots:HasLifeProtocol(PROTOCOL)
end

local function AddRecipeToBuilder(inst)
    RecipeUnlocks.Enable(inst, PROTOCOL, RECIPE)
end

local function RemoveRecipeFromBuilder(inst)
    RecipeUnlocks.Disable(inst, RECIPE)
end

local function GetHookRod(hook)
    return hook ~= nil
        and hook.inst ~= nil
        and hook.inst.components ~= nil
        and hook.inst.components.oceanfishable ~= nil
        and hook.inst.components.oceanfishable:GetRod()
        or nil
end

local function GetHookFisher(hook)
    local rod = GetHookRod(hook)
    return rod ~= nil
        and rod.components ~= nil
        and rod.components.oceanfishingrod ~= nil
        and rod.components.oceanfishingrod.fisher
        or nil
end

-- 海钓浮标落水后，若附近已有海鱼，直接让它咬钩。
local function TryForceOceanFishBite(hook)
    local fisher = GetHookFisher(hook)
    if not HasFishCallProtocol(fisher) then
        return false
    end

    local rod = GetHookRod(hook)
    local rod_component = rod ~= nil and rod.components ~= nil and rod.components.oceanfishingrod or nil
    if rod_component == nil or rod_component.target ~= hook.inst then
        return false
    end

    local x, y, z = hook.inst.Transform:GetWorldPosition()
    local fishes = TheSim:FindEntities(x, y, z, OCEAN_HOOK_RADIUS, OCEANFISH_MUST_TAGS, OCEANFISH_CANT_TAGS)
    for _, fish in ipairs(fishes) do
        if fish ~= hook.inst
            and fish:IsValid()
            and fish.components ~= nil
            and fish.components.oceanfishable ~= nil
            and fish.components.oceanfishable:GetRod() == nil
        then
            rod_component:SetTarget(fish)
            return true
        end
    end

    return false
end

local function PatchFishingRod()
    if FishingRod._kei_fish_call_patched then
        return
    end
    FishingRod._kei_fish_call_patched = true

    local old_wait_for_fish = FishingRod.WaitForFish
    function FishingRod:WaitForFish()
        if HasFishCallProtocol(self.fisherman) then
            local old_min = self.minwaittime
            local old_max = self.maxwaittime
            self.maxwaittime = math.min(old_max or POND_MAX_WAIT, POND_MAX_WAIT)
            self.minwaittime = math.min(old_min or 0, self.maxwaittime)
            local ok, result = pcall(old_wait_for_fish, self)
            self.minwaittime = old_min
            self.maxwaittime = old_max
            if not ok then
                error(result)
            end
            return result
        end
        return old_wait_for_fish(self)
    end
end

local function PatchOceanFishingHook()
    if OceanFishingHook._kei_fish_call_patched then
        return
    end
    OceanFishingHook._kei_fish_call_patched = true

    local old_set_lure_data = OceanFishingHook.SetLureData
    function OceanFishingHook:SetLureData(lure_data, lure_fns)
        local result = old_set_lure_data(self, lure_data, lure_fns)
        if self.inst ~= nil then
            self.inst:DoTaskInTime(0, function()
                if self.inst ~= nil and self.inst:IsValid() then
                    TryForceOceanFishBite(self)
                end
            end)
        end
        return result
    end

    local old_on_wall_update = OceanFishingHook.OnWallUpdate
    function OceanFishingHook:OnWallUpdate(dt)
        if TryForceOceanFishBite(self) then
            return
        end
        return old_on_wall_update(self, dt)
    end

    local old_test_interest = OceanFishingHook.TestInterest
    function OceanFishingHook:TestInterest(fish)
        local fisher = GetHookFisher(self)
        if HasFishCallProtocol(fisher) then
            return fish ~= nil and fish:IsNear(self.inst, OCEAN_HOOK_RADIUS)
        end
        return old_test_interest(self, fish)
    end

    local old_update_interest = OceanFishingHook.UpdateInterestForFishable
    function OceanFishingHook:UpdateInterestForFishable(fish)
        local fisher = GetHookFisher(self)
        if HasFishCallProtocol(fisher) then
            if fish ~= nil then
                self.interest[fish.GUID] = 1
            end
            return 1
        end
        return old_update_interest(self, fish)
    end
end

PatchFishingRod()
PatchOceanFishingHook()

local function PickAnySeasonSchool(spawnpoint)
    if FISH_DATA == nil or FISH_DATA.school == nil or FISH_DATA.fish == nil then
        return nil
    end

    local tile = TheWorld.Map:GetTileAtPoint(spawnpoint.x, spawnpoint.y, spawnpoint.z)
    local choices = {}
    for _, seasondata in pairs(FISH_DATA.school) do
        local tile_choices = seasondata[tile]
        if tile_choices ~= nil then
            for prefab, weight in pairs(tile_choices) do
                choices[prefab] = (choices[prefab] or 0) + weight
            end
        end
    end

    local schooltype = next(choices) ~= nil and weighted_random_choice(choices) or nil
    return schooltype ~= nil and FISH_DATA.fish[schooltype] or nil
end

local function DoSpawnFish(prefab, pos, rot, herd)
    if herd ~= nil and herd:IsValid() then
        local fish = SpawnPrefab(prefab)
        if fish ~= nil then
            if fish.Physics ~= nil then
                fish.Physics:Teleport(pos:Get())
            else
                fish.Transform:SetPosition(pos:Get())
            end
            fish.Transform:SetRotation(rot)
            if fish.components ~= nil and fish.components.herdmember ~= nil then
                fish.components.herdmember:Enable(true)
                fish.components.herdmember.herdprefab = herd.prefab
            end
            if fish.sg ~= nil then
                fish.sg:GoToState("arrive")
            end
            if herd.components ~= nil and herd.components.herd ~= nil then
                herd.components.herd:AddMember(fish)
            end
        end
    end
end

-- 复制原版 schoolspawner 的生成形态，但选鱼时合并所有季节权重。
local function SpawnAnySeasonSchool(spawnpoint, override_spawn_offset)
    local schooldata = PickAnySeasonSchool(spawnpoint)
    if schooldata == nil then
        return 0
    end

    local herd = SpawnPrefab("schoolherd_" .. schooldata.prefab)
    if herd == nil then
        return 0
    end
    herd.Transform:SetPosition(spawnpoint:Get())

    local schoolsize = math.random(schooldata.schoolmin, schooldata.schoolmax)
    local rotation = math.random() * 360
    local school_rand_angle = math.random() * 360
    local school_spawnpoint = spawnpoint + (override_spawn_offset
        or FindSwimmableOffset(spawnpoint, school_rand_angle, 20, 12, nil, nil, nil, true)
        or FindSwimmableOffset(spawnpoint, school_rand_angle, 13, 12, nil, nil, nil, true)
        or FindSwimmableOffset(spawnpoint, school_rand_angle, 7, 12, nil, nil, nil, true)
        or Vector3(0, 0, 0))

    local count = 0
    for i = 1, schoolsize do
        local radius = math.sqrt(math.random()) * schooldata.schoolrange
        local angle = math.random() * 360
        local offset = FindSwimmableOffset(school_spawnpoint, angle, radius, 12, true, nil, nil, true)
        if offset ~= nil then
            local pos = school_spawnpoint + offset
            if count == 0 then
                DoSpawnFish(schooldata.prefab, pos, rotation, herd)
            else
                TheWorld:DoTaskInTime(0.1 + math.random(), function()
                    DoSpawnFish(schooldata.prefab, pos, rotation, herd)
                end)
            end
            count = count + 1
        end
    end

    if count > 0 then
        local blocker = SpawnPrefab("fishschoolspawnblocker")
        if blocker ~= nil then
            blocker.Transform:SetPosition(spawnpoint:Get())
        end
        TheWorld:PushEvent("schoolspawned", { spawnpoint = spawnpoint })
    elseif herd:IsValid() then
        herd:Remove()
    end

    return count
end

local function CollectFishSpawnPoints(reader)
    local x, y, z = reader.Transform:GetWorldPosition()
    local center = Vector3(x, y, z)
    local amount = TUNING.BOOK_FISH_AMOUNT or 3
    local delta_theta = PI2 / 18
    local points = {}

    for i = 1, amount do
        local theta = math.random() * TWOPI
        local failed_attempts = 0
        while failed_attempts < MAX_FAILED_ATTEMPTS do
            local offset = FindSwimmableOffset(center, theta, FISH_SPAWN_OFFSET, 12, true, nil, nil, true)
            local spawnpoint = offset ~= nil and center + offset or Vector3(x + math.cos(theta) * FISH_SPAWN_OFFSET, 0, z + math.sin(theta) * FISH_SPAWN_OFFSET)
            if TheWorld.Map:IsOceanAtPoint(spawnpoint:Get()) and PickAnySeasonSchool(spawnpoint) ~= nil then
                table.insert(points, {
                    point = spawnpoint,
                    offset = Vector3(math.random(1, 3), 0, math.random(1, 3)),
                })
                break
            end
            theta = theta + delta_theta
            failed_attempts = failed_attempts + 1
        end
    end

    return points
end

local function PlayFishCallFx(reader)
    local x, y, z = reader.Transform:GetWorldPosition()
    local fx = SpawnPrefab("fx_book_fish")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
    local under = SpawnPrefab("fx_fish_under_book")
    if under ~= nil then
        under.Transform:SetPosition(x, y, z)
    end
end

function FishCall.Cast(reader)
    if reader == nil or not reader:IsValid() then
        return false
    end

    local points = CollectFishSpawnPoints(reader)
    if #points <= 0 then
        return false, "NOWATERNEARBY"
    end

    local spawned = 0
    for _, data in ipairs(points) do
        spawned = spawned + SpawnAnySeasonSchool(data.point, data.offset)
    end

    if spawned <= 0 then
        return false, "NOWATERNEARBY"
    end

    PlayFishCallFx(reader)
    return true
end

function FishCall.DoBuild(builder, recname, pt, rotation, skin)
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

    local points = CollectFishSpawnPoints(inst)
    if #points <= 0 then
        return false, "NOWATERNEARBY"
    end

    local is_buffered_build = builder.buffered_builds[recname] ~= nil
    if is_buffered_build then
        builder.buffered_builds[recname] = nil
        inst.replica.builder:SetIsBuildBuffered(recname, false)
    end

    inst:PushEvent("refreshcrafting")

    local spawned = 0
    for _, data in ipairs(points) do
        spawned = spawned + SpawnAnySeasonSchool(data.point, data.offset)
    end
    if spawned <= 0 then
        return false, "NOWATERNEARBY"
    end

    if not GrowthRecipes.TrySpendExperience(inst, EXPERIENCE_COST) then
        return false, "KEI_EXPERIENCE_NOT_FULL"
    end

    if not RecipeUnlocks.UnlockAfterBuild(inst, PROTOCOL, RECIPE) then
        return false, "KEI_PROTOCOL_CONSUME_FAILED"
    end

    PlayFishCallFx(inst)
    if inst.components.talker ~= nil and STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_FISH_CALL ~= nil then
        inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_FISH_CALL)
    end
    return true
end

function FishCall.Enable(slots, inst)
    AddRecipeToBuilder(inst)
end

function FishCall.Disable(slots, inst)
    RemoveRecipeFromBuilder(inst)
end

return FishCall
