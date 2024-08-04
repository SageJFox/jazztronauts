CreateClientConVar("jazz_money_protection", "1", true, true, "Protect your money from arbitrary hub map logic.\n" ..
"\t0 - allow any uses (includes triggers, automatic logic, etc.)\n" ..
"\t1 - you had to have +USEd a button of some sort for it to be allowed\n" ..
"\t2 - block all map uses, only the Bartender's shop can take money", 0, 2)

ENT.Type = "point"

--print our warning for attempted access
net.Receive("JazzLogicPurchaseChat",function()
	local txt = net.ReadString()
	local name = net.ReadString()
	local amt = net.ReadUInt(31)
	chat.AddText( amt ~= 0 and jazzloc.Localize( txt, name, amt ) or jazzloc.Localize(txt) )
end)

local AttentionMarker = Material("ui/jazztronauts/catcoin.png", "smooth")
local markers = 0

function markerprice(self, scrpos, visible)
	local fadein = (LocalPlayer():EyePos():DistToSqr(self.pos) < 26896) and visible or 0 --(82 * 2)² (82 units: max +USE distance)

	if fadein > 0 then
		--text bkg
		surface.SetFont("JazzNoteMultiplierExtra")
		local size, alpha = ScreenScale(16), Lerp(math.sqrt(fadein),0,255)
		draw.NoTexture()
		surface.SetDrawColor( 0, 0, 0, alpha * 0.5 )
		local w, h = surface.GetTextSize(self.label)
		surface.DrawRect(scrpos.x - (w/2 + 10), scrpos.y + size/2 - 2, w + 20, h + 4)
		--coin
		surface.SetDrawColor( 255, 255, 255, alpha )
		surface.SetMaterial(self.icon)
		surface.DrawTexturedRect(scrpos.x - size/2, scrpos.y - size/2, size, size)
		--text
		local notes = LocalPlayer():GetNotes()
		if self.price < 0 then
			surface.SetTextColor( 51, 255, 24, alpha )
		elseif notes >= self.price or (notes > 0 and self.partial) then
			surface.SetTextColor( 240, 240, 204, alpha )
		else
			surface.SetTextColor( 255, 24, 51, alpha )
		end
		surface.SetTextPos(scrpos.x - w/2, scrpos.y + size/2)
		surface.DrawText(self.label)
	end

end

function ENT:Initialize()
	net.Start("JazzLogicPurchaseInit") --this feels stupid but it works and reasonable methods don't
		net.WriteEntity(self)
	net.SendToServer()
end

net.Receive("JazzLogicPurchaseInit", function()

	local markerName = "purchase" .. markers
	markers = markers + 1

	local price = net.ReadInt(32)
	local pos = net.ReadVector()
	local partial = net.ReadBool()

	worldmarker.Register(markerName, AttentionMarker, 20)
	worldmarker.Update(markerName, pos)
	worldmarker.markers[markerName].label = (price > 0 and "" or "+") .. jazzloc.Localize( "jazz.store.price", math.abs(price) )
	worldmarker.markers[markerName].price = price
	worldmarker.markers[markerName].partial = partial
	worldmarker.SetRenderFunction(markerName, markerprice)
	worldmarker.SetEnabled(markerName, true)

end)
