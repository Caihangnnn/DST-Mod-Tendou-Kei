local KEI_DEPLOYABLE_ITEMS = {
    winona_catapult_item = "winona_catapult",
    winona_spotlight_item = "winona_spotlight",
    winona_battery_low_item = "winona_battery_low",
    winona_battery_high_item = "winona_battery_high",
    winona_storage_robot = "winona_storage_robot",
}

local KEI_WINONA_MACHINES = {
    winona_catapult = true,
    winona_spotlight = true,
    winona_battery_low = true,
    winona_battery_high = true,
    winona_storage_robot = true,
    winona_remote = true,
    winona_catapult_item = true,
    winona_spotlight_item = true,
    winona_battery_low_item = true,
    winona_battery_high_item = true,
}

local KEI_BATTERIES = {
    winona_battery_low = true,
    winona_battery_high = true,
}

local LOW_BATTERY_PREFABS = {
    winona_battery_low = true,
    winona_battery_low_item = true,
}

local function IsKei(inst)
    return inst ~= nil and inst:HasTag("kei")
end

local function IsEngineerOrKei(inst)
    return inst ~= nil and (inst:HasTag("handyperson") or inst:HasTag("kei"))
end

local function IsKeiShadowFuel(item)
    return item ~= nil and (item.prefab == "nightmarefuel" or item.prefab == "horrorfuel")
end

local function IsKeiLunarBatteryFuel(item)
    return item ~= nil and (item.prefab == "alterguardianhatshard" or item.prefab == "purebrilliance")
end

local function MarkKeiWinonaMachine(inst)
    if inst == nil or not KEI_WINONA_MACHINES[inst.prefab] then
        return
    end

    inst.kei_winona_made_by_kei = true

    if KEI_BATTERIES[inst.prefab] then
        inst._noidledrain = true
        inst:PushEvent("engineeringcircuitchanged")
    elseif inst.components ~= nil and inst.components.powerload ~= nil then
        inst.kei_winona_no_idle_drain = true
        inst:PushEvent("engineeringcircuitchanged")
    end
end

local function AllowKeiDeployableItem(inst)
    if inst == nil
        or inst.components == nil
        or inst.components.deployable == nil
        or KEI_DEPLOYABLE_ITEMS[inst.prefab] == nil
    then
        return
    end

    inst.components.deployable.restrictedtag = nil
end

local function FindNearbyMachine(prefab, pt)
    if prefab == nil or pt == nil then
        return nil
    end

    local ents = TheSim:FindEntities(pt.x, 0, pt.z, 1.5, nil, { "INLIMBO" })
    for _, ent in ipairs(ents) do
        if ent.prefab == prefab then
            return ent
        end
    end
end

local function PatchSaveLoad(inst)
    if inst.kei_winona_save_load_patched then
        return
    end
    inst.kei_winona_save_load_patched = true

    local old_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        if old_OnSave ~= nil then
            old_OnSave(inst, data)
        end
        if inst.kei_winona_made_by_kei then
            data.kei_winona_made_by_kei = true
        end
    end

    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data, ...)
        if old_OnLoad ~= nil then
            old_OnLoad(inst, data, ...)
        end
        if data ~= nil and data.kei_winona_made_by_kei then
            MarkKeiWinonaMachine(inst)
        end
    end
end

local function PatchLowBatteryFuel(inst)
    if not TheWorld.ismastersim
        or inst.components == nil
        or inst.components.fueled == nil
        or inst.kei_shadow_fuel_patched
    then
        return
    end
    inst.kei_shadow_fuel_patched = true

    local fueled = inst.components.fueled
    local old_can_take = fueled.cantakefuelitemfn
    fueled:SetCanTakeFuelItemFn(function(inst, item, doer)
        if IsKei(doer) and IsKeiShadowFuel(item) then
            return true
        end
        return old_can_take == nil or old_can_take(inst, item, doer)
    end)
end

local function PatchHighBatteryTrader(inst)
    if not TheWorld.ismastersim
        or inst.components == nil
        or inst.components.trader == nil
        or inst.kei_lunar_fuel_patched
    then
        return
    end
    inst.kei_lunar_fuel_patched = true

    local trader = inst.components.trader
    local old_able_to_accept = trader.abletoaccepttest
    trader:SetAbleToAcceptTest(function(inst, item, giver, count)
        if IsKei(giver) and IsKeiLunarBatteryFuel(item) then
            return true
        end
        if old_able_to_accept ~= nil then
            return old_able_to_accept(inst, item, giver, count)
        end
        return true
    end)
end

AddComponentPostInit("deployable", function(self)
    local target_prefab = KEI_DEPLOYABLE_ITEMS[self.inst.prefab]
    if target_prefab == nil or self.kei_deployable_patched then
        return
    end
    self.kei_deployable_patched = true

    self.restrictedtag = nil

    function self:IsDeployable(deployer)
        if not IsEngineerOrKei(deployer) then
            return false
        elseif deployer.components ~= nil then
            if deployer.components.rider ~= nil and deployer.components.rider:IsRiding() then
                return self.inst.components.complexprojectile ~= nil
            elseif deployer.components.inventory ~= nil and deployer.components.inventory:IsFloaterHeld() then
                return self.inst:HasTag("boatbuilder")
            end
        elseif deployer.replica ~= nil then
            local rider = deployer.replica.rider
            if rider ~= nil and rider:IsRiding() then
                return self.inst:HasTag("complexprojectile")
            end
            local inventory = deployer.replica.inventory
            if inventory ~= nil and inventory:IsFloaterHeld() then
                return self.inst:HasTag("boatbuilder")
            end
        end
        return true
    end

    local old_ondeploy = self.ondeploy
    self.ondeploy = function(inst, pt, deployer, rot)
        local made_by_kei = IsKei(deployer) or inst.kei_winona_made_by_kei
        if old_ondeploy ~= nil then
            old_ondeploy(inst, pt, deployer, rot)
        end
        if made_by_kei then
            if inst:IsValid() and inst.prefab == target_prefab then
                MarkKeiWinonaMachine(inst)
            else
                MarkKeiWinonaMachine(FindNearbyMachine(target_prefab, pt))
            end
        end
    end

    self.inst:DoTaskInTime(0, AllowKeiDeployableItem)
end)

AddComponentPostInit("powerload", function(self)
    local old_GetLoad = self.GetLoad
    function self:GetLoad()
        if self.inst.kei_winona_no_idle_drain and self:IsIdle() then
            return 0
        end
        return old_GetLoad(self)
    end
end)

AddComponentPostInit("spellbook", function(self)
    if self.inst.prefab ~= "winona_remote" or self.kei_spellbook_patched then
        return
    end
    self.kei_spellbook_patched = true

    local old_canusefn = self.canusefn
    self:SetRequiredTag(nil)
    self:SetCanUseFn(function(inst, user)
        return IsEngineerOrKei(user) and (old_canusefn == nil or old_canusefn(inst, user))
    end)
end)

for prefab in pairs(KEI_WINONA_MACHINES) do
    AddPrefabPostInit(prefab, function(inst)
        PatchSaveLoad(inst)
        AllowKeiDeployableItem(inst)
        inst:DoTaskInTime(0, AllowKeiDeployableItem)

        inst:ListenForEvent("onbuilt", function(inst, data)
            if data ~= nil and IsKei(data.builder) then
                inst:DoTaskInTime(0, MarkKeiWinonaMachine)
            end
        end)

        if LOW_BATTERY_PREFABS[prefab] then
            PatchLowBatteryFuel(inst)
        elseif prefab == "winona_battery_high" then
            PatchHighBatteryTrader(inst)
        end
    end)
end
