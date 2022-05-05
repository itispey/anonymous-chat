local api = require 'methods'
local redis = require 'redis'
local u, config, plugins, last_update, last_cron
config = require 'config' -- Load configuration file.
clr = require 'term.colors'
db = redis.connect(config.redis.host, config.redis.port)

function bot_init(on_reload) -- The function run when the bot is started or reloaded.
	if on_reload then
		package.loaded.config = nil
		package.loaded.languages = nil
		package.loaded.utilities = nil
	end

	db:select(config.redis.db or 0) --select the redis db

	u = require 'utilities' -- Load miscellaneous and cross-plugin functions.
	now_ms = require('socket').gettime

	bot = api.getMe().result -- Get bot info
	--bot.revision = u.bash('git rev-parse --short HEAD')

	plugins = {} -- Load plugins.
	for i, v in ipairs(config.plugins) do
		local p = require('plugins.'..v)
		package.loaded['plugins.'..v] = nil
		if p.triggers then
			for funct, trgs in pairs(p.triggers) do
				for i = 1, #trgs do
					-- interpret any whitespace character in commands just as space
					trgs[i] = trgs[i]:gsub(' ', '%%s+')
				end
				if not p[funct] then
					p.trgs[funct] = nil
					print(clr.red..funct..' triggers ignored in '..v..': '..funct..' function not defined'..clr.reset)
				end
			end
		end
		table.insert(plugins, p)
	end

	print('\n'..clr.blue..'BOT RUNNING:'..clr.reset, clr.red..'[@'..bot.username .. '] [' .. bot.first_name ..'] ['..bot.id..']'..clr.reset..'\n')

	last_update = last_update or -2 --skip pending updates
	last_cron = last_cron or os.time() -- the time of the last cron job

	if on_reload then
		return #plugins
	else
		api.sendAdmin('*Bot started!*\n_'..os.date('On %A, %d %B %Y\nAt %X')..'_\n'..#plugins..' plugins loaded', true)
		start_timestamp = os.time()
		current = {h = 0}
		last = {h = 0}
	end
end

local function extract_usernames(msg)
	if msg.from then
		if msg.from.username then
			db:hset('bot:usernames', '@'..msg.from.username:lower(), msg.from.id)
		end
	end
	if msg.forward_from and msg.forward_from.username then
		db:hset('bot:usernames', '@'..msg.forward_from.username:lower(), msg.forward_from.id)
	end
	if msg.new_chat_member then
		if msg.new_chat_member.username then
			db:hset('bot:usernames', '@'..msg.new_chat_member.username:lower(), msg.new_chat_member.id)
		end
		db:sadd(string.format('chat:%d:members', msg.chat.id), msg.new_chat_member.id)
	end
	if msg.left_chat_member then
		if msg.left_chat_member.username then
			db:hset('bot:usernames', '@'..msg.left_chat_member.username:lower(), msg.left_chat_member.id)
		end
		db:srem(string.format('chat:%d:members', msg.chat.id), msg.left_chat_member.id)
	end
	if msg.reply_to_message then
		extract_usernames(msg.reply_to_message)
	end
	if msg.pinned_message then
		extract_usernames(msg.pinned_message)
	end
end

local function collect_stats(msg)

	extract_usernames(msg)

	if msg.chat.type ~= 'private' and msg.chat.type ~= 'inline' and msg.from then
		db:hset('chat:'..msg.chat.id..':userlast', msg.from.id, os.time()) --last message for each user
		db:hset('bot:chats:latsmsg', msg.chat.id, os.time()) --last message in the group
	end
end

local function match_triggers(triggers, text)
	if text and triggers then
		text = text:gsub('^(/[%w_]+)@'..bot.username, '%1')
		for i, trigger in pairs(triggers) do
			local matches = {}
			matches = { string.match(text, trigger) }
			if next(matches) then
				return matches, trigger
			end
		end
	end
end

local function on_msg_receive(msg, callback) -- The fn run whenever a message is received.
	--u.dump('PARSED', msg)
	if not msg then
		return
	end

	if msg.chat.type ~= 'group' then --do not process messages from normal groups

		if msg.date < os.time() - 60 then
			print('          >>> Old update skipped <<<          ')
			return false
		end -- Do not process old messages.
		-- os.time(os.date("!*t")) is used so that the timestamp is returned from UTC, not the current timezone.
		-- the ! indicates UTC - https://www.lua.org/manual/5.2/manual.html#pdf-os.date
		if not msg.text then msg.text = msg.caption or '' end

		collect_stats(msg)

		local continue = true
		local onm_success
		for i=1, #plugins do
			if plugins[i].onEveryMessage then
				onm_success, continue = pcall(plugins[i].onEveryMessage, msg)
				if not onm_success then
					api.sendAdmin('یک #باگ جدید 😑 (پیش پردازش).\n'..tostring(continue)..msg.text)
				end
			end
			if not continue then return end
		end

		for i, plugin in pairs(plugins) do
			if plugin.triggers then
				local blocks, trigger = match_triggers(plugin.triggers[callback], msg.text)
				if blocks then

					if config.bot_settings.stream_commands then --print some info in the terminal
						print(clr.green..'['..os.date('%X')..']'..clr.magenta..' '..trigger..clr.yellow..' '..msg.from.first_name..clr.cyan..' ['..msg.from.id..'] -> ['..msg.chat.id..']'..clr.reset)
					end

					--if not check_callback(msg, callback) then goto searchaction end
					local success, result = xpcall(plugin[callback], debug.traceback, msg, blocks) --execute the main function of the plugin triggered

					if not success then --if a bug happens
						print(result)
						if config.bot_settings.notify_bug then
							api.sendReply(msg, ("داری اشتباه میزنی :|\nاگه مشکلی هست، به @GoodAdministrator_Bot پیام بده."), 'html')
						end
						api.sendAdmin('یک #باگ جدید 😑\n'..result..'\n'..msg.text)
						return
					end

					if not result then --if the action returns true, then don't stop the loop of the plugin's actions
						return
					end
				end

			end
		end
	else
		if msg.group_chat_created or (msg.new_chat_member and msg.new_chat_member.id == bot.id) then

			-- send disclamer
			api.sendMessage(msg.chat.id, ([[
سلام! من ربات لجندری هستم :)
برای استفاده از من، باید گروه خودتون رو به سوپرگروه آپدیت کنید.
]]):format(bot.first_name))

			api.leaveChat(msg.chat.id)

			-- log this event
			if config.bot_settings.stream_commands then
				print(string.format('%s[%s]%s Bot was added to a normal group %s%s [%d] -> [%d]',
					  clr.blue, os.date('%X'), clr.yellow, clr.reset, msg.from.first_name, msg.from.id, msg.chat.id))
			end
		end
	end
end

local function parseMessageFunction(update)

	db:hincrby('bot:general', 'messages', 1)

	local msg, function_key

	if update.message or update.edited_message then

		function_key = 'onTextMessage'

		if update.edited_message then
			update.edited_message.edited = true
			update.edited_message.original_date = update.edited_message.date
			update.edited_message.date = update.edited_message.edit_date
			function_key = 'onEditedMessage'
		end

		msg = update.message or update.edited_message

		if msg.text then
		elseif msg.photo then
			msg.media = true
			msg.media_type = 'photo'
		elseif msg.audio then
			msg.media = true
			msg.media_type = 'audio'
		elseif msg.document then
			msg.media = true
			msg.media_type = 'document'
			if msg.document.mime_type == 'video/mp4' then
				msg.media_type = 'gif'
			end
		elseif msg.sticker then
			msg.media = true
			msg.media_type = 'sticker'
		elseif msg.video then
			msg.media = true
			msg.media_type = 'video'
		elseif msg.video_note then
			msg.media = true
			msg.media_type = 'video_note'
		elseif msg.voice then
			msg.media = true
			msg.media_type = 'voice'
		elseif msg.contact then
			msg.media = true
			msg.media_type = 'contact'
		elseif msg.venue then
			msg.media = true
			msg.media_type = 'venue'
		elseif msg.location then
			msg.media = true
			msg.media_type = 'location'
		elseif msg.game then
			msg.media = true
			msg.media_type = 'game'
		elseif msg.left_chat_member then
			msg.service = true
			if msg.left_chat_member.id == bot.id then
				msg.text = '###left_chat_member:bot'
			else
				msg.text = '###left_chat_member'
			end
		elseif msg.new_chat_member then
			msg.service = true
			if msg.new_chat_member.id == bot.id then
				msg.text = '###new_chat_member:bot'
			else
				msg.text = '###new_chat_member'
			end
		elseif msg.new_chat_photo then
			msg.service = true
			msg.text = '###new_chat_photo'
		elseif msg.delete_chat_photo then
			msg.service = true
			msg.text = '###delete_chat_photo'
		elseif msg.group_chat_created then
			msg.service = true
			msg.text = '###group_chat_created'
		elseif msg.supergroup_chat_created then
			msg.service = true
			msg.text = '###supergroup_chat_created'
		elseif msg.channel_chat_created then
			msg.service = true
			msg.text = '###channel_chat_created'
		elseif msg.migrate_to_chat_id then
			msg.service = true
			msg.text = '###migrate_to_chat_id'
		elseif msg.migrate_from_chat_id then
			msg.service = true
			msg.text = '###migrate_from_chat_id'
		elseif msg.new_chat_title then
			msg.service = true
			msg.text = '###new_chat_title'
		elseif msg.pinned_message then
			msg.service = true
			msg.text = '###pinned_message'
		else
			--callback = 'onUnknownType'
			print('Unknown update type') return
		end

		if msg.forward_from_chat then
			if msg.forward_from_chat.type == 'channel' then
				msg.spam = 'forwards'
			end
		end
		if msg.caption then
			local caption_lower = msg.caption:lower()
			if caption_lower:match('telegram%.me') or caption_lower:match('telegram%.dog') or caption_lower:match('t%.me') then
				msg.spam = 'links'
			end
		end
		if msg.entities then
			for i, entity in pairs(msg.entities) do
				if entity.type == 'text_mention' then
					msg.mention_id = entity.user.id
				end
				if entity.type == 'url' or entity.type == 'text_link' then
					local text_lower = msg.text or msg.caption
					text_lower = entity.url and text_lower..entity.url or text_lower
					text_lower = text_lower:lower()
					if text_lower:match('telegram%.me') or
						text_lower:match('telegram%.dog') or
						text_lower:match('t%.me') then
						msg.spam = 'links'
					else
						msg.media_type = 'link'
						msg.media = true
					end
				end
			end
		end
		if msg.reply_to_message then
			msg.reply = msg.reply_to_message
			if msg.reply.caption then
				msg.reply.text = msg.reply.caption
			end
		end
	elseif update.callback_query then
		msg = update.callback_query
		msg.cb = true
		msg.text = '###cb:'..msg.data
		if msg.message then
			msg.original_text = msg.message.text
			msg.original_date = msg.message.date
			msg.message_id = msg.message.message_id
			msg.chat = msg.message.chat
		else --when the inline keyboard is sent via the inline mode
			msg.chat = {type = 'inline', id = msg.from.id, title = msg.from.first_name}
			msg.message_id = msg.inline_message_id
		end
		msg.date = os.time()
		msg.cb_id = msg.id
		msg.message = nil
		msg.target_id = msg.data:match('(-%d+)$') --callback datas often ship IDs
		function_key = 'onCallbackQuery'
	else
		--function_key = 'onUnknownType'
		print('Unknown update type') return
	end

	--print('Mod:', msg.from.mod, 'Admin:', msg.from.admin)
	return on_msg_receive(msg, function_key)
end

bot_init() -- Actually start the script. Run the bot_init function.

api.firstUpdate()
while true do -- Start a loop while the bot should be running.
	local res = api.getUpdates(last_update+1) -- Get the latest updates
	if res then
		clocktime_last_update = os.clock()
		for i=1, #res.result do -- Go through every new message.
			last_update = res.result[i].update_id
			--print(last_update)
			--u.dump(res.result[i])
			current.h = current.h + 1
			parseMessageFunction(res.result[i])
		end
	else
		print('Connection error')
	end
	if last_cron ~= os.date('%H') then -- Run cron jobs every hour.
		last_cron = os.date('%H')
		last.h = current.h
		current.h = 0
		print(clr.yellow..'Cron started...'..clr.reset)
		for i=1, #plugins do
			if plugins[i].cron then -- Call each plugin's cron function, if it has one.
				local res, err = pcall(plugins[i].cron)
				if not res then
					api.sendLog('An #error occurred (cron).\n'..err)
					return
				end
			end
		end
	end
end
