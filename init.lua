local CutsceneService = {}
CutsceneService.__index = CutsceneService

-- Dependencies

local CutsceneEvent = script.CutsceneEvent
local RunService = game:GetService("RunService")
local SequenceProvider = game:GetService("KeyframeSequenceProvider")
local LoadString = require(script.Loadstring)
local Trove = require(script.Trove).new()


function CutsceneService.new(Properties: {CameraObject: Camera, VFXData: {}})
	local self = setmetatable({}, CutsceneService)
	self.properties = Properties
	self.functionsTable = {}
	return self
end

function CutsceneService:TrackCamera(HostPlayer: Player, CameraRig: BasePart, Animation: AnimationTrack)
	
	self:ExecuteAllFunctions()
	
	if RunService:IsClient() then
		Animation:Play()		
		self:ExecuteAnimationEvents(HostPlayer, Animation)
		self.properties.CameraObject.CameraType = Enum.CameraType.Scriptable
		
		Trove:Connect(RunService.Heartbeat, function(deltaTime: number) 
			if Animation.IsPlaying then
				self.properties.CameraObject.CFrame = CameraRig.CFrame
			end
		end)
		
		Animation.Stopped:Connect(function() 
			Trove:Clean()
			self:ExecuteAllFunctions()
			self.properties.VFXData[Animation.Animation.AnimationId].End(HostPlayer)
			self.properties.CameraObject.CameraType = Enum.CameraType.Custom	
		end)
	end
end

function CutsceneService:PlayCutscene(HostPlayer: Player, CameraRigPath: string, AnimationId: string, players: {})
	CutsceneEvent:FireClient(HostPlayer, CameraRigPath, AnimationId, true)
	
	if players ~= nil then
		for _, players: Player in pairs(players) do
			CutsceneEvent:FireClient(players, CameraRigPath, AnimationId, false, HostPlayer)
		end
	end
end

function CutsceneService:ExecuteAnimationEvents(HostPlayer: Player, Animation: AnimationTrack)
	Animation.KeyframeReached:Connect(function(keyframeName: string) 
		if self.properties.VFXData[Animation.Animation.AnimationId][keyframeName] then
			self.properties.VFXData[Animation.Animation.AnimationId][keyframeName](HostPlayer)
		else
			warn(`Could not find event at {Animation.TimePosition}`)
		end
	end)
end

function CutsceneService:ListenClient()
	
	local Player: Player = game.Players.LocalPlayer
	local Character: Model = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid: Humanoid = Character:WaitForChild('Humanoid')
	local AnimatorObject: Animator = Humanoid:WaitForChild('Animator')
	
	CutsceneEvent.OnClientEvent:Connect(function(CameraRig: string, AnimationID: string, Host: boolean, HostPlayer: Player) 
		if Host then
			self:ExecuteAllFunctions()
			self:TrackCamera(Player, LoadString(`return {CameraRig}`)(), self:GetTrackFromID(AnimatorObject, AnimationID))
		else
			self:ExecuteAllFunctions()
			self:EmulateCutscene(HostPlayer, LoadString(`return {CameraRig}`)(), AnimationID)
		end
	end)
end

function CutsceneService:GetTrackFromID(AnimatorObject: Animator, ID: string): AnimationTrack
	local AnimObject = Instance.new('Animation')
	AnimObject.AnimationId = ID
	return AnimatorObject:LoadAnimation(AnimObject)
end


function CutsceneService:EmulateCutscene(HostPlayer: Player, CameraRig: BasePart, AnimationID: string)	
	
	local Humanoid = HostPlayer.Character:WaitForChild('Humanoid')
	local Animator: Animator = Humanoid:WaitForChild('Animator')
	
	local Animation: AnimationTrack = self:GetTrackFromID(Animator, AnimationID)
	Animation:Play()
	
	-- Set Camera to Scriptable
	
	self.properties.CameraObject.CameraType = Enum.CameraType.Scriptable
	
	-- Track Camera
	
	Trove:Connect(RunService.Heartbeat, function(deltaTime: number) 
		if Animation.IsPlaying then
			self.properties.CameraObject.CFrame = CameraRig.CFrame
			print(CameraRig.CFrame)
		end
	end)
	
	-- Animation Stop
	

	Trove:Connect(Animation.Stopped, function() 
		Trove:Clean()
		self:ExecuteAllFunctions()
		self.properties.VFXData[Animation.Animation.AnimationId].End(HostPlayer)
		self.properties.CameraObject.CameraType = Enum.CameraType.Custom	
	end)
	
	-- Watch for Animation KeyFrames then execute functions
	
	Trove:Connect(Animation.KeyframeReached, function(keyframeName: string) 
		if self.properties.VFXData[Animation.Animation.AnimationId][keyframeName] then
			self.properties.VFXData[Animation.Animation.AnimationId][keyframeName](HostPlayer)
		else
			warn(`Could not find event at {Animation.TimePosition}`)
		end
	end)
end

function CutsceneService:ExecuteAllFunctions()
	for _, functions in pairs(self.functionsTable) do
		functions()
	end
end

function CutsceneService:AttachFunction(func_)
	table.insert(self.functionsTable, func_)
end



return CutsceneService
