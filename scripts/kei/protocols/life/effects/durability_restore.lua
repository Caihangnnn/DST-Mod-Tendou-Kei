-- 生活协议-物品修理：周期恢复背包内工具/护甲的耐久。

local DurabilityRestore = {}

--- 由 kei_protocolslots 的周期任务调用。
---@param slots table  KeiProtocolSlots 实例
---@param inst  Entity 角色实体
---@param stacks number 该协议的当前叠加层数
function DurabilityRestore.Apply(slots, inst, stacks)
    local inventory = inst.components.inventory
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

return DurabilityRestore
