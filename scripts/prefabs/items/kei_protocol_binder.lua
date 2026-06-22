local assets = {
    Asset("ANIM", "anim/kei_protocol_binder.zip"),
    Asset("ANIM", "anim/ui_kei_protocol_box_7x1.zip"),
    Asset("ATLAS", "images/inventoryimages/kei_protocol_binder.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_protocol_binder.tex"),
    Asset("ATLAS", "images/inventoryimages/kei_protocol_binder_open.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_protocol_binder_open.tex"),
}

local BINDER_BANK = "kei_protocol_binder"
local BINDER_BUILD = "kei_protocol_binder"
local BINDER_ANIM_IDLE = "idle"
local BINDER_WORLD_SCALE = 1.5
local BINDER_ICON_ATLAS_CLOSED = "images/inventoryimages/kei_protocol_binder.xml"
local BINDER_ICON_IMAGE_CLOSED = "kei_protocol_binder"
local BINDER_ICON_ATLAS_OPEN = "images/inventoryimages/kei_protocol_binder_open.xml"
local BINDER_ICON_IMAGE_OPEN = "kei_protocol_binder_open"

local function RefreshBinderVisual(inst)
    if inst == nil then
        return
    end

    local inventoryitem = inst.components ~= nil and inst.components.inventoryitem or nil
    local container = inst.components ~= nil and inst.components.container or nil

    if inventoryitem ~= nil then
        local opened = container ~= nil and container:IsOpen() and inventoryitem:IsHeld()
        inventoryitem.atlasname = opened and BINDER_ICON_ATLAS_OPEN or BINDER_ICON_ATLAS_CLOSED
        inventoryitem:ChangeImageName(opened and BINDER_ICON_IMAGE_OPEN or BINDER_ICON_IMAGE_CLOSED)
    end
end

local function OnOpen(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/backpack_open", nil, 0.5)
    RefreshBinderVisual(inst)
end

local function OnClose(inst)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/backpack_close", nil, 0.5)
    RefreshBinderVisual(inst)
end

local function SetCanBeOpened(inst, can_open)
    if inst == nil or inst.components == nil or inst.components.container == nil then
        return
    end
    inst.components.container.canbeopened = can_open == true
    if not inst.components.container.canbeopened and inst.components.container:IsOpen() then
        inst.components.container:Close()
    end
    RefreshBinderVisual(inst)
end

local function OnPutInInventory(inst)
    SetCanBeOpened(inst, true)
end

local function OnDropped(inst)
    SetCanBeOpened(inst, false)
end

local function SwapWithProtocolSlots(inst, doer)
    if doer == nil
        or not doer:HasTag("kei")
        or doer.components.kei_protocolslots == nil
    then
        return false
    end
    return doer.components.kei_protocolslots:SwapWithProtocolBinder(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.Transform:SetScale(BINDER_WORLD_SCALE, BINDER_WORLD_SCALE, BINDER_WORLD_SCALE)
    inst.AnimState:SetBank(BINDER_BANK)
    inst.AnimState:SetBuild(BINDER_BUILD)
    inst.AnimState:PlayAnimation(BINDER_ANIM_IDLE, true)

    inst:AddTag("kei_protocol_binder")
    inst:AddTag("portablestorage")

    MakeInventoryFloatable(inst, "small", 0.2, nil, nil, nil)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("kei_protocol_binder")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true
    inst.components.container.canbeopened = false
    RefreshBinderVisual(inst)
    if inst.components.inventoryitem:IsHeld() then
        SetCanBeOpened(inst, true)
    end

    inst.SwapWithProtocolSlots = SwapWithProtocolSlots

    MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end

return Prefab("kei_protocol_binder", fn, assets)
