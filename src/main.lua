local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	skynet.error("server start")
	local chatbox = skynet.newservice("chatbox")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		chatbox = chatbox
	})

	skynet.exit()
end)
