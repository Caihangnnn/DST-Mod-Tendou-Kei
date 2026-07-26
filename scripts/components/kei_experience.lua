-- Kei experience, daily gains, growth states, and save data.

local ProtocolSlotUnlocks = require("kei/protocol_slot_unlocks")

local AMPLIFICATION_DAMAGE_KEY = "kei_experience_amplification"
local AMPLIFICATION_ABSORB_KEY = "kei_experience_amplification"

local DAILY_RULES = {
    gather = { amount = TUNING.KEI_EXPERIENCE_GATHER_AMOUNT, cap = TUNING.KEI_EXPERIENCE_GATHER_DAILY_CAP },
    craft = { amount = TUNING.KEI_EXPERIENCE_CRAFT_AMOUNT, cap = TUNING.KEI_EXPERIENCE_CRAFT_DAILY_CAP },
    work = { amount = TUNING.KEI_EXPERIENCE_WORK_AMOUNT, cap = TUNING.KEI_EXPERIENCE_WORK_DAILY_CAP },
    eat = { amount = TUNING.KEI_EXPERIENCE_EAT_AMOUNT, cap = TUNING.KEI_EXPERIENCE_EAT_DAILY_CAP },
    sleep = { amount = TUNING.KEI_EXPERIENCE_SLEEP_AMOUNT, cap = TUNING.KEI_EXPERIENCE_SLEEP_DAILY_CAP },
    capture = { amount = TUNING.KEI_EXPERIENCE_CAPTURE_AMOUNT, cap = TUNING.KEI_EXPERIENCE_CAPTURE_DAILY_CAP },
    plant = { amount = TUNING.KEI_EXPERIENCE_PLANT_AMOUNT, cap = TUNING.KEI_EXPERIENCE_PLANT_DAILY_CAP },
    blueprint = { amount = TUNING.KEI_EXPERIENCE_BLUEPRINT_AMOUNT, cap = TUNING.KEI_EXPERIENCE_BLUEPRINT_DAILY_CAP },
}

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function GetCurrentCycle()
    return TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.cycles or 0
end

local function CopyNumberTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(key) == "string" and type(value) == "number" then
            copy[key] = value
        end
    end
    return copy
end

local KeiExperience = Class(function(self, inst)
    self.inst = inst
    self.current = 0
    self.max = 0
    self.daily_gains = {}
    self.daily_combat_kills = {}
    self.current_cycle = GetCurrentCycle()
    self.potential_end_time = nil
    self._potential_task = nil
    self._combat_damage_depth = 0
    self._applied_mode = nil

    self:RecalculateMax()
    self:InstallDamageProtection()

    inst:ListenForEvent("picksomething", function()
        self:AddDailyExperience("gather")
    end)
    inst:ListenForEvent("harvestsomething", function()
        self:AddDailyExperience("gather")
    end)
    inst:ListenForEvent("builditem", function()
        self:AddDailyExperience("craft")
    end)
    inst:ListenForEvent("buildstructure", function()
        self:AddDailyExperience("craft")
    end)
    inst:ListenForEvent("finishedwork", function(_, data)
        local action = data ~= nil and data.action or nil
        if action == ACTIONS.CHOP or action == ACTIONS.MINE then
            self:AddDailyExperience("work")
        elseif action == ACTIONS.NET then
            self:AddDailyExperience("capture")
        end
    end)
    inst:ListenForEvent("oneat", function()
        self:AddDailyExperience("eat")
    end)
    inst:ListenForEvent("learnrecipe", function()
        self:AddDailyExperience("blueprint")
    end)
    inst:ListenForEvent("itemplanted", function(_, data)
        if data ~= nil and data.doer == inst then
            self:AddDailyExperience("plant")
        end
    end, TheWorld)

    inst:WatchWorldState("cycles", function(_, cycles)
        self:OnNewCycle(cycles)
    end)
end)

function KeiExperience:GetMaxForUnlockedSlots(unlocked_slots)
    local base_slots = ProtocolSlotUnlocks.GetBaseInitialSlots()
    local extra_slots = math.max(0, (unlocked_slots or base_slots) - base_slots)
    return (TUNING.KEI_EXPERIENCE_BASE_MAX or 1000)
        + extra_slots * (TUNING.KEI_EXPERIENCE_MAX_PER_EXTRA_SLOT or 1000)
end

function KeiExperience:RecalculateMax()
    local slots = self.inst.components ~= nil and self.inst.components.kei_protocolslots or nil
    local unlocked_slots = slots ~= nil and slots.unlocked_slots or ProtocolSlotUnlocks.GetInitialSlots()
    local old_max = self.max
    self.max = self:GetMaxForUnlockedSlots(unlocked_slots)
    self.current = math.clamp(self.current or 0, 0, self.max)
    self:SyncNetValues()
    if old_max ~= self.max then
        self:RefreshGrowthEffects()
    end
end

function KeiExperience:SyncNetValues()
    if self.inst._kei_experience_current ~= nil then
        self.inst._kei_experience_current:set(self.current)
    end
    if self.inst._kei_experience_max ~= nil then
        self.inst._kei_experience_max:set(self.max)
    end
end

function KeiExperience:GetPercent()
    return self.max > 0 and self.current / self.max or 0
end

function KeiExperience:IsFull()
    return self.max > 0 and self.current >= self.max
end

function KeiExperience:DoDelta(amount)
    amount = tonumber(amount) or 0
    local old = self.current
    self.current = math.clamp(old + amount, 0, self.max)
    if self.current ~= old then
        self:SyncNetValues()
        self.inst:PushEvent("kei_experiencedelta", {
            old = old,
            new = self.current,
            max = self.max,
        })
        self:RefreshGrowthEffects()
    end
    return self.current - old
end

function KeiExperience:ConsumeAll()
    if not self:IsFull() then
        return false
    end
    self:DoDelta(-self.current)
    return true
end

function KeiExperience:AddDailyExperience(category, amount, cap)
    local rule = DAILY_RULES[category]
    amount = amount or (rule ~= nil and rule.amount) or 0
    cap = cap or (rule ~= nil and rule.cap) or 0
    if amount <= 0 or cap <= 0 or self:IsFull() then
        return 0
    end

    local gained_today = self.daily_gains[category] or 0
    local allowed = math.min(amount, math.max(0, cap - gained_today))
    if allowed <= 0 then
        return 0
    end

    self.daily_gains[category] = gained_today + allowed
    return self:DoDelta(allowed)
end

function KeiExperience:AddCombatExperience(prefab, max_health)
    if prefab == nil or self:IsFull() then
        return 0
    end

    max_health = tonumber(max_health) or 0
    if max_health <= 0 then
        return 0
    end

    local kills = self.daily_combat_kills[prefab] or 0
    self.daily_combat_kills[prefab] = kills + 1
    local amount = max_health * (TUNING.KEI_EXPERIENCE_COMBAT_HEALTH_RATIO or 0.1) * (0.5 ^ kills)
    return self:DoDelta(amount)
end

function KeiExperience:AddSleepExperience()
    return self:AddDailyExperience("sleep")
end

function KeiExperience:OnNewCycle(cycles)
    cycles = tonumber(cycles) or GetCurrentCycle()
    if cycles == self.current_cycle then
        return
    end

    self.current_cycle = cycles
    self.daily_gains = {}
    self.daily_combat_kills = {}
    self:DoDelta(TUNING.KEI_EXPERIENCE_DAILY_GAIN or 100)
end

function KeiExperience:IsPotentialActive()
    return self.potential_end_time ~= nil and self.potential_end_time > GetTime()
end

function KeiExperience:GetPotentialRemaining()
    return self:IsPotentialActive() and math.max(0, self.potential_end_time - GetTime()) or 0
end

function KeiExperience:StopPotential()
    if self._potential_task ~= nil then
        self._potential_task:Cancel()
        self._potential_task = nil
    end
    self.potential_end_time = nil
    self:RefreshGrowthEffects()
end

function KeiExperience:StartPotential(duration)
    duration = tonumber(duration) or TUNING.KEI_POTENTIAL_DURATION or 240
    if duration <= 0 then
        return false
    end

    if self._potential_task ~= nil then
        self._potential_task:Cancel()
    end
    self.potential_end_time = GetTime() + duration
    self._potential_task = self.inst:DoTaskInTime(duration, function()
        self._potential_task = nil
        self.potential_end_time = nil
        self:RefreshGrowthEffects()
    end)
    self:RefreshGrowthEffects()
    return true
end

function KeiExperience:GetGrowthMode()
    if self:IsPotentialActive() then
        return "potential"
    elseif self:IsFull() then
        return "amplification"
    end
    return nil
end

function KeiExperience:IsNonAttackDamageImmune()
    return self:GetGrowthMode() ~= nil
end

function KeiExperience:RefreshGrowthEffects()
    local mode = self:GetGrowthMode()
    if mode == self._applied_mode then
        return
    end
    self._applied_mode = mode

    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    local health = self.inst.components ~= nil and self.inst.components.health or nil
    if combat ~= nil then
        combat.externaldamagemultipliers:RemoveModifier(self.inst, AMPLIFICATION_DAMAGE_KEY)
    end
    if health ~= nil then
        health.externalabsorbmodifiers:RemoveModifier(self.inst, AMPLIFICATION_ABSORB_KEY)
    end

    if mode == "potential" then
        if combat ~= nil then
            combat.externaldamagemultipliers:SetModifier(
                self.inst,
                TUNING.KEI_POTENTIAL_DAMAGE_MULT or 10,
                AMPLIFICATION_DAMAGE_KEY
            )
        end
        if health ~= nil then
            health.externalabsorbmodifiers:SetModifier(
                self.inst,
                TUNING.KEI_POTENTIAL_ABSORB or 0.99,
                AMPLIFICATION_ABSORB_KEY
            )
        end
    elseif mode == "amplification" then
        if combat ~= nil then
            combat.externaldamagemultipliers:SetModifier(
                self.inst,
                TUNING.KEI_EXPERIENCE_FULL_DAMAGE_MULT or 2,
                AMPLIFICATION_DAMAGE_KEY
            )
        end
        if health ~= nil then
            health.externalabsorbmodifiers:SetModifier(
                self.inst,
                TUNING.KEI_EXPERIENCE_FULL_ABSORB or 0.5,
                AMPLIFICATION_ABSORB_KEY
            )
        end
    end
end

-- Only negative DoDelta calls inside Combat:GetAttacked count as attack damage.
function KeiExperience:InstallDamageProtection()
    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    local health = self.inst.components ~= nil and self.inst.components.health or nil
    if combat == nil or health == nil then
        return
    end

    self._old_combat_getattacked = combat.GetAttacked
    combat.GetAttacked = function(component, ...)
        self._combat_damage_depth = self._combat_damage_depth + 1
        local results = Pack(pcall(self._old_combat_getattacked, component, ...))
        self._combat_damage_depth = math.max(0, self._combat_damage_depth - 1)
        if not results[1] then
            error(results[2])
        end
        return unpack(results, 2, results.n)
    end

    self._old_health_dodelta = health.DoDelta
    health.DoDelta = function(component, amount, ...)
        if amount ~= nil
            and amount < 0
            and self:IsNonAttackDamageImmune()
            and self._combat_damage_depth <= 0
        then
            return 0
        end
        return self._old_health_dodelta(component, amount, ...)
    end
end

function KeiExperience:OnSave()
    return {
        current = self.current,
        current_cycle = self.current_cycle,
        daily_gains = self.daily_gains,
        daily_combat_kills = self.daily_combat_kills,
        potential_remaining = self:GetPotentialRemaining(),
    }
end

function KeiExperience:OnLoad(data)
    data = data or {}
    self.current = math.max(0, tonumber(data.current) or 0)

    local saved_cycle = tonumber(data.current_cycle)
    local current_cycle = GetCurrentCycle()
    if saved_cycle ~= nil and saved_cycle == current_cycle then
        self.daily_gains = CopyNumberTable(data.daily_gains)
        self.daily_combat_kills = CopyNumberTable(data.daily_combat_kills)
    else
        self.daily_gains = {}
        self.daily_combat_kills = {}
    end
    self.current_cycle = current_cycle

    self:RecalculateMax()
    local potential_remaining = tonumber(data.potential_remaining) or 0
    if potential_remaining > 0 then
        self:StartPotential(potential_remaining)
    else
        self:RefreshGrowthEffects()
    end
end

function KeiExperience:OnRemoveFromEntity()
    self:StopPotential()

    local combat = self.inst.components ~= nil and self.inst.components.combat or nil
    local health = self.inst.components ~= nil and self.inst.components.health or nil
    if combat ~= nil then
        combat.externaldamagemultipliers:RemoveModifier(self.inst, AMPLIFICATION_DAMAGE_KEY)
        if self._old_combat_getattacked ~= nil then
            combat.GetAttacked = self._old_combat_getattacked
        end
    end
    if health ~= nil then
        health.externalabsorbmodifiers:RemoveModifier(self.inst, AMPLIFICATION_ABSORB_KEY)
        if self._old_health_dodelta ~= nil then
            health.DoDelta = self._old_health_dodelta
        end
    end
end

return KeiExperience
