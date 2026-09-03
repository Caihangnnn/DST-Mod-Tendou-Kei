local VirtualHandEquipment = {}
local VirtualEquipment = require("kei/protocols/analysis/virtual_equipment")

-- Only these vanilla weapon prefabs receive the virtual-staff attack cooldown.
-- Keep this list explicit: ranged or spellcaster items are not automatically
-- treated as staves.
local VIRTUAL_STAFF_PREFABS = {
    icestaff = true,
    icestaff2 = true,
    icestaff3 = true,
    firestaff = true,
}

function VirtualHandEquipment.IsVirtualStaff(item)
    return item ~= nil
        and item:HasTag("kei_virtual_hand_equipment")
        and VIRTUAL_STAFF_PREFABS[item.kei_source_prefab or item.prefab] == true
end

-- Keep source callbacks safe while disabling armor inheritance.
local function DisableVirtualHandArmor(item)
    local armor = item.components.armor
    if armor == nil then
        return
    end

    if armor.InitIndestructible ~= nil then
        armor:InitIndestructible(0)
    else
        armor.indestructible = true
        armor.absorb_percent = 0
    end

    armor.condition = armor.maxcondition or armor.condition
    armor.onfinished = nil
    armor.ontakedamage = nil
end

-- 清理虚拟装备
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

    VirtualEquipment.GuardBuildDiscount(item)
    DisableVirtualHandArmor(item)
end

-- 断开虚拟装备与当前持有者的归属关系，避免残留在实体层级中
local function ClearVirtualInventoryOwner(item)
    local inventoryitem = item.components.inventoryitem
    if inventoryitem == nil then return end

    local owner = inventoryitem.owner
    if owner ~= nil then
        owner:RemoveChild(item)
    end
    inventoryitem:ClearOwner()
end

-- 延迟移除虚拟装备，避免在回调链中立刻删除导致报错
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

-- 忽略虚拟手部装备在凯伊角色上的已知回调异常，避免中断流程
local function IgnoreVirtualHandCallbackError(item, err)
    local owner = item.components.inventoryitem ~= nil and item.components.inventoryitem.owner or nil
    if owner ~= nil and owner:HasTag("kei") and item:HasTag("kei_virtual_hand_equipment") then
        print("[Tendou Kei] ignored virtual hand equipment callback error: " .. tostring(err))
        return true
    end
    return false
end

-- 为虚拟装备的武器和施法回调加保护包装，屏蔽不兼容装备的运行时错误。
-- 这里的核心思路是：虚拟手持装备并不一定完整模拟原装备的所有上下文，
-- 某些武器或法术回调在被“虚拟装备”触发时可能访问不到预期数据而报错。
-- 因此这里会把关键回调包一层 pcall，仅在凯伊使用虚拟装备时报错时吞掉异常并回退；
-- 如果是真实装备或其他角色触发异常，则继续抛错，避免掩盖正常问题。
local function WrapVirtualHandEquipment(item)
    local weapon = item.components.weapon
    -- 包装伤害计算函数：
    -- 某些武器的 GetDamage 会依赖额外状态，虚拟装备缺少这些状态时可能直接报错。
    -- 如果是凯伊触发，则打印日志并退回到 weapon.damage 的基础伤害，保证攻击流程不断。
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

    -- 包装近战攻击回调：
    -- 原始 onattack 可能会生成特效、附带状态或读取额外组件。
    -- 当这些逻辑与虚拟装备不兼容时，只对凯伊的虚拟手持忽略错误，避免一次攻击把整条逻辑链打断。
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

    -- 包装投射物发射回调：
    -- 有些远程武器会在发射瞬间执行额外逻辑，虚拟装备在这个阶段也可能缺上下文。
    -- 出错时同样只对凯伊虚拟手持做降级处理，其余情况保留原始报错。
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
    -- 包装施法回调：
    -- 部分法杖或法术物品在施法时会校验 owner、库存归属或其他运行环境。
    -- 这里复用统一的异常过滤逻辑，只忽略“凯伊 + 虚拟手部装备”这一类已知可接受错误。
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

-- 移除当前已挂载的虚拟手部装备，并清理背包槽位和所有权
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

-- 根据协议槽数据生成并装备虚拟手部装备，失败时回滚并返回 false
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
    if virtual == nil or virtual.components.equippable == nil or virtual.components.stackable ~= nil then
        if virtual ~= nil then
            ScheduleVirtualEquipmentRemove(virtual)
        end
        return false
    end

    virtual.kei_source_prefab = data.source
    virtual:AddTag("kei_virtual_hand_equipment")
    if VIRTUAL_STAFF_PREFABS[data.source] then
        virtual:AddTag("kei_virtual_staff")
    end
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
