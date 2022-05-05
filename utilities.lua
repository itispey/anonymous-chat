local serpent = require 'serpent'
local config = require 'config'
local api = require 'methods'
local ltn12 = require 'ltn12'
local HTTPS = require 'ssl.https'

-- utilities.lua
-- Functions shared among plugins.

local utilities = {}

-- Escape markdown for Telegram. This function makes non-clickable usernames,
-- hashtags, commands, links and emails, if only_markup flag isn't setted.
function string:escape(only_markup)
	if not only_markup then
		-- insert word joiner
		self = self:gsub('([@#/.])(%w)', '%1\xE2\x81\xA0%2')
	end
	return self:gsub('[*_`[]', '\\%0')
end

function string:escape_html()
	self = self:gsub('&', '&amp;')
	self = self:gsub('"', '&quot;')
	self = self:gsub('<', '&lt;'):gsub('>', '&gt;')
	return self
end

-- Remove specified formating or all markdown. This function useful for put
-- names into message. It seems not possible send arbitrary text via markdown.
function string:escape_hard(ft)
	if ft == 'bold' then
		return self:gsub('%*', '')
	elseif ft == 'italic' then
		return self:gsub('_', '')
	elseif ft == 'fixed' then
		return self:gsub('`', '')
	elseif ft == 'link' then
		return self:gsub(']', '')
	else
		return self:gsub('[*_`[%]]', '')
	end
end

function utilities.startCron()
	local plugins = {}
	for i, v in ipairs(config.plugins) do
		local p = require('plugins.'..v)
		package.loaded['plugins.'..v] = nil
		table.insert(plugins, p)
	end
	for i = 1, #plugins do
		if plugins[i].cron then
			local res, err = pcall(plugins[i].cron)
			print(clr.green..'Cron started...'..clr.reset)
			if not res then
				api.sendLog('An #error occurred (cron).\n'..err)
				return
			end
		end
	end
end

function utilities.saveFile(file_path, data)
	local s = JSON.encode(data)
	local f = io.open(file_path, 'w')
	f:write(s)
	f:close()
end

function utilities.loadFile(file_path)
	local file = io.open(file_path)
	local data_ = file:read('*all')
	file:close()
	local data = JSON.decode(data_)
	return data
end

function utilities.saveLog(file_path, text)
	if text == 'del' then
		local file = io.open(file_path, 'w')
		file:close()
		return
	end
	local file = io.open(file_path, 'w')
	file:write(text)
	file:close()
end

function utilities.loadLog(file_path)
	local file = io.open(file_path)
	if not file then
		utilities.saveLog(file_path, '')
		return ''
	end
	local text = file:read('*all')
	file:close()
	return text
end

function utilities.is_superadmin(user_id)
	for i=1, #config.superadmins do
		if tonumber(user_id) == config.superadmins[i] then
			return true
		end
	end
	return false
end

function utilities.join_channel(user_id, callback)
	local res = api.getChatMember(config.channel_id, user_id)
	if not res or (res.result.status == 'kicked' or res.result.status == 'left') then
		local text = [[
	⛔️ کاربر گرامی!
	شما برای استفاده از سرویس ربات لجندری، باید در کانال رسمی لجندری عضو باشید.
	لطفا از طریق دکمه "عضویت"، اقدام به عضو شدن در کانال کنید و سپس توسط دکمه "ادامه"، ادامه مراحل را طی کنید!

	با احترام؛ تیم لجندری
		]]
		local keyboard = {inline_keyboard = {
			{{text = 'عضویت', url = 'https://telegram.me/joinchat/AAAAAEIMxObc7_gBcu-13Q'}},
			{{text = 'ادامه', callback_data = callback}}
		}}
		return text, keyboard
	end
end

function string:trim() -- Trims whitespace from a string.
	local s = self:gsub('^%s*(.-)%s*$', '%1')
	return s
end

function utilities.dump(...)
	for _, value in pairs{...} do
		print(serpent.block(value, {comment=false}))
	end
end

function utilities.vtext(...)
	local lines = {}
	for _, value in pairs{...} do
		table.insert(lines, serpent.block(value, {comment=false}))
	end
	return table.concat(lines, '\n')
end

function utilities.download_to_file(url, file_path)
	print("url to download: "..url)
	local respbody = {}
	local options = {
		url = url,
		sink = ltn12.sink.table(respbody),
		redirect = true
	}
	-- nil, code, headers, status
	local response = nil
	options.redirect = false
	response = {HTTPS.request(options)}
	local code = response[2]
	local headers = response[3]
	local status = response[4]
	if code ~= 200 then return false, code end
	print("Saved to: "..file_path)
	file = io.open(file_path, "w+")
	file:write(table.concat(respbody))
	file:close()
	return file_path, code
end

function utilities.telegram_file_link(res)
	--res = table returned by getFile()
	return "https://api.telegram.org/file/bot"..config.api_token.."/"..res.result.file_path
end

function utilities.deeplink_constructor(chat_id, what)
	return 'https://telegram.me/'..bot.username..'?start='..chat_id..'_'..what
end

function table.clone(t)
  local new_t = {}
  local i, v = next(t, nil)
  while i do
	new_t[i] = v
	i, v = next(t, i)
  end
  return new_t
end

function utilities.get_date(timestamp)
	if not timestamp then
		timestamp = os.time()
	end
	return os.date('%d/%m/%y', timestamp)
end

-- Resolves username. Returns ID of user if it was early stored in date base.
-- Argument username must begin with symbol @ (commercial 'at')
function utilities.resolve_user(username)
	assert(username:byte(1) == string.byte('@'))
	username = username:lower()

	local stored_id = tonumber(db:hget('bot:usernames', username))
	if not stored_id then
		username = username:gsub('@', '')
		print(username)
		local req = api.performRequest('https://guardianplus.ir/apis/getuser/index.php?username='..username)
		local res = JSON.decode(req)
		if res == nil then
			api.sendAdmin(('This API (https://guardianplus.ir/apis/getuser/index.php?username=%s) doesn\'t working.'):format(username))
			return false, 'کاربر مورد نظر پیدا نشد!\nلطفا یکی از پیام های اون کاربر را برای من فوروارد کنید تا اون رو بشناسم.'
		elseif res.ok == 'true' then
			db:hset('bot:usernames', '@'..res.result.username:lower(), res.result.id)
			return res.result.id
		elseif res.ok == 'false' then
			return false, 'نام کاربری اشتباه می باشد.'
		end
	else
		local user_obj = api.getChat(stored_id)
		if not user_obj then
			return stored_id
		else
			if not user_obj.result.username then
				return stored_id
			else
				if username ~= '@'..user_obj.result.username:lower() then
					db:hset('bot:usernames', '@'..user_obj.result.username:lower(), user_obj.result.id)
					return false, 'نام کاربری وارد شده اشتباه می باشد!'
				end
			end
		end
		assert(stored_id == user_obj.result.id)
		return user_obj.result.id
	end
end

function utilities.get_sm_error_string(code)
	local descriptions = {
		[112] = ("این متن به اشتباه مارک شده است!.\n"
					.. "ممکن هست در متن از *Underline* یا خط فاصله بزرگ استفاده شده باشد.\n"),
		[118] = ('این متن خیلی طولانی می باشد. حداکثر کاراکتر مجاز *4000* می باشد.'),
		[146] = ('یکی از لینک هایی که می خواهید درون دکمه شیشه ای قرار بدهید، اشتباه می باشد! لطفا لینک را چک کنید.'),
		[137] = ("یکی از دکمه های شیشه ای مشکلی دارد! احتمالا متن آن را ننوشته اید یا لینک آن اشتباه می باشد."),
		[149] = ("یکی از دکمه های شیشه ای مشکلی دارد! احتمالا متن آن را ننوشته اید یا لینک آن اشتباه می باشد."),
		[115] = ("لطفا یک متنی را وارد کنید.")
	}

	return descriptions[code] or ("فرمت متن اشتباه است.")
end

function string:escape_magic()
	self = self:gsub('%%', '%%%%')
	self = self:gsub('%-', '%%-')
	self = self:gsub('%?', '%%?')

	return self
end

function utilities.get_media_type(msg)
	if msg.photo then
		return 'photo'
	elseif msg.video then
		return 'video'
	elseif msg.video_note then
		return 'video_note'
	elseif msg.audio then
		return 'audio'
	elseif msg.voice then
		return 'voice'
	elseif msg.document then
		if msg.document.mime_type == 'video/mp4' then
			return 'gif'
		else
			return 'document'
		end
	elseif msg.sticker then
		return 'sticker'
	elseif msg.contact then
		return 'contact'
	elseif msg.location then
		return 'location'
	elseif msg.game then
		return 'game'
	elseif msg.venue then
		return 'venue'
	else
		return false
	end
end

function utilities.get_media_id(msg)
	if msg.photo then
		return msg.photo[#msg.photo].file_id, 'photo'
	elseif msg.document then
		return msg.document.file_id
	elseif msg.video then
		return msg.video.file_id, 'video'
	elseif msg.audio then
		return msg.audio.file_id
	elseif msg.voice then
		return msg.voice.file_id, 'voice'
	elseif msg.sticker then
		return msg.sticker.file_id
	else
		return false, 'The message has not a media file_id'
	end
end

function utilities.migrate_chat_info(old, new, on_request)
	if not old or not new then
		return false
	end

	for hash_name, hash_content in pairs(config.chat_settings) do
		local old_t = db:hgetall('chat:'..old..':'..hash_name)
		if next(old_t) then
			for key, val in pairs(old_t) do
				db:hset('chat:'..new..':'..hash_name, key, val)
			end
		end
	end

	for _, hash_name in pairs(config.chat_hashes) do
		local old_t = db:hgetall('chat:'..old..':'..hash_name)
		if next(old_t) then
			for key, val in pairs(old_t) do
				db:hset('chat:'..new..':'..hash_name, key, val)
			end
		end
	end

	for i=1, #config.chat_sets do
		local old_t = db:smembers('chat:'..old..':'..config.chat_sets[i])
		if next(old_t) then
			db:sadd('chat:'..new..':'..config.chat_sets[i], table.unpack(old_t))
		end
	end

	if on_request then
		api.sendReply(msg, 'Should be done')
	end
end

-- Return user mention for output a text
function utilities.getname_final(user)
	--return utilities.getname_link(user.first_name, user.username) or '<code>'..user.first_name:escape_html()..'</code>'
	return string.format('<a href="tg://user?id=%s">%s</a>', user.id, user.first_name:escape_html())
end

-- Return link to user profile or false, if he doesn't have login
function utilities.getname_link(name, username)
	if not name or not username then return nil end
	username = username:gsub('@', '')
	return ('<a href="%s">%s</a>'):format('https://telegram.me/'..username, name:escape_html())
end

function utilities.bash(str)
	local cmd = io.popen(str)
	local result = cmd:read('*all')
	cmd:close()
	return result
end

function utilities.telegram_file_link(res)
	--res = table returned by getFile()
	return "https://api.telegram.org/file/bot"..config.telegram.token.."/"..res.result.file_path
end

function utilities.getRules(chat_id)
	local hash = 'chat:'..chat_id..':info'
	local rules = db:hget(hash, 'rules')
	if not rules then
		return ("قوانینی موجود نمی باشد.")
	else
		return rules
	end
end

local function sort_funct(a, b)
	return a:gsub('#', '') < b:gsub('#', '')
end

function utilities.sendStartMe(msg)
	local keyboard = {inline_keyboard = {{{text = ("پیام دهید..."), url = 'https://telegram.me/'..bot.username}}}}
	api.sendMessage(msg.chat.id, ("لطفا اول به من پیام دهید :)"), true, keyboard)
end

function utilities.table2keyboard(t)
	local keyboard = {inline_keyboard = {}}
	for i, line in pairs(t) do
		if type(line) ~= 'table' then return false, 'Wrong structure (each line need to be a table, not a single value)' end
		local new_line ={}
		for k,v in pairs(line) do
			if type(k) ~= 'string' then return false, 'Wrong structure (table of arrays)' end
			local button = {}
			button.text = k
			button.callback_data = v
			table.insert(new_line, button)
		end
		table.insert(keyboard.inline_keyboard, new_line)
	end

	return keyboard
end

return utilities
