local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")

AddComponentPostInit("builder", function(self)
    local old_DoBuild = self.DoBuild

    function self:DoBuild(recname, pt, rotation, skin)
        if self.inst:HasTag("kei_dormant") then
            return false, "KEI_DORMANT"
        end

        if not ProtocolSlotUnlocks.IsUnlockRecipe(recname) then
            return old_DoBuild(self, recname, pt, rotation, skin)
        end

        local recipe = GetValidRecipe(recname)
        local protocolslots = self.inst.components.kei_protocolslots
        if recipe == nil
            or protocolslots == nil
            or not self.inst:HasTag("kei")
            or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
        then
            return false
        end

        if not (self:IsBuildBuffered(recname) or self:HasIngredients(recipe)) then
            return false
        end

        if recipe.canbuild ~= nil then
            local success, msg = recipe.canbuild(recipe, self.inst, pt, rotation, self.current_prototyper, skin)
            if not success then
                return false, msg
            end
        end

        local can_unlock, reason = protocolslots:CanUseUnlockRecipe(recname)
        if not can_unlock then
            return false, reason
        end

        local is_buffered_build = self.buffered_builds[recname] ~= nil
        if is_buffered_build then
            self.buffered_builds[recname] = nil
            self.inst.replica.builder:SetIsBuildBuffered(recname, false)
        end

        self.inst:PushEvent("refreshcrafting")

        local materials, discounted = self:GetIngredients(recname)
        if self:CheckIngredientsForMimic(materials) or (discounted and self:CheckDiscountEquipsForMimic()) then
            return false, "ITEMMIMIC"
        end

        self:RemoveIngredients(materials, recname, discounted)

        local unlocked, unlock_reason = protocolslots:UnlockNextSlot(recname)
        if unlocked then
            if self.inst.components.talker ~= nil then
                self.inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_PROTOCOL_UNLOCK)
            end
            return true
        end

        return false, unlock_reason or "KEI_PROTOCOL_SLOTS_FULL"
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

AddComponentPostInit("inventory", function(self)
    local old_DropItem = self.DropItem
    local old_RemoveItem = self.RemoveItem
    local old_Unequip = self.Unequip
    local old_Equip = self.Equip

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
