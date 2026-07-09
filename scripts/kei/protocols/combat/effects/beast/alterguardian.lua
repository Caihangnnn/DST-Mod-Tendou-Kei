-- 天体英雄高级协议：电量为 0 时解析协议不失效（由 CanRun 处理），
-- 每周期回复电量（由 DrainProtocols 处理）。

local AlterguardianEffect = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function AlterguardianEffect.Enable(slots, inst)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function AlterguardianEffect.Disable(slots, inst)
end

return AlterguardianEffect
