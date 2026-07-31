local assets = {
    Asset("ANIM", "anim/kei_items.zip"),
    Asset("ANIM", "anim/ui_kei_mini_alice_box_8x1.zip"),
    Asset("ATLAS", "images/inventoryimages/kei_mini_alice.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_mini_alice.tex"),
}

local ALICE_BANK = "kei_item"
local ALICE_BUILD = "kei_items"
local ALICE_GROUND_ANIM = "kei_analysis_cd_ground"
local ALICE_ICON_ATLAS = "images/inventoryimages/kei_mini_alice.xml"
local ALICE_ICON_CLOSED = "kei_mini_alice_closed"
local ALICE_ICON_OPEN = "kei_mini_alice_open"

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

local function RefreshAliceIcon(inst)
    if inst == nil
        or inst.components == nil
        or inst.components.inventoryitem == nil
        or inst.components.container == nil
    then
        return
    end

    local image = inst.components.container:IsOpen()
        and ALICE_ICON_OPEN
        or ALICE_ICON_CLOSED
    inst.components.inventoryitem.atlasname = ALICE_ICON_ATLAS
    inst.components.inventoryitem:ChangeImageName(image)
end

local function OnPutInInventory(inst)
    inst.components.inventoryitem.islockedinslot = true
    RefreshAliceIcon(inst)
end

local function OnDropped(inst)
    inst:AddTag("no_container_store")
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    inst:Remove()
end

local function OnOpen(inst)
    RefreshAliceIcon(inst)
end

local function OnClose(inst)
    RefreshAliceIcon(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(ALICE_BANK)
    inst.AnimState:SetBuild(ALICE_BUILD)
    inst.AnimState:PlayAnimation(ALICE_GROUND_ANIM)

    inst:AddTag("nosteal")
    inst:AddTag("no_container_store")
    inst:AddTag("kei_mini_alice")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.keepondeath = true

    inst:AddComponent("container")
    inst.components.container:EnableInfiniteStackSize(true)
    inst.components.container:WidgetSetup("kei_mini_alice_box")
    inst.components.container.stay_open_on_hide = true
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.canbeopened = true
    AllowParallelProtocolSlotOpen(inst.components.container)

    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(0)

    RefreshAliceIcon(inst)
    return inst
end

return Prefab("kei_mini_alice", fn, assets)
