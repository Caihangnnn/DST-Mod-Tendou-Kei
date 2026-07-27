-- 心灵手巧：将使用 Wilson 长动作状态的交互替换为原版短动作。

local Craftsmanship = {}

local function GetExperienceTotal(inst)
    if inst == nil then
        return 0
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience ~= nil then
        return tonumber(experience.total) or 0
    end

    -- 客户端没有主机组件，使用角色同步的累计经验值进行状态图预测。
    if inst._kei_experience_total ~= nil then
        return tonumber(inst._kei_experience_total:value()) or 0
    end

    return 0
end

local function IsActive(inst)
    return inst ~= nil
        and inst:HasTag("kei")
        and GetExperienceTotal(inst) >= (TUNING.KEI_CRAFTSMANSHIP_EXPERIENCE_THRESHOLD or 2000)
end

local function AddCraftsmanshipToStategraph(sg)
    local actionhandlers = sg.actionhandlers
    if actionhandlers == nil then
        return
    end

    for _, handler in pairs(actionhandlers) do
        if handler ~= nil
            and handler.deststate ~= nil
            and not handler._kei_craftsmanship_wrapped
        then
            local old_deststate = handler.deststate
            handler._kei_craftsmanship_wrapped = true
            handler.deststate = function(inst, action)
                local state = old_deststate(inst, action)
                if IsActive(inst) and state == "dolongaction" then
                    return "doshortaction"
                end
                return state
            end
        end
    end
end

AddStategraphPostInit("wilson", AddCraftsmanshipToStategraph)
AddStategraphPostInit("wilson_client", AddCraftsmanshipToStategraph)
