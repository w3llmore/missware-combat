-- render/watermark.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local WM_TextService = game:GetService("TextService")
local WM_Stats = game:GetService("Stats")
local Player = Players.LocalPlayer

local MissWare = _G.MissWare or {}
local ACCENT_COLORS = MissWare.ACCENT_COLORS or {Default = Color3.new(1,1,1)}
local currentAccentColor = MissWare.currentAccentColor or "Default"
local createSlider = MissWare.createSlider or function() end
local createDropdown = MissWare.createDropdown or function() end

local WM_ICON_FONT = Font.new(
    "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json",
    Enum.FontWeight.Bold,
    Enum.FontStyle.Normal
)

local AllWatermarks = {}
local _pingItem = nil
local ColorPickerGui = nil

local function GetRealPing()
    if not _pingItem or not _pingItem.Parent then
        local network = WM_Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        _pingItem = serverStats and serverStats:FindFirstChild("Data Ping")
    end
    if not _pingItem then return 0 end
    local ok, val = pcall(function() return _pingItem:GetValue() end)
    if ok and type(val) == "number" then return math.floor(val) end
    return 0
end

-- ====== КОЛОРПИКЕР (ОТДЕЛЬНЫЙ GUI) ======
local function createColorPicker(btn, currentColor, callback)
    local isOpen = false
    btn.MouseButton1Click:Connect(function()
        if isOpen then return end
        isOpen = true

        if not ColorPickerGui then
            ColorPickerGui = Instance.new("ScreenGui")
            ColorPickerGui.Name = "WM_ColorPicker"
            ColorPickerGui.ResetOnSpawn = false
            ColorPickerGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            ColorPickerGui.Parent = CoreGui
        end

        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.5
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 999
        overlay.Parent = ColorPickerGui

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, 240, 0, 0)
        popup.Position = UDim2.new(0.5, -120, 0.5, -120)
        popup.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        popup.BackgroundTransparency = 1
        popup.ClipsDescendants = true
        popup.ZIndex = 1000
        popup.Parent = overlay
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", popup)
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(60, 60, 75)
        stroke.Transparency = 1

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.new(0, 10, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = "Select Color"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 16
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = popup

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -30, 0, 8)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.Parent = popup
        
        local function closePopup()
            isOpen = false
            TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, -120), BackgroundTransparency = 1
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
            task.wait(0.15)
            overlay:Destroy()
        end
        closeBtn.MouseButton1Click:Connect(closePopup)

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 0, 0)
        container.Position = UDim2.new(0, 10, 0, 45)
        container.BackgroundTransparency = 1
        container.Parent = popup

        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.new(0, 38, 0, 38)
        grid.CellPadding = UDim2.new(0, 6, 0, 6)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = container

        local colorData = {
            Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 150, 255),
            Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 150, 0),
            Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 100, 100),
            Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 255, 100), Color3.fromRGB(180, 130, 255),
            Color3.fromRGB(0, 0, 0), Color3.fromRGB(128, 128, 128), Color3.fromRGB(255, 200, 200)
        }

        for i, color in ipairs(colorData) do
            local cBtn = Instance.new("TextButton")
            cBtn.BackgroundColor3 = color
            cBtn.Text = ""
            cBtn.AutoButtonColor = false
            cBtn.ZIndex = 1000
            cBtn.LayoutOrder = i
            cBtn.Parent = container
            Instance.new("UICorner", cBtn).CornerRadius = UDim.new(1, 0)
            
            if color == currentColor then
                local b = Instance.new("UIStroke", cBtn)
                b.Thickness = 2
                b.Color = Color3.fromRGB(255, 255, 255)
            end
            
            cBtn.MouseButton1Click:Connect(function()
                callback(color)
                btn.BackgroundColor3 = color
                closePopup()
            end)
        end

        local rows = math.ceil(#colorData / 5)
        local height = 45 + rows * 44 + 15
        popup.Size = UDim2.new(0, 240, 0, height)
        container.Size = UDim2.new(1, -20, 0, rows * 44)

        popup.BackgroundTransparency = 1
        popup.Size = UDim2.new(0, 0, 0, 0)
        stroke.Transparency = 1
        
        TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 240, 0, height), BackgroundTransparency = 0
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()

        local function checkClick(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mp = UserInputService:GetMouseLocation()
                local ap = popup.AbsolutePosition
                local as = popup.AbsoluteSize
                if not (mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y) then
                    closePopup()
                end
            end
        end
        overlay.InputBegan:Connect(checkClick)
    end)
end

-- ====== WATERMARK CLASS ======
local Watermark = {}
Watermark.__index = Watermark

function Watermark.new()
    local self = setmetatable({}, Watermark)

    local function Animate(object, properties, duration)
        duration = duration or 0.2
        local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(object, info, properties)
        tween:Play()
        return tween
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Neverlose_Watermarks"
    gui.Parent = CoreGui
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        if protect_gui then protect_gui(gui) end
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)

    self.gui = gui
    self.blocks = {}
    self.visible = true
    self.position = "Right"
    self.misswareTextLabel = nil
    self.combinedBlock = nil

    self.container = Instance.new("Frame")
    self.container.Name = "Watermarks_Container"
    self.container.Parent = gui
    self.container.AnchorPoint = Vector2.new(1, 0)
    self.container.Position = UDim2.new(1, -15, 0, 15)
    self.container.Size = UDim2.new(0, 0, 0, 38)
    self.container.BackgroundTransparency = 1
    self.container.BorderSizePixel = 0
    self.container.ClipsDescendants = false

    self.layout = Instance.new("UIListLayout")
    self.layout.Parent = self.container
    self.layout.FillDirection = Enum.FillDirection.Horizontal
    self.layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    self.layout.SortOrder = Enum.SortOrder.LayoutOrder
    self.layout.Padding = UDim.new(0, 6)

    self.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local cw = self.layout.AbsoluteContentSize.X
        if cw > 0 then self.container.Size = UDim2.new(0, cw, 0, 38) end
    end)

    function self:SetPosition(position)
        self.position = position or "Right"
        local wasVisible = self.container.Visible
        self.container.Visible = false
        local offsetX, offsetY = 15, 15
        if position == "Left" then
            self.container.AnchorPoint = Vector2.new(0, 0)
            self.container.Position = UDim2.new(0, 170, 0, 15)
            self.layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        elseif position == "Center" then
            self.container.AnchorPoint = Vector2.new(0.5, 0)
            self.container.Position = UDim2.new(0.5, 0, 0, offsetY)
            self.layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        else
            self.container.AnchorPoint = Vector2.new(1, 0)
            self.container.Position = UDim2.new(1, -offsetX, 0, offsetY)
            self.layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        end
        task.wait(0.05)
        local cw = self.layout.AbsoluteContentSize.X
        if cw > 0 then self.container.Size = UDim2.new(0, cw, 0, 38) end
        if wasVisible then self.container.Visible = true end
    end

    function self:UpdateMissWareColor(color)
        if self.misswareTextLabel then self.misswareTextLabel.TextColor3 = color end
    end

    function self:AddCombinedBlock(elements)
        local block = {}
        local oval = Instance.new("Frame")
        oval.Parent = self.container
        oval.BackgroundColor3 = Color3.fromRGB(8, 8, 13)
        oval.BackgroundTransparency = 0.15
        oval.BorderSizePixel = 0
        oval.Size = UDim2.new(0, 0, 0, 36)
        oval.ZIndex = 999
        oval.LayoutOrder = #self.blocks + 1
        Instance.new("UICorner", oval).CornerRadius = UDim.new(0, 10)
        
        local outline = Instance.new("UIStroke", oval)
        outline.Thickness = 2; outline.Transparency = 0.8; outline.Color = Color3.fromRGB(0, 0, 0)

        local elLayout = Instance.new("UIListLayout")
        elLayout.FillDirection = Enum.FillDirection.Horizontal
        elLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        elLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        elLayout.SortOrder = Enum.SortOrder.LayoutOrder
        elLayout.Parent = oval

        local elementsList = {}
        for i, el in ipairs(elements) do
            local section = Instance.new("Frame")
            section.BackgroundTransparency = 1
            section.Size = UDim2.new(0, 0, 1, 0)
            section.LayoutOrder = i
            section.Parent = oval
            
            local sLayout = Instance.new("UIListLayout")
            sLayout.FillDirection = Enum.FillDirection.Horizontal
            sLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            sLayout.SortOrder = Enum.SortOrder.LayoutOrder
            sLayout.Padding = UDim.new(0, 8)
            sLayout.Parent = section
            
            local tLabel = Instance.new("TextLabel")
            tLabel.Parent = section
            tLabel.BackgroundTransparency = 1
            tLabel.Size = UDim2.new(0, 60, 1, 0)
            tLabel.Font = Enum.Font.GothamBold
            tLabel.Text = el.text
            tLabel.TextColor3 = el.color
            tLabel.TextSize = 13
            tLabel.TextXAlignment = Enum.TextXAlignment.Left
            tLabel.AutomaticSize = Enum.AutomaticSize.X
            
            if el.isMissWare then self.misswareTextLabel = tLabel end
            elementsList[i] = { Text = tLabel, Data = el, Section = section }
        end
        
        local function relayout()
            for _, fr in ipairs(elementsList) do
                fr.Section.Size = UDim2.new(0, fr.Text.AbsoluteSize.X + 24, 1, 0)
            end
            oval.AutomaticSize = Enum.AutomaticSize.X
        end
        relayout()

        function block:SetElementText(index, text)
            local fr = elementsList[index]
            if fr and fr.Text.Text ~= text then
                fr.Text.Text = text
                relayout()
            end
        end
        
        function block:SetVisible(v)
            oval.Visible = v
        end

        table.insert(self.blocks, block)
        return block
    end

    function self:SetVisible(visible)
        self.visible = visible
        self.container.Visible = visible
    end

    function self:Destroy()
        for i, wm in ipairs(AllWatermarks) do
            if wm == self then table.remove(AllWatermarks, i); break end
        end
        self.gui:Destroy()
    end

    table.insert(AllWatermarks, self)
    return self
end

-- ====== CARD ======
_G.createWatermarkCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20,20,20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 140)
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cs = Instance.new("UIStroke", card)
    cs.Thickness = 1
    cs.Color = Color3.fromRGB(45,45,55)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -16, 0, 36)
    header.Position = UDim2.new(0, 8, 0, 4)
    header.BackgroundTransparency = 1
    header.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 100, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Watermark"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70,70,80)
    toggle.BackgroundTransparency = 0
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card

    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content

    local watermarkEnabled = false
    local watermarkInstance = nil
    local fpsConn = nil
    local currentPosition = "Right"
    local watermarkColor = ACCENT_COLORS[currentAccentColor]

    createDropdown(content, "Position", {"Right", "Left", "Center"}, "Right", function(v)
        currentPosition = v
        if watermarkInstance then watermarkInstance:SetPosition(v) end
    end)

    -- MISSWARE COLOR
    local colorRow = Instance.new("Frame")
    colorRow.Size = UDim2.new(1, 0, 0, 26)
    colorRow.BackgroundTransparency = 1
    colorRow.Parent = content

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 110, 1, 0)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "MissWare Color"
    colorLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    colorLabel.TextSize = 11
    colorLabel.Font = Enum.Font.Gotham
    colorLabel.Parent = colorRow

    local colorBtn = Instance.new("TextButton")
    colorBtn.Size = UDim2.new(0, 25, 0, 22)
    colorBtn.Position = UDim2.new(1, -30, 0, 2)
    colorBtn.BackgroundColor3 = watermarkColor
    colorBtn.Text = ""
    colorBtn.AutoButtonColor = false
    colorBtn.Parent = colorRow
    Instance.new("UICorner", colorBtn).CornerRadius = UDim.new(0, 4)

    createColorPicker(colorBtn, watermarkColor, function(color)
        watermarkColor = color
        colorBtn.BackgroundColor3 = color
        if watermarkInstance and watermarkInstance.UpdateMissWareColor then
            watermarkInstance:UpdateMissWareColor(color)
        end
    end)

    toggle.MouseButton1Click:Connect(function()
        watermarkEnabled = not watermarkEnabled
        toggle.Text = watermarkEnabled and "ON" or "OFF"
        toggle.BackgroundColor3 = watermarkEnabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(70,70,80)

        if watermarkEnabled then
            watermarkInstance = Watermark.new()
            watermarkInstance:SetPosition(currentPosition)
            local combined = watermarkInstance:AddCombinedBlock({
                { text = "FPS: 0", color = Color3.fromRGB(100, 255, 150) },
                { text = "Ping: 0", color = Color3.fromRGB(255, 200, 100) },
                { text = "MissWare", color = watermarkColor, isMissWare = true },
            })
            watermarkInstance:SetVisible(true)

            local frameCount, lastTime = 0, tick()
            local currentFPS, currentPing = 0, 0
            local lastFPS, lastPing = -1, -1
            local pingTimer = 0

            currentPing = GetRealPing()
            lastPing = currentPing
            combined:SetElementText(2, "Ping: " .. currentPing)

            fpsConn = RunService.Heartbeat:Connect(function(dt)
                if not watermarkEnabled or not watermarkInstance then return end
                frameCount = frameCount + 1
                pingTimer = pingTimer + dt
                local now = tick()
                if now - lastTime >= 1 then
                    currentFPS = frameCount
                    frameCount = 0
                    lastTime = now
                end
                if pingTimer >= 2 then
                    pingTimer = 0
                    currentPing = GetRealPing()
                end
                if currentFPS ~= lastFPS then
                    lastFPS = currentFPS
                    combined:SetElementText(1, "FPS: " .. currentFPS)
                end
                if currentPing ~= lastPing then
                    lastPing = currentPing
                    combined:SetElementText(2, "Ping: " .. currentPing)
                end
            end)
        else
            if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
            if watermarkInstance then watermarkInstance:Destroy(); watermarkInstance = nil end
        end
    end)
end
