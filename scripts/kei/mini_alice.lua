-- 娇小爱丽丝的分页容量与槽位访问规则。

local MiniAlice = {}

MiniAlice.SLOTS_PER_PAGE = 8
MiniAlice.ARROW_MODE_BOTH = 1
MiniAlice.ARROW_MODE_BOTH_LOOP = 2
MiniAlice.ARROW_MODE_LEFT_LOOP = 3
MiniAlice.ARROW_MODE_RIGHT_LOOP = 4

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
    return math.clamp(tonumber(TUNING.KEI_MINI_ALICE_MAX_PAGES) or 7, 1, 7)
end

function MiniAlice.GetArrowMode()
    return math.clamp(tonumber(TUNING.KEI_MINI_ALICE_ARROW_MODE) or MiniAlice.ARROW_MODE_BOTH, 1, 4)
end

function MiniAlice.HasLeftArrow()
    local mode = MiniAlice.GetArrowMode()
    return mode == MiniAlice.ARROW_MODE_BOTH
        or mode == MiniAlice.ARROW_MODE_BOTH_LOOP
        or mode == MiniAlice.ARROW_MODE_LEFT_LOOP
end

function MiniAlice.HasRightArrow()
    local mode = MiniAlice.GetArrowMode()
    return mode == MiniAlice.ARROW_MODE_BOTH
        or mode == MiniAlice.ARROW_MODE_BOTH_LOOP
        or mode == MiniAlice.ARROW_MODE_RIGHT_LOOP
end

function MiniAlice.IsArrowLooping()
    return MiniAlice.GetArrowMode() ~= MiniAlice.ARROW_MODE_BOTH
end

function MiniAlice.GetPreviousPage(page, page_count)
    page = math.clamp(page or 1, 1, page_count or 1)
    if page > 1 then
        return page - 1
    end
    return MiniAlice.IsArrowLooping() and math.max(page_count or 1, 1) or page
end

function MiniAlice.GetNextPage(page, page_count)
    page_count = math.max(page_count or 1, 1)
    page = math.clamp(page or 1, 1, page_count)
    if page < page_count then
        return page + 1
    end
    return MiniAlice.IsArrowLooping() and 1 or page
end

function MiniAlice.GetUnlockedPages(owner)
    if owner == nil then
        return 1
    end

    local pages
    if owner.components ~= nil
        and owner.components.kei_protocolslots ~= nil
    then
        pages = owner.components.kei_protocolslots.mini_alice_pages
    elseif owner._kei_mini_alice_pages ~= nil then
        pages = owner._kei_mini_alice_pages:value()
    end

    return math.clamp(tonumber(pages) or 1, 1, MiniAlice.GetMaxPages())
end

function MiniAlice.GetAccessibleSlotCount(owner)
    return MiniAlice.GetUnlockedPages(owner) * MiniAlice.SLOTS_PER_PAGE
end

local function GetContainerOwner(container)
    local inst = container ~= nil and container.inst or nil
    local inventoryitem = inst ~= nil
        and inst.components ~= nil
        and inst.components.inventoryitem
        or nil

    if inventoryitem ~= nil then
        if inventoryitem.GetGrandOwner ~= nil then
            return inventoryitem:GetGrandOwner() or inventoryitem.owner
        end
        return inventoryitem.owner
    end

    -- 客户端通常只有 replica；娇小爱丽丝只能由自己的持有者打开，
    -- 因此使用本地玩家作为当前分页权限的所有者。
    local inventoryitem_replica = inst ~= nil
        and inst.replica ~= nil
        and inst.replica.inventoryitem
        or nil
    if inventoryitem_replica ~= nil
        and ThePlayer ~= nil
        and inventoryitem_replica.IsGrandOwner ~= nil
        and inventoryitem_replica:IsGrandOwner(ThePlayer)
    then
        return ThePlayer
    end

    local replica_container = container ~= nil and container.IsOpenedBy ~= nil and container or nil
    if replica_container ~= nil and ThePlayer ~= nil and replica_container:IsOpenedBy(ThePlayer) then
        return ThePlayer
    end

    -- 服务端容器可能暂时还没有同步 inventoryitem.owner，使用当前开启者兜底。
    if container ~= nil and container.openlist ~= nil then
        for opener in pairs(container.openlist) do
            return opener
        end
    end
    if container ~= nil and container.opener ~= nil then
        return container.opener
    end
end

function MiniAlice.IsSlotAccessible(container, slot)
    if container == nil or slot == nil then
        return true
    end

    local owner = GetContainerOwner(container)

    return slot >= 1 and slot <= MiniAlice.GetAccessibleSlotCount(owner)
end

return MiniAlice
