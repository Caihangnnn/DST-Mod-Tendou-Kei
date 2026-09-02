local VirtualEquipment = {}

local function GuardCallback(equippable, field)
    local callback = equippable[field]
    if callback == nil then return false end

    equippable[field] = function(item, owner, from_ground)
        local builder = owner ~= nil and owner.components ~= nil and owner.components.builder or nil
        local previous_mod = builder ~= nil and builder.ingredientmod or 1
        local ok, result1, result2, result3 = pcall(callback, item, owner, from_ground)

        -- Keep discounts from real equipment, but remove reductions introduced
        -- by this virtual equipment callback.
        local current_mod = builder ~= nil and builder.ingredientmod or previous_mod
        if builder ~= nil and current_mod < previous_mod then
            builder.ingredientmod = previous_mod
        end
        if not ok then error(result1) end
        return result1, result2, result3
    end
    return true
end

function VirtualEquipment.GuardBuildDiscount(item)
    if TUNING.KEI_VIRTUAL_EQUIPMENT_BUILD_DISCOUNT ~= false
        or item == nil
        or item.components == nil
        or item.components.equippable == nil
        or item.components.equippable.kei_build_discount_guarded
    then
        return
    end

    local equippable = item.components.equippable
    local guarded = GuardCallback(equippable, "onequipfn")
    guarded = GuardCallback(equippable, "onequiptomodelfn") or guarded
    equippable.kei_build_discount_guarded = guarded or nil
end

return VirtualEquipment
