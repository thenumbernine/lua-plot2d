local ffi = require 'ffi'
local gl = require 'gl'
local glu = require 'ffi.glu'
local sdl = require 'ffi.sdl'
local ig = require 'imgui'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'
local box2 = require 'vec.box2'
local ImGuiApp = require 'imguiapp'
local class = require 'ext.class'
local table = require 'ext.table'
local file = require 'ext.file'

local Plot2DApp = class(ImGuiApp)

function Plot2DApp:init(...)
	self.initArgs = {...}
	
	self.viewpos = vec2()
	self.viewsize = vec2(1,1)
	self.viewbbox = box2()
	self.leftButtonDown = false
	self.leftShiftDown = false
	self.rightShiftDown = false
	self.mousepos = vec2()
	
	return Plot2DApp.super.init(self, ...)
end

function Plot2DApp:setGraphInfo(graphs, numRows, fontfile)
	self.graphs = graphs
	self.numRows = numRows
	self.fontfile = fontfile

	for name,graph in pairs(self.graphs) do
		if not graph.color then
			local c = vec3(math.random(),math.random(),math.random())
			c = c / math.max(table.unpack(c))
			graph.color = c
		end
		local length
		for _,data in ipairs(graph) do
			if not length then
				length = #data
			else
				assert(#data == length, "data mismatched length, found "..#data.." expected "..length)
			end
		end
		graph.length = length
	end
	
	self:resetView()
end

function Plot2DApp:resetView()
	local min = {}
	local max = {}
	for name,graph in pairs(self.graphs) do
		if graph.enabled ~= false then
			for j,data in ipairs(graph) do
				for _,v in ipairs(data) do
					min[j] = min[j] and math.min(min[j], v) or v
					max[j] = max[j] and math.max(max[j], v) or v
				end
			end
		end
	end
	if min[1] and max[1] and min[2] and max[2] then
		self.viewpos = vec2((min[1] + max[1]) * .5, (min[2] + max[2]) * .5)
		self.viewsize = vec2(math.max(max[1] - min[1], 1e-10), math.max(max[2] - min[2], 1e-10))
	end
end

function Plot2DApp:initGL(...)
	Plot2DApp.super.initGL(self, ...)
	self:setGraphInfo(table.unpack(self.initArgs))

	if not self.fontfile or not file(self.fontfile):exists() then
		self.fontfile = (os.getenv'HOME' or os.getenv'USERPROFILE')..'/Projects/lua/plot2d/font.png'
	end

	local names = table()
	for name,_ in pairs(self.graphs) do
		names:insert(name)
	end
	names:sort()
	
	local function colorForEnabled(graph)
		if graph.enabled~=false then
			return graph.color[1], graph.color[2], graph.color[3], 1
		else
			return .4, .4, .4, 1
		end
	end
	
	gl.glClearColor(0,0,0,0)
end

function Plot2DApp:event(event, ...)
	Plot2DApp.super.event(self, event, ...)
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	local canHandleKeyboard = not ig.igGetIO()[0].WantCaptureKeyboard
	
	local w, h = self:size()
	if event.type == sdl.SDL_MOUSEMOTION then
		self.mousepos[1], self.mousepos[2] = event.motion.x / w, event.motion.y / h
		if self.leftButtonDown then
			if self.leftShiftDown or self.rightShiftDown then
				-- stretch individual axis
				self.viewsize[1] = self.viewsize[1] * math.exp(-.01 * event.motion.xrel)
				self.viewsize[2] = self.viewsize[2] * math.exp(.01 * event.motion.yrel)
			else
				-- pan
				self.viewpos = self.viewpos + vec2(
					-event.motion.xrel / w * (self.viewbbox.max[1] - self.viewbbox.min[1]),
					event.motion.yrel / h * (self.viewbbox.max[2] - self.viewbbox.min[2]))
			end
		end
	elseif event.type == sdl.SDL_MOUSEBUTTONDOWN then
		if canHandleMouse then
			if event.button.button == sdl.SDL_BUTTON_LEFT then
				self.leftButtonDown = true
			elseif event.button.button == sdl.SDL_BUTTON_WHEELUP then
				local delta = vec2(
					(event.button.x/w - .5) * (self.viewbbox.max[1] - self.viewbbox.min[1]),
					(.5 - event.button.y/h) * (self.viewbbox.max[2] - self.viewbbox.min[2]))
				self.viewpos = self.viewpos + delta * (1 - .9)
				self.viewsize = self.viewsize * .9
			elseif event.button.button == sdl.SDL_BUTTON_WHEELDOWN then
				local delta = vec2(
					(event.button.x/w - .5) * (self.viewbbox.max[1] - self.viewbbox.min[1]),
					(.5 - event.button.y/h) * (self.viewbbox.max[2] - self.viewbbox.min[2]))
				self.viewpos = self.viewpos + delta * (1 - 1 / .9)
				self.viewsize = self.viewsize / .9
			end
		end
	elseif event.type == sdl.SDL_MOUSEBUTTONUP then
		if canHandleMouse then
			if event.button.button == sdl.SDL_BUTTON_LEFT then
				self.leftButtonDown = false
			end
		end
	end
	if canHandleKeyboard then
		if event.type == sdl.SDL_KEYDOWN then
			if event.key.keysym.sym == sdl.SDLK_r then
				self:resetView()
			elseif event.key.keysym.sym == sdl.SDLK_LSHIFT then
				self.leftShiftDown = true
			elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
				self.rightShiftDown = true
			end
		elseif event.type == sdl.SDL_KEYUP then
			if event.key.keysym.sym == sdl.SDLK_LSHIFT then
				self.leftShiftDown = false 
			elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
				self.rightShiftDown = false 
			end
		end
	end
end

function Plot2DApp:update(...)
	
	local w, h = self:size()
	local ar = w / h
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)

	self.viewbbox.min = self.viewpos - vec2(self.viewsize[1], self.viewsize[2])
	self.viewbbox.max = self.viewpos + vec2(self.viewsize[1], self.viewsize[2])
	
	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glOrtho(self.viewbbox.min[1], self.viewbbox.max[1], self.viewbbox.min[2], self.viewbbox.max[2], -1, 1)
	gl.glMatrixMode(gl.GL_MODELVIEW)
	
	gl.glBegin(gl.GL_LINES)
	do
		local gridScale = 5^(math.floor(math.log(self.viewsize[1]) / math.log(5))-1)
		gl.glColor3f(.2, .2, .2)
		local ixmin = math.floor(self.viewbbox.min[1]/gridScale)
		local ixmax = math.ceil(self.viewbbox.max[1]/gridScale)
		if ixmax - ixmin < 100 then
			for ix=ixmin,ixmax do
				local x = ix * gridScale
				gl.glVertex2d(x, self.viewbbox.min[2])
				gl.glVertex2d(x, self.viewbbox.max[2])
			end
		end
		local gridScale = 5^(math.floor(math.log(self.viewsize[2]) / math.log(5))-1)
		local iymin = math.floor(self.viewbbox.min[2]/gridScale)
		local iymax = math.ceil(self.viewbbox.max[2]/gridScale)
		if iymax - iymin < 100 then
			for iy=iymin,iymax do
				local y = iy * gridScale
				gl.glVertex2d(self.viewbbox.min[1], y)
				gl.glVertex2d(self.viewbbox.max[1], y)
			end
		end
	end
	do
		gl.glColor3f(.5, .5, .5)
		if self.viewbbox.min[1] < 0 and self.viewbbox.max[1] > 0 then
			gl.glVertex2d(0, self.viewbbox.min[2])
			gl.glVertex2d(0, self.viewbbox.max[2])
		end
		if self.viewbbox.min[2] < 0 and self.viewbbox.max[2] > 0 then
			gl.glVertex2d(self.viewbbox.min[1], 0)
			gl.glVertex2d(self.viewbbox.max[1], 0)
		end
	end
	gl.glEnd()
	
	for _,graph in pairs(self.graphs) do
		if graph.enabled~=false then
			gl.glColor3f(graph.color[1], graph.color[2], graph.color[3])
			if graph.showLines~=false then
				gl.glBegin(gl.GL_LINE_STRIP)
				for i=1,graph.length do
					gl.glVertex2d(graph[1][i], graph[2][i])
				end
				gl.glEnd()
			end
			if graph.showPoints then
				gl.glPointSize(graph.pointSize or 3)	-- TODO only show points when zoomed in such that the smallest distance ... mean distance between points is greater than 3 pixels on the screen
				gl.glBegin(gl.GL_POINTS)
				for i=1,graph.length do
					gl.glVertex2d(graph[1][i], graph[2][i])
				end
				gl.glEnd()
				gl.glPointSize(1)
			end
		end
	end
	
	Plot2DApp.super.update(self, ...)
end

Plot2DApp.showMouseCoords = false
local float3 = ffi.new('float[3]')
function Plot2DApp:updateGUI()
	-- TODO store graphs as {name=name, ...} instead of name={...}
	-- but that would break things that use plot2d
	local graphNames = table.keys(self.graphs):sort()

	ig.luatableCheckbox('show coords', self, 'showMouseCoords')

	ig.igText'Graphs:'
	local function graphGUI(graph, name)
		ig.igPushID_Str('graph '..name)
		ig.luatableCheckbox(name, graph, 'enabled')
		ig.igSameLine()
		if ig.igCollapsingHeader'' then
			ig.luatableCheckbox('show lines', graph, 'showLines')
			ig.luatableCheckbox('show points', graph, 'showPoints')
		
			if graph.color then
				for i=1,3 do
					float3[i-1] = graph.color[i]
				end
				if ig.igColorEdit3('color', float3, 0) then
					for i=1,3 do
						graph.color[i] = float3[i-1]
					end
				end
			end
		end
		ig.igPopID()
	end

	local graphFields = table{'enabled', 'showLines', 'showPoints'}
	local all = graphFields:map(function(field) return true, field end)
	for _,name in ipairs(graphNames) do
		local graph = self.graphs[name]
		for _,field in ipairs(graphFields) do
			all[field] = all[field] and graph[field]
		end
	end
	local allWas = table(all)
	graphGUI(all, 'all')
	for _,field in ipairs(graphFields) do
		if all[field] ~= allWas[field] then
			for _,name in ipairs(graphNames) do
				local graph = self.graphs[name]
				graph[field] = all[field]
			end
		end
	end

	for _,name in ipairs(graphNames) do
		local graph = self.graphs[name]
		graphGUI(graph, name)
	end

	if self.showMouseCoords then
		ig.igBeginTooltip()
		ig.igText(self:getCoordText())
		ig.igEndTooltip()
	end
end

function Plot2DApp:getCoordText()
	return ('%.3e, %.3e'):format(
		self.mousepos[1] * self.viewbbox.max[1] + (1-self.mousepos[1]) * self.viewbbox.min[1],
		(1-self.mousepos[2]) * self.viewbbox.max[2] + self.mousepos[2] * self.viewbbox.min[2]
	)
end

return Plot2DApp
