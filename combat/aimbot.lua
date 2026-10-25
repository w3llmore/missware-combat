-- ========== AIMBOT SETTINGS ==========
local AimbotSettings = {
    Enabled = false,
    AimPart = "Head",
    AimMode = "Classic",
    FOV = 10,
    Smoothness = 0.3,
    SilentAim = false,
    AutoFire = false,
    AutoStop = false,
    MaxDistance = 400,
    AutoFireDelay = 0.05,
    BindKey = nil,
}

-- ========== AIMBOT LOGIC ==========
local fovCircle = nil
local aimbotConnection = nil
local lastFireTime = 0
local currentTarget = nil
local currentTargetPlayer = nil

local function isPlayerAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function isTeammate(plr)
    if not plr or not Player then return false end
    if plr.Team and Player.Team and plr.Team == Player.Team then
        return true
    end
    return false
end

local function isVisible(targetPart)
    if not targetPart then return true end
    if not Camera then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local distance = (origin - targetPart.Position).Magnitude
    local ray = Ray.new(origin, direction * distance)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {Player.Character, targetPart})
    return not hit or hit == targetPart or hit:IsDescendantOf(targetPart.Parent)
end

local function getTargetPart(char)
    if not char then return nil end
    local aimPart = AimbotSettings.AimPart or "Head"
    if aimPart == "Head" then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestEnemy()
    if not AimbotSettings.Enabled then return nil end
    if not Camera then return nil end

    local cp = Camera.CFrame.Position
    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    local best, bestScore, bestPlayer = nil, math.huge, nil

    local maxFov = AimbotSettings.SilentAim and math.huge
        or (math.tan(math.rad(AimbotSettings.FOV / 2)) / math.tan(math.rad(Camera.FieldOfView / 2))) * cx
    local checkTeam = (AimbotSettings.AimMode == "CounterBlox")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == Player then continue end
        if not isPlayerAlive(plr) then continue end
        if checkTeam and isTeammate(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local part = getTargetPart(char)
        if not part or not isVisible(part) then continue end

        local pos = part.Position
        local dist = (pos - cp).Magnitude
        if dist > AimbotSettings.MaxDistance then continue end

        local screenPos = Camera:WorldToViewportPoint(pos)
        if not screenPos then continue end

        local dx, dy = screenPos.X - cx, screenPos.Y - cy
        local fovDist = math.sqrt(dx * dx + dy * dy)

        if fovDist <= maxFov and fovDist < bestScore then
            bestScore, best, bestPlayer = fovDist, part, plr
        end
    end

    if best then currentTargetPlayer = bestPlayer end
    return best
end

local function applyAutoStop()
    if not AimbotSettings.AutoStop then return end
    if not AimbotSettings.Enabled then return end
    if not currentTarget then return end

    local char = Player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local humanoid = char:FindFirstChild("Humanoid")

    root.Velocity = Vector3.new(0, root.Velocity.Y, 0)

    if humanoid then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Running then
            humanoid:MoveTo(root.Position)
        end
    end
end

function createFovCircle()
    if not Drawing then return end
    if not Camera then return end

    if fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end

    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible = false
        fovCircle.Radius = 100
        fovCircle.Thickness = 2
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.NumSides = 60
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

function updateFovCircle()
    if not Drawing or not fovCircle then return end
    if not Camera then return end

    pcall(function()
        local vs = Camera.ViewportSize
        local cx = vs.X / 2
        local cy = vs.Y / 2
        fovCircle.Position = Vector2.new(cx, cy)

        if AimbotSettings.SilentAim then
            fovCircle.Visible = false
            return
        end

        local aimRad = math.rad(AimbotSettings.FOV) / 2
        local camRad = math.rad(Camera.FieldOfView) / 2
        local r = (math.tan(aimRad) / math.tan(camRad)) * cx
        fovCircle.Radius = math.clamp(r, 5, cx - 10)
        fovCircle.Visible = AimbotSettings.Enabled
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
    end)
end

local function mainLoop()
    if not AimbotSettings.Enabled then
        if fovCircle then
            pcall(function() fovCircle.Visible = false end)
        end
        return
    end

    if not Camera then return end

    updateFovCircle()

    local target = getClosestEnemy()
    if target then
        currentTarget = target
    else
        currentTarget = nil
        currentTargetPlayer = nil
    end

    applyAutoStop()

    if currentTarget and AimbotSettings.Enabled then
        pcall(function()
            local targetPos = currentTarget.Position
            local camPos = Camera.CFrame.Position

            if AimbotSettings.SilentAim then
                Camera.CFrame = CFrame.lookAt(camPos, targetPos)
            else
                local targetCF = CFrame.lookAt(camPos, targetPos)
                local smooth = AimbotSettings.Smoothness or 0.5
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, smooth + 0.2)
            end
        end)
    end

    -- AUTOFIRE
    if not AimbotSettings.AutoFire or not currentTarget or not currentTargetPlayer then return end

    local plr = currentTargetPlayer
    if plr == Player or not isPlayerAlive(plr) then
        currentTarget = nil
        currentTargetPlayer = nil
        return
    end

    if AimbotSettings.AimMode == "CounterBlox" and isTeammate(plr) then
        currentTarget = nil
        currentTargetPlayer = nil
        return
    end

    if not isVisible(currentTarget) then return end

    local screenPos = Camera:WorldToViewportPoint(currentTarget.Position)
    if not screenPos then return end

    local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    if math.abs(screenPos.X - cx) > 30 or math.abs(screenPos.Y - cy) > 30 then return end

    if tick() - lastFireTime < AimbotSettings.AutoFireDelay then return end

    if mouse1press then pcall(mouse1press) end
    task.wait(0.01)
    if mouse1release then pcall(mouse1release) end
    lastFireTime = tick()
end

function startAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end

    currentTarget = nil
    currentTargetPlayer = nil
    lastFireTime = 0

    createFovCircle()

    aimbotConnection = RunService.RenderStepped:Connect(mainLoop)
end

function stopAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end

    if fovCircle then
        pcall(function() fovCircle.Visible = false end)
    end

    currentTarget = nil
    currentTargetPlayer = nil
    lastFireTime = 0
end
