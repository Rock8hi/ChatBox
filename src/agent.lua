local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local cjson = require "cjson"

local CMD = {}
local client = {}

local chatbox

local client_fd

local function send_package(pack)
	local data = cjson.encode(pack)
	print("send: ", data)
	local package = string.pack(">s2", data)
	socket.write(client_fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg, sz)
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	chatbox = conf.chatbox
	
	skynet.fork(function()
		while true do
			send_package{cmd = "heartbeat"}
			skynet.sleep(500)
		end
	end)
	
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

function CMD.notify_message(msg)
	send_package(msg)
end

function CMD.notify_new_user(msg)
	send_package(msg)
end

function CMD.notify_remove_user(msg)
	send_package(msg)
end

function client.get_user_list(msg)
	return skynet.call(chatbox, "lua", "get_user_list", msg)
end

function client.create_user(msg)
	return skynet.call(chatbox, "lua", "create_user", skynet.self(), msg)
end

function client.send_message(msg)
	return skynet.call(chatbox, "lua", "send_message", msg)
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	
	skynet.dispatch("client", function(_, _, text, ...)
		print("dispatch client: ", text)
		local data = cjson.decode(text)
		local f = assert(client[data.cmd])
		local result = f(data)
		if result then
			send_package(result)
		end
	end)
end)
