local HasBlood = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GunRemote: RemoteEvent = ReplicatedStorage.Remotes:WaitForChild("GunRemote")
local GunFunction: RemoteFunction = ReplicatedStorage.Remotes:WaitForChild("GunFunction")
local GunModule: ModuleScript = require(script.GunModule)

local function VFXHandler(VFXName: string, Pos: CFrame, DestroyTime: number, WeldMember: Part)
	local VFX = ReplicatedStorage.VFX[VFXName]
	if VFX then
		local vfx: Part = VFX:Clone()
		vfx.Parent = workspace.VFXGame
		vfx.CFrame = Pos
		vfx.CanCollide = false
		vfx.Massless = true
		vfx.Transparency = 1
		vfx.Anchored = false
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = vfx
		weld.Part1 = WeldMember
		weld.Parent = vfx
		
		game.Debris:AddItem(vfx, DestroyTime)
		
        return vfx
	end
end

local function FireGun(plr: Player, Gun: Tool, Pos: Vector3)
	GunRemote:FireClient(plr, "Fire")
	local char: Model = plr.Character
	local hrp: Part = char:WaitForChild("HumanoidRootPart")
	local GunConfig = GunModule.GunSettings[Gun.Name]
	
	local bullet: Part = ReplicatedStorage.Bullet:Clone()
	bullet.Parent = workspace
	bullet.CFrame = Gun.FirePoint.CFrame * CFrame.new(2,0,0)
	bullet.CanCollide = false
	bullet.Anchored = false
	bullet.Massless = false -- helps avoid inertia delay
	bullet:SetNetworkOwner(plr)

	-- Attachment + LinearVelocity
	local attachment: Attachment = Instance.new("Attachment")
	attachment.Parent = bullet

	local lv: LinearVelocity = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.Parent = bullet
	lv.VectorVelocity = (Pos - bullet.Position).Unit * GunConfig.Speed

	local FlashVFX = VFXHandler("Flash", Gun.FirePoint.CFrame * CFrame.Angles(0, math.rad(90), 0), 3, Gun.FirePoint)	
	task.spawn(function()
		task.wait(0.05)
		FlashVFX.PointLight.Enabled = false
		for i,v in pairs(FlashVFX:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end)
	-- Cleanup
	game:GetService("Debris"):AddItem(bullet, GunConfig.Lifetime)
	local TouchConnection: RBXScriptConnection
	TouchConnection = bullet.Touched:Connect(function(Hit)
		if Hit and Hit.Parent:FindFirstChild("Humanoid") and Hit.Parent.Name ~= plr.Name then
			TouchConnection:Disconnect()
			if HasBlood == true then
				local BloodVFX = VFXHandler("Blood", Hit.CFrame, 3)
				task.spawn(function()
					BloodVFX.CFrame = CFrame.lookAt(BloodVFX.Position, hrp.Position)
					for i,v in pairs(BloodVFX:GetDescendants()) do
						task.wait(.01)
						if v:IsA("ParticleEmitter") then
							v:Emit(v:GetAttribute("EmitCount"))
						end
					end
				end)
			end
			Hit.Parent.Humanoid:TakeDamage(GunConfig.Damage)
			bullet:Destroy()
		end
	end)
	
end

GunRemote.OnServerEvent:Connect(function(plr: Player, Args: SharedTable)
	if Args.Cond == "Fire" then

		if table.find(GunModule.ValidGuns, Args.Tool.Name) and GunModule.Players[plr.UserId].GunDebounce == false and GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] > 0 then
			
			GunModule.Players[plr.UserId].GunDebounce = true
			GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] -= 1
			FireGun(plr, Args.Tool, Args.TargetPos)
			task.delay(GunModule.GunSettings[Args.Tool.Name].Rate, function()
				GunModule.Players[plr.UserId].GunDebounce = false
			end)
		end
		
	elseif Args.Cond == "Equipped" then
		GunModule.Players[plr.UserId]["GunEquipped"] = Args.Tool.Name
		if not GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] then
			GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] = GunModule.GunSettings[Args.Tool.Name].AmmoCapacity
		end
		
	elseif Args.Cond == "Unequipped" then
		GunModule.Players[plr.UserId]["GunEquipped"] = ""
		
	elseif Args.Cond == "Reload" and 
		GunModule.Players[plr.UserId]["State"] ~= "Reloading" and
		GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] ~= GunModule.GunSettings[Args.Tool.Name].AmmoCapacity
	then
		GunRemote:FireClient(plr, "Reloading")
		GunModule.Players[plr.UserId]["State"] = "Reloading"
		task.delay(2, function()
			GunModule.Players[plr.UserId]["State"] = ""
			GunModule.Players[plr.UserId]["GunsAmmo"][Args.Tool.Name] = GunModule.GunSettings[Args.Tool.Name].AmmoCapacity
			GunRemote:FireClient(plr, "Reloaded", GunModule.Players[plr.UserId]["Ammo"])
		end)
	else
		return
	end
	
end)

Players.PlayerAdded:Connect(function(plr: Player)
	GunModule.Players[plr.UserId] = {}
	for i,v in pairs(GunModule.Players["Default"]) do
		GunModule.Players[plr.UserId][i] = v
	end
	print(GunModule.Players[plr.UserId])
end)

GunFunction.OnServerInvoke = function(plr: Player, Args: string, GunName: string)
	if Args == "GetGunProperty" then
		return GunModule.GunSettings[GunName]
	elseif Args == "GetPlayerinfo" then
		return GunModule.Players[plr.UserId]
	end
end
