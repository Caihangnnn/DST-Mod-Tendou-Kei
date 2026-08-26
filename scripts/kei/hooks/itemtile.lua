if not TheNet:IsDedicated() then
    local Image = require("widgets/image")
    local ANALYSIS_BACKGROUND_ATLAS = "images/inventoryimages/analysis_cd_slot.xml"
    local ANALYSIS_BACKGROUND_IMAGE = "analysis_cd_slot.tex"

    local function SetRotorPowerColour(tile, percent)
        if tile.spoilage == nil then
            return
        end

        local anim = tile.spoilage:GetAnimState()
        percent = math.max(0, math.min(1, tonumber(percent) or 0))
        -- The controller reuses the food spoilage meter, so remove the
        -- vanilla green/yellow symbol overrides before applying its power
        -- colours.
        anim:ClearAllOverrideSymbols()
        if percent > 0.5 then
            -- 原版食物进度条默认是绿色，这里叠加浅蓝色作为高电量状态。
            anim:SetMultColour(0.55, 0.85, 1, 1)
            anim:SetAddColour(0.05, 0.08, 0.2, 0)
        elseif percent > 0.2 then
            anim:SetMultColour(1, 0.85, 0.2, 1)
            anim:SetAddColour(0.2, 0.1, 0, 0)
        else
            anim:SetMultColour(1, 0.25, 0.25, 1)
            anim:SetAddColour(0.25, 0, 0, 0)
        end
    end

    AddClassPostConstruct("widgets/itemtile", function(self)
        if self.item == nil then
            return
        end

        if TUNING.KEI_ANALYSIS_USE_EQUIPMENT_VISUAL == true
            and self.item:HasTag("kei_analysis_protocol")
        then
            self.kei_analysis_background = self:AddChild(Image(
                ANALYSIS_BACKGROUND_ATLAS,
                ANALYSIS_BACKGROUND_IMAGE
            ))
            self.kei_analysis_background:SetClickable(false)
            self.kei_analysis_background:MoveToBack()
        end

        if not self.item:HasTag("kei_rotor_survey_controller") then
            return
        end

        local function UpdateRotorPower(_, data)
            if data ~= nil and data.percent ~= nil then
                SetRotorPowerColour(self, data.percent)
            elseif self.item.components ~= nil and self.item.components.perishable ~= nil then
                SetRotorPowerColour(self, self.item.components.perishable:GetPercent())
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
            SetRotorPowerColour(self, 1)
        end

        local old_set_percent = self.SetPercent
        self.SetPercent = function(tile, percent, ...)
            local result = old_set_percent(tile, percent, ...)
            SetRotorPowerColour(tile, percent)
            return result
        end

        local old_set_perish_percent = self.SetPerishPercent
        self.SetPerishPercent = function(tile, percent, ...)
            local result = old_set_perish_percent(tile, percent, ...)
            SetRotorPowerColour(tile, percent)
            return result
        end
    end)
end
