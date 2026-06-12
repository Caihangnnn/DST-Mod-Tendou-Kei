local KeiProtocolSlots = Class(function(self, inst)
    self.inst = inst
    self.unlocked_slots = 1
    self.active = {}
    self.active_combat = {}
    self.virtual_equips = {}
    self.analysis_damage_bonus = 0

    self:SyncUnlockedSlots()

    inst:DoTaskInTime(0, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)

    self._scan_task = inst:DoPeriodicTask(1, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)

    self._drain_task = inst:DoPeriodicTask(TUNING.KEI_PROTOCOL_DRAIN_PERIOD, function()
        self:DrainProtocols()
    end)

    inst:ListenForEvent("onhitother", function(_, data)
        self:OnHitOther(data)
    end)

    inst:ListenForEvent("healthdelta", function()
        if self:IsDisabledByHealth() then
            self:DisableAllProtocols()
        end
    end)

    inst:ListenForEvent("death", function()
        self:DisableAllProtocols()
    end)

    inst:ListenForEvent("respawnfromghost", function()
        inst:DoTaskInTime(0, function()
            self:Refresh()
        end)
    end)
end)

local function IsProtocol(item)
    return item ~= nil and item:HasTag("kei_protocol_cd") and item.kei_protocol_data ~= nil
end

local function IsProtocolContainer(item)
    return item ~= nil and item.prefab == "kei_protocol_container"
end

local function HiddenEquipSlot(slot)
    return EQUIPSLOTS["KEI_PROTOCOL_" .. tostring(slot)]
end

local function ProtocolNeedsPower(data)
    return data.kind == "combat" or data.slot == "head" or data.slot == "body"
end

local function ProtocolNeedsStability(data)
    return data.slot == "hands"
end

local function GetAnalysisDamageBonus(data)
    if data.damage_bonus ~= nil then
        return data.damage_bonus
    end
    return data.damage_mult ~= nil and data.damage_mult > 1 and data.damage_mult * TUNING.UNARMED_DAMAGE or 0
end

local MOOSE_ELECTRIC_BUFF_NAME = "kei_moose_electricattack"

local function ReturnItemToOwner(owner, item)
    if owner ~= nil and owner.components.inventory ~= nil then
        if owner.components.inventory:GiveItem(item, nil, owner:GetPosition()) then
            return
        end
    end
    if owner ~= nil then
        item.Transform:SetPosition(owner.Transform:GetWorldPosition())
    end
end

local function GetMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_MAX or 7
end

local function GetHardMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_HARD_MAX or 7
end

local function GetInitialSlots()
    return TUNING.KEI_PROTOCOL_SLOT_INITIAL or 1
end

local function GetTierTargetSlots(tier)
    if tier == nil then
        return nil
    end
    return math.min(GetInitialSlots() + tier * (TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2), GetMaxSlots())
end

local function GetTierPreviousSlots(tier)
    if tier == nil then
        return nil
    end
    return math.min(GetInitialSlots() + (tier - 1) * (TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2), GetMaxSlots())
end

local function RemoveProtocolContainer(owner, inventory, container)
    if container.components.container ~= nil then
        local stored = container.components.container:GetItemInSlot(1)
        if stored ~= nil then
            stored = container.components.container:RemoveItem(stored, true)
            if stored ~= nil then
                ReturnItemToOwner(owner, stored)
            end
        end
    end
    if inventory ~= nil then
        inventory:RemoveItem(container, true)
    end
    if container:IsValid() then
        container:Remove()
    end
end

function KeiProtocolSlots:SyncUnlockedSlots()
    if self.inst._kei_unlocked_protocol_slots ~= nil then
        self.inst._kei_unlocked_protocol_slots:set(self.unlocked_slots)
    end
end

function KeiProtocolSlots:ConfigureProtocolContainer(container, slot)
    container:AddTag("kei_protocol_slot")
    container.kei_protocol_slot_index = slot

    if container.components.inventoryitem ~= nil then
        container.components.inventoryitem.islockedinslot = true
        container.components.inventoryitem.canbepickedup = false
        container.components.inventoryitem.keepondeath = true
    end

    if container.components.container ~= nil then
        local stored = container.components.container:GetItemInSlot(1)
        if stored ~= nil and not IsProtocol(stored) then
            stored = container.components.container:RemoveItem(stored, true)
            if stored ~= nil then
                ReturnItemToOwner(self.inst, stored)
            end
        end
        stored = container.components.container:GetItemInSlot(1)
        if stored ~= nil and stored.components.inventoryitem ~= nil then
            stored.components.inventoryitem.keepondeath = true
        end
        if container.SetPowered ~= nil then
            container:SetPowered(slot <= self.unlocked_slots and self:IsFunctional())
        else
            container.components.container.canbeopened = slot <= self.unlocked_slots and self:IsFunctional()
        end
    end
end

function KeiProtocolSlots:EnsureProtocolContainers()
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return
    end

    local max_slots = GetMaxSlots()
    self.unlocked_slots = math.clamp(self.unlocked_slots, GetInitialSlots(), max_slots)
    self:SyncUnlockedSlots()

    for slot = 1, max_slots do
        local current = inventory:GetItemInSlot(slot)

        if IsProtocolContainer(current) then
            self:ConfigureProtocolContainer(current, slot)
        else
            local displaced = current ~= nil and inventory:RemoveItem(current, true) or nil
            local container = SpawnPrefab("kei_protocol_container")
            if container ~= nil then
                self:ConfigureProtocolContainer(container, slot)
                inventory:GiveItem(container, slot)

                if displaced ~= nil then
                    if IsProtocol(displaced)
                        and slot <= self.unlocked_slots
                        and container.components.container ~= nil
                        and container.components.container:GetItemInSlot(1) == nil
                    then
                        container.components.container:GiveItem(displaced, 1)
                    else
                        ReturnItemToOwner(self.inst, displaced)
                    end
                end
            elseif displaced ~= nil then
                ReturnItemToOwner(self.inst, displaced)
            end
        end
    end

    for slot = max_slots + 1, GetHardMaxSlots() do
        local current = inventory:GetItemInSlot(slot)
        if IsProtocolContainer(current) then
            RemoveProtocolContainer(self.inst, inventory, current)
        end
    end
end

function KeiProtocolSlots:OnRemoveFromEntity()
    self:ClearModifiers()
end

function KeiProtocolSlots:CanUnlockTier(tier)
    local target_slots = GetTierTargetSlots(tier)
    local previous_slots = GetTierPreviousSlots(tier)
    return target_slots ~= nil and previous_slots ~= nil
        and target_slots > self.unlocked_slots
        and self.unlocked_slots == previous_slots
end

function KeiProtocolSlots:UnlockTier(tier)
    if not self:CanUnlockTier(tier) then
        self:SyncUnlockedSlots()
        return false
    end
    self.unlocked_slots = GetTierTargetSlots(tier)
    self:SyncUnlockedSlots()
    self:EnsureProtocolContainers()
    self:Refresh()
    return true
end

function KeiProtocolSlots:IsDisabledByHealth()
    local health = self.inst.components.health
    return self.inst:HasTag("playerghost")
        or (health ~= nil and (health:IsDead() or health.currenthealth <= 0))
end

function KeiProtocolSlots:IsFunctional()
    return not self:IsDisabledByHealth()
end

function KeiProtocolSlots:SetProtocolContainersPowered(powered)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return
    end

    for slot = 1, GetMaxSlots() do
        local container = inventory:GetItemInSlot(slot)
        if IsProtocolContainer(container) and container.components.container ~= nil then
            local enabled = powered and slot <= self.unlocked_slots
            if container.SetPowered ~= nil then
                container:SetPowered(enabled)
            else
                container.components.container.canbeopened = enabled
                if not enabled and container.components.container:IsOpen() then
                    container.components.container:Close()
                end
            end
        end
    end
end

function KeiProtocolSlots:CanRun(data)
    if not self:IsFunctional() then
        return false
    end
    if ProtocolNeedsPower(data) and self.inst.components.hunger ~= nil and self.inst.components.hunger.current <= 0 then
        return false
    end
    if ProtocolNeedsStability(data) and self.inst.components.sanity ~= nil and self.inst.components.sanity.current <= 0 then
        return false
    end
    return true
end

function KeiProtocolSlots:GetProtocolSlotItems()
    local items = {}
    if not self:IsFunctional() then
        return items
    end
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return items
    end

    for slot = 1, GetMaxSlots() do
        local container = inventory:GetItemInSlot(slot)
        if IsProtocolContainer(container) and container.components.container ~= nil then
            local item = container.components.container:GetItemInSlot(1)
            if IsProtocol(item) and slot <= self.unlocked_slots and self:CanRun(item.kei_protocol_data) then
                table.insert(items, {
                    item = item,
                    slot = slot,
                    data = item.kei_protocol_data,
                })
            end
        end
    end

    return items
end

local function CleanVirtualEquipment(item, equipslot)
    item.persists = false
    item:AddTag("kei_virtual_equipment")
    item:AddTag("NOCLICK")
    item:RemoveTag("heavy")

    if item.components.equippable ~= nil then
        item.components.equippable.restrictedtag = nil
        item.components.equippable.equipslot = equipslot
        item.components.equippable:SetPreventUnequipping(true)
    end

    if item.components.container ~= nil then
        item:RemoveComponent("container")
    end

    if item.components.inventoryitem ~= nil then
        item.components.inventoryitem.canbepickedup = false
        item.components.inventoryitem.cangoincontainer = false
    end

    if item.components.fueled ~= nil then
        item.components.fueled:StopConsuming()
    end

    if item.components.perishable ~= nil then
        item:RemoveComponent("perishable")
    end
end

function KeiProtocolSlots:RemoveVirtualEquip(slot)
    local virtual = self.virtual_equips[slot]
    if virtual == nil then
        return
    end

    local equipslot = HiddenEquipSlot(slot)
    local inventory = self.inst.components.inventory
    if inventory ~= nil and equipslot ~= nil and inventory:GetEquippedItem(equipslot) == virtual then
        virtual.kei_allow_virtual_drop = true
        inventory:Unequip(equipslot, true, true)
    end

    if virtual:IsValid() then
        virtual:Remove()
    end
    self.virtual_equips[slot] = nil
end

function KeiProtocolSlots:ApplyVirtualEquip(entry)
    local data = entry.data
    local slot = entry.slot
    local equipslot = HiddenEquipSlot(slot)
    local inventory = self.inst.components.inventory

    if data.source == nil or equipslot == nil or inventory == nil then
        self:RemoveVirtualEquip(slot)
        return
    end

    local current = self.virtual_equips[slot]
    if current ~= nil
        and current:IsValid()
        and current.kei_source_prefab == data.source
        and inventory:GetEquippedItem(equipslot) == current
    then
        return
    end

    self:RemoveVirtualEquip(slot)

    local virtual = SpawnPrefab(data.source)
    if virtual == nil or virtual.components.equippable == nil then
        if virtual ~= nil then
            virtual:Remove()
        end
        return
    end

    virtual.kei_source_prefab = data.source
    CleanVirtualEquipment(virtual, equipslot)

    inventory:Equip(virtual, nil, true)
    if inventory:GetEquippedItem(equipslot) == virtual then
        self.virtual_equips[slot] = virtual
    else
        virtual:Remove()
    end
end

function KeiProtocolSlots:ClearVirtualEquips(keep)
    for slot in pairs(self.virtual_equips) do
        if keep == nil or not keep[slot] then
            self:RemoveVirtualEquip(slot)
        end
    end
end

function KeiProtocolSlots:ClearModifiers()
    self:ClearVirtualEquips()
    self:SetAnalysisDamageBonus(0)

    self.inst:RemoveTag("kei_nofreezing")
    self.inst:RemoveTag("kei_nooverheat")
    self:DisableFreezeImmunity()
    self:DisableMooseProtocol()

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, "kei_analysis_armor")
        self.inst.components.health.externalfiredamagemultipliers:RemoveModifier(self.inst)
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "kei_analysis_hands")
    end
end

function KeiProtocolSlots:SetAnalysisDamageBonus(amount)
    local combat = self.inst.components.combat
    local old = self.analysis_damage_bonus or 0
    amount = amount or 0

    if combat ~= nil then
        if old ~= 0 then
            combat.damagebonus = (combat.damagebonus or 0) - old
        end
        if amount ~= 0 then
            combat.damagebonus = (combat.damagebonus or 0) + amount
        end
    end

    self.analysis_damage_bonus = amount
end

function KeiProtocolSlots:DisableAllProtocols()
    self.active = {}
    self.active_combat = {}
    self:SyncCombatProtocolFlags()
    self:SetProtocolContainersPowered(false)
    self:ClearModifiers()
end

local function FreezeImmuneRedirect()
    return true
end

function KeiProtocolSlots:EnableFreezeImmunity()
    local freezable = self.inst.components.freezable
    if freezable == nil or self._kei_freeze_immune then
        return
    end

    self._kei_old_freeze_redirectfn = freezable.redirectfn
    freezable:SetRedirectFn(FreezeImmuneRedirect)
    if freezable:IsFrozen() then
        freezable:Unfreeze()
    end
    freezable.coldness = 0
    freezable:UpdateTint()
    self._kei_freeze_immune = true
end

function KeiProtocolSlots:DisableFreezeImmunity()
    local freezable = self.inst.components.freezable
    if freezable == nil or not self._kei_freeze_immune then
        return
    end

    freezable:SetRedirectFn(self._kei_old_freeze_redirectfn)
    self._kei_old_freeze_redirectfn = nil
    self._kei_freeze_immune = nil
end

function KeiProtocolSlots:RefreshTemperatureProtocols()
    if self.active_combat.deerclops then
        self.inst:AddTag("kei_nofreezing")
        self:EnableFreezeImmunity()
        if self.inst.components.temperature ~= nil
            and self.inst.components.temperature:GetCurrent() < TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE
        then
            self.inst.components.temperature:SetTemperature(TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE)
        end
    else
        self.inst:RemoveTag("kei_nofreezing")
        self:DisableFreezeImmunity()
    end

    if self.active_combat.dragonfly then
        self.inst:AddTag("kei_nooverheat")
        if self.inst.components.temperature ~= nil
            and self.inst.components.temperature:GetCurrent() > TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE
        then
            self.inst.components.temperature:SetTemperature(TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        end
        if self.inst.components.health ~= nil then
            self.inst.components.health.externalfiredamagemultipliers:SetModifier(self.inst, 0)
        end
    else
        self.inst:RemoveTag("kei_nooverheat")
        if self.inst.components.health ~= nil then
            self.inst.components.health.externalfiredamagemultipliers:RemoveModifier(self.inst)
        end
    end
end

function KeiProtocolSlots:EnableMooseProtocol()
    if not self.inst:HasDebuff(MOOSE_ELECTRIC_BUFF_NAME) then
        self.inst:AddDebuff(MOOSE_ELECTRIC_BUFF_NAME, "buff_electricattack")
    end

    if not self.inst:HasTag("wet") then
        if self.inst.components.moistureimmunity == nil then
            self.inst:AddComponent("moistureimmunity")
        end
        self.inst.components.moistureimmunity:AddSource(self.inst)
    end
end

function KeiProtocolSlots:DisableMooseProtocol()
    self.inst:RemoveDebuff(MOOSE_ELECTRIC_BUFF_NAME)

    if self.inst.components.moistureimmunity ~= nil then
        self.inst.components.moistureimmunity:RemoveSource(self.inst)
    end
end

function KeiProtocolSlots:RefreshMooseProtocol()
    if self.active_combat.moose then
        self:EnableMooseProtocol()
    else
        self:DisableMooseProtocol()
    end
end

function KeiProtocolSlots:HasCombatProtocol(protocol)
    return self:IsFunctional() and self.active_combat[protocol] == true
end

function KeiProtocolSlots:SyncCombatProtocolFlags()
    if self.inst._kei_eyeofterror_protocol_active ~= nil then
        self.inst._kei_eyeofterror_protocol_active:set(self:HasCombatProtocol("eyeofterror"))
    end
end

function KeiProtocolSlots:Refresh()
    if not self:IsFunctional() then
        self:DisableAllProtocols()
        return
    end
    self:SetProtocolContainersPowered(true)

    local items = self:GetProtocolSlotItems()
    local combat = {}
    local damage_bonus = 0
    local speed_mult = 1
    local planar_bonus = 0
    local desired_virtuals = {}

    self.active = items

    for _, entry in ipairs(items) do
        local data = entry.data
        if data.kind == "combat" and data.protocol ~= nil then
            combat[data.protocol] = true
        elseif data.kind == "analysis" then
            if data.slot == "head" or data.slot == "body" then
                desired_virtuals[entry.slot] = true
                self:ApplyVirtualEquip(entry)
            elseif data.slot == "hands" then
                damage_bonus = damage_bonus + GetAnalysisDamageBonus(data)
                speed_mult = speed_mult * (data.speed_mult or 1)
                planar_bonus = planar_bonus + (data.planar_bonus or 0)
            end
        end
    end

    self:ClearVirtualEquips(desired_virtuals)
    self.active_combat = combat
    self:RefreshTemperatureProtocols()
    self:RefreshMooseProtocol()
    self:SyncCombatProtocolFlags()

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, "kei_analysis_armor")
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "kei_analysis_hands")
        self:SetAnalysisDamageBonus(damage_bonus)
    end
    if planar_bonus > 0 then
        if self.inst.components.planardamage == nil then
            self.inst:AddComponent("planardamage")
        end
        self.inst.components.planardamage:AddBonus(self.inst, planar_bonus, "kei_analysis_hands")
    elseif self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "kei_analysis_hands", speed_mult)
    end
end

function KeiProtocolSlots:DrainProtocols()
    if not self:IsFunctional() then
        self:DisableAllProtocols()
        return
    end

    local power_cost = 0
    local stability_cost = 0

    for _, entry in ipairs(self.active) do
        local data = entry.data
        if ProtocolNeedsPower(data) then
            power_cost = power_cost + TUNING.KEI_PROTOCOL_DRAIN_AMOUNT
        elseif ProtocolNeedsStability(data) then
            stability_cost = stability_cost + TUNING.KEI_PROTOCOL_DRAIN_AMOUNT
        end
    end

    if power_cost > 0 and self.inst.components.hunger ~= nil then
        self.inst.components.hunger:DoDelta(-power_cost)
    end
    if stability_cost > 0 and self.inst.components.sanity ~= nil then
        self.inst.components.sanity:DoDelta(-stability_cost)
    end

    self:Refresh()
end

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }

function KeiProtocolSlots:DoBeargerPulse(target, weapon)
    if self._doing_aoe or target == nil or target.components.combat == nil then
        return
    end
    self._doing_aoe = true
    local x, y, z = target.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 3, AREA_MUST_TAGS, AREA_EXCLUDE_TAGS)
    for _, ent in ipairs(ents) do
        if ent ~= target
            and ent ~= self.inst
            and ent.components.combat ~= nil
            and self.inst.components.combat ~= nil
            and self.inst.components.combat:IsValidTarget(ent)
        then
            local damage = self.inst.components.combat:CalcDamage(ent, weapon, 0.35)
            ent.components.combat:GetAttacked(self.inst, damage, weapon)
        end
    end
    self._doing_aoe = false
end

function KeiProtocolSlots:OnHitOther(data)
    if not self:IsFunctional() then
        return
    end

    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() then
        return
    end

    if self.active_combat.deerclops and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(1)
        target.components.freezable:SpawnShatterFX()
    end

    if self.active_combat.dragonfly and target.components.burnable ~= nil and not target.components.burnable:IsBurning() then
        local had_tag = self.inst:HasTag("controlled_burner")
        if not had_tag then
            self.inst:AddTag("controlled_burner")
        end
        target.components.burnable:Ignite(nil, self.inst, self.inst)
        if not had_tag then
            self.inst:RemoveTag("controlled_burner")
        end
    end

    if self.active_combat.bearger then
        self:DoBeargerPulse(target, data.weapon)
    end
end

function KeiProtocolSlots:OnSave()
    return {
        unlocked_slots = self.unlocked_slots,
    }
end

function KeiProtocolSlots:OnLoad(data)
    if data ~= nil and data.unlocked_slots ~= nil then
        self.unlocked_slots = math.clamp(data.unlocked_slots, GetInitialSlots(), GetMaxSlots())
    end
    self:SyncUnlockedSlots()
    self.inst:DoTaskInTime(0, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)
end

return KeiProtocolSlots
