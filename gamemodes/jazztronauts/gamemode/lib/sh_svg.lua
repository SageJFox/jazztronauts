--SVG file processing

--only really making this for our very specific purpose so this is very much *not* going to process every SVG file under the Sun.
--many many assumptions are made, and most SVG functionality is omitted or ignored.

AddCSLuaFile()

if SERVER then return end

module( "SVG", package.seeall )

local SVGd = "%s+d%s*=%s*\"([^\"]+)" -- pattern, returns the inner value of d="..."
local SVGfill = "%s+fill%s*=%s*\"([^\"]+)" -- fill="..."
local SVGwidth = "%s+width%s*=%s*\"([^\"]+)" -- width="..."
local SVGheight = "%s+height%s*=%s*\"([^\"]+)" -- height="..."
local SVGfillalpha = "%s+fill%-opacity%s*=%s*\"([^\"]+)" -- fill-opacity="..."

--given a hexidecimal color string, return a color
local function hexcode(str,alpha)
	if not str or 
		not isstring(str) or 
		string.lower(str) == "none" then return color_transparent end
	local r,g,b
	local a = alpha or 255
	for x in string.gmatch(str,"(%x%x)") do
		r,g,b = g,b,tonumber(x,16)
	end
	if not r or not g or not b then error("Malformed Color String: '" .. hex .. "'") end
    return Color(r,g,b,a)
end

local function alpha(alpha)
	if not alpha then return 255 end
	local percent = 1
	if string.find(alpha,"%%") then percent = 100 end
	local _,_,alpha = string.find(alpha,"%d+")
	alpha = tonumber(alpha)
	return alpha / percent * 255
end

local function getVertices(str)
	local str = string.Replace(str,"%s*,%s*",",") --ensure commas are spaceless before we explode
	local tab = string.Explode("%s",str, true)
	local vertices = {}
	for _, v in ipairs(tab) do
		if not v then continue end
		local vertexstr = string.Split(v,",")
		if #vertexstr < 2 then continue end
		local vertex = {}
		vertex.x = tonumber(vertexstr[1])
		vertex.y = tonumber(vertexstr[2])
		table.insert(vertices,vertex)
	end
	return vertices
end

--process points of a passed Cubic Bezier Curve (C/c portion of a path's d). More iterations result in a smoother curve, at an increased cost of performance
local function BezierCubic(p0,p1,p2,p3,iterations)
	local p0, p1, p2, p3, iter = p0, p1, p2, p3, iterations
	if not p2 and istable(p0) and #p0 >= 4 then --allow being passed a table of DrawPoly tables or vectors
		iter = p1
		p3 = p0[4]
		p2 = p0[3]
		p1 = p0[2]
		p0 = p0[1]
	end

	--validize me, cap'n!
	if not ((istable(p0) or isvector(p0)) and 
			(istable(p1) or isvector(p1)) and 
			(istable(p2) or isvector(p2)) and 
			(istable(p3) or isvector(p3))) then return {} end
	
	--optimization for drawing: if our control points are the same as our inital points, it's a straight segment that doesn't need any points between it
	if p0.x == p1.x and p0.y == p1.y and p2.x == p3.x and p2.y == p3.y then return {} end
	--todo maybe: could also check if the four points are colinear and in order (i.e. the normalized vectors of p1-p0 == p3-p2 == p3-p0)

	--adjust our iterations based on our size if we weren't given a specific value
	if iter == nil or string.find(iter,"auto") then
		local x1,y1 = p0.x, p0.y
		local x2,y2 = p3.x, p3.y
		--an estimation. Roughly one segment per 6 pixels of diagonal length
		iter = math.floor(math.sqrt(math.pow(x2 - x1,2) + math.pow(y2 - y1,2)) / 6)
	end

	--if we have zero iterations, we're just drawing a straight line from p0 to p3 anyway
	if not isnumber(iter) or iter <= 0 then return {} end

	local tab = {}

	local function beeznuts(i0, i1, i2, i3, t)
		--todo: validate that these are numbers
		return math.pow(1 - t,3) * i0 + 3 * math.pow(1 - t,2) * t * i1 + 3 * (1 - t) * math.pow(t,2) * i2 + math.pow(t,3) * i3
	end
	for i = 1, iter - 1 do
		local tab2 = {}
		tab2.x = beeznuts(p0.x,p1.x,p2.x,p3.x,1/iter * i)
		tab2.y = beeznuts(p0.y,p1.y,p2.y,p3.y,1/iter * i)
		table.insert(tab,tab2)
	end
	return tab
end

local function processd(d,x,y,w,h,width,height,iterations)

	local tab = getVertices(d)

	--translate points as desired
	for _, v in ipairs(tab) do
		v.x = x + v.x / width * w - math.min(0,w)
		v.y = y + v.y / height * h - math.min(0,h)
	end

	local vertices = {}
	--C/c processing - assumes one M command, followed by one C command, and assumes ending Z command
	for var = 1, (#tab - 1) / 3 do
		table.insert(vertices,tab[1]) --get the first point in
		if #tab < 4 then break end --if we're properly formatted, this should only happen with 1 point left, which was added the line before as the last point
		--note that we remove the first three points (the fourth point is used again in the next loop)
		table.Add(vertices,BezierCubic(table.remove(tab,1),table.remove(tab,1),table.remove(tab,1),tab[1],iterations))
	end

	--if we're flipping (once), make our table clockwise again
	if (w < 0) ~= (h < 0) then vertices = table.Reverse(vertices) end

	return vertices
end

--debug stuff. Set DEBUG to 1 to see shapes drawn partially transparent, and 2 to see vertices drawn, 3 for both. Both are drawn in the pattern shown below
local DEBUG = 0
local debugalpha = 100
local debugcol = {
	Color(255,0,0,debugalpha),
	Color(255,128,0,debugalpha),
	Color(255,255,0,debugalpha),
	Color(0,255,0,debugalpha),
	Color(0,255,255,debugalpha),
	Color(0,0,255,debugalpha),
	Color(255,0,255,debugalpha)
}

--tables corresponding to each part of a previously processed SVG file, as well as the transforms they had applied
local cachefill, cached, cachetransforms = {}, {}, {}

local function tablesnotempty(...)
	for _,v in ipairs({...}) do
		if next(v) == nil then return false end
	end
	return true
end

--Draw the provided SVG file at the specified x,y coordiate with the specified width and height.
--If no x or y is provided, use 0,0. If no width/height is provided, use the width and height of the SVG file.
--caching prevents an SVG from being reprocessed if nothing has changed from the last draw call.
--only turn caching on if you're drawing one SVG file per frame, and ideally only when an animation has ended
--In our case, we'd only turn it on when the chat box is fully open.
--Iterations are how smoothly curves will be processed. More iterations result in more points per curve.
--So higher is smoother, but more processing, more drawing, and more memory for caching.

function DrawSVG(svg,x,y,w,h,cache,iterations)
	--we don't need to draw anything if we have no width or height
	if w == 0 or h == 0 then return end
	local cache = cache or false

	--check our caches
	if cache and tablesnotempty(cachetransforms,cachefill,cached) then
		--make sure our cached values are actually up to date
		local current = {svg,x or 0,y or 0,w,h}
		for k, v in ipairs(current) do
			if cachetransforms[k] ~= v then
				--print("SVG cache invalidated!")
				table.Empty(cachetransforms)
				table.Empty(cached)
				table.Empty(cachefill)
				break
			end
		end
	end
	if cache and tablesnotempty(cachetransforms,cachefill,cached) then --checking again, in case previous cache was invalidated
		--draw cached SVG paths
		draw.NoTexture()
		for i = 1, #cached do
			surface.SetDrawColor(cachefill[i])
			surface.DrawPoly(cached[i])
			if DEBUG >= 2 then
				local process = 1
				for _, v in ipairs(cached[i]) do
					surface.SetDrawColor(debugcol[process % #debugcol + 1])
					surface.DrawRect(v.x - 2, v.y - 2,4,4)
					process = process + 1
				end
			end
		end
	else
		if not isstring(svg) then return end
		--attempt to open the first argument as a file, otherwise, assume it's the raw SVG data
		local svgname = svg
		local svg = file.Read(svg,"GAME") or svg
		local iterations = iterations or "auto"

		--pull out the SVG's width/height values
		local _,_,width = string.find(svg,SVGwidth)
		local _,_,height = string.find(svg,SVGheight)
		width = tonumber(width)
		height = tonumber(height)
		if not (width and height) then return end
		if width == 0 or height == 0 then return end

		--finally set up our basic variables
		local x, y, w, h = x or 0, y or 0, w or width, h or height
		local start, process, debugprocess = 1, 1, 1

		--cache overall SVG info, this is what we will compare to next frame to see if our work this frame still works
		if cache then cachetransforms = {svgname,x,y,w,h} end

		--process each path present in the SVG file
		while string.find(svg,SVGd,start) do
			--pulling out our relevant info: The fill, its opacity, and the actual path data (d="...")
			local _,_,color = string.find(svg,SVGfill,start)
			local _,_,opacity = string.find(svg,SVGfillalpha,start)
			local _,ender,d = string.find(svg,SVGd,start)
			if not ender then break end --we've hit the end of the file
			
			if DEBUG == 1 or DEBUG == 3 then
			--debug one: draw in bright, partially transparent colors to make sure paths are doing what they're expected to be doing
				local col = debugcol[debugprocess % #debugcol + 1]
				surface.SetDrawColor(col)
				if cache then cachefill[process] = col end
				debugprocess = debugprocess + 1
			else
				--process hexadecimal fill color and percentile opacity, caching if necessary
				local col = hexcode( color, alpha(opacity) )
				surface.SetDrawColor( col )
				if cache then cachefill[process] = col end
			end

			draw.NoTexture()
			--translating to the desired x/y, scaling to the desired width/height, and converting curve data to DrawPoly vertices
			local tab = processd(d,x,y,w,h,width,height,iterations)

			surface.DrawPoly(tab)
			if cache then cached[process] = table.Copy(tab) end

			--debug two: draw vertices
			if DEBUG >= 2 then
				for _, v in ipairs(tab) do
					surface.SetDrawColor(debugcol[debugprocess % #debugcol + 1])
					surface.DrawRect(v.x - 2, v.y - 2,4,4)
					debugprocess = debugprocess + 1
				end
			end
			start = ender + 1
			process = process + 1
		end
	end
end