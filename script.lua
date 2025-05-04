repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

-- Configuration
local ESP_COLOR = Color3.fromRGB(255, 50, 50)
local ESP_TEXT_SIZE = 14
local ESP_MAX_DISTANCE = 1000  -- Max distance to show ESP
local AIMLOCK_KEY = Enum.UserInputType.MouseButton2
local AIMLOCK_FOV = 100  -- Field of view for aimlock
local SMOOTHNESS = 0.5  -- Aimlock smoothness (lower = smoother)

-- Better ESP function with distance and health
local function createESP(player)
    if not player.Character then return end
    
    local character = player.Character
    if not character:FindFirstChild("Head") then return end
    
    -- Wait for humanoid
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Create container
    local container = Instance.new("BillboardGui")
    container.Name = "ESP_"..player.Name
    container.AlwaysOnTop = true
    container.Size = UDim2.new(0, 200, 0, 50)
    container.StudsOffset = Vector3.new(0, 2.5, 0)
    container.Adornee = character.Head
    container.Parent = character.Head
    
    -- Player name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = ESP_COLOR
    nameLabel.TextSize = ESP_TEXT_SIZE
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0.7
    nameLabel.Parent = container
    
    -- Distance/health label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLabel.TextSize = ESP_TEXT_SIZE - 2
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextStrokeTransparency = 0.7
    infoLabel.Parent = container
    
    -- Health bar background
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBG"
    healthBarBg.Size = UDim2.new(1, 0, 0.1, 0)
    healthBarBg.Position = UDim2.new(0, 0, 0.9, 0)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = container
    
    -- Health bar
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBg
    
    -- Update function for ESP
    local function updateESP()
        if not character or not character:FindFirstChild("Head") then return end
        
        -- Calculate distance
        local distance = (localPlayer.Character and localPlayer.Character:FindFirstChild("Head")) 
            and (character.Head.Position - localPlayer.Character.Head.Position).Magnitude 
            or 0
            
        -- Only show if within max distance
        container.Enabled = distance <= ESP_MAX_DISTANCE
        
        -- Update info label
        infoLabel.Text = string.format("%.0f studs | %d/%d HP", distance, humanoid.Health, humanoid.MaxHealth)
        
        -- Update health bar
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.new(1 - healthPercent, healthPercent, 0)
    end
    
    -- Connect update events
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not character or not character.Parent then
            conn:Disconnect()
            return
        end
        updateESP()
    end)
end

-- Remove ESP
local function removeESP(player)
    if player.Character then
        for _, part in pairs(player.Character:GetDescendants()) do
            if part.Name == "ESP_"..player.Name then
                part:Destroy()
            end
        end
    end
end

-- Initialize ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(1) -- Wait for character to fully load
            createESP(player)
        end)
        
        if player.Character then
            createESP(player)
        end
    end
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        createESP(player)
    end)
end)

-- Handle leaving players
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- Improved Aimlock
local aiming = false
local moveMouse = mousemoverel or function(dx, dy) 
    mouse.Move(mouse.X + dx, mouse.Y + dy) 
end

local function getClosestTarget()
    local closest = nil
    local shortestDistance = AIMLOCK_FOV
    local localHead = localPlayer.Character and localPlayer.Character:FindFirstChild("Head")
    
    if not localHead then return nil end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closest = head
                    end
                end
            end
        end
    end
    
    return closest
end

-- Smooth aimlock function
local function smoothAim(targetPos, currentPos, delta)
    return currentPos + (targetPos - currentPos) * (1 - SMOOTHNESS) * delta * 60
end

-- Main aimlock loop
RunService.RenderStepped:Connect(function(delta)
    if aiming then
        local targetHead = getClosestTarget()
        if targetHead then
            local targetPos = Workspace.CurrentCamera:WorldToViewportPoint(targetHead.Position)
            local mousePos = UserInputService:GetMouseLocation()
            
            local currentPos = Vector2.new(mousePos.X, mousePos.Y)
            local targetPos2D = Vector2.new(targetPos.X, targetPos.Y)
            
            -- Smooth aiming
            local newPos = smoothAim(targetPos2D, currentPos, delta)
            local deltaPos = newPos - currentPos
            
            moveMouse(deltaPos.X, deltaPos.Y)
        end
    end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == AIMLOCK_KEY then
        aiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == AIMLOCK_KEY then
        aiming = false
    end
end)

-- Auto remove ESP when character dies
localPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid").Died:Connect(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                removeESP(player)
            end
        end
    end)
end)

print("Rival ESP & Aimlock loaded successfully!")
