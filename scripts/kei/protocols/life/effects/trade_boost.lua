-- 生活协议-交易增强：强化猪王/蚁狮交易，并让特定鱼类交易视为大鱼。

local TradeBoost = {}
local PROTOCOL = "trade_boost"
local MULTIPLIER = 2
local SHARKBOI_BIG_FISH_WEIGHT = 150
local PERSISTENT_BIG_FISH_SECONDS = 10

local Trader = require("components/trader")

local FISH_TRADE_TARGETS = {
    mermking = true,
    hermitcrab = true,
    sharkboi = true,
}

local function HasTradeBoost(giver)
    return giver ~= nil
        and giver.components ~= nil
        and giver.components.kei_protocolslots ~= nil
        and giver.components.kei_protocolslots:HasLifeProtocol(PROTOCOL)
end

local function GetTradeValueKey(target)
    if target == nil then
        return nil
    end
    if target.prefab == "pigking" then
        return "goldvalue"
    elseif target.prefab == "antlion" then
        return "rocktribute"
    end
end

local function GetFishTradeTarget(target)
    if target ~= nil and FISH_TRADE_TARGETS[target.prefab] then
        return target.prefab
    end
end

local function IsBoostableFish(item)
    return item ~= nil
        and item.HasTag ~= nil
        and item:HasTag("oceanfish")
        and item.components ~= nil
        and item.components.weighable ~= nil
end

local function GetBigFishPercentThreshold(target)
    if target ~= nil
        and target.prefab == "hermitcrab"
        and TUNING ~= nil
        and TUNING.HERMITCRAB ~= nil
        and TUNING.HERMITCRAB.HEAVY_FISH_THRESHHOLD ~= nil then
        return TUNING.HERMITCRAB.HEAVY_FISH_THRESHHOLD
    end
    return (TUNING ~= nil and TUNING.WEIGHABLE_HEAVY_WEIGHT_PERCENT) or 1
end

local function BigFishGetWeight(self)
    local old_get_weight = self._kei_trade_boost_old_get_weight
    local value = old_get_weight ~= nil and old_get_weight(self) or self.weight
    local min_weight = self._kei_trade_boost_min_weight
    if min_weight ~= nil then
        return math.max(value or 0, min_weight)
    end
    return value
end

local function BigFishGetWeightPercent(self)
    local old_get_weight_percent = self._kei_trade_boost_old_get_weight_percent
    local value = old_get_weight_percent ~= nil and old_get_weight_percent(self) or self.weight_percent
    return math.max(value or 0, self._kei_trade_boost_min_percent or 1)
end

local function RestoreBigFishOverride(item)
    local weighable = item ~= nil and item.components ~= nil and item.components.weighable or nil
    if weighable == nil or not weighable._kei_trade_boost_bigfish_active then
        return
    end

    if item._kei_trade_boost_bigfish_restore_task ~= nil then
        item._kei_trade_boost_bigfish_restore_task:Cancel()
        item._kei_trade_boost_bigfish_restore_task = nil
    end

    weighable.GetWeight = weighable._kei_trade_boost_old_get_weight
    weighable.GetWeightPercent = weighable._kei_trade_boost_old_get_weight_percent
    weighable._kei_trade_boost_old_get_weight = nil
    weighable._kei_trade_boost_old_get_weight_percent = nil
    weighable._kei_trade_boost_min_weight = nil
    weighable._kei_trade_boost_min_percent = nil
    weighable._kei_trade_boost_bigfish_active = nil
end

-- 临时把鱼的称重接口抬到大鱼区间，避免改动鱼本体保存的重量数据。
local function InstallBigFishOverride(item, target, persistent)
    if not IsBoostableFish(item) then
        return
    end

    local weighable = item.components.weighable
    if not weighable._kei_trade_boost_bigfish_active then
        weighable._kei_trade_boost_old_get_weight = weighable.GetWeight
        weighable._kei_trade_boost_old_get_weight_percent = weighable.GetWeightPercent
    end

    weighable._kei_trade_boost_bigfish_active = true
    weighable._kei_trade_boost_min_weight = target ~= nil and target.prefab == "sharkboi" and SHARKBOI_BIG_FISH_WEIGHT or nil
    weighable._kei_trade_boost_min_percent = GetBigFishPercentThreshold(target)
    weighable.GetWeight = BigFishGetWeight
    weighable.GetWeightPercent = BigFishGetWeightPercent

    if persistent then
        if item._kei_trade_boost_bigfish_restore_task ~= nil then
            item._kei_trade_boost_bigfish_restore_task:Cancel()
        end
        item._kei_trade_boost_bigfish_restore_task = item:DoTaskInTime(PERSISTENT_BIG_FISH_SECONDS, function(inst)
            inst._kei_trade_boost_bigfish_restore_task = nil
            RestoreBigFishOverride(inst)
        end)
        return
    end

    return function()
        RestoreBigFishOverride(item)
    end
end

local function RunOnAcceptWithBoost(onaccept, target, giver, item, count, value_key)
    if onaccept == nil then
        return
    end

    local tradable = item ~= nil and item.components ~= nil and item.components.tradable or nil
    local old_value = tradable ~= nil and tradable[value_key] or nil
    if old_value == nil or old_value <= 0 then
        return onaccept(target, giver, item, count)
    end

    tradable[value_key] = old_value * MULTIPLIER
    local ok, err = pcall(onaccept, target, giver, item, count)
    tradable[value_key] = old_value
    if not ok then
        error(err)
    end
end

local function RunOnAcceptWithBigFish(onaccept, target, giver, item, count, persistent)
    if onaccept == nil then
        return
    end

    local installed = IsBoostableFish(item)
    local restore = installed and InstallBigFishOverride(item, target, persistent) or nil
    local ok, result = pcall(onaccept, target, giver, item, count)
    if restore ~= nil then
        restore()
    elseif not ok and installed and persistent then
        RestoreBigFishOverride(item)
    end
    if not ok then
        error(result)
    end
    return result
end

local function PatchTraderAcceptGift()
    if Trader._kei_trade_boost_patched then
        return
    end
    Trader._kei_trade_boost_patched = true

    local old_accept_gift = Trader.AcceptGift
    function Trader:AcceptGift(giver, item, count)
        local value_key = GetTradeValueKey(self.inst)
        local fish_target = GetFishTradeTarget(self.inst)
        if not HasTradeBoost(giver) or (value_key == nil and fish_target == nil) then
            return old_accept_gift(self, giver, item, count)
        end

        local old_onaccept = self.onaccept
        self.onaccept = function(target, trade_giver, accepted_item, accepted_count)
            if value_key ~= nil then
                return RunOnAcceptWithBoost(old_onaccept, target, trade_giver, accepted_item, accepted_count, value_key)
            end
            return RunOnAcceptWithBigFish(old_onaccept, target, trade_giver, accepted_item, accepted_count, fish_target == "mermking")
        end

        local restore_fish = nil
        if fish_target == "sharkboi" and IsBoostableFish(item) then
            -- 大霜鲨会在 accept test 阶段检查重量，因此需要提前覆盖判定接口。
            restore_fish = InstallBigFishOverride(item, self.inst, false)
        end

        local ok, result = pcall(old_accept_gift, self, giver, item, count)
        if restore_fish ~= nil then
            restore_fish()
        end
        self.onaccept = old_onaccept
        if not ok then
            error(result)
        end
        return result
    end
end

PatchTraderAcceptGift()

function TradeBoost.Enable(slots, inst)
    -- 效果在 trader 组件交易入口统一判定，这里只保留生活协议标准接口。
end

function TradeBoost.Disable(slots, inst)
end

return TradeBoost