-- 前端临时显示代理：Kei 的真实资源还未制作时，选人界面统一借用 Wendy。
-- 注意这里只改显示，不改变真正被选择和进入世界的角色 prefab 名。
local KEI_PREFAB = "kei"
local KEI_DISPLAY_PREFAB = "wendy"
local LOCKED_GREY = { 0.5, 0.5, 0.5, 1 }

local function ShouldPatchFrontend()
    return TheNet == nil or not TheNet:IsDedicated()
end

if ShouldPatchFrontend() then
    require("characterutil")

    local OldSetOvalPortraitTexture = GLOBAL.SetOvalPortraitTexture
    local OldSetSkinnedOvalPortraitTexture = GLOBAL.SetSkinnedOvalPortraitTexture

    if OldSetOvalPortraitTexture ~= nil then
        GLOBAL.SetOvalPortraitTexture = function(image_widget, character)
            if character == KEI_PREFAB then
                return OldSetOvalPortraitTexture(image_widget, KEI_DISPLAY_PREFAB)
            end
            return OldSetOvalPortraitTexture(image_widget, character)
        end
    end

    if OldSetSkinnedOvalPortraitTexture ~= nil then
        GLOBAL.SetSkinnedOvalPortraitTexture = function(image_widget, character, skin)
            if character == KEI_PREFAB then
                return OldSetOvalPortraitTexture(image_widget, KEI_DISPLAY_PREFAB)
            end
            return OldSetSkinnedOvalPortraitTexture(image_widget, character, skin)
        end
    end

    local function ApplyWendyHead(button)
        local skin_mode = "normal_skin"
        local base_build = KEI_DISPLAY_PREFAB
        local skindata = GetSkinData(KEI_DISPLAY_PREFAB .. "_none")
        if skindata.skins ~= nil then
            base_build = skindata.skins[skin_mode] or base_build
        end

        if button.herocharacter == "random" or not Profile:GetAnimatedHeadsEnabled() then
            button.head_animstate:SetTime(0)
            button.head_animstate:Pause()
        else
            button.head_animstate:SetTime(math.random() * 1.5)
        end

        button.head_anim:SetScale(CHARACTER_BUTTON_SCALE[KEI_DISPLAY_PREFAB] or CHARACTER_BUTTON_SCALE.default)
        button.head_anim:SetPosition(0, CHARACTER_BUTTON_OFFSET[KEI_DISPLAY_PREFAB] or CHARACTER_BUTTON_OFFSET.default, 0)
        SetSkinsOnAnim(button.head_animstate, KEI_DISPLAY_PREFAB, base_build, {}, nil, skin_mode)

        if IsCharacterOwned(KEI_PREFAB) then
            button.image:SetTint(unpack(WHITE))
            button.head_animstate:SetMultColour(unpack(WHITE))
            button.lock_img:Hide()
        else
            button.image:SetTint(unpack(LOCKED_GREY))
            button.head_animstate:SetMultColour(unpack(LOCKED_GREY))
            button.lock_img:Show()
        end
    end

    local CharacterButton = require("widgets/redux/characterbutton")
    if CharacterButton ~= nil and not CharacterButton._kei_wendy_display_patch then
        CharacterButton._kei_wendy_display_patch = true
        local OldSetCharacter = CharacterButton.SetCharacter
        CharacterButton.SetCharacter = function(button, hero)
            button.herocharacter = hero
            if hero == KEI_PREFAB then
                ApplyWendyHead(button)
            else
                OldSetCharacter(button, hero)
            end
        end
    end

    local SkinsPuppet = require("widgets/skinspuppet")
    if SkinsPuppet ~= nil and not SkinsPuppet._kei_wendy_display_patch then
        SkinsPuppet._kei_wendy_display_patch = true
        local OldSetCharacter = SkinsPuppet.SetCharacter
        SkinsPuppet.SetCharacter = function(puppet, character)
            OldSetCharacter(puppet, character == KEI_PREFAB and KEI_DISPLAY_PREFAB or character)
        end

        local OldSetSkins = SkinsPuppet.SetSkins
        SkinsPuppet.SetSkins = function(puppet, prefabname, base_item, clothing_names, skip_change_emote, skinmode, monkey_curse)
            if prefabname == KEI_PREFAB then
                local display_skinmode = GetSkinModes(KEI_DISPLAY_PREFAB)[1]
                OldSetSkins(puppet, KEI_DISPLAY_PREFAB, KEI_DISPLAY_PREFAB .. "_none", {}, skip_change_emote, display_skinmode, monkey_curse)
                puppet.prefabname = KEI_PREFAB
            else
                OldSetSkins(puppet, prefabname, base_item, clothing_names, skip_change_emote, skinmode, monkey_curse)
            end
        end
    end
end
