-- combat/pvpbot.lua
-- MissWare PvP Bot Module (Ability Dodger + Auto Haki)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer

local MissWare = _G.MissWare or {}
local createSlider = MissWare.createSlider
local createCheckbox = MissWare.createCheckbox
local createDropdown = MissWare.createDropdown

local PvPBotSettings = {
    Enabled = false,
    Mode = "BloxFruits",
    DetectRange = 40,
    DodgeDistance = 1.0,
    DodgeCooldown = 0.6,
    DodgeMode = "Dash",
    AutoHaki = false,
}

local PV = {
    conn = nil,
    lastDodge = 0,
    lastHakiCheck = 0,
}

local DANGER_NAMES = {
    "ice", "freeze", "frozen", "blizzard", "snow",
    "dragon", "fire", "flame", "burn", "inferno",
    "dough", "pastry", "bake", "awaken",
    "venom", "poison", "toxic", "acid",
    "kitsune", "fox", "spiritfire",
    "portal", "warp", "teleport", "dimension",
    "lightning", "thunder", "electric", "shock",
    "magma", "lava", "molten", "eruption",
    "string", "thread", "web",
    "light", "flash", "holy",
    "dark", "shadow", "void", "blackhole",
    "phoenix", "reborn", "heal",
    "rubber", "gum", "stretch",
    "gravity", "pull", "push", "gravitational",
    "spirit", "soul", "ghost",
    "buddha", "enlighten",
    "leopard", "panther", "claw",
    "control", "barrier", "shambles",
    "attack", "blast", "beam", "projectile", "charge", "cast",
}

local function pvpIsDangerName(name)
    local n = name:lower()
    for _, pattern in ipairs(DANGER_NAMES) do
        if n:find(pattern) then return true end
    end
    return false
end

local function pvpIsEnemy(plr)
    if not plr or plr == Player then return false end
    if not plr.Character then return false end
    return true
end

local function pvpScanEnemy(enemyChar)
    if not enemyChar or not enemyChar.Parent then return false end
    for _, d in ipairs(enemyChar:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke")
           or d:IsA("Sparkles") or d:IsA("Beam") or d:IsA("Trail")
           or d:IsA("Explosion") or d:IsA("Sound") then
            if (d:IsA("ParticleEmitter") and d.Enabled)
               or (d:IsA("Fire") and d.Enabled)
               or (d:IsA("Smoke") and d.Enabled)
               or (d:IsA("Beam") and d.Enabled)
               or (d:IsA("Trail") and d.Enabled)
               or (d:IsA("Sound") and d.Playing) then
                if pvpIsDangerName(d.Name) then
                    return true, d.Name
                end
            end
        end
    end
    return false
end

local function pvpScanWorkspace(enemyPos)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
            if pvpIsDangerName(obj.Name) then
                local part = obj:FindFirstChildWhichIsA("BasePart") or obj
                if part and part.Position then
                    local dist = (part.Position - enemyPos).Magnitude
                    if dist < 15 then
                        return true, obj.Name
                    end
                end
            end
        end
    end
    return false
end

local function pvpDoDodge(enemyPos, mode)
    local myChar = Player.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local fromEnemy = myRoot.Position - enemyPos
    fromEnemy = Vector3.new(fromEnemy.X, 0, fromEnemy.Z)
    if fromEnemy.Magnitude < 0.1 then
        fromEnemy = Vector3.new(0, 0, 1)
    end
    fromEnemy = fromEnemy.Unit

    local distMult = PvPBotSettings.DodgeDistance or 1.0

    if mode == "Jump" then
        myRoot.Velocity = fromEnemy * 50 * distMult + Vector3.new(0, 60, 0)
    elseif mode == "Side" then
        local side = Vector3.new(-fromEnemy.Z, 0, fromEnemy.X)
        myRoot.Velocity = side * 100 * distMult
    else
        myRoot.Velocity = fromEnemy * 100 * distMult + Vector3.new(0, 20, 0)
    end
end

local function pvpAutoHaki()
    if not PvPBotSettings.AutoHaki then return end
    local myChar = Player.Character
    if not myChar then return end

    local ken = myChar:GetAttribute("Ken")
    if ken == 0 or ken == nil then
        if keypress then pcall(keypress, 0x4B) end -- 'K'
    end
    local buso = myChar:GetAttribute("Buso")
    if buso == 0 or buso == nil then
        if keypress then pcall(keypress, 0x4A) end -- 'J'
    end
end

local function pvpLoop()
    if not PvPBotSettings.Enabled then return end
    if not Camera then return end

    local now = tick()
    if now - PV.lastDodge < PvPBotSettings.DodgeCooldown then return end

    if now - PV.lastHakiCheck > 0.3 then
        PV.lastHakiCheck = now
        pcall(pvpAutoHaki)
    end

    local myChar = Player.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position

    local nearest, nearestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if pvpIsEnemy(plr) then
            local eChar = plr.Character
            if eChar then
                local eRoot = eChar:FindFirstChild("HumanoidRootPart")
                local eHum = eChar:FindFirstChildOfClass("Humanoid")
                if eRoot and eHum and eHum.Health > 0 then
                    local d = (eRoot.Position - myPos).Magnitude
                    if d < PvPBotSettings.DetectRange and d < nearestDist then
                        nearest = eChar
                        nearestDist = d
                    end
                end
            end
        end
    end

    if not nearest then return end
    local eRoot = nearest:FindFirstChild("HumanoidRootPart")
    if not eRoot then return end

    local isDanger1, dangerName1 = pvpScanEnemy(nearest)
    local isDanger2, dangerName2 = pvpScanWorkspace(eRoot.Position)

    if isDanger1 or isDanger2 then
        local name = dangerName1 or dangerName2 or "?"
        pvpDoDodge(eRoot.Position, PvPBotSettings.DodgeMode or "Dash")
        PV.lastDodge = now
        print("[PvPBot] Dodge from:", name)
    end
end

function _G.startPvPBot()
    if PV.conn then PV.conn:Disconnect(); PV.conn = nil end
    PV.lastDodge = 0
    PV.lastHakiCheck = 0
    PV.conn = RunService.Heartbeat:Connect(pvpLoop)
end

function _G.stopPvPBot()
    if PV.conn then PV.conn:Disconnect(); PV.conn = nil end
end

_G.createPvPBotCard = function(parent)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Size = UDim2.new(0, 225, 0, 280)
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

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 100, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "PvP Bot"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

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

    toggle.MouseButton1Click:Connect(function()
        PvPBotSettings.Enabled = not PvPBotSettings.Enabled
        toggle.Text = PvPBotSettings.Enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = PvPBotSettings.Enabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 80)
        if PvPBotSettings.Enabled then _G.startPvPBot() else _G.stopPvPBot() end
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = card

    local contentList = Instance.new("UIListLayout")
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.Padding = UDim.new(0, 6)
    contentList.Parent = content

    createDropdown(content, "Mode", {"BloxFruits", "Generic"}, PvPBotSettings.Mode, function(val) PvPBotSettings.Mode = val end)
    createDropdown(content, "Dodge Mode", {"Dash", "Jump", "Side"}, PvPBotSettings.DodgeMode, function(val) PvPBotSettings.DodgeMode = val end)
    createSlider(content, "Detect Range", 10, 100, PvPBotSettings.DetectRange, "m", function(val) PvPBotSettings.DetectRange = val end)
    createSlider(content, "Dodge Mult", 0.5, 3.0, PvPBotSettings.DodgeDistance, "", function(val) PvPBotSettings.DodgeDistance = val end)
    createSlider(content, "Dodge CD", 0.1, 2.0, PvPBotSettings.DodgeCooldown, "s", function(val) PvPBotSettings.DodgeCooldown = val end)
    createCheckbox(content, "Auto Haki (Ken+Buso)", PvPBotSettings.AutoHaki, function(val) PvPBotSettings.AutoHaki = val end)
end

_G.PvPBotSettings = PvPBotSettings
