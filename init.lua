local CutsceneService = {}
CutsceneService.__index = CutsceneService

-- Dependencies

local CutsceneEvent = script.CutsceneEvent
local RunService = game:GetService("RunService")
local SequenceProvider = game:GetService("KeyframeSequenceProvider")
local LoadString = require(script.Loadstring)
local Trove = require(script.Trove).new()
local Util = require(script.Util)


function CutsceneService.new(Properties: {CameraObject: Camera, VFXData: {}})
	local self = setmetatable({}, CutsceneService)
	self.properties = Properties
	self.functionsTable = {}
	return self
end

function CutsceneService:TrackCamera(CameraRig: BasePart, Animation: AnimationTrack)
	
	self:ExecuteAllFunctions()
	
	if RunService:IsClient() then
		Animation:Play()		
		self:ExecuteAnimationEvents(Animation)
		self.properties.CameraObject.CameraType = Enum.CameraType.Scriptable
		
		Trove:Connect(RunService.Heartbeat, function(deltaTime: number) 
			if Animation.IsPlaying then
				self.properties.CameraObject.CFrame = CameraRig.CFrame
			end
		end)
		
		Animation.Stopped:Connect(function() 
			Trove:Clean()
			self:ExecuteAllFunctions()
			self.properties.VFXData[Animation.Animation.AnimationId].End()
			self.properties.CameraObject.CameraType = Enum.CameraType.Custom	
		end)
	end
end

function CutsceneService:PlayCutscene(CameraRigPath: string, AnimationId: string)
	CutsceneEvent:FireAllClients(CameraRigPath, AnimationId)
end

function CutsceneService:ExecuteAnimationEvents(Animation: AnimationTrack)
	Animation.KeyframeReached:Connect(function(keyframeName: string) 
		if self.properties.VFXData[Animation.Animation.AnimationId][keyframeName] then
			self.properties.VFXData[Animation.Animation.AnimationId][keyframeName]()
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
	
	CutsceneEvent.OnClientEvent:Connect(function(CameraRig: string, AnimationID: string) 
		self:ExecuteAllFunctions()
		self:TrackCamera(LoadString(`return {CameraRig}`)(), self:GetTrackFromID(AnimatorObject, AnimationID))
	end)
end

function CutsceneService:GetTrackFromID(AnimatorObject: Animator, ID: string): AnimationTrack
	local AnimObject = Instance.new('Animation')
	AnimObject.AnimationId = ID
	return AnimatorObject:LoadAnimation(AnimObject)
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
