--                                    Customisables
local Animations: SharedTable = {
	Idle = "rbxassetid://111435934785103", -- Replace with custom anim Id if you adding any other gun
	Fire = "rbxassetid://137842740807649",-- Replace with custom anim Id if you adding any other gun
	Reload = "rbxassetid://119426315630908",-- Replace with custom anim Id if you adding any other gun
	Walk = "rbxassetid://101090054271149"-- Replace with custom anim Id if you adding any other gun
}
local Sounds: SharedTable = {
	Fire = "rbxassetid://139161111759039",-- Replace with custom Sound Id if you adding any other gun
	Reload = "rbxassetid://106357432149977"-- Replace with custom Sound Id if you adding any other gun
}
local GunWhitePicID: string =  "rbxassetid://139904130664696" -- Replace with custom gun white pic ID if using this script in any other gun
local FireMode: string = "Semi" -- Add the Default FireMode for the gun here make sure to add the fire modes u want in the gun in the AvailableFireModes Table
local AvailableFireModes: SharedTable = {"Semi"}

local FireKey: SharedTable = {
	PC = Enum.UserInputType.MouseButton1,
	Console = Enum.KeyCode.ButtonR2
}
local ReloadKey: SharedTable = {
	PC = Enum.KeyCode.R,
	Console = Enum.KeyCode.ButtonX
}
local ToggleFireMode: SharedTable = {
	PC = Enum.KeyCode.E,
	Console = Enum.KeyCode.DPadDown
}


-- Strcit: Don't Alter the script if you don't know how to script. Below all the things are not customisations

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Remotes
local GunRemote: RemoteEvent = ReplicatedStorage.Remotes:WaitForChild("GunRemote")
local GunFunction: RemoteFunction = ReplicatedStorage.Remotes.GunFunction

-- Variables
local tool: Tool = script.Parent
local plr: Player = Players.LocalPlayer
local char: Model = plr.Character or plr.CharacterAdded:Wait()
local hrp: Part = char:WaitForChild("HumanoidRootPart")
local mouse: Vector2 = plr:GetMouse()
local ShiftLock: ModuleScript = require(script.MobileShiftLock)

local DiscardAnims, Firetrack, Reloadtrack
local DiscardSounds, ReloadSound, FireSound
local IsEquipped: boolean = false
local IsHolded: boolean = false
local IsInBrust: boolean = false
local ShotFired: number = 0
local DeviceType: string = ""
local camera: Camera = workspace.CurrentCamera
local viewportSize: Vector2 = camera.ViewportSize
local GunProperties: SharedTable =  GunFunction:InvokeServer("GetGunProperty", tool.Name)
local PlayerInfo: SharedTable = GunFunction:InvokeServer("GetPlayerinfo")

-- Recoil 
local recoilOffset = CFrame.new()
local currentRecoil = Vector2.new()
local accumulatedMult = 1

local UI: ScreenGui = plr.PlayerGui:WaitForChild("GunUI")
local FireButton: ImageButton = UI.FireButton
local ReloadButton: ImageButton = UI.ReloadButton
local FireModeButton: ImageButton = UI.Frame.BulletUI.FireModeButton
local Crosshair: ImageLabel = UI.Crosshair



local function NextValue(sequenceTable, currentValue)
	local currentIndex = table.find(sequenceTable, currentValue)

	if currentIndex then
		local nextIndex = currentIndex + 1
		if nextIndex > #sequenceTable then
			nextIndex = 1 
		end
		return sequenceTable[nextIndex]
	else
		return sequenceTable[1]
	end
end

local function SetupSound()
	ReloadSound = Instance.new("Sound")
	ReloadSound.SoundId = Sounds.Reload
	ReloadSound.Parent = tool.Handle
	ReloadSound.Volume = 1
	ReloadSound.PlaybackSpeed = .6

	FireSound = Instance.new("Sound")
	FireSound.SoundId = Sounds.Fire
	FireSound.Parent = tool.Handle
	FireSound.Volume = 1
	FireSound.PlaybackSpeed = 1

	local function DiscardSounds()
		ReloadSound:Destroy()
		FireSound:Destroy()
	end

	return DiscardSounds, FireSound, ReloadSound
end

local function applyRecoil()
	-- Scale recoil by accumulated multiplier
	local kick = Vector2.new(
		GunProperties.Recoil.X * accumulatedMult,
		GunProperties.Recoil.Y * accumulatedMult
	)

	currentRecoil += kick
	accumulatedMult *= GunProperties.RecoilMult -- increase multiplier for next shot
end

local function UpdateAmmoUI()
	task.wait(.1)
	local newplrinfo = GunFunction:InvokeServer("GetPlayerinfo")
	UI.Frame.Ammo.Text = newplrinfo["GunsAmmo"][tool.Name] .."/"..GunProperties.AmmoCapacity

	for _, bullet in ipairs(UI.Frame.BulletUI:GetChildren()) do
		if bullet:IsA("ImageLabel") then
			bullet.Visible = false
		end
	end

	if FireMode == "Auto" then
		for i,v in pairs(UI.Frame.BulletUI:GetChildren()) do
			if v:IsA("ImageLabel") then
				v.Visible = true
			end
		end
	elseif FireMode == "Burst" then
		local BulletUI = UI.Frame.BulletUI:GetChildren()
		print(BulletUI)
		BulletUI[1].Visible = true
		BulletUI[2].Visible = true
		BulletUI[3].Visible = true
	elseif FireMode == "Semi" then
		local BulletUI = UI.Frame.BulletUI:GetChildren()

		if #BulletUI > 0 then
			local firstChild = BulletUI[1]
			if firstChild:IsA("ImageLabel") then
				firstChild.Visible = true
			end
		end
	end
end

local function resetRecoil()
	accumulatedMult = 1
end

local function SendRayFromCam(arg)
	local rayOrigin = camera.CFrame.Position
	local rayDirection = camera.CFrame.LookVector * 1000

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Players.LocalPlayer.Character, tool, workspace.VFXGame}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result then
	end
	local hitPos = result and result.Position or (rayOrigin + rayDirection)

	if arg == "Fire" then
		-- Return the world position we hit
		return hitPos
	end
end

local function setupAnimations(character)
	local RightArm: Part = character:WaitForChild("Right Arm")
	local Grip: Weld = RightArm:WaitForChild("RightGrip")
	Grip:Destroy()

	local motor = Instance.new("Motor6D")
	motor.Name = "RightGrip"
	motor.Part0 = RightArm
	motor.Part1 = tool.Handle
	motor.Parent = RightArm

	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Preload animations
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = Animations.Idle
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Action
	idleTrack.Looped = true

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = Animations.Walk
	local walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Action
	walkTrack.Looped = true

	local fireAnim = Instance.new("Animation")
	fireAnim.AnimationId = Animations.Fire
	local fireTrack = animator:LoadAnimation(fireAnim)
	fireTrack.Priority = Enum.AnimationPriority.Action2
	fireTrack.Looped = false -- fire should play once

	local ReloadAnim = Instance.new("Animation")
	ReloadAnim.AnimationId = Animations.Reload
	local ReloadTrack = animator:LoadAnimation(ReloadAnim)
	ReloadTrack.Priority = Enum.AnimationPriority.Action2
	ReloadTrack.Looped = false -- Reload should play once

	-- Start idle/walk logic
	local currentTrack = nil
	local function switchTo(track)
		if currentTrack ~= track then
			if currentTrack and currentTrack.IsPlaying then
				currentTrack:Stop(0.1)
			end
			currentTrack = track
			if not track.IsPlaying then
				track:Play(0.1)
			end
		end
	end

	local function initializeState()
		if humanoid.MoveDirection.Magnitude > 0.1 and humanoid.WalkSpeed > 0 then
			switchTo(walkTrack)
		else
			switchTo(idleTrack)
		end
	end
	initializeState()

	local connections = {}
	table.insert(connections, humanoid.Running:Connect(function(speed)
		if speed > 1 then
			switchTo(walkTrack)
			walkTrack:AdjustSpeed(speed / humanoid.WalkSpeed)
		else
			switchTo(idleTrack)
		end
	end))

	table.insert(connections, humanoid.Died:Connect(function()
		if currentTrack and currentTrack.IsPlaying then
			currentTrack:Stop(0)
		end
	end))

	-- Cleanup
	local function discardAnimations()
		if idleTrack.IsPlaying then idleTrack:Stop(0) end
		if walkTrack.IsPlaying then walkTrack:Stop(0) end
		if fireTrack.IsPlaying then fireTrack:Stop(0) end
		if ReloadTrack.IsPlaying then ReloadTrack:Stop(0) end
		for _, conn in ipairs(connections) do conn:Disconnect() end
		connections = {}
		motor:Destroy()
	end

	-- Return both discard and fireTrack so we can trigger fire later
	return discardAnimations, fireTrack, ReloadTrack
end

tool.Equipped:Connect(function()
	DisableShitlock = ShiftLock.Enable()
	DiscardAnims, Firetrack, Reloadtrack = setupAnimations(char)
	DiscardSounds, FireSound, ReloadSound = SetupSound(tool)
	IsEquipped = true
	GunRemote:FireServer({Tool = tool, Cond = "Equipped"})
	Crosshair.Visible = true

	UI.Frame.Visible = true
	UI.Frame.Image.Image = GunWhitePicID
	UI.Frame.GunName.Text = tostring(tool.Name)
	UpdateAmmoUI()

	if DeviceType == 'Mobile' then
		FireButton.Visible = true
		ReloadButton.Visible = true
	elseif DeviceType == 'PC' then
		UserInputService.MouseIconEnabled = false
	end
end)

tool.Unequipped:Connect(function()
	UI.Frame.Visible = false
	DiscardAnims()
	DiscardSounds()
	IsEquipped = false
	GunRemote:FireServer({Tool = tool, Cond = "Unequipped"})
	IsHolded = false
	DisableShitlock()
	Crosshair.Visible = false

	if DeviceType == 'Mobile' then
		FireButton.Visible = false
		ReloadButton.Visible = false
	elseif DeviceType == 'PC' then
		UserInputService.MouseIconEnabled = true
	end
end)

FireButton.MouseButton1Down:Connect(function()
	if IsEquipped then
		IsHolded = true
		if FireMode == "Auto" then
			repeat 
				local targetPos = SendRayFromCam("Fire")
				task.wait(0.001)
				GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
			until IsHolded == false
		elseif FireMode == "Semi" then
			local targetPos = SendRayFromCam("Fire")
			GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
		elseif FireMode == "Burst" and not IsInBrust then
			local newplrinfo
			IsInBrust = true
			repeat
				newplrinfo = GunFunction:InvokeServer("GetPlayerinfo")
				task.wait(0.001)
				if newplrinfo["GunsAmmo"][tool.Name] == 0 then
					ShotFired = 0
					IsInBrust = false
					return 
				end
				local targetPos = SendRayFromCam("Fire")
				GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
				if not IsEquipped then
					return
				end
			until ShotFired >= 3
			ShotFired = 0
			IsInBrust = false
		end
	end
end)

FireButton.MouseButton1Up:Connect(function()
	IsHolded = false
end)

ReloadButton.Activated:Connect(function()
	if IsEquipped then
		GunRemote:FireServer({Tool = tool, Cond = "Reload"})
	end
end)

FireModeButton.TouchTap:Connect(function()
	if IsEquipped then
		local NextMode = NextValue(AvailableFireModes, FireMode)
		FireMode = NextMode
		UpdateAmmoUI()
	end
end)

UserInputService.InputBegan:Connect(function(Input, IsChatting)
	if IsChatting or not IsEquipped then return end
	local mouse = plr:GetMouse()

	if UserInputService.KeyboardEnabled or UserInputService.MouseEnabled then
		DeviceType = "PC"
	elseif UserInputService.GamepadEnabled then
		DeviceType = "Console"
	elseif UserInputService.TouchEnabled then
		DeviceType = "Mobile"
	end

	if DeviceType == "PC" then
		if Input.UserInputType == FireKey.PC then
			if FireMode == "Auto" then
				IsHolded = true
				if IsEquipped then
					repeat 
						local targetPos = SendRayFromCam("Fire")

						task.wait(0.001)
						GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
					until IsHolded == false
				end
			elseif FireMode == "Semi" then
				local targetPos = SendRayFromCam("Fire")
				GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
			elseif FireMode == "Burst" and not IsInBrust then
				local newplrinfo
				IsInBrust = true
				repeat
					newplrinfo = GunFunction:InvokeServer("GetPlayerinfo")
					task.wait(0.001)
					if newplrinfo["GunsAmmo"][tool.Name] == 0 then
						ShotFired = 0
						IsInBrust = false
						return 
					end
					local targetPos = SendRayFromCam("Fire")
					GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
					if not IsEquipped then
						return
					end
				until ShotFired >= 3
				ShotFired = 0
				IsInBrust = false
			end
		elseif Input.KeyCode == ReloadKey.PC then
			GunRemote:FireServer({Tool = tool, Cond = "Reload"})

		elseif Input.KeyCode == ToggleFireMode.PC then
			local NextMode = NextValue(AvailableFireModes, FireMode)
			FireMode = NextMode
			UpdateAmmoUI()

		end
	elseif DeviceType == "Console" then 
		if Input.UserInputType == FireKey.Console then
			if FireMode == "Auto" then
				IsHolded = true
				if IsEquipped then
					repeat 
						local targetPos = SendRayFromCam("Fire")

						task.wait(0.001)
						GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
					until IsHolded == false
				end
			elseif FireMode == "Semi" then
				local targetPos = SendRayFromCam("Fire")
				GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
			elseif FireMode == "Burst" and not IsInBrust then
				local newplrinfo
				IsInBrust = true
				repeat
					newplrinfo = GunFunction:InvokeServer("GetPlayerinfo")
					task.wait(0.001)
					if newplrinfo["GunsAmmo"][tool.Name] == 0 then
						ShotFired = 0
						IsInBrust = false
						return 
					end
					local targetPos = SendRayFromCam("Fire")
					GunRemote:FireServer({Tool = tool, Cond = "Fire", TargetPos = targetPos})
					if not IsEquipped then
						return
					end
				until ShotFired >= 3
				ShotFired = 0
				IsInBrust = false
			end
		elseif Input.KeyCode == ReloadKey.Console then
			GunRemote:FireServer({Tool = tool, Cond = "Reload"})


		elseif Input.KeyCode == ToggleFireMode.Console then
			local NextMode = NextValue(AvailableFireModes, FireMode)
			FireMode = NextMode

		end
	end
end)

UserInputService.InputEnded:Connect(function(Input, IsChatting)
	if IsChatting or not IsEquipped then return end

	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		IsHolded = false
		resetRecoil()
	end
end)

GunRemote.OnClientEvent:Connect(function(Arg)
	if IsEquipped then
		if Arg == "Fire" then
			Firetrack:Play()
			FireSound:Play()
			applyRecoil()
			UpdateAmmoUI()
			ShotFired += 1
		elseif Arg == "Reloaded" then
			UpdateAmmoUI()
		elseif Arg == "Reloading" then
			Reloadtrack:Play()
			ReloadSound:Play()
		end
	end
end)

local function setFirstPersonTransparency(enabled)
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Left Arm" or part.Name == "Right Arm" then
				-- Arms stay visible
				part.LocalTransparencyModifier = 0
			else
				-- Everything else hidden in FPP
				part.LocalTransparencyModifier = enabled and 1 or 0
			end
		end
	end
end

-- Example: toggle when zooming into FPP
RunService.RenderStepped:Connect(function(dt)
	if IsEquipped then
		local inFpp = (camera.Focus.Position - camera.CFrame.Position).Magnitude < 1
		setFirstPersonTransparency(inFpp)

		-- Smoothly decay recoil
		local randomSign = (math.random(0,1) == 0) and -1 or 1
		currentRecoil = currentRecoil:Lerp(Vector2.new(), dt * 5)

		-- Build recoil offset from currentRecoil
		recoilOffset = CFrame.Angles(
			math.rad(-currentRecoil.Y),
			math.rad(currentRecoil.X * randomSign),
			0
		)
		local FinalCFrame = camera.CFrame * recoilOffset 

		--Apply recoil offset on top of normal camera look
		camera.CFrame = CFrame.new(camera.CFrame.Position, camera.Focus.Position) * recoilOffset
	end
end)
