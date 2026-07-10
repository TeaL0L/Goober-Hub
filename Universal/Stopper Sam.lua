local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local SpeedEnabled = true
local AutoTeleportRed = false
local GreenMin = 0
local GreenMax = 100
local YellowMin = 100
local YellowMax = 120
local RedMin = 120
local RedMax = 999

local function GetColor(speed)
	if speed >= GreenMin and speed <= GreenMax then
		return Color3.fromRGB(0, 255, 120)
	elseif speed >= YellowMin and speed <= YellowMax then
		return Color3.fromRGB(255, 220, 0)
	else
		return Color3.fromRGB(255, 60, 60)
	end
end

local function CreateDisplay(player, character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end

	local old = head:FindFirstChild("SpeedDisplay")
	if old then old:Destroy() end

	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeedDisplay"
	gui.Size = UDim2.fromOffset(130, 30)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = math.huge
	gui.LightInfluence = 0
	gui.Parent = head

	local warnLabel = Instance.new("TextLabel")
	warnLabel.Size = UDim2.fromScale(1, 0.5)
	warnLabel.Position = UDim2.fromScale(0, 0)
	warnLabel.BackgroundTransparency = 1
	warnLabel.Font = Enum.Font.GothamBold
	warnLabel.TextScaled = true
	warnLabel.TextStrokeTransparency = 0.35
	warnLabel.Text = ""
	warnLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	warnLabel.Visible = false
	warnLabel.Parent = gui

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.fromScale(1, 0.5)
	speedLabel.Position = UDim2.fromScale(0, 0.5)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.TextScaled = true
	speedLabel.TextStrokeTransparency = 0.35
	speedLabel.Text = ""
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.Parent = gui

	local root = character:WaitForChild("HumanoidRootPart", 5)
	local lastPos = root and root.Position or Vector3.new()
	local lastTime = tick()

	task.spawn(function()
		while gui.Parent and character.Parent do
			if SpeedEnabled then
				root = character:FindFirstChild("HumanoidRootPart")
				if root then
					local now = tick()
					local dt = now - lastTime
					if dt > 0 then
						local dist = (root.Position - lastPos).Magnitude
						local speed = dist / dt
						local color = GetColor(speed)
						speedLabel.Text = string.format("%.1f studs/s", speed)
						speedLabel.TextColor3 = color
						if speed >= RedMin then
							warnLabel.Text = "WARNING DRUNK DRIVER"
							warnLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
							warnLabel.Visible = true
							if AutoTeleportRed then
								local lpChar = game:GetService("Players").LocalPlayer.Character
								local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
								if lpRoot then
									lpRoot.CFrame = root.CFrame * CFrame.new(0, 0, -5)
								end
							end
						else
							warnLabel.Visible = false
						end
					end
					lastPos = root.Position
					lastTime = now
				else
					speedLabel.Text = "--"
				end
			else
				speedLabel.Text = ""
				warnLabel.Visible = false
			end
			task.wait(0.1)
		end
	end)
end

local function SetupPlayer(player)
	if player.Character then
		CreateDisplay(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		CreateDisplay(player, character)
	end)
end

for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	SetupPlayer(player)
end
game:GetService("Players").PlayerAdded:Connect(SetupPlayer)

local Window = Rayfield:CreateWindow({
	Name = "Stopper Sam",
	Icon = 0,
	LoadingTitle = "Stopper Sam",
	LoadingSubtitle = "Player Speed Display",
	Theme = "Amethyst",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "StopperSam",
		FileName = "Config"
	},
	KeySystem = false
})

local MainTab = Window:CreateTab("Main", "gauge")

MainTab:CreateSection("Speed Display")

MainTab:CreateToggle({
	Name = "Stopper Sam activate",
	CurrentValue = true,
	Flag = "SpeedEnabled",
	Callback = function(Value)
		SpeedEnabled = Value
	end
})

MainTab:CreateLabel("Green " .. GreenMin .. "-" .. GreenMax, 0, Color3.fromRGB(0, 255, 120))
MainTab:CreateInput({ Name = "Green Min", CurrentValue = tostring(GreenMin), PlaceholderText = "0", Flag = "GreenMin", Callback = function(v) local n = tonumber(v) if n then GreenMin = n end end })
MainTab:CreateInput({ Name = "Green Max", CurrentValue = tostring(GreenMax), PlaceholderText = "100", Flag = "GreenMax", Callback = function(v) local n = tonumber(v) if n then GreenMax = n end end })

MainTab:CreateLabel("Yellow " .. YellowMin .. "-" .. YellowMax, 0, Color3.fromRGB(255, 220, 0))
MainTab:CreateInput({ Name = "Yellow Min", CurrentValue = tostring(YellowMin), PlaceholderText = "100", Flag = "YellowMin", Callback = function(v) local n = tonumber(v) if n then YellowMin = n end end })
MainTab:CreateInput({ Name = "Yellow Max", CurrentValue = tostring(YellowMax), PlaceholderText = "120", Flag = "YellowMax", Callback = function(v) local n = tonumber(v) if n then YellowMax = n end end })

MainTab:CreateLabel("Red " .. RedMin .. "-" .. RedMax, 0, Color3.fromRGB(255, 60, 60))
MainTab:CreateInput({ Name = "Red Min", CurrentValue = tostring(RedMin), PlaceholderText = "120", Flag = "RedMin", Callback = function(v) local n = tonumber(v) if n then RedMin = n end end })
MainTab:CreateInput({ Name = "Red Max", CurrentValue = tostring(RedMax), PlaceholderText = "999", Flag = "RedMax", Callback = function(v) local n = tonumber(v) if n then RedMax = n end end })

MainTab:CreateToggle({
	Name = "Auto Teleport to Red Players",
	CurrentValue = false,
	Flag = "AutoTeleportRed",
	Callback = function(val)
		AutoTeleportRed = val
	end
})

-- ESP
local ESPTab = Window:CreateTab("ESP", "eye")

ESPTab:CreateSection("ESP Settings")

local ESPEnabled = false
local ESPBoxes = true
local ESPNames = true
local ESPTracers = true
local ESPHealth = true
local ESPDistance = true

ESPTab:CreateToggle({
	Name = "ESP Enabled",
	CurrentValue = false,
	Flag = "ESPEnabled",
	Callback = function(v) ESPEnabled = v end
})

ESPTab:CreateToggle({
	Name = "Boxes",
	CurrentValue = true,
	Flag = "ESPBoxes",
	Callback = function(v) ESPBoxes = v end
})

ESPTab:CreateToggle({
	Name = "Names",
	CurrentValue = true,
	Flag = "ESPNames",
	Callback = function(v) ESPNames = v end
})

ESPTab:CreateToggle({
	Name = "Tracers",
	CurrentValue = true,
	Flag = "ESPTracers",
	Callback = function(v) ESPTracers = v end
})

ESPTab:CreateToggle({
	Name = "Health Bars",
	CurrentValue = true,
	Flag = "ESPHealth",
	Callback = function(v) ESPHealth = v end
})

ESPTab:CreateToggle({
	Name = "Distance",
	CurrentValue = true,
	Flag = "ESPDistance",
	Callback = function(v) ESPDistance = v end
})

ESPTab:CreateSection("Color")

local ESPUseTeamColor = true
local ESPCustomColor = Color3.fromRGB(255, 255, 255)

ESPTab:CreateToggle({
	Name = "Use Team Colors",
	CurrentValue = true,
	Flag = "ESPUseTeamColor",
	Callback = function(v) ESPUseTeamColor = v end
})

ESPTab:CreateColorPicker({
	Name = "Custom ESP Color",
	Color = ESPCustomColor,
	Flag = "ESPCustomColor",
	Callback = function(v) ESPCustomColor = v end
})

local ESPCache = {}

local function GetESPDrawing(player)
	if ESPCache[player] then return ESPCache[player] end
	local d = {
		Box = Drawing.new("Square"),
		Name = Drawing.new("Text"),
		Tracer = Drawing.new("Line"),
		HealthBar = Drawing.new("Square"),
		HealthBg = Drawing.new("Square"),
		Dist = Drawing.new("Text"),
	}
	d.Box.Thickness = 1.5
	d.Box.Filled = false
	d.Name.Center = true
	d.Name.Size = 14
	d.Name.Outline = true
	d.Name.Font = 2
	d.Tracer.Thickness = 1.5
	d.HealthBar.Thickness = 1
	d.HealthBar.Filled = true
	d.HealthBg.Thickness = 1
	d.HealthBg.Filled = true
	d.HealthBg.Color = Color3.fromRGB(30, 30, 30)
	d.HealthBg.Transparency = 0.3
	d.Dist.Center = true
	d.Dist.Size = 12
	d.Dist.Outline = true
	d.Dist.Font = 2
	ESPCache[player] = d
	return d
end

local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

RunService.RenderStepped:Connect(function()
	if not ESPEnabled then
		for _, d in pairs(ESPCache) do
			d.Box.Visible = false
			d.Name.Visible = false
			d.Tracer.Visible = false
			d.HealthBar.Visible = false
			d.HealthBg.Visible = false
			d.Dist.Visible = false
		end
		return
	end
	for _, p in pairs(Players:GetPlayers()) do
		if p == LocalPlayer then
			-- skip self
		elseif p.Character then
			local char = p.Character
			local root = char:FindFirstChild("HumanoidRootPart")
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local head = char:FindFirstChild("Head")
			if root and humanoid and head then
				local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
				if onScreen then
					local headPos, _ = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
					local feetPos, _ = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
					local boxHeight = (headPos.Y - feetPos.Y) * 1.2
					local boxWidth = boxHeight * 0.6
					local boxX = screenPos.X - boxWidth / 2
					local boxY = headPos.Y - boxHeight * 0.1

					local d = GetESPDrawing(p)
					local color = ESPUseTeamColor and p.TeamColor.Color or ESPCustomColor

					d.Box.Visible = ESPBoxes
					if ESPBoxes then
						d.Box.Color = color
						d.Box.Transparency = 0.8
						d.Box.Size = Vector2.new(boxWidth, boxHeight)
						d.Box.Position = Vector2.new(boxX, boxY)
					end

					d.Name.Visible = ESPNames
					if ESPNames then
						d.Name.Color = color
						d.Name.Position = Vector2.new(screenPos.X, boxY - 16)
						d.Name.Text = p.Name
					end

					d.Tracer.Visible = ESPTracers
					if ESPTracers then
						d.Tracer.Color = color
						d.Tracer.Transparency = 0.7
						d.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
						d.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
					end

					if ESPHealth then
						local hp = math.max(0, math.min(1, humanoid.Health / humanoid.MaxHealth))
						local barWidth = 4
						local barHeight = boxHeight * hp
						local barX = boxX - barWidth - 3
						local barY = boxY + boxHeight - barHeight
						d.HealthBg.Visible = true
						d.HealthBg.Size = Vector2.new(barWidth, boxHeight)
						d.HealthBg.Position = Vector2.new(barX, boxY)
						d.HealthBar.Visible = true
						d.HealthBar.Size = Vector2.new(barWidth, barHeight)
						d.HealthBar.Position = Vector2.new(barX, barY)
						d.HealthBar.Color = Color3.fromRGB(math.floor(255 * (1 - hp)), math.floor(255 * hp), 0)
					else
						d.HealthBar.Visible = false
						d.HealthBg.Visible = false
					end

					d.Dist.Visible = ESPDistance
					if ESPDistance then
						local lpChar = LocalPlayer.Character
						local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
						local dist = lpRoot and math.floor((lpRoot.Position - root.Position).Magnitude) or 0
						d.Dist.Color = color
						d.Dist.Position = Vector2.new(screenPos.X, feetPos.Y + 4)
						d.Dist.Text = tostring(dist) .. " studs"
					end
				end
			end
		end
	end
	for p, d in pairs(ESPCache) do
		if not Players:FindFirstChild(p.Name) then
			d.Box:Remove()
			d.Name:Remove()
			d.Tracer:Remove()
			d.HealthBar:Remove()
			d.HealthBg:Remove()
			d.Dist:Remove()
			ESPCache[p] = nil
		end
	end
end)

-- Misc
local MiscTab = Window:CreateTab("Misc", "terminal")
local LP = game:GetService("Players").LocalPlayer

MiscTab:CreateSection("Player Teleport")

local TeleportTarget = nil

local function BuildPlayerList()
	local options = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LP then
			table.insert(options, p.Name)
		end
	end
	return options
end

local PlayerDropdown = MiscTab:CreateDropdown({
	Name = "Target Player",
	Options = BuildPlayerList(),
	CurrentOption = {},
	MultipleOptions = false,
	Flag = "TeleportTarget",
	Callback = function(opts)
		TeleportTarget = opts[1]
	end
})

task.spawn(function()
	while true do
		task.wait(1)
		PlayerDropdown:Refresh(BuildPlayerList())
	end
end)

MiscTab:CreateButton({
	Name = "Teleport",
	Callback = function()
		if not TeleportTarget then return end
		local target = Players:FindFirstChild(TeleportTarget)
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		local lpRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if root and lpRoot then
			lpRoot.CFrame = root.CFrame * CFrame.new(0, 0, -5)
		end
	end
})

local LoopTeleportOn = false
local LoopTeleportThread = nil

MiscTab:CreateToggle({
	Name = "Loop Teleport",
	CurrentValue = false,
	Flag = "LoopTeleport",
	Callback = function(val)
		LoopTeleportOn = val
		if val then
			LoopTeleportThread = task.spawn(function()
				while LoopTeleportOn do
					if TeleportTarget then
						local target = Players:FindFirstChild(TeleportTarget)
						local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
						local lpRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
						if root and lpRoot then
							lpRoot.CFrame = root.CFrame * CFrame.new(0, 0, -5)
						end
					end
					task.wait(0.1)
				end
				LoopTeleportThread = nil
			end)
		end
	end
})

MiscTab:CreateSection("Other")

MiscTab:CreateButton({
	Name = "Isopibbler???",
	Callback = function()
		local url = "https://youtu.be/rjVVYZs-3LM?si=tlOYKSoOOvq1jpzu"
		setclipboard(url)
		Rayfield:Notify({
			Title = "Isopibbler???",
			Content = "Link copied to clipboard! Paste it in your browser.",
			Duration = 5,
			Image = "link"
		})
	end
})

MiscTab:CreateButton({
	Name = "Load Infinite Yield",
	Callback = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
	end
})

Rayfield:LoadConfiguration()
