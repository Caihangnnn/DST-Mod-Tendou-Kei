-- 天体英雄高级协议：电量为 0 时解析协议不失效（由 CanRun 处理），
-- 每周期回复电量（由 DrainProtocols 处理）。

local AlterguardianEffect = {}

function AlterguardianEffect.Enable(slots, inst)
end

function AlterguardianEffect.Disable(slots, inst)
end

return AlterguardianEffect