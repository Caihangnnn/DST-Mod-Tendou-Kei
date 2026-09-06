local ClientSettings = {}

local SAVE_KEY = "tendou_kei_client_settings_v1"
local DEFAULT_MINI_ALICE_ARROW_MODE = 1
local DEFAULT_MINI_ALICE_DISPLAY_MODE = 1
local DEFAULT_MINI_ALICE_FUSION_PAGES = 2
local DEFAULTS = {
    bindings = {
        flame = KEY_Z,
        rotor = KEY_R,
        task_book = KEY_X,
    },
    right_click_priority = { "guard", "leap", "dash" },
    mini_alice_arrow_mode = DEFAULT_MINI_ALICE_ARROW_MODE,
    mini_alice_display_mode = DEFAULT_MINI_ALICE_DISPLAY_MODE,
    mini_alice_fusion_pages = DEFAULT_MINI_ALICE_FUSION_PAGES,
}

local KEY_NAMES = {
    [KEY_ESCAPE] = "Esc",
    [KEY_SPACE] = "空格",
    [KEY_TAB] = "Tab",
    [KEY_ENTER] = "Enter",
    [KEY_BACKSPACE] = "Backspace",
    [KEY_MINUS] = "-",
    [KEY_EQUALS] = "=",
    [KEY_LEFTBRACKET] = "[",
    [KEY_RIGHTBRACKET] = "]",
    [KEY_BACKSLASH] = "\\",
    [KEY_SEMICOLON] = ";",
    [KEY_PERIOD] = ".",
    [KEY_SLASH] = "/",
    [KEY_TILDE] = "`",
    [KEY_HOME] = "Home",
    [KEY_END] = "End",
    [KEY_INSERT] = "Insert",
    [KEY_DELETE] = "Delete",
    [KEY_PAGEUP] = "PageUp",
    [KEY_PAGEDOWN] = "PageDown",
    [KEY_UP] = "Up",
    [KEY_DOWN] = "Down",
    [KEY_LEFT] = "Left",
    [KEY_RIGHT] = "Right",
}

for code = KEY_A, KEY_Z do
    KEY_NAMES[code] = string.upper(string.char(code))
end
for code = KEY_0, KEY_9 do
    KEY_NAMES[code] = string.char(code)
end
for index = 1, 12 do
    KEY_NAMES[KEY_F1 + index - 1] = "F" .. tostring(index)
end

local function CopyDefaults()
    return {
        bindings = {
            flame = DEFAULTS.bindings.flame,
            rotor = DEFAULTS.bindings.rotor,
            task_book = DEFAULTS.bindings.task_book,
        },
        right_click_priority = { "guard", "leap", "dash" },
        mini_alice_arrow_mode = DEFAULTS.mini_alice_arrow_mode,
        mini_alice_display_mode = DEFAULTS.mini_alice_display_mode,
        mini_alice_fusion_pages = DEFAULTS.mini_alice_fusion_pages,
    }
end

local function IsValidPriority(value)
    return value == "guard" or value == "leap" or value == "dash"
end

local function IsValidKey(value)
    return type(value) == "number" and KEY_NAMES[value] ~= nil
end

local function IsValidMiniAliceArrowMode(value)
    value = tonumber(value)
    return value ~= nil and value >= 1 and value <= 4 and value == math.floor(value)
end

local function IsValidMiniAliceDisplayMode(value)
    value = tonumber(value)
    return value ~= nil and value >= 1 and value <= 3 and value == math.floor(value)
end

local function IsValidMiniAliceFusionPages(value)
    value = tonumber(value)
    return value == 2 or value == 3
end

ClientSettings.data = CopyDefaults()
ClientSettings.handlers = {}
ClientSettings.listeners = {}
ClientSettings.next_listener_id = 0
ClientSettings.capture_action = nil

function ClientSettings:GetKeyName(key)
    return KEY_NAMES[key] or "未设置"
end

function ClientSettings:GetBinding(action)
    return self.data.bindings[action] or DEFAULTS.bindings[action]
end

function ClientSettings:GetRightClickPriority()
    return self.data.right_click_priority
end

function ClientSettings:GetMiniAliceArrowMode()
    return IsValidMiniAliceArrowMode(self.data.mini_alice_arrow_mode)
        and self.data.mini_alice_arrow_mode
        or DEFAULTS.mini_alice_arrow_mode
end

function ClientSettings:GetMiniAliceDisplayMode()
    return IsValidMiniAliceDisplayMode(self.data.mini_alice_display_mode)
        and self.data.mini_alice_display_mode
        or DEFAULTS.mini_alice_display_mode
end

function ClientSettings:GetMiniAliceFusionPages()
    return IsValidMiniAliceFusionPages(self.data.mini_alice_fusion_pages)
        and self.data.mini_alice_fusion_pages
        or DEFAULTS.mini_alice_fusion_pages
end

function ClientSettings:NotifyChanged()
    for _, fn in pairs(self.listeners) do
        fn(self.data)
    end
end

function ClientSettings:Save()
    if TheSim ~= nil and TheSim.SetPersistentString ~= nil and json ~= nil then
        TheSim:SetPersistentString(SAVE_KEY, json.encode(self.data), false)
    end
end

function ClientSettings:SetBinding(action, key)
    if DEFAULTS.bindings[action] == nil or not IsValidKey(key) then
        return false
    end

    local old_key = self:GetBinding(action)
    for other, other_key in pairs(self.data.bindings) do
        if other ~= action and other_key == key then
            self.data.bindings[other] = old_key
        end
    end
    self.data.bindings[action] = key
    self:Save()
    self:NotifyChanged()
    return true
end

function ClientSettings:SetPrioritySlot(index, value)
    if index < 1 or index > 3 or not IsValidPriority(value) then
        return false
    end

    local priorities = self.data.right_click_priority
    local old_index = nil
    for slot, current in ipairs(priorities) do
        if current == value then
            old_index = slot
            break
        end
    end
    if old_index ~= nil then
        priorities[old_index], priorities[index] = priorities[index], priorities[old_index]
        self:Save()
        self:NotifyChanged()
    end
    return true
end

function ClientSettings:SetMiniAliceArrowMode(mode)
    mode = tonumber(mode)
    if not IsValidMiniAliceArrowMode(mode) then
        return false
    end

    mode = math.floor(mode)
    if self:GetMiniAliceArrowMode() == mode then
        return true
    end
    self.data.mini_alice_arrow_mode = mode
    self:Save()
    self:NotifyChanged()
    return true
end

function ClientSettings:CycleMiniAliceArrowMode()
    local mode = self:GetMiniAliceArrowMode() % 4 + 1
    self:SetMiniAliceArrowMode(mode)
    return mode
end

function ClientSettings:SetMiniAliceDisplayMode(mode)
    mode = tonumber(mode)
    if not IsValidMiniAliceDisplayMode(mode) then
        return false
    end

    mode = math.floor(mode)
    if self:GetMiniAliceDisplayMode() == mode then
        return true
    end
    self.data.mini_alice_display_mode = mode
    self:Save()
    self:NotifyChanged()
    return true
end

function ClientSettings:CycleMiniAliceDisplayMode()
    local mode = self:GetMiniAliceDisplayMode() % 3 + 1
    self:SetMiniAliceDisplayMode(mode)
    return mode
end

function ClientSettings:SetMiniAliceFusionPages(pages)
    pages = tonumber(pages)
    if not IsValidMiniAliceFusionPages(pages) then
        return false
    end

    pages = math.floor(pages)
    if self:GetMiniAliceFusionPages() == pages then
        return true
    end
    self.data.mini_alice_fusion_pages = pages
    self:Save()
    self:NotifyChanged()
    return true
end

function ClientSettings:CycleMiniAliceFusionPages()
    local pages = self:GetMiniAliceFusionPages() == 2 and 3 or 2
    self:SetMiniAliceFusionPages(pages)
    return pages
end

function ClientSettings:BeginCapture(action, callback)
    if DEFAULTS.bindings[action] == nil then
        return false
    end
    self.capture_action = action
    self.capture_callback = callback
    return true
end

function ClientSettings:RegisterActionHandler(action, on_down, on_up)
    self.handlers[action] = { down = on_down, up = on_up }
end

function ClientSettings:Subscribe(fn)
    self.next_listener_id = self.next_listener_id + 1
    self.listeners[self.next_listener_id] = fn
    return self.next_listener_id
end

function ClientSettings:Unsubscribe(id)
    self.listeners[id] = nil
end

local function HandleKey(key, is_down)
    if ClientSettings.capture_action ~= nil and is_down then
        local action = ClientSettings.capture_action
        local callback = ClientSettings.capture_callback
        ClientSettings.capture_action = nil
        ClientSettings.capture_callback = nil
        ClientSettings:SetBinding(action, key)
        if callback ~= nil then
            callback(key)
        end
        return
    end

    for action, handler in pairs(ClientSettings.handlers) do
        if ClientSettings:GetBinding(action) == key then
            local fn = is_down and handler.down or handler.up
            if fn ~= nil then
                fn()
            end
        end
    end
end

local function Load()
    if TheSim == nil or TheSim.GetPersistentString == nil or json == nil then
        return
    end
    TheSim:GetPersistentString(SAVE_KEY, function(success, value)
        if not success or value == nil or value == "" then
            return
        end
        local ok, saved = pcall(json.decode, value)
        if not ok or type(saved) ~= "table" then
            return
        end

        local data = CopyDefaults()
        for action in pairs(data.bindings) do
            if saved.bindings ~= nil and IsValidKey(saved.bindings[action]) then
                data.bindings[action] = saved.bindings[action]
            end
        end
        local seen = {}
        for index = 1, 3 do
            local value = saved.right_click_priority ~= nil and saved.right_click_priority[index] or nil
            if IsValidPriority(value) and not seen[value] then
                data.right_click_priority[index] = value
                seen[value] = true
            end
        end
        for index = 1, 3 do
            if seen[data.right_click_priority[index]] then
                for _, fallback in ipairs(DEFAULTS.right_click_priority) do
                    if not seen[fallback] then
                        data.right_click_priority[index] = fallback
                        seen[fallback] = true
                        break
                    end
                end
            else
                seen[data.right_click_priority[index]] = true
            end
        end
        if IsValidMiniAliceArrowMode(saved.mini_alice_arrow_mode) then
            data.mini_alice_arrow_mode = math.floor(saved.mini_alice_arrow_mode)
        end
        if IsValidMiniAliceDisplayMode(saved.mini_alice_display_mode) then
            data.mini_alice_display_mode = math.floor(saved.mini_alice_display_mode)
        end
        if IsValidMiniAliceFusionPages(saved.mini_alice_fusion_pages) then
            data.mini_alice_fusion_pages = math.floor(saved.mini_alice_fusion_pages)
        end
        ClientSettings.data = data
        ClientSettings:NotifyChanged()
    end)
end

if TheNet ~= nil and not TheNet:IsDedicated() and TheInput ~= nil then
    for key in pairs(KEY_NAMES) do
        TheInput:AddKeyDownHandler(key, function()
            HandleKey(key, true)
        end)
        TheInput:AddKeyUpHandler(key, function()
            HandleKey(key, false)
        end)
    end
    Load()
end

return ClientSettings
