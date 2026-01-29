local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local path = require 'ext.path'
local assert = require 'ext.assert'
local gl = require 'gl'
local glu = require 'ffi.req' 'glu'
local sdl = require 'sdl'
local ig = require 'imgui'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'
local box2 = require 'vec.box2'
local ImGuiApp = require 'imgui.app'

local GLSceneObject = require 'gl.sceneobject'


local Plot2DApp = ImGuiApp:subclass()

function Plot2DApp:init(...)
	self.initArgs = {...}

	self.viewpos = vec2()
	self.viewsize = vec2(1,1)
	self.viewbbox = box2()
	self.leftButtonDown = false
	self.leftShiftDown = false
	self.rightShiftDown = false
	self.mousepos = vec2()

	Plot2DApp.super.init(self, ...)
end

-- TODO somehow, try to unify the API of this and of gnuplot package
function Plot2DApp:setGraphInfo(graphs, numRows)
	self.graphs = graphs or {}
	self.numRows = numRows

	for name,graph in pairs(self.graphs) do
		if not graph.color then
			local c = vec3(math.random(),math.random(),math.random())
			c = c / math.max(table.unpack(c))
			graph.color = c
		end

		-- for imgui ... should I move this check there?
		if graph.enabled == nil then graph.enabled = true end
		if graph.showLines == nil then graph.showLines = true end
		if graph.showPoints == nil then graph.showPoints = false end

		local length
		for _,data in ipairs(graph) do
			if not length then
				length = #data
			else
				assert.eq(#data, length, "data mismatched length, found "..#data.." expected "..length)
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

function Plot2DApp:initGL()
	Plot2DApp.super.initGL(self)

	self.view = require 'glapp.view'{
		ortho = true,
	}

	self.lineObj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
in vec4 vertex;
uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vertex;
}
]],
			fragmentCode = [[
out vec4 fragColor;
uniform vec4 color;
void main() {
	fragColor = color;
}
]],
		},
		vertexes = {
			dim = 4,
			useVec = true,
		},
		geometry = {
			mode = gl.GL_LINES,
		},
	}

	self:setGraphInfo(table.unpack(self.initArgs))

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

function Plot2DApp:event(event)
	Plot2DApp.super.event(self, event)
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	local canHandleKeyboard = not ig.igGetIO()[0].WantCaptureKeyboard

	local w, h = self:size()
	if event[0].type == sdl.SDL_EVENT_MOUSE_MOTION then
		self.mousepos[1], self.mousepos[2] = event[0].motion.x / w, event[0].motion.y / h
		if self.leftButtonDown then
			if self.leftShiftDown or self.rightShiftDown then
				-- stretch individual axis
				self.viewsize[1] = self.viewsize[1] * math.exp(-.01 * event[0].motion.xrel)
				self.viewsize[2] = self.viewsize[2] * math.exp(.01 * event[0].motion.yrel)
			else
				-- pan
				self.viewpos = self.viewpos + vec2(
					-event[0].motion.xrel / w * (self.viewbbox.max[1] - self.viewbbox.min[1]),
					event[0].motion.yrel / h * (self.viewbbox.max[2] - self.viewbbox.min[2]))
			end
		end
	elseif event[0].type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN then
		if canHandleMouse then
			if event[0].button.button == sdl.SDL_BUTTON_LEFT then
				self.leftButtonDown = true
			end
		end
	elseif event[0].type == sdl.SDL_EVENT_MOUSE_BUTTON_UP then
		if canHandleMouse then
			if event[0].button.button == sdl.SDL_BUTTON_LEFT then
				self.leftButtonDown = false
			end
		end
	elseif event[0].type == SDL_EVENNT_MOUSE_WHEEL then
		local x = event[0].wheel.x
		local y = event[0].wheel.y
		local dx = 10 * event[0].wheel.x
		local dy = 10 * event[0].wheel.y

		local aspectRatio = self.width / self.height
		local fdx = -2 * dx / self.width * self.view.orthoSize * aspectRatio
		local fdy = 2 * dy / self.height * self.view.orthoSize
		self.viewpos = self.viewpos + vec2(fdx, fdy)
	end
	if canHandleKeyboard then
		if event[0].type == sdl.SDL_EVENT_KEY_DOWN then
			if event[0].key.key == sdl.SDLK_R then
				self:resetView()
			elseif event[0].key.key == sdl.SDLK_LSHIFT then
				self.leftShiftDown = true
			elseif event[0].key.key == sdl.SDLK_RSHIFT then
				self.rightShiftDown = true
			end
		elseif event[0].type == sdl.SDL_EVENT_KEY_UP then
			if event[0].key.key == sdl.SDLK_LSHIFT then
				self.leftShiftDown = false
			elseif event[0].key.key == sdl.SDLK_RSHIFT then
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

	self.view.mvMat:setIdent()
	self.view.projMat:setOrtho(self.viewbbox.min[1], self.viewbbox.max[1], self.viewbbox.min[2], self.viewbbox.max[2], -1, 1)
	self.view.mvProjMat:copy(self.view.projMat)

	self.lineObj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.lineObj.uniforms.color = {.2, .2, .2, 1}
	local vertexVec = self.lineObj.attrs.vertex.buffer.vec
	self.lineObj:beginUpdate()
	do
		local gridScale = 5^(math.floor(math.log(self.viewsize[1]) / math.log(5))-1)
		local ixmin = math.floor(self.viewbbox.min[1]/gridScale)
		local ixmax = math.ceil(self.viewbbox.max[1]/gridScale)
		if ixmax - ixmin < 100 then
			for ix=ixmin,ixmax do
				local x = ix * gridScale
				vertexVec:emplace_back():set(x, self.viewbbox.min[2], 0, 1)
				vertexVec:emplace_back():set(x, self.viewbbox.max[2], 0, 1)
			end
		end
		local gridScale = 5^(math.floor(math.log(self.viewsize[2]) / math.log(5))-1)
		local iymin = math.floor(self.viewbbox.min[2]/gridScale)
		local iymax = math.ceil(self.viewbbox.max[2]/gridScale)
		if iymax - iymin < 100 then
			for iy=iymin,iymax do
				local y = iy * gridScale
				vertexVec:emplace_back():set(self.viewbbox.min[1], y, 0, 1)
				vertexVec:emplace_back():set(self.viewbbox.max[1], y, 0, 1)
			end
		end
	end
	self.lineObj:endUpdate()

	self.lineObj.uniforms.color = {.5, .5, .5, 1}
	self.lineObj:beginUpdate()
	do
		if self.viewbbox.min[1] < 0 and self.viewbbox.max[1] > 0 then
			vertexVec:emplace_back():set(0, self.viewbbox.min[2], 0, 1)
			vertexVec:emplace_back():set(0, self.viewbbox.max[2], 0, 1)
		end
		if self.viewbbox.min[2] < 0 and self.viewbbox.max[2] > 0 then
			vertexVec:emplace_back():set(self.viewbbox.min[1], 0, 0, 1)
			vertexVec:emplace_back():set(self.viewbbox.max[1], 0, 0, 1)
		end
	end
	self.lineObj:endUpdate()

	for _,graph in pairs(self.graphs) do
		if graph.enabled then
			self.lineObj.uniforms.color = {graph.color[1], graph.color[2], graph.color[3], 1}
			if graph.showLines then
				self.lineObj.geometry.mode = gl.GL_LINE_STRIP
				self.lineObj:beginUpdate()
				for i=1,graph.length do
					vertexVec:emplace_back():set(graph[1][i], graph[2][i], 0, 1)
				end
				self.lineObj:endUpdate()
				self.lineObj.geometry.mode = gl.GL_LINES
			end
			if graph.showPoints then
				gl.glPointSize(graph.pointSize or 3)	-- TODO only show points when zoomed in such that the smallest distance ... mean distance between points is greater than 3 pixels on the screen
				self.lineObj.geometry.mode = gl.GL_POINTS
				self.lineObj:beginUpdate()
				for i=1,graph.length do
					vertexVec:emplace_back():set(graph[1][i], graph[2][i], 0, 1)
				end
				self.lineObj:endUpdate()
				self.lineObj.geometry.mode = gl.GL_LINES
				gl.glPointSize(1)
			end
		end
	end

	Plot2DApp.super.update(self, ...)
end

function Plot2DApp:checkbox(...)
	if self.conciseView then
		ig.igSameLine()
		return ig.luatableTooltipCheckbox(...)
	else
		return ig.luatableCheckbox(...)
	end
end

function Plot2DApp:addGUIRow(graph, name)
	ig.igPushID_Str('graph '..name)

	if not self.conciseView then
		ig.igText(name)
	end

	if self.conciseView then
		ig.luatableTooltipCheckbox(name, graph, 'enabled')
	else
		ig.luatableCheckbox(name, graph, 'enabled')
	end
	if self.conciseView or ig.igCollapsingHeader'' then
		self:checkbox('show lines', graph, 'showLines')
		self:checkbox('show points', graph, 'showPoints')

		if graph.color then
			ig.igSameLine()
			--[[ edit R G B or picker
			ig.luatableColorEdit3('color', graph, 'color', 0)
			--]]
			--[[ giant embedded picker
			ig.luatableColorPicker3('color', graph, 'color', 0)
			--]]
			-- would be nice to have the picker upon popup, like igColorEdit3 does, but without the R G B text entry that igColorEdit3 does ...
			if ig.igColorButton(
				'color',
				ig.ImVec4(graph.color[1], graph.color[2], graph.color[3], 1),
				0
			) then
				-- TODO modal window of this ...
				ig.luatableColorPicker3('color', graph, 'color', 0)
			end
		end
		if self.conciseView then
			ig.igSameLine()
			ig.igText(name)
		end
	end
	ig.igPopID()
end

Plot2DApp.showMouseCoords = false
function Plot2DApp:updateGUI()
	-- TODO store graphs as {name=name, ...} instead of name={...}
	-- but that would break things that use plot2d
	local graphNames = table.keys(self.graphs):sort()

	self:checkbox('show coords', self, 'showMouseCoords')

	ig.igText'Graphs:'

	local graphFields = table{'enabled', 'showLines', 'showPoints'}
	local all = graphFields:map(function(field) return true, field end)
	for _,name in ipairs(graphNames) do
		local graph = self.graphs[name]
		for _,field in ipairs(graphFields) do
			all[field] = all[field] and graph[field]
		end
	end
	local allWas = table(all)
	self:addGUIRow(all, 'all')
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
		self:addGUIRow(graph, tostring(name))
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
