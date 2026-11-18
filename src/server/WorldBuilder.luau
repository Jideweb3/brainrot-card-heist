-- WorldBuilder.luau
-- Builds the whole physical place in code: plaza, giant card machine,
-- eight bases, eight card stands per base (the last two start locked
-- behind rebirths), a rebirth pad and a lock pad per base, a shield dome
-- per base, lights and signs.

local CardData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CardData"))

local WorldBuilder = {}

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material or Enum.Material.SmoothPlastic
	if part.Material == Enum.Material.Neon then
		-- Owner phone feedback: full-strength neon reads far too shiny, so
		-- every neon part in the world is born at 55% colour.
		color = Color3.new(color.R * 0.55, color.G * 0.55, color.B * 0.55)
	end
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeTextFace(part, text, textColor, backgroundColor, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TextFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.04, 0)
	padding.PaddingBottom = UDim.new(0.04, 0)
	padding.Parent = label

	if textSize then
		label.TextScaled = false
		label.TextSize = textSize
	end

	return label
end

local function makeLamp(parent, position, color)
	local pole = makePart(parent, "LampPole", Vector3.new(0.45, 7, 0.45), CFrame.new(position + Vector3.new(0, 3.5, 0)), Color3.fromRGB(35, 38, 52), Enum.Material.Metal)
	local head = makePart(parent, "LampGlow", Vector3.new(1.4, 1.4, 1.4), CFrame.new(position + Vector3.new(0, 7.4, 0)), color, Enum.Material.Neon)
	head.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = head
	return pole
end

function WorldBuilder.Build(workspace)
	-- One ground only: the grass slab built below is it. Kill any stray
	-- template baseplate a Studio save may have left behind in the place.
	local strayBaseplate = workspace:FindFirstChild("Baseplate")
	if strayBaseplate then
		strayBaseplate:Destroy()
	end

	-- Soft cloud layer, so the sky has some life in screenshots. Clouds
	-- only exist as a Terrain child; the pcall keeps an engine quirk here
	-- from ever breaking the build.
	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			local clouds = Instance.new("Clouds")
			clouds.Cover = 0.5
			clouds.Density = 0.45
			clouds.Color = Color3.fromRGB(255, 255, 255)
			clouds.Parent = terrain
		end
	end)

	local old = workspace:FindFirstChild("BrainrotCardHeist")
	if old then
		old:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "BrainrotCardHeist"
	world.Parent = workspace

	local activeCards = Instance.new("Folder")
	activeCards.Name = "ActiveCards"
	activeCards.Parent = world

	local plaza = makePart(world, "Plaza", Vector3.new(170, 1, 170), CFrame.new(0, 0, 0), Color3.fromRGB(43, 47, 70), Enum.Material.SmoothPlastic)
	plaza.Name = "Plaza"

	-- Bright grass everywhere else, so the world never reads as a bare
	-- baseplate: a full-size ground slab just under the plaza top.
	makePart(world, "Ground", Vector3.new(512, 1, 512), CFrame.new(0, -0.1, 0), Color3.fromRGB(86, 178, 84), Enum.Material.SmoothPlastic)

	local ring = makePart(world, "MachineRing", Vector3.new(38, 0.35, 38), CFrame.new(0, 0.68, 0), Color3.fromRGB(255, 196, 66), Enum.Material.Neon)
	ring.CanCollide = false

	-- Sunburst rays underfoot around the machine. The eight base paths
	-- leave at the base angles (0, 45, 90...), so the rays sit half a
	-- step off them (11.25 degrees) and never cross a walkway.
	for rayIndex = 1, 16 do
		local rayAngle = math.rad((rayIndex - 1) * 22.5 + 11.25)
		local rayPos = Vector3.new(math.sin(rayAngle) * 36, 0.53, math.cos(rayAngle) * 36)
		local rayColor = rayIndex % 2 == 1 and Color3.fromRGB(240, 180, 70) or Color3.fromRGB(105, 70, 200)
		local ray = makePart(world, "PlazaRay", Vector3.new(4.2, 0.1, 30), CFrame.new(rayPos) * CFrame.Angles(0, rayAngle, 0), rayColor, Enum.Material.SmoothPlastic)
		ray.CanCollide = false
	end

	-- A neutral Roblox spawn keeps a fresh character out of the machine while
	-- the server assigns a base and teleports them to it.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1.1, 28)
	spawn.Material = Enum.Material.Neon
	-- Built by hand rather than via makePart, so it gets the same 55%
	-- neon dimming applied here.
	local spawnColor = Color3.fromRGB(70, 220, 160)
	spawn.Color = Color3.new(spawnColor.R * 0.55, spawnColor.G * 0.55, spawnColor.B * 0.55)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.25
	spawn.Neutral = true
	spawn.Parent = world

	-- Giant card machine.
	local machine = Instance.new("Model")
	machine.Name = "GiantCardMachine"
	machine.Parent = world

	makePart(machine, "MachineBase", Vector3.new(16, 1.4, 11), CFrame.new(0, 1.2, 0), Color3.fromRGB(36, 38, 58), Enum.Material.Metal)
	makePart(machine, "MachineBody", Vector3.new(12, 10, 7), CFrame.new(0, 6.4, 0), Color3.fromRGB(255, 91, 122), Enum.Material.SmoothPlastic)
	local glass = makePart(machine, "CardChamber", Vector3.new(8.5, 6.2, 0.35), CFrame.new(0, 6.1, 3.72), Color3.fromRGB(120, 225, 255), Enum.Material.Glass)
	glass.Transparency = 0.45
	glass.CanCollide = false

	local machineSign = makePart(machine, "MachineSign", Vector3.new(15, 2.6, 0.45), CFrame.new(0, 12.7, 3.55), Color3.fromRGB(24, 22, 44), Enum.Material.Neon)
	makeTextFace(machineSign, "BRAINROT CARD MACHINE", Color3.fromRGB(255, 235, 130), Color3.fromRGB(24, 22, 44))

	local sampleCard = makePart(machine, "SampleCard", Vector3.new(3.4, 4.8, 0.22), CFrame.new(0, 6.1, 3.45) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 196, 66), Enum.Material.Neon)
	sampleCard.CanCollide = false
	makeTextFace(sampleCard, "?", Color3.fromRGB(45, 30, 0), Color3.fromRGB(255, 196, 66), 72)

	local lever = makePart(machine, "PullLever", Vector3.new(0.9, 3.2, 0.9), CFrame.new(5.3, 4.7, 4.15) * CFrame.Angles(math.rad(18), 0, 0), Color3.fromRGB(255, 55, 75), Enum.Material.Neon)
	lever.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PullPrompt"
	prompt.ActionText = "Pull a Card"
	prompt.ObjectText = string.format("$%d Card Machine", CardData.PullCost)
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = lever

	makePart(machine, "OutputPlatform", Vector3.new(9, 0.7, 5), CFrame.new(0, 0.9, 7.5), Color3.fromRGB(70, 220, 160), Enum.Material.Neon)

	local machineRefs = {
		Model = machine,
		Prompt = prompt,
		OutputCFrame = CFrame.new(0, 4.1, 7.5) * CFrame.Angles(0, math.pi, 0),
	}

	-- Neon bollards ringing the machine, alternating pink and yellow.
	for bollardIndex = 1, 6 do
		local bollardAngle = math.rad((bollardIndex - 1) * 60 + 30)
		local bollardPos = Vector3.new(math.sin(bollardAngle) * 13, 1.3, math.cos(bollardAngle) * 13)
		local bollardColor = bollardIndex % 2 == 1 and Color3.fromRGB(255, 91, 122) or Color3.fromRGB(255, 196, 66)
		local bollard = makePart(world, "Bollard", Vector3.new(0.5, 1.6, 0.5), CFrame.new(bollardPos), bollardColor, Enum.Material.Neon)
		bollard.CanCollide = false
	end

	-- Gentle gold sparkles drifting up off the machine: one emitter on an
	-- invisible part, low rate, purely decorative.
	local sparkleSource = makePart(machine, "SparkleSource", Vector3.new(1, 1, 1), CFrame.new(0, 12.4, 4.5), Color3.fromRGB(255, 214, 110), Enum.Material.SmoothPlastic)
	sparkleSource.Transparency = 1
	sparkleSource.CanCollide = false
	local machineSparkles = Instance.new("ParticleEmitter")
	machineSparkles.Name = "MachineSparkles"
	machineSparkles.Rate = 6
	machineSparkles.Lifetime = NumberRange.new(1.6, 2.6)
	machineSparkles.Speed = NumberRange.new(1.2, 1.2)
	machineSparkles.SpreadAngle = Vector2.new(25, 25)
	machineSparkles.Color = ColorSequence.new(Color3.fromRGB(255, 214, 110))
	machineSparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	machineSparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	machineSparkles.LightEmission = 0.6
	machineSparkles.Parent = sparkleSource

	-- Hero hologram: a giant translucent card floating above the machine,
	-- so the centre of the map reads as an event from anywhere. Built
	-- still at its home CFrame; GameServer spins and bobs it from there.
	local holoHome = CFrame.new(0, 23, 0)
	local holoCard = Instance.new("Model")
	holoCard.Name = "HoloCard"
	holoCard.Parent = world
	local holoTrim = makePart(holoCard, "GlowTrim", Vector3.new(7, 9.4, 0.14), holoHome * CFrame.new(0, 0, 0.12), Color3.fromRGB(255, 196, 66), Enum.Material.Neon)
	holoTrim.CanCollide = false
	local holoBody = makePart(holoCard, "HoloBody", Vector3.new(6.4, 8.8, 0.3), holoHome, Color3.fromRGB(120, 80, 255), Enum.Material.SmoothPlastic)
	holoBody.Transparency = 0.15
	holoBody.CanCollide = false
	holoCard.PrimaryPart = holoBody
	local holoLabel = makeTextFace(holoBody, "🦈", Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 80, 255))
	-- Let the shark art ghost through the face behind the emoji.
	holoLabel.BackgroundTransparency = 0.45
	local tralalero = CardData.CardsById["tralalero_tralala"]
	if tralalero and tralalero.ImageId and tralalero.ImageId > 0 then
		local holoArt = Instance.new("Decal")
		holoArt.Name = "HoloArt"
		holoArt.Texture = "rbxassetid://" .. tralalero.ImageId
		holoArt.Face = Enum.NormalId.Front
		holoArt.Transparency = 0.2
		holoArt.Parent = holoBody
	end

	-- Eight bases around the machine.
	local bases = {}
	local baseColors = {
		Color3.fromRGB(255, 107, 107), Color3.fromRGB(255, 166, 66), Color3.fromRGB(255, 224, 102),
		Color3.fromRGB(107, 220, 145), Color3.fromRGB(72, 202, 228), Color3.fromRGB(84, 126, 255),
		Color3.fromRGB(178, 102, 255), Color3.fromRGB(255, 102, 178),
	}

	for baseIndex = 1, 8 do
		local angle = math.rad((baseIndex - 1) * 45)
		local position = Vector3.new(math.sin(angle) * 62, 0, math.cos(angle) * 62)
		local baseCFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
		local baseModel = Instance.new("Model")
		baseModel.Name = "Base" .. baseIndex
		baseModel:SetAttribute("BaseIndex", baseIndex)
		baseModel.Parent = world

		local accent = baseColors[baseIndex]
		-- A real square base, not a flat pad: a 34x34 floor inside proper
		-- walls, with a laser doorway in the front wall as the only way in.
		makePart(baseModel, "Floor", Vector3.new(34, 1, 34), baseCFrame * CFrame.new(0, 0.55, 0), accent, Enum.Material.SmoothPlastic)

		local wallColor = Color3.fromRGB(37, 42, 58)
		local function makeWall(name, size, offset)
			makePart(baseModel, name, size, baseCFrame * offset, wallColor, Enum.Material.Metal)
			local trimSize = Vector3.new(size.X == 0.7 and 0.95 or size.X + 0.25, 0.3, size.Z == 0.7 and 0.95 or size.Z + 0.25)
			local trim = makePart(baseModel, name .. "Trim", trimSize, baseCFrame * CFrame.new(offset.X, 8.15, offset.Z), accent, Enum.Material.Neon)
			trim.CanCollide = false
		end
		makeWall("BackWall", Vector3.new(34, 7, 0.7), CFrame.new(0, 4.5, 16.6))
		makeWall("LeftWall", Vector3.new(0.7, 7, 34), CFrame.new(-16.6, 4.5, 0))
		makeWall("RightWall", Vector3.new(0.7, 7, 34), CFrame.new(16.6, 4.5, 0))
		-- Front wall: two segments leaving a 7-wide doorway in the centre.
		makeWall("FrontWallLeft", Vector3.new(13.5, 7, 0.7), CFrame.new(-10.25, 4.5, -16.6))
		makeWall("FrontWallRight", Vector3.new(13.5, 7, 0.7), CFrame.new(10.25, 4.5, -16.6))

		-- Laser door: red neon bars across the doorway over an invisible
		-- blocker. The blocker stops everyone; the owner's client turns it
		-- off locally and paints the bars green (see Game.client.luau).
		for barIndex = 1, 4 do
			local barX = -2.625 + (barIndex - 1) * 1.75
			local bar = makePart(baseModel, "LaserBar", Vector3.new(0.35, 6.6, 0.35), baseCFrame * CFrame.new(barX, 4.35, -16.6), Color3.fromRGB(255, 45, 60), Enum.Material.Neon)
			bar.CanCollide = false
		end
		local laserWall = makePart(baseModel, "LaserWall", Vector3.new(7, 7, 0.7), baseCFrame * CFrame.new(0, 4.5, -16.6), Color3.fromRGB(255, 45, 60), Enum.Material.SmoothPlastic)
		laserWall.Transparency = 1
		local doorHeader = makePart(baseModel, "DoorHeader", Vector3.new(7.4, 0.5, 0.9), baseCFrame * CFrame.new(0, 7.75, -16.6), accent, Enum.Material.Neon)
		doorHeader.CanCollide = false

		local sign = makePart(baseModel, "OwnerSign", Vector3.new(15, 3, 0.45), baseCFrame * CFrame.new(0, 5.4, 11.5), Color3.fromRGB(24, 22, 44), Enum.Material.Neon)
		local signLabel = makeTextFace(sign, "BASE " .. baseIndex, Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 22, 44))

		-- A proud banner over the front doorway in the base's colour, so a
		-- claimed base photographs like a fortress. GameServer writes the
		-- owner's name onto BannerLabel alongside the sign. The z sits a
		-- touch proud of the front wall (-16.6) so the whole banner face
		-- stays visible instead of sinking into the wall segments.
		local banner = makePart(baseModel, "BaseBanner", Vector3.new(10.5, 2.2, 0.3), baseCFrame * CFrame.new(0, 8.2, -17.1), accent, Enum.Material.SmoothPlastic)
		banner.CanCollide = false
		local bannerLabel = makeTextFace(banner, "BASE " .. baseIndex, Color3.fromRGB(255, 255, 255), accent)

		-- A thin matte-gold trim strip flush under the banner's bottom
		-- edge (banner centre y 8.2, half-height 1.1, so its bottom edge
		-- is y 7.1; the 0.35-tall strip centres at 7.1 - 0.175 = 6.925),
		-- at the banner's z, a hair thicker so it reads as a frame lip.
		local bannerTrim = makePart(baseModel, "BannerTrim", Vector3.new(10.5, 0.35, 0.32), baseCFrame * CFrame.new(0, 6.925, -17.1), Color3.fromRGB(240, 180, 70), Enum.Material.SmoothPlastic)
		bannerTrim.CanCollide = false

		-- A coloured walkway from the plaza out to this base, so a player
		-- carrying a card can follow their colour home.
		local pathColor = Color3.new(accent.R * 0.5, accent.G * 0.5, accent.B * 0.5)
		local pathMid = Vector3.new(math.sin(angle) * 37, 0.56, math.cos(angle) * 37)
		local pathEnd = Vector3.new(math.sin(angle) * 58, 0.56, math.cos(angle) * 58)
		local path = makePart(world, "Path", Vector3.new(7, 0.12, 42), CFrame.lookAt(pathMid, pathEnd), pathColor, Enum.Material.SmoothPlastic)
		path.CanCollide = false

		-- A tall beam of the base's colour behind the back rail: home is
		-- visible from anywhere on the map.
		local beacon = makePart(baseModel, "HomeBeacon", Vector3.new(1.2, 60, 1.2), baseCFrame * CFrame.new(0, 30, 13.5), accent, Enum.Material.Neon)
		beacon.Transparency = 0.5
		beacon.CanCollide = false

		local stands = {}
		local standXs = {-13.5, -4.5, 4.5, 13.5}
		local standZs = {-4.5, 4}
		local standIndex = 0
		for row = 1, 2 do
			for column = 1, 4 do
				standIndex += 1
				local localPosition = Vector3.new(standXs[column], 0, standZs[row])
				local standModel = Instance.new("Model")
				standModel.Name = "Stand" .. standIndex
				standModel:SetAttribute("BaseIndex", baseIndex)
				standModel:SetAttribute("StandIndex", standIndex)
				standModel.Parent = baseModel

				local pedestalCFrame = baseCFrame * CFrame.new(localPosition.X, 1.7, localPosition.Z)
				local pedestal = makePart(standModel, "Pedestal", Vector3.new(3, 2.4, 3), pedestalCFrame, Color3.fromRGB(35, 38, 56), Enum.Material.Metal)
				local slotCFrame = baseCFrame * CFrame.new(localPosition.X, 5.15, localPosition.Z)
				makePart(standModel, "Backboard", Vector3.new(4.4, 5.8, 0.35), slotCFrame * CFrame.new(0, 0, 0.42), Color3.fromRGB(22, 24, 40), Enum.Material.SmoothPlastic)
				makePart(standModel, "GlowTrim", Vector3.new(4.7, 0.35, 0.5), slotCFrame * CFrame.new(0, -3, 0.2), accent, Enum.Material.Neon)

				local standPrompt = Instance.new("ProximityPrompt")
				standPrompt.Name = "StandPrompt"
				standPrompt.ActionText = "Use Stand"
				standPrompt.ObjectText = "Empty Card Stand"
				standPrompt.HoldDuration = 0.25
				standPrompt.MaxActivationDistance = 13
				standPrompt.RequiresLineOfSight = false
				standPrompt.Parent = pedestal

				-- Stands past the starting count wear a floating lock tag
				-- until the base owner's rebirths unlock them.
				local lockGui = nil
				if standIndex > CardData.StartingStands then
					lockGui = Instance.new("BillboardGui")
					lockGui.Name = "StandLockTag"
					lockGui.Size = UDim2.fromScale(6, 1.8)
					lockGui.StudsOffset = Vector3.new(0, 4.6, 0)
					lockGui.AlwaysOnTop = false
					lockGui.Parent = pedestal

					local lockLabel = Instance.new("TextLabel")
					lockLabel.Name = "Label"
					lockLabel.Size = UDim2.fromScale(1, 1)
					lockLabel.BackgroundColor3 = Color3.fromRGB(24, 22, 44)
					lockLabel.BackgroundTransparency = 0.25
					lockLabel.BorderSizePixel = 0
					lockLabel.Text = "🔒 REBIRTH TO UNLOCK"
					lockLabel.TextColor3 = Color3.fromRGB(255, 220, 92)
					lockLabel.TextScaled = true
					lockLabel.Font = Enum.Font.FredokaOne
					lockLabel.Parent = lockGui
				end

				stands[standIndex] = {
					Index = standIndex,
					Model = standModel,
					Pedestal = pedestal,
					Prompt = standPrompt,
					SlotCFrame = slotCFrame,
					LockGui = lockGui,
				}
			end
		end

		-- Rebirth pad (front-left of the base, facing the plaza).
		local rebirthPad = makePart(baseModel, "RebirthPad", Vector3.new(6, 0.4, 6), baseCFrame * CFrame.new(-11, 1.25, -8.5), Color3.fromRGB(255, 196, 0), Enum.Material.Neon)
		rebirthPad.CanCollide = false
		local rebirthSign = makePart(baseModel, "RebirthSign", Vector3.new(6.4, 1.7, 0.4), baseCFrame * CFrame.new(-11, 3.2, -11.2), Color3.fromRGB(24, 22, 44), Enum.Material.Neon)
		local rebirthLabel = makeTextFace(rebirthSign, "♻ REBIRTH", Color3.fromRGB(255, 220, 92), Color3.fromRGB(24, 22, 44))
		rebirthLabel.Parent.Face = Enum.NormalId.Back
		local rebirthPrompt = Instance.new("ProximityPrompt")
		rebirthPrompt.Name = "RebirthPrompt"
		rebirthPrompt.ActionText = "Rebirth"
		rebirthPrompt.ObjectText = "Rebirth Pad"
		rebirthPrompt.HoldDuration = 0.6
		rebirthPrompt.MaxActivationDistance = 12
		rebirthPrompt.RequiresLineOfSight = false
		rebirthPrompt.Parent = rebirthPad

		-- Lock pad (front-right): raises the shield dome over the base.
		local lockPad = makePart(baseModel, "LockPad", Vector3.new(6, 0.4, 6), baseCFrame * CFrame.new(11, 1.25, -8.5), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
		lockPad.CanCollide = false
		local lockSign = makePart(baseModel, "LockSign", Vector3.new(6.4, 1.7, 0.4), baseCFrame * CFrame.new(11, 3.2, -11.2), Color3.fromRGB(24, 22, 44), Enum.Material.Neon)
		local lockPadLabel = makeTextFace(lockSign, "🛡 LOCK BASE", Color3.fromRGB(160, 220, 255), Color3.fromRGB(24, 22, 44))
		lockPadLabel.Parent.Face = Enum.NormalId.Back
		local lockPrompt = Instance.new("ProximityPrompt")
		lockPrompt.Name = "LockPrompt"
		lockPrompt.ActionText = "Lock Base"
		lockPrompt.ObjectText = "Shield the base for 60s"
		lockPrompt.HoldDuration = 0.4
		lockPrompt.MaxActivationDistance = 12
		lockPrompt.RequiresLineOfSight = false
		lockPrompt.Parent = lockPad

		-- Shield dome: invisible until the base is locked.
		local dome = makePart(baseModel, "ShieldDome", Vector3.new(44, 22, 34), baseCFrame * CFrame.new(0, 3.5, 0), Color3.fromRGB(120, 200, 255), Enum.Material.ForceField)
		dome.Shape = Enum.PartType.Ball
		dome.CanCollide = false
		dome.Transparency = 1

		local lockedSign = makePart(baseModel, "LockedSign", Vector3.new(11, 2.2, 0.45), baseCFrame * CFrame.new(0, 8.8, 11.5), Color3.fromRGB(60, 16, 24), Enum.Material.Neon)
		local lockedLabel = makeTextFace(lockedSign, "🔒 BASE LOCKED", Color3.fromRGB(255, 120, 120), Color3.fromRGB(60, 16, 24))
		local lockedGui = lockedLabel.Parent
		lockedGui.Enabled = false

		bases[baseIndex] = {
			Index = baseIndex,
			Model = baseModel,
			CFrame = baseCFrame,
			SpawnCFrame = baseCFrame * CFrame.new(0, 2.2, 8),
			SignLabel = signLabel,
			BannerLabel = bannerLabel,
			Stands = stands,
			RebirthPrompt = rebirthPrompt,
			LockPrompt = lockPrompt,
			ShieldDome = dome,
			LockSignGui = lockedGui,
		}
	end

	for lampIndex = 1, 8 do
		local angle = math.rad((lampIndex - 1) * 45 + 22.5)
		local pos = Vector3.new(math.sin(angle) * 48, 0.5, math.cos(angle) * 48)
		makeLamp(world, pos, baseColors[lampIndex])
	end

	-- Arena fence ring: segmented wall with a neon top trim, so the play
	-- area reads as one designed place from any distance.
	local ringRadius = 95
	local ringSegments = 28
	for seg = 1, ringSegments do
		local a1 = math.rad((seg - 1) * (360 / ringSegments))
		local a2 = math.rad(seg * (360 / ringSegments))
		local p1 = Vector3.new(math.sin(a1) * ringRadius, 0, math.cos(a1) * ringRadius)
		local p2 = Vector3.new(math.sin(a2) * ringRadius, 0, math.cos(a2) * ringRadius)
		local mid = (p1 + p2) / 2
		local segLength = (p2 - p1).Magnitude + 0.4
		local wallCFrame = CFrame.lookAt(Vector3.new(mid.X, 2, mid.Z), Vector3.new(p2.X, 2, p2.Z))
		makePart(world, "ArenaWall", Vector3.new(0.6, 3.2, segLength), wallCFrame, Color3.fromRGB(35, 38, 52), Enum.Material.Metal)
		local trim = makePart(world, "ArenaTrim", Vector3.new(0.7, 0.3, segLength), wallCFrame * CFrame.new(0, 1.75, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		trim.CanCollide = false
	end

	-- Blocky trees filling the band between the bases and the ring,
	-- angled off the path lines.
	for treeIndex = 1, 14 do
		local treeAngle = math.rad((treeIndex - 1) * (360 / 14) + 10)
		local treeRadius = 84 + ((treeIndex * 37) % 9)
		local treePos = Vector3.new(math.sin(treeAngle) * treeRadius, 0, math.cos(treeAngle) * treeRadius)
		makePart(world, "TreeTrunk", Vector3.new(1.2, 4, 1.2), CFrame.new(treePos + Vector3.new(0, 2.4, 0)), Color3.fromRGB(101, 67, 50), Enum.Material.SmoothPlastic)
		local canopyMain = makePart(world, "TreeCanopy", Vector3.new(4.6, 4.6, 4.6), CFrame.new(treePos + Vector3.new(0, 6.2, 0)), Color3.fromRGB(74, 178, 80), Enum.Material.SmoothPlastic)
		canopyMain.Shape = Enum.PartType.Ball
		local canopyTop = makePart(world, "TreeCanopyTop", Vector3.new(3.2, 3.2, 3.2), CFrame.new(treePos + Vector3.new(1.5, 7.7, 0.5)), Color3.fromRGB(96, 196, 92), Enum.Material.SmoothPlastic)
		canopyTop.Shape = Enum.PartType.Ball
	end

	-- Plaza statue ring: the game's brainrot cast standing on pedestals
	-- around the machine, purely for looks — screenshots should show the
	-- characters in the 3D world, not only on cards. The pedestals are
	-- built now; the models themselves load from free Creator Store
	-- assets in a spawned thread, so a slow or dead asset can never hold
	-- up server start, and every step is pcall-guarded so one junk asset
	-- can never break the game or the other statues.
	local statuesFolder = Instance.new("Folder")
	statuesFolder.Name = "Statues"
	statuesFolder.Parent = world

	local plazaTopY = 0.5
	local pedestalTopY = plazaTopY + 1.4
	local statueDefs = {
		{ Name = "TRALALERO TRALALA", AssetId = 111854862176457 },
		{ Name = "TUNG TUNG TUNG SAHUR", AssetId = 138151705692565 },
		{ Name = "BOMBARDIRO CROCODILO", AssetId = 111138597903728 },
		{ Name = "BALLERINA CAPPUCCINA", AssetId = 81269930750607 },
		{ Name = "CAPPUCCINO ASSASSINO", AssetId = 88011361629493 },
		{ Name = "CHIMPANZINI BANANINI", AssetId = 83732984780551 },
		{ Name = "LIRILI LARILA", AssetId = 132142269279297 },
		{ Name = "BONECA AMBALABU", AssetId = 123210637670218 },
	}
	local statueSpots = {}

	for statueIndex, def in ipairs(statueDefs) do
		-- Half a step off the base angles (0, 45, 90...), so each statue
		-- stands between two base paths.
		local angle = math.rad(22.5 + 45 * (statueIndex - 1))
		local sx = math.sin(angle) * 36
		local sz = math.cos(angle) * 36
		statueSpots[statueIndex] = { X = sx, Z = sz }

		local pedestalCFrame = CFrame.lookAt(
			Vector3.new(sx, plazaTopY + 0.7, sz),
			Vector3.new(0, plazaTopY + 0.7, 0))
		makePart(statuesFolder, "StatuePedestal", Vector3.new(5.5, 1.4, 5.5), pedestalCFrame, Color3.fromRGB(38, 40, 54), Enum.Material.SmoothPlastic)
		local trim = makePart(statuesFolder, "StatueTrim", Vector3.new(5.9, 0.3, 5.9), pedestalCFrame * CFrame.new(0, 0.55, 0), Color3.fromRGB(240, 180, 70), Enum.Material.SmoothPlastic)
		trim.CanCollide = false

		-- Name plaque on the centre-facing side of the pedestal (the
		-- face a player at the machine reads). lookAt aims the part's
		-- back at the centre, so the text face flips to Back — the same
		-- trick the rebirth and lock signs use.
		local centreDir = (Vector3.new(0, 0, 0) - Vector3.new(sx, 0, sz)).Unit
		local plaqueCFrame = CFrame.lookAt(
			Vector3.new(sx, plazaTopY + 0.7, sz) + centreDir * 2.88,
			Vector3.new(0, plazaTopY + 0.7, 0))
		local plaque = makePart(statuesFolder, "StatuePlaque", Vector3.new(5.2, 1.05, 0.24), plaqueCFrame, Color3.fromRGB(24, 22, 44), Enum.Material.SmoothPlastic)
		plaque.CanCollide = false
		local plaqueLabel = makeTextFace(plaque, def.Name, Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 22, 44))
		plaqueLabel.Parent.Face = Enum.NormalId.Back
	end

	-- Strip a loaded asset down to a silent, still statue: no scripts of
	-- any kind, no sounds, no particle/beam effects, and every part
	-- anchored and non-colliding so it can never interact with play.
	local function sanitiseStatue(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript")
				or descendant:IsA("Sound")
				or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.Massless = true
			end
		end
	end

	-- LoadAsset hands back a container: usually one Model inside, but
	-- some assets are loose parts in the container itself. Prefer the
	-- single child Model; otherwise use the container when it holds
	-- parts; otherwise the first Model buried anywhere inside.
	local function pickStatueRoot(asset)
		local childModels = {}
		for _, child in ipairs(asset:GetChildren()) do
			if child:IsA("Model") then
				table.insert(childModels, child)
			end
		end
		if #childModels == 1 then
			return childModels[1]
		end
		if asset:FindFirstChildWhichIsA("BasePart", true) then
			return asset
		end
		for _, descendant in ipairs(asset:GetDescendants()) do
			if descendant:IsA("Model") then
				return descendant
			end
		end
		return nil
	end

	task.spawn(function()
		local InsertService = game:GetService("InsertService")
		for statueIndex, def in ipairs(statueDefs) do
			local spot = statueSpots[statueIndex]
			local ok, asset = pcall(function()
				return InsertService:LoadAsset(def.AssetId)
			end)
			if not ok or not asset then
				print("[BrainrotCardHeist] Statue skipped: " .. def.Name .. " (load failed)")
			else
				local statue = nil
				local placed, err = pcall(function()
					sanitiseStatue(asset)
					statue = pickStatueRoot(asset)
					if not statue then
						error("no parts")
					end
					if statue ~= asset then
						-- Keep only the chosen model; the rest of the
						-- container (helper parts, thumbnails) goes away.
						statue.Parent = nil
						asset:Destroy()
					end
					statue.Name = def.Name

					if not statue.PrimaryPart then
						statue.PrimaryPart = statue:FindFirstChildWhichIsA("BasePart", true)
					end
					statue.Parent = statuesFolder

					-- Normalise to an 8-stud-tall statue whatever size
					-- the creator authored it at.
					local _, size = statue:GetBoundingBox()
					if size.Y <= 0 then
						error("no parts")
					end
					local scaled = pcall(function()
						statue:ScaleTo(8 / size.Y * statue:GetScale())
					end)
					if not scaled then
						print("[BrainrotCardHeist] Statue scale failed, keeping authored size: " .. def.Name)
					end

					-- Pose: rigid-move the model so its bounding-box
					-- bottom centre lands exactly on the pedestal top,
					-- yawed to face the machine at the centre.
					local bboxCFrame, finalSize = statue:GetBoundingBox()
					local pivotOffset = bboxCFrame:Inverse() * statue:GetPivot()
					local centrePos = Vector3.new(spot.X, pedestalTopY + finalSize.Y / 2, spot.Z)
					local centreCFrame = CFrame.lookAt(centrePos, Vector3.new(0, centrePos.Y, 0))
					statue:PivotTo(centreCFrame * pivotOffset)
					print(string.format("[BrainrotCardHeist] Statue loaded: %s (height %.1f)", def.Name, finalSize.Y))
				end)
				if not placed then
					local reason = string.find(tostring(err), "no parts") and "no parts" or "error"
					print("[BrainrotCardHeist] Statue skipped: " .. def.Name .. " (" .. reason .. ")")
					if statue and statue.Parent then
						statue:Destroy()
					end
					asset:Destroy()
				end
			end
		end
	end)

	return {
		World = world,
		ActiveCards = activeCards,
		Machine = machineRefs,
		Bases = bases,
		HoloCard = holoCard,
	}
end

return WorldBuilder
