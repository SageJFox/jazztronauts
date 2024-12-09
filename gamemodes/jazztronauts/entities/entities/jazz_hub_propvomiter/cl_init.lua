JazzVomitProps = JazzVomitProps or {}

local Lifetime = CreateClientConVar("jazz_propvomiter_proplifetime","5",true,false,"How long vomited props live, in seconds.",2,10)
local FadeBegin = 2
local PipeRadius = 40

local function TickVomitProps()
	for i=#JazzVomitProps, 1, -1 do
		local p = JazzVomitProps[i]

		local t = (IsValid(p) and p.Instance.RemoveAt or 0) - UnPredictedCurTime()
		if not IsValid(p) or t < 0 then
			table.remove(JazzVomitProps, i)
			if IsValid(p) then
				p:Remove()
			end
			continue
		end

		if t < FadeBegin then
			local alpha = 255.0 * t / FadeBegin
			p:SetRenderMode(RENDERMODE_TRANSADD)
			p:SetColor(Color(255, 255, 255, alpha))
		end
	end
end

local function getPropSize(ent)
	local phys = ent:GetPhysicsObject()
	local min, max = IsValid(phys) and phys:GetAABB()

	if not min or not max then
		min, max = ent:GetModelRenderBounds()
	end

	return max - min
end

local function resize(ent)
	local size = getPropSize(ent) * 0.5

	ent:PhysicsInitSphere(32)

	local maxsize = math.max(size.x, size.y, size.z)
	local scale = 32 / maxsize
	ent:SetModelScale(scale)
end

local function tooBig(ent)
	local size = getPropSize(ent) * 0.5

	return size.x > PipeRadius || size.y > PipeRadius
end

local idx = 0
local function AddVomitProp(model, pos)
	idx = idx + 1
	local shouldRagdoll = util.IsValidRagdoll(model)
	local sprite = nil
	if string.find(model,"%*[%d]+") then model = "models/sunabouzu/worldgib01.mdl" end --let's not crash with an Engine error
	if string.find(model,"sprites%/.-%.vmt") or string.find(model,"sprites%/.-%.spr") then --sprites
		sprite = string.sub(model,1,-4) .. ".vmt"
		model = "models/hunter/blocks/cube025x025x025.mdl"
	end
	local entObj = ManagedCSEnt(model .. idx .. FrameNumber(), model, shouldRagdoll)
	local ent = entObj.Instance
	if not IsValid(ent) then return end
	if shouldRagdoll then

		for i=0, ent:GetPhysicsObjectCount()-1 do
			local phys = ent:GetPhysicsObjectNum( i )
			if phys then

				phys:SetPos( pos, true )
				phys:Wake()
				phys:SetVelocity( VectorRand() * 100  )
				phys:AddAngleVelocity(VectorRand() * 100  )

			end
		end

		if not IsValid(ent:GetPhysicsObject()) then
			resize(ent)
		end
	else
		if not ent:PhysicsInit(SOLID_VPHYSICS) or tooBig(ent) then
			resize(ent)
		end
		if sprite then ent:SetMaterial(sprite) end
		ent:SetPos(pos)
	end

	ent:SetNoDraw(false)
	ent:DrawShadow(true)

	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:GetPhysicsObject():SetMass(500)
	ent:GetPhysicsObject():Wake()
	ent:GetPhysicsObject():SetVelocity(Vector(0, 0, math.Rand(-1000, -100)))
	ent:GetPhysicsObject():AddAngleVelocity(VectorRand() * 1000)


	ent.RemoveAt = UnPredictedCurTime() + Lifetime:GetFloat()
	table.insert(JazzVomitProps, entObj)
	//SafeRemoveEntityDelayed(ent, 10)

	return ent
end

local brushModels = {
	--"models/sunabouzu/worldgib01.mdl",
	"models/sunabouzu/worldgib02.mdl",
	"models/sunabouzu/worldgib03.mdl"
}
local function AddVomitBrush(material, pos)
	local model = table.Random(brushModels)
	local ent = AddVomitProp(model, pos)
	if not IsValid(ent) then return end
	local matname, mat = brush.GetBrushMaterial(material)

	ent:SetMaterial(matname)
	return ent
end

hook.Add("Think", "TickVomitProps", TickVomitProps)

local processed = 0
local percentage = CreateClientConVar("jazz_propvomiter_percent","100",true,false,"Set the percentage of props that should appear from the prop vomiter. Lower percentages are easier on your system, but you won't see every prop.",0,100)

net.Receive("jazz_propvom_effect", function(len, ply)
	processed = processed + percentage:GetFloat()
	if processed < 100 then return end
	processed = processed - 100
	local pos = net.ReadVector()
	local model = net.ReadString()
	local type = net.ReadString()

	if type == "brush" or type == "displacement" then
		AddVomitBrush(model, pos)
	else
		AddVomitProp(model, pos)
	end
end )


local AttentionMarker = Material("materials/ui/jazztronauts/yes.png", "smooth")
local markerName = "vomiter"

net.Receive("jazz_propvom_propsavailable", function(len, ply, marker)
	local hasProps = net.ReadBool()
	local markerpos = net.ReadVector()

	if hasProps then
		worldmarker.Register(markerName, AttentionMarker, 20)
		worldmarker.Update(markerName, markerpos)
		worldmarker.SetEnabled(markerName, true)
	else
		worldmarker.SetEnabled(markerName, false)
	end

end )