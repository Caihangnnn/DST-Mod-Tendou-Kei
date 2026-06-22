local LifeProtocolDefs = require("kei/protocols/life")

local LIFE_PROTOCOLS = LifeProtocolDefs.LIFE_PROTOCOLS

--- 战斗协议效果处理器注册表。
local EFFECT_HANDLERS = {
    deerclops                      = require("kei/protocols/effects/deerclops"),
    dragonfly                      = require("kei/protocols/effects/dragonfly"),
    moose                          = require("kei/protocols/effects/moose"),
    toadstool                      = require("kei/protocols/effects/toadstool"),
    malbatross                     = require("kei/protocols/effects/malbatross"),
    bearger                        = require("kei/protocols/effects/bearger"),
    klaus                          = require("kei/protocols/effects/klaus"),
    beequeen                       = require("kei/protocols/effects/beequeen"),
    mutateddeerclops               = require("kei/protocols/effects/mutateddeerclops"),
    stalker_atrium                 = require("kei/protocols/effects/stalker"),
    minotaur                       = require("kei/protocols/effects/minotaur"),
    antlion                        = require("kei/protocols/effects/antlion"),
    alterguardian_phase4_lunarrift = require("kei/protocols/effects/celestial_orb"),
    wagboss_robot                  = require("kei/protocols/effects/wagboss"),
    daywalker2                     = require("kei/protocols/effects/daywalker2"),
}

--- 生活协议效果处理器（导出 Apply 方法，非 EffectHandler 接口）。
local LIFE_EFFECTS = {
    growth_acceleration = require("kei/protocols/effects/growth_acceleration"),
    durability_restore  = require("kei/protocols/effects/durability_restore"),
}

--- 仅做 tag 增删的协议效果。
local TAG_EFFECTS = {
    mutatedbearger   = { "kei_attack_speed_boost" },
    vault_pillar_guard = { "kei_vault_pillar_guard_spin" },
}

local ANALYSIS_ARMOR_MODIFIER = "kei_analysis_armor"
local ANALYSIS_HANDS_MODIFIER = "kei_analysis_hands"

----------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------

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
    if tier == nil then return nil end
    return math.min(GetInitialSlots() + tier * (TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2), GetMaxSlots())
end

local function GetTierPreviousSlots(tier)
    if tier == nil then return nil end
    return math.min(GetInitialSlots() + (tier - 1) * (TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2), GetMaxSlots())
end

local function GetUnlockedTierCount(unlocked_slots)
    local step = TUNING.KEI_PROTOCOL_UNLOCK_STEP or 2
    if step <= 0 then return 0 end
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

----------------------------------------------------------------
-- 构造函数
----------------------------------------------------------------

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
        local stacks = self:GetLifeProtocolCount("growth_acceleration")
        LIFE_EFFECTS.growth_acceleration.Apply(self, self.inst, stacks)
    end)

    self._life_durability_task = inst:DoPeriodicTask(TUNING.KEI_LIFE_DURABILITY_RESTORE_PERIOD or 60, function()
        local stacks = self:GetLifeProtocolCount("durability_restore")
        LIFE_EFFECTS.durability_restore.Apply(self, self.inst, stacks)
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

----------------------------------------------------------------
-- 槽位管理
----------------------------------------------------------------

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
    if inventory == nil then return end

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

----------------------------------------------------------------
-- 状态查询
----------------------------------------------------------------

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
    if protocol == nil or inventory == nil then return false end

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
    if inventory == nil then return end

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
    if not self:IsFunctional() then return false end
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
    if not self:IsFunctional() then return items end
    local inventory = self.inst.components.inventory
    if inventory == nil then return items end

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

----------------------------------------------------------------
-- 虚拟装备
----------------------------------------------------------------

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
    if virtual == nil then return end

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
        if virtual ~= nil then virtual:Remove() end
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

----------------------------------------------------------------
-- 解析手部属性
----------------------------------------------------------------

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

    if HasHandEquipment(self.inst) then return end

    local has_actions = actions ~= nil and next(actions) ~= nil
    if not has_actions and not tough then return end

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

----------------------------------------------------------------
-- 修饰符清理
----------------------------------------------------------------

function KeiProtocolSlots:ClearModifiers()
    self:ClearVirtualEquips()
    self:ClearAnalysisToolActions()
    self:SetAnalysisDamageBonus(0)

    -- 调用所有战斗效果处理器的 Disable。
    for _, handler in pairs(EFFECT_HANDLERS) do
        if handler.Disable then
            handler.Disable(self, self.inst)
        end
    end

    -- 清除 tag-only 效果的标签。
    for _, tags in pairs(TAG_EFFECTS) do
        for _, tag in ipairs(tags) do
            self.inst:RemoveTag(tag)
        end
    end

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

----------------------------------------------------------------
-- 协议查询 API
----------------------------------------------------------------

function KeiProtocolSlots:HasCombatProtocol(protocol)
    return self:IsFunctional() and self.active_combat[protocol] == true
end

function KeiProtocolSlots:GetLifeProtocolCount(protocol)
    return self:IsFunctional() and (self.active_life[protocol] or 0) or 0
end

function KeiProtocolSlots:HasLifeProtocol(protocol)
    return self:GetLifeProtocolCount(protocol) > 0
end

----------------------------------------------------------------
-- 网络同步
----------------------------------------------------------------

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

----------------------------------------------------------------
-- 效果分发
----------------------------------------------------------------

function KeiProtocolSlots:RefreshEffects()
    for protocol, handler in pairs(EFFECT_HANDLERS) do
        local is_active = self.active_combat[protocol] == true
        if is_active then
            if handler.Enable then
                handler.Enable(self, self.inst)
            end
        else
            if handler.Disable then
                handler.Disable(self, self.inst)
            end
        end
    end

    -- tag-only 效果。
    for protocol, tags in pairs(TAG_EFFECTS) do
        if self.active_combat[protocol] then
            for _, tag in ipairs(tags) do
                self.inst:AddTag(tag)
            end
        else
            for _, tag in ipairs(tags) do
                self.inst:RemoveTag(tag)
            end
        end
    end
end

----------------------------------------------------------------
-- 核心刷新与消耗
----------------------------------------------------------------

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
    self:RefreshEffects()
    self:SyncLifeProtocolFlags()
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

----------------------------------------------------------------
-- 事件分发
----------------------------------------------------------------

function KeiProtocolSlots:OnHitOther(data)
    if not self:IsFunctional() then return end
    local target = data and data.target
    if target == nil or not target:IsValid() then return end

    for protocol, handler in pairs(EFFECT_HANDLERS) do
        if self.active_combat[protocol] and handler.OnHitOther then
            handler.OnHitOther(self, self.inst, data)
        end
    end
end

function KeiProtocolSlots:OnAttacked(data)
    if not self:IsFunctional() then return end

    for protocol, handler in pairs(EFFECT_HANDLERS) do
        if self.active_combat[protocol] and handler.OnAttacked then
            handler.OnAttacked(self, self.inst, data)
        end
    end
end

----------------------------------------------------------------
-- 存档 / 读档
----------------------------------------------------------------

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
