#!/usr/bin/env luajit
--[[ invoke with gnuplot-formatted files

data will be in the form of "x y [z]"
and plotted accordingly

TODO - file vs equations? 

--]]

require 'ext'
local graphs = table()

local defaultValue = 0

for _,fn in ipairs(arg) do
	if not path(fn):exists() then
		io.stderr:write('file '..tostring(fn)..' does not exist\n')
		io.stderr:flush()
	else
		local g = {enabled=true}
	
		-- [[ splot-compat
		local j = 1
		for l in io.lines(fn) do
			local ws = l:trim():split('%s+')
			if #ws == 0 then
				-- if we're dealing with splot data then this is a row separator
				-- if we're dealing with 2d data then this is an invalid entry
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
		--]]

		--[[ 1d-plot compat for graphing 0:1

		local gx = table()
		local gy = table()
		local lines = path(fn):read():split('\n')
		for i,l in ipairs(lines) do
			l = l:trim()
			if #l > 0 then
				local n = tonumber(l)
				if n then
					gx:insert(i)
					gy:insert(n)
				end
			end
		end

		print(gx:inf())
		print(gx:sup())
		print(gy:inf())
		print(gy:sup())
		g[1] = gx
		g[2] = gy
		graphs[fn] = g
		--]]
	end
end

local plot2d = require 'plot2d'
return plot2d(graphs)
