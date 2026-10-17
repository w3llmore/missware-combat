-- movement/bhop.lua
-- MissWare BunnyHop Module

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local MissWare = _G.MissWare or {}
local createSlider = MissWare.createSlider or function() end
local createCheckbox = MissWare.createCheckbox or function() end
local createDropdown = MissWare.createDropdown or function() end
local captureKeybind = MissWare.captureKeybind or function() end

local BHOP_FORCE = 1e5

local BHOP_MODES = {
    Classic       = { MaxSpeed = 70, Accel = 620, KeepOnGround = false, AirSteer = true, JumpDebounce = 0.09 },
    WarfareTycoon = { MaxSpeed = 55, Accel = 480, KeepOnGround = true,  AirSteer = true, JumpDebounce = 0.11 },
    CounterBlox   = { MaxSpeed = 65, Accel = 520, KeepOnGround = true,  AirSteer = true, JumpDebounce = 0.09 },
}

local BunnyHopSettings = {
    Enabled      = false,
    Mode         = "CounterBlox",
    AutoJump     = true,
    AirSteer     = true,
    MaxSpeed     = 65,
    Accel        = 520,
    KeepOnGround = true,
    JumpDebounce = 0.09,
    JumpPower    = 18,
    BindKey      = Enum.KeyCode.RightControl,
    AutoJumpBind = nil,
    AirSteerBind = nil,
}

local BH = {
    bv = nil,
    conn = nil,
    lastJump = 0,
    horiz = Vector3.zero,
    dir = Vector3.zero,
    wasAir = false,
    lastJumpTime = 0,
    bhopToggle = nil,
}

local function getParts()
    local char = Player.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function applyMode(mode)
    local p = BHOP_MODES[mode]
    if not p then return end
    BunnyHopSettings.Mode         = mode
    BunnyHopSettings.MaxSpeed     = p.MaxSpeed
    BunnyHopSettings.Accel        = p.Accel
    BunnyHopSettings.KeepOnGround = p.KeepOnGround
    BunnyHopSettings.AirSteer     = p.AirSteer
    BunnyHopSettings.JumpDebounce = p.JumpDebounce
    BH.horiz, BH.dir, BH.wasAir = Vector3.zero, Vector3.zero, false
    BH.lastJump = 0
end

local function applyJumpPower()
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        if hum.UseJumpPower ~= nil then hum.UseJumpPower = true end
        hum.JumpPower = BunnyHopSettings.JumpPower
    end)
end

local function ensureBV(hrp)
    if BH.bv and BH.bv.Parent == hrp then return BH.bv end
    if BH.bv then pcall(function() BH.bv:Destroy() end) end
    for _, o in ipairs(hrp:GetChildren()) do
        if o.Name == "MissWare_BhopRail" then pcall(function() o:Destroy() end) end
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name     = "MissWare_BhopRail"
    bv.P        = 8000
    bv.MaxForce = Vector3.zero
    bv.Velocity = Vector3.zero
    bv.Parent   = hrp
    BH.bv = bv
    return bv
end

local function driveOn(x, z)
    if not BH.bv then return end
    BH.bv.MaxForce = Vector3.new(BHOP_FORCE, 0, BHOP_FORCE)
    BH.bv.Velocity = Vector3.new(x, 0, z)
end

local function driveOff()
    if not BH.bv then return end
    BH.bv.MaxForce = Vector3.zero
    BH.bv.Velocity = Vector3.zero
end

local function wishDirFlat()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local f = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    local r = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
    if f.Magnitude > 0 then f = f.Unit end
    if r.Magnitude > 0 then r = r.Unit end
    local move = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += f end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= f end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += r end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= r end
    if move.Magnitude == 0 then return nil end
    return move.Unit
end

local function stepCounterBlox(dt)
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then driveOff(); return end
    ensureBV(hrp)

    local st  = hum:GetState()
    local air = (st == Enum.HumanoidStateType.Freefall) or (st == Enum.HumanoidStateType.Jumping)

    if air then
        if not BH.wasAir then
            local v = hrp.AssemblyLinearVelocity
            local h = Vector3.new(v.X, 0, v.Z)
            if BH.horiz.Magnitude < 1 then BH.horiz = h end
            if BH.dir.Magnitude == 0 then BH.dir = (h.Magnitude > 1) and h.Unit or Vector3.zero end
            BH.wasAir = true
        end
        if BunnyHopSettings.AirSteer then
            local d = wishDirFlat()
            if d then BH.dir = d end
        end
        if BH.dir.Magnitude > 0 then
            BH.horiz = BH.horiz + BH.dir * BunnyHopSettings.Accel * dt
        end
        local real = hrp.AssemblyLinearVelocity
        local rh = Vector3.new(real.X, 0, real.Z)
        if rh.Magnitude > BunnyHopSettings.MaxSpeed then
            BH.horiz = rh.Unit * BunnyHopSettings.MaxSpeed
        elseif BH.horiz.Magnitude > BunnyHopSettings.MaxSpeed then
            BH.horiz = BH.horiz.Unit * BunnyHopSettings.MaxSpeed
        end
        driveOn(BH.horiz.X, BH.horiz.Z)
    else
        local want = BunnyHopSettings.AutoJump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
        local wish = wishDirFlat()
        if not want then
            driveOff()
            local v = hrp.AssemblyLinearVelocity
            BH.horiz = Vector3.new(v.X, 0, v.Z)
            BH.wasAir = false
            return
        end
        if not wish then
            driveOff()
            local v = hrp.AssemblyLinearVelocity
            BH.horiz = Vector3.new(v.X, 0, v.Z)
            BH.dir = Vector3.zero
            BH.wasAir = false
            return
        end
        if BunnyHopSettings.KeepOnGround and BH.horiz.Magnitude > 0.5 then
            driveOn(BH.horiz.X, BH.horiz.Z)
        else
            driveOff()
            local v = hrp.AssemblyLinearVelocity
            BH.horiz = Vector3.new(v.X, 0, v.Z)
        end
        BH.wasAir = false
        if hum.FloorMaterial ~= Enum.Material.Air then
            local now = os.clock()
            if now - BH.lastJump > BunnyHopSettings.JumpDebounce then
                hum.Jump = true
                BH.lastJump = now
            end
        end
    end
end

local function applyClassic()
    local char = Player.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum.SeatPart or hum.Health <= 0 then return end
    if math.random() > 0.9 then return end
    if BunnyHopSettings.AutoJump and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0 then
        local now = tick()
        if now - BH.lastJumpTime > 0.3 + math.random() * 0.1 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            BH.lastJumpTime = now
        end
    end
    if BunnyHopSettings.AirSteer and hum.FloorMaterial == Enum.Material.Air then
        local md = hum.MoveDirection
        if md.Magnitude > 0.3 then
            local cs = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
            if cs < BunnyHopSettings.MaxSpeed then
                hrp.Velocity = hrp.Velocity + Vector3.new(md.X * 8, 0, md.Z * 8)
            end
            local v = hrp.Velocity
            local hs = Vector3.new(v.X, 0, v.Z).Magnitude
            if hs > BunnyHopSettings.MaxSpeed then
                local lim = Vector3.new(v.X, 0, v.Z).Unit * BunnyHopSettings.MaxSpeed
                hrp.Velocity = Vector3.new(lim.X, v.Y, lim.Z)
            end
        end
    end
end

local function applyWarfare()
    local char = Player.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum.SeatPart or hum.Health <= 0 then return end
    if math.random() > 0.88 then return end
    local onGround = hum.FloorMaterial ~= Enum.Material.Air
    if BunnyHopSettings.AutoJump and onGround then
        local md = hum.MoveDirection
        if md.Magnitude > 0 then
            local now = tick()
            if now - BH.lastJumpTime > 0.25 + math.random() * 0.1 then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, BunnyHopSettings.JumpPower * (0.9 + math.random() * 0.1), hrp.Velocity.Z)
                BH.lastJumpTime = now
            end
        end
    end
    if BunnyHopSettings.AirSteer and not onGround then
        local md = hum.MoveDirection
        if md.Magnitude > 0.3 then
            local cs = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
            if cs < BunnyHopSettings.MaxSpeed then
                hrp.Velocity = hrp.Velocity + Vector3.new(md.X * 12, 0, md.Z * 12)
            end
            local v = hrp.Velocity
            local hs = Vector3.new(v.X, 0, v.Z).Magnitude
            if hs > BunnyHopSettings.MaxSpeed then
                local lim = Vector3.new(v.X, 0, v.Z).Unit * BunnyHopSettings.MaxSpeed
                hrp.Velocity = Vector3.new(lim.X, v.Y, lim.Z)
            end
        end
    end
end

function _G.startBunnyHop()
    if BH.conn then return end
    BH.horiz, BH.dir, BH.wasAir = Vector3.zero, Vector3.zero, false
    BH.lastJump, BH.lastJumpTime = 0, 0
    applyJumpPower()
    BH.conn = RunService.Stepped:Connect(function(_, dt)
        if not BunnyHopSettings.Enabled then return end
        local ok, err = pcall(function()
            if BunnyHopSettings.Mode == "CounterBlox" then stepCounterBlox(dt)
            elseif BunnyHopSettings.Mode == "WarfareTycoon" then applyWarfare()
            else applyClassic() end
        end)
        if not ok then
            warn("[MissWare BHOP] " .. tostring(err))
            _G.stopBunnyHop()
        end
    end)
end

function _G.stopBunnyHop()
    if BH.conn then BH.conn:Disconnect(); BH.conn = nil end
    driveOff()
    if BH.bv then pcall(function() BH.bv:Destroy() end); BH.bv = nil end
    BH.horiz, BH.dir, BH.wasAir = Vector3.zero, Vector3.zero, false
    BH.lastJump, BH.lastJumpTime = 0, 0
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local k = input.KeyCode
    if BunnyHopSettings.AutoJumpBind and k == BunnyHopSettings.AutoJumpBind then
        BunnyHopSettings.AutoJump = not BunnyHopSettings.AutoJump
    elseif BunnyHopSettings.AirSteerBind and k == BunnyHopSettings.AirSteerBind then
        BunnyHopSettings.AirSteer = not BunnyHopSettings.AirSteer
    end
end)

Player.CharacterAdded:Connect(function()
    BH.bv = nil
    BH.horiz, BH.dir, BH.wasAir = Vector3.zero, Vector3.zero, false
    BH.lastJump, BH.lastJumpTime = 0, 0
    task.delay(0.4, applyJumpPower)
end)

_G.createBunnyHopCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 220)
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cs = Instance.new("UIStroke", card)
    cs.Thickness = 1
    cs.Color = Color3.fromRGB(45, 45, 55)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -16, 0, 36)
    header.Position = UDim2.new(0, 8, 0, 4)
    header.BackgroundTransparency = 1
    header.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 100, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Bunny Hop"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -100, 0, 7)
    toggle.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    toggle.BackgroundTransparency = 0
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.AutoButtonColor = false
    toggle.Parent = header
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    BH.bhopToggle = toggle
    toggle.MouseButton1Click:Connect(function()
        BunnyHopSettings.Enabled = not BunnyHopSettings.Enabled
        toggle.Text = BunnyHopSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = BunnyHopSettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        if BunnyHopSettings.Enabled then _G.startBunnyHop() else _G.stopBunnyHop() end
    end)

    local bind = Instance.new("TextButton")
    bind.Size = UDim2.new(0, 50, 0, 22)
    bind.Position = UDim2.new(1, -50, 0, 7)
    bind.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bind.BackgroundTransparency = 0
    bind.Text = "Bind"
    bind.TextColor3 = Color3.fromRGB(200, 200, 200)
    bind.Font = Enum.Font.Gotham
    bind.TextSize = 10
    bind.AutoButtonColor = false
    bind.Parent = header
    Instance.new("UICorner", bind).CornerRadius = UDim.new(0, 4)
    bind.MouseButton1Click:Connect(function()
        captureKeybind(function(k)
            BunnyHopSettings.BindKey = k
            bind.Text = k.Name
        end, function()
            BunnyHopSettings.BindKey = nil
            bind.Text = "Bind"
        end)
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card
    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 4)
    cl.Parent = content

    createDropdown(content, "Mode", {"Classic", "WarfareTycoon", "CounterBlox"}, BunnyHopSettings.Mode, function(v) applyMode(v) end)
    createCheckbox(content, "Auto Jump", BunnyHopSettings.AutoJump, function(v) BunnyHopSettings.AutoJump = v end)
    createSlider(content, "Jump Power", 10, 60, BunnyHopSettings.JumpPower, "", function(v) BunnyHopSettings.JumpPower = v; applyJumpPower() end)
    createSlider(content, "Max Speed", 16, 80, BunnyHopSettings.MaxSpeed, "", function(v) BunnyHopSettings.MaxSpeed = v end)
    createCheckbox(content, "Strafe Boost", BunnyHopSettings.AirSteer, function(v) BunnyHopSettings.AirSteer = v end)
end

_G.BunnyHopSettings = BunnyHopSettings
_G.BhopToggle = BH.bhopToggle
