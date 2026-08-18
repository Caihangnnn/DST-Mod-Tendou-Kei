local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Spinner = require "widgets/spinner"
local TEMPLATES = require "widgets/redux/templates"
local PlayerAvatarPortrait = require "widgets/redux/playeravatarportrait"
local TaskBook = require "kei/task_book"

local ATLAS = "images/quagmire_recipebook.xml"
local GRID_WIDTH = 390
local GRID_HEIGHT = 390

local function GetSyncedProtocolVisual(owner, slot)
    local visual_var = owner ~= nil and owner._kei_protocol_slot_visuals ~= nil
        and owner._kei_protocol_slot_visuals[slot] or nil
    local value = visual_var ~= nil and visual_var:value() or ""
    local atlas, image = nil, nil
    if type(value) == "string" then
        atlas, image = value:match("^([^\t]+)\t(.+)$")
    end
    if atlas ~= nil then
        if image ~= nil and not image:match("%.tex$") then
            image = image .. ".tex"
        end
    end
    return atlas, image
end

local function GetInsertedProtocols(owner)
    local protocols = {}
    local inventory = owner ~= nil and owner.replica ~= nil and owner.replica.inventory or nil
    local slot_count = owner ~= nil and owner._kei_unlocked_protocol_slots ~= nil
        and owner._kei_unlocked_protocol_slots:value() or 0

    if owner == nil then
        return protocols
    end

    for slot = 1, math.min(slot_count, 7) do
        local atlas, image = GetSyncedProtocolVisual(owner, slot)
        local slot_container = inventory ~= nil and inventory:GetItemInSlot(slot) or nil
        local container = slot_container ~= nil and slot_container.replica ~= nil and slot_container.replica.container or nil
        local protocol = container ~= nil and container:GetItemInSlot(1) or nil
        local inventoryitem = protocol ~= nil and protocol.replica ~= nil and protocol.replica.inventoryitem or nil
        if atlas == nil and protocol ~= nil and protocol:IsValid() and inventoryitem ~= nil then
            atlas = inventoryitem:GetAtlas()
            image = inventoryitem:GetImage()
        end
        if atlas ~= nil and image ~= nil then
            table.insert(protocols, {
                slot = slot,
                atlas = atlas,
                image = image,
            })
        end
    end

    return protocols
end

local function GetProtocolSignature(protocols)
    local signature = {}
    for _, protocol in ipairs(protocols) do
        table.insert(signature, tostring(protocol.slot) .. ":" .. protocol.atlas .. ":" .. protocol.image)
    end
    return table.concat(signature, ",")
end

local function AddDetailPanel(parent)
    local decor = parent:AddChild(Image(ATLAS, "quagmire_recipe_menu_block.tex"))
    decor:ScaleToSize(360, 500)
    local left_corner = parent:AddChild(Image(ATLAS, "quagmire_recipe_corner_decoration.tex"))
    left_corner:ScaleToSize(100, 100)
    left_corner:SetPosition(-120, -190)
    local right_corner = parent:AddChild(Image(ATLAS, "quagmire_recipe_corner_decoration.tex"))
    right_corner:ScaleToSize(-100, 100)
    right_corner:SetPosition(120, -190)
end

local StatusPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookStatusPage")
    self.owner = owner

    -- Keep the task page's content frame identical to the data page, while
    -- reserving its center for future task content instead of protocol CDs.
    self.gridroot = self:AddChild(Widget("task_root"))
    self.gridroot:SetPosition(-180, -35)
    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    local title = self:AddChild(Text(HEADERFONT, 18, "任务", UICOLOURS.BROWN_DARK))
    title:SetHAlign(ANCHOR_RIGHT)
    title:SetPosition(-310, 229)
    local line = self:AddChild(Image(ATLAS, "quagmire_recipe_line_short.tex"))
    line:SetScale(.5, .5)
    line:SetPosition(-310, 216)

    local top_border = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    top_border:SetScale(.75, .75)
    top_border:SetPosition(-3, GRID_HEIGHT / 2 + 1)
    local bottom_border = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    bottom_border:SetScale(.75, -.75)
    bottom_border:SetPosition(-3, -GRID_HEIGHT / 2)
end)

local TaskPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookTaskPage")
    self.owner = owner
    self.protocol_signature = nil

    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    self.protocol_ring = self.details_root:AddChild(Widget("protocol_ring"))
    self.protocol_ring:SetPosition(0, 8)
    self:CreatePlayerPortrait()
    self:RefreshProtocolRing(true)
    self:UpdateWhilePaused(true)

    if owner ~= nil then
        self._protocol_slots_dirty_fn = function()
            self:RefreshProtocolRing()
        end
        self.inst:ListenForEvent("kei_protocol_slots_dirty", self._protocol_slots_dirty_fn, owner)
        self.inst:ListenForEvent("kei_protocol_slot_visuals_dirty", self._protocol_slots_dirty_fn, owner)
    end
    self.refresh_elapsed = .25
    self:StartUpdating()
end)

function TaskPage:CreatePlayerPortrait()
    self.portrait = self.protocol_ring:AddChild(PlayerAvatarPortrait())
    self.portrait:HideVanityItems()
    self.portrait:AlwaysHideRankBadge()
    self.portrait.playername:Hide()
    self.portrait:HideHoverText()
    -- PlayerAvatarPortrait offsets its puppet downward internally. This small
    -- lift aligns the visible character with the protocol ring's center.
    self.portrait:SetPosition(0, 20)
    self.portrait:SetScale(.9)

    local owner = self.owner
    local client_data = owner ~= nil and owner.userid ~= nil and TheNet:GetClientTableForUser(owner.userid) or nil
    local prefab = owner ~= nil and owner.prefab or "kei"
    if client_data ~= nil then
        local base_skin, clothing = GetSkinsDataFromClientTableData(client_data)
        self.portrait:SetSkins(prefab, base_skin, clothing)
    else
        self.portrait:SetSkins(prefab, prefab .. "_none", {})
    end
end

function TaskPage:RefreshProtocolRing(force)
    local protocols = GetInsertedProtocols(self.owner)
    local signature = GetProtocolSignature(protocols)
    if not force and signature == self.protocol_signature then
        return
    end
    self.protocol_signature = signature

    if self.protocol_icons ~= nil then
        for _, icon in ipairs(self.protocol_icons) do
            icon:Kill()
        end
    end
    self.protocol_icons = {}

    local count = #protocols
    local radius = 132
    for index, protocol in ipairs(protocols) do
        local icon = self.protocol_ring:AddChild(Image(protocol.atlas, protocol.image))
        icon:ScaleToSize(54, 54)
        local angle = math.pi / 2 - (index - 1) * (2 * math.pi) / count
        icon:SetPosition(math.cos(angle) * radius, math.sin(angle) * radius)
        table.insert(self.protocol_icons, icon)
    end

    if self.portrait ~= nil then
        self.portrait:MoveToFront()
    end
end

function TaskPage:OnUpdate(dt)
    if self.portrait ~= nil then
        self.portrait:EmoteUpdate(dt)
    end
    self.refresh_elapsed = self.refresh_elapsed + dt
    if self.refresh_elapsed >= .25 then
        self.refresh_elapsed = 0
        self:RefreshProtocolRing()
    end
end

function TaskPage:OnRemoveEntity()
    if self.owner ~= nil and self._protocol_slots_dirty_fn ~= nil then
        self.inst:RemoveEventCallback("kei_protocol_slots_dirty", self._protocol_slots_dirty_fn, self.owner)
        self.inst:RemoveEventCallback("kei_protocol_slot_visuals_dirty", self._protocol_slots_dirty_fn, self.owner)
    end
end

local DataPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookDataPage")
    self.owner = owner
    self.sort_mode = "default"
    self.filter_mode = "all"
    self:CreateLayout()
    self:RefreshEntries()
    if owner ~= nil then
        self.inst:ListenForEvent("kei_taskbook_dirty", function() self:RefreshEntries() end, owner)
    end
end)

function DataPage:CreateLayout()
    self.gridroot = self:AddChild(Widget("grid_root"))
    self.gridroot:SetPosition(-180, -35)
    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    local title = self:AddChild(Text(HEADERFONT, 18, "已记录数据", UICOLOURS.BROWN_DARK))
    title:SetHAlign(ANCHOR_RIGHT)
    title:SetPosition(-310, 229)
    local line = self:AddChild(Image(ATLAS, "quagmire_recipe_line_short.tex"))
    line:SetScale(.5, .5)
    line:SetPosition(-310, 216)
    self.count_text = self:AddChild(Text(HEADERFONT, 18, "0", UICOLOURS.BROWN_DARK))
    self.count_text:SetHAlign(ANCHOR_RIGHT)
    self.count_text:SetPosition(-310, 196)

    self.spinner_root = self.gridroot:AddChild(self:BuildSpinners())
end

function DataPage:UpdateGridDecor()
    if self.grid_border_top ~= nil then self.grid_border_top:Kill() end
    if self.grid_border_bottom ~= nil then self.grid_border_bottom:Kill() end

    local _, grid_height = self.grid:GetScrollRegionSize()
    self.grid_border_top = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    self.grid_border_top:SetScale(.75, .75)
    self.grid_border_top:SetPosition(-3, grid_height / 2 + 1)
    self.grid_border_bottom = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    self.grid_border_bottom:SetScale(.75, -.75)
    self.grid_border_bottom:SetPosition(-3, -grid_height / 2)
    self.spinner_root:SetPosition(0, grid_height / 2 + 5)
end

function DataPage:BuildSpinners()
    local root = Widget("spinner_root")
    local width_label = 150
    local width_spinner = 150
    local height = 25

    local function MakeSpinner(label, options, on_changed)
        local spacing = 5
        local total_width = width_label + width_spinner + spacing
        local group = Widget("labelspinner")
        group.label = group:AddChild(Text(HEADERFONT, 18, label))
        group.label:SetPosition((-total_width / 2) + (width_label / 2), 0)
        group.label:SetRegionSize(width_label, height)
        group.label:SetHAlign(ANCHOR_RIGHT)
        group.label:SetColour(UICOLOURS.BROWN_DARK)

        group.spinner = group:AddChild(Spinner(
            options,
            width_spinner,
            height,
            { font = HEADERFONT, size = 18 },
            nil,
            ATLAS,
            nil,
            true
        ))
        group.spinner:SetTextColour(UICOLOURS.BROWN_DARK)
        group.spinner:SetOnChangedFn(on_changed)
        group.spinner:SetPosition((total_width / 2) - (width_spinner / 2), 0)
        return group
    end

    local items = {
        MakeSpinner("排序", {
        { text = "默认", data = "default" },
        { text = "按字母排序", data = "alphabetical" },
        { text = "珍惜度", data = "rarity" },
        }, function(data) self.sort_mode = data; self:RefreshEntries() end),
        MakeSpinner("筛选条件", {
        { text = "全部", data = "all" },
        { text = "白色", data = "white" },
        { text = "蓝色", data = "blue" },
        { text = "金色", data = "gold" },
        { text = "紫色", data = "purple" },
        { text = "已深度植入", data = "implanted" },
        }, function(data) self.filter_mode = data; self:RefreshEntries() end),
    }

    for index, item in ipairs(items) do
        local group = root:AddChild(item)
        group:SetPosition(50, (#items - index + 1) * (height + 3))
    end
    return root
end

function DataPage:BuildGrid(entries)
    if self.grid ~= nil then self.grid:Kill() end
    local function CellCtor(_, index)
        local cell = Widget("taskbook-cell-" .. index)
        cell.root = cell:AddChild(ImageButton(ATLAS, "cookbook_known.tex", "cookbook_known_selected.tex"))
        cell.root:SetNormalScale(73 / 128, 73 / 128)
        cell.root:SetFocusScale(73 / 128 + .05, 73 / 128 + .05)
        -- Match cookbook cells: the icon is 93px in the 128px source cell,
        -- then scales together with the cookbook_known background.
        cell.icon_root = cell.root.image:AddChild(Widget("icon_root"))
        cell.icon = cell.icon_root:AddChild(Image("images/global.xml", "square.tex"))
        cell.root:SetOnClick(function() self.selected_id = cell.data ~= nil and cell.data.id or nil end)
        return cell
    end
    local function ApplyCell(_, cell, data)
        cell.data = data
        if data == nil then cell:Hide(); return end
        cell:Show()
        cell.icon:SetTexture(data.atlas, data.image .. ".tex")
        -- This is the original cookbook food size. Only the displayed image
        -- differs from a cookbook entry; its cell remains completely vanilla.
        cell.icon:ScaleToSize(93, 93)
        cell.icon_root:SetPosition(0, 0)
        cell.icon:SetTint(1, 1, 1, 1)
        cell.root.image:SetTint(1, 1, 1, 1)
        cell.root:SetHoverText(data.name .. "\n" .. data.prefab)
    end
    self.grid = self.gridroot:AddChild(TEMPLATES.ScrollingGrid(entries, {
        context = {}, widget_width = 78, widget_height = 78, force_peek = true,
        num_visible_rows = 5, num_columns = 5, item_ctor_fn = CellCtor, apply_fn = ApplyCell,
        scrollbar_offset = 20, scrollbar_height_offset = -60,
    }))
    self.grid:SetPosition(-15, 0)
    self.grid.up_button:SetTextures(ATLAS, "quagmire_recipe_scroll_arrow_hover.tex")
    self.grid.up_button:SetScale(.5)
    self.grid.down_button:SetTextures(ATLAS, "quagmire_recipe_scroll_arrow_hover.tex")
    self.grid.down_button:SetScale(-.5)
    self.grid.scroll_bar_line:SetTexture(ATLAS, "quagmire_recipe_scroll_bar.tex")
    self.grid.scroll_bar_line:SetScale(.8)
    self.grid.position_marker:SetTextures(ATLAS, "quagmire_recipe_scroll_handle.tex")
    self.grid.position_marker.image:SetTexture(ATLAS, "quagmire_recipe_scroll_handle.tex")
    self.grid.position_marker:SetScale(.6)
    self:UpdateGridDecor()
end

function DataPage:RefreshEntries()
    local entries, filtered = TaskBook.GetEntries(self.owner), {}
    for _, entry in ipairs(entries) do
        if self.filter_mode == "all" or self.filter_mode == entry.rarity or (self.filter_mode == "implanted" and entry.implanted) then
            table.insert(filtered, entry)
        end
    end
    table.sort(filtered, function(a, b)
        if self.sort_mode == "alphabetical" then return a.prefab < b.prefab end
        if self.sort_mode == "rarity" then
            local ar, br = TaskBook.RARITY_ORDER[a.rarity] or 0, TaskBook.RARITY_ORDER[b.rarity] or 0
            return ar == br and a.prefab < b.prefab or ar < br
        end
        return a.id < b.id
    end)
    self.count_text:SetString(tostring(#filtered) .. " / " .. tostring(#entries))
    self:BuildGrid(filtered)
end

local KeiTaskBookWidget = Class(Widget, function(self, owner, initial_tab)
    Widget._ctor(self, "KeiTaskBookWidget")
    self.owner = owner
    self.root = self:AddChild(Widget("root"))
    local tab_root = self.root:AddChild(Widget("tab_root"))
    local backdrop = self.root:AddChild(Image(ATLAS, "quagmire_recipe_menu_bg.tex"))
    backdrop:ScaleToSize(900, 550)
    self.tabs = {}
    for index, label in ipairs({ "任务", "状态", "数据" }) do
        local tab = tab_root:AddChild(ImageButton(ATLAS, "quagmire_recipe_tab_inactive.tex", nil, nil, nil, "quagmire_recipe_tab_active.tex"))
        tab:SetFocusScale(.7, .7)
        tab:SetNormalScale(.7, .7)
        tab:SetText(label)
        tab:SetTextSize(22)
        tab:SetFont(HEADERFONT)
        tab:SetTextColour(UICOLOURS.GOLD)
        tab:SetTextFocusColour(UICOLOURS.GOLD)
        tab:SetTextSelectedColour(UICOLOURS.GOLD)
        tab.text:SetPosition(0, -2)
        tab.clickoffset = Vector3(0, 5, 0)
        tab:SetPosition((index - 2) * 200, 285)
        tab:SetOnClick(function() self:SelectTab(index) end)
        tab:MoveToBack()
        self.tabs[index] = tab
    end
    self:SelectTab(initial_tab or (owner ~= nil and owner._kei_taskbook_selected_tab) or 1)
end)

function KeiTaskBookWidget:SelectTab(index)
    index = math.clamp(tonumber(index) or 1, 1, #self.tabs)
    if self.last_selected ~= nil then self.last_selected:Unselect() end
    self.last_selected = self.tabs[index]
    self.selected_tab = index
    if self.owner ~= nil then
        self.owner._kei_taskbook_selected_tab = index
    end
    self.last_selected:Select()
    self.last_selected:MoveToFront()
    if self.panel ~= nil then self.panel:Kill() end
    if index == 1 then
        self.panel = self.root:AddChild(StatusPage(self.owner))
    elseif index == 2 then
        self.panel = self.root:AddChild(TaskPage(self.owner))
    else
        self.panel = self.root:AddChild(DataPage(self.owner))
    end
    self.focus_forward = self.panel
end

return KeiTaskBookWidget
