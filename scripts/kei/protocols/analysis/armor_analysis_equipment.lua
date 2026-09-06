local AnalysisArmorUpgrade = require("kei/analysis_armor_upgrade")
local VirtualEquipment = require("kei/protocols/analysis/virtual_equipment")
local Enchantment = require("kei/integrations/enchantment")

local ArmorAnalysisEquipment = {}

-- 将协议槽编号映射到对应的隐藏装备槽，供虚拟护甲挂载使用
local function HiddenEquipSlot(slot)
    return EQUIPSLOTS["KEI_PROTOCOL_" .. tostring(slot)]
end

-- 根据护甲强化配方制作次数计算护甲吸收缩放：初始 50%，每次增加 10%。
-- 将解析装备提供的护甲吸收率应用到虚拟护甲上
-- 可使用协议数据中的 absorb 覆盖原护甲吸收，否则继承预制体自身的吸收率
local function ApplyArmorAbsorb(virtual, data, absorb_scale)
    local armor = virtual ~= nil and virtual.components ~= nil and virtual.components.armor or nil
    if armor == nil then return end

    local absorb = data ~= nil and data.absorb or nil
    if absorb == nil then
        absorb = armor.absorb_percent
    end
    if absorb == nil then return end

    if armor.SetAbsorption ~= nil then
        armor:SetAbsorption(absorb * absorb_scale)
    else
        armor.absorb_percent = absorb * absorb_scale
    end
end

-- 清理虚拟护甲的交互与持久化能力，使其只作为隐藏装备存在
local function CleanVirtualEquipment(item, equipslot)
    item.persists = false
    item:AddTag("kei_virtual_equipment")
    item:AddTag("NOCLICK")
    item:RemoveTag("heavy")
    item:RemoveTag("repairable")

    if item.components.equippable ~= nil then
        VirtualEquipment.GuardBuildDiscount(item)
        -- A virtual armor copy must not run arbitrary source-prefab equip
        -- callbacks after its fueled/uses components have been removed.
        item.components.equippable:SetOnEquip(nil)
        item.components.equippable:SetOnUnequip(nil)
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

-- 延迟移除虚拟护甲，避免在装备或卸下流程的回调链里直接删除实体
local function ScheduleRemove(item)
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

-- 移除指定协议槽当前挂载的虚拟护甲，并从隐藏装备槽中卸下后清理实体
function ArmorAnalysisEquipment.Remove(protocolslots, slot)
    local virtual = protocolslots.virtual_equips[slot]
    if virtual == nil then return end

    local equipslot = HiddenEquipSlot(slot)
    local inventory = protocolslots.inst.components.inventory
    if inventory ~= nil and equipslot ~= nil and inventory:GetEquippedItem(equipslot) == virtual then
        virtual.kei_allow_virtual_drop = true
        inventory:Unequip(equipslot, true, true)
    end

    if virtual:IsValid() then
        ScheduleRemove(virtual)
    end
    protocolslots.virtual_equips[slot] = nil
end

-- 根据协议数据生成并装备指定槽位的虚拟护甲
-- 如果同源虚拟护甲已经存在，则只更新吸收率而不重复生成
function ArmorAnalysisEquipment.Apply(protocolslots, entry)
    local data = entry.data
    local slot = entry.slot
    local equipslot = HiddenEquipSlot(slot)
    local inventory = protocolslots.inst.components.inventory

    if data.source == nil or equipslot == nil or inventory == nil then
        ArmorAnalysisEquipment.Remove(protocolslots, slot)
        return
    end

    local current = protocolslots.virtual_equips[slot]
    local enchantment_key = Enchantment.GetKey(data.enchantments)
    if current ~= nil
        and current:IsValid()
        and current.kei_source_prefab == data.source
        and current.kei_enchantment_key == enchantment_key
        and inventory:GetEquippedItem(equipslot) == current
    then
        ApplyArmorAbsorb(current, data, AnalysisArmorUpgrade.GetAbsorbScale(protocolslots.inst))
        return
    end

    ArmorAnalysisEquipment.Remove(protocolslots, slot)

    local virtual = SpawnPrefab(data.source)
    if virtual == nil or virtual.components.equippable == nil then
        if virtual ~= nil then virtual:Remove() end
        return
    end

    virtual.kei_source_prefab = data.source
    virtual.kei_enchantment_key = enchantment_key
    Enchantment.Apply(virtual, data.enchantments)
    CleanVirtualEquipment(virtual, equipslot)
    Enchantment.InstallVirtualArmorCallbacks(virtual)
    ApplyArmorAbsorb(virtual, data, AnalysisArmorUpgrade.GetAbsorbScale(protocolslots.inst))

    inventory:Equip(virtual, nil, true)
    if inventory:GetEquippedItem(equipslot) == virtual then
        protocolslots.virtual_equips[slot] = virtual
    else
        ScheduleRemove(virtual)
    end
end

-- 清空当前所有虚拟护甲，可通过 keep 表保留指定槽位
function ArmorAnalysisEquipment.Clear(protocolslots, keep)
    for slot in pairs(protocolslots.virtual_equips) do
        if keep == nil or not keep[slot] then
            ArmorAnalysisEquipment.Remove(protocolslots, slot)
        end
    end
end

return ArmorAnalysisEquipment
