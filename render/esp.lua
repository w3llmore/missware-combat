-- render/esp.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local Drawing = Drawing or nil

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() Camera = Workspace.CurrentCamera end)

local MissWare = _G.MissWare or {}
local ACCENT_COLORS = MissWare.ACCENT_COLORS or {Default = Color3.new(1,1,1)}
local currentAccentColor = MissWare.currentAccentColor or "Default"
local createSlider = MissWare.createSlider or function() end
local createCheckbox = MissWare.createCheckbox or function() end
local createDropdown = MissWare.createDropdown or function() end

local ESPSettings = {
    Enabled = false, Mode = "Classic",
    ChamsVisibleColor = Color3.fromRGB(0, 255, 0), ChamsHiddenColor = Color3.fromRGB(255, 0, 0),
    HealthBar = false, NameESP = false, NameColor = Color3.fromRGB(255, 255, 255),
    TeamCheck = false, MaxDistance = 500
}

local ESP = {
    conn = nil, activeHighlights = {}, activeNames = {}, activeHealthBars = {},
    visibilityCache = {}, frameCounter = 0, newEspEnabled = false, espData = {}, toggle = nil,
}

local ColorPickerGui = nil
local function createColorPicker(btn, currentColor, callback)
    local colorPickerVisible = false
    btn.MouseButton1Click:Connect(function()
        if colorPickerVisible then return end
        colorPickerVisible = true
        if not ColorPickerGui then
            ColorPickerGui = Instance.new("ScreenGui")
            ColorPickerGui.Name = "MissWare_ESP_ColorPicker"
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
            colorPickerVisible = false
            TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, -120), BackgroundTransparency = 1
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
            task.wait(0.15)
            overlay:Destroy()
        end
        closeBtn.MouseButton1Click:Connect(closePopup)
        local colorContainer = Instance.new("Frame")
        colorContainer.Size = UDim2.new(1, -20, 0, 0)
        colorContainer.Position = UDim2.new(0, 10, 0, 45)
        colorContainer.BackgroundTransparency = 1
        colorContainer.Parent = popup
        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.new(0, 38, 0, 38)
        grid.CellPadding = UDim2.new(0, 6, 0, 6)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = colorContainer
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
            cBtn.Parent = colorContainer
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
        colorContainer.Size = UDim2.new(1, -20, 0, rows * 44)
        popup.BackgroundTransparency = 1
        popup.Size = UDim2.new(0, 0, 0, 0)
        stroke.Transparency = 1
        TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 240, 0, height), BackgroundTransparency = 0
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
        local function checkClickOutside(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mp = UserInputService:GetMouseLocation()
                local ap = popup.AbsolutePosition
                local as = popup.AbsoluteSize
                if not (mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y) then
                    closePopup()
                end
            end
        end
        overlay.InputBegan:Connect(checkClickOutside)
    end)
end

local function isRealPlayer(plr)
    if not plr or typeof(plr) ~= "Instance" then return false end
    if not plr:IsA("Player") then return false end
    if not plr.Parent then return false end
    if plr == Player then return false end
    return true
end

local function isPlayerAlive(plr)
    if not isRealPlayer(plr) then return false end
    if not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

local function isPlayerAlive2(plr)
    local char = plr.Character
    if not char or not char.Parent then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return false end
    return true
end

local function isSameTeam(plr)
    if plr == Player then return true end
    if plr.Team and Player.Team and plr.Team == Player.Team then return true end
    if plr.TeamColor and Player.TeamColor and plr.TeamColor == Player.TeamColor then return true end
    return false
end

local function espIsTeammate(plr)
    local forceTeamCheck = (ESPSettings.Mode == "CounterBlox")
    if not ESPSettings.TeamCheck and not forceTeamCheck then return false end
    return isSameTeam(plr)
end

local function getPlayerParts(plr)
    if not isRealPlayer(plr) or not plr.Character then return {} end
    local parts = {}
    for _, obj in ipairs(plr.Character:GetDescendants()) do
        if obj:IsA("BasePart") then table.insert(parts, obj) end
    end
    return parts
end

local function isPlayerVisible(plr)
    if not isPlayerAlive(plr) then return false end
    local camera = Camera
    if not camera then return false end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local sp, on = camera:WorldToViewportPoint(root.Position)
    if sp.Z < 0 or not on then return false end
    return true
end

local function createNewESP(plr)
    if not isRealPlayer(plr) or ESP.espData[plr] or not Drawing then return end
    local box = Drawing.new("Square"); box.Thickness = 2; box.Filled = false; box.Color = ESPSettings.ChamsVisibleColor; box.Visible = false
    local tracer = Drawing.new("Line"); tracer.Thickness = 1.5; tracer.Color = ESPSettings.ChamsHiddenColor; tracer.Visible = false
    local nt = Drawing.new("Text"); nt.Size = 14; nt.Center = true; nt.Outline = true; nt.Font = 2; nt.Color = ESPSettings.NameColor; nt.Visible = false
    ESP.espData[plr] = { Player = plr, Box = box, Tracer = tracer, Name = nt }
end

local function removeNewESP(plr)
    local d = ESP.espData[plr]
    if d then
        if d.Box then d.Box:Remove() end
        if d.Tracer then d.Tracer:Remove() end
        if d.Name then d.Name:Remove() end
        ESP.espData[plr] = nil
    end
end

local function setNewESPVisible(v)
    for _, d in pairs(ESP.espData) do
        if d.Box then d.Box.Visible = v end
        if d.Tracer then d.Tracer.Visible = v end
        if d.Name then d.Name.Visible = v end
    end
end

local function updateNewESP()
    if not ESP.newEspEnabled or not ESPSettings.Enabled then setNewESPVisible(false); return end
    local camera = Camera; if not camera then return end
    local vs = camera.ViewportSize
    for plr, data in pairs(ESP.espData) do
        if not isRealPlayer(plr) or not isPlayerAlive(plr) or not isPlayerVisible(plr) or espIsTeammate(plr) then
            data.Box.Visible = false; data.Tracer.Visible = false; data.Name.Visible = false
        else
            local parts = getPlayerParts(plr)
            if #parts == 0 then data.Box.Visible = false; data.Tracer.Visible = false; data.Name.Visible = false
            else
                local minX, minY, minZ = math.huge, math.huge, math.huge
                local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
                for _, part in ipairs(parts) do
                    local pos, size = part.Position, part.Size / 2
                    local cs = {
                        Vector3.new(pos.X-size.X,pos.Y-size.Y,pos.Z-size.Z), Vector3.new(pos.X+size.X,pos.Y-size.Y,pos.Z-size.Z),
                        Vector3.new(pos.X-size.X,pos.Y+size.Y,pos.Z-size.Z), Vector3.new(pos.X+size.X,pos.Y+size.Y,pos.Z-size.Z),
                        Vector3.new(pos.X-size.X,pos.Y-size.Y,pos.Z+size.Z), Vector3.new(pos.X+size.X,pos.Y-size.Y,pos.Z+size.Z),
                        Vector3.new(pos.X-size.X,pos.Y+size.Y,pos.Z+size.Z), Vector3.new(pos.X+size.X,pos.Y+size.Y,pos.Z+size.Z),
                    }
                    for _, c in ipairs(cs) do
                        if c.X<minX then minX=c.X end; if c.Y<minY then minY=c.Y end; if c.Z<minZ then minZ=c.Z end
                        if c.X>maxX then maxX=c.X end; if c.Y>maxY then maxY=c.Y end; if c.Z>maxZ then maxZ=c.Z end
                    end
                end
                local cp = Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2)
                local c3 = {Vector3.new(minX,minY,minZ),Vector3.new(maxX,minY,minZ),Vector3.new(minX,maxY,minZ),Vector3.new(maxX,maxY,minZ),
                            Vector3.new(minX,minY,maxZ),Vector3.new(maxX,minY,maxZ),Vector3.new(minX,maxY,maxZ),Vector3.new(maxX,maxY,maxZ)}
                local sMinX,sMinY,sMaxX,sMaxY = math.huge,math.huge,-math.huge,-math.huge
                for _, p in ipairs(c3) do
                    local sp = camera:WorldToViewportPoint(p)
                    if sp.X<sMinX then sMinX=sp.X end; if sp.Y<sMinY then sMinY=sp.Y end
                    if sp.X>sMaxX then sMaxX=sp.X end; if sp.Y>sMaxY then sMaxY=sp.Y end
                end
                local bw,bh = sMaxX-sMinX, sMaxY-sMinY
                if bw<20 or bh<20 then
                    local cs2 = camera:WorldToViewportPoint(cp)
                    if cs2 then data.Box.Size=Vector2.new(30,30); data.Box.Position=Vector2.new(cs2.X-15,cs2.Y-15); data.Box.Visible=true
                    else data.Box.Visible=false end
                else data.Box.Size=Vector2.new(bw,bh); data.Box.Position=Vector2.new(sMinX,sMinY); data.Box.Visible=true end
                local cs3 = camera:WorldToViewportPoint(cp)
                if cs3 then
                    data.Tracer.From=Vector2.new(vs.X/2,vs.Y); data.Tracer.To=Vector2.new(cs3.X,cs3.Y); data.Tracer.Visible=true
                    local dist=(cp-camera.CFrame.Position).Magnitude
                    data.Name.Text=plr.Name.." ["..math.floor(dist).."m]"; data.Name.Position=Vector2.new(cs3.X,sMaxY+15); data.Name.Visible=true
                else data.Tracer.Visible=false; data.Name.Visible=false end
            end
        end
    end
end

local function isTargetVisible(char, now)
    if not char or not char.Parent then return true end
    local head = char:FindFirstChild("Head"); local root = char:FindFirstChild("HumanoidRootPart")
    if not head and not root then return true end
    local cached = ESP.visibilityCache[char]
    if cached and now-cached.time<0.25 then return cached.visible end
    local camera = Camera; if not camera then return true end
    local origin = camera.CFrame.Position
    local ignore = {}; if Player.Character then table.insert(ignore, Player.Character) end; table.insert(ignore, char)
    local pts = {}
    if head then table.insert(pts,head.Position); table.insert(pts,head.Position+Vector3.new(0,0.5,0)); table.insert(pts,head.Position-Vector3.new(0,0.5,0)) end
    if root then table.insert(pts,root.Position) end
    local vis = false
    for _, point in ipairs(pts) do
        local dir = point-origin; local dist = dir.Magnitude
        if dist>ESPSettings.MaxDistance then break end
        if dist>0.01 then
            local ray = Ray.new(origin,dir.Unit*dist)
            local ok,hit = pcall(function() return Workspace:FindPartOnRayWithIgnoreList(ray,ignore) end)
            if ok and (not hit or hit==head or hit==root or (hit and hit:IsDescendantOf(char))) then vis=true; break end
        end
    end
    ESP.visibilityCache[char]={visible=vis,time=now}
    return vis
end

local function updateClassicESP()
    local now = tick(); local camera = Camera; if not camera then return end
    local camPos = camera.CFrame.Position
    for char, hl in pairs(ESP.activeHighlights) do if not char or not char.Parent then pcall(function() hl:Destroy() end); ESP.activeHighlights[char]=nil end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == Player then continue end
        if espIsTeammate(plr) then
            local char = plr.Character
            if char and ESP.activeHighlights[char] then pcall(function() ESP.activeHighlights[char]:Destroy() end); ESP.activeHighlights[char]=nil end
            if ESP.activeNames[plr] then pcall(function() ESP.activeNames[plr]:Remove() end); ESP.activeNames[plr]=nil end
            if ESP.activeHealthBars[plr] then local d=ESP.activeHealthBars[plr]; pcall(function() d.Text:Remove() end); pcall(function() d.Heart:Remove() end); ESP.activeHealthBars[plr]=nil end
            continue
        end
        if not isPlayerAlive2(plr) then
            local char=plr.Character
            if char and ESP.activeHighlights[char] then ESP.activeHighlights[char].Enabled=false end
            if ESP.activeNames[plr] then ESP.activeNames[plr].Visible=false end
            if ESP.activeHealthBars[plr] then ESP.activeHealthBars[plr].Text.Visible=false; ESP.activeHealthBars[plr].Heart.Visible=false end
            continue
        end
        local char=plr.Character; if not char or not char.Parent then continue end
        local head=char:FindFirstChild("Head"); if not head then continue end
        local dist=(camPos-head.Position).Magnitude; local inRange = dist <= ESPSettings.MaxDistance
        local hl=ESP.activeHighlights[char]
        if not hl then hl=Instance.new("Highlight"); hl.Parent=char; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.OutlineTransparency=1; hl.FillTransparency=0.3; ESP.activeHighlights[char]=hl end
        if not inRange then if hl.Enabled then hl.Enabled=false end
        else
            local vis=isTargetVisible(char,now); local newColor=vis and ESPSettings.ChamsVisibleColor or ESPSettings.ChamsHiddenColor
            if hl.FillColor~=newColor then hl.FillColor=newColor end
            if not hl.Enabled then hl.Enabled=true end
        end
        if ESPSettings.NameESP and inRange then
            local sp,on=camera:WorldToViewportPoint(head.Position+Vector3.new(0,2,0))
            if on and sp.Z>0 then
                local nt=ESP.activeNames[plr]
                if not nt then nt=Drawing.new("Text"); nt.Size=13; nt.Center=true; nt.Outline=true; nt.OutlineColor=Color3.fromRGB(0,0,0); ESP.activeNames[plr]=nt end
                if nt.Text~=plr.Name then nt.Text=plr.Name end
                if nt.Color~=ESPSettings.NameColor then nt.Color=ESPSettings.NameColor end
                nt.Position=Vector2.new(sp.X,sp.Y)
                if not nt.Visible then nt.Visible=true end
            else if ESP.activeNames[plr] then ESP.activeNames[plr].Visible=false end end
        elseif ESP.activeNames[plr] then ESP.activeNames[plr].Visible=false end
        if ESPSettings.HealthBar and inRange then
            local hum=char:FindFirstChild("Humanoid")
            if hum and hum.Health>0 then
                local oy=math.clamp(3.5-dist*0.001,1.5,3.5)
                local sp,on=camera:WorldToViewportPoint(head.Position+Vector3.new(0,oy,0))
                if on and sp.Z>0 then
                    local data=ESP.activeHealthBars[plr]
                    if not data then
                        local text=Drawing.new("Text"); text.Size=18; text.Center=true; text.Outline=true; text.OutlineColor=Color3.fromRGB(0,0,0); text.OutlineTransparency=0.5; text.Font=3; text.Color=Color3.fromRGB(255,255,255)
                        local heart=Drawing.new("Text"); heart.Size=16; heart.Center=true; heart.Outline=true; heart.OutlineColor=Color3.fromRGB(0,0,0); heart.OutlineTransparency=0.5; heart.Font=3; heart.Color=Color3.fromRGB(255,60,60); heart.Text="♥"
                        data={Text=text,Heart=heart}; ESP.activeHealthBars[plr]=data
                    end
                    local hp=math.clamp(hum.Health/hum.MaxHealth,0,1)
                    local color
                    if hp>0.5 then color=Color3.fromRGB(0,255,120) elseif hp>0.3 then color=Color3.fromRGB(255,220,0) else color=Color3.fromRGB(255,60,60) end
                    data.Text.Text=tostring(math.floor(hum.Health)); data.Text.Color=color; data.Text.Position=Vector2.new(sp.X+14,sp.Y); data.Text.Visible=true
                    data.Heart.Position=Vector2.new(sp.X-14,sp.Y); data.Heart.Visible=true
                else
                    if ESP.activeHealthBars[plr] then ESP.activeHealthBars[plr].Text.Visible=false; ESP.activeHealthBars[plr].Heart.Visible=false end
                end
            end
        elseif ESP.activeHealthBars[plr] then ESP.activeHealthBars[plr].Text.Visible=false; ESP.activeHealthBars[plr].Heart.Visible=false end
    end
end

local function clearAllESP()
    for _, hl in pairs(ESP.activeHighlights) do pcall(function() hl:Destroy() end) end; ESP.activeHighlights={}
    for _, n in pairs(ESP.activeNames) do pcall(function() n:Remove() end) end; ESP.activeNames={}
    for _, d in pairs(ESP.activeHealthBars) do pcall(function() d.Text:Remove() end); pcall(function() d.Heart:Remove() end) end; ESP.activeHealthBars={}
    ESP.visibilityCache={}
    for plr,d in pairs(ESP.espData) do if d.Box then d.Box:Remove() end; if d.Tracer then d.Tracer:Remove() end; if d.Name then d.Name:Remove() end end
    ESP.espData={}
end

local function updateESP()
    if not ESPSettings.Enabled then clearAllESP(); if ESP.newEspEnabled then ESP.newEspEnabled=false; setNewESPVisible(false) end; return end
    ESP.frameCounter = ESP.frameCounter + 1
    if ESPSettings.Mode == "Classic" or ESPSettings.Mode == "CounterBlox" then
        if ESP.frameCounter % 2 == 0 then updateClassicESP() end
        return
    end
    if ESP.frameCounter % 3 == 0 then
        if ESP.frameCounter % 30 == 0 then ESP.visibilityCache={} end
        if next(ESP.activeHighlights) then for _,hl in pairs(ESP.activeHighlights) do pcall(function() hl:Destroy() end) end; ESP.activeHighlights={} end
        if next(ESP.activeNames) then for _,n in pairs(ESP.activeNames) do pcall(function() n:Remove() end) end; ESP.activeNames={} end
        if next(ESP.activeHealthBars) then for _,d in pairs(ESP.activeHealthBars) do pcall(function() d.Text:Remove() end); pcall(function() d.Heart:Remove() end) end; ESP.activeHealthBars={} end
        if not ESP.newEspEnabled then
            ESP.newEspEnabled = true
            for _,plr in ipairs(Players:GetPlayers()) do if isRealPlayer(plr) then createNewESP(plr) end end
        end
        updateNewESP()
    end
end

function _G.startESP()
    if ESP.conn then ESP.conn:Disconnect() end
    ESP.conn = RunService.Heartbeat:Connect(updateESP)
end

function _G.stopESP()
    if ESP.conn then ESP.conn:Disconnect(); ESP.conn=nil end
    clearAllESP(); ESP.newEspEnabled=false; setNewESPVisible(false)
end

Players.PlayerAdded:Connect(function(plr) if isRealPlayer(plr) and ESPSettings.Enabled and ESPSettings.Mode=="Operation 1" then createNewESP(plr) end end)
Players.PlayerRemoving:Connect(function(plr) removeNewESP(plr); if ESP.activeNames[plr] then pcall(function() ESP.activeNames[plr]:Remove() end); ESP.activeNames[plr]=nil end; if ESP.activeHealthBars[plr] then local d=ESP.activeHealthBars[plr]; pcall(function() d.Text:Remove() end); pcall(function() d.Heart:Remove() end); ESP.activeHealthBars[plr]=nil end end)

_G.createESPCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20,20,20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 420)
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
    title.Text = "ESP"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70,70,80)
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    ESP.toggle = toggle
    toggle.MouseButton1Click:Connect(function()
        ESPSettings.Enabled = not ESPSettings.Enabled
        toggle.Text = ESPSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = ESPSettings.Enabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(70,70,80)
        if ESPSettings.Enabled then _G.startESP() else _G.stopESP() end
    end)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 3
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.Parent = card

    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content
    cl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() content.CanvasSize = UDim2.new(0, 0, 0, cl.AbsoluteContentSize.Y + 20) end)

    createDropdown(content, "Mode", {"Classic", "Operation 1", "CounterBlox"}, ESPSettings.Mode, function(v) ESPSettings.Mode = v; if ESPSettings.Enabled then _G.stopESP(); _G.startESP() end end)

    local function colorRowCreate(labelText, colorVal, onPick)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent = content
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 110, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(180,180,190)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = row
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 25, 0, 22)
        btn.Position = UDim2.new(1, -30, 0, 2)
        btn.BackgroundColor3 = colorVal
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        createColorPicker(btn, colorVal, onPick)
    end

    colorRowCreate("Visible Color", ESPSettings.ChamsVisibleColor, function(c) ESPSettings.ChamsVisibleColor = c end)
    colorRowCreate("Hidden Color", ESPSettings.ChamsHiddenColor, function(c) ESPSettings.ChamsHiddenColor = c end)
    colorRowCreate("Name Color", ESPSettings.NameColor, function(c) ESPSettings.NameColor = c end)

    createCheckbox(content, "Health Bar", ESPSettings.HealthBar, function(v) ESPSettings.HealthBar = v end)
    createCheckbox(content, "Name ESP", ESPSettings.NameESP, function(v) ESPSettings.NameESP = v end)
    createCheckbox(content, "Team Check", ESPSettings.TeamCheck, function(v) ESPSettings.TeamCheck = v end)
    createSlider(content, "Max Distance", 100, 1000, ESPSettings.MaxDistance, "m", function(v) ESPSettings.MaxDistance = v end)
end

_G.ESPSettings = ESPSettings
