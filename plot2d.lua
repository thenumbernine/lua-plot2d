--[[
TODO make modular
- allow dynamic update of data
- separate rendering from viewport setup (so other apps can incorporate overlays)
... or incorporate multiple viewports into this program as well ... like gnuplot, matlab, etc allow split views of separate graphs in one window
	gnuplot has "set multiple layout <cols>,<rows>" ...
	i could do that, or i could allow custom x,y locations, ...

How do I want this to end up?
1) some standalone (modal) interface:
	plot2d = require 'plot2d.plot2d'
	plot2d{data, labels, viewports (splits), etc}

2) some interactive (modalless) interface
	Plot2DApp = require 'plot2d.plot2dapp'
	local plot2DApp = Plot2DApp{similar setup info}
	plot2DApp:run()	<- same behavior as invoking 'plot2d' standalone
	... or invoke the individual plot2DApp commands

--]]
local ffi = require 'ffi'
local gl = require 'ffi.OpenGL'
local glu = require 'ffi.glu'
local sdl = require 'ffi.sdl'
local GLApp = require 'glapp'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'
local box2 = require 'vec.box2'
local GUI = require 'gui'

local resetView

--[[
graphs = {
	[name] = {
		[enabled = true,]	-- optional
		{x1,x2,...},
		{y1,y2,...},
		...
	}
--]]
local function plot2d(graphs, numRows, fontfile)

	for name,graph in pairs(graphs) do
		if not graph.color then
			local c = vec3(math.random(),math.random(),math.random())
			c = c / math.max(unpack(c))
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

	local viewpos = vec2()
	local viewsize = vec2(1,1)
	local viewbbox = box2()
	local leftButtonDown = false
	local leftShiftDown = false
	local rightShiftDown = false
	local gui
	local coordText
	local mousepos = vec2()

	resetView = function()
		local min = {}
		local max = {}
		for name,graph in pairs(graphs) do
			if graph.enabled then
				for j,data in ipairs(graph) do
					for _,v in ipairs(data) do
						min[j] = min[j] and math.min(min[j], v) or v
						max[j] = max[j] and math.max(max[j], v) or v
					end
				end
			end
		end
		if min[1] and max[1] and min[2] and max[2] then
			viewpos = vec2((min[1] + max[1]) * .5, (min[2] + max[2]) * .5)
			viewsize = vec2(math.max(max[1] - min[1], 1e-10), math.max(max[2] - min[2], 1e-10))
		end
	end
	
	resetView()

	local glapp = GLApp()
	
	function glapp:initGL()
		
		if not fontfile or not io.fileexists(fontfile) then
			fontfile = '/Users/christophermoore/Projects/lua/plot2d/font.png'
		end
	
		gui = GUI{font=fontfile}
		
		local names = table()
		for name,_ in pairs(graphs) do
			names:insert(name)
		end
		names:sort()
		
		local function colorForEnabled(graph)
			if graph.enabled then
				return graph.color[1], graph.color[2], graph.color[3], 1
			else
				return .4, .4, .4, 1
			end
		end
		
		local Text = require 'gui.widget.text'
		
		coordText = gui:widget{
			class=Text,
			text='',
			parent={gui.root},
			pos={0,0},
			fontSize={2,2}
		}
		
		local y = 1
		local x = 1
		for i,name in ipairs(names) do
			local graph = graphs[name]
			gui:widget{
				class=Text,
				text=name,
				parent={gui.root},
				pos={x,y},
				fontSize={2,2},
				graph=graph,
				fontColor={colorForEnabled(graph)},
				mouseEvent=function(menu,event,x,y)
					if bit.band(event,1) ~= 0 then	-- left press
						graph.enabled = not graph.enabled
						menu:fontColor(colorForEnabled(graph))
					end
				end,
			}
			y=y+2
			
			if numRows and i % numRows == 0 then
				y = 1
				x = x + 10
			end
		end
		
		gl.glClearColor(0,0,0,0)
	end
	
	function glapp:event(event)
		local w, h = self:size()
		if event.type == sdl.SDL_MOUSEMOTION then
			mousepos[1], mousepos[2] = event.motion.x / w, event.motion.y / h
			if leftButtonDown then
				if leftShiftDown or rightShiftDown then
					-- stretch individual axis
					viewsize[1] = viewsize[1] * math.exp(-.01 * event.motion.xrel)
					viewsize[2] = viewsize[2] * math.exp(.01 * event.motion.yrel)
				else
					-- pan
					viewpos = viewpos + vec2(
						-event.motion.xrel / w * (viewbbox.max[1] - viewbbox.min[1]),
						event.motion.yrel / h * (viewbbox.max[2] - viewbbox.min[2]))
				end
			end
		elseif event.type == sdl.SDL_MOUSEBUTTONDOWN then
			if event.button.button == sdl.SDL_BUTTON_LEFT then
				leftButtonDown = true
			elseif event.button.button == sdl.SDL_BUTTON_WHEELUP then
				local delta = vec2(
					(event.button.x/w - .5) * (viewbbox.max[1] - viewbbox.min[1]),
					(.5 - event.button.y/h) * (viewbbox.max[2] - viewbbox.min[2]))
				viewpos = viewpos + delta * (1 - .9)
				viewsize = viewsize * .9
			elseif event.button.button == sdl.SDL_BUTTON_WHEELDOWN then
				local delta = vec2(
					(event.button.x/w - .5) * (viewbbox.max[1] - viewbbox.min[1]),
					(.5 - event.button.y/h) * (viewbbox.max[2] - viewbbox.min[2]))
				viewpos = viewpos + delta * (1 - 1 / .9)
				viewsize = viewsize / .9
			end
		elseif event.type == sdl.SDL_MOUSEBUTTONUP then
			if event.button.button == sdl.SDL_BUTTON_LEFT then
				leftButtonDown = false
			end
		elseif event.type == sdl.SDL_KEYDOWN then
			if event.key.keysym.sym == sdl.SDLK_r then
				resetView()
			elseif event.key.keysym.sym == sdl.SDLK_LSHIFT then
				leftShiftDown = true
			elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
				rightShiftDown = true
			end
		elseif event.type == sdl.SDL_KEYUP then
			if event.key.keysym.sym == sdl.SDLK_LSHIFT then
				leftShiftDown = false 
			elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
				rightShiftDown = false 
			end
		end
	end
		
	function glapp:update()
		local w, h = self:size()
		local ar = w / h
		gl.glClear(gl.GL_COLOR_BUFFER_BIT)
		
		viewbbox.min = viewpos - vec2(viewsize[1], viewsize[2])
		viewbbox.max = viewpos + vec2(viewsize[1], viewsize[2])
		
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glLoadIdentity()
		gl.glOrtho(viewbbox.min[1], viewbbox.max[1], viewbbox.min[2], viewbbox.max[2], -1, 1)
		gl.glMatrixMode(gl.GL_MODELVIEW)
		
		local mx, my = gui:sysSize()
		coordText:pos(mousepos[1] * mx, mousepos[2] * my)
		coordText:setText(
			('%.3e'):format(mousepos[1] * viewbbox.max[1] + (1-mousepos[1]) * viewbbox.min[1])..','..
			('%.3e'):format((1-mousepos[2]) * viewbbox.max[2] + mousepos[2] * viewbbox.min[2])
		)

		gl.glBegin(gl.GL_LINES)
		do
			local gridScale = 5^(math.floor(math.log(viewsize[1]) / math.log(5))-1)
			gl.glColor3f(.2, .2, .2)
			local ixmin = math.floor(viewbbox.min[1]/gridScale)
			local ixmax = math.ceil(viewbbox.max[1]/gridScale)
			if ixmax - ixmin < 100 then
				for ix=ixmin,ixmax do
					local x = ix * gridScale
					gl.glVertex2d(x, viewbbox.min[2])
					gl.glVertex2d(x, viewbbox.max[2])
				end
			end
			local gridScale = 5^(math.floor(math.log(viewsize[2]) / math.log(5))-1)
			local iymin = math.floor(viewbbox.min[2]/gridScale)
			local iymax = math.ceil(viewbbox.max[2]/gridScale)
			if iymax - iymin < 100 then
				for iy=iymin,iymax do
					local y = iy * gridScale
					gl.glVertex2d(viewbbox.min[1], y)
					gl.glVertex2d(viewbbox.max[1], y)
				end
			end
		end
		do
			gl.glColor3f(.5, .5, .5)
			if viewbbox.min[1] < 0 and viewbbox.max[1] > 0 then
				gl.glVertex2d(0, viewbbox.min[2])
				gl.glVertex2d(0, viewbbox.max[2])
			end
			if viewbbox.min[2] < 0 and viewbbox.max[2] > 0 then
				gl.glVertex2d(viewbbox.min[1], 0)
				gl.glVertex2d(viewbbox.max[1], 0)
			end
		end
		gl.glEnd()
		
		for _,graph in pairs(graphs) do
			if graph.enabled then
				gl.glColor3f(graph.color[1], graph.color[2], graph.color[3])
				gl.glBegin(gl.GL_LINE_STRIP)
				for i=1,graph.length do
					gl.glVertex2d(graph[1][i], graph[2][i])
				end
				gl.glEnd()
				gl.glPointSize(3)	-- TODO only show points when zoomed in such that the smallest distance ... mean distance between points is greater than 3 pixels on the screen
				gl.glBegin(gl.GL_POINTS)
				for i=1,graph.length do
					gl.glVertex2d(graph[1][i], graph[2][i])
				end
				gl.glEnd()
				gl.glPointSize(1)
			end
		end
		
		gui:update()
	end
	
	glapp:run()
end

return plot2d
