local VirtualHandEquipment = {}

local function CleanVirtualEquipment(item)
    item.persists = false
    item:AddTag("kei_virtual_equipment")
    item:AddTag("NOCLICK")
    item:RemoveTag("heavy")
    item:RemoveTag("repairable")

    if item.components.equippable ~= nil then
        item.components.equippable.restrictedtag = nil
        item.components.equippable.equipslot = EQUIPSLOTS.HANDS
        item.components.equippable:SetPreventUnequipping(false)
    end

    if item.components.container ~= nil then
        item:RemoveComponent("container")
    end

    if item.components.inventoryitem ~= nil then
        item.components.inventoryitem.canbepickedup = false
        item.components.inventoryitem.cangoincontainer = false
        item.components.inventoryitem.keepondeath = true
    end

    if item.components.trader ~= nil then
        item:RemoveComponent("trader")
    end

    if item.components.repairable ~= nil then
        item:RemoveComponent("repairable")
    end

    if item.components.finiteuses ~= nil then
        item:RemoveComponent("finiteuses")
    end

    if item.components.fueled ~= nil then
        item:RemoveComponent("fueled")
    end

    if item.components.perishable ~= nil then
        item:RemoveComponent("perishable")
    end
end

local function ClearVirtualInventoryOwner(item)
    local inventoryitem = item.components.inventoryitem
    if inventoryitem == nil then return end

    local owner = inventoryitem.owner
    if owner ~= nil then
        owner:RemoveChild(item)
    end
    inventoryitem:ClearOwner()
end

local function ScheduleVirtualEquipmentRemove(item)
    if item == nil or not item:IsValid() or item.kei_pending_virtual_remove then return end

    item.kei_pending_virtual_remove = true
    item.persists = false
    item:Hide()
    item:DoTaskInTime(0.1, function(inst)
        if inst:IsValid() then
            inst:Remove()
        end
    end)
end

local function IgnoreVirtualHandCallbackError(item, err)
    local owner = item.components.inventoryitem ~= nil and item.components.inventoryitem.owner or nil
    if owner ~= nil and owner:HasTag("kei") and item:HasTag("kei_virtual_hand_equipment") then
        print("[Tendou Kei] ignored virtual hand equipment callback error: " .. tostring(err))
        return true
    end
    return false
end

local function WrapVirtualHandEquipment(item)
    local weapon = item.components.weapon
    if weapon ~= nil and weapon.GetDamage ~= nil and not weapon.kei_virtual_hand_safe_getdamage then
        local old_getdamage = weapon.GetDamage
        weapon.GetDamage = function(self, attacker, target)
            local ok, damage, spdamage = pcall(old_getdamage, self, attacker, target)
            if ok then
                return damage, spdamage
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon damage error: " .. tostring(damage))
                return self.damage or 0
            end
            error(damage)
        end
        weapon.kei_virtual_hand_safe_getdamage = true
    end

    if weapon ~= nil and weapon.onattack ~= nil and not weapon.kei_virtual_hand_safe_onattack then
        local old_onattack = weapon.onattack
        weapon.onattack = function(inst, attacker, target, projectile)
            local ok, result1, result2, result3 = pcall(old_onattack, inst, attacker, target, projectile)
            if ok then
                return result1, result2, result3
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon onattack error: " .. tostring(result1))
                return nil
            end
            error(result1)
        end
        weapon.kei_virtual_hand_safe_onattack = true
    end

    if weapon ~= nil and weapon.onprojectilelaunched ~= nil and not weapon.kei_virtual_hand_safe_onprojectilelaunched then
        local old_onprojectilelaunched = weapon.onprojectilelaunched
        weapon.onprojectilelaunched = function(inst, attacker, target, projectile)
            local ok, result1, result2, result3 = pcall(old_onprojectilelaunched, inst, attacker, target, projectile)
            if ok then
                return result1, result2, result3
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon projectile error: " .. tostring(result1))
                return nil
            end
            error(result1)
        end
        weapon.kei_virtual_hand_safe_onprojectilelaunched = true
    end

    local spellcaster = item.components.spellcaster
    if spellcaster ~= nil and spellcaster.spell ~= nil and not spellcaster.kei_virtual_hand_safe_spell then
        local old_spell = spellcaster.spell
        spellcaster.spell = function(spellcaster_self, caster, target, pos)
            local ok, result1, result2, result3 = pcall(old_spell, spellcaster_self, caster, target, pos)
            if ok then
                return result1, result2, result3
            end
            if IgnoreVirtualHandCallbackError(item, result1) then
                return nil
            end
            error(result1)
        end
        spellcaster.kei_virtual_hand_safe_spell = true
    end
end

function VirtualHandEquipment.Remove(protocolslots)
    local virtual = protocolslots.virtual_hand_equip
    if virtual == nil then return end

    protocolslots.virtual_hand_equip = nil

    local inventory = protocolslots.inst.components.inventory
    if inventory ~= nil and inventory.equipslots ~= nil and inventory.equipslots[EQUIPSLOTS.HANDS] == virtual then
        inventory.equipslots[EQUIPSLOTS.HANDS] = nil
        inventory.floaterheld = nil

        ClearVirtualInventoryOwner(virtual)
        protocolslots.inst:PushEvent("unequip", { item = virtual, eslot = EQUIPSLOTS.HANDS, no_animation = true, kei_virtual_silent = true })
    end

    if virtual:IsValid() then
        ScheduleVirtualEquipmentRemove(virtual)
    end
end

function VirtualHandEquipment.Apply(protocolslots, entry)
    local data = entry.data
    local inventory = protocolslots.inst.components.inventory
    if data.source == nil or inventory == nil then
        VirtualHandEquipment.Remove(protocolslots)
        return false
    end

    local hand_item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if hand_item ~= nil and hand_item ~= protocolslots.virtual_hand_equip then
        VirtualHandEquipment.Remove(protocolslots)
        return false
    end

    local current = protocolslots.virtual_hand_equip
    if current ~= nil
        and current:IsValid()
        and current.kei_source_prefab == data.source
        and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == current
    then
        return true
    end

    local was_suppressing = protocolslots._kei_suppress_hand_virtual
    protocolslots._kei_suppress_hand_virtual = true
    VirtualHandEquipment.Remove(protocolslots)
    protocolslots._kei_suppress_hand_virtual = was_suppressing

    local virtual = SpawnPrefab(data.source, data.skin_name)
    if virtual == nil or virtual.components.equippable == nil then
        if virtual ~= nil then virtual:Remove() end
        return false
    end

    virtual.kei_source_prefab = data.source
    virtual:AddTag("kei_virtual_hand_equipment")
    CleanVirtualEquipment(virtual)
    WrapVirtualHandEquipment(virtual)

    inventory:Equip(virtual, nil, true)
    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == virtual then
        protocolslots.virtual_hand_equip = virtual
        return true
    end

    ScheduleVirtualEquipmentRemove(virtual)
    return false
end

return VirtualHandEquipment