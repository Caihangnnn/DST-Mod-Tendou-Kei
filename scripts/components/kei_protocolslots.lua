local KeiProtocolSlots = Class(function(self, inst)
    self.inst = inst
    self.unlocked_slots = 1
    self.active = {}
    self.active_combat = {}

    -- 每秒重新扫描背包前若干格，便于玩家直接拖动 CD 后立即生效。
    self._scan_task = inst:DoPeriodicTask(1, function()
        self:Refresh()
    end)
    -- 协议不是免费常驻：按周期扣除电量或稳定性。
    self._drain_task = inst:DoPeriodicTask(TUNING.KEI_PROTOCOL_DRAIN_PERIOD, function()
        self:DrainProtocols()
    end)

    -- 战斗协议需要在 Kei 命中目标时触发。
    inst:ListenForEvent("onhitother", function(_, data)
        self:OnHitOther(data)
    end)
end)

local function IsProtocol(item)
    -- 协议 CD 通过标签和 kei_protocol_data 双重判断，避免误读普通物品。
    return item ~= nil and item:HasTag("kei_protocol_cd") and item.kei_protocol_data ~= nil
end

local function ProtocolNeedsPower(data)
    -- 战斗协议与护甲类解析协议消耗电量。
    return data.kind == "combat" or data.slot == "head" or data.slot == "body"
end

local function ProtocolNeedsStability(data)
    -- 武器 / 手部解析协议消耗稳定性。
    return data.slot == "hands"
end

function KeiProtocolSlots:OnRemoveFromEntity()
    self:ClearModifiers()
end

function KeiProtocolSlots:UnlockTier(tier)
    -- 解锁顺序固定为 1/3/5/7 格，重复使用低阶模块不会消耗。
    local target_slots = ({ 3, 5, 7 })[tier]
    if target_slots == nil or target_slots <= self.unlocked_slots then
        return false
    end
    self.unlocked_slots = math.min(target_slots, TUNING.KEI_PROTOCOL_SLOT_MAX)
    self:Refresh()
    return true
end

function KeiProtocolSlots:CanRun(data)
    -- 对应资源见底时，该协议会被扫描逻辑临时跳过。
    if ProtocolNeedsPower(data) and self.inst.components.hunger ~= nil and self.inst.components.hunger.current <= 0 then
        return false
    end
    if ProtocolNeedsStability(data) and self.inst.components.sanity ~= nil and self.inst.components.sanity.current <= 0 then
        return false
    end
    return true
end

function KeiProtocolSlots:GetProtocolSlotItems()
    -- 只读取背包物品栏前 7 格，并且只启用已经解锁的格子。
    local items = {}
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return items
    end
    for i = 1, TUNING.KEI_PROTOCOL_SLOT_MAX do
        local item = inventory.itemslots[i]
        if IsProtocol(item) and i <= self.unlocked_slots and self:CanRun(item.kei_protocol_data) then
            table.insert(items, {
                item = item,
                slot = i,
                data = item.kei_protocol_data,
            })
        end
    end
    return items
end

function KeiProtocolSlots:ClearModifiers()
    -- 移除本组件加过的所有外部倍率，防止卸载或刷新后残留。
    if self.inst.components.health ~= nil then
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, "kei_analysis_armor")
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "kei_analysis_hands")
    end
end

function KeiProtocolSlots:Refresh()
    -- 每次刷新都从当前背包状态重新计算，避免记录增量带来的脏状态。
    local items = self:GetProtocolSlotItems()
    local combat = {}
    local armor_absorb = 0
    local damage_mult = 1
    local speed_mult = 1
    local planar_bonus = 0

    self.active = items

    for _, entry in ipairs(items) do
        local data = entry.data
        if data.kind == "combat" and data.protocol ~= nil then
            -- 战斗协议只记录开关，具体效果在命中事件里执行。
            combat[data.protocol] = true
        elseif data.kind == "analysis" then
            -- 解析协议可以叠加或取最大值，取值规则集中放在这里。
            if data.slot == "head" or data.slot == "body" then
                armor_absorb = math.max(armor_absorb, data.absorb or 0)
            elseif data.slot == "hands" then
                damage_mult = damage_mult * (data.damage_mult or 1)
                speed_mult = speed_mult * (data.speed_mult or 1)
                planar_bonus = planar_bonus + (data.planar_bonus or 0)
            end
        end
    end

    self.active_combat = combat

    if self.inst.components.health ~= nil then
        -- 护甲解析使用 health 的外部吸收修正。
        self.inst.components.health.externalabsorbmodifiers:SetModifier(self.inst, armor_absorb, "kei_analysis_armor")
    end
    if self.inst.components.combat ~= nil then
        -- 手部解析的攻击倍率挂在 combat 外部伤害倍率上。
        self.inst.components.combat.externaldamagemultipliers:SetModifier(self.inst, damage_mult, "kei_analysis_hands")
    end
    if planar_bonus > 0 then
        if self.inst.components.planardamage == nil then
            self.inst:AddComponent("planardamage")
        end
        self.inst.components.planardamage:AddBonus(self.inst, planar_bonus, "kei_analysis_hands")
    elseif self.inst.components.planardamage ~= nil then
        self.inst.components.planardamage:RemoveBonus(self.inst, "kei_analysis_hands")
    end
    if self.inst.components.locomotor ~= nil then
        -- 手部解析里可能包含武器或装备带来的移动倍率。
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "kei_analysis_hands", speed_mult)
    end
end

function KeiProtocolSlots:DrainProtocols()
    -- 按当前 active 列表汇总消耗，避免重复扫描背包和扣费不同步。
    local power_cost = 0
    local stability_cost = 0

    for _, entry in ipairs(self.active) do
        local data = entry.data
        if ProtocolNeedsPower(data) then
            power_cost = power_cost + TUNING.KEI_PROTOCOL_DRAIN_AMOUNT
        elseif ProtocolNeedsStability(data) then
            stability_cost = stability_cost + TUNING.KEI_PROTOCOL_DRAIN_AMOUNT
        end
    end

    if power_cost > 0 and self.inst.components.hunger ~= nil then
        self.inst.components.hunger:DoDelta(-power_cost)
    end
    if stability_cost > 0 and self.inst.components.sanity ~= nil then
        self.inst.components.sanity:DoDelta(-stability_cost)
    end

    self:Refresh()
end

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }

function KeiProtocolSlots:DoBeargerPulse(target, weapon)
    -- 熊獾协议：命中目标周围小范围溅射。_doing_aoe 防止溅射再次触发溅射。
    if self._doing_aoe or target == nil or target.components.combat == nil then
        return
    end
    self._doing_aoe = true
    local x, y, z = target.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 3, AREA_MUST_TAGS, AREA_EXCLUDE_TAGS)
    for _, ent in ipairs(ents) do
        if ent ~= target
            and ent ~= self.inst
            and ent.components.combat ~= nil
            and self.inst.components.combat ~= nil
            and self.inst.components.combat:IsValidTarget(ent)
        then
            local damage = self.inst.components.combat:CalcDamage(ent, weapon, 0.35)
            ent.components.combat:GetAttacked(self.inst, damage, weapon)
        end
    end
    self._doing_aoe = false
end

function KeiProtocolSlots:OnHitOther(data)
    -- 三类巨兽战斗协议都从同一个命中事件入口分发。
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() then
        return
    end

    if self.active_combat.deerclops and target.components.freezable ~= nil then
        -- 独眼巨鹿协议：为目标叠加寒冷值。
        target.components.freezable:AddColdness(1)
        target.components.freezable:SpawnShatterFX()
    end

    if self.active_combat.dragonfly and target.components.burnable ~= nil and not target.components.burnable:IsBurning() then
        -- 龙蝇协议：用 controlled_burner 标签模拟可控点燃，减少误伤行为。
        local had_tag = self.inst:HasTag("controlled_burner")
        if not had_tag then
            self.inst:AddTag("controlled_burner")
        end
        target.components.burnable:Ignite(nil, self.inst, self.inst)
        if not had_tag then
            self.inst:RemoveTag("controlled_burner")
        end
    end

    if self.active_combat.bearger then
        -- 熊獾协议：命中后追加一次范围伤害。
        self:DoBeargerPulse(target, data.weapon)
    end
end

function KeiProtocolSlots:OnSave()
    -- 协议 CD 本身由背包保存，这里只需要保存已解锁槽位数。
    return {
        unlocked_slots = self.unlocked_slots,
    }
end

function KeiProtocolSlots:OnLoad(data)
    if data ~= nil and data.unlocked_slots ~= nil then
        self.unlocked_slots = math.clamp(data.unlocked_slots, 1, TUNING.KEI_PROTOCOL_SLOT_MAX)
    end
    -- 等角色背包恢复完成后再刷新，否则读不到存档里的 CD。
    self.inst:DoTaskInTime(0, function()
        self:Refresh()
    end)
end

return KeiProtocolSlots
