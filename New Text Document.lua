-- CHEAT ENGINE
-- This is the actual cheat code - DO NOT EDIT unless you know what you're doing
-- Edit the config table in the loader script instead

-- Wait for config to be passed
local Config = _G.CheatConfig or Config or {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Variables
local flying = false
local noclipActive = false
local bodyVelocity = nil
local autoClicking = false
local currentTarget = nil

--[[ INITIALIZATION ]]

-- Wait for character
local function getCharacter()
    if LocalPlayer.Character and LocalPlayer.Character.Parent then
        return LocalPlayer.Character
    else
        LocalPlayer.CharacterAdded:Wait()
        return LocalPlayer.Character
    end
end

--[[ GOD MODE ]]
if Config.Player.GodMode then
    LocalPlayer.CharacterAdded:Connect(function(character)
        wait(0.5)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        humanoid.BreakJointsOnDeath = false
        
        -- Anti-stun
        humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health <= 0 then
                wait(0.1)
                humanoid.Health = humanoid.MaxHealth
            end
        end)
    end)
    
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        end
    end
end

--[[ INFINITE JUMP ]]
if Config.Player.InfiniteJump then
    local infiniteJumpActive = true
    UserInputService.JumpRequest:Connect(function()
        if infiniteJumpActive and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                wait(0.1)
                humanoid:ChangeState(Enum.HumanoidStateType.Landing)
            end
        end
    end)
end

--[[ FLY MODE ]]
if Config.Player.FlyMode then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F then
            flying = not flying
            local character = getCharacter()
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            
            if flying then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = true
                end
                
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                bodyVelocity.Parent = humanoidRootPart
                
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Fly Mode",
                    Text = "Fly mode ENABLED - Use WASD + Space/Shift",
                    Duration = 2
                })
            else
                if bodyVelocity then
                    bodyVelocity:Destroy()
                    bodyVelocity = nil
                end
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = false
                end
                
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Fly Mode",
                    Text = "Fly mode DISABLED",
                    Duration = 2
                })
            end
        end
    end)
    
    -- Fly movement
    RunService.RenderStepped:Connect(function()
        if flying and bodyVelocity then
            local moveDirection = Vector3.new()
            local camera = workspace.CurrentCamera
            local forwardVector = camera.CFrame.LookVector
            local rightVector = camera.CFrame.RightVector
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + Vector3.new(forwardVector.X, 0, forwardVector.Z)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - Vector3.new(forwardVector.X, 0, forwardVector.Z)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - rightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + rightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end
            
            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.Unit
            end
            
            bodyVelocity.Velocity = moveDirection * Config.Player.Speed
        end
    end)
end

--[[ NO CLIP ]]
if Config.Player.NoClip then
    noclipActive = true
    RunService.Stepped:Connect(function()
        if noclipActive and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

--[[ SPEED HACK ]]
if Config.Player.Speed > 16 then
    LocalPlayer.CharacterAdded:Connect(function(character)
        wait(0.5)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.WalkSpeed = Config.Player.Speed
    end)
    
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.Player.Speed
        end
    end
end

--[[ ESP / WALLHACK ]]
if Config.Visual.ESP then
    local function createESP(player)
        if player == LocalPlayer then return end
        
        player.CharacterAdded:Connect(function(character)
            wait(0.5)
            if character and character:FindFirstChild("HumanoidRootPart") then
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
                highlight.FillTransparency = 0.4
                highlight.OutlineTransparency = 0
                highlight.Parent = character
                
                -- Name tag
                if Config.Visual.NameTags then
                    local billboard = Instance.new("BillboardGui")
                    local nameLabel = Instance.new("TextLabel")
                    
                    billboard.Size = UDim2.new(0, 200, 0, 50)
                    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Parent = character
                    
                    nameLabel.Size = UDim2.new(1, 0, 1, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.TextStrokeTransparency = 0
                    nameLabel.Text = player.Name
                    nameLabel.Parent = billboard
                end
            end
        end)
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        createESP(player)
    end
    
    Players.PlayerAdded:Connect(createESP)
end

--[[ AUTO CLICKER ]]
if Config.Combat.AutoClick then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.V then
            autoClicking = not autoClicking
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Auto Clicker",
                Text = autoClicking and "ON - Clicking every " .. Config.Combat.ClickDelay .. "s" or "OFF",
                Duration = 2
            })
            
            while autoClicking do
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    local args = {
                        [1] = Mouse,
                        [2] = {Target = Mouse.Target}
                    }
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    wait(0.05)
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end
                wait(Config.Combat.ClickDelay)
            end
        end
    end)
end

--[[ TRIGGERBOT ]]
if Config.Combat.TriggerBot then
    RunService.RenderStepped:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local mouseTarget = Mouse.Target
            if mouseTarget and mouseTarget.Parent and mouseTarget.Parent:FindFirstChild("Humanoid") then
                local targetPlayer = Players:GetPlayerFromCharacter(mouseTarget.Parent)
                if targetPlayer and targetPlayer ~= LocalPlayer then
                    -- Auto shoot
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    wait(Config.Combat.TriggerDelay)
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end
            end
        end
    end)
end

--[[ AIMBOT (Silent) ]]
if Config.Aimbot.Enabled then
    local function getClosestPlayer()
        local closestDistance = Config.Aimbot.FOV
        local closestPlayer = nil
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local screenPoint, onScreen = workspace.CurrentCamera:WorldToScreenPoint(player.Character.HumanoidRootPart.Position)
                if onScreen then
                    local distance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
        return closestPlayer
    end
    
    RunService.RenderStepped:Connect(function()
        if Config.Aimbot.Enabled then
            local target = getClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local targetPos = target.Character.HumanoidRootPart.Position
                if Config.Aimbot.PredictMovement and target.Character:FindFirstChild("Humanoid") then
                    local velocity = target.Character.HumanoidRootPart.Velocity
                    targetPos = targetPos + velocity * 0.1
                end
                
                local screenPoint = workspace.CurrentCamera:WorldToScreenPoint(targetPos)
                if screenPoint.Z > 0 then
                    mousemoveabs(screenPoint.X, screenPoint.Y)
                end
            end
        end
    end)
end

--[[ TELEPORT ]]
if Config.World.TeleportDistance > 0 then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.T then
            local targetPos = Mouse.Hit.p
            local character = getCharacter()
            local hrp = character:FindFirstChild("HumanoidRootPart")
            
            if hrp and (targetPos - hrp.Position).Magnitude <= Config.World.TeleportDistance then
                hrp.CFrame = CFrame.new(targetPos)
                
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Teleport",
                    Text = "Teleported to target location",
                    Duration = 1
                })
            end
        end
    end)
end

--[[ ANTI-AFK ]]
if Config.World.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

--[[ REACH ]]
if Config.Combat.Reach > 5 then
    -- Hook melee hit distance
    local oldHit
    oldHit = hookfunction(getrenv()._G.meleeHitFunction or function() end, function(...)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local args = {...}
            -- Modify distance check here based on game
        end
        return oldHit(...)
    end)
end

--[[ AUTO FARM ]]
if Config.Misc.AutoFarm then
    local function autoFarm()
        while Config.Misc.AutoFarm do
            -- Generic auto farm - looks for collectables
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Tool") or obj:IsA("Model") and obj:FindFirstChild("TouchInterest") then
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = obj.CFrame
                        wait(0.5)
                    end
                end
            end
            wait(1)
        end
    end
    
    if Config.Misc.AutoFarm then
        coroutine.wrap(autoFarm)()
    end
end

--[[ AUTO COLLECT ]]
if Config.Misc.AutoCollect then
    LocalPlayer.CharacterAdded:Connect(function(character)
        wait(1)
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Tool") and obj.Parent ~= character then
                    local distance = (obj.Position - hrp.Position).Magnitude
                    if distance < 20 then
                        fireproximityprompt(obj:FindFirstChildWhichIsA("ProximityPrompt"))
                    end
                end
            end
        end
    end)
end

--[[ CHAT SPAM ]]
if Config.Misc.ChatSpam then
    coroutine.wrap(function()
        while Config.Misc.ChatSpam do
            wait(5)
            game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(Config.Misc.SpamMessage, "All")
        end
    end)()
end

--[[ NAME SPOOFER ]]
if Config.Misc.SpoofName then
    -- Changes display name locally
    LocalPlayer.DisplayName = Config.Misc.FakeName
    LocalPlayer.Name = Config.Misc.FakeName
end

--[[ SERVER HOP ]]
if Config.World.ServerHop then
    local function hopServer()
        local servers = {}
        for _, v in pairs(game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"))) do
            if type(v) == "table" and v.playing ~= nil and v.id ~= game.JobId then
                servers[#servers + 1] = v.id
            end
        end
        if #servers > 0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        end
    end
    
    -- Bind to key (Press H to hop)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.H then
            hopServer()
        end
    end)
end

--[[ GUI NOTIFICATION ]]
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Cheat Loaded",
    Text = "All features loaded! Check config for settings.\nV=AutoClick | F=Fly | T=Teleport | H=ServerHop",
    Duration = 5
})

-- Create simple menu GUI
local screenGui = Instance.new("ScreenGui")
local mainFrame = Instance.new("Frame")
local titleLabel = Instance.new("TextLabel")
local statusLabel = Instance.new("TextLabel")

screenGui.Name = "CheatMenu"
screenGui.Parent = game:GetService("CoreGui")

mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleLabel.Text = "Cheat Menu"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.Parent = mainFrame

statusLabel.Size = UDim2.new(1, 0, 0, 40)
statusLabel.Position = UDim2.new(0, 0, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: ACTIVE\nPress F1 to toggle menu"
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

-- Toggle menu with F1
local menuVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        menuVisible = not menuVisible
        screenGui.Enabled = menuVisible
    end
end)

print("Cheat Engine Loaded Successfully!")