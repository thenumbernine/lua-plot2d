package = "plot2d"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/lua-plot2d"
}
description = {
	summary = "2D plotting in opengl",
	detailed = "2D plotting in opengl",
	homepage = "https://github.com/thenumbernine/lua-plot2d",
	license = "MIT"
}
dependencies = {
	"lua ~> 5.1"
}
build = {
	type = "builtin",
	modules = {
		["plot2d.app"] = "app.lua",
		["plot2d"] = "plot2d.lua",
		["plot2d.run"] = "run.lua"
	}
}
