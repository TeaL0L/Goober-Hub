local Player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local CurrentCamera = workspace.CurrentCamera
local StarterPlayer = game:GetService("StarterPlayer")

local SESSION_KEY = "_GnomesHubSession"
_G[SESSION_KEY] = (_G[SESSION_KEY] or 0) + 1
local SESSION = _G[SESSION_KEY]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Goober Hub",
   LoadingTitle = "Goober Hub",
   LoadingSubtitle = "by Goober Hub",
   ShowText = "Goober Hub",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.K,
   ConfigurationSaving = {
      Enabled = true,
      FileName = "GooberHub"
   },
   KeySystem = false
})

local MovementTab = Window:CreateTab("Movement", "zap")
local PlayerTab = Window:CreateTab("Player", "user")
local ESPTab = Window:CreateTab("ESP", "eye")
local MiscTab = Window:CreateTab("Misc", "package")

local MAT_COLORS = {
   Clonk = Color3.fromRGB(255, 180, 40),
   Fraggles = Color3.fromRGB(70, 200, 90),
   Plasto = Color3.fromRGB(50, 150, 255),
   Weapon = Color3.fromRGB(220, 50, 50),
   Trap = Color3.fromRGB(180, 100, 30)
}

local ITEM_OVERRIDES = {
   Gun = { label = nil, mat = "Weapon" },
   Knife1 = { label = "Knife", mat = "Weapon" },
   Knife2 = { label = "Knife", mat = "Weapon" },
   Knife3 = { label = "Knife", mat = "Weapon" },
   Spoon1 = { label = "Spoon", mat = nil },
   Spoon2 = { label = "Spoon", mat = nil },
   Spoon3 = { label = "Spoon", mat = nil },
   PaperPlane = { label = "Paper Plane", mat = nil },
   MouseTrap = { label = "Mouse Trap", mat = "Trap" },
   PlungerMODEL = { label = "Plunger", mat = "Plasto" },
   Tnt = { label = "TNT", mat = "Weapon" }
}

local flags = {
   ws = 32,
   wsE = false,
   fly = false,
   flySpd = 25,
   noclip = false,
   fb = false,
}

local function getSprintSpeed()
   local base = StarterPlayer.CharacterWalkSpeed + 4
   local mult = 1
   local ok1, v = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, 1862894357)
   if ok1 and v then mult = mult * 1.1 end
   local ok2, v = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, 1875417216)
   if ok2 and v then mult = mult * 1.2 end
   return base * mult
end

local sprintSpeed = getSprintSpeed()

local infiniteStamina = false
local mouseUnlock = false
local mouseUnlockConn = nil
local postSimConn = nil

local function applyMouseUnlock(enabled)
   if enabled then
      Player.CameraMode = Enum.CameraMode.Classic
      UserInputService.MouseIconEnabled = true
      UserInputService.MouseBehavior = Enum.MouseBehavior.Default
   else
      Player.CameraMode = Enum.CameraMode.LockFirstPerson
      UserInputService.MouseIconEnabled = false
      UserInputService.MouseBehavior = Enum.MouseBehavior.Default
   end
end

local function toggleMouseUnlock()
   mouseUnlock = not mouseUnlock
   applyMouseUnlock(mouseUnlock)
   if mouseUnlockConn then mouseUnlockConn:Disconnect(); mouseUnlockConn = nil end
   if postSimConn then postSimConn:Disconnect(); postSimConn = nil end
   if mouseUnlock then
      mouseUnlockConn = Player:GetPropertyChangedSignal("CameraMode"):Connect(function()
         if _G[SESSION_KEY] ~= SESSION then return end
         if mouseUnlock and Player.CameraMode ~= Enum.CameraMode.Classic then
            Player.CameraMode = Enum.CameraMode.Classic
         end
      end)
      postSimConn = RunService.PostSimulation:Connect(function()
         if _G[SESSION_KEY] ~= SESSION then return end
         if mouseUnlock and Player.CameraMode ~= Enum.CameraMode.Classic then
            Player.CameraMode = Enum.CameraMode.Classic
         end
      end)
   end
end

local preRenderConn = nil
local staminaCharConn = nil
local animTrack = nil

local function stopStaminaTrack()
   if not animTrack then return end
   pcall(function() animTrack:Stop() end)
   animTrack = nil
end

local function loadStaminaTrack(animator, runAnimObj)
   stopStaminaTrack()
   if not animator or not runAnimObj then return end
   local ok, track = pcall(function() return animator:LoadAnimation(runAnimObj) end)
   if ok and track then
      track.Priority = Enum.AnimationPriority.Movement
      pcall(function() track:Play() end)
      animTrack = track
   end
end

local function cleanupStamina()
   if preRenderConn then preRenderConn:Disconnect(); preRenderConn = nil end
   if staminaCharConn then staminaCharConn:Disconnect(); staminaCharConn = nil end
   stopStaminaTrack()
end

local function toggleInfiniteStamina(value)
   infiniteStamina = value
   if not value then cleanupStamina() return end
   local handlerScript = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("HUD") and Player.PlayerGui.HUD:FindFirstChild("Handler")
   local runAnimObj = handlerScript and handlerScript:FindFirstChild("RunAnimation")
   staminaCharConn = Player.CharacterAdded:Connect(function()
      stopStaminaTrack()
   end)
   local wasSprinting = false
   preRenderConn = RunService.PreRender:Connect(function()
      if _G[SESSION_KEY] ~= SESSION then return end
      local char = Player.Character
      if not char then return end
      local hum = char:FindFirstChildOfClass("Humanoid")
      if not hum then return end
      local isCrouched = Player:FindFirstChild("IsCrouched") and Player.IsCrouched.Value
      local isAnchored = hum.RootPart and (hum.RootPart.Anchored or hum.RootPart:FindFirstChildWhichIsA("WeldConstraint"))
      local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
      local moving = hum.MoveDirection.Magnitude > 0
      local shouldSprint = shiftHeld and moving and not isCrouched and not isAnchored
      if shouldSprint then
         hum.WalkSpeed = sprintSpeed
         if not wasSprinting or not animTrack then
            local animator = hum:FindFirstChildOfClass("Animator")
            loadStaminaTrack(animator, runAnimObj)
         end
         wasSprinting = true
         if CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
            local beatStage = Player:GetAttribute("BeatStage") or 0
            local targetFov = beatStage > 0 and 90 or 87
            if math.abs(CurrentCamera.FieldOfView - targetFov) > 0.5 then
               TweenService:Create(CurrentCamera, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = targetFov }):Play()
            end
         end
      else
         if wasSprinting then
            stopStaminaTrack()
         end
         wasSprinting = false
         if CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
            local beatStage = Player:GetAttribute("BeatStage") or 0
            local targetFov = beatStage > 0 and 85 or 82
            if math.abs(CurrentCamera.FieldOfView - targetFov) > 0.5 then
               TweenService:Create(CurrentCamera, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = targetFov }):Play()
            end
         end
      end
      local pg = Player:FindFirstChild("PlayerGui")
      if pg then
         local hud = pg:FindFirstChild("HUD")
         if hud then
            local stats = hud:FindFirstChild("Stats")
            if stats then
               local stamina = stats:FindFirstChild("Stamina")
               if stamina then
                  local level = stamina:FindFirstChild("level")
                  if level then
                     for _, tween in level:GetTweens() do tween:Cancel() end
                     level.Size = UDim2.new(1, 0, 1, 0)
                  end
               end
            end
         end
      end
   end)
end

local itemFilters = { Clonk = true, Fraggles = true, Plasto = true, Weapon = true, Trap = true }

local ENEMY_FILTER_KEYS = { Grandpa_Model = "Grandpa", Rat = "Rat", Roach = "Roach" }
local enemyFilters = { Grandpa = true, Rat = true, Roach = true }

local espEnabled = false
local espItems = {}
local espConnections = {}
local espAddConn = nil

local function applyItemFilters()
   for _, data in next, espItems do
      local visible = espEnabled and (itemFilters[data.material] ~= false)
      if data.highlight then data.highlight.Enabled = visible end
      if data.billboard then data.billboard.Enabled = visible end
   end
end

local function lookupMaterial(name)
   for _, cat in game.ReplicatedStorage.Assets.Items:GetChildren() do
      local found = cat:FindFirstChild(name)
      if found then
         local mat = found:GetAttribute("Material")
         if mat then return mat end
      end
   end
   return nil
end

local function getItemDefinition(itemModel)
   local name = itemModel.Name
   local override = ITEM_OVERRIDES[name]
   if override then
      local label = override.label or name
      local mat = override.mat or itemModel:GetAttribute("Material") or lookupMaterial(name) or "Fraggles"
      return mat, label
   end
   local mat = itemModel:GetAttribute("Material")
   if mat then return mat, name end
   mat = lookupMaterial(name)
   if mat then return mat, name end
   return "Fraggles", name
end

local function createItemEsp(itemModel)
   if not itemModel.PrimaryPart then return end
   if espItems[itemModel] then return end
   local oldHl = itemModel:FindFirstChild("GnomesItemHl")
   if oldHl then oldHl:Destroy() end
   local oldBg = itemModel:FindFirstChild("GnomesItemBg")
   if oldBg then oldBg:Destroy() end
   local mat, displayName = getItemDefinition(itemModel)
   local color = MAT_COLORS[mat] or Color3.fromRGB(200, 200, 200)
   local highlight = Instance.new("Highlight")
   highlight.Name = "GnomesItemHl"
   highlight.Adornee = itemModel
   highlight.FillColor = color
   highlight.FillTransparency = 0.7
   highlight.OutlineColor = color
   highlight.OutlineTransparency = 0.3
   highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
   highlight.Parent = itemModel
   local pp = itemModel.PrimaryPart
   local labelYOff = pp.Size.Y / 2 + 2
   local bg = Instance.new("BillboardGui")
   bg.Name = "GnomesItemBg"
   bg.Adornee = pp
   bg.Size = UDim2.new(0, 120, 0, 26)
   bg.StudsOffset = Vector3.new(0, labelYOff, 0)
   bg.AlwaysOnTop = true
   bg.Parent = itemModel
   local bgFrame = Instance.new("Frame")
   bgFrame.Size = UDim2.new(1, 0, 1, 0)
   bgFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
   bgFrame.BackgroundTransparency = 0.25
   bgFrame.BorderSizePixel = 0
   bgFrame.Parent = bg
   local bgCorner = Instance.new("UICorner")
   bgCorner.CornerRadius = UDim.new(0, 6)
   bgCorner.Parent = bgFrame
   local dot = Instance.new("Frame")
   dot.Size = UDim2.new(0, 8, 0, 8)
   dot.Position = UDim2.new(0, 8, 0.5, -4)
   dot.BackgroundColor3 = color
   dot.BorderSizePixel = 0
   dot.Parent = bgFrame
   local dotCorner = Instance.new("UICorner")
   dotCorner.CornerRadius = UDim.new(1, 0)
   dotCorner.Parent = dot
   local nameLabel = Instance.new("TextLabel")
   nameLabel.Size = UDim2.new(1, -24, 0, 14)
   nameLabel.Position = UDim2.new(0, 22, 0, 1)
   nameLabel.BackgroundTransparency = 1
   nameLabel.Text = displayName
   nameLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
   nameLabel.Font = Enum.Font.GothamBold
   nameLabel.TextSize = 12
   nameLabel.TextXAlignment = Enum.TextXAlignment.Left
   nameLabel.TextTransparency = 0.1
   nameLabel.Parent = bgFrame
   local matLabel = Instance.new("TextLabel")
   matLabel.Size = UDim2.new(1, -24, 0, 11)
   matLabel.Position = UDim2.new(0, 22, 0, 15)
   matLabel.BackgroundTransparency = 1
   matLabel.Text = mat
   matLabel.TextColor3 = color
   matLabel.Font = Enum.Font.Gotham
   matLabel.TextSize = 9
   matLabel.TextXAlignment = Enum.TextXAlignment.Left
   matLabel.TextTransparency = 0.3
   matLabel.Parent = bgFrame
   local visible = itemFilters[mat] ~= false
   highlight.Enabled = visible
   bg.Enabled = visible
   espItems[itemModel] = { highlight = highlight, billboard = bg, item = itemModel, material = mat }
   local conn = itemModel.AncestryChanged:Connect(function()
      if _G[SESSION_KEY] ~= SESSION then conn:Disconnect() return end
      if not itemModel.Parent then conn:Disconnect(); removeItemEsp(itemModel) end
   end)
   table.insert(espConnections, conn)
end

local function removeItemEsp(itemModel)
   local data = espItems[itemModel]
   if data then
      if data.highlight then data.highlight:Destroy() end
      if data.billboard then data.billboard:Destroy() end
      espItems[itemModel] = nil
   end
end

local function cleanupEsp()
   for item, data in next, espItems do
      if data.highlight then data.highlight:Destroy() end
      if data.billboard then data.billboard:Destroy() end
   end
   for k in next, espItems do espItems[k] = nil end
   if espAddConn then espAddConn:Disconnect(); espAddConn = nil end
   for _, conn in espConnections do conn:Disconnect() end
   for i = #espConnections, 1, -1 do table.remove(espConnections) end
end

local enemyEsp = {}
local enemyEspConns = {}
local enemyAddConn = nil
local enemyEspEnabled = false

local function applyEnemyFilters()
   for _, data in next, enemyEsp do
      local visible = enemyEspEnabled and (enemyFilters[data.filterKey] ~= false)
      if data.highlight then data.highlight.Enabled = visible end
      if data.billboard then data.billboard.Enabled = visible end
   end
end

local function createEnemyEsp(model)
   if enemyEsp[model] then return end
   local hum = model:FindFirstChildWhichIsA("Humanoid")
   local root = hum and hum.RootPart or model.PrimaryPart
   if not root then return end
   local oldHl = model:FindFirstChild("GnomesEnemyHl")
   if oldHl then oldHl:Destroy() end
   local oldBg = model:FindFirstChild("GnomesEnemyBg")
   if oldBg then oldBg:Destroy() end
   local highlight = Instance.new("Highlight")
   highlight.Name = "GnomesEnemyHl"
   highlight.Adornee = model
   highlight.FillColor = Color3.fromRGB(255, 60, 60)
   highlight.FillTransparency = 0.6
   highlight.OutlineColor = Color3.fromRGB(255, 30, 30)
   highlight.OutlineTransparency = 0.2
   highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
   highlight.Parent = model
   local bg = Instance.new("BillboardGui")
   bg.Name = "GnomesEnemyBg"
   bg.Adornee = root
   bg.Size = UDim2.new(0, 140, 0, 34)
   bg.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 2, 0)
   bg.AlwaysOnTop = true
   bg.Parent = model
   local bgFrame = Instance.new("Frame")
   bgFrame.Size = UDim2.new(1, 0, 1, 0)
   bgFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
   bgFrame.BackgroundTransparency = 0.2
   bgFrame.BorderSizePixel = 0
   bgFrame.Parent = bg
   local bgCorner = Instance.new("UICorner")
   bgCorner.CornerRadius = UDim.new(0, 6)
   bgCorner.Parent = bgFrame
   local nameLabel = Instance.new("TextLabel")
   nameLabel.Size = UDim2.new(1, -10, 0, 16)
   nameLabel.Position = UDim2.new(0, 5, 0, 2)
   nameLabel.BackgroundTransparency = 1
   nameLabel.Text = model.Name:gsub("_Model", ""):gsub("_", " ")
   nameLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
   nameLabel.Font = Enum.Font.GothamBold
   nameLabel.TextSize = 12
   nameLabel.TextXAlignment = Enum.TextXAlignment.Left
   nameLabel.Parent = bgFrame
   local barBg = Instance.new("Frame")
   barBg.Size = UDim2.new(1, -10, 0, 4)
   barBg.Position = UDim2.new(0, 5, 0, 20)
   barBg.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
   barBg.BorderSizePixel = 0
   barBg.Parent = bgFrame
   local barCorner = Instance.new("UICorner")
   barCorner.CornerRadius = UDim.new(1, 0)
   barCorner.Parent = barBg
   local barFill = Instance.new("Frame")
   barFill.Size = UDim2.new(1, 0, 1, 0)
   barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
   barFill.BorderSizePixel = 0
   barFill.Parent = barBg
   local barFillCorner = Instance.new("UICorner")
   barFillCorner.CornerRadius = UDim.new(1, 0)
   barFillCorner.Parent = barFill
   local healthLabel = Instance.new("TextLabel")
   healthLabel.Size = UDim2.new(1, -10, 0, 12)
   healthLabel.Position = UDim2.new(0, 5, 0, 24)
   healthLabel.BackgroundTransparency = 1
   healthLabel.Text = tostring(math.floor(hum.Health)) .. "/" .. tostring(hum.MaxHealth)
   healthLabel.TextColor3 = Color3.fromRGB(220, 200, 200)
   healthLabel.Font = Enum.Font.Gotham
   healthLabel.TextSize = 9
   healthLabel.TextXAlignment = Enum.TextXAlignment.Left
   healthLabel.TextTransparency = 0.2
   healthLabel.Parent = bgFrame
   bg.Size = UDim2.new(0, 140, 0, 36)
   local filterKey = ENEMY_FILTER_KEYS[model.Name] or model.Name
   local visible = enemyFilters[filterKey] ~= false
   highlight.Enabled = visible
   bg.Enabled = visible
   enemyEsp[model] = { highlight = highlight, billboard = bg, barFill = barFill, healthLabel = healthLabel, humanoid = hum, filterKey = filterKey }
   local healthConn = hum.HealthChanged:Connect(function()
      if _G[SESSION_KEY] ~= SESSION then return end
      local data = enemyEsp[model]
      if data then
         data.barFill.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
         data.healthLabel.Text = tostring(math.floor(hum.Health)) .. "/" .. tostring(hum.MaxHealth)
      end
   end)
   table.insert(enemyEspConns, healthConn)
   local diedConn = hum.Died:Connect(function()
      if _G[SESSION_KEY] ~= SESSION then return end
      removeEnemyEsp(model)
   end)
   table.insert(enemyEspConns, diedConn)
end

local function removeEnemyEsp(model)
   local data = enemyEsp[model]
   if data then
      if data.highlight then data.highlight:Destroy() end
      if data.billboard then data.billboard:Destroy() end
      enemyEsp[model] = nil
   end
end

local function cleanupEnemyEsp()
   for model, data in next, enemyEsp do
      if data.highlight then data.highlight:Destroy() end
      if data.billboard then data.billboard:Destroy() end
   end
   for k in next, enemyEsp do enemyEsp[k] = nil end
   if enemyAddConn then enemyAddConn:Disconnect(); enemyAddConn = nil end
   for _, conn in enemyEspConns do conn:Disconnect() end
   for i = #enemyEspConns, 1, -1 do table.remove(enemyEspConns) end
end

local function shouldBeEnemy(model)
   if not model:IsA("Model") or not model:IsDescendantOf(workspace) then return false end
   if model == Player.Character then return false end
   for _, plr in ipairs(game.Players:GetPlayers()) do
      if plr.Character == model then return false end
   end
   local n = model.Name
   if n == "PoseStatueGuy" or n == "grandpa" or n == "baby" or n:find("Arms") then return false end
   local hum = model:FindFirstChildWhichIsA("Humanoid")
   if not hum or hum.Health <= 0 then return false end
   return true
end

-- Player ESP
local playerEspItems = {}
local playerEspEnabled = false

local function cleanupPlayerEsp()
   for plr, data in next, playerEspItems do
      if data.billboard then data.billboard:Destroy() end
   end
   for k in next, playerEspItems do playerEspItems[k] = nil end
end

local function togglePlayerEsp(value)
   playerEspEnabled = value
   if not value then cleanupPlayerEsp() return end
   for _, plr in ipairs(game.Players:GetPlayers()) do
      if plr == Player then continue end
      local c = plr.Character
      if c and c.PrimaryPart and not playerEspItems[plr] then
         local bg = Instance.new("BillboardGui")
         bg.Size = UDim2.new(0, 100, 0, 26); bg.AlwaysOnTop = true
         bg.StudsOffset = Vector3.new(0, 3, 0); bg.Parent = c; bg.ResetOnSpawn = false
         local lbl = Instance.new("TextLabel")
         lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
         lbl.TextColor3 = Color3.fromRGB(255, 100, 100); lbl.TextStrokeTransparency = 0.3
         lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13; lbl.Parent = bg
         playerEspItems[plr] = { billboard = bg, player = plr }
      end
   end
   game.Players.PlayerAdded:Connect(function(plr)
      if _G[SESSION_KEY] ~= SESSION then return end
      if not playerEspEnabled then return end
      plr.CharacterAdded:Connect(function(c)
         if _G[SESSION_KEY] ~= SESSION then return end
         if not playerEspEnabled or not c.PrimaryPart or playerEspItems[plr] then return end
         local bg = Instance.new("BillboardGui")
         bg.Size = UDim2.new(0, 100, 0, 26); bg.AlwaysOnTop = true
         bg.StudsOffset = Vector3.new(0, 3, 0); bg.Parent = c; bg.ResetOnSpawn = false
         local lbl = Instance.new("TextLabel")
         lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
         lbl.TextColor3 = Color3.fromRGB(255, 100, 100); lbl.TextStrokeTransparency = 0.3
         lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13; lbl.Parent = bg
         playerEspItems[plr] = { billboard = bg, player = plr }
      end)
   end)
end

local function toggleEsp(value)
   espEnabled = value
   if not value then cleanupEsp() return end
   for _, item in CollectionService:GetTagged("CanGrab") do
      if item:IsDescendantOf(workspace) and item:IsA("Model") and item.PrimaryPart then createItemEsp(item) end
   end
   espAddConn = CollectionService:GetInstanceAddedSignal("CanGrab"):Connect(function(item)
      if _G[SESSION_KEY] ~= SESSION then return end
      if espEnabled and item:IsDescendantOf(workspace) and item:IsA("Model") and item.PrimaryPart then createItemEsp(item) end
   end)
end

local function toggleEnemyEsp(value)
   enemyEspEnabled = value
   if not value then cleanupEnemyEsp() return end
   for _, obj in workspace:GetDescendants() do
      local hum = obj:IsA("Humanoid") and obj or obj:FindFirstChildWhichIsA("Humanoid")
      if hum then
         local model = hum.Parent
         if model and shouldBeEnemy(model) then createEnemyEsp(model) end
      end
   end
   enemyAddConn = workspace.DescendantAdded:Connect(function(obj)
      if _G[SESSION_KEY] ~= SESSION then return end
      if not enemyEspEnabled then return end
      local hum = obj:IsA("Humanoid") and obj or obj:FindFirstChildWhichIsA("Humanoid")
      if hum then
         local model = hum.Parent
         if model and shouldBeEnemy(model) then createEnemyEsp(model) end
      end
   end)
end

UserInputService.InputBegan:Connect(function(input, processed)
   if _G[SESSION_KEY] ~= SESSION then return end
   if processed then return end
   if input.KeyCode == Enum.KeyCode.X then
      toggleMouseUnlock()
      FreeMouseToggle:Set(mouseUnlock)
   end
end)

local preSimAntiBreak = nil

local function clearViewRig(char)
   if not char then return end
   for _, v in char:GetChildren() do
      if v:IsA("BasePart") and string.find(v.Name, "Arm") then v.Transparency = 0 end
      if v:IsA("Model") and v.Name == "ViewRig" then
         for _, part in v:GetDescendants() do if part:IsA("BasePart") then part.Transparency = 0 end end
      end
   end
end

local function toggleAntiBreakArms(value)
   if value then
      local attName = Player.Name .. "Att"
      local grabbedPart = nil
      local launched = false
      local function findGrabbedPart()
         grabbedPart = nil
         for _, desc in workspace:GetDescendants() do
            if desc:IsA("Attachment") and desc.Name == attName then
               local part = desc.Parent
               if part and part:IsA("BasePart") then grabbedPart = part; return end
            end
         end
      end
      local function isGrabbing()
         if grabbedPart and grabbedPart:FindFirstChild(attName) then return true end
         findGrabbedPart()
         return grabbedPart ~= nil
      end
      findGrabbedPart()
      preSimAntiBreak = RunService.PreSimulation:Connect(function()
         local char = Player.Character
         if not char then return end
         for _, cp in char:GetDescendants() do if cp.Name == "ColliderPart" then cp:Destroy() end end
         local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
         if root and Vector3.new(root.Velocity.X, 0, root.Velocity.Z).Magnitude > 80 then
            root.Velocity = Vector3.new(0, root.Velocity.Y, 0)
         end
      end)
      antiBreakConn = RunService.Heartbeat:Connect(function()
         local char = Player.Character
         if not char then return end
         local isRagdoll = char:FindFirstChild("IsRagdoll")
         if isRagdoll and isRagdoll.Value then isRagdoll.Value = false end
         local humanoid = char:FindFirstChildWhichIsA("Humanoid")
         local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
         if humanoid then
            if humanoid.PlatformStand then humanoid.PlatformStand = false end
            if not humanoid.AutoRotate then humanoid.AutoRotate = true end
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
         end
         clearViewRig(char)
         for _, cp in char:GetDescendants() do if cp.Name == "ColliderPart" then cp:Destroy() end end
         if root then
            local flatSpeed = Vector3.new(root.Velocity.X, 0, root.Velocity.Z).Magnitude
            if flatSpeed > 80 then root.Velocity = Vector3.new(0, root.Velocity.Y, 0); launched = true
            elseif launched and flatSpeed < 15 then launched = false end
         end
         if isGrabbing() and not launched and not grabOverrideActive then
            if not root then return end
            local bp = grabbedPart:FindFirstChildWhichIsA("BodyPosition")
            if bp then
               local offset = bp.Position - root.Position
               if offset.Magnitude > 18 then bp.Position = root.Position + offset.Unit * 18 end
            end
         end
      end)
   else
      if preSimAntiBreak then preSimAntiBreak:Disconnect(); preSimAntiBreak = nil end
      if antiBreakConn then antiBreakConn:Disconnect(); antiBreakConn = nil end
   end
end

local grabConn = nil
local grabScrollConn = nil
local grabClickConn = nil
local grabReleaseConn = nil
local grabDropConn = nil
local grabActivateConn = nil
local grabbedBP = nil
local grabReleaseQueued = false
local grabOverrideActive = false

local function findGrabbedBP()
   if grabbedBP and grabbedBP.Parent then return grabbedBP end
   grabbedBP = nil
   for _, obj in workspace:GetDescendants() do
      if obj:IsA("BodyPosition") then
         local part = obj.Parent
         if part and (part:IsA("BasePart") or part:IsA("Attachment")) then
            local model = part:FindFirstAncestorWhichIsA("Model")
            if model and model:HasTag("CanGrab") then grabbedBP = obj; return obj end
         end
      end
   end
   return nil
end

local function getRemote(name)
   local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
   return remotes and remotes:FindFirstChild(name or "GrabEvent")
end

local function findInteractiveInView(maxDist)
   local char = Player.Character
   if not char then return nil end
   local filter = RaycastParams.new()
   filter.FilterType = Enum.RaycastFilterType.Exclude
   local exclude = { char }
   local viewRig = char:FindFirstChild(Player.Name .. "Arms")
   if viewRig then table.insert(exclude, viewRig) end
   filter.FilterDescendantsInstances = exclude
   local result = workspace:Raycast(CurrentCamera.CFrame.Position, CurrentCamera.CFrame.LookVector * maxDist, filter)
   if result and result.Instance then
      local model = result.Instance:FindFirstAncestorWhichIsA("Model")
      if model and model:GetAttribute("System") then return model end
   end
end

local grabModelRef = nil

local function grabRelease()
   if not grabReleaseQueued then return end
   grabReleaseQueued = false
   local model = grabModelRef
   grabModelRef = nil
   if not model or not model.Parent then
      local bp = findGrabbedBP()
      if bp then model = bp.Parent:FindFirstAncestorWhichIsA("Model") end
   end
   if model then
      local ge = getRemote()
      if ge then ge:FireServer(model) end
   end
end

local grabScriptsState = {}
local function disableGrabScripts(disable)
   if not Player.Character then return end
   local char = Player.Character
   local targets = { char:FindFirstChild("GrabClient"), char:FindFirstChild("UPDGrabClient") }
   for _, script in ipairs(targets) do
      if script and script:IsA("LocalScript") then
         if disable then
            if not grabScriptsState[script] then grabScriptsState[script] = script.Disabled end
            script.Disabled = true
         else
            local orig = grabScriptsState[script]
            if orig ~= nil then script.Disabled = orig end
            grabScriptsState[script] = nil
         end
      end
   end
end

local function findGrabbableInView(maxDist)
   local char = Player.Character
   if not char then return nil end
   local filter = RaycastParams.new()
   filter.FilterType = Enum.RaycastFilterType.Exclude
   local exclude = { char }
   local viewRig = char:FindFirstChild(Player.Name .. "Arms")
   if viewRig then table.insert(exclude, viewRig) end
   filter.FilterDescendantsInstances = exclude
   local result = workspace:Raycast(CurrentCamera.CFrame.Position, CurrentCamera.CFrame.LookVector * maxDist, filter)
   if result and result.Instance then
      local model = result.Instance:FindFirstAncestorWhichIsA("Model")
      if model and model:HasTag("CanGrab") then return model end
   end
   return nil
end

local function toggleGrab(value)
   grabOverrideActive = value
   if value then
      local myDistance = 50
      disableGrabScripts(true)
      grabScrollConn = UserInputService.InputChanged:Connect(function(input, processed)
         if processed then return end
         if input.UserInputType == Enum.UserInputType.MouseWheel then
            myDistance = math.clamp(myDistance + input.Position.Z * 5, 5, 500)
         end
      end)
      grabClickConn = UserInputService.InputBegan:Connect(function(input, processed)
         if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
         if findGrabbedBP() then return end
         local interactiveModel = findInteractiveInView(1000)
         if interactiveModel then
            local cs = getRemote("CheckSystem")
            if cs then cs:FireServer(interactiveModel) end
            return
         end
         local model = findGrabbableInView(1000)
         if model and model.PrimaryPart then
            local ge = getRemote()
            if ge then ge:FireServer(model, model.PrimaryPart.Position); grabReleaseQueued = true; grabModelRef = model end
         end
      end)
      grabDropConn = UserInputService.InputBegan:Connect(function(input, processed)
         if processed then return end
         if input.KeyCode == Enum.KeyCode.H and grabReleaseQueued then grabRelease() end
      end)
      grabActivateConn = UserInputService.InputBegan:Connect(function(input, processed)
         if processed then return end
         if input.KeyCode == Enum.KeyCode.E then
            local bp = findGrabbedBP()
            if bp then
               local part = bp.Parent
               if part and part:IsA("BasePart") then
                  local model = part:FindFirstAncestorWhichIsA("Model")
                  if model then
                     local cs = getRemote("CheckSystem")
                     if cs then cs:FireServer(model) end
                  end
               end
            end
         end
      end)
      grabbedBP = nil
      grabConn = RunService.PreRender:Connect(function()
         if not Player.Character then return end
         local bp = findGrabbedBP()
         if bp then
            local targetPos = CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * myDistance
            bp.MaxForce = Vector3.new(500000, 500000, 500000)
            bp.P = 15000
            bp.D = 2000
            bp.Position = targetPos
            local part = bp.Parent
            if part and part:IsA("BasePart") then
               local model = part:FindFirstAncestorWhichIsA("Model")
               if model and model.PrimaryPart then model.PrimaryPart.CFrame = CFrame.new(targetPos) end
            end
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then grabRelease() end
         end
      end)
   else
      disableGrabScripts(false)
      if grabConn then grabConn:Disconnect(); grabConn = nil end
      if grabScrollConn then grabScrollConn:Disconnect(); grabScrollConn = nil end
      if grabClickConn then grabClickConn:Disconnect(); grabClickConn = nil end
      if grabReleaseConn then grabReleaseConn:Disconnect(); grabReleaseConn = nil end
      if grabDropConn then grabDropConn:Disconnect(); grabDropConn = nil end
      if grabActivateConn then grabActivateConn:Disconnect(); grabActivateConn = nil end
      grabbedBP = nil; grabModelRef = nil; grabReleaseQueued = false
   end
end

local antiBreakConn = nil

-- Heartbeat-based features (re-run safe via SESSION check)
RunService.Heartbeat:Connect(function(dt)
   if _G[SESSION_KEY] ~= SESSION then return end
   local char = Player.Character
   if not char then return end
   local hrp = char:FindFirstChild("HumanoidRootPart")
   local hum = char:FindFirstChild("Humanoid")
   if not hrp or not hum then return end
   if not hrp:IsDescendantOf(workspace) or not hum:IsDescendantOf(workspace) then return end

   if flags.wsE then hum.WalkSpeed = flags.ws end

   if flags.noclip then
      for _, v in ipairs(char:GetDescendants()) do
         if v:IsA("BasePart") then v.CanCollide = false end
      end
   end

   if flags.fly then
      hum.PlatformStand = true
      hrp.Anchored = true
      local m = Vector3.new(
         (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
         (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0),
         (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0))
      local cf = CurrentCamera.CFrame
      local dir = (cf.RightVector * m.X + Vector3.new(0, m.Y, 0) + cf.LookVector * m.Z).Unit * flags.flySpd
      if dir.Magnitude > 0 then
         hrp.CFrame = hrp.CFrame + dir * dt
      end
      hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + cf.LookVector)
   end

   if flags.fb then
      Lighting.Brightness = 2
      Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
      Lighting.FogEnd = 1e5
      Lighting.ClockTime = 14
   end
end)

-- Player ESP update loop
local playerEspRunning = true
task.spawn(function()
   while playerEspRunning do
      task.wait(0.5)
      if _G[SESSION_KEY] ~= SESSION then return end
      if playerEspEnabled then
         for plr, data in next, playerEspItems do
            if data and data.billboard and data.billboard.Parent then
               local c = plr.Character
               if c and c.PrimaryPart then
                  local lbl = data.billboard:FindFirstChildWhichIsA("TextLabel")
                  if lbl then
                     lbl.Text = plr.Name .. " [" .. math.floor((c.PrimaryPart.Position - CurrentCamera.CFrame.Position).Magnitude) .. "m]"
                  end
               end
            else
               playerEspItems[plr] = nil
            end
         end
      end
   end
end)

-- Auto-revive when dead
local reviveRunning = true
task.spawn(function()
   while reviveRunning do
      task.wait(0.2)
      if _G[SESSION_KEY] ~= SESSION then return end
      local char = Player.Character
      if char and infiniteStamina then
         local hum = char:FindFirstChild("Humanoid")
         if hum and hum.Health <= 0 then
            pcall(function()
               local remotes = ReplicatedStorage:FindFirstChild("Remotes")
               if remotes then
                  local revive = remotes:FindFirstChild("UseRevive")
                  if revive then revive:FireServer() end
               end
            end)
         end
      end
   end
end)

-- Movement Tab
MovementTab:CreateSection("Stamina & Movement")

local InfiniteStaminaToggle = MovementTab:CreateToggle({
   Name = "Infinite Stamina",
   CurrentValue = false,
   Flag = "InfiniteStamina",
   Callback = function(Value)
      toggleInfiniteStamina(Value)
   end
})

MovementTab:CreateToggle({
   Name = "Walkspeed",
   CurrentValue = false,
   Flag = "Walkspeed",
   Callback = function(v) flags.wsE = v end
})

MovementTab:CreateSlider({
   Name = "Speed",
   Range = {16, 120},
   Increment = 1,
   Suffix = "studs/s",
   CurrentValue = 32,
   Flag = "WalkspeedSpeed",
   Callback = function(v) flags.ws = v end
})

local FlyToggle = nil

MovementTab:CreateKeybind({
   Name = "Fly Keybind",
   CurrentKeybind = "F",
   Flag = "FlyKeybind",
   Callback = function()
      flags.fly = not flags.fly
      if FlyToggle then FlyToggle:Set(flags.fly) end
      if not flags.fly then
         local char = Player.Character
         if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if hrp then hrp.Anchored = false; hrp.Velocity = Vector3.new() end
            if hum then hum.PlatformStand = false end
         end
      end
   end
})

FlyToggle = MovementTab:CreateToggle({
   Name = "Fly",
   CurrentValue = false,
   Flag = "Fly",
   Callback = function(v)
      flags.fly = v
      local char = Player.Character
      if char then
         local hrp = char:FindFirstChild("HumanoidRootPart")
         local hum = char:FindFirstChild("Humanoid")
         if hrp then hrp.Anchored = false; hrp.Velocity = Vector3.new() end
         if hum then hum.PlatformStand = false end
      end
   end
})

MovementTab:CreateSlider({
   Name = "Fly Speed",
   Range = {5, 300},
   Increment = 1,
   Suffix = "studs/s",
   CurrentValue = 25,
   Flag = "FlySpeed",
   Callback = function(v) flags.flySpd = v end
})

MovementTab:CreateToggle({
   Name = "Noclip",
   CurrentValue = false,
   Flag = "Noclip",
   Callback = function(v) flags.noclip = v end
})

MovementTab:CreateKeybind({
   Name = "Teleport to Mouse",
   CurrentKeybind = "C",
   Callback = function()
      local char = Player.Character
      if not char then return end
      local hrp = char:FindFirstChild("HumanoidRootPart")
      if hrp and CurrentCamera then
         local m = UserInputService:GetMouseLocation()
         local ray = CurrentCamera:ScreenPointToRay(m.X, m.Y)
         local p = RaycastParams.new()
         p.FilterType = Enum.RaycastFilterType.Blacklist
         p.FilterDescendantsInstances = {char}
         local r = workspace:Raycast(ray.Origin, ray.Direction * 500, p)
         local pos = r and r.Position or ray.Origin + ray.Direction * 50
         hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
      end
   end
})

-- Misc Tab
MiscTab:CreateSection("Mouse & Camera")

FreeMouseToggle = MiscTab:CreateToggle({
   Name = "Free Mouse [X]",
   CurrentValue = false,
   Flag = "FreeMouse",
   Callback = function(Value)
      if Value ~= mouseUnlock then toggleMouseUnlock() end
   end
})

MiscTab:CreateSection("Utility")

MiscTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(v) flags.fb = v end
})

MiscTab:CreateButton({
   Name = "Server Hop",
   Callback = function()
      game:GetService("TeleportService"):Teleport(game.PlaceId)
   end
})

MiscTab:CreateButton({
   Name = "Rejoin",
   Callback = function()
      game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
   end
})

-- Player Tab
local AntiBreakToggle = PlayerTab:CreateToggle({
   Name = "Anti Break Arms",
   CurrentValue = false,
   Flag = "AntiBreak",
   Callback = function(Value)
      toggleAntiBreakArms(Value)
   end
})

local InfiniteGrabToggle = PlayerTab:CreateToggle({
   Name = "Infinite Grab",
   CurrentValue = false,
   Flag = "InfiniteGrab",
   Callback = function(Value)
      toggleGrab(Value)
   end
})

-- ESP Tab
ESPTab:CreateSection("Item ESP")

local ItemESPToggle = ESPTab:CreateToggle({
   Name = "Item ESP",
   CurrentValue = false,
   Flag = "ItemESP",
   Callback = function(Value)
      espToggled = Value
      toggleEsp(Value)
   end
})

local itemFilterOptions = {}
for name in next, itemFilters do
   table.insert(itemFilterOptions, name)
end

local ItemFilterDropdown = ESPTab:CreateDropdown({
   Name = "Item Filters",
   Options = itemFilterOptions,
   CurrentOption = itemFilterOptions,
   MultipleOptions = true,
   Flag = "ItemFilters",
   Callback = function(Options)
      for name in next, itemFilters do
         itemFilters[name] = false
      end
      for _, name in next, Options do
         itemFilters[name] = true
      end
      applyItemFilters()
   end
})

ESPTab:CreateSection("Enemy / Player ESP")

local EnemyESPToggle = ESPTab:CreateToggle({
   Name = "Enemy ESP",
   CurrentValue = false,
   Flag = "EnemyESP",
   Callback = function(Value)
      enemyEspToggled = Value
      toggleEnemyEsp(Value)
   end
})

local enemyFilterOptions = {}
for name in next, enemyFilters do
   table.insert(enemyFilterOptions, name)
end

local EnemyFilterDropdown = ESPTab:CreateDropdown({
   Name = "Enemy Filters",
   Options = enemyFilterOptions,
   CurrentOption = enemyFilterOptions,
   MultipleOptions = true,
   Flag = "EnemyFilters",
   Callback = function(Options)
      for name in next, enemyFilters do
         enemyFilters[name] = false
      end
      for _, name in next, Options do
         enemyFilters[name] = true
      end
      applyEnemyFilters()
   end
})

ESPTab:CreateToggle({
   Name = "Player ESP",
   CurrentValue = false,
   Flag = "PlayerESP",
   Callback = function(Value)
      togglePlayerEsp(Value)
   end
})

Rayfield:Notify({
   Title = "Goober Hub",
   Content = "Loaded - X: free mouse",
   Duration = 3,
   Image = "zap"
})

Rayfield:LoadConfiguration()

local espToggled = false
local enemyEspToggled = false

print("[Goober Hub] Loaded - X: free mouse | Teleport keybind in Movement tab")
