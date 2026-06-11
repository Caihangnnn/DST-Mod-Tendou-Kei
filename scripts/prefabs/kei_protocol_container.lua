local assets =
{
    Asset("ANIM", "anim/wx78_inventorycontainer.zip"),
    Asset("INV_IMAGE", "wx78_inventorycontainer"),
    Asset("INV_IMAGE", "wx78_inventorycontainer_open"),
    Asset("INV_IMAGE", "wx78_inventorycontainer_powered"),
    Asset("ANIM", "anim/ui_wx78_inventorycontainer_1x1.zip"),
}

local RefreshIcon

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
    local image = inst.components.container:IsOpen()
        and "wx78_inventorycontainer_open"
        or (inst.components.container.canbeopened and "wx78_inventorycontainer_powered" or "wx78_inventorycontainer")
    inst.components.inventoryitem:ChangeImageName(image)
end

local function OnOpen(inst)
    RefreshIcon(inst)
end

local function OnClose(inst)
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

local FLOATER_SWAP_DATA = { bank = "wx78_inventorycontainer", anim = "dropped_idle" }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("wx78_inventorycontainer")
    inst.AnimState:SetBuild("wx78_inventorycontainer")
    inst.AnimState:PlayAnimation("dropped_idle")

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

    inst:AddComponent("container")
    inst.components.container:EnableInfiniteStackSize(true)
    inst.components.container:WidgetSetup("kei_protocol_container")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.canbeopened = false
    RefreshIcon(inst)

    MakeHauntableLaunchAndDropFirstItem(inst)

    inst.SetPowered = SetPowered

    return inst
end

return Prefab("kei_protocol_container", fn, assets)
