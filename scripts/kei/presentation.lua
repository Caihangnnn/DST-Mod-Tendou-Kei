-- Kei 的前端头像资源已统一为小写 kei；这里只保留角色按钮的展示微调。
local KEI_PREFAB = "kei"

CHARACTER_BUTTON_OFFSET[KEI_PREFAB] = -45
CHARACTER_BUTTON_SCALE[KEI_PREFAB] = CHARACTER_BUTTON_SCALE.default

local function AddKeiExperienceDisplay(self)
    if self.owner == nil or not self.owner:HasTag("kei") then
        return
    end

    local KeiExperienceBadge = require("widgets/kei_experiencebadge")
    self.kei_experience = self:AddChild(KeiExperienceBadge(self.owner))
    self.kei_experience:SetPosition(self.column1-50, 35, 0)

    local function UpdateExperience()
        if self.kei_experience == nil then
            return
        end
        local current = self.owner._kei_experience_current ~= nil
            and self.owner._kei_experience_current:value()
            or 0
        local max = self.owner._kei_experience_max ~= nil
            and self.owner._kei_experience_max:value()
            or (TUNING.KEI_EXPERIENCE_BASE_MAX or 1000)
        local total = self.owner._kei_experience_total ~= nil
            and self.owner._kei_experience_total:value()
            or current
        self.kei_experience:SetValues(current, max, total)
    end

    self.inst:ListenForEvent("kei_experience_dirty", UpdateExperience, self.owner)
    UpdateExperience()

    local old_SetGhostMode = self.SetGhostMode
    function self:SetGhostMode(ghostmode, ...)
        old_SetGhostMode(self, ghostmode, ...)
        if self.kei_experience ~= nil then
            if ghostmode then
                self.kei_experience:Hide()
            else
                self.kei_experience:Show()
            end
        end
    end

    if self.owner:HasTag("playerghost") then
        self.kei_experience:Hide()
    end
end

AddClassPostConstruct("widgets/statusdisplays", AddKeiExperienceDisplay)
