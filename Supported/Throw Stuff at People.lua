-- Use global state so re-executing doesn't leave orphan loops running
_G.__tsfAlive = false
_G.__tsf = _G.__tsf or {}
for _, conn in ipairs(_G.__tsf.Connections or {}) do pcall(function() conn:Disconnect() end) end
_G.__tsf.Connections = {}
_G.__tsfAlive = true

local Flags = {}
_G.__tsf.Flags = Flags

local defaults = {
   AutoFarm = false,
   AutoEquipArm = false,
   NoCooldown = false,
   AntiFall = false,
   Glide = false,
   GlideSpeed = 20,
   SpeedEnabled = false,
   NoClip = false,
   AutoPoints = false,
   Weapon = "Chair",
   Speed = 16,
   ThrowDelay = 3,
   LeadTime = 0.3
}
for k, v in pairs(defaults) do
   Flags[k] = v
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Goober Hub",
   LoadingTitle = "Goober Hub",
   LoadingSubtitle = "By Goober Astronomy",
   Theme = "Default",
   ToggleUIKeybind = "K",
   ConfigurationSaving = { Enabled = true, FileName = "GooberHubV2" }
})
_G.__tsf.Window = Window

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local UserInputService = game:GetService("UserInputService")

-- Safe character access (never yields)
local function getChar()
   return LP.Character
end

local function getHum()
   local c = getChar()
   return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
   local c = getChar()
   return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive()
   local c = getChar()
   local h = c and c:FindFirstChildOfClass("Humanoid")
   return c and h and h.Health > 0
end

local function findNearestTarget()
   local hrp = getHRP()
   if not hrp then return nil end
   local pos = hrp.Position
   local nearest, nearestDist = nil, math.huge
   for _, p in ipairs(Players:GetPlayers()) do
      if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
         local h = p.Character:FindFirstChildOfClass("Humanoid")
         if h and h.Health > 0 then
            local d = (p.Character.HumanoidRootPart.Position - pos).Magnitude
            if d < nearestDist then nearestDist = d; nearest = p end
         end
      end
   end
   for _, v in ipairs(Workspace:GetDescendants()) do
      if v:IsA("Model") and v:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(v) then
         local h = v:FindFirstChildOfClass("Humanoid")
         local hrp2 = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
         if h and h.Health > 0 and hrp2 then
            local d = (hrp2.Position - pos).Magnitude
            if d < nearestDist then nearestDist = d; nearest = v end
         end
      end
   end
   return nearest
end

local function getNearestTargetPos()
   local t = findNearestTarget()
   if not t then return nil end
   local char = t:IsA("Player") and t.Character or t
   if not char then return nil end
   local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
   if not hrp then return nil end
   return hrp.Position
end

local function getToolRef(name)
   local tool = ReplicatedStorage:FindFirstChild(name)
   if tool and tool:IsA("Tool") then return tool end
   for _, v in ipairs(ReplicatedStorage:GetChildren()) do
      if v:IsA("Tool") and v.Name:lower():find(name:lower()) then return v end
   end
   return nil
end

local function tpTo(cf)
   local hrp = getHRP()
   if hrp then hrp.CFrame = cf end
end

-- Get or equip the selected weapon. Returns a tool reference.
local function equipWeapon()
   local char = getChar()
   if not char then return nil end
   local bp = LP:FindFirstChild("Backpack")
   if not bp then return nil end
   local src = getToolRef(Flags.Weapon)
   if not src then return nil end
   -- Check character first (fast path - tool persists after throws)
   for _, v in ipairs(char:GetChildren()) do
      if v:IsA("Tool") and v.Name == src.Name then
         return v
      end
   end
   -- Check backpack
   for _, v in ipairs(bp:GetChildren()) do
      if v:IsA("Tool") and v.Name == src.Name then
         v.Parent = char
         return v
      end
   end
   -- Clone new tool (fast poll)
   pcall(function() ReplicatedStorage.CloneTool:FireServer(bp, src, 0) end)
   for i = 1, 10 do
      task.wait(0.02)
      for _, v in ipairs(bp:GetChildren()) do
         if v:IsA("Tool") and v.Name == src.Name then
            v.Parent = char
            return v
         end
      end
   end
   return nil
end

-- Throw using a specific tool reference
local function throwWeapon(tool, targetPos)
   local char = getChar()
   local hum = getHum()
   if not (char and hum and tool) then return false end
   local rf = tool:FindFirstChild("RemoteFunction")
   if not rf then return false end
   hum.TargetPoint = targetPos
   task.spawn(function()
      pcall(function()
         rf:InvokeServer({ target = targetPos, char = char, hum = hum })
      end)
   end)
   return true
end

-- Build tool list (only unlocked weapons)
local function getUnlockedWeapons()
   local ls = LP:FindFirstChild("leaderstats")
   if not ls then return {} end
   local list = {}
   for _, v in ipairs(ReplicatedStorage:GetChildren()) do
      if v:IsA("Tool") then
         local bv = ls:FindFirstChild(v.Name)
         if bv and bv:IsA("BoolValue") and bv.Value then
            table.insert(list, v.Name)
         end
      end
   end
   table.sort(list)
   return list
end

local function getAllWeapons()
   local ls = LP:FindFirstChild("leaderstats")
   local seen = {}
   local list = {}
   local function add(name)
      if not seen[name] then
         seen[name] = true
         table.insert(list, name)
      end
   end
   for _, v in ipairs(ReplicatedStorage:GetChildren()) do
      if v:IsA("Tool") then add(v.Name) end
   end
   if ls then
      local weaponPrefixes = {}
      for _, v in ipairs(ReplicatedStorage:GetChildren()) do
         if v:IsA("Tool") then weaponPrefixes[v.Name] = true end
      end
      for _, v in ipairs(ls:GetChildren()) do
         if v:IsA("BoolValue") and not weaponPrefixes[v.Name]
            and not v.Name:match("SeenUpdate") and not v.Name:match("TalkedHunter")
            and not v.Name:match("Claimed") and not v.Name:match("GroupReward")
            and not v.Name:match("FirstVisit") and not v.Name:match("Recovered")
            and not v.Name:match("Cooldown") and not v.Name:match("QuestNumber")
            and not v.Name:match("ConsecutiveDays") and not v.Name:match("StartDate")
            and not v.Name:match("LastReward") and not v.Name:match("Streaklight")
         then
            add(v.Name)
         end
      end
   end
   table.sort(list)
   return list
end

local allWeaponList = getAllWeapons()
Flags.Weapon = allWeaponList[1] or "Chair"

-- ===== UI =====
local CombatTab = Window:CreateTab("Combat", "swords")
local MovementTab = Window:CreateTab("Movement", "zap")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local ExploitsTab = Window:CreateTab("Exploits", "shield")

CombatTab:CreateSection("Combat Settings")

local WeaponDropdown = CombatTab:CreateDropdown({
   Name = "Weapon",
   Options = allWeaponList,
   CurrentOption = { allWeaponList[1] or "Chair" },
   MultipleOptions = false,
   Flag = "Combat_Weapon",
   Callback = function(v) Flags.Weapon = v[1] or allWeaponList[1] or "Chair" end
})

local AutoFarmToggle = CombatTab:CreateToggle({
   Name = "Auto Farm",
   CurrentValue = false,
   Flag = "Combat_AutoFarm",
   Callback = function(v)
      Flags.AutoFarm = v
      if not v then
         local bp = LP:FindFirstChild("Backpack")
         local char = getChar()
         if bp then
            for _, tool in ipairs(bp:GetChildren()) do
               if tool:IsA("Tool") then pcall(function() tool:Destroy() end) end
            end
         end
         if char then
            for _, tool in ipairs(char:GetChildren()) do
               if tool:IsA("Tool") then pcall(function() tool:Destroy() end) end
            end
         end
      end
   end
})

local NoCooldownToggle = CombatTab:CreateToggle({
   Name = "No Cooldown",
   CurrentValue = false,
   Flag = "Combat_NoCooldown",
   Callback = function(v) Flags.NoCooldown = v end
})

CombatTab:CreateSection("Auto Farm Settings")

local AutoFarmDelay = CombatTab:CreateSlider({
   Name = "Throw Delay (sec)",
   Range = { 0.1, 3 },
   Increment = 0.1,
   Suffix = "s",
   CurrentValue = 3,
   Flag = "Combat_ThrowDelay",
   Callback = function(v) Flags.ThrowDelay = v end
})

local LeadTimeSlider = CombatTab:CreateSlider({
   Name = "Target Prediction (sec)",
   Range = { 0, 1 },
   Increment = 0.05,
   Suffix = "s",
   CurrentValue = 0.3,
   Flag = "Combat_LeadTime",
   Callback = function(v) Flags.LeadTime = v end
})

CombatTab:CreateSection("Quick Actions")

CombatTab:CreateButton({
   Name = "Equip Weapon",
   Callback = equipWeapon
})

CombatTab:CreateButton({
   Name = "Throw Once at Nearest",
   Callback = function()
      local pos = getNearestTargetPos()
      if not pos then return end
      local tool = equipWeapon()
      if tool then throwWeapon(tool, pos) end
   end
})

CombatTab:CreateSection("Weapon Unlocker")

local weaponList = {
   "Anchor","Anvil","Barbeque","BatPack","BlackHole","Bomb","Boulder","Bow",
   "Box","Brick","Car","Chair","Coconut","Cursed Cutlass","Cursed Pumpkin",
   "CursedBrick","Devil's Trident","Dynamite","Egg","Electric Pumpkin",
   "Exploding Knife","Firework","Flaming Pumpkin","Fly","God's Arm",
   "Key","KeyCard","Keys","Lawn Mower","Log","Mast Scrap","Metal Pan",
   "Piano","Powder Keg","Pumpkin","Revolver","RocketToken","Safe",
   "Shock Stunner","Shopping Cart","Shovel","Shuriken","Slipper","Spear",
   "Static Stunner","Stone","Streaklight Stunner","Table","ThrowingKnife",
   "Thruster","TimeArm","Void Stunner","Warp Dagger","Water Balloon",
   "Wood Scrap","bosstrident","maxwell","pickupcard","vibing maxwell",
   "BOSSKILLER","Candle","MoverTool"
}
table.sort(weaponList)

Flags.SelectedWeapon = weaponList[1]

CombatTab:CreateDropdown({
   Name = "Unlock Weapon",
   Options = weaponList,
   CurrentOption = { weaponList[1] },
   MultipleOptions = false,
   Flag = "Combat_GiveWeapon",
   Callback = function(v) Flags.SelectedWeapon = v[1] or weaponList[1] end
})

CombatTab:CreateButton({
   Name = "Unlock Selected",
   Callback = function()
      local ls = LP:FindFirstChild("leaderstats")
      if not ls then return end
      local name = Flags.SelectedWeapon
      local bv = ls:FindFirstChild(name)
      if bv and bv:IsA("BoolValue") then
         bv.Value = true
      end
      pcall(function() ReplicatedStorage.changestat:FireServer(name, true) end)
      Rayfield:Notify({ Title = "Goober Hub", Content = "Unlocked: " .. name, Duration = 3 })
   end
})

CombatTab:CreateButton({
   Name = "Unlock All Weapons",
   Callback = function()
      local ls = LP:FindFirstChild("leaderstats")
      if not ls then return end
      local count = 0
      for _, tool in ipairs(ReplicatedStorage:GetChildren()) do
         if tool:IsA("Tool") then
            local bv = ls:FindFirstChild(tool.Name)
            if bv and bv:IsA("BoolValue") and not bv.Value then
               bv.Value = true
               pcall(function() ReplicatedStorage.changestat:FireServer(tool.Name, true) end)
               count = count + 1
            end
         end
      end
      Rayfield:Notify({ Title = "Goober Hub", Content = "Unlocked " .. count .. " weapons", Duration = 3 })
   end
})

CombatTab:CreateSection("Arm Unlocker")

local armNames = {"Wooden", "Steel", "Bionic", "GodArm", "TimeArm", "Shock", "Static", "Void", "Streaklight", "Speedy"}
Flags.SelectedArm = armNames[1]

CombatTab:CreateDropdown({
   Name = "Unlock Arm",
   Options = armNames,
   CurrentOption = { armNames[1] },
   MultipleOptions = false,
   Flag = "Combat_SelectedArm",
   Callback = function(v) Flags.SelectedArm = v[1] or armNames[1] end
})

CombatTab:CreateButton({
   Name = "Unlock Selected Arm",
   Callback = function()
      local ls = LP:FindFirstChild("leaderstats")
      if not ls then return end
      local name = Flags.SelectedArm
      local bv = ls:FindFirstChild(name)
      if bv and bv:IsA("BoolValue") then
         bv.Value = true
      end
      pcall(function() ReplicatedStorage.changestat:FireServer(name, true) end)
      Rayfield:Notify({ Title = "Goober Hub", Content = "Unlocked: " .. name, Duration = 3 })
   end
})

CombatTab:CreateButton({
   Name = "Unlock All Arms",
   Callback = function()
      local ls = LP:FindFirstChild("leaderstats")
      if not ls then return end
      local count = 0
      for _, name in ipairs(armNames) do
         local bv = ls:FindFirstChild(name)
         if bv and bv:IsA("BoolValue") and not bv.Value then
            bv.Value = true
            pcall(function() ReplicatedStorage.changestat:FireServer(name, true) end)
            count = count + 1
         end
      end
      Rayfield:Notify({ Title = "Goober Hub", Content = "Unlocked " .. count .. " arms", Duration = 3 })
   end
})

CombatTab:CreateSection("Arm Equipment")

-- Maps: displayName -> { leaderstatsName, RS tool path }
local armEquipData = {
   ["Wooden Arm"]     = { stat = "Wooden",     tool = function() return ReplicatedStorage.Arms.WoodenArm end },
   ["Steel Arm"]      = { stat = "Steel",      tool = function() return ReplicatedStorage.Arms.SteelArm end },
   ["Bionic Arm"]     = { stat = "Bionic",     tool = function() return ReplicatedStorage.Arms.BionicArm end },
   ["Speedy Arm"]     = { stat = "Speedy",     tool = function() return ReplicatedStorage.Arms.SpeedyArm end },
   ["God's Arm"]      = { stat = "GodArm",     tool = function() return ReplicatedStorage:FindFirstChild("God's Arm") end },
   ["Time Arm"]       = { stat = "TimeArm",    tool = function() return ReplicatedStorage.TimeArm end },
   ["Shock Stunner"]  = { stat = "Shock",      tool = function() return ReplicatedStorage:FindFirstChild("Shock Stunner") end },
   ["Static Stunner"] = { stat = "Static",     tool = function() return ReplicatedStorage:FindFirstChild("Static Stunner") end },
   ["Void Stunner"]  = { stat = "Void",       tool = function() return ReplicatedStorage:FindFirstChild("Void Stunner") end },
   ["Streaklight"]    = { stat = "Streaklight", tool = function() return ReplicatedStorage:FindFirstChild("Streaklight Stunner") end },
}

local armEquipNames = {}
for name in pairs(armEquipData) do table.insert(armEquipNames, name) end
table.sort(armEquipNames)

Flags.SelectedArmEquip = armEquipNames[1]

CombatTab:CreateDropdown({
   Name = "Equip Arm",
   Options = armEquipNames,
   CurrentOption = { armEquipNames[1] },
   MultipleOptions = false,
   Flag = "Combat_ArmEquipV2",
   Callback = function(v) Flags.SelectedArmEquip = v[1] or armEquipNames[1] end
})

local function equipArm(name)
   local data = armEquipData[name]
   if not data then return false end
   local ls = LP:FindFirstChild("leaderstats")
   local owned = ls and ls:FindFirstChild(data.stat)
   if not owned or not owned.Value then
      Rayfield:Notify({ Title = "Goober Hub", Content = "You don't own: " .. name, Duration = 3 })
      return false
   end
   local tool = data.tool()
   if not tool then
      Rayfield:Notify({ Title = "Goober Hub", Content = "Tool not found for: " .. name, Duration = 3 })
      return false
   end
   local char = getChar()
   local bp = LP:FindFirstChild("Backpack")
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   if not (char and bp and hum) then return false end
   pcall(function() hum:UnequipTools() end)
   for _, t in ipairs(bp:GetChildren()) do
      if t:IsA("Tool") then pcall(function() t:Destroy() end) end
   end
   pcall(function() ReplicatedStorage.EquipTool:FireServer(bp, tool) end)
   task.wait(0.3)
   local clone = bp:FindFirstChild(tool.Name)
   if clone then clone.Parent = char end
   Rayfield:Notify({ Title = "Goober Hub", Content = "Equipped: " .. name, Duration = 2 })
   return true
end

CombatTab:CreateButton({
   Name = "Equip Selected Arm",
   Callback = function() equipArm(Flags.SelectedArmEquip) end
})

Flags.AutoEquipArm = false
CombatTab:CreateToggle({
   Name = "Auto Equip Arm",
   CurrentValue = false,
   Flag = "Combat_AutoEquipArm",
   Callback = function(v)
      Flags.AutoEquipArm = v
      if v then task.spawn(function() equipArm(Flags.SelectedArmEquip) end) end
   end
})

MovementTab:CreateSection("Movement")

local SpeedToggle = MovementTab:CreateToggle({
   Name = "Speed Hack",
   CurrentValue = false,
   Flag = "Movement_Speed",
   Callback = function(v)
      Flags.SpeedEnabled = v
      local hum = getHum()
      if hum then hum.WalkSpeed = v and Flags.Speed or 16 end
   end
})

local SpeedSlider = MovementTab:CreateSlider({
   Name = "Walk Speed",
   Range = { 16, 200 },
   Increment = 5,
   Suffix = "studs/s",
   CurrentValue = 16,
   Flag = "Movement_WalkSpeed",
   Callback = function(v)
      Flags.Speed = v
      if Flags.SpeedEnabled then
         local hum = getHum()
         if hum then hum.WalkSpeed = v end
      end
   end
})

local AntiFallToggle = MovementTab:CreateToggle({
   Name = "Anti Fall / Anti Knockback",
   CurrentValue = false,
   Flag = "Movement_AntiFall",
   Callback = function(v) Flags.AntiFall = v end
})

local GlideToggle = MovementTab:CreateToggle({
   Name = "Glide",
   CurrentValue = false,
   Flag = "Movement_Glide",
   Callback = function(v) Flags.Glide = v end
})

local GlideSlider = MovementTab:CreateSlider({
   Name = "Glide Speed",
   Range = { 1, 100 },
   Increment = 1,
   Suffix = "studs/s",
   CurrentValue = 20,
   Flag = "Movement_GlideSpeed",
   Callback = function(v) Flags.GlideSpeed = v end
})

local NoClipToggle = MovementTab:CreateToggle({
   Name = "No Clip (Walk Through Walls)",
   CurrentValue = false,
   Flag = "Movement_NoClip",
   Callback = function(v) Flags.NoClip = v end
})

MovementTab:CreateSection("Teleport")

MovementTab:CreateButton({
   Name = "Teleport to Mouse",
   Callback = function()
      local hrp = getHRP()
      if not hrp then return end
      local ray = Mouse.UnitRay
      local params = RaycastParams.new()
      params.FilterDescendantsInstances = { getChar() or {} }
      params.FilterType = Enum.RaycastFilterType.Exclude
      local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
      local pos = result and result.Position or ray.Origin + ray.Direction * 500
      tpTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
   end
})

MovementTab:CreateButton({
   Name = "Teleport to Nearest Target",
   Callback = function()
      local pos = getNearestTargetPos()
      if pos then tpTo(CFrame.new(pos + Vector3.new(0, 5, 0))) end
   end
})

VisualsTab:CreateSection("Visuals")

local ESPObjects = {}
local ESPConn = nil
local ESPEnabled = false

local function clearESP()
   for _, bg in pairs(ESPObjects) do
      pcall(function() bg:Destroy() end)
   end
   table.clear(ESPObjects)
end

local function updateESP()
   if ESPConn then ESPConn:Disconnect() ESPConn = nil end
   if not ESPEnabled then clearESP(); return end
   ESPConn = RunService.RenderStepped:Connect(function()
      for _, p in ipairs(Players:GetPlayers()) do
         if p == LP then continue end
         local char = p.Character
         if not char then
            if ESPObjects[p] then pcall(function() ESPObjects[p]:Destroy() end); ESPObjects[p] = nil end
            continue
         end
         local hrp = char:FindFirstChild("HumanoidRootPart")
         local hum = char:FindFirstChildOfClass("Humanoid")
         if not (hrp and hum and hum.Health > 0) then
            if ESPObjects[p] then pcall(function() ESPObjects[p]:Destroy() end); ESPObjects[p] = nil end
            continue
         end
         if not ESPObjects[p] then
            local bg = Instance.new("BillboardGui")
            bg.Name = "TSE_ESP"
            bg.Size = UDim2.new(0, 200, 0, 50)
            bg.AlwaysOnTop = true
            bg.StudsOffset = Vector3.new(0, 3, 0)
            bg.Adornee = hrp
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = p.Name .. "\n[" .. math.floor(hum.Health) .. " HP]"
            lbl.TextColor3 = Color3.new(1, 0, 0)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.TextStrokeTransparency = 0.5
            lbl.Parent = bg
            bg.Parent = hrp
            ESPObjects[p] = bg
         else
            local lbl = ESPObjects[p]:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.Text = p.Name .. "\n[" .. math.floor(hum.Health) .. " HP]" end
         end
      end
   end)
end

VisualsTab:CreateToggle({
   Name = "ESP",
   CurrentValue = false,
   Flag = "Visuals_ESP",
   Callback = function(v)
      ESPEnabled = v
      updateESP()
   end
})

ExploitsTab:CreateSection("Points Farm")

ExploitsTab:CreateToggle({
   Name = "Auto Points",
   CurrentValue = false,
   Flag = "Exploits_AutoPoints",
   Callback = function(v) Flags.AutoPoints = v end
})

ExploitsTab:CreateButton({
   Name = "Get Points Once (+100)",
   Callback = function()
      pcall(function() ReplicatedStorage.GetPoints:FireServer() end)
      Rayfield:Notify({ Title = "Goober Hub", Content = "+100 points", Duration = 1 })
   end
})

Rayfield:LoadConfiguration()

-- ===== CHARACTER RESPAWN HANDLER =====
-- Pause auto-farm while dead, re-equip after respawn
local respawnPending = false

table.insert(_G.__tsf.Connections, LP.CharacterAdded:Connect(function(newChar)
   respawnPending = true
   local ok, hum = pcall(function() return newChar:WaitForChild("Humanoid", 5) end)
   local ok2, hrp = pcall(function() return newChar:WaitForChild("HumanoidRootPart", 5) end)
   if not (ok and hum and ok2 and hrp) then respawnPending = false; return end
   task.wait(1)
   respawnPending = false
   if Flags.NoCooldown or Flags.AutoFarm then
      equipWeapon()
   end
   if Flags.AutoEquipArm then
      task.spawn(function() equipArm(Flags.SelectedArmEquip) end)
   end
end))

-- ===== RENDERED LOOP =====
local lastSafePos = nil

table.insert(_G.__tsf.Connections, RunService.RenderStepped:Connect(function()
   if not isAlive() then return end
   local char = getChar()
   local hum = getHum()
   local hrp = getHRP()
   if not (char and hum and hrp) then return end

   if Flags.NoCooldown then
      local cd = char:FindFirstChild("cooldown")
      if cd then cd.Value = 0 end
      local stun = char:FindFirstChild("Stun")
      if stun then stun.Value = 0 end
      local ragdolled = char:FindFirstChild("Ragdolled")
      if ragdolled then ragdolled.Value = false end
   end

   if Flags.SpeedEnabled then hum.WalkSpeed = Flags.Speed end

   if Flags.AntiFall then
      local ragdolled = char:FindFirstChild("Ragdolled")
      if ragdolled then ragdolled.Value = false end
      local stun = char:FindFirstChild("Stun")
      if stun then stun.Value = 0 end
      local cooldown = char:FindFirstChild("cooldown")
      if cooldown then cooldown.Value = 0 end
      hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
      hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
      hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
      hum.PlatformStand = false
      hum.Sit = false
      -- Save safe position when on ground
      local vel = hrp.AssemblyLinearVelocity
      local onGround = math.abs(vel.Y) < 2
      if hrp.Position.Y > -30 and onGround then
         lastSafePos = hrp.CFrame
      end
      -- Teleport back if falling into void
      if hrp.Position.Y < -35 and lastSafePos then
         char:PivotTo(lastSafePos + Vector3.new(0, 5, 0))
         hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
         hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
      else
         -- Only cancel knockback force
         local isKnockback = (math.abs(vel.X) > 20 or math.abs(vel.Z) > 20 or vel.Y < -30)
         if isKnockback then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
         end
      end
   end

   if Flags.Glide then
      local vel = hrp.AssemblyLinearVelocity
      if vel.Y < 0 then
         hrp.AssemblyLinearVelocity = Vector3.new(vel.X, -Flags.GlideSpeed, vel.Z)
      end
   end

   if Flags.NoClip then
      for _, part in ipairs(char:GetDescendants()) do
         if part:IsA("BasePart") then part.CanCollide = false end
      end
      hrp.CanCollide = false
   end
end))

-- ===== AUTO FARM LOOP =====
task.spawn(function()
   while _G.__tsfAlive do
      if not Flags.AutoFarm then
         task.wait(0.2)
         continue
      end

      if not isAlive() then
         LP.CharacterAdded:Wait()
         task.wait(1)
         lastSafePos = nil
         continue
      end

      local targetPos = getNearestTargetPos()
      if not targetPos then
         task.wait(0.2)
         continue
      end

      local tool = equipWeapon()
      if not tool then
         task.wait(0.2)
         continue
      end

      -- Re-verify tool right before throw (it can be destroyed by other players' hits)
      if not tool.Parent or not tool:FindFirstChild("RemoteFunction") then
         tool = equipWeapon()
         if not tool then
            task.wait(0.2)
            continue
         end
      end

      pcall(throwWeapon, tool, targetPos)

      task.wait(Flags.ThrowDelay)
   end
end)

-- ===== NO COOLDOWN LOOP =====
task.spawn(function()
   while _G.__tsfAlive and task.wait(0.3) do
      if not Flags.NoCooldown then continue end
      if respawnPending or not isAlive() then continue end

      local char = getChar()
      local cd = char:FindFirstChild("cooldown")
      if cd then cd.Value = 0 end

      -- Ensure we have the right weapon equipped
      local tool = getHRP() and char:FindFirstChildOfClass("Tool")
      if not tool then
         equipWeapon()
      end
   end
end)

-- ===== AUTO POINTS LOOP =====
table.insert(_G.__tsf.Connections, RunService.Heartbeat:Connect(function()
   if not Flags.AutoPoints then return end
   pcall(function() ReplicatedStorage.GetPoints:FireServer() end)
end))
