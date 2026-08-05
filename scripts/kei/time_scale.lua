-- Per-entity time scaling used by effects that slow a creature's actions.
-- This deliberately stays local to the affected entity. The global simulation
-- time must not be changed because that would also slow every other creature.

local KeiTimeScale = {}

local MIN_SCALE = 0.01

local function GetSources(inst)
    if inst == nil then
        return nil
    end
    return inst._kei_time_scale_sources
end

local function NormalizeScale(scale)
    scale = tonumber(scale)
    if scale == nil then
        return 1
    end
    return math.max(MIN_SCALE, scale)
end

function KeiTimeScale.GetMultiplier(inst)
    local sources = GetSources(inst)
    if sources == nil then
        return 1
    end

    local multiplier = 1
    local has_source = false
    for _, source_multiplier in pairs(sources) do
        has_source = true
        -- Multiple effects should not make the same time-slow stack
        -- exponentially. The strongest active slow is authoritative.
        multiplier = math.min(multiplier, source_multiplier)
    end

    return has_source and multiplier or 1
end

function KeiTimeScale.RefreshAnimation(inst)
    if inst ~= nil and inst.AnimState ~= nil then
        inst.AnimState:SetDeltaTimeMultiplier(KeiTimeScale.GetMultiplier(inst))
    end
end

function KeiTimeScale.Add(inst, source, multiplier)
    if inst == nil or source == nil then
        return
    end

    inst._kei_time_scale_sources = inst._kei_time_scale_sources or {}
    inst._kei_time_scale_sources[source] = NormalizeScale(multiplier)
    KeiTimeScale.RefreshAnimation(inst)
end

function KeiTimeScale.Remove(inst, source)
    if inst == nil then
        return
    end

    local sources = inst._kei_time_scale_sources
    if sources ~= nil then
        sources[source] = nil
        if next(sources) == nil then
            inst._kei_time_scale_sources = nil
        end
    end
    KeiTimeScale.RefreshAnimation(inst)
end

function KeiTimeScale.InstallStateGraphHook()
    if StateGraphInstance == nil
        or StateGraphInstance.UpdateState == nil
        or StateGraphInstance._kei_time_scale_hooked
    then
        return
    end

    local old_update_state = StateGraphInstance.UpdateState
    StateGraphInstance.UpdateState = function(self, dt)
        local inst = self ~= nil and self.inst or nil
        if inst ~= nil then
            dt = dt * KeiTimeScale.GetMultiplier(inst)
        end
        return old_update_state(self, dt)
    end
    StateGraphInstance._kei_time_scale_hooked = true
end

function KeiTimeScale.InstallCombatHooks(self)
    if self._kei_time_scale_hooks_installed then
        return
    end
    self._kei_time_scale_hooks_installed = true

    local old_in_cooldown = self.InCooldown
    local old_get_cooldown = self.GetCooldown
    local old_override_cooldown = self.OverrideCooldown

    function self:InCooldown(...)
        local last_start = self.laststartattacktime
        local scale = KeiTimeScale.GetMultiplier(self.inst)
        if last_start == nil or scale >= 0.999999 then
            return old_in_cooldown(self, ...)
        end
        return last_start + self.min_attack_period / scale > GetTime()
    end

    function self:GetCooldown(...)
        local last_start = self.laststartattacktime
        local scale = KeiTimeScale.GetMultiplier(self.inst)
        if last_start == nil or scale >= 0.999999 then
            return old_get_cooldown(self, ...)
        end
        return math.max(0, self.min_attack_period / scale - GetTime() + last_start)
    end

    function self:OverrideCooldown(cd, ...)
        local scale = KeiTimeScale.GetMultiplier(self.inst)
        if scale >= 0.999999 then
            return old_override_cooldown(self, cd, ...)
        end
        self.laststartattacktime = GetTime() - self.min_attack_period / scale + cd
    end
end

return KeiTimeScale
