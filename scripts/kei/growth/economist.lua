-- 经济学家：每日自然经验结算时，额外获得当前经验的百分之一。

local function GetExperienceTotal(inst)
    if inst == nil then
        return 0
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience ~= nil then
        return tonumber(experience.total) or 0
    end

    -- 客户端只用于状态预测，实际经验结算始终在服务器执行。
    if inst._kei_experience_total ~= nil then
        return tonumber(inst._kei_experience_total:value()) or 0
    end

    return 0
end

local function IsActive(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst:HasTag("kei")
        and not inst:HasTag("playerghost")
        and GetExperienceTotal(inst) >= (TUNING.KEI_ECONOMIST_EXPERIENCE_THRESHOLD or 15000)
end

local function AddEconomistToExperience(component)
    if component._kei_economist_cycle_wrapped then
        return
    end

    local old_on_new_cycle = component.OnNewCycle
    if old_on_new_cycle == nil then
        return
    end

    component._kei_economist_cycle_wrapped = true
    component.OnNewCycle = function(self, cycles, ...)
        local old_cycle = self.current_cycle
        local result = old_on_new_cycle(self, cycles, ...)

        -- OnNewCycle 会在重复收到同一周期时直接返回，因此只在周期确实
        -- 变化后追加一次经济学家收益。
        if self.current_cycle ~= old_cycle
            and IsActive(self.inst)
            and self.current > 0
        then
            self:DoDelta(GetExperienceTotal(self.inst) * 0.01)
        end

        return result
    end
end

AddComponentPostInit("kei_experience", AddEconomistToExperience)
