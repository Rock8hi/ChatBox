local skynet = require "skynet"
local netpack = require "netpack"

local CMD = {}
local auto_id=0
local chat_user_list={}
local agents={}

local function is_exist(name)
	for userid, userinfo in pairs(chat_user_list) do
		if userinfo.name == name then
			return true
		end
	end
	return false
end

function CMD.get_user_list(msg)
	local users = {}
	for userid, userinfo in pairs(chat_user_list) do
		table.insert(users, userinfo)
	end
	return {cmd = "get_user_list", code = "ok", users = users}
end

-- msg.name: 用户注册的昵称
function CMD.create_user(agent, msg)
	if is_exist(msg.name) then
		return {cmd = "create_user", code="exist"} --已经存在该名字
	end
	
	auto_id = auto_id + 1
	
	local user_info = {userid = auto_id, name = msg.name}
	chat_user_list[user_info.userid] = user_info
	
	agents[user_info.userid] = agent
	
	-- 广播给其他在线用户，有新用户上线了
	for userid, agent in pairs(agents) do
		skynet.call(agent, "lua", "notify_new_user", {cmd = "notify_new_user", code = "ok", users = user_info})
	end
	
	-- 回复新用户，创建账号成功
	return {cmd = "create_user", code = "ok", users = user_info}
end

-- 移除离线用户
function CMD.remove_user(agent)
	local temp_userid
	for userid1, agent1 in pairs(agents) do
		if agent1 == agent then
			temp_userid = userid1
			break
		end
	end
	
	if not temp_userid then
		return
	end
	
	-- 移除代理
	agents[temp_userid] = nil
	
	-- 通知其他玩家
	for userid2, agent2 in pairs(agents) do
		skynet.call(agent2, "lua", "notify_remove_user", {cmd = "notify_remove_user", code = "ok", users = chat_user_list[temp_userid]})
	end
	
	-- 移除玩家信息
	chat_user_list[temp_userid] = nil
end

-- msg.chat: 聊天内容
function CMD.send_message(msg)
	-- 把聊天内容广播给所有用户
	for userid, agent in pairs(agents) do
		skynet.call(agent, "lua", "notify_message", {cmd = "notify_message", code = "ok", chat = msg.chat})
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, cmd, ...)
		local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
