-- dj_ui_base.lua
-- Custom UI für DJ HUB (kein Rayfield-Design mehr)
-- Stil: dunkel, lila Akzent, Sidebar + Karten, Monospace  (Strelizia-Look)
-- WICHTIG: API ist 100% Rayfield-kompatibel -> alle deine Tab-Dateien bleiben unverändert.

local UIBase = {}

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local isMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

----------------------------------------------------------------------
-- THEME  (hier kannst du alles umfärben)
----------------------------------------------------------------------
local Theme = {
    Bg          = Color3.fromRGB(13, 13, 16),
    Sidebar     = Color3.fromRGB(17, 17, 21),
    Card        = Color3.fromRGB(20, 20, 26),
    CardHeader  = Color3.fromRGB(26, 26, 33),
    Field       = Color3.fromRGB(28, 28, 35),
    Stroke      = Color3.fromRGB(42, 42, 52),
    StrokeSoft  = Color3.fromRGB(34, 34, 42),
    Accent      = Color3.fromRGB(150, 99, 247),
    AccentDim   = Color3.fromRGB(96, 62, 168),
    Text        = Color3.fromRGB(228, 228, 234),
    SubText     = Color3.fromRGB(150, 150, 162),
    Danger      = Color3.fromRGB(235, 90, 90),
    Off         = Color3.fromRGB(36, 36, 44),
    Font        = Enum.Font.Code,        -- Monospace
    FontBold    = Enum.Font.Code,
    Title       = "DJ HUB",
    Footer      = "DJ HUB · Kick a Lucky Block · v1.0.0",
}

----------------------------------------------------------------------
-- HELFER
----------------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then o[k] = v end
        end
    end
    if parent then o.Parent = parent end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function corner(inst, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, inst)
end

local function stroke(inst, color, thick, trans)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thick or 1,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
end

local function pad(inst, all)
    new("UIPadding", {
        PaddingLeft   = UDim.new(0, all),
        PaddingRight  = UDim.new(0, all),
        PaddingTop    = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
    }, inst)
end

local function tween(inst, t, props)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- Geschützt in CoreGui / gethui ablegen
local function mountGui(gui)
    local parented = false
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
    pcall(function()
        if typeof(gethui) == "function" then
            gui.Parent = gethui()
            parented = true
        end
    end)
    if not parented then
        pcall(function() gui.Parent = CoreGui end)
        if not gui.Parent then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end

----------------------------------------------------------------------
-- LIBRARY
----------------------------------------------------------------------
local Lib = {}
Lib.Flags = {}            -- für Save/Load-System (loader.lua liest das)
local activeToasts = {}

----------------------------------------------------------------------
-- NOTIFY  (Toasts unten rechts)
----------------------------------------------------------------------
local toastHolder

local function ensureToastHolder(screen)
    if toastHolder and toastHolder.Parent then return toastHolder end
    toastHolder = new("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 300, 1, -32),
        BackgroundTransparency = 1,
    }, screen)
    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, toastHolder)
    return toastHolder
end

function Lib:Notify(opts)
    opts = opts or {}
    local screen = self.__screen
    if not screen then return end
    local holder = ensureToastHolder(screen)

    local card = new("Frame", {
        BackgroundColor3 = Theme.Card,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, holder)
    corner(card, 10)
    stroke(card, Theme.Stroke, 1, 1)
    local accentBar = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 3, 1, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, card)
    corner(accentBar, 3)

    local inner = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 0, 0),
        Position = UDim2.new(0, 14, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, card)
    pad(inner, 10)
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, inner)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Theme.FontBold,
        Text = tostring(opts.Title or "DJ HUB"),
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    }, inner)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font,
        Text = tostring(opts.Content or ""),
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 2,
    }, inner)

    -- Einblenden
    tween(card, 0.18, { BackgroundTransparency = 0 })
    tween(accentBar, 0.18, { BackgroundTransparency = 0 })
    local s = card:FindFirstChildOfClass("UIStroke"); if s then tween(s, 0.18, { Transparency = 0 }) end

    local dur = tonumber(opts.Duration) or 4
    task.delay(dur, function()
        if not card.Parent then return end
        tween(card, 0.25, { BackgroundTransparency = 1 })
        tween(accentBar, 0.25, { BackgroundTransparency = 1 })
        if s then tween(s, 0.25, { Transparency = 1 }) end
        for _, lbl in ipairs(inner:GetDescendants()) do
            if lbl:IsA("TextLabel") then tween(lbl, 0.25, { TextTransparency = 1 }) end
        end
        task.wait(0.3)
        pcall(function() card:Destroy() end)
    end)
end

----------------------------------------------------------------------
-- KOMPONENTEN-BAUSTEINE (auf einem Karten-Content-Frame)
----------------------------------------------------------------------
local function makeRow(parent, height, searchName)
    local row = new("Frame", {
        BackgroundColor3 = Theme.Field,
        Size = UDim2.new(1, 0, 0, height or 38),
        BorderSizePixel = 0,
    }, parent)
    corner(row, 8)
    stroke(row, Theme.StrokeSoft, 1)
    row:SetAttribute("SearchName", string.lower(searchName or ""))
    return row
end

-- BUTTON
local function buildButton(content, def)
    local row = makeRow(content, 38, def.Name)
    local btn = new("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.Font,
        Text = tostring(def.Name or "Button"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        AutoButtonColor = false,
    }, row)
    btn.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = Theme.CardHeader }) end)
    btn.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = Theme.Field }) end)
    btn.MouseButton1Click:Connect(function()
        tween(row, 0.08, { BackgroundColor3 = Theme.AccentDim })
        task.delay(0.12, function() tween(row, 0.15, { BackgroundColor3 = Theme.Field }) end)
        if def.Callback then pcall(def.Callback) end
    end)
    return { Set = function() end }
end

-- TOGGLE (Checkbox-Style wie in den Screenshots)
local function buildToggle(content, def, flags)
    local state = not not def.CurrentValue
    local row = makeRow(content, 38, def.Name)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -56, 1, 0),
        Font = Theme.Font,
        Text = tostring(def.Name or "Toggle"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local box = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 22, 0, 22),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
    }, row)
    corner(box, 6)
    stroke(box, Theme.Stroke, 1)
    local check = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.FontBold,
        Text = "✓",
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextTransparency = 1,
    }, box)

    local hit = new("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
    }, row)

    local obj = {}
    obj.CurrentValue = state

    local function render(fireCb)
        if state then
            tween(box, 0.15, { BackgroundColor3 = Theme.Accent })
            tween(check, 0.15, { TextTransparency = 0 })
        else
            tween(box, 0.15, { BackgroundColor3 = Theme.Off })
            tween(check, 0.15, { TextTransparency = 1 })
        end
        obj.CurrentValue = state
        if fireCb and def.Callback then pcall(def.Callback, state) end
    end

    hit.MouseButton1Click:Connect(function()
        state = not state
        render(true)
    end)

    function obj:Set(v)
        state = not not v
        render(true)
    end

    render(false)
    if def.Flag then flags[def.Flag] = obj end
    return obj
end

-- SLIDER
local function buildSlider(content, def, flags)
    local min = (def.Range and def.Range[1]) or 0
    local max = (def.Range and def.Range[2]) or 100
    local inc = def.Increment or 1
    local val = math.clamp(def.CurrentValue or min, min, max)
    local suffix = def.Suffix or ""

    local row = makeRow(content, 54, def.Name)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 16),
        Font = Theme.Font,
        Text = tostring(def.Name or "Slider"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local track = new("Frame", {
        Position = UDim2.new(0, 12, 0, 30),
        Size = UDim2.new(1, -24, 0, 16),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
    }, row)
    corner(track, 6)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 6)
    local valLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.FontBold,
        TextSize = 11,
        TextColor3 = Theme.Text,
        Text = tostring(val),
    }, track)

    local obj = {}
    obj.CurrentValue = val

    local function render(fireCb)
        local a = (max > min) and ((val - min) / (max - min)) or 0
        tween(fill, 0.08, { Size = UDim2.new(a, 0, 1, 0) })
        valLbl.Text = (suffix ~= "" and (tostring(val) .. " " .. suffix)) or tostring(val)
        obj.CurrentValue = val
        if fireCb and def.Callback then pcall(def.Callback, val) end
    end

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local raw = min + rel * (max - min)
        val = math.clamp(math.floor((raw / inc) + 0.5) * inc, min, max)
        render(true)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    function obj:Set(v)
        val = math.clamp(tonumber(v) or min, min, max)
        render(true)
    end

    render(false)
    if def.Flag then flags[def.Flag] = obj end
    return obj
end

-- INPUT
local function buildInput(content, def, flags)
    local row = makeRow(content, 56, def.Name)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 16),
        Font = Theme.Font,
        Text = tostring(def.Name or "Input"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local boxFrame = new("Frame", {
        Position = UDim2.new(0, 12, 0, 28),
        Size = UDim2.new(1, -24, 0, 22),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
    }, row)
    corner(boxFrame, 6)
    stroke(boxFrame, Theme.Stroke, 1)
    local tb = new("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Font = Theme.Font,
        Text = "",
        PlaceholderText = tostring(def.PlaceholderText or ""),
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, boxFrame)

    local obj = { CurrentValue = "" }

    tb.FocusLost:Connect(function()
        obj.CurrentValue = tb.Text
        if def.Callback then pcall(def.Callback, tb.Text) end
        if def.RemoveTextAfterFocusLost then tb.Text = "" end
    end)

    function obj:Set(v)
        tb.Text = tostring(v or "")
        obj.CurrentValue = tb.Text
        if def.Callback then pcall(def.Callback, tb.Text) end
    end

    if def.Flag then flags[def.Flag] = obj end
    return obj
end

-- DROPDOWN (single + multi)
local function buildDropdown(content, def, flags, screen)
    local options = def.Options or {}
    local multi   = def.MultipleOptions and true or false

    local selected = {}
    if multi then
        local cur = def.CurrentOption or {}
        if type(cur) == "table" then
            for _, v in ipairs(cur) do selected[v] = true end
        end
    end
    local single = (not multi) and (def.CurrentOption or options[1]) or nil

    local row = makeRow(content, 56, def.Name)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 16),
        Font = Theme.Font,
        Text = tostring(def.Name or "Dropdown"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local box = new("TextButton", {
        Position = UDim2.new(0, 12, 0, 28),
        Size = UDim2.new(1, -24, 0, 22),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(box, 6)
    stroke(box, Theme.Stroke, 1)
    local valLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -28, 1, 0),
        Font = Theme.Font,
        Text = "---",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, box)
    local chevron = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 16, 1, 0),
        Font = Theme.FontBold,
        Text = "v",
        TextColor3 = Theme.SubText,
        TextSize = 12,
    }, box)

    local obj = {}
    obj.CurrentOption = multi and {} or single

    local function labelText()
        if multi then
            local list = {}
            for _, opt in ipairs(options) do if selected[opt] then table.insert(list, opt) end end
            obj.CurrentOption = list
            if #list == 0 then return "---" end
            return table.concat(list, ", ")
        else
            obj.CurrentOption = single
            return tostring(single or "---")
        end
    end

    local function refresh(fireCb)
        local t = labelText()
        valLbl.Text = t
        valLbl.TextColor3 = (t == "---") and Theme.SubText or Theme.Text
        if fireCb and def.Callback then pcall(def.Callback, obj.CurrentOption) end
    end

    -- Popup
    local open = false
    local popup
    local function closePopup()
        open = false
        tween(chevron, 0.15, { Rotation = 0 })
        if popup then popup:Destroy() popup = nil end
    end
    local function openPopup()
        if open then closePopup() return end
        open = true
        tween(chevron, 0.15, { Rotation = 180 })

        popup = new("Frame", {
            BackgroundColor3 = Theme.Card,
            Size = UDim2.new(0, box.AbsoluteSize.X, 0, math.min(#options, 6) * 28 + 8),
            Position = UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + box.AbsoluteSize.Y + 4),
            BorderSizePixel = 0,
            ZIndex = 50,
        }, screen)
        corner(popup, 8)
        stroke(popup, Theme.Accent, 1)
        local sf = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -8, 1, -8),
            Position = UDim2.new(0, 4, 0, 4),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ZIndex = 51,
        }, popup)
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, sf)

        for _, opt in ipairs(options) do
            local item = new("TextButton", {
                BackgroundColor3 = Theme.Field,
                Size = UDim2.new(1, 0, 0, 24),
                Font = Theme.Font,
                Text = tostring(opt),
                TextColor3 = (multi and selected[opt]) and Theme.Accent
                           or ((not multi and single == opt) and Theme.Accent or Theme.Text),
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                ZIndex = 52,
            }, sf)
            corner(item, 5)
            new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, item)
            item.MouseEnter:Connect(function() tween(item, 0.1, { BackgroundColor3 = Theme.CardHeader }) end)
            item.MouseLeave:Connect(function() tween(item, 0.1, { BackgroundColor3 = Theme.Field }) end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    selected[opt] = not selected[opt]
                    item.TextColor3 = selected[opt] and Theme.Accent or Theme.Text
                    refresh(true)
                else
                    single = opt
                    refresh(true)
                    closePopup()
                end
            end)
        end
    end

    box.MouseButton1Click:Connect(openPopup)

    function obj:Set(v)
        if multi then
            selected = {}
            if type(v) == "table" then for _, x in ipairs(v) do selected[x] = true end end
        else
            single = v
        end
        refresh(true)
    end

    refresh(false)
    if def.Flag then flags[def.Flag] = obj end
    return obj
end

-- PARAGRAPH
local function buildParagraph(content, def)
    local card = new("Frame", {
        BackgroundColor3 = Theme.Field,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
    }, content)
    corner(card, 8)
    stroke(card, Theme.StrokeSoft, 1)
    card:SetAttribute("SearchName", string.lower((def.Title or "") .. " " .. (def.Content or "")))
    local inner = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, card)
    pad(inner, 10)
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, inner)
    if def.Title and def.Title ~= "" then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Theme.FontBold,
            Text = tostring(def.Title),
            TextColor3 = Theme.Accent,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }, inner)
    end
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font,
        Text = tostring(def.Content or ""),
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 2,
    }, inner)
    return { Set = function() end }
end

----------------------------------------------------------------------
-- TAB / KARTEN-LOGIK
----------------------------------------------------------------------
local function newCard(page, titleText)
    local card = new("Frame", {
        BackgroundColor3 = Theme.Card,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
    }, page)
    corner(card, 10)
    stroke(card, Theme.Stroke, 1)

    -- Header
    local header = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
    }, card)
    new("Frame", {  -- accent dot
        BackgroundColor3 = Theme.Accent,
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 4, 0, 14),
        BorderSizePixel = 0,
    }, header)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 0, 0),
        Size = UDim2.new(1, -36, 1, 0),
        Font = Theme.FontBold,
        Text = tostring(titleText or "Section"),
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    new("Frame", {  -- separator
        BackgroundColor3 = Theme.StrokeSoft,
        Position = UDim2.new(0, 12, 0, 33),
        Size = UDim2.new(1, -24, 0, 1),
        BorderSizePixel = 0,
    }, card)

    local body = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 0, 0, 34),
    }, card)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 8),  PaddingBottom = UDim.new(0, 12),
    }, body)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

    return card, body
end

----------------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------------
local function createWindow(opts)
    opts = opts or {}
    Theme.Title = opts.Name or Theme.Title

    local screen = new("ScreenGui", {
        Name = "DJHUB_UI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 99999,
        IgnoreGuiInset = true,
    })
    mountGui(screen)
    Lib.__screen = screen
    ensureToastHolder(screen)

    -- Fenstergröße (mobil etwas kleiner skaliert)
    local W, H = 700, 460
    local root = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, W, 0, H),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, screen)
    corner(root, 12)
    stroke(root, Theme.Stroke, 1)
    if isMobile then
        new("UIScale", { Scale = 0.78 }, root)
    end

    -- Top-Akzentlinie (Regenbogen-Strip wie in den Screenshots)
    local topline = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, root)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(90, 220, 140)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 99, 247)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(90, 160, 255)),
        }),
    }, topline)

    -- HEADER-BAR
    local topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
    }, root)

    -- Logo
    local logoBadge = new("Frame", {
        Position = UDim2.new(0, 14, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, topbar)
    corner(logoBadge, 7)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
        Font = Theme.FontBold, Text = "D", TextColor3 = Color3.fromRGB(255,255,255), TextSize = 16,
    }, logoBadge)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 48, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        Font = Theme.FontBold,
        Text = Theme.Title,
        TextColor3 = Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)

    -- Page-Titel + Subtitel (mittig links neben Suche)
    local pageTitle = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 200, 0, 6),
        Size = UDim2.new(0, 240, 0, 18),
        Font = Theme.FontBold,
        Text = "Home",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)
    local pageSub = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 200, 0, 24),
        Size = UDim2.new(0, 240, 0, 16),
        Font = Theme.Font,
        Text = "contains basic information",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)

    -- Suche
    local searchFrame = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -54, 0.5, 0),
        Size = UDim2.new(0, 220, 0, 30),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, topbar)
    corner(searchFrame, 8)
    stroke(searchFrame, Theme.Stroke, 1)
    local searchBox = new("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Font = Theme.Font,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, searchFrame)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0, 18, 1, 0),
        Font = Theme.Font, Text = "⌕", TextColor3 = Theme.SubText, TextSize = 16,
    }, searchFrame)

    -- Minimieren / Drag-Griff
    local minBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = Theme.Field,
        Text = "—",
        Font = Theme.FontBold,
        TextColor3 = Theme.Text,
        TextSize = 16,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, topbar)
    corner(minBtn, 7)

    -- SIDEBAR
    local sidebar = new("Frame", {
        Position = UDim2.new(0, 0, 0, 50),
        Size = UDim2.new(0, 168, 1, -50 - 22),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
    }, root)
    local sideList = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
    }, sidebar)
    new("UIPadding", { PaddingTop = UDim.new(0,10), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) }, sideList)
    new("UIListLayout", { Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder }, sideList)

    -- CONTENT-BEREICH
    local contentHolder = new("Frame", {
        Position = UDim2.new(0, 168, 0, 50),
        Size = UDim2.new(1, -168, 1, -50 - 22),
        BackgroundTransparency = 1,
    }, root)

    -- Footer
    new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -4),
        Size = UDim2.new(1, -20, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.Font,
        Text = Theme.Footer,
        TextColor3 = Theme.SubText,
        TextSize = 11,
    }, root)

    -- DRAG (über Topbar)
    do
        local dragging, dragStart, startPos
        local function begin(input)
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end
        topbar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                begin(i)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- MINIMIEREN
    local minimized = false
    local restoreBtn = new("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 120, 0, 40),
        BackgroundColor3 = Theme.Accent,
        Text = "DJ HUB",
        Font = Theme.FontBold,
        TextColor3 = Color3.fromRGB(255,255,255),
        TextSize = 14,
        Visible = false,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, screen)
    corner(restoreBtn, 10)
    local function toggleMin()
        minimized = not minimized
        root.Visible = not minimized
        restoreBtn.Visible = minimized
    end
    minBtn.MouseButton1Click:Connect(toggleMin)
    restoreBtn.MouseButton1Click:Connect(toggleMin)
    UserInputService.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == Enum.KeyCode.RightShift then toggleMin() end
    end)

    ----------------------------------------------------------------
    -- WINDOW-OBJEKT
    ----------------------------------------------------------------
    local tabs = {}
    local currentTab

    local Window = {}

    local function selectTab(tab)
        if currentTab == tab then return end
        for _, t in ipairs(tabs) do
            t.page.Visible = (t == tab)
            tween(t.btn, 0.15, { BackgroundColor3 = (t == tab) and Theme.Field or Theme.Sidebar })
            t.label.TextColor3 = (t == tab) and Theme.Text or Theme.SubText
            t.bar.BackgroundTransparency = (t == tab) and 0 or 1
        end
        currentTab = tab
        pageTitle.Text = tab.name
        pageSub.Text   = tab.subtitle or ("everything about " .. string.lower(tab.name))
    end

    function Window:CreateTab(name, icon)
        name = name or "Tab"

        -- Sidebar-Button
        local btn = new("TextButton", {
            BackgroundColor3 = Theme.Sidebar,
            Size = UDim2.new(1, 0, 0, 36),
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = #tabs + 1,
        }, sideList)
        corner(btn, 8)
        local bar = new("Frame", {
            BackgroundColor3 = Theme.Accent,
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 3, 0, 18),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        }, btn)
        corner(bar, 3)
        local dot = new("Frame", {
            BackgroundColor3 = Theme.Accent,
            Position = UDim2.new(0, 14, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 8, 0, 8),
            BorderSizePixel = 0,
        }, btn)
        corner(dot, 4)
        local label = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 30, 0, 0),
            Size = UDim2.new(1, -38, 1, 0),
            Font = Theme.Font,
            Text = name,
            TextColor3 = Theme.SubText,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, btn)

        -- Seite (ScrollingFrame mit Karten)
        local page = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Accent,
            Visible = false,
        }, contentHolder)
        new("UIPadding", {
            PaddingLeft = UDim.new(0,14), PaddingRight = UDim.new(0,14),
            PaddingTop = UDim.new(0,14), PaddingBottom = UDim.new(0,14),
        }, page)
        new("UIListLayout", { Padding = UDim.new(0,12), SortOrder = Enum.SortOrder.LayoutOrder }, page)

        local tabData = {
            name = name, page = page, btn = btn, label = label, bar = bar,
            currentBody = nil,
        }
        table.insert(tabs, tabData)

        btn.MouseEnter:Connect(function()
            if currentTab ~= tabData then tween(btn, 0.1, { BackgroundColor3 = Theme.Card }) end
        end)
        btn.MouseLeave:Connect(function()
            if currentTab ~= tabData then tween(btn, 0.1, { BackgroundColor3 = Theme.Sidebar }) end
        end)
        btn.MouseButton1Click:Connect(function() selectTab(tabData) end)

        -- Karten-Helfer
        local function ensureBody()
            if not tabData.currentBody then
                local _, body = newCard(page, name)
                tabData.currentBody = body
            end
            return tabData.currentBody
        end

        -- TAB-API (Rayfield-kompatibel)
        local Tab = {}

        function Tab:CreateSection(text)
            local _, body = newCard(page, text or "")
            tabData.currentBody = body
            return { Set = function() end }
        end

        function Tab:CreateButton(def)    return buildButton(ensureBody(), def or {}) end
        function Tab:CreateToggle(def)    return buildToggle(ensureBody(), def or {}, Lib.Flags) end
        function Tab:CreateSlider(def)    return buildSlider(ensureBody(), def or {}, Lib.Flags) end
        function Tab:CreateInput(def)     return buildInput(ensureBody(), def or {}, Lib.Flags) end
        function Tab:CreateDropdown(def)  return buildDropdown(ensureBody(), def or {}, Lib.Flags, screen) end
        function Tab:CreateParagraph(def) return buildParagraph(ensureBody(), def or {}) end
        function Tab:CreateLabel(text)    return buildParagraph(ensureBody(), { Content = text }) end

        if #tabs == 1 then selectTab(tabData) end
        return Tab
    end

    -- SUCHE: filtert Zeilen in der aktiven Seite
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(searchBox.Text)
        if not currentTab then return end
        for _, card in ipairs(currentTab.page:GetChildren()) do
            if card:IsA("Frame") then
                local body = card:FindFirstChild("Frame")  -- body-Frame
                local anyVisible = false
                for _, child in ipairs(card:GetDescendants()) do
                    local sn = child:GetAttribute("SearchName")
                    if sn ~= nil then
                        local match = (q == "" or string.find(sn, q, 1, true) ~= nil)
                        child.Visible = match
                        if match then anyVisible = true end
                    end
                end
                if q == "" then card.Visible = true else card.Visible = anyVisible end
            end
        end
    end)

    return Window
end

----------------------------------------------------------------------
-- ÖFFENTLICHE API (wie dj_ui_base vorher)
----------------------------------------------------------------------
function Lib:CreateWindow(opts)
    return createWindow(opts)
end

function UIBase.createWindow()
    local Window = createWindow({ Name = "DJ HUB" })
    -- loader erwartet: return Rayfield, Window
    return Lib, Window
end

return UIBase
