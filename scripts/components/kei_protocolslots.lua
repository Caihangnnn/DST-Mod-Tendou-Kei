local CombatProtocolDefs = require("kei/protocols/combat")
local LifeProtocolDefs = require("kei/protocols/life")
local BasicAttributeProtocolDefs = require("kei/protocols/basic_attributes")
local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")
local AnalysisArmorUpgrade = require("kei/analysis_armor_upgrade")
local LifeRecipeUnlocks = require("kei/protocols/life/recipe_unlocks")
local VirtualHandEquipment = require("kei/protocols/analysis/virtual_hand_equipment")
local HandAnalysisInheritance = require("kei/protocols/analysis/hand_analysis_inheritance")
local ArmorAnalysisEquipment = require("kei/protocols/analysis/armor_analysis_equipment")

local LIFE_PROTOCOLS = LifeProtocolDefs.LIFE_PROTOCOLS
local BASIC_ATTRIBUTE_PROTOCOLS = BasicAttributeProtocolDefs.BASIC_ATTRIBUTE_PROTOCOLS

local function GetCombatEffectPath(def)
    if def.category == "beast" or def.category == "biome" then
        return "kei/protocols/combat/effects/" .. def.category .. "/" .. (def.effect_file or def.protocol)
    end
    return "kei/protocols/combat/effects/" .. (def.effect_file or def.protocol)
end

local function BuildCombatEffectHandlers()
    local handlers = {}
    for _, def in ipairs(CombatProtocolDefs.COMBAT_PROTOCOL_LIST) do
        handlers[def.protocol] = require(GetCombatEffectPath(def))
    end
    return handlers
end

local function BuildLifeEffects()
    local effects = {}
    for _, def in ipairs(LifeProtocolDefs.LIFE_PROTOCOL_LIST) do
        effects[def.protocol] = require("kei/protocols/life/effects/" .. def.protocol)
    end
    return effects
end

--- 战斗协议效果处理器注册表。
local EFFECT_HANDLERS = BuildCombatEffectHandlers()

--- 生活协议效果处理器（导出 Apply 方法，非 EffectHandler 接口）。
local LIFE_EFFECTS = BuildLifeEffects()
local ANALYSIS_ARMOR_MODIFIER = "kei_analysis_armor"
local BASIC_DAMAGE_MODIFIER = "kei_basic_attribute_damage"
local COMBAT_PROTOCOL_DAMAGE_MODIFIER = "kei_combat_protocol_damage"
local BASIC_SPEED_MODIFIER = "kei_basic_attribute_speed"
local BASIC_ABSORB_MODIFIER = "kei_basic_attribute_absorb"

----------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------

local function IsProtocol(item)
    return item ~= nil and item:HasTag("kei_protocol_cd") and item.kei_protocol_data ~= nil
end

local function IsProtocolContainer(item)
    return item ~= nil and item.prefab == "kei_protocol_container"
end

local function ProtocolNeedsPower(data)
    return data.kind == "analysis"
end

local function ProtocolNeedsStability(data)
    return data.kind == "combat"
end

local function GetProtocolDrainSettings()
    return {
        analysis_amount = TUNING.KEI_PROTOCOL_DRAIN_AMOUNT or 1,
        combat_amount = TUNING.KEI_PROTOCOL_DRAIN_AMOUNT or 1,
        cap = TUNING.KEI_PROTOCOL_DRAIN_MAX_PER_PERIOD or 5,
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
    self.unlocked_slots = ProtocolSlotUnlocks.GetInitialSlots()
    self.mini_alice_pages = 1
    self.analysis_armor_upgrade_level = 0
    self.implanted_combat_protocols = {}
    self.implanted_basic_attributes = {}
    self.permanent_life_recipes = {}
    self.active = {}
    self.active_combat = {}
    self.active_life = {}
    self.virtual_equips = {}
    self.virtual_hand_equip = nil
    self.analysis_base_damage_bonus = 0
    self.analysis_tool_actions = {}
    self._kei_worker_action_old_values = {}
    self._kei_tool_action_old_tags = {}
    self._kei_mutateddeerclops_slowed = {}
    self._protocol_state_dirty = true
    self._prev_active_combat = {}
    self.basic_attribute_modifiers = {}
    self._combat_damage_multipliers = {}
    self._combat_damage_reductions = {}
    self._kei_combat_attack_depth = 0
    self._kei_damage_parts_context = 0
    self._kei_damage_parts_multiplier = 1
    self._kei_damage_parts_fixed_bonus = 0
    self._kei_last_damage_parts = nil

    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil then
        self._old_combat_getattacked = combat.GetAttacked
        combat.GetAttacked = function(component, attacker, damage, weapon, stimuli, spdamage, ...)
            local reduction = self.basic_attribute_modifiers.fixed_damage_reduction or 0
            local true_fixed_damage = 0
            local attacker_combat = attacker ~= nil
                and attacker.components ~= nil
                and attacker.components.combat
                or nil
            local damage_parts = attacker_combat ~= nil
                and attacker_combat._kei_last_damage_parts
                or nil
            if type(damage) == "number" then
                if attacker_combat ~= nil
                    and (attacker_combat._kei_damage_parts_context or 0) > 0
                    and damage_parts ~= nil
                    and damage_parts.target == component.inst
                then
                    local attack_multiplier = math.max(0, damage_parts.multiplier or 1)
                    local scalable_damage = (damage_parts.scalable or 0) * attack_multiplier
                    -- Negative fixed damage only offsets the fixed damage segment.
                    -- The resulting true damage segment cannot be below zero.
                    true_fixed_damage = math.max(0, (damage_parts.fixed or 0) * attack_multiplier)
                    damage = math.max(0, scalable_damage - reduction)
                    attacker_combat._kei_last_damage_parts = nil
                else
                    damage = math.max(0, damage - reduction)
                end
            end

            -- 固定伤害减免后、进入原版护甲结算前，执行需要提前结算的防御效果。
            if self._kei_pre_armor_damagefn ~= nil then
                local adjusted_damage = self._kei_pre_armor_damagefn(
                    attacker,
                    damage,
                    weapon,
                    stimuli,
                    spdamage
                )
                if type(adjusted_damage) == "number" then
                    damage = math.max(0, adjusted_damage)
                end
            end
            self._kei_combat_attack_depth = self._kei_combat_attack_depth + 1
            local ok, result = pcall(
                self._old_combat_getattacked,
                component,
                attacker,
                damage,
                weapon,
                stimuli,
                spdamage,
                ...
            )
            self._kei_combat_attack_depth = math.max(0, self._kei_combat_attack_depth - 1)
            if not ok then
                error(result)
            end

            if true_fixed_damage > 0
                and component.inst.components ~= nil
                and component.inst.components.health ~= nil
            then
                -- Bypass armor and percentage damage reduction, but keep the normal
                -- invincibility check and attribute the damage to the attacker.
                component.inst.components.health:DoDelta(
                    -true_fixed_damage,
                    nil,
                    "kei_fixed_damage",
                    nil,
                    attacker,
                    true
                )
            end
            return result
        end

        self._old_combat_calcdamage = combat.CalcDamage
        combat.CalcDamage = function(component, target, weapon, multiplier, ...)
            local base_bonus = self:GetBaseDamageBonus()
            local old_getdamage = nil
            local old_defaultdamage = nil
            local defaultdamage_was_overridden = false
            local damage_source = nil

            if weapon ~= nil
                and weapon.components ~= nil
                and weapon.components.weapon ~= nil
                and weapon.components.weapon.GetDamage ~= nil
                and base_bonus ~= 0
            then
                damage_source = weapon.components.weapon
                old_getdamage = damage_source.GetDamage
                damage_source.GetDamage = function(weapon_component, ...)
                    local basedamage, spdamage = old_getdamage(weapon_component, ...)
                    if type(basedamage) == "number" then
                        basedamage = basedamage + base_bonus
                    end
                    return basedamage, spdamage
                end
            elseif weapon == nil and base_bonus ~= 0 then
                damage_source = component
                if component.inst.components ~= nil
                    and component.inst.components.rider ~= nil
                    and component.inst.components.rider:IsRiding()
                then
                    local mount = component.inst.components.rider:GetMount()
                    if mount ~= nil and mount.components ~= nil and mount.components.combat ~= nil then
                        damage_source = mount.components.combat
                    end
                end
                old_defaultdamage = damage_source.defaultdamage
                damage_source.defaultdamage = (old_defaultdamage or 0) + base_bonus
                defaultdamage_was_overridden = true
            end

            local results = { pcall(
                self._old_combat_calcdamage,
                component,
                target,
                weapon,
                multiplier,
                ...
            ) }

            if old_getdamage ~= nil then
                damage_source.GetDamage = old_getdamage
            end
            if defaultdamage_was_overridden then
                damage_source.defaultdamage = old_defaultdamage
            end
            if not results[1] then
                error(results[2])
            end

            local damage = results[2]
            local fixed_bonus = component._kei_damage_parts_fixed_bonus or 0
            if self._kei_damage_parts_context > 0 and type(damage) == "number" then
                self._kei_last_damage_parts = {
                    target = target,
                    scalable = damage - fixed_bonus,
                    fixed = fixed_bonus,
                    multiplier = self._kei_damage_parts_multiplier or 1,
                }
            end
            return unpack(results, 2)
        end

        self._old_combat_doattack = combat.DoAttack
        combat.DoAttack = function(component, ...)
            local bonus = self.basic_attribute_modifiers.fixed_damage_bonus or 0
            local old_bonus = component.damagebonus or 0
            local old_context = component._kei_damage_parts_context or 0
            local old_multiplier = component._kei_damage_parts_multiplier or 1
            local old_fixed_bonus = component._kei_damage_parts_fixed_bonus or 0
            component.damagebonus = old_bonus + bonus
            component._kei_damage_parts_context = old_context + 1
            component._kei_damage_parts_multiplier = select(5, ...) or 1
            component._kei_damage_parts_fixed_bonus = bonus
            local result = { pcall(self._old_combat_doattack, component, ...) }
            component._kei_damage_parts_context = old_context
            component._kei_damage_parts_multiplier = old_multiplier
            component._kei_damage_parts_fixed_bonus = old_fixed_bonus
            component.damagebonus = old_bonus
            if not result[1] then
                error(result[2])
            end
            return unpack(result, 2)
        end
    end

    local health = inst.components ~= nil and inst.components.health or nil
    if health ~= nil then
        -- Health:DoDelta 会先处理外部百分比减伤，再调用 deltamodifierfn。
        -- 因此基础属性减伤在这里执行时，已经位于护甲和战斗协议减伤之后。
        self._old_health_deltamodifierfn = health.deltamodifierfn
        self._kei_basic_attribute_deltamodifierfn = function(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            if self._old_health_deltamodifierfn ~= nil then
                amount = self._old_health_deltamodifierfn(
                    component,
                    amount,
                    overtime,
                    cause,
                    ignore_invincible,
                    afflicter,
                    ignore_absorb
                )
            end

            local reduction = math.min(
                TUNING.KEI_BASIC_ATTRIBUTE_MAX_DAMAGE_REDUCTION or 90,
                self.basic_attribute_modifiers.percent_damage_reduction or 0
            )
            if type(amount) == "number"
                and amount < 0
                and not ignore_absorb
                and self._kei_combat_attack_depth > 0
            then
                local combat_reduction = self:GetCombatDamageReduction()
                if combat_reduction > 0 then
                    amount = amount * math.max(1 - combat_reduction, 0)
                end
            end

            if type(amount) == "number"
                and amount < 0
                and not ignore_absorb
                and reduction ~= 0
            then
                amount = amount * (1 - reduction / 100)
            end

            -- 这是最后一层固定扣血修正，正值抵扣，负值增加每次生命损失。
            local fixed_health_loss_reduction = self.basic_attribute_modifiers.fixed_health_loss_reduction or 0
            if type(amount) == "number" and amount < 0 then
                amount = math.min(0, amount + fixed_health_loss_reduction)
            end
            return amount
        end
        health.deltamodifierfn = self._kei_basic_attribute_deltamodifierfn
    end

    self:SyncUnlockedSlots()
    self:SyncMiniAlicePages()

    inst:DoTaskInTime(0, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)

    self._refresh_task = inst:DoPeriodicTask(1, function()
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
            self._protocol_state_dirty = true
            self:Refresh()
        end
    end)

    inst:ListenForEvent("unequip", function(_, data)
        if data ~= nil and data.eslot == EQUIPSLOTS.HANDS then
            self._protocol_state_dirty = true
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


    inst:ListenForEvent("itemget", function() self._protocol_state_dirty = true end)
    inst:ListenForEvent("itemlose", function() self._protocol_state_dirty = true end)    inst:ListenForEvent("respawnfromghost", function()
        self._protocol_state_dirty = true
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

function KeiProtocolSlots:SyncProtocolSlotVisuals()
    local visual_vars = self.inst._kei_protocol_slot_visuals
    if visual_vars == nil then
        return
    end

    local inventory = self.inst.components.inventory
    for slot = 1, ProtocolSlotUnlocks.GetMaxSlots() do
        local value = ""
        local protocol_container = inventory ~= nil and inventory:GetItemInSlot(slot) or nil
        local container = protocol_container ~= nil and protocol_container.components.container or nil
        local item = container ~= nil and container:GetItemInSlot(1) or nil
        local inventoryitem = item ~= nil and item.components.inventoryitem or nil
        if inventoryitem ~= nil then
            local image = inventoryitem.imagename or item.prefab
            local atlas = inventoryitem.atlasname or GetInventoryItemAtlas(image .. ".tex")
            if type(atlas) == "string" and atlas ~= "" and type(image) == "string" and image ~= "" then
                value = atlas .. "\t" .. image
            end
        end

        local visual_var = visual_vars[slot]
        if visual_var ~= nil and visual_var:value() ~= value then
            visual_var:set(value)
        end
    end
end

function KeiProtocolSlots:SyncAnalysisArmorUpgrade()
    self.analysis_armor_upgrade_level = AnalysisArmorUpgrade.ClampLevel(
        self.analysis_armor_upgrade_level
    )
    if self.inst._kei_analysis_armor_upgrade_level ~= nil then
        self.inst._kei_analysis_armor_upgrade_level:set(self.analysis_armor_upgrade_level)
    end
end

function KeiProtocolSlots:CanUpgradeAnalysisArmor()
    if self.analysis_armor_upgrade_level >= AnalysisArmorUpgrade.MAX_LEVEL then
        return false, "KEI_ANALYSIS_ARMOR_UPGRADE_MAX"
    end
    return true
end

function KeiProtocolSlots:UpgradeAnalysisArmor()
    local can_upgrade, reason = self:CanUpgradeAnalysisArmor()
    if not can_upgrade then
        return false, reason
    end

    self.analysis_armor_upgrade_level = self.analysis_armor_upgrade_level + 1
    self:SyncAnalysisArmorUpgrade()
    self._protocol_state_dirty = true
    self:Refresh()
    return true
end

function KeiProtocolSlots:SyncMiniAlicePages()
    local max_pages = math.clamp(tonumber(TUNING.KEI_MINI_ALICE_MAX_PAGES) or 7, 1, 7)
    self.mini_alice_pages = math.clamp(
        math.floor(tonumber(self.mini_alice_pages) or 1),
        1,
        max_pages
    )
    if self.inst._kei_mini_alice_pages ~= nil then
        self.inst._kei_mini_alice_pages:set(self.mini_alice_pages)
    end
end

function KeiProtocolSlots:GetStatBonus()
    return ProtocolSlotUnlocks.GetStatBonus(self.unlocked_slots)
end

function KeiProtocolSlots:ApplyStatProgression()
    local max_stats = ProtocolSlotUnlocks.GetStatMaximums(self.unlocked_slots)
    local modifiers = self.basic_attribute_modifiers or {}
    max_stats.integrity = math.max(1, max_stats.integrity + (modifiers.integrity_max or 0))
    max_stats.power = math.max(1, max_stats.power + (modifiers.power_max or 0))
    max_stats.stability = math.max(1, max_stats.stability + (modifiers.stability_max or 0))
    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity

    if health ~= nil and health.maxhealth ~= max_stats.integrity then
        local current = health.currenthealth
        health:SetMaxHealth(max_stats.integrity)
        -- 原版 SetMaxHealth 会将当前生命值设为新上限；属性协议只应修改上限。
        health.currenthealth = math.min(current or max_stats.integrity, health:GetMaxWithPenalty())
    end
    if hunger ~= nil and hunger.max ~= max_stats.power then
        local current = hunger.current
        hunger:SetMax(max_stats.power)
        -- 原版 SetMax 会回满饥饿度；属性协议只应修改电量上限。
        hunger.current = math.min(current or max_stats.power, hunger.max)
    end
    if sanity ~= nil and sanity.max ~= max_stats.stability then
        local current = sanity.current
        sanity:SetMax(max_stats.stability)
        -- 原版 SetMax 会回满精神值；属性协议只应修改稳定性上限。
        sanity.current = math.min(current or max_stats.stability, sanity.max)
    end
end

local function AddBasicAttributeValue(target, data)
    if data == nil
        or data.kind ~= "basic_attribute"
        or BASIC_ATTRIBUTE_PROTOCOLS[data.protocol] == nil
        or data.attribute == nil
        or type(data.attribute_value) ~= "number"
    then
        return
    end
    target[data.attribute] = (target[data.attribute] or 0) + data.attribute_value
end

function KeiProtocolSlots:GetPowerDrainMultiplier()
    local reduction = math.min(
        TUNING.KEI_BASIC_ATTRIBUTE_MAX_POWER_DRAIN_REDUCTION or 90,
        math.max(0, self.basic_attribute_modifiers.power_drain_reduction or 0)
    )
    return math.max(0.1, 1 - reduction / 100)
end

function KeiProtocolSlots:ApplyBasicAttributes(modifiers)
    modifiers = modifiers or {}
    self.basic_attribute_modifiers = modifiers

    self:ApplyStatProgression()

    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    if combat ~= nil then
        combat.externaldamagemultipliers:RemoveModifier(self.inst, BASIC_DAMAGE_MODIFIER)
        local damage_multiplier = math.max(0, 1 + (modifiers.percent_damage_bonus or 0) / 100)
        if damage_multiplier ~= 1 then
            combat.externaldamagemultipliers:SetModifier(self.inst, damage_multiplier, BASIC_DAMAGE_MODIFIER)
        end
    end

    local locomotor = self.inst.components ~= nil and self.inst.components.locomotor or nil
    if locomotor ~= nil then
        locomotor:RemoveExternalSpeedMultiplier(self.inst, BASIC_SPEED_MODIFIER)
        local speed_multiplier = math.max(0, 1 + (modifiers.percent_speed_bonus or 0) / 100)
        if speed_multiplier ~= 1 then
            locomotor:SetExternalSpeedMultiplier(self.inst, BASIC_SPEED_MODIFIER, speed_multiplier)
        end
    end

    local health = self.inst.components ~= nil and self.inst.components.health or nil
    if health ~= nil then
        health.externalabsorbmodifiers:RemoveModifier(self.inst, BASIC_ABSORB_MODIFIER)
    end
end

-- 获取进入原版 CalcDamage 基础伤害段的额外伤害。
function KeiProtocolSlots:GetBaseDamageBonus()
    return (self.basic_attribute_modifiers.base_damage_bonus or 0)
        + (self.analysis_base_damage_bonus or 0)
end

local function RefreshCombatDamageMultiplier(self)
    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    if combat == nil then
        return
    end

    local multiplier = 1
    for _, value in pairs(self._combat_damage_multipliers or {}) do
        multiplier = multiplier + (value - 1)
    end
    multiplier = math.max(0, multiplier)
    combat.externaldamagemultipliers:RemoveModifier(self.inst, COMBAT_PROTOCOL_DAMAGE_MODIFIER)
    if multiplier ~= 1 then
        combat.externaldamagemultipliers:SetModifier(self.inst, multiplier, COMBAT_PROTOCOL_DAMAGE_MODIFIER)
    end
end

-- 战斗协议的攻击倍率统一采用加算，最后以一个乘区接入原版普通伤害。
function KeiProtocolSlots:SetCombatDamageMultiplier(source, multiplier)
    if source == nil then
        return
    end
    if multiplier == nil then
        self._combat_damage_multipliers[source] = nil
    else
        self._combat_damage_multipliers[source] = tonumber(multiplier) or 1
    end
    RefreshCombatDamageMultiplier(self)
end

-- 设置一个战斗协议的攻击减伤来源。该列表只在 Combat:GetAttacked 的扣血路径中使用。
function KeiProtocolSlots:SetCombatDamageReduction(source, value)
    if source == nil then
        return
    end
    if value == nil then
        self._combat_damage_reductions[source] = nil
    else
        self._combat_damage_reductions[source] = math.max(0, tonumber(value) or 0)
    end
end

-- 战斗协议之间采用加算，最终限制在配置的最大减伤以内。
function KeiProtocolSlots:GetCombatDamageReduction()
    local reduction = 0
    for _, value in pairs(self._combat_damage_reductions or {}) do
        reduction = reduction + value
    end
    local maximum_percent = math.min(
        90,
        math.max(0, tonumber(TUNING.KEI_COMBAT_PROTOCOL_MAX_DAMAGE_REDUCTION) or 90)
    )
    return math.min(math.max(reduction, 0), maximum_percent / 100)
end

function KeiProtocolSlots:ConfigureProtocolContainer(container, slot)
    container:AddTag("kei_protocol_slot")
    container.kei_protocol_slot_index = slot

    if container._kei_protocol_slot_contents_fn == nil then
        container._kei_protocol_slot_contents_fn = function()
            self._protocol_state_dirty = true
            self:SyncProtocolSlotVisuals()
        end
        container:ListenForEvent("itemget", container._kei_protocol_slot_contents_fn)
        container:ListenForEvent("itemlose", container._kei_protocol_slot_contents_fn)
    end

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

    local max_slots = ProtocolSlotUnlocks.GetMaxSlots()
    self.unlocked_slots = ProtocolSlotUnlocks.ClampUnlockedSlots(self.unlocked_slots)
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

    for slot = max_slots + 1, ProtocolSlotUnlocks.GetHardMaxSlots() do
        local current = inventory:GetItemInSlot(slot)
        if IsProtocolContainer(current) then
            RemoveProtocolContainer(self.inst, inventory, current)
        end
    end

    self:SyncProtocolSlotVisuals()
end

function KeiProtocolSlots:OnRemoveFromEntity()
    self:ClearModifiers()

    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    if combat ~= nil then
        if self._old_combat_getattacked ~= nil then
            combat.GetAttacked = self._old_combat_getattacked
        end
        if self._old_combat_calcdamage ~= nil then
            combat.CalcDamage = self._old_combat_calcdamage
        end
        if self._old_combat_doattack ~= nil then
            combat.DoAttack = self._old_combat_doattack
        end
    end
end

function KeiProtocolSlots:CanUnlockNextSlot()
    if self.unlocked_slots >= ProtocolSlotUnlocks.GetMaxSlots() then
        return false, "KEI_PROTOCOL_SLOTS_FULL"
    end
    return true
end

function KeiProtocolSlots:UnlockNextSlot()
    local can_unlock, reason = self:CanUnlockNextSlot()
    if not can_unlock then
        return false, reason
    end

    self.unlocked_slots = ProtocolSlotUnlocks.ClampUnlockedSlots(self.unlocked_slots + 1)
    self:SyncUnlockedSlots()
    self:ApplyStatProgression()
    if self.inst.components ~= nil and self.inst.components.kei_experience ~= nil then
        self.inst.components.kei_experience:RecalculateMax()
    end
    self:EnsureProtocolContainers()
    self:Refresh()
    return true
end

function KeiProtocolSlots:CanUnlockMiniAlicePage()
    local max_pages = math.clamp(tonumber(TUNING.KEI_MINI_ALICE_MAX_PAGES) or 7, 1, 7)
    if (self.mini_alice_pages or 1) >= max_pages then
        return false, "KEI_MINI_ALICE_PAGES_FULL"
    end
    return true
end

function KeiProtocolSlots:UnlockMiniAlicePage()
    local can_unlock, reason = self:CanUnlockMiniAlicePage()
    if not can_unlock then
        return false, reason
    end

    self.mini_alice_pages = (self.mini_alice_pages or 1) + 1
    self:SyncMiniAlicePages()
    self._protocol_state_dirty = true
    self.inst:PushEvent("kei_mini_alice_pages_unlocked", {
        pages = self.mini_alice_pages,
    })
    return true
end

function KeiProtocolSlots:GetFirstImplantableProtocol()
    local inventory = self.inst.components ~= nil and self.inst.components.inventory or nil
    if inventory == nil or self.unlocked_slots < ProtocolSlotUnlocks.GetMaxSlots() then
        return nil, nil
    end

    local container = inventory:GetItemInSlot(1)
    if not IsProtocolContainer(container) or container.components.container == nil then
        return nil, nil
    end

    local item = container.components.container:GetItemInSlot(1)
    local data = IsProtocol(item) and item.kei_protocol_data or nil
    if data == nil
        or (data.kind ~= "combat" and data.kind ~= "basic_attribute")
        or data.protocol == nil
    then
        return nil, nil
    end
    return item, data
end

function KeiProtocolSlots:CanDeepImplantFirst()
    local _, data = self:GetFirstImplantableProtocol()
    if data == nil then
        return false, "KEI_DEEP_IMPLANT_NO_PROTOCOL"
    end
    if data.kind == "combat" and self.implanted_combat_protocols[data.protocol] then
        return false, "KEI_DEEP_IMPLANT_ALREADY_IMPLANTED"
    end
    if data.kind == "basic_attribute" and type(data.attribute_value) ~= "number" then
        return false, "KEI_DEEP_IMPLANT_NO_PROTOCOL"
    end
    return true
end

function KeiProtocolSlots:DeepImplantFirst()
    local can_implant, reason = self:CanDeepImplantFirst()
    if not can_implant then
        return false, reason
    end

    local item, data = self:GetFirstImplantableProtocol()
    local inventory = self.inst.components.inventory
    local container = inventory:GetItemInSlot(1)
    local removed = container.components.container:RemoveItem(item, true)
    if removed == nil then
        return false, "KEI_DEEP_IMPLANT_NO_PROTOCOL"
    end

    if data.kind == "combat" then
        self.implanted_combat_protocols[data.protocol] = true
    else
        table.insert(self.implanted_basic_attributes, {
            protocol = data.protocol,
            attribute = data.attribute,
            attribute_value = data.attribute_value,
        })
    end
    if self.inst.components.kei_taskbook ~= nil then
        self.inst.components.kei_taskbook:MarkImplanted(data, removed.prefab)
    end
    removed:Remove()
    self._protocol_state_dirty = true
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
    if protocol == nil then return false end
    if self.implanted_combat_protocols[protocol] then
        return true
    end

    local inventory = self.inst.components.inventory
    if inventory == nil then return false end

    for slot = 1, ProtocolSlotUnlocks.GetMaxSlots() do
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
    return self:HasProtocolInUnlockedSlots("stalker_atrium") or self:HasProtocolInUnlockedSlots("stalker_atrium_basic")
end

function KeiProtocolSlots:AlterguardianProtocolOverridesPower()
    if not (self:HasProtocolInUnlockedSlots("alterguardian") or self:HasProtocolInUnlockedSlots("alterguardian_basic")) then
        return false
    end
    local sanity = self.inst.components.sanity
    return sanity == nil or sanity.current > 0 or self:StalkerProtocolOverridesStability()
end

function KeiProtocolSlots:SetProtocolContainersPowered(powered)
    local inventory = self.inst.components.inventory
    if inventory == nil then return end

    for slot = 1, ProtocolSlotUnlocks.GetMaxSlots() do
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
        and data.protocol ~= "stalker_atrium" and data.protocol ~= "stalker_atrium_basic"
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

    for slot = 1, ProtocolSlotUnlocks.GetMaxSlots() do
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
    local max_slots = math.min(ProtocolSlotUnlocks.GetMaxSlots(), binder_container.numslots or 0)

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
        -- 交换直接改动了协议容器内容，不一定触发 itemget/itemlose；强制重新读取并应用全部协议效果。
        self._protocol_state_dirty = true
        self:Refresh()
    end
    return swapped
end

----------------------------------------------------------------
-- 解析虚拟装备
----------------------------------------------------------------

function KeiProtocolSlots:RemoveVirtualEquip(slot)
    return ArmorAnalysisEquipment.Remove(self, slot)
end

function KeiProtocolSlots:ApplyVirtualEquip(entry)
    return ArmorAnalysisEquipment.Apply(self, entry)
end

function KeiProtocolSlots:ClearVirtualEquips(keep)
    return ArmorAnalysisEquipment.Clear(self, keep)
end

function KeiProtocolSlots:RemoveHandVirtualEquip()
    return VirtualHandEquipment.Remove(self)
end

function KeiProtocolSlots:ApplyHandVirtualEquip(entry)
    return VirtualHandEquipment.Apply(self, entry)
end

----------------------------------------------------------------
-- 修饰符清理
----------------------------------------------------------------

function KeiProtocolSlots:ClearModifiers()
    self:RemoveHandVirtualEquip()
    self:ClearVirtualEquips()
    HandAnalysisInheritance.Clear(self)
    for _, handler in pairs(LIFE_EFFECTS) do
        if handler.Disable then
            handler.Disable(self, self.inst)
        end
    end

    -- 调用所有战斗效果处理器的 Disable。
    for _, handler in pairs(EFFECT_HANDLERS) do
        if handler.Disable then
            handler.Disable(self, self.inst)
        end
    end

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, ANALYSIS_ARMOR_MODIFIER)
        self.inst.components.health.externalfiredamagemultipliers:RemoveModifier(self.inst)
        if self.inst.components.health.deltamodifierfn == self._kei_basic_attribute_deltamodifierfn then
            self.inst.components.health.deltamodifierfn = self._old_health_deltamodifierfn
        end
    end
    self._combat_damage_reductions = {}
    self._combat_damage_multipliers = {}
    RefreshCombatDamageMultiplier(self)
    self:ApplyBasicAttributes({})
end

function KeiProtocolSlots:DisableAllProtocols()
    self.active = {}
    self.active_combat = {}
    self.active_life = {}
    self.active_basic_attributes = {}
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

function KeiProtocolSlots:IsLifeRecipeUnlocked(recipe)
    return self.permanent_life_recipes ~= nil
        and self.permanent_life_recipes[recipe] == true
end

function KeiProtocolSlots:ConsumeLifeProtocol(protocol)
    if protocol == nil or not self:IsFunctional() then
        return false
    end

    local inventory = self.inst.components ~= nil and self.inst.components.inventory or nil
    if inventory == nil then
        return false
    end

    for slot = 1, ProtocolSlotUnlocks.GetMaxSlots() do
        local protocol_container = inventory:GetItemInSlot(slot)
        local container = protocol_container ~= nil
            and IsProtocolContainer(protocol_container)
            and protocol_container.components ~= nil
            and protocol_container.components.container
            or nil
        local item = container ~= nil and container:GetItemInSlot(1) or nil
        local data = IsProtocol(item) and item.kei_protocol_data or nil

        if slot <= self.unlocked_slots
            and data ~= nil
            and data.kind == "life"
            and data.protocol == protocol
            and self:CanRun(data)
        then
            local consumed = container:RemoveItemBySlot(1, true)
            if consumed == nil then
                return false
            end

            if consumed:IsValid() then
                consumed:Remove()
            end

            self._protocol_state_dirty = true
            self:Refresh()
            return true
        end
    end

    return false
end

----------------------------------------------------------------
-- 网络同步
----------------------------------------------------------------

function KeiProtocolSlots:SyncLifeProtocolFlags()
    if self.inst._kei_map_teleport_protocol_active ~= nil then
        self.inst._kei_map_teleport_protocol_active:set(self:HasLifeProtocol("map_teleport"))
    end
    if self.inst._kei_water_walk_protocol_active ~= nil then
        self.inst._kei_water_walk_protocol_active:set(self:HasLifeProtocol("water_walk"))
    end
end

function KeiProtocolSlots:SyncCombatProtocolFlags()
    if self.inst._kei_eyeofterror_protocol_active ~= nil then
        self.inst._kei_eyeofterror_protocol_active:set(self:HasCombatProtocol("eyeofterror") or self:HasCombatProtocol("eyeofterror_basic"))
    end
    local daywalker_active = self:HasCombatProtocol("daywalker") or self:HasCombatProtocol("daywalker_basic")
    if self.inst._kei_daywalker_protocol_active ~= nil then
        self.inst._kei_daywalker_protocol_active:set(daywalker_active)
    end

    if self.inst._kei_mutatedwarg_protocol_active ~= nil then
        self.inst._kei_mutatedwarg_protocol_active:set(self:HasCombatProtocol("mutatedwarg"))
    end
    if self.inst._kei_rook_protocol_active ~= nil then
        self.inst._kei_rook_protocol_active:set(self:HasCombatProtocol("rook"))
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

function KeiProtocolSlots:RefreshLifeEffects()
    LifeRecipeUnlocks.Sync(self.inst)
    for protocol, handler in pairs(LIFE_EFFECTS) do
        local stacks = self.active_life[protocol] or 0
        if stacks > 0 then
            if handler.Enable then
                handler.Enable(self, self.inst, stacks)
            end
        else
            if handler.Disable then
                handler.Disable(self, self.inst)
            end
        end
    end
end

function KeiProtocolSlots:RefreshEffects()
    self:RefreshLifeEffects()
    local prev = self._prev_active_combat or {}
    self._prev_active_combat = {}


    for protocol, handler in pairs(EFFECT_HANDLERS) do
        local is_active = self.active_combat[protocol] == true
        self._prev_active_combat[protocol] = is_active
        local was_active = prev[protocol] == true

        if is_active and not was_active then
            if handler.Enable then
                handler.Enable(self, self.inst)
            end
        elseif not is_active and was_active then
            if handler.Disable then
                handler.Disable(self, self.inst)
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

    if not self._protocol_state_dirty and next(self.active_combat or {}) == nil and next(self.active_life or {}) == nil then
        return
    end

    local items = self._protocol_state_dirty and self:GetProtocolSlotItems() or self.active
    self._protocol_state_dirty = nil
    local combat = {}
    local life = {}
    local basic_attributes = {}
    local hand_stats = HandAnalysisInheritance.NewStats()
    local desired_virtuals = {}
    local wants_hand_virtual = false

    self.active = items

    for _, entry in ipairs(items) do
        local data = entry.data
        if self.inst.components.kei_taskbook ~= nil then
            self.inst.components.kei_taskbook:RecordProtocolData(data, entry.item.prefab)
        end
        if data.kind == "combat" and data.protocol ~= nil then
            combat[data.protocol] = true
        elseif data.kind == "life" and data.protocol ~= nil then
            local definition = LIFE_PROTOCOLS[data.protocol]
            if definition ~= nil and definition.stackable == true then
                life[data.protocol] = (life[data.protocol] or 0) + 1
            else
                life[data.protocol] = 1
            end
        elseif data.kind == "basic_attribute" then
            AddBasicAttributeValue(basic_attributes, data)
        elseif data.kind == "analysis" then
            if data.slot == "head" or data.slot == "body" then
                desired_virtuals[entry.slot] = true
                self:ApplyVirtualEquip(entry)
            elseif data.slot == "hands" then
                if entry.slot == 1 then
                    -- 第一格是完整继承：虚拟手部装备无法生成时，第一格协议整体不生效。
                    if not self._kei_suppress_hand_virtual and self:ApplyHandVirtualEquip(entry) then
                        wants_hand_virtual = true
                    end
                else
                    -- 只有第二格及之后的手部协议才提供 2 类继承的面板伤害。
                    HandAnalysisInheritance.AddStats(hand_stats, data)
                end
            end
        end
    end

    self:ClearVirtualEquips(desired_virtuals)
    if not wants_hand_virtual then
        self:RemoveHandVirtualEquip()
    end
    for protocol in pairs(self.implanted_combat_protocols) do
        combat[protocol] = true
    end
    for _, data in ipairs(self.implanted_basic_attributes) do
        AddBasicAttributeValue(basic_attributes, data)
    end

    self.active_combat = combat
    self.active_life = life
    self.active_basic_attributes = basic_attributes
    self:ApplyBasicAttributes(basic_attributes)
    self:RefreshEffects()
    self:SyncLifeProtocolFlags()
    self:SyncCombatProtocolFlags()

    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, ANALYSIS_ARMOR_MODIFIER)
    end
    HandAnalysisInheritance.Apply(self, hand_stats)
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
            power_cost = power_cost + drain.analysis_amount
        elseif ProtocolNeedsStability(data) then
            stability_cost = stability_cost + drain.combat_amount
        end
    end

    if self.active_combat.lordfruitfly_basic then
        power_cost = power_cost * 0.5
        stability_cost = stability_cost * 0.5
    end

    power_cost = math.min(power_cost, drain.cap)
    stability_cost = math.min(stability_cost, drain.cap)

    local silent_drain = not TUNING.KEI_PROTOCOL_DRAIN_SOUND
    if power_cost > 0 and self.inst.components.hunger ~= nil then
        self.inst.components.hunger:DoDelta(-power_cost * self:GetPowerDrainMultiplier(), silent_drain)
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
        mini_alice_pages = self.mini_alice_pages,
        implanted_combat_protocols = self.implanted_combat_protocols,
        implanted_basic_attributes = self.implanted_basic_attributes,
        permanent_life_recipes = self.permanent_life_recipes,
        analysis_armor_upgrade_level = self.analysis_armor_upgrade_level,
    }
end

function KeiProtocolSlots:OnLoad(data)
    if data ~= nil and data.unlocked_slots ~= nil then
        self.unlocked_slots = ProtocolSlotUnlocks.ClampUnlockedSlots(data.unlocked_slots)
    end
    self.mini_alice_pages = data ~= nil and data.mini_alice_pages or 1
    self.analysis_armor_upgrade_level = AnalysisArmorUpgrade.ClampLevel(
        data ~= nil and data.analysis_armor_upgrade_level or 0
    )
    if self.inst.components ~= nil and self.inst.components.kei_experience ~= nil then
        self.inst.components.kei_experience:RecalculateMax()
    end
    self.implanted_combat_protocols = data ~= nil and data.implanted_combat_protocols or {}
    self.implanted_basic_attributes = data ~= nil and data.implanted_basic_attributes or {}
    self.permanent_life_recipes = data ~= nil and data.permanent_life_recipes or {}
    self:SyncUnlockedSlots()
    self:SyncMiniAlicePages()
    self:SyncAnalysisArmorUpgrade()
    self:ApplyStatProgression()
    self.inst:DoTaskInTime(0, function()
        self:EnsureProtocolContainers()
        self:Refresh()
    end)
end

return KeiProtocolSlots
