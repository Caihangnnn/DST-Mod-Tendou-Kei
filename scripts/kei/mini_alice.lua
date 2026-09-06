-- 娇小爱丽丝的分页容量与槽位访问规则。

local MiniAlice = {}
local ClientSettings

MiniAlice.SLOTS_PER_PAGE = 8
MiniAlice.DISPLAY_MODE_PAGE = 1
MiniAlice.DISPLAY_MODE_EXPANDED = 2
MiniAlice.DISPLAY_MODE_FUSED = 3
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
    if TheNet ~= nil and not TheNet:IsDedicated() then
        ClientSettings = ClientSettings or require("kei/client_settings")
        if ClientSettings.GetMiniAliceArrowMode ~= nil then
            return math.clamp(ClientSettings:GetMiniAliceArrowMode(), 1, 4)
        end
    end
    return MiniAlice.ARROW_MODE_BOTH
end

function MiniAlice.GetDisplayMode()
    if TheNet ~= nil and not TheNet:IsDedicated() then
        ClientSettings = ClientSettings or require("kei/client_settings")
        if ClientSettings.GetMiniAliceDisplayMode ~= nil then
            return math.clamp(ClientSettings:GetMiniAliceDisplayMode(), 1, 3)
        end
    end
    return MiniAlice.DISPLAY_MODE_PAGE
end

function MiniAlice.GetFusionPages()
    if TheNet ~= nil and not TheNet:IsDedicated() then
        ClientSettings = ClientSettings or require("kei/client_settings")
        if ClientSettings.GetMiniAliceFusionPages ~= nil then
            return ClientSettings:GetMiniAliceFusionPages() == 3 and 3 or 2
        end
    end
    return 2
end

local ARROW_MODE_NAMES = {
    [MiniAlice.ARROW_MODE_BOTH] = "模式一",
    [MiniAlice.ARROW_MODE_BOTH_LOOP] = "模式二",
    [MiniAlice.ARROW_MODE_LEFT_LOOP] = "模式三",
    [MiniAlice.ARROW_MODE_RIGHT_LOOP] = "模式四",
}

local DISPLAY_MODE_NAMES = {
    [MiniAlice.DISPLAY_MODE_PAGE] = "翻页",
    [MiniAlice.DISPLAY_MODE_EXPANDED] = "展开",
    [MiniAlice.DISPLAY_MODE_FUSED] = "融合",
}

local DISPLAY_MODE_RULES = {
    [MiniAlice.DISPLAY_MODE_PAGE] = "一次显示一页，使用左右箭头切换页面。",
    [MiniAlice.DISPLAY_MODE_EXPANDED] = "显示全部已解锁页面，第一页在最下方。",
    [MiniAlice.DISPLAY_MODE_FUSED] = "同时显示设定数量的页面，使用左右箭头切换页面组。",
}

function MiniAlice.GetDisplayModeName(mode)
    mode = math.clamp(tonumber(mode) or MiniAlice.GetDisplayMode(), 1, 3)
    return DISPLAY_MODE_NAMES[mode]
end

function MiniAlice.GetDisplayModeRule(mode)
    mode = math.clamp(tonumber(mode) or MiniAlice.GetDisplayMode(), 1, 3)
    return DISPLAY_MODE_RULES[mode]
end

local ARROW_MODE_RULES = {
    [MiniAlice.ARROW_MODE_BOTH] = "显示左右两侧箭头，到达首页或尾页时禁用对应箭头。",
    [MiniAlice.ARROW_MODE_BOTH_LOOP] = "显示左右两侧箭头，到达首页或尾页时循环到另一端。",
    [MiniAlice.ARROW_MODE_LEFT_LOOP] = "只显示左侧箭头，在首页继续向左时循环到尾页。",
    [MiniAlice.ARROW_MODE_RIGHT_LOOP] = "只显示右侧箭头，在尾页继续向右时循环到首页。",
}

function MiniAlice.GetArrowModeName(mode)
    mode = math.clamp(tonumber(mode) or MiniAlice.GetArrowMode(), 1, 4)
    return ARROW_MODE_NAMES[mode]
end

function MiniAlice.GetArrowModeRule(mode)
    mode = math.clamp(tonumber(mode) or MiniAlice.GetArrowMode(), 1, 4)
    return ARROW_MODE_RULES[mode]
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

function MiniAlice.GetFusionPageStart(page, page_count, fusion_pages)
    page_count = math.max(tonumber(page_count) or 1, 1)
    fusion_pages = fusion_pages == 3 and 3 or 2
    page = math.clamp(math.floor(tonumber(page) or 1), 1, page_count)
    return math.floor((page - 1) / fusion_pages) * fusion_pages + 1
end

function MiniAlice.GetPreviousFusionPage(page, page_count, fusion_pages)
    page_count = math.max(tonumber(page_count) or 1, 1)
    fusion_pages = fusion_pages == 3 and 3 or 2
    local start = MiniAlice.GetFusionPageStart(page, page_count, fusion_pages)
    if start > 1 then
        return start - fusion_pages
    end
    return MiniAlice.IsArrowLooping()
        and MiniAlice.GetFusionPageStart(page_count, page_count, fusion_pages)
        or start
end

function MiniAlice.GetNextFusionPage(page, page_count, fusion_pages)
    page_count = math.max(tonumber(page_count) or 1, 1)
    fusion_pages = fusion_pages == 3 and 3 or 2
    local start = MiniAlice.GetFusionPageStart(page, page_count, fusion_pages)
    local next_start = start + fusion_pages
    if next_start <= page_count then
        return next_start
    end
    return MiniAlice.IsArrowLooping() and 1 or start
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

    -- Container:OnLoad runs before the Alice item is attached to the
    -- player's inventory, so the owner's unlocked-page count is unavailable.
    if container._kei_mini_alice_loading then
        return slot >= 1 and slot <= container:GetNumSlots()
    end

    local owner = GetContainerOwner(container)

    return slot >= 1 and slot <= MiniAlice.GetAccessibleSlotCount(owner)
end

return MiniAlice
