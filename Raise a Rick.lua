-- Old connections handler
if getgenv().GooberHub then
    getgenv().GooberHub:Cleanup()
    task.wait(0.5)
end

getgenv().GooberHub = {
    Flags = {},
    Connections = {},
    Cleanup = function(self)
        for name in pairs(self.Flags) do
            _G[name] = false
        end
        for _, con in ipairs(self.Connections) do
            pcall(function() con:Disconnect() end)
        end
        table.clear(self.Connections)
    end
}

_G.RaRReady = false
_G.RaRStartTime = os.clock()

local function regFlag(name)
    getgenv().GooberHub.Flags[name] = true
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Goober Hub",
   LoadingTitle = "Goober Hub",
   LoadingSubtitle = "by Goober Pharmaceutical",
   ShowText = "Goober Hub",
   Theme = "Amethyst",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = true,
      FileName = "Goober_Hub_Config"
   },
   KeySystem = false
})

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local function getRickMain()
    return workspace:FindFirstChild("RickMain")
end

local productNames = {}
task.spawn(function()
    task.wait(8)
    local ok, allStuff = pcall(function()
        return player.PlayerGui:FindFirstChild("ShopUI") and player.PlayerGui.ShopUI:FindFirstChild("Main")
            and player.PlayerGui.ShopUI.Main:FindFirstChild("Scrolling")
            and player.PlayerGui.ShopUI.Main.Scrolling:FindFirstChild("AllStuff")
    end)
    if ok and allStuff then
        for _, item in pairs(allStuff:GetChildren()) do
            local ok2, priceVal = pcall(function() return item:FindFirstChild("PriceValue") end)
            local ok3, nameLabel = pcall(function() return item:FindFirstChild("ItemName") end)
            if ok2 and ok3 and nameLabel and nameLabel:IsA("TextLabel") then
                table.insert(productNames, {
                    name = nameLabel.Text,
                    price = priceVal.Value,
                    frame = item,
                    purchaseBtn = item:FindFirstChild("Purchase")
                })
            end
        end
        table.sort(productNames, function(a, b) return a.price < b.price end)
    end
end)

-- Tabs
local MainTab = Window:CreateTab("Main", "zap")
local CombatTab = Window:CreateTab("Combat", "shield")
local ESPTab = Window:CreateTab("Visuals", "eye")
local TeleportTab = Window:CreateTab("Teleport", "map-pin")
local MiscTab = Window:CreateTab("Misc", "settings")
local UpgradesTab = Window:CreateTab("Shop", "shopping-cart")

-- Main Tab
local FarmSection = MainTab:CreateSection("Auto Farm")

local autoClickToggle = MainTab:CreateToggle({
   Name = "Auto Click Rick",
   CurrentValue = false,
   Flag = "AutoClick",
   Callback = function(Value)
      _G.AutoClick = Value
       while _G.AutoClick do
           if not _G.RaRReady then task.wait(0.5) continue end
           local rickMain = getRickMain()
          if rickMain then
              local detector = rickMain:FindFirstChild("Click")
              if detector then fireclickdetector(detector) end
          end
          task.wait()
      end
   end
})

local autoCollectToggle = MainTab:CreateToggle({
   Name = "Auto Collect Money",
   CurrentValue = false,
   Flag = "AutoCollect",
   Callback = function(Value)
      _G.AutoCollect = Value
       while _G.AutoCollect do
           if not _G.RaRReady then task.wait(0.5) continue end
           local temp = workspace:FindFirstChild("Temporary")
          if temp then
              local char = player.Character
              local hrp = char and char:FindFirstChild("HumanoidRootPart")
              if hrp then
                  for _, money in ipairs(temp:GetChildren()) do
                      if money.Name == "Money" and money:FindFirstChild("TouchInterest") then
                          pcall(function()
                              firetouchinterest(money, hrp, 0)
                              firetouchinterest(money, hrp, 1)
                          end)
                      end
                  end
              end
          end
          task.wait(0.3)
      end
   end
})

local autoUnpackToggle = MainTab:CreateToggle({
   Name = "Auto Unpack Boxes",
   CurrentValue = false,
   Flag = "AutoUnpack",
   Callback = function(Value)
      _G.AutoUnpack = Value
       while _G.AutoUnpack do
           if not _G.RaRReady then task.wait(0.5) continue end
           local boxes = workspace:FindFirstChild("Boxes")
          if boxes then
              for _, box in ipairs(boxes:GetChildren()) do
                  if box:IsA("Model") then
                      local main = box:FindFirstChild("Main")
                      local prompt = main and main:FindFirstChild("Proximity")
                      if prompt and main.Position.Y <= 5 then
                          pcall(function() fireproximityprompt(prompt) end)
                          task.wait(prompt.HoldDuration)
                      end
                  end
              end
          end
          task.wait()
      end
   end
})

local autoFoodSection = MainTab:CreateSection("Food")

_G.MinFood = 2

local minFoodSlider = MainTab:CreateSlider({
   Name = "Minimum Food",
   Range = {0, 11},
   Increment = 1,
   Suffix = "food",
   CurrentValue = 2,
   Flag = "MinFood",
   Callback = function(Value)
      _G.MinFood = Value
   end
})

local autoBuyFood = MainTab:CreateToggle({
   Name = "Auto Buy Food (Leftover Hotdog)",
   CurrentValue = false,
   Flag = "AutoBuyFood",
   Callback = function(Value)
      _G.AutoBuyFood = Value
        while _G.AutoBuyFood do
            if not _G.RaRReady then task.wait(0.5) continue end
            -- Check fridge food count
           local fridge = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("Fridge")
           if not fridge then task.wait(3) continue end
           local spots = fridge:FindFirstChild("Spots")
           local filled = 0
           local total = 0
           if spots then
               for _, s in ipairs(spots:GetChildren()) do
                   total = total + 1
                   if #s:GetChildren() > 0 then filled = filled + 1 end
               end
           end

           -- Stop if full
           if filled >= 12 then
               _G.AutoBuyFood = false
               Rayfield:Notify({Title = "Auto Buy Food", Content = "Fridge is full! (" .. filled .. "/" .. total .. ")", Duration = 3, Image = "x"})
               break
           end

           -- Skip cycle if enough food (above threshold)
           if filled > (_G.MinFood or 2) then
               task.wait(5)
               continue
           end

            -- Need to restock: calculate how many needed
            local needed = 12 - filled

            -- First, use any hotdogs already in inventory
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            for _ = 1, needed do
                if not _G.AutoBuyFood then break end
                local hotdog = player.Backpack:FindFirstChild("Hotdog")
                if not hotdog then
                    hotdog = char and char:FindFirstChild("Hotdog")
                end
                if not hotdog then break end
                -- Equip it
                if hotdog.Parent == player.Backpack then
                    hotdog.Parent = char
                    task.wait()
                end
                if not hrp then task.wait(1) break end
                -- TP to fridge
                local mainClosed = fridge:FindFirstChild("MainClosed")
                if not mainClosed then task.wait(1) break end
                hrp.CFrame = CFrame.new(-81.4, 5.75, -46)
                task.wait()
                -- Open door if closed
                local foodPrompt = mainClosed:FindFirstChild("FoodPrompt")
                if not (foodPrompt and foodPrompt.Enabled) then
                    local doorPrompt = mainClosed:FindFirstChild("Attachment") and mainClosed.Attachment:FindFirstChild("Prompt")
                    if doorPrompt and doorPrompt.Enabled then
                        pcall(fireproximityprompt, doorPrompt)
                        task.wait(0.5)
                    end
                end
                -- Fill fridge
                foodPrompt = mainClosed:FindFirstChild("FoodPrompt")
                if foodPrompt and foodPrompt.Enabled then
                    pcall(fireproximityprompt, foodPrompt)
                end
                task.wait(1)
            end

            -- Recheck fridge count after using inventory hotdogs
            local refilled = 0
            if spots then
                for _, s in ipairs(spots:GetChildren()) do
                    if #s:GetChildren() > 0 then refilled = refilled + 1 end
                end
            end
            needed = 12 - refilled
            if needed <= 0 then task.wait(2) continue end

            -- Buy remaining needed hotdogs from gas station
            for _ = 1, needed do
                if not _G.AutoBuyFood then break end
                char = player.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(1) break end

                local items = workspace:FindFirstChild("GasStation") and workspace.GasStation:FindFirstChild("Items")
                if items then
                    for _, item in ipairs(items:GetChildren()) do
                        if item.Name == "Hotdog_Item" then
                            local prompt = item:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and prompt.Enabled then
                                hrp.CFrame = item.CFrame * CFrame.new(0, 0, 2)
                                task.wait(0.3)
                                pcall(fireproximityprompt, prompt)
                                for _ = 1, 20 do
                                    task.wait(0.1)
                                    if player.Backpack:FindFirstChild("Hotdog") then break end
                                end
                                break
                            end
                        end
                    end
                end

                -- Equip hotdog
                local hotdog = player.Backpack:FindFirstChild("Hotdog")
                if hotdog then
                    hotdog.Parent = char
                    task.wait()
                end

                -- TP to fridge
                local mainClosed = fridge:FindFirstChild("MainClosed")
                if not mainClosed then task.wait(1) break end

                hrp.CFrame = CFrame.new(-81.4, 5.75, -46)
                task.wait()

                -- Open door if closed
                local foodPrompt = mainClosed:FindFirstChild("FoodPrompt")
                if not (foodPrompt and foodPrompt.Enabled) then
                    local doorPrompt = mainClosed:FindFirstChild("Attachment") and mainClosed.Attachment:FindFirstChild("Prompt")
                    if doorPrompt and doorPrompt.Enabled then
                        pcall(fireproximityprompt, doorPrompt)
                        task.wait(0.5)
                    end
                end

                -- Fill fridge
                foodPrompt = mainClosed:FindFirstChild("FoodPrompt")
                if foodPrompt and foodPrompt.Enabled then
                    pcall(fireproximityprompt, foodPrompt)
                end

                 task.wait(1)
             end
             task.wait(2)
       end
    end
})

local FuelSection = MainTab:CreateSection("Fuel")

local autoFuelToggle = MainTab:CreateToggle({
   Name = "Auto Fuel Heater",
   CurrentValue = false,
   Flag = "AutoFuel",
   Callback = function(Value)
      _G.AutoFuel = Value
       while _G.AutoFuel do
           if not _G.RaRReady then task.wait(0.5) continue end
           local char = player.Character
           local hrp = char and char:FindFirstChild("HumanoidRootPart")
           if not hrp then task.wait(1) continue end

           local fuel = game.ReplicatedStorage.Stats:FindFirstChild("HeaterFuel")
           if fuel and fuel.Value <= 50 then
               local main = workspace.MainHeater:FindFirstChild("Main")
               local prompt = main and main:FindFirstChild("Prompt")
               if prompt and prompt.Enabled then
                   hrp.CFrame = main.CFrame * CFrame.new(0, 0, 3)
                   task.wait(0.3)
                   pcall(fireproximityprompt, prompt)
                   task.wait(1)
               end
           end
           task.wait(5)
       end
   end
})

local MainInfoSection = MainTab:CreateSection("Info")

local stats = game.ReplicatedStorage:WaitForChild("Stats")
local moneyLabel = MainTab:CreateLabel("Money: " .. tostring(stats.Money and stats.Money.Value or 0))
local gemsLabel = MainTab:CreateLabel("Gems: 0")
local dayLabel = MainTab:CreateLabel("Day: " .. tostring(stats.Day and stats.Day.Value or 0))
local foodLabel = MainTab:CreateLabel("Food: " .. tostring(stats.FoodAmount and stats.FoodAmount.Value or 0))
local fuelLabel = MainTab:CreateLabel("Heater Fuel: " .. tostring(stats.HeaterFuel and stats.HeaterFuel.Value or 0))
local multLabel = MainTab:CreateLabel("Multiplier: " .. tostring(stats.Multiplier and stats.Multiplier.Value or 0))

local function getGemsText()
    local gemsUI = player.PlayerGui.MainUI.Currency.Gems:FindFirstChildOfClass("TextLabel")
    return gemsUI and gemsUI.Text or "0"
end

coroutine.wrap(function()
    while task.wait(1) do
        pcall(function() moneyLabel:Set("Money: " .. tostring(stats.Money.Value)) end)
        pcall(function() gemsLabel:Set("Gems: " .. getGemsText()) end)
        pcall(function() dayLabel:Set("Day: " .. tostring(stats.Day.Value)) end)
        pcall(function() foodLabel:Set("Food: " .. tostring(stats.FoodAmount.Value)) end)
        pcall(function() fuelLabel:Set("Heater Fuel: " .. tostring(stats.HeaterFuel.Value)) end)
        pcall(function() multLabel:Set("Multiplier: " .. tostring(stats.Multiplier.Value)) end)
    end
end)()

-- Upgrades/Shop Tab
local ShopSection = UpgradesTab:CreateSection("Auto Purchase")

local autoBuyToggle = UpgradesTab:CreateToggle({
   Name = "Auto Buy Cheapest Upgrade",
   CurrentValue = false,
   Flag = "AutoBuy",
   Callback = function(Value)
      _G.AutoBuy = Value
       while _G.AutoBuy do
           if not _G.RaRReady then task.wait(0.5) continue end
           local best = nil
          for _, item in ipairs(productNames) do
              if item.price <= stats.Money.Value and item.price <= (_G.MaxBuyPrice or 50000) then
                  local purchased = item.frame:FindFirstChild("Purchased")
                  local locked = item.frame:FindFirstChild("Locked")
                  if not purchased and not locked then
                      best = item
                      break
                  end
              end
          end
          if best and best.purchaseBtn then
              local purchaseFunc = game.ReplicatedStorage.Events:FindFirstChild("Purchase")
              if purchaseFunc and purchaseFunc.ClassName == "RemoteFunction" then
                  pcall(function() purchaseFunc:InvokeServer(best.name) end)
              end
          end
          task.wait(1)
      end
   end
})

local maxBuyPrice = UpgradesTab:CreateSlider({
   Name = "Max Purchase Price",
   Range = {1000, 1000000},
   Increment = 1000,
   Suffix = "$",
   CurrentValue = 50000,
   Flag = "MaxBuyPrice",
   Callback = function(Value)
      _G.MaxBuyPrice = Value
   end
})
_G.MaxBuyPrice = 50000

local buySpecificSection = UpgradesTab:CreateSection("Buy Specific Item")

local itemDropdown = UpgradesTab:CreateDropdown({
   Name = "Select Item",
   Options = {},
   CurrentOption = {},
   MultipleOptions = false,
   Flag = "ItemSelect",
   Callback = function(Option)
      _G.SelectedItem = Option[1]
   end
})

do
    local names = {}
    for _, item in ipairs(productNames) do
        table.insert(names, item.name)
    end
    itemDropdown:Refresh(names)
end

local buyNowBtn = UpgradesTab:CreateButton({
   Name = "Buy Selected Item",
   Callback = function()
      if _G.SelectedItem then
          local purchaseFunc = game.ReplicatedStorage.Events:FindFirstChild("Purchase")
          if purchaseFunc and purchaseFunc.ClassName == "RemoteFunction" then
              pcall(function() purchaseFunc:InvokeServer(_G.SelectedItem) end)
          end
      end
   end
})

-- Combat Tab
local CombatSection = CombatTab:CreateSection("Auto Defense")

local autoKillThieves = CombatTab:CreateToggle({
   Name = "Auto Kill Thieves",
   CurrentValue = false,
   Flag = "AutoKillThieves",
   Callback = function(Value)
      _G.AutoKillThieves = Value
        while _G.AutoKillThieves do
            if not _G.RaRReady then task.wait(0.5) continue end
            local thieves = workspace:FindFirstChild("Thieves")
           if thieves then
               local t2 = thieves:FindFirstChild("Thieves")
               if t2 then
                   local dmgEvent = game.ReplicatedStorage.Events:FindFirstChild("playerDamage")
                   if dmgEvent then
                       for _, thief in pairs(t2:GetChildren()) do
                           local humanoid = thief:FindFirstChildOfClass("Humanoid")
                           if humanoid and humanoid.Health > 0 then
                               pcall(function() dmgEvent:FireServer(thief, 99999) end)
                           end
                       end
                   end
               end
           end
           task.wait(0.5)
       end
   end
})

-- ESP Tab renamed to Visuals
local ESPSection = ESPTab:CreateSection("ESP Settings")

local function createESP(obj, color, label)
    if not obj then return end
    if _G.ESPObjects[obj] then
        if _G.ESPObjects[obj].Parent then
            return
        else
            _G.ESPObjects[obj] = nil
        end
    end
    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP"
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 8, 0, 8)
    bg.StudsOffset = Vector3.new(0, 3, 0)
    bg.Adornee = obj
    bg.Parent = obj
    bg.ClipsDescendants = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
    frame.Parent = bg

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 0, 20)
    txt.Position = UDim2.new(0, 0, -0.5, -10)
    txt.BackgroundTransparency = 1
    txt.Text = label or ""
    txt.TextColor3 = Color3.fromRGB(255, 255, 255)
    txt.TextStrokeTransparency = 0
    txt.TextSize = 14
    txt.Font = Enum.Font.GothamBold
    txt.Parent = bg

    _G.ESPObjects[obj] = bg
end

_G.ESPObjects = {}

local thiefESP = ESPTab:CreateToggle({
   Name = "Thief ESP",
   CurrentValue = false,
   Flag = "ThiefESP",
   Callback = function(Value)
      _G.ThiefESP = Value
      if not Value then
          for obj, _ in pairs(_G.ESPObjects) do
              if obj and obj.Name == "Thief" then
                  if _G.ESPObjects[obj] then
                      _G.ESPObjects[obj]:Destroy()
                      _G.ESPObjects[obj] = nil
                  end
              end
          end
      end
       while _G.ThiefESP do
           if not _G.RaRReady then task.wait(0.5) continue end
           local thieves = workspace:FindFirstChild("Thieves")
          if thieves then
              local t2 = thieves:FindFirstChild("Thieves")
              if t2 then
                  for _, thief in pairs(t2:GetChildren()) do
                      createESP(thief, Color3.fromRGB(255, 0, 0), "Thief")
                  end
              end
          end
          task.wait(2)
      end
   end
})

local VisualsSection = ESPTab:CreateSection("Lighting")

local brightLoop = nil
local RunService = game:GetService("RunService")

local fullbright = ESPTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(Value)
      _G.Fullbright = Value
      if brightLoop then
          brightLoop:Disconnect()
          brightLoop = nil
      end
      if Value then
          local function brightFunc()
              local Lighting = game:GetService("Lighting")
              Lighting.Brightness = 2
              Lighting.ClockTime = 14
              Lighting.FogEnd = 100000
              Lighting.GlobalShadows = false
              Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
          end
          brightLoop = RunService.RenderStepped:Connect(brightFunc)
      end
   end
})

local noFog = ESPTab:CreateToggle({
   Name = "Remove Fog",
   CurrentValue = false,
   Flag = "NoFog",
   Callback = function(Value)
      _G.NoFog = Value
      if Value then
          local Lighting = game:GetService("Lighting")
          Lighting.FogEnd = 100000
          for i,v in pairs(Lighting:GetDescendants()) do
              if v:IsA("Atmosphere") then
                  v:Destroy()
              end
          end
      end
   end
})

-- Teleport Tab
local TeleportSection = TeleportTab:CreateSection("Locations")

local tpToRick = TeleportTab:CreateButton({
   Name = "Teleport to Rick",
   Callback = function()
      local rickMain = getRickMain()
      local hrp = rickMain and rickMain:FindFirstChild("HumanoidRootPart")
      if hrp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
          player.Character.HumanoidRootPart.CFrame = hrp.CFrame + Vector3.new(0, 3, 3)
      end
   end
})

local tpToCave = TeleportTab:CreateButton({
   Name = "Teleport to Cave",
   Callback = function()
       if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
           player.Character.HumanoidRootPart.CFrame = CFrame.new(-275, 4, -303)
       end
   end
})

local tpToHouse = TeleportTab:CreateButton({
   Name = "Teleport to House",
   Callback = function()
       if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
           player.Character.HumanoidRootPart.CFrame = CFrame.new(-31, 5, -85)
       end
   end
})

local tpToShop = TeleportTab:CreateButton({
   Name = "Teleport to Shop",
   Callback = function()
       if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
           player.Character.HumanoidRootPart.CFrame = CFrame.new(-93, 5, 287)
       end
   end
})

local tpToCaveInside = TeleportTab:CreateButton({
   Name = "Teleport to Cave Inside",
   Callback = function()
       if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
           player.Character.HumanoidRootPart.CFrame = CFrame.new(-263, -284, 257)
       end
   end
})

-- Misc Tab
local IYSection = MiscTab:CreateSection("Admin")

local loadIY = MiscTab:CreateButton({
   Name = "Load Infinite Yield",
   Callback = function()
       loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
   end
})

local AntiAfkSection = MiscTab:CreateSection("Anti AFK")

local antiAfk = MiscTab:CreateToggle({
   Name = "Anti AFK",
   CurrentValue = false,
   Flag = "AntiAfk",
   Callback = function(Value)
      _G.AntiAfk = Value
       while _G.AntiAfk do
           if not _G.RaRReady then task.wait(0.5) continue end
           local virtualUser = game:GetService("VirtualUser")
          virtualUser:CaptureController()
          virtualUser:ClickButton2(Vector2.new())
          task.wait(60)
      end
   end
})

regFlag("AutoClick")
regFlag("AutoCollect")
regFlag("AutoBuy")
regFlag("AutoKillThieves")
regFlag("ThiefESP")
regFlag("AutoUnpack")
regFlag("AutoBuyFood")
regFlag("NoFog")
regFlag("AntiAfk")

Rayfield:LoadConfiguration()

task.delay(8, function() _G.RaRReady = true end)

Rayfield:Notify({
    Title = "Goober Hub",
   Content = "Loaded successfully! Press K to toggle UI.",
   Duration = 5,
   Image = "zap"
})
