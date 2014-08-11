#!/usr/bin/env luajit
--[[ invoke with gnuplot-formatted files

data will be in the form of "x y [z]"
and plotted accordingly

--]]
local args = {...}

require 'ext'
local graphs = table()

local defaultValue = 0

for _,fn in ipairs(args) do
	if not io.fileexists(fn) then
		io.stderr:write('file '..tostring(fn)..' does not exist\n')
		io.stderr:flush()
	else
		local g = {enabled=true}
		
		local j = 1
		for l in io.lines(fn) do
			local ws = l:trim():split('%s+')
			if #ws == 0 then
				-- then this is a row separator in splot
			else
				for i=1,#ws do
					if not g[i] then g[i] = table() end
					g[i][j] = tonumber(ws[i])
				end
				j = j + 1
			end
		end

		local jmax = j
		for i=1,#g do
			local gi = g[i]
			for j=1,jmax do
				gi[j] = gi[j] or defaultValue
			end
		end
		
		graphs[fn] = g
	end
end

local plot2d = require 'plot2d'
plot2d(graphs)
