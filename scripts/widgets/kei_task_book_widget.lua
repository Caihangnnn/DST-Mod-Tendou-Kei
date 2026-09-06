local ImageButton = require "widgets/imagebutton"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local TextButton = require "widgets/textbutton"
local UIAnim = require "widgets/uianim"
local Spinner = require "widgets/spinner"
local TEMPLATES = require "widgets/redux/templates"
local PlayerAvatarPortrait = require "widgets/redux/playeravatarportrait"
local TaskBook = require "kei/task_book"
local ClientSettings = require "kei/client_settings"
local MiniAlice = require "kei/mini_alice"
local MusicAPI = _G.TENDOU_KEI_MUSIC

local ATLAS = "images/quagmire_recipebook.xml"
local GRID_WIDTH = 390
local GRID_HEIGHT = 390
local PROTOCOL_DETAIL_TEXT_COLOUR = { .95, .95, .95, 1 }

local KEI_SKIN_OPTIONS = {
    { skin = "kei_none", name = "新生" },
    { skin = "kei_skin_decagrammaton", name = "十字神名" },
}
local KEI_SKIN_INDEX = {
    kei_none = 1,
    kei_skin_decagrammaton = 2,
}
local KEI_PORTRAIT_FACINGS = {
    FACING_DOWN,
    FACING_RIGHT,
    FACING_UP,
}

local function CreateCompactMusicButton(parent, label, width, height)
    local button = parent:AddChild(ImageButton(
        ATLAS,
        "cookbook_known.tex",
        "cookbook_known.tex",
        "cookbook_known.tex",
        "cookbook_known.tex"
    ))
    button:ForceImageSize(width or 28, height or 24)
    button:SetText(label)
    button:SetFont(HEADERFONT)
    button:SetTextSize(16)
    button:SetTextColour(UICOLOURS.BROWN_DARK)
    button:SetTextFocusColour(UICOLOURS.GOLD)
    button.scale_on_focus = false
    button.move_on_click = false
    return button
end

local MUSIC_RULE_LABELS = {
    sequence = "顺序播放",
    random = "随机播放",
    loop = "循环播放",
}

local function GetOwnerSkinName(owner)
    if owner == nil or owner.userid == nil or TheNet == nil then
        return "kei_none"
    end

    local client_data = TheNet:GetClientTableForUser(owner.userid)
    local skin_name = client_data ~= nil and client_data.base_skin or nil
    return type(skin_name) == "string" and skin_name ~= "" and skin_name or "kei_none"
end

local function CreatePortraitArrow(parent, x, y, is_left, scale)
    local button = parent:AddChild(ImageButton(
        "images/ui.xml",
        is_left and "crafting_inventory_arrow_l_idle.tex" or "crafting_inventory_arrow_r_idle.tex",
        is_left and "crafting_inventory_arrow_l_hl.tex" or "crafting_inventory_arrow_r_hl.tex",
        is_left and "arrow_left_disabled.tex" or "arrow_right_disabled.tex",
        is_left and "crafting_inventory_arrow_l_hl.tex" or "crafting_inventory_arrow_r_hl.tex"
    ))
    button.scale_on_focus = false
    button:SetScale(scale or 1)
    button:SetPosition(x, y)
    return button
end

local function CreateAtlasBackground(parent, atlas, texture, width, height)
    local background = parent:AddChild(Image(atlas, texture))
    background:ScaleToSize(width, height)
    background:MoveToBack()
    return background
end

-- AnimState cannot enumerate an animation bank. Try the common idle variants
-- in a random order and retain the first one with a valid visual boundary.
local IDLE_ANIM_FALLBACKS = {
    "idle_loop", "idle", "idle1", "idle2", "idle3", "idle4",
    "idle_creepy", "idle_happy", "idle_angry", "idle_scared", "idle_sad", "idle_pre",
}

local function ConfigureTaskAnimal(animal, data, anim)
    if animal == nil or type(data) ~= "table" or data.build == nil or data.bank == nil then return false end
    local success, valid = pcall(function()
        local animstate = animal:GetAnimState()
        animstate:SetBuild(data.build)
        animstate:SetBank(data.bank)
        animstate:PlayAnimation(anim or data.anim or "idle_loop", true)
        if data.facing ~= nil then
            animal:SetFacing(data.facing)
            animstate:MakeFacingDirty()
        end
        return animstate:IsCurrentAnimation(anim or data.anim or "idle_loop")
    end)
    return success and valid
end

local function FitTaskAnimal(animal, max_width, max_height, center_x, center_y)
    local success, x1, y1, x2, y2 = pcall(function()
        animal:SetScale(1)
        return animal:GetAnimState():GetVisualBB()
    end)
    local width, height = success and x2 - x1 or 0, success and y2 - y1 or 0
    if width <= 0 or height <= 0 then return false end
    local scale = math.min(max_width / width, max_height / height)
    animal:SetScale(scale)
    -- AnimState's vertical bounding-box axis is opposite the UI axis.
    animal:SetPosition(center_x - (x1 + x2) * scale / 2, center_y + (y1 + y2) * scale / 2)
    return true
end

local function ShowTaskAnimal(animal, data, max_width, max_height, center_x, center_y)
    local candidates, seen = {}, {}
    local function AddCandidate(anim)
        if type(anim) == "string" and anim ~= "" and not seen[anim] then
            seen[anim] = true
            table.insert(candidates, anim)
        end
    end
    AddCandidate(data ~= nil and data.anim)
    for _, anim in ipairs(IDLE_ANIM_FALLBACKS) do AddCandidate(anim) end
    for index = #candidates, 2, -1 do
        local swap = math.random(index)
        candidates[index], candidates[swap] = candidates[swap], candidates[index]
    end
    for _, anim in ipairs(candidates) do
        if ConfigureTaskAnimal(animal, data, anim)
            and FitTaskAnimal(animal, max_width, max_height, center_x, center_y) then
            animal:Show()
            return true
        end
    end
    animal:Hide()
    return false
end

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

local TASK_RARITY_COLOURS = {
    [1] = { 1, 1, 1, 1 },
    [2] = { .38, .65, 1, 1 },
    [3] = UICOLOURS.GOLD,
}

local function GetReplicaStackSize(item)
    local stackable = item ~= nil and item.replica ~= nil and item.replica.stackable or nil
    return stackable ~= nil and stackable:StackSize() or 1
end

local function CountOwnedPrefab(owner, prefab)
    local inventory = owner ~= nil and owner.replica ~= nil and owner.replica.inventory or nil
    if inventory == nil then return 0 end
    local count, visited = 0, {}
    local function Visit(item)
        if item == nil or visited[item] then return end
        visited[item] = true
        if item.prefab == prefab then count = count + GetReplicaStackSize(item) end
        local container = item.replica ~= nil and item.replica.container or nil
        if container ~= nil then
            for slot = 1, container:GetNumSlots() do Visit(container:GetItemInSlot(slot)) end
        end
    end
    for slot = 1, inventory:GetNumSlots() do Visit(inventory:GetItemInSlot(slot)) end
    Visit(inventory:GetActiveItem())
    Visit(inventory:GetEquippedItem(EQUIPSLOTS.BACK))
    return count
end

local TaskListPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookTaskListPage")
    self.owner = owner
    self.sort_mode = "rarity"
    self.filter_mode = "all"
    self.selected_id = nil
    self.last_signature = nil
    self.grid_signature = nil
    self:CreateLayout()
    self:RefreshEntries(true)
    self:UpdateWhilePaused(true)
    self:StartUpdating()
    if owner ~= nil then
        self.inst:ListenForEvent("kei_taskbook_dirty", function() self:RefreshEntries(true) end, owner)
    end
end)

function TaskListPage:CreateLayout()
    self.gridroot = self:AddChild(Widget("grid_root"))
    self.gridroot:SetPosition(-180, -35)
    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    local completed_title = self:AddChild(Text(HEADERFONT, 18, "累计完成", UICOLOURS.BROWN_DARK))
    completed_title:SetHAlign(ANCHOR_MIDDLE)
    completed_title:SetPosition(-350, 229)
    local current_title = self:AddChild(Text(HEADERFONT, 18, "当前任务", UICOLOURS.BROWN_DARK))
    current_title:SetHAlign(ANCHOR_MIDDLE)
    current_title:SetPosition(-270, 229)
    local line = self:AddChild(Image(ATLAS, "quagmire_recipe_line_short.tex"))
    line:SetScale(.5, .5)
    line:SetPosition(-310, 216)
    self.completed_count_text = self:AddChild(Text(HEADERFONT, 18, "0", UICOLOURS.BROWN_DARK))
    self.completed_count_text:SetHAlign(ANCHOR_MIDDLE)
    self.completed_count_text:SetPosition(-350, 196)
    self.count_text = self:AddChild(Text(HEADERFONT, 18, "0", UICOLOURS.BROWN_DARK))
    self.count_text:SetHAlign(ANCHOR_MIDDLE)
    self.count_text:SetPosition(-270, 196)
    self.spinner_root = self.gridroot:AddChild(self:BuildSpinners())
end

function TaskListPage:BuildSpinners()
    local root = Widget("spinner_root")
    local function MakeSpinner(label, options, changed)
        local group = Widget("labelspinner")
        local text = group:AddChild(Text(HEADERFONT, 18, label, UICOLOURS.BROWN_DARK))
        text:SetRegionSize(120, 25)
        text:SetHAlign(ANCHOR_RIGHT)
        text:SetPosition(-78, 0)
        local spinner = group:AddChild(Spinner(options, 150, 25, { font = HEADERFONT, size = 18 }, nil, ATLAS, nil, true))
        spinner:SetTextColour(UICOLOURS.BROWN_DARK)
        spinner:SetPosition(60, 0)
        spinner:SetOnChangedFn(changed)
        return group
    end
    local sort = root:AddChild(MakeSpinner("排序", {
        { text = "稀有度", data = "rarity" },
        { text = "未完成", data = "active" },
    }, function(data) self.sort_mode = data self:RefreshEntries(true) end))
    sort:SetPosition(50, 56)
    local filter = root:AddChild(MakeSpinner("筛选条件", {
        { text = "全部", data = "all" },
        { text = "未完成", data = "active" },
        { text = "可提交", data = "submittable" },
        { text = "已完成", data = "completed" },
    }, function(data) self.filter_mode = data self:RefreshEntries(true) end))
    filter:SetPosition(50, 28)
    return root
end

function TaskListPage:UpdateGridDecor()
    if self.grid_border_top ~= nil then self.grid_border_top:Kill() end
    if self.grid_border_bottom ~= nil then self.grid_border_bottom:Kill() end
    local _, height = self.grid:GetScrollRegionSize()
    self.grid_border_top = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    self.grid_border_top:SetScale(.75, .75)
    self.grid_border_top:SetPosition(-3, height / 2 + 1)
    self.grid_border_bottom = self.gridroot:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    self.grid_border_bottom:SetScale(.75, -.75)
    self.grid_border_bottom:SetPosition(-3, -height / 2)
    self.spinner_root:SetPosition(0, height / 2 + 5)
end

function TaskListPage:BuildGrid(entries)
    if self.grid ~= nil then self.grid:Kill() end
    local function CellCtor(_, index)
        local cell = Widget("task-cell-" .. index)
        cell.root = cell:AddChild(ImageButton(ATLAS, "cookbook_known.tex", "cookbook_known_selected.tex"))
        cell.root:SetNormalScale(73 / 128, 73 / 128)
        cell.root:SetFocusScale(73 / 128 + .05, 73 / 128 + .05)
        cell.icon_root = cell.root.image:AddChild(Widget("icon_root"))
        cell.icon = cell.icon_root:AddChild(Image("images/global.xml", "square.tex"))
        cell.animal = cell.icon_root:AddChild(UIAnim())
        cell.root:SetOnClick(function()
            self.selected_id = cell.data ~= nil and cell.data.id or nil
            self:RefreshDetails()
        end)
        return cell
    end
    local function ApplyCell(_, cell, data)
        cell.data = data
        if data == nil then cell:Hide() return end
        cell:Show()
        if ShowTaskAnimal(cell.animal, data.visual, 64, 64, 0, 0) then
            cell.icon:Hide()
        else
            cell.icon:Show()
            cell.icon:SetTexture(data.atlas or "images/global.xml", data.texture or "square.tex")
            cell.icon:ScaleToSize(93, 93)
        end
        cell.root.image:SetTint(unpack(TASK_RARITY_COLOURS[data.rarity] or { 1, 1, 1, 1 }))
        cell.root:SetHoverText(data.target_name .. "\n" .. data.status)
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

function TaskListPage:UpdateOfferControls(selected)
    if selected == nil or self.details_selected_id ~= selected.id then return end

    for shares, choice in pairs(self.offer_choices or {}) do
        local selected_choice = selected.offer ~= nil and selected.offer.shares == shares
        choice.image:SetTint(unpack(selected_choice and { .45, .85, .45, 1 } or { 1, 1, 1, 1 }))
        if selected.completed then choice:Disable() else choice:Enable() end
    end

    if self.submit_button ~= nil then
        if selected.completed or not selected.can_submit then self.submit_button:Disable() else self.submit_button:Enable() end
    end

    if self.status_text ~= nil then
        self.status_text:SetString(selected.completed and "已完成" or "未完成")
        self.status_text:SetColour(unpack(selected.completed and { .45, .85, .45, 1 } or UICOLOURS.BROWN_DARK))
    end

    local preview = selected.reward_preview or {}
    for index, widget in ipairs(self.reward_preview_entries or {}) do
        local reward = preview[index]
        if reward ~= nil then
            local atlas, texture = TaskBook.GetPrefabIcon(reward.prefab)
            widget.icon:SetTexture(atlas or "images/global.xml", texture or "square.tex")
            widget.icon:SetHoverText(TaskBook.GetPrefabName(reward.prefab))
            widget.icon:Show()
            widget.text:SetString(reward.is_food and "x" .. tostring(reward.count) or
                (reward.reward_chance > 0 and reward.reward_chance < .005 and "<1%" or
                    tostring(math.floor(reward.reward_chance * 100 + .5)) .. "%"))
            widget.text:Show()
        else
            widget.icon:Hide()
            widget.text:Hide()
        end
    end
end

local function GetDetailSignature(entry)
    if entry == nil then return "" end
    local visual = entry.visual or {}
    return table.concat({
        entry.id, entry.target_prefab or "", tostring(visual.bank or ""), visual.build or "",
        tostring(visual.facing or ""), visual.anim or "",
    }, "\t")
end

function TaskListPage:RefreshDetails()
    if self.details_content ~= nil then self.details_content:Kill() end
    self.details_content = self.details_root:AddChild(Widget("task_details"))
    self.offer_choices = nil
    self.submit_button = nil
    self.status_text = nil
    local selected
    for _, entry in ipairs(self.entries or {}) do
        if entry.id == self.selected_id then selected = entry break end
    end
    if selected == nil then
        self.detail_signature = ""
        return
    end
    self.detail_signature = GetDetailSignature(selected)
    self.details_selected_id = selected.id
    local horizontal = self.details_content:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    horizontal:ScaleToSize(330, 3)
    horizontal:SetPosition(0, 42)
    local vertical = self.details_content:AddChild(Image(ATLAS, "quagmire_recipe_line.tex"))
    vertical:ScaleToSize(3, 185)
    vertical:SetPosition(0, 135)

    local animal = self.details_content:AddChild(UIAnim())
    if ShowTaskAnimal(animal, selected.visual, 140, 130, -88, 135) then
    else
        animal:Hide()
        local target_atlas, target_texture = TaskBook.GetScrapbookPrefabIcon(selected.target_prefab)
        local target_icon = self.details_content:AddChild(Image(target_atlas or "images/global.xml", target_texture or "square.tex"))
        target_icon:ScaleToSize(112, 112)
        target_icon:SetPosition(-88, 135)
        target_icon:SetHoverText(selected.target_name)
    end
    local wanted_title = self.details_content:AddChild(Text(HEADERFONT, 30, "它想要", UICOLOURS.BROWN_DARK))
    wanted_title:SetPosition(88, 184)
    if selected.offer ~= nil then
        local atlas, texture = TaskBook.GetPrefabIcon(selected.offer.submit_prefab)
        local wanted_icon = self.details_content:AddChild(Image(atlas or "images/global.xml", texture or "square.tex"))
        wanted_icon:ScaleToSize(62, 62)
        wanted_icon:SetPosition(88, 116)
        wanted_icon:SetHoverText(selected.offer.submit_name)
    end
    local possible_title = self.details_content:AddChild(Text(HEADERFONT, 18, "可能获得", UICOLOURS.BROWN_DARK))
    possible_title:SetHAlign(ANCHOR_MIDDLE)
    possible_title:SetPosition(0, 16)
    self.reward_preview_entries = {}
    local preview = selected.reward_preview or {}
    local preview_count = math.max(1, #preview)
    local preview_rows = preview_count > 5 and 2 or 1
    local preview_columns = math.ceil(preview_count / preview_rows)
    local preview_width = 280 / preview_columns
    local preview_icon_size = math.max(18, math.min(preview_rows == 2 and 36 or 50, preview_width - 12))
    for index = 1, preview_count do
        local column = (index - 1) % preview_columns
        local row = math.floor((index - 1) / preview_columns)
        local x = -140 + (column + .5) * preview_width
        local icon_y = preview_rows == 2 and (row == 0 and -30 or -82) or -43
        local text_y = preview_rows == 2 and (row == 0 and -51 or -105) or -78
        local entry = {}
        entry.icon = self.details_content:AddChild(Image("images/global.xml", "square.tex"))
        entry.icon:ScaleToSize(preview_icon_size, preview_icon_size)
        entry.icon:SetPosition(x, icon_y)
        entry.text = self.details_content:AddChild(Text(BODYTEXTFONT, 15, "", UICOLOURS.WHITE))
        entry.text:SetPosition(x, text_y)
        self.reward_preview_entries[index] = entry
    end

    if selected.offer ~= nil then
        local refuse = self.details_content:AddChild(TextButton())
        refuse.image:SetSize(52, 32)
        refuse:SetText("不给")
        refuse:SetTextSize(20)
        refuse:SetPosition(-121, -155)
        refuse:SetHoverText("放弃该任务，有机会激怒它")
        refuse:SetOnClick(function()
            if MOD_RPC ~= nil and MOD_RPC.TendouKei ~= nil and MOD_RPC.TendouKei.RefuseTask ~= nil then
                SendModRPCToServer(MOD_RPC.TendouKei.RefuseTask, selected.id)
            end
        end)
    end
    self.offer_choices = {}
    for shares = 1, 3 do
        local offer = selected.offers ~= nil and selected.offers[shares] or nil
        if offer ~= nil then
            local choice = self.details_content:AddChild(ImageButton(ATLAS, "cookbook_known.tex", "cookbook_known_selected.tex"))
            choice:SetNormalScale(.36, .36)
            choice:SetFocusScale(.4, .4)
            choice:SetText(tostring(offer.submit_count))
            choice:SetTextSize(19)
            choice:SetPosition((shares - 2) * 54, -155)
            choice:SetOnClick(function()
                if MOD_RPC ~= nil and MOD_RPC.TendouKei ~= nil and MOD_RPC.TendouKei.SetTaskShares ~= nil then
                    SendModRPCToServer(MOD_RPC.TendouKei.SetTaskShares, selected.id, shares)
                end
            end)
            choice:SetHoverText("提交 " .. tostring(offer.submit_count) .. " 个 " .. selected.offer.submit_name)
            self.offer_choices[shares] = choice
        end
    end
    local submit = self.details_content:AddChild(TextButton())
    submit.image:SetSize(112, 32)
    submit:SetText("提交")
    submit:SetTextSize(20)
    submit:SetPosition(121, -155)
    submit:SetOnClick(function()
        if MOD_RPC ~= nil and MOD_RPC.TendouKei ~= nil and MOD_RPC.TendouKei.SubmitTask ~= nil then
            SendModRPCToServer(MOD_RPC.TendouKei.SubmitTask, selected.id)
        end
    end)
    self.submit_button = submit

    local status = self.details_content:AddChild(Text(
        HEADERFONT,
        30,
        selected.completed and "已完成" or "未完成",
        selected.completed and { .45, .85, .45, 1 } or UICOLOURS.BROWN_DARK))
    status:SetPosition(0, -202)
    self.status_text = status
    self:UpdateOfferControls(selected)
end

function TaskListPage:RefreshEntries(force)
    local day = TheWorld ~= nil and TheWorld.state ~= nil and (TheWorld.state.cycles or 0) or 0
    local entries, signature = {}, {}
    for _, task in ipairs(TaskBook.GetTasks(self.owner)) do
        local offer = task.offer
        local owned = offer ~= nil and CountOwnedPrefab(self.owner, offer.submit_prefab) or 0
        local can_submit = not task.completed and offer ~= nil and task.expires_day > day and owned >= offer.submit_count
        local status = task.completed and "已完成" or (can_submit and "可提交" or "未完成")
        local atlas, texture = TaskBook.GetScrapbookPrefabIcon(task.target_prefab)
        local entry = {
            id = task.id, target_prefab = task.target_prefab,
            rarity = task.rarity, created_day = task.created_day, expires_day = task.expires_day,
            loot = task.loot,
            offer = offer ~= nil and {
                shares = offer.shares, submit_prefab = offer.submit_prefab, submit_count = offer.submit_count,
                reward_prefab = offer.reward_prefab, reward_count = offer.reward_count,
                submit_name = TaskBook.GetPrefabName(offer.submit_prefab),
                reward_name = TaskBook.GetPrefabName(offer.reward_prefab),
            } or nil,
            offers = {},
            reward_preview = TaskBook.GetTaskOfferRewardPreview(task),
            completed = task.completed, can_submit = can_submit, status = status,
            target_name = TaskBook.GetPrefabName(task.target_prefab),
            atlas = atlas, texture = texture,
            visual = TaskBook.GetTaskVisual(task.target_prefab, task.visual),
        }
        for shares = 1, 3 do
            local task_offer = task.offers ~= nil and task.offers[shares] or nil
            if task_offer ~= nil then
                entry.offers[shares] = {
                    shares = task_offer.shares,
                    submit_count = task_offer.submit_count,
                }
            end
        end
        table.insert(signature, task.id .. ":" .. status .. ":" .. tostring(day)
            .. ":" .. (offer ~= nil and table.concat({ offer.shares, offer.submit_prefab, offer.submit_count, offer.reward_prefab, offer.reward_count }, ":") or ""))
        if self.filter_mode == "all" or (self.filter_mode == "active" and not task.completed)
            or (self.filter_mode == "submittable" and can_submit)
            or (self.filter_mode == "completed" and task.completed)
        then
            table.insert(entries, entry)
        end
    end
    local current_signature = table.concat(signature, ",") .. "/" .. self.sort_mode .. "/" .. self.filter_mode
    if not force and current_signature == self.last_signature then return end
    self.last_signature = current_signature
    table.sort(entries, function(a, b)
        if self.sort_mode == "active" then
            if a.completed ~= b.completed then return not a.completed end
        end
        if a.rarity ~= b.rarity then return a.rarity < b.rarity end
        return a.id < b.id
    end)
    self.entries = entries
    local selected_found = false
    for _, entry in ipairs(entries) do
        if entry.id == self.selected_id then selected_found = true break end
    end
    if not selected_found then self.selected_id = entries[1] ~= nil and entries[1].id or nil end
    self.count_text:SetString(tostring(#entries))
    local completed_count = self.owner ~= nil and self.owner._kei_taskbook_completed_count ~= nil
        and self.owner._kei_taskbook_completed_count:value() or 0
    self.completed_count_text:SetString(tostring(completed_count))
    local grid_values = {}
    for _, entry in ipairs(entries) do
        local visual = entry.visual or {}
        table.insert(grid_values, table.concat({
            entry.id, tostring(entry.rarity), entry.atlas or "", entry.texture or "",
            tostring(visual.bank or ""), visual.build or "", tostring(visual.facing or ""), visual.anim or "",
        }, "\t"))
    end
    local grid_signature = table.concat(grid_values, ",")
    if self.grid_signature ~= grid_signature then
        self.grid_signature = grid_signature
        self:BuildGrid(entries)
    end
    local selected
    for _, entry in ipairs(entries) do
        if entry.id == self.selected_id then selected = entry break end
    end
    local detail_signature = GetDetailSignature(selected)
    if self.detail_signature ~= detail_signature then
        self.detail_signature = detail_signature
        self:RefreshDetails()
    else
        self:UpdateOfferControls(selected)
    end
end

function TaskListPage:OnUpdate(dt)
    self.refresh_elapsed = (self.refresh_elapsed or 0) + dt
    if self.refresh_elapsed >= .5 then
        self.refresh_elapsed = 0
        self:RefreshEntries(false)
    end
end

local TaskPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookTaskPage")
    self.owner = owner
    self.protocol_signature = nil

    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    self.settings_root = self:AddChild(Widget("client_settings_root"))
    self.settings_root:SetPosition(-GRID_WIDTH / 2 - 30, 0)
    AddDetailPanel(self.settings_root)
    local feedback_text = self.settings_root:AddChild(Text(HEADERFONT, 17, "天童凯伊bug反馈Q群: 711300573", UICOLOURS.BROWN_DARK))
    feedback_text:SetRegionSize(340, 24)
    feedback_text:SetHAlign(ANCHOR_MIDDLE)
    feedback_text:SetPosition(0, 238)
    local settings_title = self.settings_root:AddChild(Text(HEADERFONT, 22, "快捷键设定", UICOLOURS.BROWN_DARK))
    settings_title:SetPosition(0, 210)

    local function CreateSmallSettingsButton(x, y)
        local button = self.settings_root:AddChild(ImageButton(
            ATLAS,
            "cookbook_known.tex",
            "cookbook_known.tex"
        ))
        button:ForceImageSize(72, 32)
        button:SetFont(HEADERFONT)
        button:SetTextSize(20)
        button:SetTextColour(UICOLOURS.BROWN_DARK)
        button.scale_on_focus = false
        button:SetPosition(x, y)
        return button
    end

    self.key_buttons = {}
    local function AddKeyBinding(label, action, y)
        local text = self.settings_root:AddChild(Text(HEADERFONT, 19, label, UICOLOURS.BROWN_DARK))
        text:SetRegionSize(70, 30)
        text:SetHAlign(ANCHOR_LEFT)
        text:SetPosition(-120, y)
        local button = CreateSmallSettingsButton(-49, y)
        button:SetHoverText("点击绑定")
        button:SetOnClick(function()
            button:SetText("按下按键")
            ClientSettings:BeginCapture(action, function()
                if self.inst:IsValid() then
                    self:RefreshClientSettings()
                end
            end)
        end)
        self.key_buttons[action] = button
    end

    local function AddUnassignedKeyBinding(y)
        local button = CreateSmallSettingsButton(49, y)
        button:SetText("未设定")
        button:Disable()
        local text = self.settings_root:AddChild(Text(HEADERFONT, 19, "未设定", UICOLOURS.BROWN_DARK))
        text:SetRegionSize(70, 30)
        text:SetHAlign(ANCHOR_RIGHT)
        text:SetPosition(120, y)
    end

    AddKeyBinding("冰火", "flame", 145)
    AddKeyBinding("无人机控制器", "rotor", 88)
    AddKeyBinding("冒险手记", "task_book", 31)
    AddUnassignedKeyBinding(145)
    AddUnassignedKeyBinding(88)

    local alice_mode_button = CreateSmallSettingsButton(49, 31)
    alice_mode_button:SetOnClick(function()
        ClientSettings:CycleMiniAliceArrowMode()
    end)
    self.mini_alice_arrow_mode_button = alice_mode_button
    local alice_mode_label = self.settings_root:AddChild(Text(
        HEADERFONT,
        19,
        "爱丽丝翻页",
        UICOLOURS.BROWN_DARK
    ))
    alice_mode_label:SetRegionSize(70, 30)
    alice_mode_label:SetHAlign(ANCHOR_RIGHT)
    alice_mode_label:SetPosition(120, 31)

    local priority_title = self.settings_root:AddChild(Text(HEADERFONT, 18, "右键优先级（重新装备 CD 后生效）", UICOLOURS.BROWN_DARK))
    priority_title:SetPosition(0, -58)
    self.priority_spinners = {}
    local priority_options = {
        { text = "格挡", data = "guard" },
        { text = "跳劈", data = "leap" },
        { text = "冲刺", data = "dash" },
    }
    for index = 1, 3 do
        local label = self.settings_root:AddChild(Text(HEADERFONT, 18, "优先级 " .. tostring(index), UICOLOURS.BROWN_DARK))
        label:SetRegionSize(130, 28)
        label:SetHAlign(ANCHOR_LEFT)
        label:SetPosition(-30, -100 - (index - 1) * 48)
        local spinner = self.settings_root:AddChild(Spinner(
            priority_options,
            112,
            28,
            { font = HEADERFONT, size = 18 },
            nil,
            ATLAS,
            nil,
            true
        ))
        spinner:SetTextColour(UICOLOURS.BROWN_DARK)
        spinner:SetPosition(70, -100 - (index - 1) * 48)
        spinner:SetOnChangedFn(function(value)
            if not self.updating_client_settings then
                ClientSettings:SetPrioritySlot(index, value)
            end
        end)
        self.priority_spinners[index] = spinner
    end

    self.status_values_root = self.details_root:AddChild(Widget("status_values_root"))
    local function AddStatusValue(label, y)
        local label_text = self.status_values_root:AddChild(Text(HEADERFONT, 24, label, UICOLOURS.BROWN_DARK))
        label_text:SetRegionSize(70, 32)
        label_text:SetHAlign(ANCHOR_LEFT)
        label_text:SetPosition(-125, y)
        local value_text = self.status_values_root:AddChild(Text(BODYTEXTFONT, 22, "-", UICOLOURS.GOLD))
        value_text:SetRegionSize(300, 32)
        value_text:SetHAlign(ANCHOR_LEFT)
        value_text:SetPosition(70, y)
        return value_text
    end
    self.attack_status_value = AddStatusValue("攻击", 218)
    self.defense_status_value = AddStatusValue("防御", 190)

    self.protocol_ring = self.details_root:AddChild(Widget("protocol_ring"))
    self.protocol_ring:SetPosition(0, -8)
    self:CreatePlayerPortrait()
    self:CreateMusicControls()
    self:RefreshProtocolRing(true)
    self:RefreshCombatStatusValues()
    self:RefreshClientSettings()
    self._client_settings_listener = ClientSettings:Subscribe(function()
        if self.inst:IsValid() then
            self:RefreshClientSettings()
        end
    end)
    self:UpdateWhilePaused(true)

    if owner ~= nil then
        self._protocol_slots_dirty_fn = function()
            self:RefreshProtocolRing()
        end
        self.inst:ListenForEvent("kei_protocol_slots_dirty", self._protocol_slots_dirty_fn, owner)
        self.inst:ListenForEvent("kei_protocol_slot_visuals_dirty", self._protocol_slots_dirty_fn, owner)
        self._combat_status_dirty_fn = function()
            self:RefreshCombatStatusValues()
        end
        self.inst:ListenForEvent("kei_status_combat_dirty", self._combat_status_dirty_fn, owner)
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
    local base_skin, clothing
    if client_data ~= nil then
        base_skin, clothing = GetSkinsDataFromClientTableData(client_data)
    else
        base_skin, clothing = prefab .. "_none", {}
    end
    self.equipped_skin = base_skin ~= nil and base_skin ~= "" and base_skin or "kei_none"
    self.preview_skin_index = KEI_SKIN_INDEX[self.equipped_skin] or 1
    self.view_index = 1
    self.dressup_cooldown = 0
    self.portrait:SetSkins(prefab, KEI_SKIN_OPTIONS[self.preview_skin_index].skin, clothing or {})
    self.portrait.puppet.anim:SetFacing(KEI_PORTRAIT_FACINGS[self.view_index])

    self.portrait_view_left = CreatePortraitArrow(self.protocol_ring, -84, 0, true, .55)
    self.portrait_view_right = CreatePortraitArrow(self.protocol_ring, 84, 0, false, .55)
    self.portrait_view_left:SetOnClick(function()
        self.view_index = (self.view_index - 2) % #KEI_PORTRAIT_FACINGS + 1
        self.portrait.puppet.anim:SetFacing(KEI_PORTRAIT_FACINGS[self.view_index])
    end)
    self.portrait_view_right:SetOnClick(function()
        self.view_index = self.view_index % #KEI_PORTRAIT_FACINGS + 1
        self.portrait.puppet.anim:SetFacing(KEI_PORTRAIT_FACINGS[self.view_index])
    end)

    self.skin_selector = self.details_root:AddChild(Widget("skin_selector"))
    self.skin_selector:SetPosition(0, -194)
    self.skin_name_background = CreateAtlasBackground(
        self.skin_selector, ATLAS, "quagmire_recipe_menu_block.tex", 148, 32
    )
    self.skin_left = CreatePortraitArrow(self.skin_selector, -100, 0, true, .5)
    self.skin_right = CreatePortraitArrow(self.skin_selector, 100, 0, false, .5)
    self.skin_name = self.skin_selector:AddChild(Text(HEADERFONT, 21, "", UICOLOURS.BROWN_DARK))
    self.skin_name:SetRegionSize(150, 30)
    self.skin_name:SetHAlign(ANCHOR_MIDDLE)
    self.skin_name:SetPosition(0, 0)

    self.dressup_button = self.details_root:AddChild(TextButton())
    self.dressup_button:SetText("换装")
    self.dressup_button:SetTextSize(20)
    self.dressup_button:SetTextColour(UICOLOURS.GOLD)
    self.dressup_button:SetTextFocusColour(UICOLOURS.GOLD)
    self.dressup_button.image:SetTexture(ATLAS, "quagmire_recipe_tab_inactive.tex")
    self.dressup_button.image:ScaleToSize(100, 32)
    self.dressup_button.image:MoveToBack()
    self.dressup_button:SetPosition(0, -231)

    local function SelectSkin(index)
        self.preview_skin_index = (index - 1) % #KEI_SKIN_OPTIONS + 1
        local selected = KEI_SKIN_OPTIONS[self.preview_skin_index]
        self.portrait:SetSkins(prefab, selected.skin, clothing or {})
        self.portrait.puppet.anim:SetFacing(KEI_PORTRAIT_FACINGS[self.view_index])
        self.skin_name:SetString(selected.name)
    end

    self.skin_left:SetOnClick(function()
        SelectSkin(self.preview_skin_index - 1)
    end)
    self.skin_right:SetOnClick(function()
        SelectSkin(self.preview_skin_index + 1)
    end)
    self.dressup_button:SetOnClick(function()
        if self.dressup_cooldown > 0 then
            return
        end

        local selected = KEI_SKIN_OPTIONS[self.preview_skin_index]
        if selected.skin ~= self.equipped_skin
            and MOD_RPC ~= nil
            and MOD_RPC.TendouKei ~= nil
            and MOD_RPC.TendouKei.SetKeiTaskBookSkin ~= nil
        then
            SendModRPCToServer(MOD_RPC.TendouKei.SetKeiTaskBookSkin, selected.skin)
        end
        self.dressup_cooldown = .5
        self.dressup_button:Disable()
    end)

    self.skin_name:SetString(KEI_SKIN_OPTIONS[self.preview_skin_index].name)
end

function TaskPage:RefreshMusicControls()
    if self.music_track_button == nil or MusicAPI == nil then
        return
    end

    local index = MusicAPI:GetCurrentIndex()
    local title = MusicAPI:GetTrackTitle(index)
    if MusicAPI:IsPlaying() then
        self.music_track_button:SetString(title)
    else
        self.music_track_button:SetString(title .. "（已暂停）")
    end
    self.music_pause_button:SetText(MusicAPI:IsPlaying() and "||" or ">")
    self.music_mode_button:SetText(MusicAPI:GetMode() == "public" and "众乐乐" or "独乐乐")
    self.music_rule_button:SetText(MUSIC_RULE_LABELS[MusicAPI:GetRule()] or MUSIC_RULE_LABELS.sequence)
    self.music_volume_value:SetString(string.format("%d%%", math.floor(MusicAPI:GetVolume() * 100 + .5)))
end

function TaskPage:SelectMusicTrack(index)
    if MusicAPI ~= nil then
        MusicAPI:Play(index)
        self:RefreshMusicControls()
    end
    self:CloseMusicList()
end

function TaskPage:OpenMusicList()
    if self.music_list_open or MusicAPI == nil then
        return
    end

    self.music_list_open = true

    -- A transparent button catches clicks that are outside the list. It is
    -- inserted before the list so the list remains clickable above it.
    self.music_dismiss = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.music_dismiss:ForceImageSize(900, 550)
    self.music_dismiss.image:SetTint(1, 1, 1, 0)
    self.music_dismiss.scale_on_focus = false
    self.music_dismiss.move_on_click = false
    self.music_dismiss:SetOnClick(function()
        self:CloseMusicList()
    end)

    self.music_list_root = self:AddChild(TEMPLATES.RectangleWindow(560, 280))
    self.music_list_root:SetPosition(0, -125)

    local titles = MusicAPI:GetTrackTitles()
    local function ItemConstructor(_, index)
        local widget = Widget("kei_music_item_" .. tostring(index))
        widget:SetOnGainFocus(function()
            if self.music_list ~= nil then
                self.music_list:OnWidgetFocus(widget)
            end
        end)
        widget.backing = widget:AddChild(TEMPLATES.ListItemBackground(250, 28, function() end))
        widget.backing.move_on_click = false
        widget.name = widget:AddChild(Text(BODYTEXTFONT, 15, ""))
        widget.name:SetRegionSize(242, 26)
        widget.name:SetHAlign(ANCHOR_MIDDLE)
        widget.name:SetVAlign(ANCHOR_MIDDLE)
        widget.name:SetPosition(0, 0)
        widget.focus_forward = widget.backing
        return widget
    end
    local function ApplyItem(_, widget, title, index)
        widget.item_index = index
        if title == nil then
            widget:Hide()
            widget.focus_forward = nil
            return
        end
        widget:Show()
        widget.name:SetString(title)
        widget.name:SetColour(UICOLOURS.BROWN_DARK)
        widget.backing:SetOnClick(function()
            self:SelectMusicTrack(widget.item_index)
        end)
        widget.focus_forward = widget.backing
    end

    self.music_list = self.music_list_root:AddChild(TEMPLATES.ScrollingGrid(titles, {
        widget_width = 250,
        widget_height = 28,
        num_visible_rows = 7,
        num_columns = 2,
        item_ctor_fn = ItemConstructor,
        apply_fn = ApplyItem,
        scrollbar_offset = 28,
        scrollbar_height_offset = -70,
        allow_bottom_empty_row = true,
    }))
    self.music_list_root.focus_forward = self.music_list
    self.music_list_root:MoveToFront()
    self.music_list_root:SetFocus()
end

function TaskPage:CloseMusicList()
    if self.music_dismiss ~= nil then
        self.music_dismiss:Kill()
        self.music_dismiss = nil
    end
    if self.music_list_root ~= nil then
        self.music_list_root:Kill()
        self.music_list_root = nil
        self.music_list = nil
    end
    self.music_list_open = false
end

function TaskPage:CreateMusicControls()
    self.music_root = self:AddChild(Widget("kei_music_controls"))
    self.music_root:SetPosition(0, -178)

    -- Keep the five rows compact enough to stay inside the highlighted area:
    -- icon, volume, audience, playback rule, then track controls.
    self.music_volume_icon = self.music_root:AddChild(Text(HEADERFONT, 22, "♪", UICOLOURS.BROWN_DARK))
    self.music_volume_icon:SetPosition(0, 42)
    self.music_volume_icon:SetHAlign(ANCHOR_MIDDLE)
    self.music_volume_icon:SetRegionSize(26, 22)

    self.music_volume_minus = CreateCompactMusicButton(self.music_root, "-", 22, 18)
    self.music_volume_minus:SetPosition(-25, 21)
    self.music_volume_minus:SetHelpTextMessage("减小音量")
    self.music_volume_minus:SetOnClick(function()
        if MusicAPI ~= nil then MusicAPI:SetVolume(MusicAPI:GetVolume() - .1) end
        self:RefreshMusicControls()
    end)
    self.music_volume_value = self.music_root:AddChild(Text(BODYTEXTFONT, 12, "50%", UICOLOURS.GOLD))
    self.music_volume_value:SetPosition(0, 21)
    self.music_volume_value:SetHAlign(ANCHOR_MIDDLE)
    self.music_volume_value:SetRegionSize(28, 18)
    self.music_volume_plus = CreateCompactMusicButton(self.music_root, "+", 22, 18)
    self.music_volume_plus:SetPosition(25, 21)
    self.music_volume_plus:SetHelpTextMessage("增大音量")
    self.music_volume_plus:SetOnClick(function()
        if MusicAPI ~= nil then MusicAPI:SetVolume(MusicAPI:GetVolume() + .1) end
        self:RefreshMusicControls()
    end)

    self.music_mode_button = CreateCompactMusicButton(self.music_root, "独乐乐", 76, 18)
    self.music_mode_button:SetPosition(0, 0)
    self.music_mode_button:SetHelpTextMessage("切换独乐乐或众乐乐")
    self.music_mode_button:SetOnClick(function()
        if MusicAPI ~= nil then
            MusicAPI:SetMode(MusicAPI:GetMode() == "public" and "local" or "public")
        end
        self:RefreshMusicControls()
    end)

    self.music_rule_button = CreateCompactMusicButton(self.music_root, "顺序播放", 76, 18)
    self.music_rule_button:SetPosition(0, -21)
    self.music_rule_button:SetHelpTextMessage("切换播放规则")
    self.music_rule_button:SetOnClick(function()
        if MusicAPI ~= nil then MusicAPI:CycleRule() end
        self:RefreshMusicControls()
    end)

    self.music_previous_button = CreateCompactMusicButton(self.music_root, "|<", 24, 18)
    self.music_previous_button:SetPosition(-31, -42)
    self.music_previous_button:SetHelpTextMessage("上一首")
    self.music_previous_button:SetOnClick(function()
        if MusicAPI ~= nil then MusicAPI:Previous() end
        self:RefreshMusicControls()
    end)

    self.music_pause_button = CreateCompactMusicButton(self.music_root, "||", 24, 18)
    self.music_pause_button:SetPosition(0, -42)
    self.music_pause_button:SetHelpTextMessage("暂停或继续")
    self.music_pause_button:SetOnClick(function()
        if MusicAPI ~= nil then
            if MusicAPI:IsPlaying() then MusicAPI:Pause() else MusicAPI:Play() end
        end
        self:RefreshMusicControls()
    end)

    self.music_next_button = CreateCompactMusicButton(self.music_root, ">|", 24, 18)
    self.music_next_button:SetPosition(31, -42)
    self.music_next_button:SetHelpTextMessage("下一首")
    self.music_next_button:SetOnClick(function()
        if MusicAPI ~= nil then MusicAPI:Next() end
        self:RefreshMusicControls()
    end)

    self.music_track_button = self:AddChild(Text(HEADERFONT, 17, "", UICOLOURS.BROWN_DARK))
    self.music_track_button:SetPosition(0, -260)
    self.music_track_button:SetRegionSize(460, 30)
    self.music_track_button:SetHAlign(ANCHOR_MIDDLE)
    self.music_track_button:SetVAlign(ANCHOR_MIDDLE)
    self:RefreshMusicControls()
end

function TaskPage:RefreshEquippedSkin()
    local equipped_skin = GetOwnerSkinName(self.owner)
    if equipped_skin ~= self.equipped_skin then
        self.equipped_skin = equipped_skin
    end
end

function TaskPage:RefreshClientSettings()
    for action, button in pairs(self.key_buttons or {}) do
        button:SetText(ClientSettings:GetKeyName(ClientSettings:GetBinding(action)))
    end
    self.updating_client_settings = true
    for index, spinner in ipairs(self.priority_spinners or {}) do
        spinner:SetSelected(ClientSettings:GetRightClickPriority()[index])
    end
    if self.mini_alice_arrow_mode_button ~= nil then
        local mode = ClientSettings:GetMiniAliceArrowMode()
        self.mini_alice_arrow_mode_button:SetText(MiniAlice.GetArrowModeName(mode))
        self.mini_alice_arrow_mode_button:SetHoverText(MiniAlice.GetArrowModeRule(mode))
    end
    self.updating_client_settings = nil
end

function TaskPage:RefreshCombatStatusValues()
    local owner = self.owner
    local attack_detail = owner ~= nil and owner._kei_status_attack_detail ~= nil
        and owner._kei_status_attack_detail:value() or ""
    local defense_detail = owner ~= nil and owner._kei_status_defense_detail ~= nil
        and owner._kei_status_defense_detail:value() or ""
    if self.attack_status_value ~= nil then
        self.attack_status_value:SetString(attack_detail ~= "" and attack_detail or "-")
    end
    if self.defense_status_value ~= nil then
        self.defense_status_value:SetString(defense_detail ~= "" and defense_detail or "-")
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

function TaskPage:OnMouseButton(button, down, x, y)
    if TaskPage._base.OnMouseButton(self, button, down, x, y) then
        return true
    end
    if self.music_list_open and not down then
        self:CloseMusicList()
        return true
    end
    return false
end

function TaskPage:OnUpdate(dt)
    if self.portrait ~= nil then
        self.portrait:EmoteUpdate(dt)
    end
    self:RefreshEquippedSkin()
    if self.dressup_cooldown > 0 then
        self.dressup_cooldown = math.max(0, self.dressup_cooldown - dt)
        if self.dressup_cooldown <= 0 and self.dressup_button ~= nil then
            self.dressup_button:Enable()
        end
    end
    self.refresh_elapsed = self.refresh_elapsed + dt
    if self.refresh_elapsed >= .25 then
        self.refresh_elapsed = 0
        self:RefreshProtocolRing()
        self:RefreshMusicControls()
    end
end

function TaskPage:OnRemoveEntity()
    self:CloseMusicList()
    if self._client_settings_listener ~= nil then
        ClientSettings:Unsubscribe(self._client_settings_listener)
        self._client_settings_listener = nil
    end
    if self.owner ~= nil and self._protocol_slots_dirty_fn ~= nil then
        self.inst:RemoveEventCallback("kei_protocol_slots_dirty", self._protocol_slots_dirty_fn, self.owner)
        self.inst:RemoveEventCallback("kei_protocol_slot_visuals_dirty", self._protocol_slots_dirty_fn, self.owner)
        self.inst:RemoveEventCallback("kei_status_combat_dirty", self._combat_status_dirty_fn, self.owner)
    end
end

local DataPage = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiTaskBookDataPage")
    self.owner = owner
    self.sort_mode = "default"
    self.filter_mode = "all"
    self.selected_id = nil
    self.entries = {}
    self.filtered_entries = {}
    self:CreateLayout()
    self:RefreshEntries()
end)

function DataPage:CreateLayout()
    self.gridroot = self:AddChild(Widget("grid_root"))
    self.gridroot:SetPosition(-180, -35)
    self.details_root = self:AddChild(Widget("details_root"))
    self.details_root:SetPosition(GRID_WIDTH / 2 + 30, 0)
    AddDetailPanel(self.details_root)

    local title = self:AddChild(Text(HEADERFONT, 18, "协议数据", UICOLOURS.BROWN_DARK))
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
        cell.root:SetOnClick(function()
            self.selected_id = cell.data ~= nil and cell.data.id or nil
            self:RefreshDetails()
        end)
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

local function WrapProtocolDetailText(value, max_chars)
    local lines, current = {}, {}
    for character in tostring(value or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if character == "\n" then
            table.insert(lines, table.concat(current))
            current = {}
        else
            table.insert(current, character)
            if #current >= max_chars then
                table.insert(lines, table.concat(current))
                current = {}
            end
        end
    end
    if #current > 0 or #lines == 0 then table.insert(lines, table.concat(current)) end
    return table.concat(lines, "\n")
end

local function AddProtocolDetailText(parent, font, size, value, x, y, width, height, align)
    local text = parent:AddChild(Text(font, size, value or "", PROTOCOL_DETAIL_TEXT_COLOUR))
    text:SetRegionSize(width, height)
    text:SetHAlign(align or ANCHOR_LEFT)
    if text.SetVAlign ~= nil then text:SetVAlign(ANCHOR_TOP) end
    text:SetPosition(x, y)
    return text
end

function DataPage:RefreshDetails()
    if self.details_content ~= nil then self.details_content:Kill() end
    self.details_content = self.details_root:AddChild(Widget("protocol_details"))

    local selected
    for _, entry in ipairs(self.filtered_entries or {}) do
        if entry.id == self.selected_id then
            selected = entry
            break
        end
    end
    if selected == nil then return end

    local title = self.details_content:AddChild(Text(HEADERFONT, 28, selected.name, UICOLOURS.BROWN_DARK))
    title:SetHAlign(ANCHOR_MIDDLE)
    title:SetPosition(0, 215)

    local title_line = self.details_content:AddChild(Image(ATLAS, "quagmire_recipe_line_short.tex"))
    title_line:SetScale(.75, .75)
    title_line:SetPosition(0, 197)

    local icon = self.details_content:AddChild(Image(selected.atlas, selected.image .. ".tex"))
    icon:ScaleToSize(88, 88)
    icon:SetPosition(0, 141)

    local category_title = self.details_content:AddChild(Text(HEADERFONT, 22, "协议分类", UICOLOURS.BROWN_DARK))
    category_title:SetPosition(0, 80)
    AddProtocolDetailText(
        self.details_content, BODYTEXTFONT, 21, selected.category,
        0, 52, 300, 28, ANCHOR_MIDDLE
    )

    local acquisition_title = self.details_content:AddChild(Text(HEADERFONT, 22, "获取方式", UICOLOURS.BROWN_DARK))
    acquisition_title:SetPosition(0, 12)
    AddProtocolDetailText(
        self.details_content, BODYTEXTFONT, 21,
        WrapProtocolDetailText(selected.acquisition, 24),
        0, -47, 300, 90, ANCHOR_MIDDLE
    )

    local effect_title = self.details_content:AddChild(Text(HEADERFONT, 22, "能力效果", UICOLOURS.BROWN_DARK))
    effect_title:SetPosition(0, -88)
    AddProtocolDetailText(
        self.details_content, BODYTEXTFONT, 21,
        WrapProtocolDetailText(selected.effect, 24),
        0, -177, 300, 150, ANCHOR_MIDDLE
    )
end

function DataPage:RefreshEntries()
    local entries, filtered = TaskBook.GetAllEntries(self.owner), {}
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
    self.entries = entries
    self.filtered_entries = filtered
    local selected_is_visible = false
    for _, entry in ipairs(filtered) do
        if entry.id == self.selected_id then
            selected_is_visible = true
            break
        end
    end
    if not selected_is_visible then
        self.selected_id = filtered[1] ~= nil and filtered[1].id or nil
    end
    self.count_text:SetString(tostring(#filtered) .. " / " .. tostring(#entries))
    self:BuildGrid(filtered)
    self:RefreshDetails()
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
        self.panel = self.root:AddChild(TaskListPage(self.owner))
    elseif index == 2 then
        self.panel = self.root:AddChild(TaskPage(self.owner))
    else
        self.panel = self.root:AddChild(DataPage(self.owner))
    end
    self.focus_forward = self.panel
end

return KeiTaskBookWidget
