if not TheNet:IsDedicated() then
    local Image = require("widgets/image")
    local ANALYSIS_BACKGROUND_ATLAS = "images/inventoryimages/analysis_cd_slot.xml"
    local ANALYSIS_BACKGROUND_IMAGE = "analysis_cd_slot.tex"

    AddClassPostConstruct("widgets/itemtile", function(self)
        if TUNING.KEI_ANALYSIS_USE_EQUIPMENT_VISUAL ~= true
            or self.item == nil
            or not self.item:HasTag("kei_analysis_protocol")
        then
            return
        end

        self.kei_analysis_background = self:AddChild(Image(
            ANALYSIS_BACKGROUND_ATLAS,
            ANALYSIS_BACKGROUND_IMAGE
        ))
        self.kei_analysis_background:SetClickable(false)
        self.kei_analysis_background:MoveToBack()
    end)
end
