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

graphs = {
	[name] = {
		[enabled = true,]	-- optional
		{x1,x2,...},
		{y1,y2,...},
		...
	}
--]]
local Plot2DApp = require 'plot2d.app'

local function plot2d(graphs, numRows)
	local plot2DApp = Plot2DApp(graphs, numRows)
	return plot2DApp:run()
end

return plot2d
