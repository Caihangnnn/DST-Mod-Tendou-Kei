local GrowthRecipes = require("kei/growth_recipes")
local MiniAlice = require("kei/mini_alice")
local FISH_CALL_RECIPE = "kei_fish_call_spell"
local FULLMOON_RECIPE = "kei_fullmoon_spell"
local NEWMOON_RECIPE = "kei_newmoon_spell"
local RIPEN_RECIPE = "kei_ripen_spell"
local WEATHER_RECIPE = "kei_weather_spell"

AddComponentPostInit("builder", function(self)
    local old_HasCharacterIngredient = self.HasCharacterIngredient
    local old_RemoveIngredients = self.RemoveIngredients
    local old_DoBuild = self.DoBuild

    function self:HasCharacterIngredient(ingredient)
        if GrowthRecipes.IsExperienceIngredient(ingredient) then
            local amount = GrowthRecipes.GetExperienceIngredientAmount(ingredient, self.inst)
            ingredient.amount = amount
            return GrowthRecipes.HasEnoughExperienceIngredient(self.inst, ingredient), amount
        end
        return old_HasCharacterIngredient(self, ingredient)
    end

    function self:RemoveIngredients(ingredients, recname, discounted, ...)
        GrowthRecipes.ConsumeExperienceIngredients(self.inst, recname)
        return old_RemoveIngredients(self, ingredients, recname, discounted, ...)
    end

    function self:DoBuild(recname, pt, rotation, skin)
        if self.inst:HasTag("kei_dormant") then
            return false, "KEI_DORMANT"
        end

        if recname == FISH_CALL_RECIPE then
            return require("kei/protocols/life/effects/fish_call").DoBuild(self, recname, pt, rotation, skin)
        end

        if recname == FULLMOON_RECIPE then
            return require("kei/protocols/life/effects/fullmoon_recipe").DoBuild(self, recname, pt, rotation, skin)
        end

        if recname == NEWMOON_RECIPE then
            return require("kei/protocols/life/effects/newmoon_recipe").DoBuild(self, recname, pt, rotation, skin)
        end

        if recname == RIPEN_RECIPE then
            return require("kei/protocols/life/effects/ripen").DoBuild(self, recname, pt, rotation, skin)
        end

        if recname == WEATHER_RECIPE then
            return require("kei/protocols/life/effects/weather").DoBuild(self, recname, pt, rotation, skin)
        end
        if GrowthRecipes.IsGrowthRecipe(recname) then
            return GrowthRecipes.DoBuild(self, recname, pt, rotation, skin)
        end

        return old_DoBuild(self, recname, pt, rotation, skin)
    end

end)

AddClassPostConstruct("components/builder_replica", function(self)
    local old_HasCharacterIngredient = self.HasCharacterIngredient

    function self:HasCharacterIngredient(ingredient)
        if GrowthRecipes.IsExperienceIngredient(ingredient) then
            local amount = GrowthRecipes.GetExperienceIngredientAmount(ingredient, self.inst)
            ingredient.amount = amount
            return GrowthRecipes.HasEnoughExperienceIngredient(self.inst, ingredient), amount
        end
        return old_HasCharacterIngredient(self, ingredient)
    end

end)

-- 字符串、动作和配方分文件维护，避免入口文件继续膨胀。
local function IsProtectedVirtualEquipment(item)
    return item ~= nil
        and item:HasTag("kei_virtual_equipment")
        and not item.kei_allow_virtual_drop
        and item.components.equippable ~= nil
        and item.components.equippable:IsEquipped()
end

local function IsKeiVirtualHandEquipment(item)
    return item ~= nil and item:HasTag("kei_virtual_hand_equipment")
end

local function IsEquippedKeiHandItem(inventory, item)
    return inventory.inst ~= nil
        and inventory.inst:HasTag("kei")
        and item ~= nil
        and inventory.equipslots ~= nil
        and inventory.equipslots[EQUIPSLOTS.HANDS] == item
        and not item:HasTag("kei_virtual_equipment")
end

local function IsActivePlayerDrop(inventory, item)
    local buffered = inventory.inst ~= nil and inventory.inst.bufferedaction or nil
    return buffered ~= nil
        and buffered.action == ACTIONS.DROP
        and buffered.invobject == item
end

local function IsProjectileOrThrowableHandItem(item)
    if item == nil then
        return false
    end

    if item:HasTag("projectile")
        or item:HasTag("rangedweapon")
        or item:HasTag("blowdart")
        or item:HasTag("throwable")
    then
        return true
    end

    local components = item.components
    return components ~= nil
        and (components.complexprojectile ~= nil
            or components.throwable ~= nil
            or (components.weapon ~= nil and components.weapon.projectile ~= nil))
end

local function IsActiveHandItemUse(inventory, item)
    local buffered = inventory.inst ~= nil and inventory.inst.bufferedaction or nil
    if buffered == nil or buffered.action == nil or buffered.action == ACTIONS.DROP then
        return false
    end

    if buffered.invobject == item then
        return true
    end

    return buffered.action == ACTIONS.ATTACK
        and inventory.equipslots ~= nil
        and inventory.equipslots[EQUIPSLOTS.HANDS] == item
        and IsProjectileOrThrowableHandItem(item)
end

local function IsSpentEquipment(item)
    if item == nil or item.components == nil then
        return false
    end

    local finiteuses = item.components.finiteuses
    if finiteuses ~= nil and finiteuses.GetUses ~= nil and finiteuses:GetUses() <= 0 then
        return true
    end

    local fueled = item.components.fueled
    if fueled ~= nil and fueled.IsEmpty ~= nil and fueled:IsEmpty() then
        return true
    end

    local armor = item.components.armor
    if armor ~= nil and armor.GetPercent ~= nil and armor:GetPercent() <= 0 then
        return true
    end

    return false
end

local function IsCraftingContainer(container)
    return container ~= nil
        and container.excludefromcrafting ~= true
        and container.readonlycontainer ~= true
end

local function AddCraftingItems(target, container, item, amount, total, use_open_containers)
    if container == nil or total >= amount then
        return total
    end

    local found = container:GetCraftingIngredient(
        item,
        amount - total,
        use_open_containers
    )
    for found_item, count in pairs(found) do
        local accepted = math.min(count, amount - total)
        target[found_item] = accepted
        total = total + accepted
        if total >= amount then
            break
        end
    end

    return total
end

local function AddInventoryCraftingItems(target, inventory, item, amount, total)
    local candidates = {}
    for slot = 1, inventory.maxslots do
        local candidate = inventory:GetItemInSlot(slot)
        if candidate ~= nil
            and candidate.prefab == item
            and not candidate:HasTag("nocrafting")
        then
            table.insert(candidates, {
                item = candidate,
                stacksize = candidate.components.stackable
                    and candidate.components.stackable:StackSize()
                    or 1,
                slot = slot,
            })
        end
    end

    table.sort(candidates, function(a, b)
        if a.stacksize == b.stacksize then
            return a.slot < b.slot
        end
        return a.stacksize < b.stacksize
    end)

    for _, candidate in ipairs(candidates) do
        local count = math.min(candidate.stacksize, amount - total)
        target[candidate.item] = count
        total = total + count
        if total >= amount then
            break
        end
    end

    return total
end

local function GetOtherOpenCraftingContainers(inventory, overflow, alice)
    local containers = {}
    for container_inst in pairs(inventory.opencontainers) do
        local container = container_inst.components.container or container_inst.components.inventory
        if container ~= nil
            and container ~= overflow
            and container ~= alice
            and not MiniAlice.IsContainer(container)
            and IsCraftingContainer(container)
        then
            table.insert(containers, container)
        end
    end
    return containers
end

AddComponentPostInit("inventory", function(self)
    local old_DropItem = self.DropItem
    local old_RemoveItem = self.RemoveItem
    local old_Unequip = self.Unequip
    local old_Equip = self.Equip

    function self:GetCraftingIngredient(item, amount)
        local overflow = self:GetOverflowContainer()
        local alice = MiniAlice.GetOpenContainer(self.inst)
        local crafting_items = {}
        local total = 0

        -- Preserve the vanilla order for other opened containers.
        for _, container in ipairs(GetOtherOpenCraftingContainers(self, overflow, alice)) do
            total = AddCraftingItems(crafting_items, container, item, amount, total, true)
            if total >= amount then
                return crafting_items
            end
        end

        total = AddInventoryCraftingItems(crafting_items, self, item, amount, total)
        if total >= amount then
            return crafting_items
        end

        -- Mini Alice is deliberately between the player's inventory and the body backpack.
        total = AddCraftingItems(crafting_items, alice, item, amount, total, false)
        if total >= amount then
            return crafting_items
        end

        total = AddCraftingItems(crafting_items, overflow, item, amount, total, false)
        if total >= amount then
            return crafting_items
        end

        local activeitem = self.activeitem
        if activeitem ~= nil
            and activeitem.prefab == item
            and not activeitem:HasTag("nocrafting")
        then
            crafting_items[activeitem] = math.min(
                activeitem.components.stackable
                    and activeitem.components.stackable:StackSize()
                    or 1,
                amount - total
            )
        end

        return crafting_items
    end

    function self:Unequip(equipslot, slip, force)
        local item = self.equipslots ~= nil and self.equipslots[equipslot] or nil
        if IsKeiVirtualHandEquipment(item) then
            return nil
        end

        return old_Unequip(self, equipslot, slip, force)
    end

    function self:Equip(item, old_to_active, no_animation, force_ui_anim)
        if self.inst:HasTag("kei")
            and item ~= nil
            and item.components ~= nil
            and item.components.equippable ~= nil
            and item.components.equippable.equipslot == EQUIPSLOTS.HANDS
        then
            local current = self:GetEquippedItem(EQUIPSLOTS.HANDS)
            local protocolslots = self.inst.components ~= nil and self.inst.components.kei_protocolslots or nil
            if IsKeiVirtualHandEquipment(current) and protocolslots ~= nil then
                protocolslots._kei_suppress_hand_virtual = true
                protocolslots:RemoveHandVirtualEquip()
                local ok, result1, result2, result3 = pcall(old_Equip, self, item, old_to_active, no_animation, force_ui_anim)
                protocolslots._kei_suppress_hand_virtual = nil
                protocolslots:Refresh()
                if not ok then
                    error(result1)
                end
                return result1, result2, result3
            end
        end

        return old_Equip(self, item, old_to_active, no_animation, force_ui_anim)
    end

    function self:DropItem(item, wholestack, randomdir, pos, keepoverstacked)
        if self.inst:HasTag("kei_dormant") then
            return nil
        end

        if IsProtectedVirtualEquipment(item) then
            return nil
        end

        if IsEquippedKeiHandItem(self, item)
            and not IsActivePlayerDrop(self, item)
            and not IsActiveHandItemUse(self, item)
            and not IsSpentEquipment(item)
        then
            return nil
        end

        return old_DropItem(self, item, wholestack, randomdir, pos, keepoverstacked)
    end

    function self:RemoveItem(item, wholestack, checkallcontainers, keepoverstacked)
        if IsProtectedVirtualEquipment(item) then
            return nil
        end

        return old_RemoveItem(self, item, wholestack, checkallcontainers, keepoverstacked)
    end
end)
