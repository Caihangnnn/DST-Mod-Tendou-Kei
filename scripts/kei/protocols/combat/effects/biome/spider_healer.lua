-- 护士蜘蛛协议：允许 Kei 接受护士蜘蛛的治疗。

local SpiderHealerEffect = {}

-- 原版护士蜘蛛会治疗 spiderwhisperer；这里只添加治疗识别所需标签。
function SpiderHealerEffect.Enable(slots, inst)
    if inst:HasTag('spiderwhisperer') then
        slots._kei_spider_healer_added_spiderwhisperer = nil
        return
    end

    inst:AddTag('spiderwhisperer')
    slots._kei_spider_healer_added_spiderwhisperer = true
end

-- 只移除本协议添加的标签，避免覆盖其它模组或角色能力来源。
function SpiderHealerEffect.Disable(slots, inst)
    if slots._kei_spider_healer_added_spiderwhisperer then
        inst:RemoveTag('spiderwhisperer')
        slots._kei_spider_healer_added_spiderwhisperer = nil
    end
end

return SpiderHealerEffect