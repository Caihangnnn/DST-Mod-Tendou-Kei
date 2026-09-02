if not TheNet:IsDedicated() then
    local Image = require("widgets/image")
    local ROTOR_POWER_BACKGROUND_ATLAS = "images/inventoryimages/analysis_cd_slot.xml"
    local ROTOR_POWER_BACKGROUND_IMAGE = "analysis_cd_slot.tex"

    local function ClampPercent(percent)
        return math.max(0, math.min(1, tonumber(percent) or 0))
    end

    local function Lerp(first, second, amount)
        return first + (second - first) * amount
    end

    local function GetRotorPowerColour(percent)
        percent = ClampPercent(percent)

        -- Match the familiar battery readout: red at empty, yellow at half,
        -- and green at full. Keeping this on the background image avoids all
        -- interaction with the vanilla spoilage meter.
        if percent < 0.5 then
            local amount = percent / 0.5
            return Lerp(0.95, 1, amount), Lerp(0.18, 0.82, amount), Lerp(0.12, 0.12, amount)
        end

        local amount = (percent - 0.5) / 0.5
        return Lerp(1, 0.22, amount), Lerp(0.82, 0.88, amount), Lerp(0.12, 0.25, amount)
    end

    local function SetRotorPowerColour(tile, percent)
        if tile.kei_rotor_power_background == nil then
            return
        end

        local red, green, blue = GetRotorPowerColour(percent)
        tile.kei_rotor_power_background:SetTint(red, green, blue, 1)
    end

    AddClassPostConstruct("widgets/itemtile", function(self)
        if self.item == nil or not self.item:HasTag("kei_rotor_survey_controller") then
            return
        end

        self.kei_rotor_power_background = self:AddChild(Image(
            ROTOR_POWER_BACKGROUND_ATLAS,
            ROTOR_POWER_BACKGROUND_IMAGE
        ))
        self.kei_rotor_power_background:SetClickable(false)
        self.kei_rotor_power_background:MoveToBack()
        self.kei_rotor_power_percent = 1

        local old_start_drag = self.StartDrag
        self.StartDrag = function(tile, ...)
            local result = old_start_drag(tile, ...)
            if tile.kei_rotor_power_background ~= nil then
                tile.kei_rotor_power_background:Hide()
            end
            return result
        end

        local function UpdateRotorPower(_, data)
            local percent = data ~= nil and data.percent or nil
            if percent == nil
                and self.item.components ~= nil
                and self.item.components.perishable ~= nil
            then
                percent = self.item.components.perishable:GetPercent()
            end
            if percent ~= nil then
                self.kei_rotor_power_percent = ClampPercent(percent)
                SetRotorPowerColour(self, self.kei_rotor_power_percent)
            end
        end

        self.inst:ListenForEvent("perishchange", UpdateRotorPower, self.item)
        self.inst:ListenForEvent("forceperishchange", UpdateRotorPower, self.item)

        if self.item.components ~= nil and self.item.components.perishable ~= nil then
            UpdateRotorPower(nil, {
                percent = self.item.components.perishable:GetPercent(),
            })
        else
            -- 客户端刚创建物品时可能还未收到电量数值，先显示满电颜色。
            SetRotorPowerColour(self, self.kei_rotor_power_percent)
        end
    end)
end
