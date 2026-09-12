local VirtualHandEquipment = {}
local VirtualEquipment = require("kei/protocols/analysis/virtual_equipment")
local Enchantment = require("kei/integrations/enchantment")

-- yyxk's character resource is the clearest example: its equipment calls
-- owner.components.yyxk:DoMP(-cost), and uses the return value to decide
-- whether the action may continue.  A missing resource must therefore behave
-- as "paid successfully", without adding a persistent component to Kei.
local VIRTUAL_MISSING_RESOURCE_VALUE = 1000000000
local VIRTUAL_RESOURCE_COMPONENTS = {
    yyxk = true,
    ccs_magic = true,
    fri_mana = true,
    fri_potion = true,
    mcwskill = true,
    ray_chirou = true,
    ray_duanlian = true,
    ray_heshui = true,
    ray_molizhi = true,
    ray_naili = true,
    ray_pilaozhi = true,
    ray_shucai = true,
}

local function IsVirtualResourceMutator(name)
    return type(name) == "string"
        and (name == "DoMP"
            or name == "DoDelta"
            or name:match("^Set") ~= nil
            or name:match("^Add") ~= nil
            or name:match("^Remove") ~= nil
            or name:match("^Use") ~= nil
            or name:match("^Consume") ~= nil
            or name:match("^DoDelta") ~= nil
            or name:match("^Spend") ~= nil
            or name:match("^Drain") ~= nil
            or name:match("^Deduct") ~= nil
            or name:match("^Recharge") ~= nil
            or name:match("^Restore") ~= nil)
end

local function IsVirtualResourceBooleanGetter(name)
    return type(name) == "string"
        and (name:match("^Can") ~= nil
            or name:match("^Has") ~= nil
            or name:match("^Is") ~= nil
            or name:match("^Should") ~= nil)
end

local function IsLikelyVirtualResourceMethod(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return name:match("^[A-Z]") ~= nil
        or lower_name:match("^do") ~= nil
        or lower_name:match("^get") ~= nil
        or lower_name:match("^set") ~= nil
        or lower_name:match("^add") ~= nil
        or lower_name:match("^remove") ~= nil
        or lower_name:match("^use") ~= nil
        or lower_name:match("^consume") ~= nil
        or lower_name:match("^spend") ~= nil
        or lower_name:match("^cost") ~= nil
        or lower_name:match("^drain") ~= nil
        or lower_name:match("^deduct") ~= nil
        or lower_name:match("^recharge") ~= nil
        or lower_name:match("^restore") ~= nil
        or lower_name:match("^check") ~= nil
        or lower_name:match("^pause") ~= nil
        or lower_name:match("^resume") ~= nil
        or lower_name:match("^update") ~= nil
        or lower_name:match("^reset") ~= nil
        or lower_name:match("^clear") ~= nil
        or lower_name:match("^xv") ~= nil
        or lower_name:match("^jian") ~= nil
        or lower_name:match("^xue") ~= nil
        or lower_name:match("^buk") ~= nil
end

local function IsVirtualResourceValueGetter(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return lower_name:match("^get.*current") ~= nil
        or lower_name:match("^get.*max") ~= nil
        or lower_name:match("^get.*amount") ~= nil
        or lower_name:match("^get.*value") ~= nil
        or lower_name:match("^get.*power") ~= nil
        or lower_name:match("^get.*energy") ~= nil
        or lower_name:match("^get.*mana") ~= nil
        or lower_name:match("^get.*magic") ~= nil
        or lower_name:match("^get.*stamina") ~= nil
        or lower_name:match("^get.*rage") ~= nil
        or lower_name:match("^get.*resource") ~= nil
        or lower_name:match("^get.*special") ~= nil
        or lower_name:match("^get.*percent") ~= nil
        or lower_name == "get"
end

local function IsVirtualResourceBooleanMethod(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return lower_name:match("^can") ~= nil
        or lower_name:match("^has") ~= nil
        or lower_name:match("^is") ~= nil
        or lower_name:match("^should") ~= nil
        or lower_name:match("^check") ~= nil
        or lower_name:match("^jian") ~= nil
end

local function IsLikelyVirtualResourceValue(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return lower_name:match("current") ~= nil
        or lower_name:match("^cur") ~= nil
        or lower_name:match("max") ~= nil
        or lower_name:match("amount") ~= nil
        or lower_name:match("value") ~= nil
        or lower_name:match("level") ~= nil
        or lower_name:match("lv$") ~= nil
        or lower_name:match("exp") ~= nil
        or lower_name:match("count") ~= nil
        or lower_name:match("point") ~= nil
        or lower_name:match("power") ~= nil
        or lower_name:match("energy") ~= nil
        or lower_name:match("mana") ~= nil
        or lower_name:match("stamina") ~= nil
        or lower_name:match("rage") ~= nil
        or lower_name:match("cost") ~= nil
        or lower_name == "mcwskill"
        or lower_name == "skillpoint"
        or lower_name == "skillpoints"
        or lower_name == "skillvalue"
        or lower_name == "picksomething"
        or lower_name == "finishedwork"
        or lower_name == "fishingcollect"
        or lower_name == "builditem"
        or lower_name == "learncookbookrecipe"
end

-- mcwskill is also used as a resource-like component by the MCW equipment
-- callbacks.  Its exact field names vary between equipment versions, so keep
-- the common current-value spellings numeric when the component is absent.
local function IsLikelyMCWSkillValue(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return lower_name == "mcwskill"
        or lower_name == "skillpoint"
        or lower_name == "skillpoints"
        or lower_name == "skillvalue"
        or lower_name == "skillcost"
        or lower_name == "current_skill"
        or lower_name == "currentskill"
        or lower_name == "skillnum"
        or lower_name == "skillvalue"
end

local function IsLikelyMCWSkillNestedValue(name)
    if type(name) ~= "string" then
        return false
    end
    local lower_name = name:lower()
    return lower_name == "skills"
        or lower_name == "skilldata"
        or lower_name == "skill_data"
        or lower_name == "data"
        or lower_name == "skill"
        or lower_name == "level"
        or lower_name == "rank"
end

local function IsLikelyVirtualResourceNestedValue(name)
    return type(name) == "string"
        and (name == "accumulateAction"
            or name == "nilxinup"
            or name == "yeyuup"
            or name == "skills"
            or name == "skill"
            or name == "stats"
            or name == "data")
end

-- Keep the exact yyxk component in the allow-list, while also accepting the
-- conventional names used by other character-resource components.  Unknown
-- components are never fabricated: a missing health/inventory/etc. component
-- remains a normal nil feature check.
local function IsLikelyVirtualResourceComponent(name)
    if type(name) ~= "string" then
        return false
    end
    if VIRTUAL_RESOURCE_COMPONENTS[name] then
        return true
    end
    local lower_name = name:lower()
    return lower_name:match("power") ~= nil
        or lower_name:match("energy") ~= nil
        or lower_name:match("stamina") ~= nil
        or lower_name:match("mana") ~= nil
        or lower_name:match("magic") ~= nil
        or lower_name:match("molizhi") ~= nil
        or lower_name:match("moli") ~= nil
        or lower_name:match("soul") ~= nil
        or lower_name:match("^mp$") ~= nil
        or lower_name:match("_mp$") ~= nil
        or lower_name:match("^sp$") ~= nil
        or lower_name:match("_sp$") ~= nil
        or lower_name:match("rage") ~= nil
        or lower_name:match("resource") ~= nil
        or lower_name:match("special") ~= nil
        or lower_name:match("cost") ~= nil
end

local function GetVirtualResourceValue(name)
    if type(name) ~= "string" then
        return nil
    end
    local lower_name = name:lower()
    if lower_name == "percent"
    then
        return 1
    elseif lower_name == "current"
        or lower_name == "curmp"
        or lower_name == "max"
        or lower_name == "maxmp"
        or lower_name == "amount"
        or lower_name == "value"
        or lower_name == "power"
        or lower_name == "energy"
        or lower_name == "cost"
    then
        return VIRTUAL_MISSING_RESOURCE_VALUE
    end
    return nil
end

-- A missing resource may expose nested state (for example yyxk's
-- `accumulateAction` or `skills`).  Return a callable nested proxy for that
-- state: it can be indexed by more fields and called as a custom method, but
-- never writes state or throws merely because the source character's field is
-- absent.
local function CreateVirtualResourceMember()
    local member
    local children = {}
    local member_metatable = {
        __index = function(_, name)
            local value = GetVirtualResourceValue(name)
            if value ~= nil then
                return value
            end
            if IsVirtualResourceBooleanMethod(name) then
                return function() return true end
            end
            if IsLikelyVirtualResourceMethod(name) then
                return function() return true end
            end
            if IsVirtualResourceValueGetter(name) then
                return function() return name:lower():match("percent") ~= nil and 1 or VIRTUAL_MISSING_RESOURCE_VALUE end
            end
            if IsLikelyVirtualResourceValue(name) then
                local lower_name = name:lower()
                if lower_name:match("level") ~= nil
                    or lower_name:match("lv$") ~= nil
                    or lower_name:match("exp") ~= nil
                then
                    return 0
                end
                return VIRTUAL_MISSING_RESOURCE_VALUE
            end
            if IsLikelyMCWSkillValue(name) then
                return VIRTUAL_MISSING_RESOURCE_VALUE
            end
            if IsLikelyMCWSkillNestedValue(name) then
                if children[name] == nil then
                    children[name] = CreateVirtualResourceMember()
                end
                return children[name]
            end
            if IsLikelyVirtualResourceNestedValue(name) then
                if children[name] == nil then
                    children[name] = CreateVirtualResourceMember()
                end
                return children[name]
            end
            return nil
        end,
        __newindex = function() end,
        __call = function() return true end,
        __tostring = function() return "virtual_missing_resource" end,
    }
    member = setmetatable({}, member_metatable)
    return member
end

local function CreateVirtualMissingResourceComponent()
    local proxy = {
        maxmp = VIRTUAL_MISSING_RESOURCE_VALUE,
        curmp = VIRTUAL_MISSING_RESOURCE_VALUE,
    }
    proxy.DoMP = function() return true end
    local members = {}

    setmetatable(proxy, {
        __index = function(_, name)
            local value = GetVirtualResourceValue(name)
            if value ~= nil then
                return value
            end
            if IsLikelyVirtualResourceValue(name) then
                return VIRTUAL_MISSING_RESOURCE_VALUE
            end
            if IsLikelyMCWSkillValue(name) then
                return VIRTUAL_MISSING_RESOURCE_VALUE
            end
            if IsLikelyMCWSkillNestedValue(name) then
                if members[name] == nil then
                    members[name] = CreateVirtualResourceMember()
                end
                return members[name]
            end
            if IsVirtualResourceValueGetter(name) then
                return function() return name:lower():match("percent") ~= nil and 1 or VIRTUAL_MISSING_RESOURCE_VALUE end
            end
            if IsVirtualResourceMutator(name) then
                return function() return true end
            end
            if IsVirtualResourceBooleanGetter(name) then
                return function() return true end
            end
            if IsLikelyVirtualResourceNestedValue(name) then
                if members[name] == nil then
                    members[name] = CreateVirtualResourceMember()
                end
                return members[name]
            end
            if IsVirtualResourceBooleanMethod(name) then
                return function() return true end
            end
            if IsLikelyVirtualResourceMethod(name) then
                return function() return true end
            end
            return nil
        end,
        __newindex = function() end,
    })
    return proxy
end

-- Run a virtual-equipment callback with temporary proxies for components that
-- the current character does not have.  A shallow components proxy is used
-- instead of changing the real components table's metatable.  This keeps the
-- engine's component table and all existing components untouched, including
-- when the callback throws an error.
local function CallWithVirtualMissingResources(owner, callback, ...)
    if owner == nil
        or owner.components == nil
        or type(callback) ~= "function"
    then
        return pcall(callback, ...)
    end

    local old_components = owner.components
    local components = {}
    local proxies = {}
    for name, component in pairs(old_components) do
        components[name] = component
    end

    local proxy_metatable = {
        __index = function(_, name)
            local value = old_components[name]
            if value ~= nil then
                return value
            end
            if not IsLikelyVirtualResourceComponent(name) then
                return nil
            end
            if proxies[name] == nil then
                proxies[name] = CreateVirtualMissingResourceComponent()
            end
            return proxies[name]
        end,
        __newindex = function(_, name, value)
            -- Changes to an existing component still target the real
            -- component table.  New entries stay on the temporary proxy so
            -- an equipment callback cannot accidentally install a persistent
            -- character-only component through AddComponent-style code.
            if old_components[name] ~= nil then
                old_components[name] = value
            else
                rawset(components, name, value)
            end
        end,
    }

    setmetatable(components, proxy_metatable)
    local set_ok = pcall(function()
        owner.components = components
    end)
    if not set_ok then
        return pcall(callback, ...)
    end

    local results = { pcall(callback, ...) }
    pcall(function()
        owner.components = old_components
    end)
    return unpack(results)
end

-- Only these vanilla weapon prefabs receive the virtual-staff attack cooldown.
-- Keep this list explicit: ranged or spellcaster items are not automatically
-- treated as staves.
local VIRTUAL_STAFF_PREFABS = {
    icestaff = true,
    icestaff2 = true,
    icestaff3 = true,
    firestaff = true,
}

function VirtualHandEquipment.IsVirtualStaff(item)
    return item ~= nil
        and item:HasTag("kei_virtual_hand_equipment")
        and VIRTUAL_STAFF_PREFABS[item.kei_source_prefab or item.prefab] == true
end

-- Keep source callbacks safe while disabling armor inheritance.
local function DisableVirtualHandArmor(item)
    local armor = item.components.armor
    if armor == nil then
        return
    end

    if armor.InitIndestructible ~= nil then
        armor:InitIndestructible(0)
    else
        armor.indestructible = true
        armor.absorb_percent = 0
    end

    armor.condition = armor.maxcondition or armor.condition
    armor.onfinished = nil
    armor.ontakedamage = nil
end

-- 清理虚拟装备
local function CleanVirtualEquipment(item)
    item.persists = false
    item:AddTag("kei_virtual_equipment")
    item:AddTag("NOCLICK")
    item:RemoveTag("heavy")
    item:RemoveTag("repairable")

    if item.components.equippable ~= nil then
        item.components.equippable.restrictedtag = nil
        item.components.equippable.equipslot = EQUIPSLOTS.HANDS
        item.components.equippable:SetPreventUnequipping(false)
    end

    if item.components.container ~= nil then
        item:RemoveComponent("container")
    end

    if item.components.inventoryitem ~= nil then
        item.components.inventoryitem.canbepickedup = false
        item.components.inventoryitem.cangoincontainer = false
        item.components.inventoryitem.keepondeath = true
    end

    if item.components.trader ~= nil then
        item:RemoveComponent("trader")
    end

    if item.components.repairable ~= nil then
        item:RemoveComponent("repairable")
    end

    -- Keep durability-related components available for source callbacks, but
    -- freeze the virtual copy so its state cannot change.
    VirtualEquipment.LockDurability(item)

    VirtualEquipment.GuardBuildDiscount(item)
    DisableVirtualHandArmor(item)
end

-- 断开虚拟装备与当前持有者的归属关系，避免残留在实体层级中
local function ClearVirtualInventoryOwner(item)
    local inventoryitem = item.components.inventoryitem
    if inventoryitem == nil then return end

    local owner = inventoryitem.owner
    if owner ~= nil then
        owner:RemoveChild(item)
    end
    inventoryitem:ClearOwner()
end

-- 延迟移除虚拟装备，避免在回调链中立刻删除导致报错
local function ScheduleVirtualEquipmentRemove(item)
    if item == nil or not item:IsValid() or item.kei_pending_virtual_remove then return end

    item.kei_pending_virtual_remove = true
    item.persists = false
    item:Hide()
    item:DoTaskInTime(0.1, function(inst)
        if inst:IsValid() then
            inst:Remove()
        end
    end)
end

-- 忽略虚拟手部装备在凯伊角色上的已知回调异常，避免中断流程
local function IgnoreVirtualHandCallbackError(item, err)
    local owner = item.components.inventoryitem ~= nil and item.components.inventoryitem.owner or nil
    if owner ~= nil and owner:HasTag("kei") and item:HasTag("kei_virtual_hand_equipment") then
        print("[Tendou Kei] ignored virtual hand equipment callback error: " .. tostring(err))
        return true
    end
    return false
end

local function GetVirtualEquipmentOwner(item)
    local inventoryitem = item ~= nil and item.components.inventoryitem or nil
    return inventoryitem ~= nil and inventoryitem.owner or nil
end

local function IsVirtualHandKeiUser(item, user)
    return item ~= nil
        and item:HasTag("kei_virtual_hand_equipment")
        and user ~= nil
        and user:HasTag("kei")
end

-- 为虚拟装备的武器和施法回调加保护包装，屏蔽不兼容装备的运行时错误。
-- 这里的核心思路是：虚拟手持装备并不一定完整模拟原装备的所有上下文，
-- 某些武器或法术回调在被“虚拟装备”触发时可能访问不到预期数据而报错。
-- 因此这里会把关键回调包一层 pcall，仅在凯伊使用虚拟装备时报错时吞掉异常并回退；
-- 如果是真实装备或其他角色触发异常，则继续抛错，避免掩盖正常问题。
local function WrapVirtualHandEquipment(item)
    local equippable = item.components.equippable
    if equippable ~= nil then
        if equippable.onequipfn ~= nil and not equippable.kei_virtual_hand_safe_onequip then
            local old_onequip = equippable.onequipfn
            equippable.onequipfn = function(inst, owner, from_ground)
                local ok, result1, result2 = CallWithVirtualMissingResources(
                    owner,
                    old_onequip,
                    inst,
                    owner,
                    from_ground
                )
                if ok then
                    return result1, result2
                end
                if owner ~= nil and owner:HasTag("kei") then
                    print("[Tendou Kei] ignored virtual hand equipment equip error: " .. tostring(result1))
                    return nil
                end
                error(result1)
            end
            equippable.kei_virtual_hand_safe_onequip = true
        end

        if equippable.onunequipfn ~= nil and not equippable.kei_virtual_hand_safe_onunequip then
            local old_onunequip = equippable.onunequipfn
            equippable.onunequipfn = function(inst, owner)
                local ok, result1, result2 = CallWithVirtualMissingResources(
                    owner,
                    old_onunequip,
                    inst,
                    owner
                )
                if ok then
                    return result1, result2
                end
                if owner ~= nil and owner:HasTag("kei") then
                    print("[Tendou Kei] ignored virtual hand equipment unequip error: " .. tostring(result1))
                    return nil
                end
                error(result1)
            end
            equippable.kei_virtual_hand_safe_onunequip = true
        end

        if equippable.onpocketfn ~= nil and not equippable.kei_virtual_hand_safe_onpocket then
            local old_onpocket = equippable.onpocketfn
            equippable.onpocketfn = function(inst, owner)
                local ok, result1, result2 = CallWithVirtualMissingResources(
                    owner,
                    old_onpocket,
                    inst,
                    owner
                )
                if ok then
                    return result1, result2
                end
                if owner ~= nil and owner:HasTag("kei") then
                    print("[Tendou Kei] ignored virtual hand equipment pocket error: " .. tostring(result1))
                    return nil
                end
                error(result1)
            end
            equippable.kei_virtual_hand_safe_onpocket = true
        end
    end

    local weapon = item.components.weapon
    -- 包装伤害计算函数：
    -- 某些武器的 GetDamage 会依赖额外状态，虚拟装备缺少这些状态时可能直接报错。
    -- 如果是凯伊触发，则打印日志并退回到 weapon.damage 的基础伤害，保证攻击流程不断。
    if weapon ~= nil and weapon.GetDamage ~= nil and not weapon.kei_virtual_hand_safe_getdamage then
        local old_getdamage = weapon.GetDamage
        weapon.GetDamage = function(self, attacker, target)
            local ok, damage, spdamage = CallWithVirtualMissingResources(
                attacker,
                old_getdamage,
                self,
                attacker,
                target
            )
            if ok then
                return damage, spdamage
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon damage error: " .. tostring(damage))
                return self.damage or 0
            end
            error(damage)
        end
        weapon.kei_virtual_hand_safe_getdamage = true
    end

    -- 包装近战攻击回调：
    -- 原始 onattack 可能会生成特效、附带状态或读取额外组件。
    -- 当这些逻辑与虚拟装备不兼容时，只对凯伊的虚拟手持忽略错误，避免一次攻击把整条逻辑链打断。
    if weapon ~= nil and weapon.onattack ~= nil and not weapon.kei_virtual_hand_safe_onattack then
        local old_onattack = weapon.onattack
        weapon.onattack = function(inst, attacker, target, projectile)
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                attacker,
                old_onattack,
                inst,
                attacker,
                target,
                projectile
            )
            if ok then
                return result1, result2, result3
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon onattack error: " .. tostring(result1))
                return nil
            end
            error(result1)
        end
        weapon.kei_virtual_hand_safe_onattack = true
    end

    -- 包装投射物发射回调：
    -- 有些远程武器会在发射瞬间执行额外逻辑，虚拟装备在这个阶段也可能缺上下文。
    -- 出错时同样只对凯伊虚拟手持做降级处理，其余情况保留原始报错。
    if weapon ~= nil and weapon.onprojectilelaunched ~= nil and not weapon.kei_virtual_hand_safe_onprojectilelaunched then
        local old_onprojectilelaunched = weapon.onprojectilelaunched
        weapon.onprojectilelaunched = function(inst, attacker, target, projectile)
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                attacker,
                old_onprojectilelaunched,
                inst,
                attacker,
                target,
                projectile
            )
            if ok then
                return result1, result2, result3
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon projectile error: " .. tostring(result1))
                return nil
            end
            error(result1)
        end
        weapon.kei_virtual_hand_safe_onprojectilelaunched = true
    end

    if weapon ~= nil and weapon.onprojectilelaunch ~= nil and not weapon.kei_virtual_hand_safe_onprojectilelaunch then
        local old_onprojectilelaunch = weapon.onprojectilelaunch
        weapon.onprojectilelaunch = function(inst, attacker, target)
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                attacker,
                old_onprojectilelaunch,
                inst,
                attacker,
                target
            )
            if ok then
                return result1, result2, result3
            end
            if attacker ~= nil and attacker:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand weapon projectile launch error: " .. tostring(result1))
                return nil
            end
            error(result1)
        end
        weapon.kei_virtual_hand_safe_onprojectilelaunch = true
    end

    -- AOESpell is another common hand-item activation path.  Its callback is
    -- called as (item, doer, pos), so the doer is the second argument.
    local aoespell = item.components.aoespell
    if aoespell ~= nil and aoespell.spellfn ~= nil and not aoespell.kei_virtual_hand_safe_spellfn then
        local old_aoe_spell = aoespell.spellfn
        aoespell.spellfn = function(inst, doer, pos)
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                doer,
                old_aoe_spell,
                inst,
                doer,
                pos
            )
            if ok then
                return result1, result2, result3
            end
            if doer ~= nil and doer:HasTag("kei") then
                print("[Tendou Kei] ignored virtual hand AOE spell error: " .. tostring(result1))
                return false, result1
            end
            error(result1)
        end
        aoespell.kei_virtual_hand_safe_spellfn = true
    end

    local spellcaster = item.components.spellcaster
    if spellcaster ~= nil and spellcaster.can_cast_fn ~= nil and not spellcaster.kei_virtual_hand_safe_can_cast then
        local old_can_cast = spellcaster.can_cast_fn
        spellcaster.can_cast_fn = function(caster, target, pos, spell_item)
            local ok, result1, result2 = CallWithVirtualMissingResources(
                caster,
                old_can_cast,
                caster,
                target,
                pos,
                spell_item
            )
            if ok then
                return result1, result2
            end
            if IgnoreVirtualHandCallbackError(item, result1) then
                return false, result1
            end
            error(result1)
        end
        spellcaster.kei_virtual_hand_safe_can_cast = true
    end

    -- Some mods replace the component method directly instead of using
    -- SetCanCastFn. Preserve that calling convention while giving the custom
    -- method the same temporary resource view.
    local custom_can_cast = spellcaster ~= nil and rawget(spellcaster, "CanCast") or nil
    if type(custom_can_cast) == "function" and not spellcaster.kei_virtual_hand_safe_custom_can_cast then
        spellcaster.CanCast = function(spellcaster_self, ...)
            local args = { ... }
            local doer = args[1]
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                doer,
                custom_can_cast,
                spellcaster_self,
                unpack(args)
            )
            if ok then
                return result1, result2, result3
            end
            if IgnoreVirtualHandCallbackError(item, result1) then
                return false, result1
            end
            error(result1)
        end
        spellcaster.kei_virtual_hand_safe_custom_can_cast = true
    end

    -- 包装施法回调：
    -- 部分法杖或法术物品在施法时会校验 owner、库存归属或其他运行环境。
    -- 这里复用统一的异常过滤逻辑，只忽略“凯伊 + 虚拟手部装备”这一类已知可接受错误。
    if spellcaster ~= nil and spellcaster.spell ~= nil and not spellcaster.kei_virtual_hand_safe_spell then
        local old_spell = spellcaster.spell
        spellcaster.spell = function(spellcaster_self, target, pos, doer)
            local caster = doer or GetVirtualEquipmentOwner(item)
            local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                caster,
                old_spell,
                spellcaster_self,
                target,
                pos,
                doer
            )
            if ok then
                return result1, result2, result3
            end
            if IgnoreVirtualHandCallbackError(item, result1) then
                return nil
            end
            error(result1)
        end
        spellcaster.kei_virtual_hand_safe_spell = true
    end

    -- Spellbook callbacks are used by a few modded equipment items instead of
    -- spellcaster.  Keep their user argument in the same compatibility view.
    local spellbook = item.components.spellbook
    if spellbook ~= nil then
        if spellbook.canusefn ~= nil and not spellbook.kei_virtual_hand_safe_canuse then
            local old_can_use = spellbook.canusefn
            spellbook.canusefn = function(inst, user)
                local ok, result1, result2 = CallWithVirtualMissingResources(
                    user,
                    old_can_use,
                    inst,
                    user
                )
                if ok then
                    return result1, result2
                end
                if user ~= nil and user:HasTag("kei") then
                    print("[Tendou Kei] ignored virtual hand spellbook availability error: " .. tostring(result1))
                    return false, result1
                end
                error(result1)
            end
            spellbook.kei_virtual_hand_safe_canuse = true
        end

        if spellbook.spellfn ~= nil and not spellbook.kei_virtual_hand_safe_spellfn then
            local old_spellbook_spell = spellbook.spellfn
            spellbook.spellfn = function(inst, user)
                local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                    user,
                    old_spellbook_spell,
                    inst,
                    user
                )
                if ok then
                    return result1, result2, result3
                end
                if user ~= nil and user:HasTag("kei") then
                    print("[Tendou Kei] ignored virtual hand spellbook error: " .. tostring(result1))
                    return false, result1
                end
                error(result1)
            end
            spellbook.kei_virtual_hand_safe_spellfn = true
        end
    end

    -- MCW and some other mods ship their own spellcaster component instead of
    -- using the vanilla `spellcaster` component.  Their CastSpell methods
    -- still call a callback named `spell(inst, target, pos, doer)`.  Discover
    -- these components by name so a mod update can add another custom
    -- spellcaster without requiring a hard-coded component key.
    for component_name, component in pairs(item.components) do
        local lower_component_name = type(component_name) == "string"
            and component_name:lower()
            or ""
        if lower_component_name:match("spellcaster") ~= nil
            and component ~= spellcaster
            and type(component.spell) == "function"
            and not component.kei_virtual_hand_safe_spell
        then
            local old_spell = component.spell
            component.spell = function(inst, target, pos, doer)
                local ok, result1, result2, result3 = CallWithVirtualMissingResources(
                    doer,
                    old_spell,
                    inst,
                    target,
                    pos,
                    doer
                )
                if ok then
                    return result1, result2, result3
                end
                if IsVirtualHandKeiUser(item, doer) then
                    print("[Tendou Kei] ignored virtual hand " .. component_name .. " spell error: " .. tostring(result1))
                    return nil
                end
                error(result1)
            end
            component.kei_virtual_hand_safe_spell = true
        end
    end
end

-- 移除当前已挂载的虚拟手部装备，并清理背包槽位和所有权
function VirtualHandEquipment.Remove(protocolslots)
    local virtual = protocolslots.virtual_hand_equip
    if virtual == nil then return end

    protocolslots.virtual_hand_equip = nil

    local inventory = protocolslots.inst.components.inventory
    if inventory ~= nil and inventory.equipslots ~= nil and inventory.equipslots[EQUIPSLOTS.HANDS] == virtual then
        inventory.equipslots[EQUIPSLOTS.HANDS] = nil
        inventory.floaterheld = nil

        ClearVirtualInventoryOwner(virtual)
        protocolslots.inst:PushEvent("unequip", { item = virtual, eslot = EQUIPSLOTS.HANDS, no_animation = true, kei_virtual_silent = true })
    end

    if virtual:IsValid() then
        ScheduleVirtualEquipmentRemove(virtual)
    end
end

-- 根据协议槽数据生成并装备虚拟手部装备，失败时回滚并返回 false
function VirtualHandEquipment.Apply(protocolslots, entry)
    local data = entry.data
    local inventory = protocolslots.inst.components.inventory
    if data.source == nil or inventory == nil then
        VirtualHandEquipment.Remove(protocolslots)
        return false
    end

    local hand_item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if hand_item ~= nil and hand_item ~= protocolslots.virtual_hand_equip then
        VirtualHandEquipment.Remove(protocolslots)
        return false
    end

    local current = protocolslots.virtual_hand_equip
    local enchantment_key = Enchantment.GetKey(data.enchantments)
    if current ~= nil
        and current:IsValid()
        and current.kei_source_prefab == data.source
        and current.kei_enchantment_key == enchantment_key
        and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == current
    then
        return true
    end

    local was_suppressing = protocolslots._kei_suppress_hand_virtual
    protocolslots._kei_suppress_hand_virtual = true
    VirtualHandEquipment.Remove(protocolslots)
    protocolslots._kei_suppress_hand_virtual = was_suppressing

    local virtual = SpawnPrefab(data.source, data.skin_name)
    if virtual == nil or virtual.components.equippable == nil or virtual.components.stackable ~= nil then
        if virtual ~= nil then
            ScheduleVirtualEquipmentRemove(virtual)
        end
        return false
    end

    virtual.kei_source_prefab = data.source
    virtual.kei_enchantment_key = enchantment_key
    virtual:AddTag("kei_virtual_hand_equipment")
    if VIRTUAL_STAFF_PREFABS[data.source] then
        virtual:AddTag("kei_virtual_staff")
    end
    Enchantment.Apply(virtual, data.enchantments)
    CleanVirtualEquipment(virtual)
    WrapVirtualHandEquipment(virtual)

    inventory:Equip(virtual, nil, true)
    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == virtual then
        protocolslots.virtual_hand_equip = virtual
        return true
    end

    ScheduleVirtualEquipmentRemove(virtual)
    return false
end

return VirtualHandEquipment
