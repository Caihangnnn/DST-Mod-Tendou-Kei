local containers = require("containers")
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
        then
            return true
        end
    end

    return false
end

local function InventoryHasNonProtocolRoomForItem(inventory, item)
    if inventory == nil
        or item == nil
        or not inventory:IsOpenedBy(inventory.inst)
    then
        return false
    end

    local slot, target = inventory:GetNextAvailableSlot(item)
    return slot ~= nil
        and not (target ~= nil and target.inst ~= nil and target.inst:HasTag("kei_protocol_slot"))
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

AddComponentPostInit("container", function(self)
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot

    function self:MoveItemFromAllOfSlot(slot, container, opener, ...)
        local item = self:GetItemInSlot(slot)
        if opener ~= nil
            and self.inst:HasTag("kei_protocol_slot")
            and item ~= nil
            and item:HasTag("kei_protocol_cd")
            and item.components.inventoryitem ~= nil
            and not item.components.inventoryitem.islockedinslot
        then
            local binder = FindOpenProtocolBinderWithRoom(opener, item)
            if binder ~= nil then
                old_MoveItemFromAllOfSlot(self, slot, binder, opener, ...)
                return
            end

            if InventoryHasNonProtocolRoomForItem(opener.components.inventory, item) then
                old_MoveItemFromAllOfSlot(self, slot, opener, opener, ...)
                return
            end

            return
        end

        old_MoveItemFromAllOfSlot(self, slot, container, opener, ...)
    end
end)

local function ClientContainerHasRoomForItem(container, item)
    if container == nil
        or item == nil
        or not container:CanTakeItemInSlot(item)
    then
        return false
    end

    local item_stackable = item.replica.stackable
    if container:AcceptsStacks() and item_stackable ~= nil then
        for _, stored in pairs(container:GetItems()) do
            local stored_stackable = stored.replica.stackable
            if stored_stackable ~= nil
                and not stored_stackable:IsFull()
                and stored_stackable:CanStackWith(item)
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

local function ClientInventoryHasRoomForItem(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    if inventory == nil or item == nil then
        return false
    end

    if ClientContainerHasRoomForItem(inventory, item) then
        return true
    end

    local overflow = inventory:GetOverflowContainer()
    return overflow ~= nil and ClientContainerHasRoomForItem(overflow, item)
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
                local dest_inst = ClientFindOpenProtocolBinderWithRoom(character, container_item)
                if dest_inst == nil and ClientInventoryHasRoomForItem(character, container_item) then
                    dest_inst = character
                end

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
        pos = Vector3(0, 200, 0),
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

