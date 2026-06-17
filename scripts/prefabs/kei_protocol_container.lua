local assets =
{
    Asset("ANIM", "anim/kei_protocol_popup.zip"),
    Asset("ATLAS", "images/kei_protocol_slot_closed.xml"),
    Asset("ATLAS", "images/kei_protocol_slot_locked.xml"),
    Asset("ATLAS", "images/kei_protocol_slot_openable.xml"),
    Asset("IMAGE", "images/kei_protocol_slot_closed.tex"),
    Asset("IMAGE", "images/kei_protocol_slot_locked.tex"),
    Asset("IMAGE", "images/kei_protocol_slot_openable.tex"),
}

local SLOT_BANK = "kei_protocol_popup"
local SLOT_BUILD = "kei_protocol_popup"
local SLOT_ANIM_OPENING = "opening"
local SLOT_ANIM_CLOSING = "closing"

local SLOT_ICON_ATLAS_CLOSED = "images/kei_protocol_slot_closed.xml"
local SLOT_ICON_IMAGE_CLOSED = "kei_protocol_slot_closed"
local SLOT_ICON_ATLAS_LOCKED = "images/kei_protocol_slot_locked.xml"
local SLOT_ICON_IMAGE_LOCKED = "kei_protocol_slot_locked"
local SLOT_ICON_ATLAS_OPENABLE = "images/kei_protocol_slot_openable.xml"
local SLOT_ICON_IMAGE_OPENABLE = "kei_protocol_slot_openable"

local RefreshIcon

local function SetAnimPose(inst, anim, at_end)
    inst.AnimState:PlayAnimation(anim, false)
    local len = inst.AnimState:GetCurrentAnimationLength() or 0
    inst.AnimState:SetTime(at_end and len or 0)
end

local function FreezeOnAnimOver(inst, anim)
    if inst._kei_slot_animover_fn ~= nil then
        inst:RemoveEventCallback("animover", inst._kei_slot_animover_fn)
        inst._kei_slot_animover_fn = nil
    end

    inst._kei_slot_animover_fn = function()
        if inst.AnimState:IsCurrentAnimation(anim) then
            SetAnimPose(inst, anim, true)
            if inst._kei_slot_animover_fn ~= nil then
                inst:RemoveEventCallback("animover", inst._kei_slot_animover_fn)
                inst._kei_slot_animover_fn = nil
            end
        end
    end
    inst:ListenForEvent("animover", inst._kei_slot_animover_fn)
end

local function OnPutInInventory(inst)
    inst:RemoveTag("no_container_store")
    inst.components.inventoryitem.islockedinslot = true
    RefreshIcon(inst)
end

local function OnDropped(inst)
    inst:AddTag("no_container_store")
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    inst:Remove()
end

function RefreshIcon(inst)
    local atlas, image
    if inst.components.container:IsOpen() then
        atlas = SLOT_ICON_ATLAS_OPENABLE
        image = SLOT_ICON_IMAGE_OPENABLE
    elseif inst.components.container.canbeopened then
        atlas = SLOT_ICON_ATLAS_CLOSED
        image = SLOT_ICON_IMAGE_CLOSED
    else
        atlas = SLOT_ICON_ATLAS_LOCKED
        image = SLOT_ICON_IMAGE_LOCKED
    end
    inst.components.inventoryitem.atlasname = atlas
    inst.components.inventoryitem:ChangeImageName(image)
end

local function OnOpen(inst)
    inst.AnimState:PlayAnimation(SLOT_ANIM_OPENING)
    FreezeOnAnimOver(inst, SLOT_ANIM_OPENING)
    RefreshIcon(inst)
end

local function OnClose(inst)
    inst.AnimState:PlayAnimation(SLOT_ANIM_CLOSING)
    FreezeOnAnimOver(inst, SLOT_ANIM_CLOSING)
    RefreshIcon(inst)
end

local function SetPowered(inst, powered)
    if inst.components.container.canbeopened ~= powered then
        inst.components.container.canbeopened = powered
        if not powered and inst.components.container:IsOpen() then
            inst.components.container:Close()
        else
            RefreshIcon(inst)
        end
    else
        RefreshIcon(inst)
    end
end

local function OpenWithoutClosingProtocolSlots(container, doer, ...)
    local inventory = doer ~= nil and doer.components.inventory or nil
    local kept_open = nil

    if inventory ~= nil then
        for open_inst in pairs(inventory.opencontainers) do
            if open_inst ~= container.inst
                and open_inst:HasTag("kei_protocol_slot")
                and open_inst.components.container ~= nil
                and open_inst.components.container:IsOpenedBy(doer)
            then
                kept_open = kept_open or {}
                kept_open[open_inst] = true
                inventory.opencontainers[open_inst] = nil
            end
        end
    end

    local result = container._kei_old_open(container, doer, ...)

    if kept_open ~= nil and inventory ~= nil then
        for open_inst in pairs(kept_open) do
            if open_inst:IsValid()
                and open_inst.components.container ~= nil
                and open_inst.components.container:IsOpenedBy(doer)
            then
                inventory.opencontainers[open_inst] = true
            end
        end
    end

    return result
end

local function AllowParallelProtocolSlotOpen(container)
    if container._kei_old_open == nil then
        container._kei_old_open = container.Open
        container.Open = OpenWithoutClosingProtocolSlots
    end
end

local function GetStatus(inst)
    return inst.components.inventoryitem:IsHeld()
        and (inst.components.container.canbeopened and "HELD" or "NOPOWER")
        or nil
end

local function DisplayNameFn(inst)
    local inventoryitem = inst.replica.inventoryitem
    return inventoryitem and inventoryitem:IsHeld()
        and STRINGS.NAMES.WX78_INVENTORYCONTAINER_HELD
        or STRINGS.NAMES.WX78_INVENTORYCONTAINER
end

local FLOATER_SWAP_DATA = { bank = SLOT_BANK, anim = SLOT_ANIM_CLOSING }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank(SLOT_BANK)
    inst.AnimState:SetBuild(SLOT_BUILD)
    SetAnimPose(inst, SLOT_ANIM_CLOSING, true)

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "small", 0.35, 1.15, nil, nil, FLOATER_SWAP_DATA)

    inst:AddTag("nosteal")
    inst:AddTag("no_container_store")
    inst:AddTag("kei_protocol_slot")

    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.keepondeath = true

    inst:AddComponent("container")
    inst.components.container:EnableInfiniteStackSize(true)
    inst.components.container:WidgetSetup("kei_protocol_container")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.canbeopened = false
    AllowParallelProtocolSlotOpen(inst.components.container)
    RefreshIcon(inst)

    MakeHauntableLaunchAndDropFirstItem(inst)

    inst.SetPowered = SetPowered

    return inst
end

return Prefab("kei_protocol_container", fn, assets)
