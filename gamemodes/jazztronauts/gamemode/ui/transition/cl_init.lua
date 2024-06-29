local horse = Material("ui/transition_horse.vmt")

local starttime = CurTime()
local transitioning = 0
local rate = .75
local drawearly = false
local fadeout = false -- happy transition horse or just a boring fade

local convar_drawtransition = CreateClientConVar("jazz_debug_transition", "1", true, false,
	"How to render transitions. 0 will never render them. 1 will render them normally as intended. 2 will only render a simple fade.", 0, 2)

-- use global functions In and Out below this
local function transition(delay, soundfile, early, fade)
	if not convar_drawtransition:GetBool()
	or GAMEMODE && GAMEMODE:GetDevMode() >= 2 then
		transitioning = 0
		return false
	end

	if convar_drawtransition:GetInt() == 2 then
		soundfile = false
		fade = true
	end

	if delay == nil then delay = 0 end
	starttime = CurTime() + delay

	if soundfile then
		timer.Simple( delay, function() surface.PlaySound( soundfile ) end )
	end

	drawearly = early
	fadeout = fade
	return true
end

function transitionIn(delay, nosound, early, fade)
	local soundfile = false
	if not nosound then
		soundfile = "jazztronauts/slide_reverse.wav"
	end

	local passed = transition(delay, soundfile, early, fade)
	if passed == true then transitioning = 1 end
end

function transitionOut(delay, nosound, early, fade)
	local soundfile = false
	if not nosound then
		soundfile = "jazztronauts/slide.wav"
	end

	local passed = transition(delay, soundfile, early, fade)
	if passed == true then transitioning = -1 end
end

local function txParse(args)
	return tonumber(args[1]), tobool(args[2]), tobool(args[3]), tobool(args[4])
end
concommand.Add("txin", function(_,_,args) transitionIn(txParse(args)) end )
concommand.Add("txout", function(_,_,args) transitionOut(txParse(args)) end )

local function getTransitionAmount()
	return ( CurTime() - starttime ) * rate
end

function isTransitioning()
	local amount = getTransitionAmount()
	return transitioning != 0 and (amount >= 0 and amount <= 1)
end
function isTransitionedOut()
	return transitioning == -1
end

local function drawHorse(amount)
	local display = Rect("screen")
	local transitionrect = Rect(0,0,0,0)
	transitionrect:Dock( display, DOCK_CENTER )
	transitionrect:Inset(-amount * 4096)

	transitionrect.x = math.floor(transitionrect.x)
	transitionrect.y = math.floor(transitionrect.y)
	transitionrect.w = math.floor(transitionrect.w)
	transitionrect.h = math.floor(transitionrect.h)

	local box = Box( transitionrect )

	render.OverrideBlendFunc( true, BLEND_ZERO, BLEND_SRC_COLOR )

	surface.SetMaterial( horse )
	surface.SetDrawColor(color_white)

	surface.DrawTexturedRect(transitionrect:Unpack())


	surface.SetDrawColor(color_black)
	surface.DrawRect( -1, -1, box.x0 + 1, ScrH() + 1 )
	surface.DrawRect( box.x0, -1, ScrW() - box.x0, box.y0 + 1 )
	surface.DrawRect( box.x1, box.y0, ScrW() - box.x1, ScrH() - box.y0 )
	surface.DrawRect( box.x0, box.y1, box.x1 - box.x0, ScrH() - box.y1 )

	render.OverrideBlendFunc( false )
end

local function drawFade(amount)
	surface.SetDrawColor(0, 0, 0, 255 - amount * 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end

local function drawTransition()
	if not convar_drawtransition:GetBool() then return end

	local amount = getTransitionAmount()

	if transitioning == 0 then
		return
	end

	if transitioning == -1 then
		amount = 1 - amount

		if amount < 0 then
			surface.SetDrawColor(0,0,0,255)
			surface.DrawRect( -1, -1, ScrW() + 2, ScrH() + 2 )
			return
		end
	end

	if transitioning == 1 and amount > 1 then
		return
	end

	amount = math.max(amount, 0)
	amount = amount * amount

	if fadeout then
		drawFade(amount)
	else
		drawHorse(amount)
	end

end

hook.Add("PostDrawHUD", "jazzCatTransition", function()
	if drawearly then return end

	drawTransition()
end)

hook.Add("PreDrawHUD", "jazzCatTransitionEarly", function()
	if not drawearly then return end

	cam.Start2D()
	drawTransition()
	cam.End2D()
end )



local convar_hubtransition = CreateClientConVar("jazz_transitionintohub", "1", true, false, "Toggles whether or not to show a transition when spawning in the hub.")
if not convar_hubtransition:GetBool()
or not convar_drawtransition:GetBool()
or GAMEMODE && GAMEMODE:GetDevMode() >= 2 then
	return
end

if mapcontrol.IsInHub() then
	-- Prevents flash frame before OnClientInitialized runs
	hook.Add("PostDrawHUD", "JazzPrepareTransitionIntoBar", function()
		surface.SetDrawColor(0,0,0,255)
		surface.DrawRect( -1, -1, ScrW() + 2, ScrH() + 2 )
	end )
	hook.Add("OnClientInitialized", "JazzTransitionIntoBar", function(ply)
		transitionIn(1)
		hook.Remove("PostDrawHUD", "JazzPrepareTransitionIntoBar")
	end )
end
