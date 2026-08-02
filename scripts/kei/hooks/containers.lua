local containers = require("containers")
local MiniAlice = require("kei/mini_alice")

local mini_alice_max_slots = MiniAlice.GetMaxPages() * MiniAlice.SLOTS_PER_PAGE
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS or 0, mini_alice_max_slots)

containers.params.kei_protocol_container = deepcopy(containers.params.wx78_inventorycontainer)
containers.params.kei_protocol_container.itemtestfn = function(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end
containers.params.kei_protocol_container.priorityfn = nil
containers.params.kei_protocol_container.widget.animbank = "kei_protocol_popup"
containers.params.kei_protocol_container.widget.animbuild = "kei_protocol_popup"
containers.params.kei_protocol_container.widget.slotpos = {
    Vector3(0, -7, 0),
}
containers.params.kei_protocol_container.widget.slotscale = 1.3
containers.params.kei_protocol_container.widget.slothighlightscale = 1.15
containers.params.kei_protocol_container.widget.animloop = nil
containers.params.kei_protocol_container.widget.slotbg = {
    {
        atlas = "images/inventoryimages/transparent_slot.xml",
        image = "transparent_slot.tex",
    },
}
containers.params.kei_protocol_container.widget.animfn = function(container, doer, anim)
    if anim == "open" then
        return "opening"
    elseif anim == "close" then
        return "closing"
    end
    return anim
end

local function ContainerHasRoomForItem(container, item)
    if container == nil
        or item == nil
        or not container:CanTakeItemInSlot(item)
    then
        return false
    end

    for slot = 1, container:GetNumSlots() do
        local stored = container:GetItemInSlot(slot)
        if stored == nil then
            if container:CanTakeItemInSlot(item, slot) then
                return true
            end
        elseif container:AcceptsStacks()
            and stored.components.stackable ~= nil
            and not stored.components.stackable:IsFull()
            and stored.components.stackable:CanStackWith(item)
            and container:CanTakeItemInSlot(item, slot)
        then
            return true
        end
    end

    return false
end

local function FindOpenProtocolBinderWithRoom(opener, item)
    local inventory = opener ~= nil and opener.components.inventory or nil
    if inventory == nil then
        return nil
    end

    for container_inst in pairs(inventory.opencontainers) do
        local container = container_inst.components.container
        if container_inst:HasTag("kei_protocol_binder")
            and container ~= nil
            and container:IsOpenedBy(opener)
            and ContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

local function FindOpenMiniAliceWithRoom(opener, item)
    local inventory = opener ~= nil and opener.components.inventory or nil
    if inventory == nil then
        return nil
    end

    for container_inst in pairs(inventory.opencontainers) do
        local container = container_inst.components.container
        if container_inst:HasTag("kei_mini_alice")
            and container ~= nil
            and container:IsOpenedBy(opener)
            and ContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

local function InventoryHasMainRoomForItem(inventory, item)
    if inventory == nil
        or item == nil
        or not inventory:IsOpenedBy(inventory.inst)
    then
        return false
    end

    for slot = 1, inventory.maxslots do
        local stored = inventory:GetItemInSlot(slot)
        if stored == nil then
            if inventory:CanTakeItemInSlot(item, slot) then
                return true
            end
        elseif stored.components.stackable ~= nil
            and not stored.components.stackable:IsFull()
            and stored.components.stackable:CanStackWith(item)
            and inventory:CanTakeItemInSlot(item, slot)
        then
            return true
        end
    end

    return false
end

local function FindProtocolMoveDestination(opener, item)
    local inventory = opener ~= nil and opener.components.inventory or nil
    if inventory == nil or item == nil then
        return nil
    end

    -- Keep this order identical to the client-side prediction below.
    local binder = FindOpenProtocolBinderWithRoom(opener, item)
    if binder ~= nil then
        return binder
    end

    if InventoryHasMainRoomForItem(inventory, item) then
        return opener
    end

    local alice = FindOpenMiniAliceWithRoom(opener, item)
    if alice ~= nil then
        return alice
    end

    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil
        and overflow:IsOpenedBy(opener)
        and ContainerHasRoomForItem(overflow, item)
    then
        return overflow.inst
    end
end

AddComponentPostInit("container", function(self)
    local old_CanTakeItemInSlot = self.CanTakeItemInSlot
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    local old_MoveItemFromCountOfSlot = self.MoveItemFromCountOfSlot
    local old_RemoveItemBySlot = self.RemoveItemBySlot
    local old_DropItemBySlot = self.DropItemBySlot
    local old_RemoveItem = self.RemoveItem

    local function IsMiniAliceContainer(container)
        return container ~= nil
            and container.inst ~= nil
            and container.inst:HasTag("kei_mini_alice")
    end

    local function IsAccessibleMiniAliceSlot(container, slot)
        return not IsMiniAliceContainer(container)
            or MiniAlice.IsSlotAccessible(container, slot)
    end

    local function IsAllowedControllerDestination(container, opener, item)
        if item == nil or not item:HasTag("kei_rotor_survey_controller") then
            return true
        end
        if container == nil or opener == nil or opener.userid == nil then
            return false
        end
        if container == opener then
            return item.GetControllerOwnerUserId ~= nil
                and item:GetControllerOwnerUserId() == opener.userid
        end
        if not container:HasTag("kei_mini_alice") then
            return false
        end
        local inventoryitem = container.components ~= nil
            and container.components.inventoryitem or nil
        return inventoryitem ~= nil
            and inventoryitem:GetGrandOwner() == opener
            and item.GetControllerOwnerUserId ~= nil
            and item:GetControllerOwnerUserId() == opener.userid
    end

    function self:CanTakeItemInSlot(item, slot)
        if item ~= nil and item:HasTag("kei_rotor_survey_controller") then
            if not self.inst:HasTag("kei_mini_alice") then
                return false
            end

            local inventoryitem = self.inst.components ~= nil and self.inst.components.inventoryitem or nil
            local owner = inventoryitem ~= nil and inventoryitem:GetGrandOwner() or nil
            return item.GetControllerOwnerUserId ~= nil
                and owner ~= nil
                and owner.userid ~= nil
                and item:GetControllerOwnerUserId() == owner.userid
        end
        return old_CanTakeItemInSlot(self, item, slot)
    end

    function self:RemoveItemBySlot(slot, ...)
        if not IsAccessibleMiniAliceSlot(self, slot) then
            return nil
        end
        return old_RemoveItemBySlot(self, slot, ...)
    end

    function self:DropItemBySlot(slot, ...)
        if not IsAccessibleMiniAliceSlot(self, slot) then
            return nil
        end
        local item = self:GetItemInSlot(slot)
        if item ~= nil and item:HasTag("kei_rotor_survey_controller") then
            return nil
        end
        return old_DropItemBySlot(self, slot, ...)
    end

    function self:RemoveItem(item, ...)
        if IsMiniAliceContainer(self) and item ~= nil then
            local slot = self:GetItemSlot(item)
            if slot ~= nil and not IsAccessibleMiniAliceSlot(self, slot) then
                return nil
            end
        end
        return old_RemoveItem(self, item, ...)
    end

    function self:MoveItemFromAllOfSlot(slot, container, opener, ...)
        if not IsAccessibleMiniAliceSlot(self, slot) then
            return
        end

        local item = self:GetItemInSlot(slot)
        if item ~= nil
            and not IsAllowedControllerDestination(container, opener, item)
        then
            return
        end
        if opener ~= nil
            and self.inst:HasTag("kei_protocol_slot")
            and item ~= nil
            and item:HasTag("kei_protocol_cd")
            and item.components.inventoryitem ~= nil
            and not item.components.inventoryitem.islockedinslot
        then
            local destination = FindProtocolMoveDestination(opener, item)
            if destination ~= nil then
                old_MoveItemFromAllOfSlot(self, slot, destination, opener, ...)
                return
            end

            return
        end

        old_MoveItemFromAllOfSlot(self, slot, container, opener, ...)
    end

    function self:MoveItemFromHalfOfSlot(slot, container, opener, ...)
        if not IsAccessibleMiniAliceSlot(self, slot) then
            return
        end

        local item = self:GetItemInSlot(slot)
        if item ~= nil
            and not IsAllowedControllerDestination(container, opener, item)
        then
            return
        end

        return old_MoveItemFromHalfOfSlot(self, slot, container, opener, ...)
    end

    function self:MoveItemFromCountOfSlot(slot, container, count, opener, ...)
        if not IsAccessibleMiniAliceSlot(self, slot) then
            return
        end

        local item = self:GetItemInSlot(slot)
        if item ~= nil
            and not IsAllowedControllerDestination(container, opener, item)
        then
            return
        end

        return old_MoveItemFromCountOfSlot(self, slot, container, count, opener, ...)
    end
end)

-- 客户端先行判断控制器的允许位置，避免拖动时短暂显示在背包后又被服务端弹回。
if not TheNet:IsDedicated() then
    local function IsRotorSurveyController(item)
        return item ~= nil and item:HasTag("kei_rotor_survey_controller")
    end

    local function GetControllerOwnerUserId(item)
        if item ~= nil and item.GetControllerOwnerUserId ~= nil then
            return item:GetControllerOwnerUserId()
        end
        local owner_userid = item ~= nil and item._kei_controller_owner_userid_net or nil
        return owner_userid ~= nil and owner_userid:value() or nil
    end

    AddClassPostConstruct("components/inventory_replica", function(self)
        local old_CanTakeItemInSlot = self.CanTakeItemInSlot

        function self:CanTakeItemInSlot(item, slot)
            if IsRotorSurveyController(item) then
                return self.inst ~= nil
                    and self.inst.userid ~= nil
                    and GetControllerOwnerUserId(item) == self.inst.userid
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    AddClassPostConstruct("components/container_replica", function(self)
        local old_CanTakeItemInSlot = self.CanTakeItemInSlot

        function self:CanTakeItemInSlot(item, slot)
            if IsRotorSurveyController(item) then
                if self.inst == nil or not self.inst:HasTag("kei_mini_alice") then
                    return false
                end

                local alice_inventoryitem = self.inst.replica.inventoryitem
                return ThePlayer ~= nil
                    and alice_inventoryitem ~= nil
                    and alice_inventoryitem:IsGrandOwner(ThePlayer)
                    and GetControllerOwnerUserId(item) == ThePlayer.userid
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    -- invslot 在点击时会直接发起 Put/Move RPC；对控制器在 UI 入口再次拦截，
    -- 避免客户端先显示到背包、等待服务端拒绝后又回到原位置。
    AddClassPostConstruct("widgets/invslot", function(self)
        local old_Click = self.Click
        local old_TradeItem = self.TradeItem

        local function IsAllowedClientDestination(container, owner)
            if container == nil or owner == nil then
                return false
            end
            if container == owner.replica.inventory then
                return true
            end
            local container_inst = container.inst
            if container_inst == nil or not container_inst:HasTag("kei_mini_alice") then
                return false
            end
            local inventoryitem = container_inst.replica ~= nil
                and container_inst.replica.inventoryitem or nil
            return inventoryitem ~= nil
                and inventoryitem:IsGrandOwner(owner)
        end

        function self:Click(stack_mod)
            local owner = self.owner
            local inventory = owner ~= nil and owner.replica ~= nil
                and owner.replica.inventory or nil
            local active_item = inventory ~= nil and inventory:GetActiveItem() or nil
            if IsRotorSurveyController(active_item)
                and not IsAllowedClientDestination(self.container, owner)
            then
                return
            end
            return old_Click(self, stack_mod)
        end

        function self:TradeItem(stack_mod)
            local item = self.container ~= nil
                and self.container:GetItemInSlot(self.num) or nil
            if IsRotorSurveyController(item) then
                local owner = self.owner
                local inventory = owner ~= nil and owner.replica ~= nil
                    and owner.replica.inventory or nil
                -- 控制器在主物品栏中不能被交易到其他容器；娇小爱丽丝中的
                -- 控制器仍允许按原版流程移回主物品栏。
                if self.container ~= inventory
                    and not IsAllowedClientDestination(self.container, owner)
                then
                    return
                end
                if self.container == inventory then
                    return
                end
            end
            return old_TradeItem(self, stack_mod)
        end
    end)
end

local function ClientContainerHasRoomForItem(container, item)
    if container == nil
        or item == nil
        or not container:CanTakeItemInSlot(item)
    then
        return false
    end

    local item_stackable = item.replica.stackable
    if container:AcceptsStacks() and item_stackable ~= nil then
        for slot = 1, container:GetNumSlots() do
            local stored = container:GetItemInSlot(slot)
            local stored_stackable = stored ~= nil and stored.replica.stackable or nil
            if stored ~= nil
                and stored_stackable ~= nil
                and not stored_stackable:IsFull()
                and stored_stackable:CanStackWith(item)
                and container:CanTakeItemInSlot(item, slot)
            then
                return true
            end
        end
    end

    for slot = 1, container:GetNumSlots() do
        if container:GetItemInSlot(slot) == nil and container:CanTakeItemInSlot(item, slot) then
            return true
        end
    end

    return false
end

local function ClientFindOpenProtocolBinderWithRoom(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    local opencontainers = inventory ~= nil and inventory:GetOpenContainers() or nil
    if opencontainers == nil then
        return nil
    end

    for container_inst in pairs(opencontainers) do
        local container = container_inst.replica.container
        if container_inst:HasTag("kei_protocol_binder")
            and container ~= nil
            and container:IsOpenedBy(character)
            and ClientContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

local function ClientFindOpenMiniAliceWithRoom(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    local opencontainers = inventory ~= nil and inventory:GetOpenContainers() or nil
    if opencontainers == nil then
        return nil
    end

    for container_inst in pairs(opencontainers) do
        local container = container_inst.replica.container
        if container_inst:HasTag("kei_mini_alice")
            and container ~= nil
            and container:IsOpenedBy(character)
            and ClientContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

local function ClientInventoryHasMainRoomForItem(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    if inventory == nil or item == nil or not inventory:IsOpenedBy(character) then
        return false
    end

    return ClientContainerHasRoomForItem(inventory, item)
end

local function ClientFindProtocolMoveDestination(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    if inventory == nil or item == nil then
        return nil
    end

    -- Keep this order identical to the server-side validation above.
    local binder = ClientFindOpenProtocolBinderWithRoom(character, item)
    if binder ~= nil then
        return binder
    end

    if ClientInventoryHasMainRoomForItem(character, item) then
        return character
    end

    local alice = ClientFindOpenMiniAliceWithRoom(character, item)
    if alice ~= nil then
        return alice
    end

    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil
        and overflow:IsOpenedBy(character)
        and ClientContainerHasRoomForItem(overflow, item)
    then
        return overflow.inst
    end
end

if not TheNet:IsDedicated() then
    AddClassPostConstruct("widgets/invslot", function(self)
        local old_TradeItem = self.TradeItem

        function self:TradeItem(stack_mod, ...)
            local slot_number = self.num
            local character = self.owner
            local inventory = character ~= nil and character.replica.inventory or nil
            local container = self.container
            local container_inst = container ~= nil and container.inst or nil
            local container_item = container ~= nil
                and (container.IsReadOnlyContainer == nil or not container:IsReadOnlyContainer())
                and container:GetItemInSlot(slot_number)
                or nil

            if not stack_mod
                and character ~= nil
                and inventory ~= nil
                and container_inst ~= nil
                and container_inst:HasTag("kei_protocol_slot")
                and container_item ~= nil
                and container_item:HasTag("kei_protocol_cd")
                and container_item.replica.inventoryitem ~= nil
                and not container_item.replica.inventoryitem:IsLockedInSlot()
            then
                local dest_inst = ClientFindProtocolMoveDestination(character, container_item)

                if dest_inst ~= nil then
                    container:MoveItemFromAllOfSlot(slot_number, dest_inst)
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
                else
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
                end
                return
            end

            return old_TradeItem(self, stack_mod, ...)
        end
    end)
end

local function MakeProtocolBinderSlotPositions(count)
    local slots = {}
    local spacing = 75
    local start = -spacing * (count - 1) * 0.5
    for i = 1, count do
        slots[i] = Vector3(start + spacing * (i - 1), 0, 0)
    end
    return slots
end

local function MakeProtocolBinderSlotBgs(count)
    local slotbgs = {}
    for i = 1, count do
        slotbgs[i] = {
            atlas = "images/inventoryimages/transparent_slot.xml",
            image = "transparent_slot.tex",
        }
    end
    return slotbgs
end

local MINI_ALICE_SLOT_POSITIONS = {
    Vector3(-252, 0, 0),
    Vector3(-180, 0, 0),
    Vector3(-108, 0, 0),
    Vector3(-36, 0, 0),
    Vector3(36, 0, 0),
    Vector3(108, 0, 0),
    Vector3(180, 0, 0),
    Vector3(252, 0, 0),
}

local PROTOCOL_SLOT_UI_OFFSET = Vector3(0, 100, 0)

-- 通过角色物品栏的真实槽位定位容器，避免 HUD 尚未刷新时多个容器共用首格坐标。
local function GetInventorySlotWidget(container, doer)
    if container == nil
        or doer == nil
        or doer.HUD == nil
        or doer.HUD.controls == nil
        or doer.HUD.controls.inv == nil
        or doer.HUD.controls.inv.inv == nil
    then
        return nil
    end

    local inventory = doer.replica ~= nil and doer.replica.inventory or nil
    if inventory ~= nil and inventory.GetNumSlots ~= nil then
        for slot = 1, inventory:GetNumSlots() do
            if inventory:GetItemInSlot(slot) == container then
                return doer.HUD.controls.inv.inv[slot]
            end
        end
    end

    -- 兼容部分客户端 replica 尚未同步物品栏数据的瞬间。
    for _, slot in pairs(doer.HUD.controls.inv.inv) do
        if slot.tile ~= nil and slot.tile.item == container then
            return slot
        end
    end
end

local function MakeMiniAliceAllSlotPositions(max_pages)
    local positions = {}
    for _ = 1, max_pages do
        for i = 1, #MINI_ALICE_SLOT_POSITIONS do
            positions[#positions + 1] = MINI_ALICE_SLOT_POSITIONS[i]
        end
    end
    return positions
end

local function MakeMiniAliceSlotBgs(count)
    local slotbgs = {}
    for i = 1, count do
        slotbgs[i] = {
            atlas = "images/inventoryimages/kei_alice_slot.xml",
            image = "kei_alice_slot.tex",
        }
    end
    return slotbgs
end

local MINI_ALICE_UI_OFFSET = Vector3(290, 100, 0)
local MINI_ALICE_PAGE_TWEEN_TIME = 0.1
local MINI_ALICE_PAGE_TWEEN_DISTANCE = 620

local function GetMiniAlicePosition(container, doer)
    local slot = GetInventorySlotWidget(container, doer)
    if slot ~= nil then
        return slot:GetPosition() + MINI_ALICE_UI_OFFSET
    end

    return MINI_ALICE_UI_OFFSET
end

local function GetProtocolSlotPosition(container, doer)
    local slot = GetInventorySlotWidget(container, doer)
    return slot ~= nil and slot:GetPosition() + PROTOCOL_SLOT_UI_OFFSET or nil
end

-- 不使用 wx78_inventorycontainer 的备份体定位逻辑。
containers.params.kei_protocol_container.widget.posfn = GetProtocolSlotPosition

local function GetContainerOwner(container)
    local inventoryitem = container ~= nil
        and container.inst ~= nil
        and container.inst.components ~= nil
        and container.inst.components.inventoryitem
        or nil
    return inventoryitem ~= nil and inventoryitem.owner or nil
end

local function HasMainInventoryStack(inventory, item)
    if inventory == nil or item == nil then
        return false
    end

    for slot = 1, inventory.maxslots do
        local stored = inventory:GetItemInSlot(slot)
        if stored ~= nil
            and stored.components.stackable ~= nil
            and not stored.components.stackable:IsFull()
            and stored.components.stackable:CanStackWith(item)
            and inventory:CanTakeItemInSlot(item, slot)
        then
            return true
        end
    end

    return false
end

local function HasMainInventoryEmptySlot(inventory, item)
    if inventory == nil or item == nil then
        return false
    end

    for slot = 1, inventory.maxslots do
        if inventory:GetItemInSlot(slot) == nil
            and inventory:CanTakeItemInSlot(item, slot)
        then
            return true
        end
    end

    return false
end

local function HasContainerStack(container, item)
    if container == nil or item == nil or not container:AcceptsStacks() then
        return false
    end

    for slot = 1, container:GetNumSlots() do
        local stored = container:GetItemInSlot(slot)
        if stored ~= nil
            and stored.components.stackable ~= nil
            and not stored.components.stackable:IsFull()
            and stored.components.stackable:CanStackWith(item)
            and container:CanTakeItemInSlot(item, slot)
        then
            return true
        end
    end

    return false
end

local function HasContainerRoom(container, item)
    if container == nil then
        return false
    end

    for slot = 1, container:GetNumSlots() do
        local stored = container:GetItemInSlot(slot)
        if stored == nil and container:CanTakeItemInSlot(item, slot) then
            return true
        end
    end

    return false
end

local function ShouldPrioritizeMiniAlice(container, item)
    local owner = GetContainerOwner(container)
    local inventory = owner ~= nil and owner.components ~= nil and owner.components.inventory or nil
    local has_stack = HasContainerStack(container, item)
    local has_empty_slot = HasContainerRoom(container, item)
    if inventory == nil
        or not container:IsOpenedBy(owner)
        or (not has_stack and not has_empty_slot)
    then
        return false
    end

    -- GetNextAvailableSlot checks the main inventory before specialized
    -- containers.  Alice only needs to be marked as prioritized when it has
    -- a stack that should win over an empty main-inventory slot, or when the
    -- main inventory has no suitable stack/empty slot left.
    if HasMainInventoryStack(inventory, item) then
        return false
    end

    if has_stack then
        return true
    end

    if HasMainInventoryEmptySlot(inventory, item) then
        return false
    end

    local overflow = inventory:GetOverflowContainer()
    return not HasContainerStack(overflow, item)
end

containers.params.kei_mini_alice_box = {
    widget = {
        slotpos = MakeMiniAliceAllSlotPositions(MiniAlice.GetMaxPages()),
        slotbg = MakeMiniAliceSlotBgs(mini_alice_max_slots),
        -- 动画包内 entity 名称为 kei_mini_alice_box，build 名称为
        -- ui_kei_mini_alice_box_8x1，二者需要分别设置。
        animbank = "kei_mini_alice_box",
        animbuild = "ui_kei_mini_alice_box_8x1",
        -- 无限堆叠容器会走 containerwidget 的 upgraded 动画分支。
        -- 娇小爱丽丝不需要另一套外观，因此显式复用普通动画资源。
        animbank_upgraded = "kei_mini_alice_box",
        animbuild_upgraded = "ui_kei_mini_alice_box_8x1",
        animloop = nil,
        scale = 1.9,
        itemscale = 0.8,
        pos = MINI_ALICE_UI_OFFSET,
        posfn = GetMiniAlicePosition,
        side_align_tip = 160,
    },
    type = "inv",
    openlimit = 1,
    acceptsstacks = true,
}

function containers.params.kei_mini_alice_box.itemtestfn(container, item, slot)
    return item ~= nil and MiniAlice.IsSlotAccessible(container, slot)
end

containers.params.kei_mini_alice_box.priorityfn = ShouldPrioritizeMiniAlice

-- 服务端使用 WidgetSetup("kei_mini_alice_box")，客户端 replica 则按
-- prefab 名 kei_mini_alice 自动查找 widget。保留两个名字，避免客户端
-- 打开时 GetWidget() 返回 nil。
containers.params.kei_mini_alice = containers.params.kei_mini_alice_box

local protocol_binder_slots = TUNING.KEI_PROTOCOL_SLOT_HARD_MAX or 7
local protocol_binder_width = 75 * math.max(protocol_binder_slots - 1, 0)
local PROTOCOL_BINDER_BUTTON_COOLDOWN = 0.5

local function RefreshProtocolBinderButton(inst)
    if inst ~= nil and ThePlayer ~= nil then
        inst:PushEvent("itemget", {})
    end
end

local function IsProtocolBinderButtonCoolingDown(inst)
    return inst ~= nil
        and inst._kei_protocol_binder_button_ready_time ~= nil
        and GetTime() < inst._kei_protocol_binder_button_ready_time
end

local function StartProtocolBinderButtonCooldown(inst)
    if inst == nil or IsProtocolBinderButtonCoolingDown(inst) then
        return false
    end

    inst._kei_protocol_binder_button_ready_time = GetTime() + PROTOCOL_BINDER_BUTTON_COOLDOWN
    RefreshProtocolBinderButton(inst)

    if inst._kei_protocol_binder_button_task ~= nil then
        inst._kei_protocol_binder_button_task:Cancel()
    end
    inst._kei_protocol_binder_button_task = inst:DoTaskInTime(PROTOCOL_BINDER_BUTTON_COOLDOWN, function()
        inst._kei_protocol_binder_button_ready_time = nil
        inst._kei_protocol_binder_button_task = nil
        RefreshProtocolBinderButton(inst)
    end)

    return true
end

containers.params.kei_protocol_binder = {
    widget = {
        slotpos = {
            Vector3(-267, 3, 0),
            Vector3(-190, 3, 0),
            Vector3(-113, 3, 0),
            Vector3(-36, 3, 0),
            Vector3(41, 3, 0),
            Vector3(118, 3, 0),
            Vector3(195, 3, 0),
        },
        slotbg = MakeProtocolBinderSlotBgs(protocol_binder_slots),
        animbank = "ui_kei_protocol_box_7x1",
        animbuild = "ui_kei_protocol_box_7x1",
        animfn = function(container, doer, anim)
            if anim == "open" then
                return "opening"
            elseif anim == "close" then
                return "closing"
            end
            return anim
        end,
        pos = Vector3(0, -300, 0),
        side_align_tip = math.max(160, protocol_binder_width * 0.5 + 120),
        buttoninfo = {
            text = "交换",
            position = Vector3(305, 5, 0),
        },
    },
    type = "kei_protocol_binder",
    openlimit = 1,
    acceptsstacks = false,
}

function containers.params.kei_protocol_binder.itemtestfn(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end

function containers.params.kei_protocol_binder.widget.buttoninfo.fn(inst, doer)
    if not StartProtocolBinderButtonCooldown(inst) then
        return
    end

    if inst.SwapWithProtocolSlots ~= nil then
        inst:SwapWithProtocolSlots(doer)
    elseif inst.replica.container ~= nil then
        SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
    end
end

function containers.params.kei_protocol_binder.widget.buttoninfo.validfn(inst)
    return inst ~= nil
        and inst.replica.container ~= nil
        and not IsProtocolBinderButtonCoolingDown(inst)
end

if not TheNet:IsDedicated() then
    local ImageButton = require("widgets/imagebutton")
    local Widget = require("widgets/widget")

    local function IsMiniAliceWidgetContainer(container)
        return container ~= nil and container:HasTag("kei_mini_alice")
    end

    local function IsProtocolWidgetContainer(container)
        return container ~= nil and container:HasTag("kei_protocol_slot")
    end

    local function ApplyMiniAliceItemScale(slot)
        local container = slot ~= nil and slot.container or nil
        if container == nil
            or container.inst == nil
            or not container.inst:HasTag("kei_mini_alice")
            or slot.tile == nil
        then
            return
        end

        local config = container:GetWidget()
        local itemscale = config ~= nil and tonumber(config.itemscale) or 0.9
        if slot.tile.SetBaseScale ~= nil then
            slot.tile:SetBaseScale(itemscale)
        else
            slot.tile:SetScale(itemscale, itemscale, itemscale)
        end
    end

    AddClassPostConstruct("widgets/invslot", function(self)
        local old_SetTile = self.SetTile

        function self:SetTile(tile, ...)
            old_SetTile(self, tile, ...)
            ApplyMiniAliceItemScale(self)
        end
    end)

    local function HideMiniAliceSlots(widget)
        for _, slot in ipairs(widget.inv or {}) do
            if slot.CancelMoveTo ~= nil then
                slot:CancelMoveTo()
            end
            slot:Hide()
        end
    end

    local function InstallMiniAliceSlotClip(widget)
        if widget._kei_mini_alice_slot_clip ~= nil then
            return
        end

        local clip = widget:AddChild(Widget("MiniAliceSlotClip"))
        -- Alice UI 动画包的可见横向范围约为 -304 到 300。
        -- 纵向留出足够空间，只裁剪翻页时左右越界的格子。
        clip:SetScissor(-294, -200, 584, 400)

        for _, slot in ipairs(widget.inv or {}) do
            local position = slot:GetPosition()
            clip:AddChild(slot)
            slot:SetPosition(position)
        end

        widget._kei_mini_alice_slot_clip = clip
    end

    local function UpdateMiniAlicePageButtons(widget, page, unlocked_pages)
        local transition = widget._kei_mini_alice_page_transition == true
        local has_multiple_pages = unlocked_pages > 1

        if widget._kei_mini_alice_previous_button ~= nil then
            if not MiniAlice.HasLeftArrow() then
                widget._kei_mini_alice_previous_button:Disable()
                widget._kei_mini_alice_previous_button:Hide()
            elseif not transition and (page > 1 or (MiniAlice.IsArrowLooping() and has_multiple_pages)) then
                widget._kei_mini_alice_previous_button:Show()
                widget._kei_mini_alice_previous_button:Enable()
            else
                widget._kei_mini_alice_previous_button:Show()
                widget._kei_mini_alice_previous_button:Disable()
            end
        end
        if widget._kei_mini_alice_next_button ~= nil then
            if not MiniAlice.HasRightArrow() then
                widget._kei_mini_alice_next_button:Disable()
                widget._kei_mini_alice_next_button:Hide()
            elseif not transition and (page < unlocked_pages or (MiniAlice.IsArrowLooping() and has_multiple_pages)) then
                widget._kei_mini_alice_next_button:Show()
                widget._kei_mini_alice_next_button:Enable()
            else
                widget._kei_mini_alice_next_button:Show()
                widget._kei_mini_alice_next_button:Disable()
            end
        end
    end

    local function ShowMiniAlicePage(widget, page, owner)
        local unlocked_pages = MiniAlice.GetUnlockedPages(owner)
        page = math.clamp(page or 1, 1, unlocked_pages)

        if widget._kei_mini_alice_page_transition_task ~= nil then
            widget._kei_mini_alice_page_transition_task:Cancel()
            widget._kei_mini_alice_page_transition_task = nil
        end
        widget._kei_mini_alice_page_transition = false
        HideMiniAliceSlots(widget)

        local first_slot = (page - 1) * MiniAlice.SLOTS_PER_PAGE + 1
        local last_slot = first_slot + MiniAlice.SLOTS_PER_PAGE - 1
        for slot_index = first_slot, last_slot do
            if widget.inv[slot_index] ~= nil then
                local position = MINI_ALICE_SLOT_POSITIONS[slot_index - first_slot + 1]
                widget.inv[slot_index]:SetPosition(position)
                widget.inv[slot_index]:Show()
            end
        end

        widget._kei_mini_alice_page = page
        widget._kei_mini_alice_unlocked_pages = unlocked_pages
        if widget.container ~= nil then
            widget.container._kei_mini_alice_page = page
        end
        UpdateMiniAlicePageButtons(widget, page, unlocked_pages)
    end

    local function AnimateMiniAlicePage(widget, page, owner)
        if widget._kei_mini_alice_page_transition then
            return
        end

        local current_page = widget._kei_mini_alice_page or 1
        local unlocked_pages = MiniAlice.GetUnlockedPages(owner)
        page = math.clamp(page or current_page, 1, unlocked_pages)
        if page == current_page then
            UpdateMiniAlicePageButtons(widget, current_page, unlocked_pages)
            return
        end

        local direction = page > current_page and 1 or -1
        local old_first_slot = (current_page - 1) * MiniAlice.SLOTS_PER_PAGE + 1
        local new_first_slot = (page - 1) * MiniAlice.SLOTS_PER_PAGE + 1
        local offset = Vector3(direction * MINI_ALICE_PAGE_TWEEN_DISTANCE, 0, 0)

        widget._kei_mini_alice_page_transition = true
        UpdateMiniAlicePageButtons(widget, current_page, unlocked_pages)

        for i = 1, MiniAlice.SLOTS_PER_PAGE do
            local position = MINI_ALICE_SLOT_POSITIONS[i]
            local old_slot = widget.inv[old_first_slot + i - 1]
            local new_slot = widget.inv[new_first_slot + i - 1]

            if old_slot ~= nil then
                old_slot:SetPosition(position)
                old_slot:Show()
                old_slot:MoveTo(position, position - offset, MINI_ALICE_PAGE_TWEEN_TIME)
            end

            if new_slot ~= nil then
                local start_position = position + offset
                new_slot:SetPosition(start_position)
                new_slot:Show()
                new_slot:MoveTo(start_position, position, MINI_ALICE_PAGE_TWEEN_TIME)
            end
        end

        widget._kei_mini_alice_page_transition_task = widget.inst:DoTaskInTime(
            MINI_ALICE_PAGE_TWEEN_TIME,
            function()
                widget._kei_mini_alice_page_transition_task = nil
                widget._kei_mini_alice_page_transition = false
                ShowMiniAlicePage(widget, page, owner)
            end
        )
    end

    local function InstallMiniAlicePageControls(widget, owner)
        if widget._kei_mini_alice_controls ~= nil then
            ShowMiniAlicePage(widget, widget._kei_mini_alice_page, owner)
            return
        end

        local previous_button = widget:AddChild(ImageButton(
            "images/ui.xml",
            "crafting_inventory_arrow_l_idle.tex",
            "crafting_inventory_arrow_l_hl.tex",
            "arrow_left_disabled.tex",
            "crafting_inventory_arrow_l_hl.tex",
            nil,
            { 1, 1 },
            { 0, 0 }
        ))
        previous_button.scale_on_focus = false
        previous_button:SetPosition(Vector3(-320, 0, 0))
        previous_button:SetOnClick(function()
            local page = widget._kei_mini_alice_page or 1
            local page_count = MiniAlice.GetUnlockedPages(owner)
            AnimateMiniAlicePage(widget, MiniAlice.GetPreviousPage(page, page_count), owner)
        end)

        local next_button = widget:AddChild(ImageButton(
            "images/ui.xml",
            "crafting_inventory_arrow_r_idle.tex",
            "crafting_inventory_arrow_r_hl.tex",
            "arrow_right_disabled.tex",
            "crafting_inventory_arrow_r_hl.tex",
            nil,
            { 1, 1 },
            { 0, 0 }
        ))
        next_button.scale_on_focus = false
        next_button:SetPosition(Vector3(320, 0, 0))
        next_button:SetOnClick(function()
            local page = widget._kei_mini_alice_page or 1
            local page_count = MiniAlice.GetUnlockedPages(owner)
            AnimateMiniAlicePage(widget, MiniAlice.GetNextPage(page, page_count), owner)
        end)

        widget._kei_mini_alice_controls = true
        widget._kei_mini_alice_previous_button = previous_button
        widget._kei_mini_alice_next_button = next_button
        widget._kei_mini_alice_page_owner = owner

        if owner ~= nil then
            widget._kei_mini_alice_slots_dirty_fn = function()
                ShowMiniAlicePage(widget, widget._kei_mini_alice_page, owner)
            end
            owner:ListenForEvent("kei_protocol_slots_dirty", widget._kei_mini_alice_slots_dirty_fn)
            widget._kei_mini_alice_pages_dirty_fn = function()
                local page = widget._kei_mini_alice_page or 1
                local pages = MiniAlice.GetUnlockedPages(owner)
                if page > pages then
                    page = pages
                end
                ShowMiniAlicePage(widget, page, owner)
            end
            owner:ListenForEvent("kei_mini_alice_pages_dirty", widget._kei_mini_alice_pages_dirty_fn)
        end

        local container = widget.container
        local stored_page = container ~= nil
            and tonumber(container._kei_mini_alice_page)
            or nil
        local unlocked_pages = MiniAlice.GetUnlockedPages(owner)
        if stored_page == nil
            or stored_page < 1
            or stored_page > unlocked_pages
        then
            stored_page = 1
        end
        ShowMiniAlicePage(widget, stored_page, owner)
    end

    AddClassPostConstruct("widgets/containerwidget", function(self)
        local old_Open = self.Open
        local old_Close = self.Close

        local function GetMiniAliceWidget(container)
            local replica = container ~= nil and container.replica ~= nil
                and container.replica.container or nil
            if replica == nil then
                return nil
            end

            local widget = replica:GetWidget()
            if widget == nil then
                -- 兼容部分客户端/其他模组改变 replica 初始化顺序的情况。
                -- 显式传入服务端使用的配置名，避免按 prefab 名查找失败。
                containers.widgetsetup(replica, "kei_mini_alice_box")
                widget = replica:GetWidget()
            end
            return widget
        end

        local function PlayMiniAliceAnimationOnce(widget, container, doer, name)
            local config = GetMiniAliceWidget(container)
            if config == nil or widget.bganim == nil then
                return
            end

            local anim = config.animfn ~= nil
                and config.animfn(container, doer, name)
                or name
            -- 某些客户端 UI/容器包装会重复调用 Open，明确关闭循环，
            -- 让动画只播放一次并停在最后一帧。
            widget.bganim:GetAnimState():PlayAnimation(anim, false)
        end

        local function ApplyMiniAliceScale(widget, container)
            local config = GetMiniAliceWidget(container)
            local scale = config ~= nil and tonumber(config.scale) or 1
            -- ContainerWidget 默认整体缩放为 0.6；scale 是相对于默认尺寸的倍率。
            widget:SetScale(0.6 * scale, 0.6 * scale, 0.6 * scale)
        end

        self.Open = function(widget, container, doer, ...)
            if IsMiniAliceWidgetContainer(container)
                and GetMiniAliceWidget(container) == nil
            then
                -- 不把空 widget 传入原版 ContainerWidget.Open，避免与
                -- Legion/Medal 等同样包装 Open 的模组叠加时客户端崩溃。
                return
            end

            old_Open(widget, container, doer, ...)
            if IsProtocolWidgetContainer(container) then
                if widget._kei_protocol_position_task ~= nil then
                    widget._kei_protocol_position_task:Cancel()
                end
                -- ContainerWidget.Open 会先显示默认坐标，再等待物品栏 HUD
                -- 刷新。先隐藏一帧，避免从首个协议槽位置闪现。
                widget:Hide()
                widget._kei_protocol_position_task = widget.inst:DoTaskInTime(0, function()
                    widget._kei_protocol_position_task = nil
                    if widget.isopen and widget.container == container then
                        local position = GetProtocolSlotPosition(container, doer)
                        if position ~= nil then
                            widget:SetPosition(position)
                        end
                        widget:Show()
                    end
                end)
            end
            if IsMiniAliceWidgetContainer(container) then
                ApplyMiniAliceScale(widget, container)
                InstallMiniAliceSlotClip(widget)
                PlayMiniAliceAnimationOnce(widget, container, doer, "open")
                InstallMiniAlicePageControls(widget, doer or widget.owner)
            end
        end

        self.Close = function(widget, ...)
            if widget._kei_protocol_position_task ~= nil then
                widget._kei_protocol_position_task:Cancel()
                widget._kei_protocol_position_task = nil
            end

            if widget._kei_mini_alice_slots_dirty_fn ~= nil
                and widget._kei_mini_alice_page_owner ~= nil
            then
                widget._kei_mini_alice_page_owner:RemoveEventCallback(
                    "kei_protocol_slots_dirty",
                    widget._kei_mini_alice_slots_dirty_fn
                )
                widget._kei_mini_alice_slots_dirty_fn = nil
            end
            if widget._kei_mini_alice_pages_dirty_fn ~= nil
                and widget._kei_mini_alice_page_owner ~= nil
            then
                widget._kei_mini_alice_page_owner:RemoveEventCallback(
                    "kei_mini_alice_pages_dirty",
                    widget._kei_mini_alice_pages_dirty_fn
                )
                widget._kei_mini_alice_pages_dirty_fn = nil
            end
            widget._kei_mini_alice_page_owner = nil

            if widget._kei_mini_alice_page_transition_task ~= nil then
                widget._kei_mini_alice_page_transition_task:Cancel()
                widget._kei_mini_alice_page_transition_task = nil
            end
            widget._kei_mini_alice_page_transition = false

            local container = widget.container
            if IsMiniAliceWidgetContainer(container)
                and widget._kei_mini_alice_page ~= nil
            then
                container._kei_mini_alice_page = widget._kei_mini_alice_page
            end
            widget._kei_mini_alice_controls = nil
            widget._kei_mini_alice_page = nil
            widget._kei_mini_alice_unlocked_pages = nil
            widget._kei_mini_alice_previous_button = nil
            widget._kei_mini_alice_next_button = nil
            local result = old_Close(widget, ...)
            if IsMiniAliceWidgetContainer(container)
                and widget._kei_mini_alice_slot_clip ~= nil
            then
                widget._kei_mini_alice_slot_clip:Kill()
                widget._kei_mini_alice_slot_clip = nil
            end
            if IsMiniAliceWidgetContainer(container) then
                PlayMiniAliceAnimationOnce(widget, container, widget.owner, "close")
            end
            return result
        end
    end)
end
