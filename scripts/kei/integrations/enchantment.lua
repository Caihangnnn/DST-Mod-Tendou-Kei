local Enchantment = {}

local MAX_ENCHANTS = 4

local function GetComponent(inst)
    return inst ~= nil and inst.components ~= nil and inst.components.hh_equip or nil
end

local function CopyEnchantments(enchantments)
    if type(enchantments) ~= "table" then
        return nil
    end

    local result = {}
    for _, enchantment in ipairs(enchantments) do
        if type(enchantment) == "table"
            and type(enchantment.name) == "string"
        then
            table.insert(result, {
                name = enchantment.name,
                value = enchantment.value,
            })
        end
    end
    return #result > 0 and result or nil
end

function Enchantment.GetKey(enchantments)
    local copied = CopyEnchantments(enchantments)
    if copied == nil then
        return ""
    end

    local parts = {}
    for _, enchantment in ipairs(copied) do
        table.insert(parts, tostring(enchantment.name) .. "=" .. tostring(enchantment.value))
    end
    return table.concat(parts, "|")
end

local function EnsureComponent(inst)
    local component = GetComponent(inst)
    if component ~= nil then
        return component
    end

    -- The component only exists when the enchantment mod is enabled. Keep the
    -- compatibility path optional so Kei remains usable on its own.
    if inst == nil or inst.AddComponent == nil then
        return nil
    end
    local success = pcall(inst.AddComponent, inst, "hh_equip")
    return success and GetComponent(inst) or nil
end

function Enchantment.Capture(inst)
    if TUNING.KEI_ANALYSIS_RECORD_ENCHANT ~= true then
        return nil
    end

    local component = GetComponent(inst)
    return component ~= nil and CopyEnchantments(component.equip_buff_list) or nil
end

function Enchantment.Apply(inst, enchantments)
    if TUNING.KEI_ANALYSIS_RECORD_ENCHANT ~= true then
        return false
    end

    local copied = CopyEnchantments(enchantments)
    if copied == nil then
        return false
    end

    local component = EnsureComponent(inst)
    if component == nil or component.AddEquipBuff == nil then
        return false
    end

    -- Analysis CDs can call SetAnalysisData during both creation and loading;
    -- the component may already have restored its own saved list.
    if type(component.equip_buff_list) == "table" and #component.equip_buff_list > 0 then
        return true
    end

    if component.SetEquipBuffLimit ~= nil then
        component:SetEquipBuffLimit(math.min(#copied, MAX_ENCHANTS))
    end
    for _, enchantment in ipairs(copied) do
        component:AddEquipBuff(enchantment.name, enchantment.value)
    end
    return true
end

-- Virtual armor deliberately clears source equip callbacks. Restore only the
-- enchantment callbacks so source-prefab behavior remains suppressed.
function Enchantment.InstallVirtualArmorCallbacks(inst)
    local component = GetComponent(inst)
    local equippable = inst ~= nil and inst.components ~= nil and inst.components.equippable or nil
    if component == nil or equippable == nil or component.HandleEquipBuffToPlayer == nil then
        return
    end

    equippable:SetOnEquip(function(item, owner)
        if owner ~= nil and owner:IsValid() and owner:HasTag("player") then
            component:HandleEquipBuffToPlayer(owner, true)
        end
    end)
    equippable:SetOnUnequip(function(item, owner)
        if owner ~= nil and owner:IsValid() and owner:HasTag("player") then
            component:HandleEquipBuffToPlayer(owner, false)
        end
    end)
end

return Enchantment
