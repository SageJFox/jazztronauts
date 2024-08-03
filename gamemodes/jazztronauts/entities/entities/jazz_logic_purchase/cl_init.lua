CreateClientConVar("jazz_money_protection", "1", true, true, "Protect your money from arbitrary hub map logic.\n" ..
"\t0 - allow any uses (includes triggers, automatic logic, etc.)\n" ..
"\t1 - you had to have +USEd a button of some sort for it to be allowed\n" ..
"\t2 - block all map uses, only the Bartender's shop can take money", 0, 2)

--print our warning for attempted access
net.Receive("JazzLogicPurchaseChat",function()
	local txt = net.ReadString()
	local name = net.ReadString()
	local amt = net.ReadUInt(32)
	chat.AddText( amt ~= 0 and jazzloc.Localize( txt, name, amt ) or jazzloc.Localize(txt) )
end)