-- 边角料大师：制作有耐久的物品时，额外获得一件低耐久的相同物品。

local function GetExperienceTotal(inst)
    local experience = inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_experience
        or nil

    return experience ~= nil and tonumber(experience.total) or 0
end

local function IsActive(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst:HasTag("kei")
        and not inst:HasTag("playerghost")
        and GetExperienceTotal(inst) >= (TUNING.KEI_SCRAP_MASTER_EXPERIENCE_THRESHOLD or 20000)
end

local function GetRandomDurabilityPercent()
    -- 保证复制品仍有极少量耐久，不会因为生成时就耗尽而立即消失。
    return math.max(0.01, math.random() * 0.1)
end

local function SetLowDurability(item)
    if item == nil or item.components == nil then
        return false
    end

    local percent = GetRandomDurabilityPercent()
    local has_durability = false
    local finiteuses = item.components.finiteuses
    local armor = item.components.armor
    local fueled = item.components.fueled

    if finiteuses ~= nil
        and finiteuses.SetUses ~= nil
        and tonumber(finiteuses.total) ~= nil
        and finiteuses.total > 0
    then
        finiteuses:SetUses(finiteuses.total * percent)
        has_durability = true
    end

    if armor ~= nil
        and armor.SetPercent ~= nil
        and tonumber(armor.maxcondition) ~= nil
        and armor.maxcondition > 0
        and (armor.IsIndestructible == nil or not armor:IsIndestructible())
    then
        armor:SetPercent(percent)
        has_durability = true
    end

    if fueled ~= nil
        and fueled.SetPercent ~= nil
        and tonumber(fueled.maxfuel) ~= nil
        and fueled.maxfuel > 0
    then
        fueled:SetPercent(percent)
        has_durability = true
    end

    return has_durability
end

local function GiveScrapMasterBonus(inst, data)
    if not IsActive(inst) or data == nil or data.item == nil then
        return
    end

    local product = data.item
    if not product:IsValid()
        or product.components == nil
        or product.components.inventoryitem == nil
        or data.recipe == nil
        or data.recipe.product ~= product.prefab
    then
        return
    end

    local extra = SpawnPrefab(product.prefab, product.skinname)
    if extra == nil or not SetLowDurability(extra) then
        if extra ~= nil then
            extra:Remove()
        end
        return
    end

    local inventory = inst.components ~= nil and inst.components.inventory or nil
    if inventory ~= nil then
        inventory:GiveItem(extra, nil, inst:GetPosition())
    else
        extra:Remove()
    end
end

AddPrefabPostInit("kei", function(inst)
    if TheWorld == nil or not TheWorld.ismastersim then
        return
    end

    inst:ListenForEvent("builditem", GiveScrapMasterBonus)
end)
