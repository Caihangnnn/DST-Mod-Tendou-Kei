-- 植物学家：累计经验达到要求后，采集和收获时额外获得一份产品。

local BOTANIST_PICKABLE_BLACKLIST = {
    -- 华丽基座取出的宝石属于机关交互产物，不属于植物学家加成范围。
    archive_switch = true,
}

local function GetExperienceTotal(inst)
    if inst == nil then
        return 0
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience ~= nil then
        return tonumber(experience.total) or 0
    end

    -- 客户端只用于状态预测，实际产品生成始终在服务器执行。
    if inst._kei_experience_total ~= nil then
        return tonumber(inst._kei_experience_total:value()) or 0
    end

    return 0
end

local function IsActivePicker(picker)
    return picker ~= nil
        and picker:IsValid()
        and picker:HasTag("kei")
        and not picker:HasTag("playerghost")
        and GetExperienceTotal(picker) >= (TUNING.KEI_BOTANIST_EXPERIENCE_THRESHOLD or 5000)
end

local function IsBlacklistedPickable(inst)
    return inst ~= nil and BOTANIST_PICKABLE_BLACKLIST[inst.prefab] == true
end

local function GiveExtraCropProduct(harvester, product, position)
    if product == nil or not product:IsValid() then
        return
    end

    local extra = SpawnPrefab(product.prefab)
    if extra == nil then
        return
    end

    if extra.components ~= nil and extra.components.inventoryitem ~= nil then
        extra.components.inventoryitem:InheritWorldWetnessAtTarget(product)
    end

    if harvester ~= nil
        and harvester.components ~= nil
        and harvester.components.inventory ~= nil
    then
        harvester.components.inventory:GiveItem(extra, nil, position)
    else
        extra.Transform:SetPosition(position:Get())
    end
end

local function AddPickableProductBonus(component)
    if component._kei_botanist_spawn_wrapped then
        return
    end

    local old_spawn_product_loot = component.SpawnProductLoot
    if old_spawn_product_loot == nil then
        return
    end

    component._kei_botanist_spawn_wrapped = true
    component.SpawnProductLoot = function(self, picker, ...)
        if not IsActivePicker(picker) or IsBlacklistedPickable(self.inst) then
            return old_spawn_product_loot(self, picker, ...)
        end

        -- 普通 pickable 通过 numtoharvest 控制产品数量，临时增加一次，
        -- 不改变采集结束后的原始配置。
        if not self.use_lootdropper_for_product then
            local old_num = self.numtoharvest
            self.numtoharvest = (old_num or 1) + 1
            local result = old_spawn_product_loot(self, picker, ...)
            self.numtoharvest = old_num
            return result
        end

        -- 农作物等 pickable 使用 lootdropper 生成产品。让本次采集额外
        -- 进行一次 GenerateLoot 判定，并将结果合并到本次收获中。
        local lootdropper = self.inst.components ~= nil and self.inst.components.lootdropper or nil
        if lootdropper == nil or lootdropper.GenerateLoot == nil then
            return old_spawn_product_loot(self, picker, ...)
        end

        local old_generate_loot = lootdropper.GenerateLoot
        local added = false
        lootdropper.GenerateLoot = function(dropper, ...)
            local loot = old_generate_loot(dropper, ...)
            if not added and loot ~= nil then
                added = true
                local extra_loot = old_generate_loot(dropper, ...)
                if extra_loot ~= nil then
                    for _, prefab in ipairs(extra_loot) do
                        table.insert(loot, prefab)
                    end
                end
            end
            return loot
        end

        local result = old_spawn_product_loot(self, picker, ...)
        lootdropper.GenerateLoot = old_generate_loot
        return result
    end
end

local function AddHarvestableProductBonus(component)
    if component._kei_botanist_harvest_wrapped then
        return
    end

    local old_harvest = component.Harvest
    if old_harvest == nil then
        return
    end

    component._kei_botanist_harvest_wrapped = true
    component.Harvest = function(self, picker, ...)
        if IsActivePicker(picker) and self:CanBeHarvested() then
            -- Harvest 内部会将 produce 清零，并按该值逐个生成产品。
            self.produce = (self.produce or 0) + 1
        end
        return old_harvest(self, picker, ...)
    end
end

local function AddCropProductBonus(component)
    if component._kei_botanist_crop_harvest_wrapped then
        return
    end

    local old_harvest = component.Harvest
    if old_harvest == nil then
        return
    end

    component._kei_botanist_crop_harvest_wrapped = true
    component.Harvest = function(self, harvester, ...)
        local active = IsActivePicker(harvester)
        local position = self.inst:GetPosition()
        local harvested, product = old_harvest(self, harvester, ...)
        if active and harvested and product ~= nil then
            GiveExtraCropProduct(harvester, product, position)
        end
        return harvested, product
    end
end

AddComponentPostInit("pickable", AddPickableProductBonus)
AddComponentPostInit("harvestable", AddHarvestableProductBonus)
AddComponentPostInit("crop", AddCropProductBonus)
