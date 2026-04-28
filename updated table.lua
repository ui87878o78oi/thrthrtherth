--[[
    Main Cheat File: Muffin Hub
    Description: Core cheat logic for Muffin Hub
    Version: 2.0.0
--]]

-- ============================================
-- GAME DETECTION
-- ============================================
local DA_HOOD_PLACE_ID = 2788229376
local PLATFORMER_TESTING_PLACE_ID = 129596000683069
local YUU_HOOD_PLACE_ID = 98247054732585

local function isDaHoodGame()
    return game.PlaceId == DA_HOOD_PLACE_ID
end

local function isPlatformerTestingGame()
    return game.PlaceId == PLATFORMER_TESTING_PLACE_ID
end

local function isYuuHoodGame()
    return game.PlaceId == YUU_HOOD_PLACE_ID
end

local function isSupportedGame()
    return isDaHoodGame() or isPlatformerTestingGame() or isYuuHoodGame()
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local localPlayer = Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = nil

-- Store ESP objects globally so they persist
getgenv().MUFFIN_ESP_OBJECTS = getgenv().MUFFIN_ESP_OBJECTS or {}
getgenv().MUFFIN_HITBOX_OBJECTS = getgenv().MUFFIN_HITBOX_OBJECTS or {}
getgenv().MUFFIN_TRACER_OBJECTS = getgenv().MUFFIN_TRACER_OBJECTS or {}

local function updateHitbox(player)
    if getgenv().Enabled and player ~= LocalPlayer and player.Character then
        local targetPart = player.Character:FindFirstChild(getgenv().TargetPart)
        if targetPart and targetPart:IsA('BasePart') then
            targetPart.Size = getgenv().HitboxSize
            targetPart.CanCollide = false
            targetPart.Transparency = 1
        end
    end
end

local function applyToAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        updateHitbox(player)
    end
end

local function isStaffOrAdmin(player)
    if not player then
        return false
    end

    local name = tostring(player.Name or ''):lower()
    local displayName = tostring(player.DisplayName or ''):lower()
    local keywords = {
        'admin',
        'owner',
        'staff',
        'mod',
        'moderator',
        'administrator',
        'creator',
        'developer',
    }

    for _, keyword in ipairs(keywords) do
        if name:find(keyword, 1, true) or displayName:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

local function kickLocalPlayer(reason)
    if localPlayer and localPlayer.Kick then
        pcall(function()
            localPlayer:Kick(reason)
        end)
    end
end

local function checkExistingPlayersForStaff()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isStaffOrAdmin(player) then
            kickLocalPlayer('Staff or admin joined the server.')
            return
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if isStaffOrAdmin(player) then
        kickLocalPlayer('Staff or admin joined the server.')
    end

    -- Re-attach ESP when a player joins
    task.wait(0.5)
    if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
        updateEspGui(player)
        updateTracerLine(player)
        updateHitboxPart(player)
    end
    
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
            updateEspGui(player)
            updateTracerLine(player)
            updateHitboxPart(player)
        end
        updateHitbox(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if isStaffOrAdmin(player) then
        kickLocalPlayer('Staff or admin joined the server.')
        break
    end
    
    if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
        updateEspGui(player)
        updateTracerLine(player)
        updateHitboxPart(player)
    end
    updateHitbox(player)
    
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
            updateEspGui(player)
            updateTracerLine(player)
            updateHitboxPart(player)
        end
        updateHitbox(player)
    end)
end

checkExistingPlayersForStaff()

-- CRITICAL FIX: Recreate all ESP when local player respawns
localPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    -- Clear and recreate all ESP
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            destroyEspGui(player)
            destroyHitboxPart(player)
            destroyTracerLine(player)
        end
    end
    
    task.wait(0.5)
    
    -- Recreate ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
                updateEspGui(player)
                updateTracerLine(player)
                updateHitboxPart(player)
            end
            updateHitbox(player)
        end
    end
end)

local aimEnabled = false
local selectedAimbotTarget = nil
local silentEnabled = false
local triggerEnabled = false
local rapidFireEnabled = false
local flyEnabled = false
local flyBodyVelocity = nil
local mouseDown = false
local silentAimCache = { tick = 0, hit = nil, target = nil }
local lastHeavyUpdate = 0
local heavyUpdateInterval = 0
local walkSpeedEnabled = shared.muffin['Local Player']['Speed']['Enabled'] or false
local jumpPowerEnabled = shared.muffin['Local Player']['Jump']['Enabled'] or false

local function initializePlayer()
    if not localPlayer then
        localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
    end
    if localPlayer then
        mouse = localPlayer:GetMouse()
    end
end

local function initializeCamera()
    camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal('CurrentCamera'):Wait()
end

initializePlayer()
initializeCamera()

workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
    camera = workspace.CurrentCamera
end)

Players.PlayerAdded:Connect(function(player)
    if not localPlayer and player then
        localPlayer = player
        mouse = player:GetMouse()
    end
end)

local function getRootPart(character)
    if not character then return nil end
    return character:FindFirstChild('HumanoidRootPart')
        or character:FindFirstChild('UpperTorso')
        or character:FindFirstChild('LowerTorso')
        or character:FindFirstChild('Head')
end

local function isValidTarget(player)
    if not player or player == localPlayer then
        return false
    end
    local character = player.Character
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    return humanoid and humanoid.Health > 0
end

local function getTargetPart(character, hitPartName)
    if not character then return nil end
    local part = character:FindFirstChild(hitPartName)
    if part then
        return part
    end
    return getRootPart(character) or character:FindFirstChild('Head')
end

local function getAimbotTorsoPart(character)
    if not character then return nil end
    return character:FindFirstChild('HumanoidRootPart')
        or character:FindFirstChild('UpperTorso')
        or character:FindFirstChild('LowerTorso')
        or character:FindFirstChild('Torso')
end

local function getTargetFromMouse()
    if mouse and mouse.Target and mouse.Target:IsDescendantOf(workspace) then
        return mouse.Target
    end

    if not camera then
        return nil
    end

    local viewportSize = camera.ViewportSize
    local ray = camera:ViewportPointToRay(viewportSize.X / 2, viewportSize.Y / 2)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localPlayer and localPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, raycastParams)
    return result and result.Instance
end

local function getPlayerFromCharacter(character)
    if not character then
        return nil
    end
    return Players:GetPlayerFromCharacter(character)
end

local function getDistanceFromCenter(position)
    local viewportSize = camera.ViewportSize
    local screenPoint, onScreen = camera:WorldToViewportPoint(position)
    if not onScreen then
        return math.huge
    end
    return (Vector2.new(screenPoint.X, screenPoint.Y) - viewportSize / 2).Magnitude
end

local function getClosestTarget(config)
    local bestTarget = nil
    local bestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local character = player.Character
            local rootPart = getTargetPart(character, config['Hit Part'])
            if rootPart then
                local screenDistance = getDistanceFromCenter(rootPart.Position)
                local fovValue = config.FOV
                local validByFOV = screenDistance <= (fovValue or math.huge)

                local maxDistance = config.Distance or math.huge
                local worldDistance = (camera.CFrame.Position - rootPart.Position).Magnitude
                local validByDistance = worldDistance <= maxDistance

                if validByFOV and validByDistance and screenDistance < bestDistance then
                    bestDistance = screenDistance
                    bestTarget = character
                end
            end
        end
    end

    return bestTarget
end

local function getPredictedPosition(part, prediction)
    if not part then return nil end
    local velocity = part.Velocity or Vector3.new()
    prediction = prediction or {}
    return part.Position + Vector3.new(
        velocity.X * (prediction.X or 0),
        velocity.Y * (prediction.Y or 0),
        velocity.Z * (prediction.Z or 0)
    )
end

local function getEquippedTool()
    if not localPlayer then
        return nil
    end
    local character = localPlayer.Character
    if not character then
        return nil
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            return child
        end
    end
    return nil
end

local function isWeaponEquipped()
    return getEquippedTool() ~= nil
end

local function autoFire()
    if not mouseDown then
        return
    end
    local tool = getEquippedTool()
    if not tool then
        return
    end
    pcall(function()
        tool:Activate()
    end)
end

local currentCameraCFrame = nil
local targetCFrame = nil
local lerpProgress = 1

local function aimAt(part)
    if not part then
        return
    end
    
    local targetPosition = getPredictedPosition(part, shared.muffin['Aim Assist']['Prediction'])
    if not targetPosition then
        return
    end
    
    local newTargetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)
    local smoothness = shared.muffin['Aim Assist']['Smoothness'] or 0
    
    if smoothness > 0 and smoothness < 1 then
        if not targetCFrame or (targetCFrame ~= newTargetCFrame) then
            targetCFrame = newTargetCFrame
            currentCameraCFrame = camera.CFrame
            lerpProgress = 0
        end
        
        lerpProgress = math.min(lerpProgress + smoothness, 1)
        local newCFrame = currentCameraCFrame:Lerp(targetCFrame, lerpProgress)
        camera.CFrame = newCFrame
    else
        camera.CFrame = newTargetCFrame
        targetCFrame = nil
        lerpProgress = 1
    end
end

local function getSilentAimValues()
    local currentTick = math.floor(tick() * 60)
    if silentAimCache.tick == currentTick and silentAimCache.hit and silentAimCache.target then
        return silentAimCache.hit, silentAimCache.target
    end

    local targetCharacter = getClosestTarget(shared.muffin['Silent Aim'])
    if not targetCharacter then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local targetPart = getTargetPart(targetCharacter, shared.muffin['Silent Aim']['Hit Part'])
    if not targetPart then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local predictedPosition = getPredictedPosition(targetPart, shared.muffin['Silent Aim']['Prediction'])
    if not predictedPosition then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local hitCFrame = CFrame.new(predictedPosition)
    silentAimCache.tick = currentTick
    silentAimCache.hit = hitCFrame
    silentAimCache.target = targetPart
    return hitCFrame, targetPart
end

local function hookMouse()
    if type(getrawmetatable) ~= 'function' or type(setreadonly) ~= 'function' then
        return
    end
    if not mouse then
        return
    end

    local success, mt = pcall(getrawmetatable, mouse)
    if not success or not mt then
        return
    end

    local oldIndex = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, key)
        if self == mouse and shared.muffin['Silent Aim']['Enabled'] and silentEnabled then
            if key == 'Hit' then
                local hitCFrame = getSilentAimValues()
                if hitCFrame then
                    return hitCFrame
                end
            elseif key == 'Target' then
                local _, targetPart = getSilentAimValues()
                if targetPart then
                    return targetPart
                end
            end
        end
        return oldIndex(self, key)
    end)
    setreadonly(mt, true)
end

local function patchAmmoObject(obj, ammoValue)
    if not obj then
        return
    end

    local name = obj.Name and obj.Name:lower()
    if obj:IsA('NumberValue') or obj:IsA('IntValue') then
        if name and (name:find('ammo') or name:find('currentammo') or name:find('ammocount') or name:find('mag') or name:find('clip') or name:find('rounds') or name:find('bullets') or name:find('remaining') or name:find('magazine')) then
            obj.Value = ammoValue
        elseif name and (name:find('firerate') or name:find('fire_rate') or name:find('rate') or name:find('reload') or name:find('cooldown') or name:find('delay') or name:find('rpm')) then
            obj.Value = 0
        end
    elseif obj:IsA('Tool') then
        if obj:GetAttribute('Ammo') then
            obj:SetAttribute('Ammo', ammoValue)
        end
        if obj:GetAttribute('MaxAmmo') then
            obj:SetAttribute('MaxAmmo', ammoValue)
        end
        if obj:GetAttribute('CurrentAmmo') then
            obj:SetAttribute('CurrentAmmo', ammoValue)
        end
        if obj:GetAttribute('AmmoInClip') then
            obj:SetAttribute('AmmoInClip', ammoValue)
        end
        if obj:GetAttribute('ClipSize') then
            obj:SetAttribute('ClipSize', ammoValue)
        end
        if obj:GetAttribute('FireRate') then
            obj:SetAttribute('FireRate', 0)
        end
        if obj:GetAttribute('ReloadTime') then
            obj:SetAttribute('ReloadTime', 0)
        end
        if obj:GetAttribute('Cooldown') then
            obj:SetAttribute('Cooldown', 0)
        end
        if obj:GetAttribute('RateOfFire') then
            obj:SetAttribute('RateOfFire', 0)
        end
        if obj:GetAttribute('Delay') then
            obj:SetAttribute('Delay', 0)
        end
        if obj:GetAttribute('Automatic') ~= nil then
            obj:SetAttribute('Automatic', true)
        end
        if obj:GetAttribute('Reloading') ~= nil then
            obj:SetAttribute('Reloading', false)
        end
    end

    if obj.SetAttribute then
        local attributes = {
            Ammo = ammoValue,
            MaxAmmo = ammoValue,
            CurrentAmmo = ammoValue,
            AmmoInClip = ammoValue,
            ClipSize = ammoValue,
            ReserveAmmo = ammoValue,
            FireRate = 0,
            ReloadTime = 0,
            Cooldown = 0,
            RateOfFire = 0,
            Delay = 0,
            Automatic = true,
            Reloading = false,
            CanFire = true,
            CanReload = false,
            Loaded = true,
        }
        for attrName, attrValue in pairs(attributes) do
            if obj:GetAttribute(attrName) ~= nil then
                obj:SetAttribute(attrName, attrValue)
            end
        end
    end
end

local function isGunModWeapon(tool, weaponList)
    if not tool or type(weaponList) ~= 'table' then
        return false
    end
    local toolName = tostring(tool.Name or ''):lower()
    for _, name in ipairs(weaponList) do
        if type(name) == 'string' and name ~= '' then
            local pattern = name:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1')
            if toolName:find(pattern:lower()) then
                return true
            end
        end
    end
    return false
end

local function patchSpreadValues(tool, spreadAmount)
    if not tool then
        return
    end

    local normalizedAmount = tonumber(spreadAmount) or 0
    local function patchInstance(instance)
        if not instance then
            return
        end
        if instance:IsA('NumberValue') or instance:IsA('IntValue') then
            local name = instance.Name:lower()
            if name:find('spread') or name:find('accuracy') or name:find('deviation') then
                instance.Value = normalizedAmount
            end
        end
        if instance.SetAttribute then
            for _, attrName in ipairs({'Spread', 'SpreadAmount', 'SpreadRadius', 'Accuracy', 'Deviation'}) do
                if instance:GetAttribute(attrName) ~= nil then
                    instance:SetAttribute(attrName, normalizedAmount)
                end
            end
        end
    end

    patchInstance(tool)
    for _, child in ipairs(tool:GetDescendants()) do
        patchInstance(child)
    end
end

local function applyGunModifications()
    local mods = shared.muffin['Gun Modifications']
    if not mods then
        return
    end

    local tool = getEquippedTool()
    if not tool then
        return
    end

    if mods['Spread Modifier'] and mods['Spread Modifier']['Enabled'] then
        local weapons = mods['Spread Modifier']['Weapons']
        if isGunModWeapon(tool, weapons) then
            patchSpreadValues(tool, mods['Spread Modifier']['Spread Amount'])
        end
    end

    if mods['Double Tap'] and mods['Double Tap']['Enabled'] and mouseDown then
        local weapons = mods['Double Tap']['Weapons']
        if isGunModWeapon(tool, weapons) then
            pcall(function()
                tool:Activate()
            end)
        end
    end
end

local function patchRapidFireValues(tool)
    if not tool then
        return
    end

    local function patchInstance(instance)
        if not instance then
            return
        end

        if instance:IsA('NumberValue') or instance:IsA('IntValue') then
            local name = instance.Name:lower()
            if name:find('fire') or name:find('rate') or name:find('delay') or name:find('cooldown') or name:find('reload') or name:find('charge') or name:find('recovery') then
                instance.Value = 0
            end
        end

        if instance.SetAttribute then
            local attributes = {
                FireRate = 0,
                ReloadTime = 0,
                Cooldown = 0,
                RateOfFire = 0,
                Delay = 0,
                ChargeTime = 0,
                Recovery = 0,
                ReloadDelay = 0,
                Automatic = true,
                CanFire = true,
                CanReload = false,
                Loaded = true,
            }
            for attrName, attrValue in pairs(attributes) do
                if instance:GetAttribute(attrName) ~= nil then
                    instance:SetAttribute(attrName, attrValue)
                end
            end
        end
    end

    patchInstance(tool)
    for _, child in ipairs(tool:GetDescendants()) do
        patchInstance(child)
    end
end

local function applyRapidFire()
    if not shared.muffin['Gun Modifications']['Double Tap']['Enabled'] then
        return
    end

    local tool = getEquippedTool()
    if not tool then
        return
    end

    local weapons = shared.muffin['Gun Modifications']['Double Tap']['Weapons']
    if type(weapons) == 'table' and #weapons > 0 then
        if not isGunModWeapon(tool, weapons) then
            return
        end
    end

    patchRapidFireValues(tool)
end

local function applyMovementModifiers()
    local player = localPlayer
    if not player or not player.Character then
        return
    end

    local humanoid = player.Character:FindFirstChildOfClass('Humanoid')
    if not humanoid then
        return
    end

    local walkConfig = shared.muffin['Local Player']['Speed']
    if walkConfig and walkConfig['Enabled'] then
        local active = walkConfig['Keybind'] == '' or walkSpeedEnabled
        humanoid.WalkSpeed = active and (tonumber(walkConfig['Speed']) or 300) or 16
    else
        if humanoid.WalkSpeed ~= 16 then
            humanoid.WalkSpeed = 16
        end
    end

    local jumpConfig = shared.muffin['Local Player']['Jump']
    if jumpConfig and jumpConfig['Enabled'] then
        local active = jumpConfig['Keybind'] == '' or jumpPowerEnabled
        humanoid.JumpPower = active and (tonumber(jumpConfig['Power']) or 100) or 50
    else
        if humanoid.JumpPower ~= 50 then
            humanoid.JumpPower = 50
        end
    end
end

local function destroyFlyBodyVelocity()
    if flyBodyVelocity and flyBodyVelocity.Parent then
        flyBodyVelocity:Destroy()
    end
    flyBodyVelocity = nil
end

local function updateFlyBodyVelocity(rootPart)
    if not rootPart then
        return
    end

    if not flyBodyVelocity or not flyBodyVelocity.Parent then
        flyBodyVelocity = Instance.new('BodyVelocity')
        flyBodyVelocity.Name = 'MUFFIN_FlyBodyVelocity'
        flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyVelocity.P = 10000
        flyBodyVelocity.Parent = rootPart
    end

    local speed = tonumber(shared.muffin['Local Player']['Fly']['Speed']) or 20
    local moveVector = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVector = moveVector + camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVector = moveVector - camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVector = moveVector - camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVector = moveVector + camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveVector = moveVector + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
        moveVector = moveVector - Vector3.new(0, 1, 0)
    end

    if moveVector.Magnitude > 0 then
        flyBodyVelocity.Velocity = moveVector.Unit * speed
    else
        flyBodyVelocity.Velocity = Vector3.new(0, -2, 0)
    end
end

local function handleFly()
    if not shared.muffin['Local Player']['Fly'] or not shared.muffin['Local Player']['Fly']['Enabled'] then
        destroyFlyBodyVelocity()
        return
    end

    local player = localPlayer
    if not player or not player.Character then
        destroyFlyBodyVelocity()
        return
    end

    local rootPart = getRootPart(player.Character)
    if not rootPart then
        destroyFlyBodyVelocity()
        return
    end

    if flyEnabled then
        updateFlyBodyVelocity(rootPart)
    else
        destroyFlyBodyVelocity()
    end
end

local function applyGunSettings()
    if not isSupportedGame() then
        return
    end

    local settings = shared.muffin['Gun Settings']
    if not settings or not settings['Enabled'] then
        return
    end

    local tool = getEquippedTool()
    if not tool or not mouseDown then
        return
    end

    local targetCharacter = getClosestTarget(shared.muffin['Aim Assist'])
    if not targetCharacter then
        return
    end

    local targetPart = getTargetPart(targetCharacter, shared.muffin['Aim Assist']['Hit Part'])
    if not targetPart then
        return
    end

    local worldDistance = (camera.CFrame.Position - targetPart.Position).Magnitude
    local maxGunDistance = math.huge
    local ranges = settings['Distance Detections'] or {}
    maxGunDistance = ranges.Far or math.huge
    
    if worldDistance <= maxGunDistance then
        pcall(function()
            tool:Activate()
        end)
    end
end

local espGuis = {}
local hitboxParts = {}
local tracerLines = {}
local indicatorGui = nil
local indicatorFrame = nil
local indicatorList = nil
local drawingAvailable = type(Drawing) == 'table' and type(Drawing.new) == 'function'

local function createEspGui(player)
    if not player or not player.Character then
        return nil
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        return nil
    end

    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        -- Create PlayerGui if it doesn't exist
        playerGui = Instance.new('PlayerGui')
        playerGui.Parent = localPlayer
    end

    -- Check if ESP already exists for this player
    local existingGui = playerGui:FindFirstChild('MUFFIN_ESP_' .. player.Name)
    if existingGui then
        existingGui.Adornee = targetPart
        return existingGui
    end

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'MUFFIN_ESP_' .. player.Name
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 110, 0, 16)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Adornee = targetPart
    billboard.Parent = playerGui

    local label = Instance.new('TextLabel')
    label.Name = 'EspLabel'
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name
    label.TextColor3 = shared.muffin['ESP']['Color']
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextScaled = false
    label.TextSize = 12
    label.Font = Enum.Font.SourceSansBold
    label.Parent = billboard

    return billboard
end

local function createHitboxPart(player)
    if not player or not player.Character then
        return nil
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        return nil
    end

    -- Check if hitbox already exists
    local existingHitbox = player.Character:FindFirstChild('MUFFIN_Hitbox')
    if existingHitbox then
        existingHitbox.Size = getgenv().HitboxSize
        return existingHitbox
    end

    local part = Instance.new('Part')
    part.Name = 'MUFFIN_Hitbox'
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true
    part.CastShadow = false
    part.Transparency = 1
    part.Massless = true
    part.Size = getgenv().HitboxSize
    part.CFrame = targetPart.CFrame
    part.Parent = player.Character

    local weld = Instance.new('WeldConstraint')
    weld.Name = 'MUFFIN_HitboxWeld'
    weld.Part0 = part
    weld.Part1 = targetPart
    weld.Parent = part

    return part
end

local function destroyHitboxPart(player)
    local hitbox = hitboxParts[player]
    if hitbox and hitbox.Parent then
        hitbox:Destroy()
    end
    hitboxParts[player] = nil
end

local function updateHitboxPart(player)
    if not getgenv().Enabled then
        destroyHitboxPart(player)
        return
    end

    if not isValidTarget(player) or player == localPlayer or not player.Character then
        destroyHitboxPart(player)
        return
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        destroyHitboxPart(player)
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.muffin['ESP']['Distance'] and distance > shared.muffin['ESP']['Distance'] then
        destroyHitboxPart(player)
        return
    end

    local hitbox = hitboxParts[player]
    if not hitbox or not hitbox.Parent then
        hitbox = createHitboxPart(player)
        hitboxParts[player] = hitbox
    end
    if hitbox then
        hitbox.Size = getgenv().HitboxSize
        -- Update weld target if needed
        local weld = hitbox:FindFirstChild('MUFFIN_HitboxWeld')
        if weld and weld.Part1 ~= targetPart then
            weld.Part1 = targetPart
        end
    end
end

local function destroyEspGui(player)
    local gui = espGuis[player]
    if gui and gui.Parent then
        gui:Destroy()
    end
    espGuis[player] = nil
end

local function createTracerLine(player)
    if not drawingAvailable then
        return nil
    end

    local line = Drawing.new('Line')
    line.Visible = false
    line.Transparency = shared.muffin['ESP']['Tracer']['Transparency'] or 1
    line.Color = shared.muffin['ESP']['Tracer']['Color'] or Color3.new(1, 0.4, 0.4)
    line.Thickness = shared.muffin['ESP']['Tracer']['Thickness'] or 0.5
    return line
end

local function destroyTracerLine(player)
    local line = tracerLines[player]
    if line then
        if type(line.Remove) == 'function' then
            line:Remove()
        else
            line.Visible = false
        end
    end
    tracerLines[player] = nil
end

local function updateTracerLine(player)
    if not shared.muffin['ESP']['Tracer'] or not shared.muffin['ESP']['Tracer']['Enabled'] then
        destroyTracerLine(player)
        return
    end
    if not drawingAvailable or not isValidTarget(player) or player == localPlayer or not player.Character then
        destroyTracerLine(player)
        return
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        destroyTracerLine(player)
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.muffin['ESP']['Distance'] and distance > shared.muffin['ESP']['Distance'] then
        destroyTracerLine(player)
        return
    end

    local viewportSize = camera.ViewportSize
    local targetScreenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
    if shared.muffin['ESP']['Tracer']['Hide When Offscreen'] and not onScreen then
        destroyTracerLine(player)
        return
    end

    local tracer = tracerLines[player]
    if not tracer then
        tracer = createTracerLine(player)
        if not tracer then
            return
        end
        tracerLines[player] = tracer
    end

    tracer.Color = shared.muffin['ESP']['Tracer']['Color'] or tracer.Color
    tracer.Thickness = shared.muffin['ESP']['Tracer']['Thickness'] or 0.5
    tracer.Transparency = shared.muffin['ESP']['Tracer']['Transparency'] or tracer.Transparency
    local startPoint = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    if mouse and type(mouse.X) == 'number' and type(mouse.Y) == 'number' then
        startPoint = Vector2.new(mouse.X, mouse.Y)
    end
    tracer.From = startPoint
    tracer.To = Vector2.new(targetScreenPoint.X, targetScreenPoint.Y)
    tracer.Visible = true
end

local function refreshTracers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updateTracerLine(player)
        end
    end
end

local function isPlayerUnderMouse(player)
    if not mouse or not mouse.Target or not player or not player.Character then
        return false
    end
    return mouse.Target:IsDescendantOf(player.Character)
end

local function updateEspGui(player)
    if not shared.muffin['ESP'] or not shared.muffin['ESP']['Enabled'] then
        destroyEspGui(player)
        return
    end

    if not isValidTarget(player) or player == localPlayer then
        destroyEspGui(player)
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local targetPart = getTargetPart(character, 'Head') or getRootPart(character)
    if not targetPart then
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.muffin['ESP']['Distance'] and distance > shared.muffin['ESP']['Distance'] then
        destroyEspGui(player)
        return
    end

    local gui = espGuis[player]
    if not gui or not gui.Parent then
        gui = createEspGui(player)
        espGuis[player] = gui
    end
    if not gui then
        return
    end

    gui.Adornee = targetPart
    local label = gui:FindFirstChild('EspLabel')
    if label then
        label.Text = player.Name
        label.TextColor3 = isPlayerUnderMouse(player) and Color3.new(1, 0, 0) or (shared.muffin['ESP']['Color'] or Color3.new(1, 0, 0))
        label.TextTransparency = shared.muffin['ESP']['Transparency'] and 0.5 or 0
    end
end

local function refreshEsp()
    if not shared.muffin['ESP'] or not shared.muffin['ESP']['Enabled'] then
        for player in pairs(espGuis) do
            destroyEspGui(player)
        end
        return
    end
    
    -- Update ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updateEspGui(player)
        end
    end

    -- Update hitboxes
    if getgenv().Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                updateHitboxPart(player)
            end
        end
    end
end

-- INDICATOR GUI
local function createIndicatorGui()
    if indicatorGui and indicatorGui.Parent then
        return
    end
    
    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        playerGui = Instance.new('PlayerGui')
        playerGui.Parent = localPlayer
    end

    local existingGui = nil
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == 'MUFFIN_Indicator' and child:IsA('ScreenGui') then
            if not existingGui then
                existingGui = child
            else
                child:Destroy()
            end
        end
    end

    if existingGui then
        indicatorGui = existingGui
        indicatorFrame = indicatorGui:FindFirstChild('IndicatorFrame')
        indicatorList = indicatorGui:FindFirstChild('IndicatorList')
        if indicatorFrame and indicatorList then
            return
        end
    end

    indicatorGui = Instance.new('ScreenGui')
    indicatorGui.Name = 'MUFFIN_Indicator'
    indicatorGui.ResetOnSpawn = false
    indicatorGui.Parent = playerGui

    indicatorFrame = Instance.new('Frame')
    indicatorFrame.Name = 'IndicatorFrame'
    indicatorFrame.Size = UDim2.new(0, 180, 0, 0)
    indicatorFrame.Position = UDim2.new(0, 10, 0, 10)
    indicatorFrame.AutomaticSize = Enum.AutomaticSize.Y
    indicatorFrame.BackgroundTransparency = shared.muffin['Indicator']['Background Transparency'] or 0.5
    indicatorFrame.BackgroundColor3 = shared.muffin['Indicator']['Background Color'] or Color3.new(0, 0, 0)
    indicatorFrame.BorderSizePixel = 0
    indicatorFrame.ZIndex = 10
    indicatorFrame.ClipsDescendants = true
    indicatorFrame.Parent = indicatorGui

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = indicatorFrame

    local dragStart
    local dragStartPos
    local dragging = false

    indicatorFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            dragStartPos = indicatorFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging and dragStartPos then
            local delta = input.Position - dragStart
            indicatorFrame.Position = UDim2.new(
                dragStartPos.X.Scale,
                dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale,
                dragStartPos.Y.Offset + delta.Y
            )
        end
    end)

    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'TitleLabel'
    titleLabel.Size = UDim2.new(1, -10, 0, 22)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = shared.muffin['Indicator']['Title'] or 'MUFFIN'
    titleLabel.TextColor3 = shared.muffin['Indicator']['Title Color'] or Color3.new(1, 1, 1)
    titleLabel.TextScaled = false
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = indicatorFrame

    indicatorList = Instance.new('Frame')
    indicatorList.Name = 'IndicatorList'
    indicatorList.Size = UDim2.new(1, -10, 0, 0)
    indicatorList.Position = UDim2.new(0, 5, 0, 32)
    indicatorList.AutomaticSize = Enum.AutomaticSize.Y
    indicatorList.BackgroundTransparency = 1
    indicatorList.Parent = indicatorFrame

    local layout = Instance.new('UIListLayout')
    layout.Parent = indicatorList
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local function createIndicatorLine(text, color, order)
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.RichText = true
    label.TextScaled = false
    label.TextSize = 13
    label.Font = Enum.Font.SourceSansSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = indicatorList
    return label
end

local function updateIndicator()
    if not shared.muffin['Indicator'] or not shared.muffin['Indicator']['Enabled'] then
        if indicatorGui and indicatorGui.Parent then
            indicatorGui:Destroy()
            indicatorGui = nil
        end
        return
    end

    if not indicatorGui or not indicatorGui.Parent then
        createIndicatorGui()
    end
    if not indicatorGui or not indicatorGui.Parent or not indicatorList or not indicatorList.Parent then
        return
    end

    for _, child in ipairs(indicatorList:GetChildren()) do
        if child:IsA('TextLabel') then
            child:Destroy()
        end
    end

    local function formatFeature(name, isOn)
        local labels = {
            ['Aim Assist'] = 'Lock',
            ['Silent Aim'] = 'Assist',
            ['Trigger Bot'] = 'Auto Shoot',
            ['Tracer'] = 'Line',
            ['Fly'] = 'Levitate',
            ['Speed'] = 'Speed',
            ['Jump'] = 'Jump',
        }
        local displayName = labels[name] or name
        if isOn then
            return displayName .. ' (On)'
        else
            return displayName .. ' (Off)'
        end
    end

    local function getPlayerHealth()
        local player = localPlayer
        if not player or not player.Character then
            return 0, 0
        end

        local humanoid = player.Character:FindFirstChildOfClass('Humanoid')
        local currentHealth = 0
        local maxHealth = 0
        if humanoid then
            currentHealth = humanoid.Health or 0
            maxHealth = humanoid.MaxHealth or 0
        end

        return math.floor(currentHealth), math.floor(maxHealth)
    end

    local function getAimbotStatusText()
        if not (shared.muffin['Aim Assist']['Enabled'] and (aimEnabled or isWeaponEquipped())) then
            return nil
        end
        local targetCharacter = selectedAimbotTarget
        if targetCharacter then
            local targetPlayer = getPlayerFromCharacter(targetCharacter)
            if targetPlayer then
                return 'Targeting (' .. targetPlayer.Name .. ')'
            end
        end
        return formatFeature('Aim Assist', true)
    end

    local currentHealth, maxHealth = getPlayerHealth()
    if maxHealth <= 0 then
        maxHealth = 100
    end
    
    local healthColor = shared.muffin['Indicator']['Health Color'] or Color3.new(0, 1, 0)
    local maxHealthColor = shared.muffin['Indicator']['Max Health Color'] or Color3.new(0, 0, 1)
    local featureColor = shared.muffin['Indicator']['Feature Color'] or Color3.new(0.8, 0.8, 0.8)
    local textColor = shared.muffin['Indicator']['Text Color'] or Color3.new(1, 1, 1)
    
    local healthText = 'Health <font color="rgb(' .. math.floor(healthColor.R * 255) .. ',' .. math.floor(healthColor.G * 255) .. ',' .. math.floor(healthColor.B * 255) .. ')">' .. tostring(currentHealth) .. '</font>'
        .. '<font color="rgb(' .. math.floor(textColor.R * 255) .. ',' .. math.floor(textColor.G * 255) .. ',' .. math.floor(textColor.B * 255) .. ')">/</font>'
        .. '<font color="rgb(' .. math.floor(maxHealthColor.R * 255) .. ',' .. math.floor(maxHealthColor.G * 255) .. ',' .. math.floor(maxHealthColor.B * 255) .. ')">' .. tostring(maxHealth) .. '</font>'
    createIndicatorLine(healthText, textColor, 0)

    local triggerPlayerName = nil
    if shared.muffin['Trigger Bot']['Enabled'] and triggerEnabled then
        local targetCharacter = getClosestTarget(shared.muffin['Trigger Bot'])
        if targetCharacter then
            local targetPlayer = getPlayerFromCharacter(targetCharacter)
            if targetPlayer then
                triggerPlayerName = targetPlayer.Name
            end
        end
    end

    local features = {
        { name = getAimbotStatusText(), enabled = shared.muffin['Aim Assist']['Enabled'] and (aimEnabled or isWeaponEquipped()) },
        { name = formatFeature('Silent Aim', silentEnabled), enabled = shared.muffin['Silent Aim']['Enabled'] and silentEnabled },
        { name = triggerPlayerName and ('Auto Shoot (' .. triggerPlayerName .. ')') or formatFeature('Trigger Bot', triggerEnabled), enabled = shared.muffin['Trigger Bot']['Enabled'] and (triggerEnabled or isWeaponEquipped()) },
        { name = formatFeature('Tracer', shared.muffin['ESP']['Tracer']['Enabled']), enabled = shared.muffin['ESP']['Tracer'] and shared.muffin['ESP']['Tracer']['Enabled'] },
        { name = formatFeature('Fly', flyEnabled), enabled = shared.muffin['Local Player']['Fly'] and shared.muffin['Local Player']['Fly']['Enabled'] and flyEnabled },
        { name = formatFeature('Speed', walkSpeedEnabled), enabled = shared.muffin['Local Player']['Speed']['Enabled'] and walkSpeedEnabled },
        { name = formatFeature('Jump', jumpPowerEnabled), enabled = shared.muffin['Local Player']['Jump']['Enabled'] and jumpPowerEnabled },
    }

    local order = 1
    local activeCount = 0
    for _, feature in ipairs(features) do
        if feature.enabled and feature.name then
            createIndicatorLine(feature.name, featureColor, order)
            order = order + 1
            activeCount = activeCount + 1
        end
    end

    if activeCount == 0 then
        createIndicatorLine('No active features', featureColor, order)
    end
end

Players.PlayerRemoving:Connect(function(player)
    destroyEspGui(player)
    destroyHitboxPart(player)
    destroyTracerLine(player)
    if player == localPlayer then
        if indicatorGui and indicatorGui.Parent then
            indicatorGui:Destroy()
            indicatorGui = nil
        end
    end
end)

local function normalizeKeyName(input)
    if not input or not input.KeyCode then
        return ''
    end
    return tostring(input.KeyCode.Name):upper()
end

local function normalizeKeyBind(keybind)
    if not keybind then
        return ''
    end
    local keyName = tostring(keybind):upper()
    if keyName == "'" or keyName == '"' then
        return 'QUOTE'
    end
    if keyName == 'APOSTROPHE' then
        return 'QUOTE'
    end
    return keyName
end

local function updateKeyState(input, isDown)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyName = normalizeKeyName(input)
    if shared.muffin['Aim Assist']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.muffin['Aim Assist']['Keybind']) then
        aimEnabled = isDown
    end
    if shared.muffin['Silent Aim']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.muffin['Silent Aim']['Keybind']) then
        silentEnabled = isDown
    end
    if shared.muffin['Trigger Bot']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.muffin['Trigger Bot']['Keybind']) then
        triggerEnabled = isDown
    end
end

local function handleToggleInput(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyName = normalizeKeyName(input)
    if shared.muffin['Aim Assist']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.muffin['Aim Assist']['Keybind']) then
        if aimEnabled then
            aimEnabled = false
            selectedAimbotTarget = nil
        else
            selectedAimbotTarget = getClosestTarget(shared.muffin['Aim Assist'])
            aimEnabled = selectedAimbotTarget ~= nil
        end
    end
    if shared.muffin['Silent Aim']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.muffin['Silent Aim']['Keybind']) then
        silentEnabled = not silentEnabled
    end
    if shared.muffin['Trigger Bot']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.muffin['Trigger Bot']['Keybind']) then
        triggerEnabled = not triggerEnabled
    end

    if shared.muffin['Local Player']['Fly'] and shared.muffin['Local Player']['Fly']['Enabled'] and shared.muffin['Local Player']['Fly']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.muffin['Local Player']['Fly']['Keybind']) then
        flyEnabled = not flyEnabled
    end

    if shared.muffin['Local Player']['Speed'] and shared.muffin['Local Player']['Speed']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.muffin['Local Player']['Speed']['Keybind']) then
        walkSpeedEnabled = not walkSpeedEnabled
    end
    if shared.muffin['Local Player']['Jump'] and shared.muffin['Local Player']['Jump']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.muffin['Local Player']['Jump']['Keybind']) then
        jumpPowerEnabled = not jumpPowerEnabled
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end

    handleToggleInput(input)
    updateKeyState(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
    updateKeyState(input, false)
end)

hookMouse()

-- Aggressive ESP refresh (every 2 seconds to ensure ESP always shows)
task.spawn(function()
    while task.wait(2) do
        if shared.muffin['ESP'] and shared.muffin['ESP']['Enabled'] then
            pcall(function()
                refreshEsp()
                refreshTracers()
            end)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastHeavyUpdate >= heavyUpdateInterval then
        applyGunModifications()
        applyRapidFire()
    end

    if getgenv().Enabled then
        applyToAllPlayers()
    end

    refreshTracers()
    updateIndicator()
    applyGunSettings()
    applyMovementModifiers()
    handleFly()
    autoFire()

    if shared.muffin['Trigger Bot']['Enabled'] and triggerEnabled then
        local targetCharacter = getClosestTarget(shared.muffin['Trigger Bot'])
        if targetCharacter then
            local tool = getEquippedTool()
            if tool then
                pcall(function()
                    tool:Activate()
                end)
            end
        end
    end

    if shared.muffin['Aim Assist']['Enabled'] and aimEnabled then
        local targetCharacter = selectedAimbotTarget
        if not targetCharacter or not isValidTarget(getPlayerFromCharacter(targetCharacter) or nil) then
            aimEnabled = false
            selectedAimbotTarget = nil
        else
            local targetPart = getAimbotTorsoPart(targetCharacter)
            if targetPart then
                aimAt(targetPart)
            else
                aimEnabled = false
                selectedAimbotTarget = nil
            end
        end
    end
end)

-- ============================================
-- INITIALIZE
-- ============================================
task.wait(1)
refreshEsp()
print("Muffin Hub loaded successfully!")