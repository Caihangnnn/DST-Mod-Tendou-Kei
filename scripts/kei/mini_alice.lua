-- 娇小爱丽丝的分页容量与槽位访问规则。

local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")

local MiniAlice = {}

MiniAlice.SLOTS_PER_PAGE = 8

function MiniAlice.IsContainer(container)
    return container ~= nil
        and container.inst ~= nil
        and container.inst:HasTag("kei_mini_alice")
end

function MiniAlice.GetContainer(owner)
    local inventory = owner ~= nil and owner.components ~= nil and owner.components.inventory or nil
    if inventory == nil then
        return nil
    end

    for slot = 1, inventory.maxslots do
        local item = inventory:GetItemInSlot(slot)
        if item ~= nil
            and item:HasTag("kei_mini_alice")
            and item.components ~= nil
            and item.components.container ~= nil
        then
            return item.components.container
        end
    end
end

function MiniAlice.GetOpenContainer(owner)
    local container = MiniAlice.GetContainer(owner)
    return container ~= nil and container:IsOpenedBy(owner) and container or nil
end

function MiniAlice.GetMaxPages()
    return math.clamp(tonumber(TUNING.KEI_MINI_ALICE_MAX_PAGES) or 1, 1, 7)
end

function MiniAlice.GetUnlockedPages(owner)
    if owner == nil then
        return 1
    end

    local unlocked_slots = ProtocolSlotUnlocks.GetUnlockedSlots(owner)
    return math.clamp(unlocked_slots, 1, MiniAlice.GetMaxPages())
end

function MiniAlice.GetAccessibleSlotCount(owner)
    return MiniAlice.GetUnlockedPages(owner) * MiniAlice.SLOTS_PER_PAGE
end

function MiniAlice.IsSlotAccessible(container, slot)
    if container == nil or slot == nil then
        return true
    end

    local owner = container.inst ~= nil
        and container.inst.components ~= nil
        and container.inst.components.inventoryitem ~= nil
        and container.inst.components.inventoryitem.owner
        or nil

    return slot >= 1 and slot <= MiniAlice.GetAccessibleSlotCount(owner)
end

return MiniAlice
