local WortoxSoulCommon = require("prefabs/wortox_soul_common")
local LifeProtocolDefs = require("kei_life_protocol_defs")

local LIFE_PROTOCOLS = LifeProtocolDefs.LIFE_PROTOCOLS

local MUTATEDDEERCLOPS_AURA_SLOW_KEY = "kei_mutateddeerclops_aura"
local MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG = "kei_mutateddeerclops_sg_slow"
local MUTATEDDEERCLOPS_AURA_FOLLOW_PERIOD = FRAMES
local MUTATEDDEERCLOPS_AURA_UPDATE_PERIOD = 0.25
local MUTATEDDEERCLOPS_AURA_MUST_TAGS = { "_combat", "_health" }
local MUTATEDDEERCLOPS_AURA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local WAGBOSS_PROTOCOL_COOLDOWN = 20
local CELESTIAL_ORB_FOLLOW_PERIOD = FRAMES
local CELESTIAL_ORB_TARGET_MUST_TAGS = { "_combat", "_health" }
local CELESTIAL_ORB_TARGET_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost", "companion" }
local DAYWALKER2_SHIELD_FOLLOW_PERIOD = FRAMES
local WAGBOSS_TARGET_FOLLOW_PERIOD = FRAMES
local DRAGONFLY_BURN_COLOUR = { 242 / 255, 144 / 255, 186 / 255, 1 }
local DRAGONFLY_BURN_DURATION = 30
local DRAGONFLY_BURN_DAMAGE_PERIOD = 1
local DRAGONFLY_BURN_MAX_HEALTH_DAMAGE = 0.001
local GROWTH_TIMER_PREFAB_WHITELIST = {
    rock_avocado_fruit_sprout_sapling = true,
}

local KeiProtocolSlots = Class(function(self, inst)
    self.inst = inst
    self.unlocked_slots = 1
    self.active = {}
    self.active_combat = {}
    self.active_life = {}
    self.virtual_equips = {}
    self.analysis_damage_bonus = 0
    self.analysis_tool_actions = {}
    self._kei_worker_action_old_values = {}
    self._kei_tool_action_old_tags = {}
    self._kei_mutateddeerclops_slowed = {}
    self._kei_celestial_orbs = {}
    self._kei_celestial_orb_angles = {}
    self._kei_celestial_orb_hit_times = setmetatable({}, { __mode = "k" })
    self._kei_daywalker2_shield_fx = nil
    self._kei_daywalker2_shield_follow_task = nil
    self._kei_wagboss_target_fx = nil
    self._kei_wagboss_target_follow_task = nil
    self._kei_wagboss_target_ready_task = nil

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

    self._life_growth_task = inst:DoPeriodicTask(TUNING.KEI_LIFE_GROWTH_ACCELERATION_PERIOD or 1, function()
        self:ApplyLifeGrowthAcceleration()
    end)

    self._life_durability_task = inst:DoPeriodicTask(TUNING.KEI_LIFE_DURABILITY_RESTORE_PERIOD or 60, function()
        self:ApplyLifeDurabilityRestore()
    end)

    inst:ListenForEvent("onhitother", function(_, data)
        self:OnHitOther(data)
    end)

    inst:ListenForEvent("attacked", function(_, data)
        self:OnAttacked(data)
    end)

    inst:ListenForEvent("equip", function(_, data)
        if data ~= nil and data.eslot == EQUIPSLOTS.HANDS then
            self:Refresh()
        end
    end)

    inst:ListenForEvent("unequip", function(_, data)
        if data ~= nil and data.eslot == EQUIPSLOTS.HANDS then
            self:Refresh()
        end
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
    return data.kind == "analysis"
end

local function ProtocolNeedsStability(data)
    return data.kind == "combat"
end

local function GetAnalysisDamageBonus(data)
    if data.damage_bonus ~= nil then
        return data.damage_bonus
    end
    return data.damage_mult ~= nil and data.damage_mult > 1 and data.damage_mult * TUNING.UNARMED_DAMAGE or 0
end

local function HasHandEquipment(inst)
    return inst.components.inventory ~= nil
        and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= nil
end

local function NewHandAnalysisStats()
    return {
        damage_bonus = 0,
        speed_mult = 1,
        planar_bonus = 0,
        tool_actions = {},
        tool_tough = false,
    }
end

local function AddHandAnalysisStats(stats, data)
    stats.damage_bonus = stats.damage_bonus + GetAnalysisDamageBonus(data)
    stats.speed_mult = stats.speed_mult * (data.speed_mult or 1)
    stats.planar_bonus = stats.planar_bonus + (data.planar_bonus or 0)

    if data.tool_actions ~= nil then
        for action_id, effectiveness in pairs(data.tool_actions) do
            if ACTIONS[action_id] ~= nil then
                stats.tool_actions[action_id] = (stats.tool_actions[action_id] or 0) + (effectiveness or 1)
            end
        end
    end

    stats.tool_tough = stats.tool_tough or data.tool_tough == true
end

local function GetProtocolDrainSettings()
    return {
        amount = TUNING.KEI_PROTOCOL_DRAIN_AMOUNT or 2,
        cap = TUNING.KEI_PROTOCOL_DRAIN_MAX_PER_PERIOD or TUNING.KEI_PROTOCOL_DRAIN_MAX_PER_SECOND or 10,
    }
end

local MOOSE_ELECTRIC_BUFF_NAME = "kei_moose_electricattack"
local ANALYSIS_ARMOR_MODIFIER = "kei_analysis_armor"
local ANALYSIS_HANDS_MODIFIER = "kei_analysis_hands"

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

local function GetUnlockedTierCount(unlocked_slots)
    local step = TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2
    if step <= 0 then
        return 0
    end
    return math.min(3, math.max(0, math.floor((unlocked_slots - GetInitialSlots()) / step + 0.5)))
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

function KeiProtocolSlots:GetStatBonus()
    return GetUnlockedTierCount(self.unlocked_slots) * (TUNING.KEI_PROTOCOL_STAT_BONUS or 20)
end

function KeiProtocolSlots:ApplyStatProgression()
    local bonus = self:GetStatBonus()
    local max_integrity = (TUNING.KEI_MAX_INTEGRITY or 120) + bonus
    local max_power = (TUNING.KEI_MAX_POWER or 120) + bonus
    local max_stability = (TUNING.KEI_MAX_STABILITY or 120) + bonus
    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity

    if health ~= nil and health.maxhealth ~= max_integrity then
        health:SetMaxHealth(max_integrity)
    end
    if hunger ~= nil and hunger.max ~= max_power then
        hunger:SetMax(max_power)
    end
    if sanity ~= nil and sanity.max ~= max_stability then
        sanity:SetMax(max_stability)
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
    self:ApplyStatProgression()

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
    self:ApplyStatProgression()
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
    return not self:IsDisabledByHealth() and not self.inst:HasTag("kei_dormant")
end

function KeiProtocolSlots:HasProtocolInUnlockedSlots(protocol)
    local inventory = self.inst.components.inventory
    if protocol == nil or inventory == nil then
        return false
    end

    for slot = 1, GetMaxSlots() do
        local container = inventory:GetItemInSlot(slot)
        if IsProtocolContainer(container) and container.components.container ~= nil and slot <= self.unlocked_slots then
            local item = container.components.container:GetItemInSlot(1)
            local data = IsProtocol(item) and item.kei_protocol_data or nil
            if data ~= nil and data.kind == "combat" and data.protocol == protocol then
                return true
            end
        end
    end

    return false
end

function KeiProtocolSlots:StalkerProtocolOverridesStability()
    return self:HasProtocolInUnlockedSlots("stalker_atrium")
end

function KeiProtocolSlots:AlterguardianProtocolOverridesPower()
    if not self:HasProtocolInUnlockedSlots("alterguardian") then
        return false
    end

    local sanity = self.inst.components.sanity
    return sanity == nil or sanity.current > 0 or self:StalkerProtocolOverridesStability()
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
    if ProtocolNeedsPower(data)
        and self.inst.components.hunger ~= nil
        and self.inst.components.hunger.current <= 0
        and not self:AlterguardianProtocolOverridesPower()
    then
        return false
    end
    if ProtocolNeedsStability(data)
        and self.inst.components.sanity ~= nil
        and self.inst.components.sanity.current <= 0
        and data.protocol ~= "stalker_atrium"
        and not self:StalkerProtocolOverridesStability()
    then
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

function KeiProtocolSlots:SwapWithProtocolBinder(binder)
    if binder == nil
        or binder.components.container == nil
        or self.inst.components.inventory == nil
        or not self:IsFunctional()
    then
        return false
    end

    self:EnsureProtocolContainers()

    local swapped = false
    local inventory = self.inst.components.inventory
    local binder_container = binder.components.container
    local max_slots = math.min(GetMaxSlots(), binder_container.numslots or 0)

    for slot = 1, max_slots do
        if slot <= self.unlocked_slots then
            local protocol_container = inventory:GetItemInSlot(slot)
            if IsProtocolContainer(protocol_container) and protocol_container.components.container ~= nil then
                local slot_container = protocol_container.components.container
                local equipped_cd = slot_container:GetItemInSlot(1)
                local stored_cd = binder_container:GetItemInSlot(slot)

                if equipped_cd ~= nil or stored_cd ~= nil then
                    equipped_cd = equipped_cd ~= nil and slot_container:RemoveItemBySlot(1, true) or nil
                    stored_cd = stored_cd ~= nil and binder_container:RemoveItemBySlot(slot, true) or nil

                    local stored_ok = stored_cd == nil or slot_container:GiveItem(stored_cd, 1)
                    local equipped_ok = equipped_cd == nil or binder_container:GiveItem(equipped_cd, slot)

                    if not stored_ok and stored_cd ~= nil then
                        binder_container:GiveItem(stored_cd, slot)
                    end
                    if not equipped_ok and equipped_cd ~= nil then
                        slot_container:GiveItem(equipped_cd, 1)
                    end

                    swapped = swapped
                        or (stored_cd ~= nil and stored_ok)
                        or (equipped_cd ~= nil and equipped_ok)
                end
            end
        end
    end

    if swapped then
        self:Refresh()
    end
    return swapped
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

function KeiProtocolSlots:ClearAnalysisToolActions()
    local worker = self.inst.components.worker
    if worker ~= nil then
        for action_id, old_value in pairs(self._kei_worker_action_old_values or {}) do
            local action = ACTIONS[action_id]
            if action ~= nil then
                worker.actions[action] = old_value
            end
        end
    end

    if self._kei_added_worker and self.inst.components.worker ~= nil then
        self.inst:RemoveComponent("worker")
    end

    for action_id, had_tag in pairs(self._kei_tool_action_old_tags or {}) do
        if not had_tag then
            local action = ACTIONS[action_id]
            local tag = action ~= nil and (action.id .. "_tool") or (action_id .. "_tool")
            self.inst:RemoveTag(tag)
        end
    end

    if self._kei_toughworker_old_tag ~= nil then
        if not self._kei_toughworker_old_tag then
            self.inst:RemoveTag("toughworker")
        end
        self._kei_toughworker_old_tag = nil
    end

    self._kei_added_worker = nil
    self._kei_worker_action_old_values = {}
    self._kei_tool_action_old_tags = {}
    self.analysis_tool_actions = {}
    self.analysis_tool_tough = nil
end

function KeiProtocolSlots:SetAnalysisToolActions(actions, tough)
    self:ClearAnalysisToolActions()

    if HasHandEquipment(self.inst) then
        return
    end

    local has_actions = actions ~= nil and next(actions) ~= nil
    if not has_actions and not tough then
        return
    end

    if has_actions then
        if self.inst.components.worker == nil then
            self.inst:AddComponent("worker")
            self._kei_added_worker = true
        end

        local worker = self.inst.components.worker
        for action_id, effectiveness in pairs(actions) do
            local action = ACTIONS[action_id]
            if action ~= nil then
                self._kei_worker_action_old_values[action_id] = worker.actions[action]
                worker:SetAction(action, effectiveness or 1)

                local tag = action.id .. "_tool"
                self._kei_tool_action_old_tags[action_id] = self.inst:HasTag(tag)
                self.inst:AddTag(tag)
            end
        end
    end

    if tough then
        self._kei_toughworker_old_tag = self.inst:HasTag("toughworker")
        self.inst:AddTag("toughworker")
    end

    self.analysis_tool_actions = actions or {}
    self.analysis_tool_tough = tough or nil
end

function KeiProtocolSlots:PositionDaywalker2ShieldFx()
    local fx = self._kei_daywalker2_shield_fx
    if fx ~= nil and fx:IsValid() then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y + 1.5, z)
        fx.Transform:SetRotation(0)
    end
end

function KeiProtocolSlots:EnableDaywalker2ShieldFx()
    if self._kei_daywalker2_shield_fx ~= nil and self._kei_daywalker2_shield_fx:IsValid() then
        return
    end

    local fx = SpawnPrefab("kei_daywalker2_shield_fx")
    if fx ~= nil then
        self._kei_daywalker2_shield_fx = fx
        self:PositionDaywalker2ShieldFx()
        self._kei_daywalker2_shield_follow_task = self.inst:DoPeriodicTask(DAYWALKER2_SHIELD_FOLLOW_PERIOD, function()
            self:PositionDaywalker2ShieldFx()
        end)
    end
end

function KeiProtocolSlots:DisableDaywalker2ShieldFx()
    if self._kei_daywalker2_shield_follow_task ~= nil then
        self._kei_daywalker2_shield_follow_task:Cancel()
        self._kei_daywalker2_shield_follow_task = nil
    end
    if self._kei_daywalker2_shield_fx ~= nil then
        if self._kei_daywalker2_shield_fx:IsValid() then
            self._kei_daywalker2_shield_fx:Remove()
        end
        self._kei_daywalker2_shield_fx = nil
    end
end

function KeiProtocolSlots:PositionWagbossTargetFx()
    local fx = self._kei_wagboss_target_fx
    if fx ~= nil and fx:IsValid() then
        fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
        fx.Transform:SetRotation(0)
    end
end

function KeiProtocolSlots:EnableWagbossTargetFx()
    if self._kei_wagboss_target_fx ~= nil and self._kei_wagboss_target_fx:IsValid() then
        return
    end

    local fx = SpawnPrefab("kei_wagboss_target_fx")
    if fx ~= nil then
        self._kei_wagboss_target_fx = fx
        self:PositionWagbossTargetFx()
        self._kei_wagboss_target_follow_task = self.inst:DoPeriodicTask(WAGBOSS_TARGET_FOLLOW_PERIOD, function()
            self:PositionWagbossTargetFx()
        end)
    end
end

function KeiProtocolSlots:DisableWagbossTargetFx()
    if self._kei_wagboss_target_follow_task ~= nil then
        self._kei_wagboss_target_follow_task:Cancel()
        self._kei_wagboss_target_follow_task = nil
    end
    if self._kei_wagboss_target_ready_task ~= nil then
        self._kei_wagboss_target_ready_task:Cancel()
        self._kei_wagboss_target_ready_task = nil
    end
    if self._kei_wagboss_target_fx ~= nil then
        if self._kei_wagboss_target_fx:IsValid() then
            self._kei_wagboss_target_fx:Remove()
        end
        self._kei_wagboss_target_fx = nil
    end
end

function KeiProtocolSlots:RefreshWagbossTargetFx()
    if not self:IsFunctional() or not self.active_combat.wagboss_robot then
        self:DisableWagbossTargetFx()
        return
    end

    local now = GetTime()
    local ready_time = self._kei_wagboss_beam_ready_time or 0
    if ready_time > now then
        self:DisableWagbossTargetFx()
        self._kei_wagboss_target_ready_task = self.inst:DoTaskInTime(ready_time - now, function()
            self._kei_wagboss_target_ready_task = nil
            self:RefreshWagbossTargetFx()
        end)
        return
    end

    self:EnableWagbossTargetFx()
end

function KeiProtocolSlots:ClearModifiers()
    self:ClearVirtualEquips()
    self:ClearAnalysisToolActions()
    self:SetAnalysisDamageBonus(0)

    self.inst:RemoveTag("kei_nofreezing")
    self.inst:RemoveTag("kei_nooverheat")
    self.inst:RemoveTag("kei_stagger_immune")
    self.inst:RemoveTag("kei_control_immune")
    self.inst:RemoveTag("kei_attack_speed_boost")
    self.inst:RemoveTag("kei_vault_pillar_guard_spin")
    self:DisableFreezeImmunity()
    self:DisableMooseProtocol()
    self:DisableMalbatrossProtocol()
    self:DisableToadstoolProtocol()
    self:DisableMutatedDeerclopsProtocol()
    self:DisableCelestialOrbProtocol()
    self:DisableDaywalker2ShieldFx()
    self:DisableWagbossTargetFx()

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, ANALYSIS_ARMOR_MODIFIER)
        self.inst.components.health.externalfiredamagemultipliers:RemoveModifier(self.inst)
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, ANALYSIS_HANDS_MODIFIER)
    end
    if self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, ANALYSIS_HANDS_MODIFIER)
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, ANALYSIS_HANDS_MODIFIER)
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
    self.active_life = {}
    self:SyncCombatProtocolFlags()
    self:SyncLifeProtocolFlags()
    self:SetProtocolContainersPowered(false)
    self:ClearModifiers()
end

function KeiProtocolSlots:EnableFreezeImmunity()
    local freezable = self.inst.components.freezable
    if self._kei_freeze_immune then
        return
    end

    self._kei_had_freezable = freezable ~= nil
    if freezable ~= nil then
        -- Rocky cannot be frozen because it has no freezable component. Mirror
        -- that while the Deerclops protocol is mounted, instead of only
        -- redirecting AddColdness.
        if freezable:IsFrozen() then
            freezable:Unfreeze()
        else
            freezable:Reset()
        end
        self.inst:RemoveComponent("freezable")
    end
    self._kei_freeze_immune = true
end

function KeiProtocolSlots:DisableFreezeImmunity()
    if not self._kei_freeze_immune then
        return
    end

    if self._kei_had_freezable
        and self.inst.components.freezable == nil
        and not self.inst:HasTag("playerghost")
    then
        MakeLargeFreezableCharacter(self.inst, "torso")
        self.inst.components.freezable:SetResistance(4)
        self.inst.components.freezable:SetDefaultWearOffTime(TUNING.PLAYER_FREEZE_WEAR_OFF_TIME)
    end
    self._kei_had_freezable = nil
    self._kei_freeze_immune = nil
end

local function IsValidMutatedDeerclopsAuraTarget(owner, target)
    if target == nil
        or target == owner
        or not target:IsValid()
        or target:IsInLimbo()
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
    then
        return false
    end

    local combat = owner.components.combat
    return combat == nil or not combat:IsAlly(target)
end

local function AddMutatedDeerclopsStategraphSlowSource(target, source)
    target._kei_mutateddeerclops_sg_slow_sources = target._kei_mutateddeerclops_sg_slow_sources or {}
    target._kei_mutateddeerclops_sg_slow_sources[source] = true
    target:AddTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
end

local function RemoveMutatedDeerclopsStategraphSlowSource(target, source)
    local sources = target._kei_mutateddeerclops_sg_slow_sources
    if sources == nil then
        target:RemoveTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
        return true
    end

    sources[source] = nil
    if next(sources) == nil then
        target._kei_mutateddeerclops_sg_slow_sources = nil
        target:RemoveTag(MUTATEDDEERCLOPS_AURA_SG_SLOW_TAG)
        return true
    end
    return false
end

function KeiProtocolSlots:ApplyMutatedDeerclopsSlow(target)
    if self._kei_mutateddeerclops_slowed[target] ~= nil then
        return
    end

    local data = {}
    data.onremove = function()
        self._kei_mutateddeerclops_slowed[target] = nil
    end
    self.inst:ListenForEvent("onremove", data.onremove, target)
    self._kei_mutateddeerclops_slowed[target] = data

    AddMutatedDeerclopsStategraphSlowSource(target, self.inst)
    if target.components.locomotor ~= nil then
        target.components.locomotor:SetExternalSpeedMultiplier(self.inst, MUTATEDDEERCLOPS_AURA_SLOW_KEY, TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
    end
    if target.AnimState ~= nil then
        target.AnimState:SetDeltaTimeMultiplier(TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
    end
end

function KeiProtocolSlots:ClearMutatedDeerclopsSlow(target)
    local data = self._kei_mutateddeerclops_slowed[target]
    if data == nil then
        return
    end

    self._kei_mutateddeerclops_slowed[target] = nil
    self.inst:RemoveEventCallback("onremove", data.onremove, target)

    if target:IsValid() then
        local no_sources = RemoveMutatedDeerclopsStategraphSlowSource(target, self.inst)
        if target.components.locomotor ~= nil then
            target.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, MUTATEDDEERCLOPS_AURA_SLOW_KEY)
        end
        if no_sources and target.AnimState ~= nil then
            target.AnimState:SetDeltaTimeMultiplier(1)
        end
    end
end

function KeiProtocolSlots:ClearAllMutatedDeerclopsSlows()
    local targets = {}
    for target in pairs(self._kei_mutateddeerclops_slowed) do
        table.insert(targets, target)
    end
    for _, target in ipairs(targets) do
        self:ClearMutatedDeerclopsSlow(target)
    end
end

function KeiProtocolSlots:PositionMutatedDeerclopsAura()
    local fx = self._kei_mutateddeerclops_aura
    if fx ~= nil and fx:IsValid() then
        fx.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
    end
end

function KeiProtocolSlots:UpdateMutatedDeerclopsAura()
    local fx = self._kei_mutateddeerclops_aura
    if fx == nil or not fx:IsValid() then
        self:DisableMutatedDeerclopsProtocol()
        return
    end

    self:PositionMutatedDeerclopsAura()

    local x, y, z = fx.Transform:GetWorldPosition()
    local radius = TUNING.KEI_MUTATEDDEERCLOPS_AURA_RADIUS or 5.5
    local in_range = {}
    for _, target in ipairs(TheSim:FindEntities(x, y, z, radius, MUTATEDDEERCLOPS_AURA_MUST_TAGS, MUTATEDDEERCLOPS_AURA_EXCLUDE_TAGS)) do
        if IsValidMutatedDeerclopsAuraTarget(self.inst, target) then
            in_range[target] = true
            self:ApplyMutatedDeerclopsSlow(target)
        end
    end

    local out_of_range = {}
    for target in pairs(self._kei_mutateddeerclops_slowed) do
        if not in_range[target] then
            table.insert(out_of_range, target)
        end
    end
    for _, target in ipairs(out_of_range) do
        self:ClearMutatedDeerclopsSlow(target)
    end
end

function KeiProtocolSlots:RefreshMutatedDeerclopsAuraDuration()
    if self._kei_mutateddeerclops_aura_remove_task ~= nil then
        self._kei_mutateddeerclops_aura_remove_task:Cancel()
    end
    self._kei_mutateddeerclops_aura_remove_task = self.inst:DoTaskInTime(TUNING.KEI_MUTATEDDEERCLOPS_AURA_DURATION or 5, function()
        self:DisableMutatedDeerclopsProtocol()
    end)
end

function KeiProtocolSlots:DisableMutatedDeerclopsProtocol()
    if self._kei_mutateddeerclops_aura_task ~= nil then
        self._kei_mutateddeerclops_aura_task:Cancel()
        self._kei_mutateddeerclops_aura_task = nil
    end
    if self._kei_mutateddeerclops_aura_follow_task ~= nil then
        self._kei_mutateddeerclops_aura_follow_task:Cancel()
        self._kei_mutateddeerclops_aura_follow_task = nil
    end
    if self._kei_mutateddeerclops_aura_remove_task ~= nil then
        self._kei_mutateddeerclops_aura_remove_task:Cancel()
        self._kei_mutateddeerclops_aura_remove_task = nil
    end
    if self._kei_mutateddeerclops_aura ~= nil then
        if self._kei_mutateddeerclops_aura:IsValid() then
            self._kei_mutateddeerclops_aura:KillFX()
        end
        self._kei_mutateddeerclops_aura = nil
    end
    self:ClearAllMutatedDeerclopsSlows()
end

function KeiProtocolSlots:DoMutatedDeerclopsProtocol()
    local now = GetTime()
    if (self._kei_mutateddeerclops_aura_ready_time or 0) > now then
        return
    end
    self._kei_mutateddeerclops_aura_ready_time = now + (TUNING.KEI_MUTATEDDEERCLOPS_AURA_COOLDOWN or 3)

    local fx = self._kei_mutateddeerclops_aura
    if fx ~= nil and fx:IsValid() then
        self:PositionMutatedDeerclopsAura()
        self:RefreshMutatedDeerclopsAuraDuration()
        self:UpdateMutatedDeerclopsAura()
        return
    end

    self:DisableMutatedDeerclopsProtocol()

    fx = SpawnPrefab("kei_mutateddeerclops_aura_fx")
    if fx == nil then
        return
    end

    self._kei_mutateddeerclops_aura = fx
    self:PositionMutatedDeerclopsAura()
    if fx.GrowFX ~= nil then
        fx:GrowFX()
    end

    self._kei_mutateddeerclops_aura_follow_task = self.inst:DoPeriodicTask(MUTATEDDEERCLOPS_AURA_FOLLOW_PERIOD, function()
        self:PositionMutatedDeerclopsAura()
    end)
    self._kei_mutateddeerclops_aura_task = self.inst:DoPeriodicTask(MUTATEDDEERCLOPS_AURA_UPDATE_PERIOD, function()
        self:UpdateMutatedDeerclopsAura()
    end, 0)
    self:RefreshMutatedDeerclopsAuraDuration()
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

function KeiProtocolSlots:EnableMalbatrossProtocol()
    if self._kei_malbatross_enabled then
        return
    end

    local drownable = self.inst.components.drownable
    if drownable ~= nil and not TheWorld:HasTag("cave") then
        self._kei_malbatross_old_drownable_enabled = drownable.enabled
        drownable.enabled = false
        self.inst.Physics:SetCollisionMask(
            COLLISION.GROUND,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        self.inst.Physics:Teleport(self.inst.Transform:GetWorldPosition())
    end

    self._kei_malbatross_enabled = true
end

function KeiProtocolSlots:DisableMalbatrossProtocol()
    if not self._kei_malbatross_enabled then
        return
    end

    local drownable = self.inst.components.drownable
    if drownable ~= nil then
        drownable.enabled = self._kei_malbatross_old_drownable_enabled ~= false
        self._kei_malbatross_old_drownable_enabled = nil
    end

    if not self.inst:HasTag("playerghost") then
        self.inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        self.inst.Physics:Teleport(self.inst.Transform:GetWorldPosition())
    end

    self._kei_malbatross_enabled = nil
end

function KeiProtocolSlots:RefreshMalbatrossProtocol()
    if self.active_combat.malbatross then
        self:EnableMalbatrossProtocol()
    else
        self:DisableMalbatrossProtocol()
    end
end

function KeiProtocolSlots:EnableToadstoolProtocol()
    if self._kei_toadstool_enabled then
        return
    end

    local grogginess = self.inst.components.grogginess
    if grogginess ~= nil then
        grogginess:ResetGrogginess()
        grogginess:AddImmunitySource(self.inst)
        if grogginess:IsKnockedOut() then
            grogginess:ComeTo()
        end
    end

    local sleeper = self.inst.components.sleeper
    if sleeper ~= nil then
        sleeper.sleepiness = 0
        if sleeper:IsAsleep() then
            sleeper:WakeUp()
        end
    end

    self._kei_toadstool_enabled = true
end

function KeiProtocolSlots:DisableToadstoolProtocol()
    if not self._kei_toadstool_enabled then
        return
    end

    if self.inst.components.grogginess ~= nil then
        self.inst.components.grogginess:RemoveImmunitySource(self.inst)
    end

    self._kei_toadstool_enabled = nil
end

function KeiProtocolSlots:RefreshToadstoolProtocol()
    if self.active_combat.toadstool then
        self:EnableToadstoolProtocol()
    else
        self:DisableToadstoolProtocol()
    end
end

function KeiProtocolSlots:HasCombatProtocol(protocol)
    return self:IsFunctional() and self.active_combat[protocol] == true
end

function KeiProtocolSlots:GetLifeProtocolCount(protocol)
    return self:IsFunctional() and (self.active_life[protocol] or 0) or 0
end

function KeiProtocolSlots:HasLifeProtocol(protocol)
    return self:GetLifeProtocolCount(protocol) > 0
end

function KeiProtocolSlots:ApplyLifeGrowthAcceleration()
    local stacks = self:GetLifeProtocolCount("growth_acceleration")
    if stacks <= 0 or TheSim == nil then
        return
    end

    local period = TUNING.KEI_LIFE_GROWTH_ACCELERATION_PERIOD or 1
    local speed_multiplier = stacks * (TUNING.KEI_LIFE_GROWTH_ACCELERATION_PER_STACK or 2)
    local extra_elapsed_time = math.max(0, speed_multiplier - 1) * period
    if extra_elapsed_time <= 0 then
        return
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local radius = TUNING.KEI_LIFE_GROWTH_ACCELERATION_RADIUS or 12
    for _, target in ipairs(TheSim:FindEntities(x, y, z, radius)) do
        local growable = target.components.growable
        if growable ~= nil
            and growable:IsGrowing()
            and growable.stages ~= nil
        then
            -- Preserve the original stage time roll and only advance its remaining time.
            growable:ExtendGrowTime(-extra_elapsed_time)
        end

        local timer = target.components.timer
        if ((target.growprefab ~= nil and target.StartGrowing ~= nil)
                or GROWTH_TIMER_PREFAB_WHITELIST[target.prefab])
            and timer ~= nil
            and timer:TimerExists("grow")
        then
            -- Planted tree saplings use the named "grow" timer instead of growable.
            timer:SetTimeLeft("grow", (timer:GetTimeLeft("grow") or 0) - extra_elapsed_time)
        end

        local pickable = target.components.pickable
        if growable == nil and pickable ~= nil then
            -- Let pickable retain its own pause, wither, and external-timer rules.
            pickable:LongUpdate(extra_elapsed_time)
        end
    end
end

function KeiProtocolSlots:ApplyLifeDurabilityRestore()
    local stacks = self:GetLifeProtocolCount("durability_restore")
    local inventory = self.inst.components.inventory
    if stacks <= 0 or inventory == nil then
        return
    end

    local restore_percent = stacks * (TUNING.KEI_LIFE_DURABILITY_RESTORE_PER_STACK or 0.1)
    if restore_percent <= 0 then
        return
    end

    local processed = {}
    local function RestoreDurability(item)
        if item == nil
            or processed[item]
            or not item:IsValid()
            or item:HasTag("kei_virtual_equipment")
        then
            return
        end

        processed[item] = true
        local finiteuses = item.components.finiteuses
        if finiteuses ~= nil and finiteuses.total ~= nil and finiteuses.total > 0 then
            local restored_uses = finiteuses.current + finiteuses.total * restore_percent
            finiteuses:SetUses(math.min(restored_uses, finiteuses.total))
        end

        local armor = item.components.armor
        if armor ~= nil
            and not armor:IsIndestructible()
            and armor.maxcondition ~= nil
            and armor.maxcondition > 0
        then
            if armor._kei_life_original_maxcondition ~= nil then
                armor.maxcondition = armor._kei_life_original_maxcondition
                armor._kei_life_original_maxcondition = nil
            end
            armor:SetCondition(math.min(
                armor.condition + armor.maxcondition * restore_percent,
                armor.maxcondition
            ))
        end
    end

    for _, item in pairs(inventory.itemslots) do
        RestoreDurability(item)
    end
    RestoreDurability(inventory.activeitem)
    for _, item in pairs(inventory.equipslots) do
        RestoreDurability(item)
    end
end

function KeiProtocolSlots:SyncLifeProtocolFlags()
    if self.inst._kei_map_teleport_protocol_active ~= nil then
        self.inst._kei_map_teleport_protocol_active:set(self:HasLifeProtocol("map_teleport"))
    end
end

function KeiProtocolSlots:SyncCombatProtocolFlags()
    if self.inst._kei_eyeofterror_protocol_active ~= nil then
        self.inst._kei_eyeofterror_protocol_active:set(self:HasCombatProtocol("eyeofterror"))
    end
    local daywalker_active = self:HasCombatProtocol("daywalker")
    if self.inst._kei_daywalker_protocol_active ~= nil then
        self.inst._kei_daywalker_protocol_active:set(daywalker_active)
    end
    if self.inst._kei_malbatross_protocol_active ~= nil then
        self.inst._kei_malbatross_protocol_active:set(self:HasCombatProtocol("malbatross"))
    end
    if self.inst._kei_mutatedwarg_protocol_active ~= nil then
        self.inst._kei_mutatedwarg_protocol_active:set(self:HasCombatProtocol("mutatedwarg"))
    end
    if not daywalker_active then
        self.inst.kei_daywalker_aiming = nil
        if self.inst._kei_daywalker_aiming ~= nil then
            self.inst._kei_daywalker_aiming:set(false)
        end
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
    local life = {}
    local hand_stats = NewHandAnalysisStats()
    local desired_virtuals = {}

    self.active = items

    for _, entry in ipairs(items) do
        local data = entry.data
        if data.kind == "combat" and data.protocol ~= nil then
            combat[data.protocol] = true
        elseif data.kind == "life" and data.protocol ~= nil then
            local definition = LIFE_PROTOCOLS[data.protocol]
            if definition ~= nil and definition.stackable == true then
                life[data.protocol] = (life[data.protocol] or 0) + 1
            else
                life[data.protocol] = 1
            end
        elseif data.kind == "analysis" then
            if data.slot == "head" or data.slot == "body" then
                desired_virtuals[entry.slot] = true
                self:ApplyVirtualEquip(entry)
            elseif data.slot == "hands" then
                AddHandAnalysisStats(hand_stats, data)
            end
        end
    end

    self:ClearVirtualEquips(desired_virtuals)
    self.active_combat = combat
    self.active_life = life
    self:SyncLifeProtocolFlags()
    self:RefreshTemperatureProtocols()
    self:RefreshMooseProtocol()
    self:RefreshMalbatrossProtocol()
    self:RefreshToadstoolProtocol()
    self:RefreshCelestialOrbProtocol()
    self:RefreshWagbossTargetFx()
    if not self.active_combat.mutateddeerclops then
        self:DisableMutatedDeerclopsProtocol()
    end
    if self.active_combat.daywalker2 then
        self.inst:AddTag("kei_stagger_immune")
        self.inst:AddTag("kei_control_immune")
        self:EnableDaywalker2ShieldFx()
    else
        self.inst:RemoveTag("kei_stagger_immune")
        self.inst:RemoveTag("kei_control_immune")
        self:DisableDaywalker2ShieldFx()
    end
    if self.active_combat.mutatedbearger then
        self.inst:AddTag("kei_attack_speed_boost")
    else
        self.inst:RemoveTag("kei_attack_speed_boost")
    end
    if self.active_combat.vault_pillar_guard then
        self.inst:AddTag("kei_vault_pillar_guard_spin")
    else
        self.inst:RemoveTag("kei_vault_pillar_guard_spin")
    end
    self:SyncCombatProtocolFlags()

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, ANALYSIS_ARMOR_MODIFIER)
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, ANALYSIS_HANDS_MODIFIER)
        self:SetAnalysisDamageBonus(hand_stats.damage_bonus)
    end
    if hand_stats.planar_bonus > 0 then
        if self.inst.components.planardamage == nil then
            self.inst:AddComponent("planardamage")
        end
        self.inst.components.planardamage:AddBonus(self.inst, hand_stats.planar_bonus, ANALYSIS_HANDS_MODIFIER)
    elseif self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, ANALYSIS_HANDS_MODIFIER)
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, ANALYSIS_HANDS_MODIFIER, hand_stats.speed_mult)
    end
    self:SetAnalysisToolActions(hand_stats.tool_actions, hand_stats.tool_tough)
end

function KeiProtocolSlots:DrainProtocols()
    if not self:IsFunctional() then
        self:DisableAllProtocols()
        return
    end

    self:Refresh()

    if self.active_combat.alterguardian and self.inst.components.hunger ~= nil then
        self.inst.components.hunger:DoDelta(TUNING.KEI_ALTERGUARDIAN_POWER_REGEN or 10)
    end

    -- 果蝇王协议停止额外消耗，但不阻止天体英雄协议的回电。
    if self.active_combat.lordfruitfly then
        return
    end

    local power_cost = 0
    local stability_cost = 0
    local drain = GetProtocolDrainSettings()

    for _, entry in ipairs(self.active) do
        local data = entry.data
        if ProtocolNeedsPower(data) then
            power_cost = power_cost + drain.amount
        elseif ProtocolNeedsStability(data) then
            stability_cost = stability_cost + drain.amount
        end
    end

    power_cost = math.min(power_cost, drain.cap)
    stability_cost = math.min(stability_cost, drain.cap)

    local silent_drain = not TUNING.KEI_PROTOCOL_DRAIN_SOUND
    if power_cost > 0 and self.inst.components.hunger ~= nil then
        self.inst.components.hunger:DoDelta(-power_cost, silent_drain)
    end
    if stability_cost > 0 and self.inst.components.sanity ~= nil then
        self.inst.components.sanity:DoDelta(-stability_cost, silent_drain)
    end

    self:Refresh()
end

function KeiProtocolSlots:SpawnCelestialOrb(index)
    local orb = SpawnPrefab("kei_celestial_orb_fx")
    if orb == nil then
        return nil
    end

    orb.persists = false
    self._kei_celestial_orbs[index] = orb
    return orb
end

function KeiProtocolSlots:EnsureCelestialOrbs()
    local count = TUNING.KEI_CELESTIAL_ORB_COUNT or 5
    self._kei_celestial_orbs = self._kei_celestial_orbs or {}
    self._kei_celestial_orb_angles = self._kei_celestial_orb_angles or {}

    for index = 1, count do
        local orb = self._kei_celestial_orbs[index]
        if orb == nil or not orb:IsValid() then
            orb = self:SpawnCelestialOrb(index)
        end
        if self._kei_celestial_orb_angles[index] == nil then
            self._kei_celestial_orb_angles[index] = (index - 1) * TWOPI / count
        end
    end

    for index = count + 1, #(self._kei_celestial_orbs or {}) do
        local orb = self._kei_celestial_orbs[index]
        if orb ~= nil and orb:IsValid() then
            orb:Remove()
        end
        self._kei_celestial_orbs[index] = nil
        self._kei_celestial_orb_angles[index] = nil
    end
end

function KeiProtocolSlots:UpdateCelestialOrbs()
    if not self:IsFunctional() or not self.active_combat.alterguardian_phase4_lunarrift then
        self:DisableCelestialOrbProtocol()
        return
    end

    self:EnsureCelestialOrbs()

    local count = TUNING.KEI_CELESTIAL_ORB_COUNT or 5
    local radius = TUNING.KEI_CELESTIAL_ORB_RADIUS or 2.7
    local height = TUNING.KEI_CELESTIAL_ORB_HEIGHT or 1.35
    local now = GetTime()
    local accelerated = (self._kei_celestial_orb_accel_until or 0) > now
    local speed = accelerated
        and (TUNING.KEI_CELESTIAL_ORB_ATTACK_SPEED or 0.22)
        or (TUNING.KEI_CELESTIAL_ORB_IDLE_SPEED or 0.012)
    local x, y, z = self.inst.Transform:GetWorldPosition()

    for index = 1, count do
        local angle = (self._kei_celestial_orb_angles[index] or ((index - 1) * TWOPI / count))
            + speed * CELESTIAL_ORB_FOLLOW_PERIOD * 60
        self._kei_celestial_orb_angles[index] = angle

        local orb = self._kei_celestial_orbs[index]
        if orb ~= nil and orb:IsValid() then
            local orb_x = x + math.cos(angle) * radius
            local orb_z = z + math.sin(angle) * radius
            orb.Transform:SetPosition(
                orb_x,
                y + height,
                orb_z
            )
            if accelerated then
                self:DealCelestialOrbDamageAtPoint(index, orb_x, y, orb_z)
            end
        end
    end
end

function KeiProtocolSlots:EnableCelestialOrbProtocol()
    self:EnsureCelestialOrbs()
    self:UpdateCelestialOrbs()

    if self._kei_celestial_orb_task == nil then
        self._kei_celestial_orb_task = self.inst:DoPeriodicTask(CELESTIAL_ORB_FOLLOW_PERIOD, function()
            self:UpdateCelestialOrbs()
        end)
    end
end

function KeiProtocolSlots:DisableCelestialOrbProtocol()
    if self._kei_celestial_orb_task ~= nil then
        self._kei_celestial_orb_task:Cancel()
        self._kei_celestial_orb_task = nil
    end

    for index, orb in pairs(self._kei_celestial_orbs or {}) do
        if orb ~= nil and orb:IsValid() then
            orb:Remove()
        end
        self._kei_celestial_orbs[index] = nil
    end

    self._kei_celestial_orb_angles = {}
    self._kei_celestial_orb_accel_until = nil
    self._kei_celestial_orb_damage = nil
    self._kei_celestial_orb_weapon = nil
    self._kei_celestial_orb_hit_times = setmetatable({}, { __mode = "k" })
end

function KeiProtocolSlots:RefreshCelestialOrbProtocol()
    if self.active_combat.alterguardian_phase4_lunarrift then
        self:EnableCelestialOrbProtocol()
    else
        self:DisableCelestialOrbProtocol()
    end
end

local function IsValidCelestialOrbTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.combat ~= nil
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and owner.components.combat:CanTarget(target)
        and not owner.components.combat:IsAlly(target)
end

function KeiProtocolSlots:DealCelestialOrbDamageAtPoint(orb_index, x, y, z)
    local damage = self._kei_celestial_orb_damage or 0
    if self._doing_celestial_orb_damage or damage <= 0 then
        return
    end

    local now = GetTime()
    local hit_radius = TUNING.KEI_CELESTIAL_ORB_HIT_RADIUS or 1.35
    local targets = TheSim:FindEntities(
        x,
        y,
        z,
        hit_radius,
        CELESTIAL_ORB_TARGET_MUST_TAGS,
        CELESTIAL_ORB_TARGET_EXCLUDE_TAGS
    )

    for _, target in ipairs(targets) do
        local target_hits = self._kei_celestial_orb_hit_times[target]
        if target_hits == nil then
            target_hits = {}
            self._kei_celestial_orb_hit_times[target] = target_hits
        end

        if IsValidCelestialOrbTarget(self.inst, target) and (target_hits[orb_index] or 0) <= now then
            target_hits[orb_index] = self._kei_celestial_orb_accel_until or now
            self._doing_celestial_orb_damage = true
            target.components.combat:GetAttacked(self.inst, damage, self._kei_celestial_orb_weapon)
            self._doing_celestial_orb_damage = nil
        end
    end
end

function KeiProtocolSlots:DoCelestialOrbProtocol(target, damage, weapon)
    if self._doing_celestial_orb_damage
        or (damage or 0) <= 0
        or not IsValidCelestialOrbTarget(self.inst, target)
    then
        return
    end

    local orb_damage = damage * (TUNING.KEI_CELESTIAL_ORB_DAMAGE_MULT or 0.2)
    if orb_damage <= 0 then
        return
    end

    self._kei_celestial_orb_accel_until = math.max(
        self._kei_celestial_orb_accel_until or 0,
        GetTime() + (TUNING.KEI_CELESTIAL_ORB_ACCEL_DURATION or 1.25)
    )
    self._kei_celestial_orb_damage = orb_damage
    self._kei_celestial_orb_weapon = weapon
    self._kei_celestial_orb_hit_times = setmetatable({}, { __mode = "k" })
end

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }
local BEEQUEEN_SCARE_MUST_TAGS = { "_combat", "_health" }
local BEEQUEEN_SCARE_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost", "epic" }

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function IsValidMinotaurProtocolTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and owner.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

local function IsValidShadowStrikeTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.combat ~= nil
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and owner.components.combat:IsValidTarget(target)
end

local SHADOWSTRIKE_START_DISTANCE = 5
local SHADOWSTRIKE_LUNGE_SPEED = 30
local SHADOWSTRIKE_COUNT = 5
local SHADOWSTRIKE_SPAWN_DELAY = 0.1

local function GetShadowStrikeOffset(index, base_angle)
    local angle = base_angle + (TWOPI / SHADOWSTRIKE_COUNT) * index * 2
    return Vector3(
        SHADOWSTRIKE_START_DISTANCE * math.sin(angle),
        0,
        SHADOWSTRIKE_START_DISTANCE * math.cos(angle)
    )
end

local function SpawnShadowStrikeSlash(target, rotation)
    local fx = SpawnPrefab(math.random(2) == 1 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.Transform:SetRotation(rotation or 0)
    end
end

function KeiProtocolSlots:SpawnStalkerShadowStrike(target, damage, offset)
    if not IsValidShadowStrikeTarget(self.inst, target) then
        return
    end

    local targetpos = target:GetPosition()
    local shadow = SpawnPrefab("waxwell_shadowstriker")
    if shadow == nil then
        SpawnShadowStrikeSlash(target, self.inst.Transform:GetRotation())
        self._doing_shadowstrike = true
        target.components.combat:GetAttacked(self.inst, damage)
        self._doing_shadowstrike = nil
        return
    end

    local transition = SpawnPrefab("statue_transition_2")
    if transition ~= nil then
        transition.Transform:SetPosition((targetpos + offset):Get())
    end

    shadow.persists = false
    shadow:Show()
    shadow.Transform:SetPosition((targetpos + offset):Get())
    shadow:FacePoint(targetpos)
    shadow.AnimState:PlayAnimation("lunge_pre")
    shadow.AnimState:PushAnimation("lunge_loop")
    shadow.AnimState:PushAnimation("lunge_pst")

    shadow:DoTaskInTime(12 * FRAMES, function(inst)
        if inst:IsValid() and inst.Physics ~= nil then
            inst.Physics:SetMotorVel(SHADOWSTRIKE_LUNGE_SPEED, 0, 0)
        end
    end)
    shadow:DoTaskInTime(15 * FRAMES, function(inst)
        if not IsValidShadowStrikeTarget(self.inst, target) then
            return
        end

        SpawnShadowStrikeSlash(target, inst.Transform:GetRotation())
        self._doing_shadowstrike = true
        target.components.combat:GetAttacked(self.inst, damage)
        self._doing_shadowstrike = nil
    end)
    shadow:DoTaskInTime(22 * FRAMES, function(inst)
        if inst:IsValid() and inst.Physics ~= nil then
            inst.Physics:ClearMotorVelOverride()
        end
    end)
    shadow:DoTaskInTime(30 * FRAMES, function(inst)
        if inst:IsValid() then
            inst:Remove()
        end
    end)
end

local function IsNearShadowPillar(pt, pillars)
    for _, pillarpt in pairs(pillars) do
        if distsq(pt.x, pt.z, pillarpt.x, pillarpt.z) < 1 then
            return true
        end
    end
    return false
end

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

local function IsValidAntlionSpikeTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

local function DoAntlionSpikeDamage(inst, owner, target, damage)
    if IsValidAntlionSpikeTarget(owner, target)
        and inst:IsValid()
        and target:GetDistanceSqToInst(inst) <= (TUNING.KEI_ANTLION_SANDSPIKE_DAMAGE_RADIUS or 1.1) ^ 2
    then
        target.components.combat:GetAttacked(owner, damage)
    end
end

local function ArmAntlionSpikeDamage(inst, owner, target, damage)
    inst:DoTaskInTime(2 * FRAMES, DoAntlionSpikeDamage, owner, target, damage)
end

function KeiProtocolSlots:SpawnAntlionSpike(pt, target, prefab, damage)
    local spike = SpawnPrefab(prefab or "sandspike_tall")
    if spike == nil then
        return
    end

    damage = damage or TUNING.SANDSPIKE.DAMAGE.TALL
    spike.Transform:SetPosition(pt.x, 0, pt.z)
    if spike.components.combat ~= nil then
        -- The spike keeps the vanilla animation and collision, while damage is
        -- applied only to Kei's original attack target to avoid friendly fire.
        spike.components.combat:SetDefaultDamage(0)
        spike.components.combat.playerdamagepercent = 0
    end
    spike:ListenForEvent("animover", function(inst)
        if not inst._kei_antlion_damage_armed then
            inst._kei_antlion_damage_armed = true
            ArmAntlionSpikeDamage(inst, self.inst, target, damage)
        end
    end)

    return spike
end

function KeiProtocolSlots:SpawnAntlionSpikeTriangle(center, target)
    local radius = TUNING.KEI_ANTLION_SANDSPIKE_TRIANGLE_RADIUS or 1.6
    local theta = math.random() * TWOPI
    for i = 0, 2 do
        local angle = theta + i * TWOPI / 3
        self:SpawnAntlionSpike(
            Vector3(center.x + math.cos(angle) * radius, 0, center.z + math.sin(angle) * radius),
            target,
            "sandspike_short",
            TUNING.KEI_ANTLION_SANDSPIKE_SHORT_DAMAGE or TUNING.SANDSPIKE.DAMAGE.SHORT
        )
    end
end

function KeiProtocolSlots:DoAntlionProtocol(target)
    local now = GetTime()
    if (self._kei_antlion_sandspike_ready_time or 0) > now
        or math.random() >= (TUNING.KEI_ANTLION_SANDSPIKE_CHANCE or 0.30)
        or not IsValidAntlionSpikeTarget(self.inst, target)
    then
        return
    end

    local center = target:GetPosition()
    if self:SpawnAntlionSpike(
        center,
        target,
        "sandspike_tall",
        TUNING.KEI_ANTLION_SANDSPIKE_TALL_DAMAGE or TUNING.SANDSPIKE.DAMAGE.TALL
    ) == nil then
        return
    end

    self._kei_antlion_sandspike_ready_time = now + (TUNING.KEI_ANTLION_SANDSPIKE_COOLDOWN or 0.5)
    self.inst:DoTaskInTime(TUNING.KEI_ANTLION_SANDSPIKE_VERTEX_DELAY or 8 * FRAMES, function()
        if IsValidAntlionSpikeTarget(self.inst, target) then
            self:SpawnAntlionSpikeTriangle(center, target)
        end
    end)
end

local function IsValidWagbossBeamTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and not target:IsInLimbo()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and owner.components.combat:CanTarget(target)
        and not owner.components.combat:IsAlly(target)
end

function KeiProtocolSlots:DoWagbossProtocol(target)
    local now = GetTime()
    if (self._kei_wagboss_beam_ready_time or 0) > now
        or not IsValidWagbossBeamTarget(self.inst, target)
    then
        return
    end

    local beam = SpawnPrefab("kei_wagboss_beam_fx")
    if beam == nil or beam.TrackTarget == nil then
        if beam ~= nil then
            beam:Remove()
        end
        return
    end

    local x, _, z = self.inst.Transform:GetWorldPosition()
    beam:SetCaster(self.inst)
    beam:TrackTarget(target, x, z)
    self._kei_wagboss_beam_ready_time = now + (TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_COOLDOWN or WAGBOSS_PROTOCOL_COOLDOWN)
    self:DisableWagbossTargetFx()
    self._kei_wagboss_target_ready_task = self.inst:DoTaskInTime(
        TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_COOLDOWN or WAGBOSS_PROTOCOL_COOLDOWN,
        function()
            self._kei_wagboss_target_ready_task = nil
            self:RefreshWagbossTargetFx()
        end
    )
end

function KeiProtocolSlots:SpawnMinotaurTentacle(target)
    if not IsValidMinotaurProtocolTarget(self.inst, target) then
        return false
    end

    local pt = target:GetPosition()
    local offset = FindWalkableOffset(pt, math.random() * TWOPI, 2, 3, false, true, NoHoles, false, true, true)
    if offset == nil then
        return false
    end

    local tentacle = SpawnPrefab("bigshadowtentacle")
    if tentacle == nil then
        return false
    end

    tentacle.kei_owner = self.inst
    tentacle.kei_target = target
    tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
    tentacle:DoTaskInTime(TUNING.KEI_MINOTAUR_TENTACLE_LIFETIME or 30, function(inst)
        if inst:IsValid() then
            inst:Remove()
        end
    end)
    if tentacle.components.combat ~= nil then
        tentacle.components.combat:SetRetargetFunction(0.5, function(inst)
            return IsValidMinotaurProtocolTarget(inst.kei_owner, inst.kei_target) and inst.kei_target or nil
        end)
        tentacle.components.combat:SetKeepTargetFunction(function(inst, current_target)
            return current_target == inst.kei_target
                and IsValidMinotaurProtocolTarget(inst.kei_owner, current_target)
                and current_target:IsNear(inst, TUNING.TENTACLE_STOPATTACK_DIST)
        end)
        tentacle.components.combat:SetTarget(target)
    end
    tentacle:PushEvent("arrive")
    return true
end

function KeiProtocolSlots:SpawnShadowPrison(target, weapon)
    if target.components.locomotor == nil or not IsValidMinotaurProtocolTarget(self.inst, target) then
        return
    end

    target:PushEvent("dispell_shadow_pillars")

    local map = TheWorld.Map
    local x0, y0, z0 = target.Transform:GetWorldPosition()
    if not map:IsPassableAtPoint(x0, y0, z0, true) then
        return
    end

    local padding = (target:HasTag("epic") and 1) or (target:HasTag("smallcreature") and 0) or 0.75
    local radius = math.max(1, target:GetPhysicsRadius(0) + padding)
    local num = math.floor(TWOPI * radius / 1.4 + 0.5)
    local period = 1 / num
    local delays = {}
    for i = 0, num - 1 do
        table.insert(delays, i * period)
    end

    local platform = target:GetCurrentPlatform()
    local flying = platform == nil and target:HasTag("flying")
    local target_marker = SpawnPrefab("shadow_pillar_target")
    if target_marker ~= nil then
        target_marker.Transform:SetPosition(x0, 0, z0)
        target_marker:SetDelay(delays[#delays])
        target_marker:SetTarget(target, radius, platform ~= nil)
    end

    local pillars = {}
    local theta = math.random() * TWOPI
    local delta = TWOPI / num
    for i = 1, num do
        local pt = Vector3(x0 + math.cos(theta) * radius, 0, z0 - math.sin(theta) * radius)
        if not IsNearShadowPillar(pt, pillars)
            and map:IsPassableAtPoint(pt.x, 0, pt.z, true)
            and (flying or (map:GetPlatformAtPoint(pt.x, pt.z) == platform and not map:IsGroundTargetBlocked(pt)))
        then
            local pillar = SpawnPrefab("shadow_pillar")
            if pillar ~= nil then
                pillar.Transform:SetPosition(pt:Get())
                pillar:SetDelay(table.remove(delays, math.random(#delays)))
                pillar:SetTarget(target, platform ~= nil)
                pillars[pillar] = pt
            end
        end
        theta = theta + delta
    end

    if not (target.sg ~= nil and target.sg:HasStateTag("noattack")) then
        target:PushEvent("attacked", { attacker = self.inst, damage = 0, weapon = weapon })
    end
end

function KeiProtocolSlots:DoMinotaurProtocol(target, weapon)
    local now = GetTime()
    if (self._kei_minotaur_tentacle_ready_time or 0) <= now
        and math.random() < (TUNING.KEI_MINOTAUR_TENTACLE_CHANCE or 0.30)
        and self:SpawnMinotaurTentacle(target)
    then
        self._kei_minotaur_tentacle_ready_time = now + (TUNING.KEI_MINOTAUR_TENTACLE_COOLDOWN or 0.5)
    end
    if math.random() < (TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE or 0.15) then
        self:SpawnShadowPrison(target, weapon)
    end
end

function KeiProtocolSlots:DoStalkerProtocol(target, damage)
    if self._doing_shadowstrike
        or math.random() >= (TUNING.KEI_STALKER_SHADOWSTRIKE_CHANCE or 0.30)
        or (damage or 0) <= 0
        or not IsValidShadowStrikeTarget(self.inst, target)
    then
        return
    end

    self._doing_shadowstrike = true

    local shadow_damage = damage * (TUNING.KEI_STALKER_SHADOWSTRIKE_DAMAGE_MULT or 0.5)
    local base_angle = math.random() * TWOPI
    for i = 1, SHADOWSTRIKE_COUNT do
        local offset = GetShadowStrikeOffset(i, base_angle)
        self.inst:DoTaskInTime(SHADOWSTRIKE_SPAWN_DELAY * (i - 1), function()
            self:SpawnStalkerShadowStrike(target, shadow_damage, offset)
        end)
    end

    self._doing_shadowstrike = nil
end

function KeiProtocolSlots:DoKlausProtocol(target)
    if math.random() >= (TUNING.KEI_KLAUS_SOUL_CHANCE or 0.20)
        or target == nil
        or not target:IsValid()
        or not WortoxSoulCommon.HasSoul(target)
    then
        return
    end

    local soul = SpawnPrefab("wortox_soul")
    if soul == nil then
        return
    end

    local x, y, z = target.Transform:GetWorldPosition()
    soul.Transform:SetPosition(x, y, z)
    soul.persists = false
    soul.soulhealfinishing = true

    if soul._task ~= nil then
        soul._task:Cancel()
        soul._task = nil
    end
    if soul.components.inventoryitem ~= nil then
        soul.components.inventoryitem.canbepickedup = false
    end

    WortoxSoulCommon.DoHeal(soul)
    soul.AnimState:PlayAnimation("idle_pst")
    soul.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    soul:ListenForEvent("animover", soul.Remove)
end

function KeiProtocolSlots:DoToadstoolProtocol(target)
    local now = GetTime()
    if (self._kei_toadstool_sleepbomb_ready_time or 0) > now
        or math.random() >= (TUNING.KEI_TOADSTOOL_SLEEPBOMB_CHANCE or 0.15)
        or target == nil
        or not target:IsValid()
        or target:IsInLimbo()
    then
        return
    end

    local sleepbomb = SpawnPrefab("sleepbomb")
    if sleepbomb == nil or sleepbomb.components.complexprojectile == nil then
        if sleepbomb ~= nil then
            sleepbomb:Remove()
        end
        return
    end

    sleepbomb.persists = false
    sleepbomb.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
    if self.inst.components.combat ~= nil and self.inst.components.combat:IsValidTarget(target) then
        self.inst:ForceFacePoint(target.Transform:GetWorldPosition())
        sleepbomb.components.complexprojectile:Launch(target:GetPosition(), self.inst, sleepbomb)
        self._kei_toadstool_sleepbomb_ready_time = now + (TUNING.KEI_TOADSTOOL_SLEEPBOMB_COOLDOWN or 0.5)
    else
        sleepbomb:Remove()
    end
end

local function IsValidBeequeenScareTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and target ~= nil
        and target:IsValid()
        and target ~= owner
        and target.entity:IsVisible()
        and not target:IsInLimbo()
        and not target:HasTag("player")
        and not target:HasTag("playerghost")
        and not target:HasTag("epic")
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

local function ScareBeequeenTarget(owner, target, duration)
    if not IsValidBeequeenScareTarget(owner, target) then
        return
    end

    target:PushEvent("epicscare", { scarer = owner, duration = duration })

    if target.components.hauntable ~= nil and target.components.hauntable.panicable then
        target.components.hauntable:Panic(duration)
    end

    if target.components.combat ~= nil and target.components.combat:TargetIs(owner) then
        target.components.combat:SetTarget(nil)
    end
end

function KeiProtocolSlots:SpawnBeequeenScreechFx()
    local fx = SpawnPrefab("battlesong_instant_panic_fx")
    if fx ~= nil then
        fx.Transform:SetNoFaced()
        self.inst:AddChild(fx)
    end

    if self.inst.SoundEmitter ~= nil then
        self.inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/taunt")
    end
    ShakeAllCameras(CAMERASHAKE.FULL, 1, .015, .3, self.inst, 30)
end

function KeiProtocolSlots:DoBeequeenRetaliateProtocol(attacker)
    ScareBeequeenTarget(self.inst, attacker, TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5)
end

function KeiProtocolSlots:DoBeequeenAreaProtocol(attacker)
    if not IsValidBeequeenScareTarget(self.inst, attacker) then
        return
    end

    local now = GetTime()
    if self._kei_beequeen_panic_ready_time ~= nil and now < self._kei_beequeen_panic_ready_time then
        return
    end

    self._kei_beequeen_panic_ready_time = now + (TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN or 3)

    local duration = TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(
        x, y, z,
        TUNING.KEI_BEEQUEEN_PANIC_RADIUS or 8,
        BEEQUEEN_SCARE_MUST_TAGS,
        BEEQUEEN_SCARE_EXCLUDE_TAGS
    )

    self:SpawnBeequeenScreechFx()
    for _, ent in ipairs(ents) do
        ScareBeequeenTarget(self.inst, ent, duration)
    end
end

function KeiProtocolSlots:DoBeequeenProtocol(attacker)
    if TUNING.KEI_BEEQUEEN_PRESTIGE_MODE == "retaliate" then
        self:DoBeequeenRetaliateProtocol(attacker)
    else
        self:DoBeequeenAreaProtocol(attacker)
    end
end

local function ApplyDragonflyBurnVisuals(target)
    local burnable = target ~= nil and target.components.burnable or nil
    if burnable == nil or burnable.fxchildren == nil then
        return
    end

    for _, fx in ipairs(burnable.fxchildren) do
        if fx.AnimState ~= nil then
            fx.AnimState:SetMultColour(
                DRAGONFLY_BURN_COLOUR[1],
                DRAGONFLY_BURN_COLOUR[2],
                DRAGONFLY_BURN_COLOUR[3],
                DRAGONFLY_BURN_COLOUR[4]
            )
        end
        if fx.components.firefx ~= nil and fx.components.firefx.light ~= nil then
            fx.components.firefx.light.Light:SetColour(
                DRAGONFLY_BURN_COLOUR[1],
                DRAGONFLY_BURN_COLOUR[2],
                DRAGONFLY_BURN_COLOUR[3]
            )
        end
    end
end

local function StopDragonflyBurn(target)
    local data = target ~= nil and target._kei_dragonfly_burn_data or nil
    if data == nil then
        return
    end

    target._kei_dragonfly_burn_data = nil
    if data.task ~= nil then
        data.task:Cancel()
    end
    if data.has_old_burntime and target.components.burnable ~= nil then
        target.components.burnable.burntime = data.old_burntime
    end
    if data.onextinguish ~= nil then
        target:RemoveEventCallback("onextinguish", data.onextinguish)
    end
    if data.ondeath ~= nil then
        target:RemoveEventCallback("death", data.ondeath)
    end
    if data.onremove ~= nil then
        target:RemoveEventCallback("onremove", data.onremove)
    end
end

local function StartDragonflyBurn(owner, target)
    if owner == nil
        or target == nil
        or not target:IsValid()
        or target.components.burnable == nil
    then
        return
    end

    local burnable = target.components.burnable
    if burnable:IsBurning() then
        local data = target._kei_dragonfly_burn_data
        if data == nil then
            return
        end

        burnable.burntime = DRAGONFLY_BURN_DURATION
        burnable:ExtendBurning()
        ApplyDragonflyBurnVisuals(target)
        return
    end

    local had_tag = owner:HasTag("controlled_burner")
    if not had_tag then
        owner:AddTag("controlled_burner")
    end
    burnable:Ignite(nil, owner, owner)
    if not had_tag then
        owner:RemoveTag("controlled_burner")
    end

    if not burnable:IsBurning() then
        return
    end

    ApplyDragonflyBurnVisuals(target)
    StopDragonflyBurn(target)

    local data = { old_burntime = burnable.burntime, has_old_burntime = true }
    burnable.burntime = DRAGONFLY_BURN_DURATION
    burnable:ExtendBurning()
    data.onextinguish = function(inst)
        StopDragonflyBurn(inst)
    end
    data.onremove = function(inst)
        StopDragonflyBurn(inst)
    end
    data.ondeath = function(inst)
        StopDragonflyBurn(inst)
    end
    data.task = target:DoPeriodicTask(DRAGONFLY_BURN_DAMAGE_PERIOD, function(inst)
        if inst.components.health == nil or inst.components.health:IsDead() then
            StopDragonflyBurn(inst)
            return
        end
        if inst.components.burnable == nil or not inst.components.burnable:IsBurning() then
            StopDragonflyBurn(inst)
            return
        end

        local max_health = inst.components.health.maxhealth or 0
        local damage = max_health * DRAGONFLY_BURN_MAX_HEALTH_DAMAGE
        if damage > 0 then
            inst.components.health:DoFireDamage(damage, owner, true)
        end
        ApplyDragonflyBurnVisuals(inst)
    end, DRAGONFLY_BURN_DAMAGE_PERIOD)

    target._kei_dragonfly_burn_data = data
    target:ListenForEvent("onextinguish", data.onextinguish)
    target:ListenForEvent("death", data.ondeath)
    target:ListenForEvent("onremove", data.onremove)
end

function KeiProtocolSlots:OnAttacked(data)
    if not self:IsFunctional() or not self.active_combat.beequeen then
        return
    end

    self:DoBeequeenProtocol(data ~= nil and data.attacker or nil)
end

function KeiProtocolSlots:OnHitOther(data)
    if not self:IsFunctional() then
        return
    end

    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() then
        return
    end
    local weapon = data.weapon
    local damage = data.damageresolved or 0

    if self.active_combat.deerclops and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(1)
        target.components.freezable:SpawnShatterFX()
    end

    if self.active_combat.mutateddeerclops then
        self:DoMutatedDeerclopsProtocol()
    end

    if self.active_combat.dragonfly then
        StartDragonflyBurn(self.inst, target)
    end

    if self.active_combat.bearger then
        self:DoBeargerPulse(target, weapon)
    end

    if self.active_combat.minotaur then
        self:DoMinotaurProtocol(target, weapon)
    end

    if self.active_combat.stalker_atrium then
        self:DoStalkerProtocol(target, damage)
    end

    if self.active_combat.klaus then
        self:DoKlausProtocol(target)
    end

    if self.active_combat.toadstool then
        self:DoToadstoolProtocol(target)
    end

    if self.active_combat.antlion then
        self:DoAntlionProtocol(target)
    end

    if self.active_combat.wagboss_robot then
        self:DoWagbossProtocol(target)
    end

    if self.active_combat.alterguardian_phase4_lunarrift then
        self:DoCelestialOrbProtocol(target, damage, weapon)
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
    self:ApplyStatProgression()
    self.inst:DoTaskInTime(0, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)
end

return KeiProtocolSlots
