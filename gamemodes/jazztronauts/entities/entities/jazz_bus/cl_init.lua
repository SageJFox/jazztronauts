include("shared.lua")


local trolleyScript = CreateConVar("jazz_trolley", "default", FCVAR_ARCHIVE, "Alternate styles for the trolley can be created with a lua script, loaded here. Will take effect next map load.\n" ..
"Don't mess with this unless you know what you're doing.")

local _, _, setup = string.find( trolleyScript:GetString(), "(.-)%.?l?u?a?$" ) --let .lua be optional
if setup then
	setup = setup .. ".lua"
else
	ErrorNoHalt("File defined in jazz_trolley not found! Using default.lua")
	setup = "default.lua"
end
--if file.Exists(setup,"GAME") then
	--AddCSLuaFile(setup)
	include(setup)
--else
--	error("oh no")
--end

ENT.ScreenHeight = 0
ENT.ScreenWidth = ENT.ScreenHeight * 1.80
ENT.ScreenScale = .1

ENT.CommentOffset = Vector(-160, 16, 0)

ENT.BusWidth = 71
ENT.BusLength = 280


function ENT:Initialize()
	if self:GetHubBus() then
		self:RefreshWorkshopInfo()
	end
	self.dest = self:GetDestination()
	if self.dest == "jazz_bar" or self.dest == "<hub>" or self.dest == "" then self.dest = jazzloc.Localize("jazz.bus.bar") end
	if self.PreInit then self:PreInit() end
end

function ENT:RefreshWorkshopInfo()
	if self:GetWorkshopID() == "" then return end

	-- First download information about the given workshopid
	steamworks.FileInfo( self:GetWorkshopID(), function( result )
		if !IsValid(self) or !result then return end

		self.Title = result.title

		-- Try to get the comments for this workshop
		workshop.FetchComments(result, function(comments)
			if !self then return end
			
			local function parseComment(cmt, width)
				if not cmt then return end

				return markup.Parse(
					"<font=SteamCommentFont>" .. cmt.message .. "</font>\n "
					.."<font=SteamAuthorFont> -" .. cmt.author .. "</font>",
				width)
			end

			-- Select 2 random comments for the side and back of the bus
			self.Description = comments and parseComment(self:TableSharedRandom(comments), 1400)
			self.BackBusComment = comments and parseComment(self:TableSharedRandom(comments, 1), 1400)
		end )

		-- Also try grabbing the thumbnail material
		workshop.FetchThumbnail(result, function(material)
			if !self then return end
			self.ThumbnailMat = material
		end )
	end )
end

function ENT:StartLaunchEffects()
	print("Starting clientside launch")
	self.IsLaunching = true
	self.StartLaunchTime = CurTime()
	LocalPlayer().LaunchingBus = self
end

-- Shared version of table.Random
function ENT:TableSharedRandom(tbl, seedOffset )
	local seed = self:GetCreationTime() + (seedOffset or 0)
	local rand = util.SharedRandom("busRand", 1, table.Count(tbl), seed)
	rand = math.Round(rand)
	local i = 1
	for k, v in pairs(tbl) do
		if (i == rand) then return v, k end
		i = i + 1
	end
end

function ENT:GetStartOffset()
	if not self.GetBreakTime or self:GetBreakTime() <= 0 then return 0 end
	return math.min(0, (CurTime() - self:GetBreakTime()) * 2000)
end

function ENT:Think()
	if not self:GetHubBus() then return end
	if self.IsLaunching then
		local factor = (CurTime() -  self.StartLaunchTime) * 15
		util.ScreenShake(LocalPlayer():GetPos(), factor, 5, 0.01, 100)
	end
end

function ENT:OnRemove()
	if not self:GetHubBus() then return end
	if self.IsLaunching then
		if not IsValid(LocalPlayer()) then return end
		LocalPlayer():SetDSP(25)
		LocalPlayer():ScreenFade(SCREENFADE.STAYOUT, Color(0, 0, 0, 255), 0, 5)
		LocalPlayer():EmitSound("ambient/explosions/exp4.wav", 100, 100)
	end
end

net.Receive("jazz_bus_explore_voideffects", function(len, ply)
	local bus = net.ReadEntity()
	local startTime = net.ReadFloat()
	local nomusic = net.ReadBool()

	-- Queried elsewhere for certain effects
	if IsValid(bus) then
		bus.IsLaunching = true
	end

	local waitTime = math.max(0, startTime - CurTime())
	if not nomusic then
		timer.Simple(waitTime, function()
			if IsValid(bus) then
				surface.PlaySound(bus.VoidMusicName)
			end
		end )
	end

	local fadeWaitTime = waitTime + bus.VoidMusicFadeStart
	transitionOut(fadeWaitTime + 7)

	timer.Simple(fadeWaitTime, function()
		if IsValid(bus) and LocalPlayer():InVehicle() then
			local fadelength = bus.VoidMusicFadeEnd - bus.VoidMusicFadeStart
			LocalPlayer():ScreenFade(SCREENFADE.OUT, color_white, fadelength, 15)
		end
	end)
end )