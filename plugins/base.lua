local config = require 'config'
local u = require 'utilities'
local api = require 'methods'
local JSON = require 'dkjson'

local plugin = {}

local function checkChannel(user_id)
	local res = api.getChatMember(config.channel_id, user_id)
	if not res or (res.result.status == 'left' or res.result.status == 'kicked') then
		return true, 'کاربر گرامی؛\n\nبرای استفاده از خدمات ربات چت ناشناس شما باید عضو کانال [دهکده ایرانی](https://t.me/tehronia) شوید.\n'
		..'لطفا بعد از اینکه عضو شدید، مجدد دستور /start را بزنید.'
	end
end

local function firstKeyboard()
	local keyboard = {inline_keyboard={
		{{text = 'شروع چت کردن 🙋🏻‍♂️🙋🏻', callback_data = 'bot:start_chat'}},
		{{text = 'لینک پیام ناشناس 🎃', callback_data = 'bot:get_unknown_link'}, {text = 'پشتیبانی 👩🏻‍💻', callback_data = 'bot:support'}},
		{{text = 'اعتبار من 💰', callback_data = 'bot:myaccount'}, {text = 'مشخصات من 👒', callback_data = 'bot:info_of_me'}},
		{{text = 'دعوت دوستان 👬', callback_data = 'bot:invite_friends'}},
		{{text = 'افزایش اعتبار 💖', callback_data = 'bot:balance'}, {text = 'نکات مهم ⁉️', callback_data = 'bot:rules'}}
	}}
	return keyboard
end

local function chatKeyboard()
	local keyboard = {inline_keyboard={
		{{text = 'چت تصادفی ☂️', callback_data = 'bot:random_chat'}},
		{{text = 'چت با هم جنس 👩‍❤️‍👩', callback_data = 'bot:same_chat'}, {text = 'چت با جنس مخالف 💑', callback_data = 'bot:opposite_chat'}},
		{{text = 'چت با هم شهری 🔥', callback_data = 'bot:city_chat'}, {text = 'چت با هم سن 🚶🏻', callback_data = 'bot:age_chat'}},
		{{text = 'برگشت 🔙', callback_data = 'bot:back_to_menu'}}
	}}
	return keyboard
end

local function modKeyboard()
	local keyboard = {inline_keyboard={
		{{text = 'آمار', callback_data = 'bot:stats'}},
		{{text = 'ارسال لینک دعوت', callback_data = 'bot:sendinvite'}},
		{{text = 'ارسال لینک پیام ناشناس', callback_data = 'bot:sendulink'}}
	}}
	return keyboard
end

local function back_for_admins()
	local keyboard = {inline_keyboard={
		{{text = 'برگشت', callback_data = 'bot:back_to_mod'}}
	}}
	return keyboard
end

local function backKeyboard()
	local keyboard = {inline_keyboard={
		{{text = 'برگشت 🔙', callback_data = 'bot:back_to_menu'}}
	}}
	return keyboard
end

local function inChat()
	local keyboard = {keyboard = {
		{{text = 'اطلاعات کاربر ℹ️'}},
		{{text = 'لغو چت 🚫'}}
	}}
	keyboard.resize_keyboard = true
	return keyboard
end

local function is_vip(user_id)
	local vip_users = db:sismember('buy:vip_account', user_id)
	if vip_users then
		return true
	end
	if u.is_superadmin(user_id) then
		return true
	end
end

local function is_block(user_id)
	if db:sismember('blocked_users', user_id) then
		return true
	end
end

local function delete_waiting_users(user_id)
	db:srem('random_chat:waiting_users', user_id)
	db:srem('opposite_chat:waiting_users', user_id)
	db:srem('same_chat:waiting_users', user_id)
	db:srem('city_chat:waiting_users', user_id)
	db:srem('age_chat:waiting_users', user_id)
	db:del('support:user:'..user_id)
	db:del('user:send_unknown_message:'..user_id)
	db:del('user:reply_unknown_message:'..user_id)
end

local function delete_for_admin()
	db:del('random_chat:waiting_users')
	db:del('opposite_chat:waiting_users')
	db:del('same_chat:waiting_users')
	db:del('city_chat:waiting_users')
	db:del('age_chat:waiting_users')
end

function plugin.cron()
	local users = db:smembers('buy:vip_account')
	for i = 1, #users do
		if not db:get('bot:charge_user:'..users[i]) then
			db:srem('buy:vip_account', users[i])
			print("Done")
		end
	end
	if tonumber(os.date('%H')) == 0 then
		if not db:get('backup_sent') then
			local admins = config.superadmins
			for i = 1, #admins do
				api.sendDocument(admins[i], '/var/lib/redis/dump.rdb')
			end
			db:setex('backup_sent', 3650, true)
		end
	end
end

function plugin.onTextMessage(msg, blocks)
	local user_id = msg.from.id

	if blocks[1] == 'start' then
		if blocks[2] == 'invite_user' then
			local that_id = blocks[3]
			if user_id ~= tonumber(that_id) then
				if not db:sismember('user:invited_by:'..that_id, user_id) then
					db:sadd('user:invited_by:'..that_id, user_id)
				end
			end
		elseif blocks[2] == 'unknownchat' then
			local that_id = blocks[3]
			if user_id ~= tonumber(that_id) then
				local res = api.getChat(that_id)
				if not res then
					local h_name = db:hget('info:'..that_id, 'name')
					api.sendReply(msg, ('🔸 متاسفم! اما من نمیتونم به %s پیامی ارسال کنم. احتمالا اون ربات رو بلاک کرده یا دلیت اکانت کرده!'):format(h_name))
				else
					local name = u.getname_final(res.result)
					if not is_vip(user_id) then
						if db:sismember('user:unknownchat_limit:'..user_id, that_id) then
							api.sendReply(msg, '🔻 شما از حساب رایگان استفاده می کنید و فقط می توانید یک بار به این کاربر پیام بدید.\n'
							..'لطفا حساب خود را ارتقا دهید.')
							return
						end
					end
					if db:sismember('user:block_unknownchat:'..that_id, user_id) then
						api.sendReply(msg, 'متاسفم!\nمخاطب مورد نظر شما را بلاک کرده است و شما نمی توانید پیامی برای آن ارسال کنید.')
						return
					end
					if db:get('user:save_unknown_message:'..user_id..':'..that_id) then
						local keyboard = {inline_keyboard = {
							{{text = 'ادامه میدم ✅', callback_data = 'bot:send_agian:'..that_id}, {text = 'لغو کن 🚫', callback_data = 'bot:cancel_again:'..that_id}}
						}}
						api.sendReply(msg, 'پیام قبلی شما هنوز توسط مخاطب شما خوانده نشده است! اگر پیام جدیدی ارسال کنید، پیام جدید جایگزین قبلی می شود.\n'
						..'آیا ادامه می دهید؟', true, keyboard)
						return
					end
					api.sendReply(msg, ('🔸 لطفا پیامی که می خواهید به صورت ناشناس برای %s بفرستید را ارسال کنید.'):format(name), 'html')
					db:setex('user:send_unknown_message:'..user_id, (86400 * 10), that_id)
					return
				end
			end
		end
		if db:get('found_new_user:'..user_id) then
			api.sendReply(msg, '🔻 شما هم اکنون در حال چت می باشید!\nلطفا توسط دکمه "لغو چت" یا دستور /endchat به چت خود خاتمه دهید.')
			return
		end
		delete_waiting_users(user_id)
		local text, keyboard
		db:sadd('bot:users', user_id)
		local check, text = checkChannel(user_id)
		if check then
			api.sendReply(msg, text, true)
			return
		end
		local register = db:sismember('users:register', user_id)
		if not register then
			text = '🔹 به ربات چت ناشناس خوش آمدید! پیش از هرکاری، اقدام به ثبت نام در ربات کنید.\nلطفا نام خود را ارسال کنید.'
			db:setex('user:getname:'..user_id, 3600, true)
		else
			text = '🔷 به ربات چت ناشناس خوش آمدید.\nاز فهرست زیر، گزینه دلخواه خودتان را انتخاب کنید.'
			keyboard = firstKeyboard()
		end
		api.sendReply(msg, text, true, keyboard)
	end

	if blocks[1] == 'dump' then
		u.dump(msg.reply)
	end

	if blocks[1] == 'change' then
		local city = blocks[2]
		db:hset('info:'..user_id, 'city', city)
		api.sendReply(msg, 'done')
	end
	---------------------------------- [Cancel Chat] ----------------------------
	if blocks[1]:match('(لغو چت 🚫)') or blocks[1] == 'endchat' then
		local him = db:get('found_new_user:'..user_id)
		local text, keyboard
		if him then
			text = ('⁉️ آیا مطمئن هستید که می خواهید چت را متوقف کنید؟!')
			keyboard = {inline_keyboard = {
				{{text = 'بله ✅', callback_data = 'bot:end_chat:'..him}, {text = 'ادامه گفتگو 💞', callback_data = 'bot:resume_chat'}}
			}}
			api.sendMessage(user_id, text, true, keyboard)
		else
			keyboard = {remove_keyboard = true}
			api.sendReply(msg, '🚫 جستجو متوقف شد!', true, keyboard)
			api.sendMessage(user_id, '👨🏻‍💻 دوست دارید با چه کسی چت کنید؟ از دکمه های زیر، یکی را به دلخواه انتخاب کنید.', true, chatKeyboard())
			delete_waiting_users(user_id)
		end
	end

	if blocks[1]:match('(اطلاعات کاربر ℹ️)') then
		if not is_vip(user_id) then
			api.sendReply(msg, '🔻 مشاهده اطلاعات مخاطب تنها برای کاربران ویژه امکان پذیر می باشد!\n'
			..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
			return
		end
		local that_id = db:get('found_new_user:'..user_id)
		if that_id then
			local hash = 'info:'..that_id
			local name = db:hget(hash, 'name')
			local age = db:hget(hash, 'age')
			local city = db:hget(hash, 'city')
			local sex = db:hget(hash, 'sex')
			local text = ([[
ℹ️ اطلاعات کاربر:

• نام: %s
• سن: %s
• محل زندگی: %s
• جنسیت: %s

%s
			]]):format(('<a href="tg://user?id=%s">%s</a>'):format(that_id, name), age, city, sex, '@'..bot.username)
			api.sendReply(msg, text, 'html')
		end
	end

	--------------------------------- [Auto Paymen] ------------------------------------

	if u.is_superadmin(user_id) or (user_id == config.fwd) then
		if blocks[1] == '0' then
		end

		if blocks[1] == '1' then
			local order_number = blocks[4]
			local order_user_id = blocks[5]
			local plan = blocks[6]
			local bot_id = blocks[7]
			local days
			if tonumber(bot_id) == bot.id then
				if plan == '1' then
					plan = 'سرویس 1 ماهه'
					days = 30
				else
					plan = 'سرویس 3 ماهه'
					days = 90
				end
				db:sadd('buy:vip_account', order_user_id)
				db:setex('bot:charge_user:'..order_user_id, (86400 * days), true)
				local user_text = ('✅ %s شما با موفقیت فعال شد!\nهم اکنون می توانید از قابلیت های ویژه ربات استفاده کنید.'):format(plan)
				api.sendMessage(order_user_id, user_text)
				local admin_text = ('🎄 کاربر %s یک تراکنش (%s) انجام داد!'):format(u.getname_final(api.getChat(order_user_id).result), plan)
				local admins = config.superadmins
				for i = 1, #admins do
					api.sendMessage(admins[i], admin_text, 'html')
				end
			end
		end

	end

	--------------------------------- [Just For Admin] ---------------------------------

	if u.is_superadmin(user_id) then
		if blocks[1] == 'startmod' then
			api.sendReply(msg, 'به بخش مدیریت خوش آمدید...', true, modKeyboard())
		end

		if blocks[1] == 'setvip' then
			local days = tonumber(blocks[2])
			local user_id = blocks[3]
			local res = api.getChat(user_id)
			local text
			if res then
				db:sadd('buy:vip_account', user_id)
				db:setex('bot:charge_user:'..user_id, (86400 * days), true)
				local name = u.getname_final(res.result)
				text = ('حساب کاربر %s به مدت <b>%s</b> روز شارژ شد.'):format(name, days)
			else
				text = 'کاربر مورد نظر یافت نشد!'
			end
			api.sendReply(msg, text, 'html')
		end

		if blocks[1] == 'block' then
			local user_id = blocks[2]
			local res = api.getChat(user_id)
			local text
			if res then
				db:sadd('blocked_users', user_id)
				text = ('کاربر %s بلاک شد.'):format(u.getname_final(res.result))
			else
				text = 'کاربر مورد نظر یافت نشد!'
			end
			api.sendReply(msg, text, 'html')
		end

		if blocks[1] == 'unblock' then
			local user_id = blocks[2]
			local res = api.getChat(user_id)
			local text
			if res then
				db:srem('blocked_users', user_id)
				text = ('کاربر %s آن بلاک شد.'):format(u.getname_final(res.result))
			else
				text = 'کاربر مورد نظر یافت نشد!'
			end
			api.sendReply(msg, text, 'html')
		end

		if blocks[1] == 'delete' then
			delete_for_admin()
			api.sendReply(msg, 'Done')
		end

	end

	--------------------------------- [END] ---------------------------------

end

function plugin.onCallbackQuery(msg, blocks)
	local user_id = msg.from.id

	if u.is_superadmin(user_id) then
		if blocks[1] == 'stats' then
			local stats = {
				users = db:scard('bot:users') or 0,
				boys = db:scard('bot:boys') or 0,
				girls = db:scard('bot:girls') or 0,
				vip = db:scard('buy:vip_account') or 0,
				texts = db:get('total:texts') or 0,
				photos = db:get('total:photos') or 0,
				videos = db:get('total:videos') or 0,
				video_notes = db:get('total:video_notes') or 0,
				stickers = db:get('total:stickers') or 0,
				documents = db:get('total:documents') or 0,
				audios = db:get('total:audios') or 0,
				voices = db:get('total:voices') or 0,
				locations = db:get('total:locations') or 0
			}
			local text = ([[
💖 آمار کلی ربات:

• نسخه ربات: <code>1.1.4</code>

💜 اعضای ربات: <b>%s</b> عضو

💁🏻‍♂️ تعداد اعضای پسر: <b>%s</b>
👩🏻‍🎤 تعداد اعضای دختر: <b>%s</b>
🏖 تعداد اعضای ویژه: <b>%s</b>

🔻 تعداد پیام های ارسال شده:
• متن: <b>%s</b>
• عکس: <b>%s</b>
• فیلم: <b>%s</b>
• فیلم سلفی: <b>%s</b>
• استیکر: <b>%s</b>
• فایل/گیف: <b>%s</b>
• موسیقی: <b>%s</b>
• صدا: <b>%s</b>
• موقعیت مکانی: <b>%s</b>

%s
			]]):format(stats.users, stats.boys, stats.girls, stats.vip, stats.texts, stats.photos, stats.videos, stats.video_notes, stats.stickers,
			stats.documents, stats.audios, stats.voices, stats.locations, '@'..bot.username)
			api.editMessageText(user_id, msg.message_id, text, 'html', back_for_admins())
		end

		if blocks[1] == 'sendulink' then
			local users = db:smembers('bot:users')
			local n = 0
			api.sendMessage(user_id, 'در حال انجام...\nلطفا صبر کنید...')
			for i = 1, #users do
				local name = db:hget('info:'..users[i], 'name')
				local text = ([[
🔻 سلام! من ( %s ) هستم 😃

اگه هرچی توی دلت مونده که میخوای بهم بگی و تا حالا روت نشده بگی، روی لینک زیر بزن و حرفتو ناشناس بهم بزن...
اسمت واسه من نمیاد و من نمیفهمم کی هستی 🙈

حتی خودتم میتونی تستش کنی و حرفای باحال از دوستات بشنوی...

اگه چیزی میخوای بهم بگی، الان وقتشه:
https://t.me/%s?start=unknownchat_%s
				]]):format(name, bot.username, users[i])
				local res = api.sendMessage(users[i], text)
				if not res then
					db:srem('bot:users', users[i])
				else
					api.sendMessage(users[i], '🔹 فقط کافیه این پیام رو واسه دوستات فوروارد کنی تا حرفتو به صورت ناشناس ازشون بشنوی.')
					n = n + 1
				end
			end
			api.sendMessage(user_id, 'پیام شما به '..n..' کاربر ارسال شد.')
		end

		if blocks[1] == 'sendinvite' then
			local users = db:smembers('bot:users')
			local n = 0
			api.sendMessage(user_id, 'در حال انجام...\nلطفا صبر کنید...')
			for i = 1, #users do
				local name = db:hget('info:'..users[i], 'name')
				local etebar = (db:scard('user:invited_by:'..users[i]) * 500) or 0
				local text = ([[
شما می توانید توسط لینک زیر دوستان خود را به ربات اضافه کنید و حساب #ویژه دریافت کنید !

با اضافه کردن هر عضو جدید 500 تومن به اعتبار شما اضافه خواهد شد (اطلاعات بیشتر در بخش افزایش اعتبار)

💎 اعتبار من: <b>%s</b> تومان

🔻 لینک مخصوص شما:
https://t.me/%s?start=invite_user_%s
				]]):format(etebar, bot.username, users[i])
				local res = api.sendMessage(users[i], text, 'html')
				if not res then
					db:srem('bot:users', users[i])
				else
					n = n + 1
				end
			end
			api.sendMessage(user_id, 'پیام شما به '..n..' کاربر ارسال شد.')
		end

		if blocks[1] == 'back_to_mod' then
			api.editMessageText(user_id, msg.message_id, 'به بخش مدیریت خوش آمدید.', true, modKeyboard())
		end

	end

	if blocks[1] == 'back_to_menu' then
		delete_waiting_users(user_id)
		api.editMessageText(user_id, msg.message_id, '🔷 به ربات چت ناشناس خوش آمدید.\nاز فهرست زیر، گزینه دلخواه خودتان را انتخاب کنید.', true, firstKeyboard())
	end
	if blocks[1] == 'start_chat' then
		local check, text = checkChannel(user_id)
		if check then
			api.sendMessage(user_id, text, true)
			return
		end
		api.editMessageText(user_id, msg.message_id, '👨🏻‍💻 دوست دارید با چه کسی چت کنید؟ از دکمه های زیر، یکی را به دلخواه انتخاب کنید.', true, chatKeyboard())
	end
	----------------------------------------------- [Unknown PM] -------------------------------------------
	----------------------- [Get Link] ------------------------
	if blocks[1] == 'get_unknown_link' then
		local name = db:hget('info:'..user_id, 'name')
		local text = ([[
🔻 سلام! من ( %s ) هستم 😃

اگه هرچی توی دلت مونده که میخوای بهم بگی و تا حالا روت نشده بگی، روی لینک زیر بزن و حرفتو ناشناس بهم بزن...
اسمت واسه من نمیاد و من نمیفهمم کی هستی 🙈

حتی خودتم میتونی تستش کنی و حرفای باحال از دوستات بشنوی...

اگه چیزی میخوای بهم بگی، الان وقتشه:
https://t.me/%s?start=unknownchat_%s
		]]):format(name, bot.username, user_id)
		api.editMessageText(user_id, msg.message_id, text)
		api.sendMessage(user_id, '🔹 فقط کافیه این پیام رو واسه دوستات فوروارد کنی تا حرفتو به صورت ناشناس ازشون بشنوی.', true, backKeyboard())
	end
	---------------------- [Send Message] ----------------------
	if blocks[1] == 'send_unknown_message' then
		local check, text = checkChannel(user_id)
		if check then
			api.sendMessage(user_id, text, true)
			return
		end
		local that_id = blocks[2]
		local message = db:get('user:save_unknown_message:'..user_id..':'..that_id)
		if message then
			local keyboard = {inline_keyboard = {
				{{text = 'مشاهده پیام 👀', callback_data = 'bot:see_unknown_message:'..user_id}}
			}}
			api.sendMessage(that_id, '🔸 شما یک پیام ناشناس جدید دارید!', nil, keyboard)
			api.answerCallbackQuery(msg.cb_id, '✅ پیام شما با موفقیت ارسال شد...')
			api.editMessageText(user_id, msg.message_id, '✅ پیام شما ارسال شد.\nبرای بارگزاری مجدد ربات، دستور /start را بزنید.')
			if not is_vip(user_id) then
				db:sadd('user:unknownchat_limit:'..user_id, that_id)
			end
		else
			api.answerCallbackQuery(msg.cb_id, '🚫 پیامی برای ارسال پیدا نشد! لطفا پیام خود را مجدد بنویسید.')
		end
	end
	---------------------- [Cancel Message] ----------------------
	if blocks[1] == 'cancel_send' then
		local that_id = blocks[2]
		db:del('user:save_unknown_message:'..user_id..':'..that_id)
		db:setex('user:send_unknown_message:'..user_id, (86400 * 10), that_id)
		api.editMessageText(user_id, msg.message_id, '🔻 لطفا دوباره پیام خود را ارسال کنید.')
		api.answerCallbackQuery(msg.cb_id, 'لغو شد...')
	end
	---------------------- [Send Agian] -------------------------
	if blocks[1] == 'send_agian' then
		local that_id = blocks[2]
		api.editMessageText(user_id, msg.message_id, '🔸 لطفا پیامی که می خواهید به صورت ناشناس بفرستید را ارسال کنید.')
		db:setex('user:send_unknown_message:'..user_id, (86400 * 10), that_id)
	end
	---------------------- [Cancel Agian] -----------------------
	if blocks[1] == 'cancel_again' then
		api.editMessageText(user_id, msg.message_id, '🚫 لغو شد!\nلطفا برای بارگزاری مجدد ربات، دستور /start را ارسال کنید.')
	end
	---------------------- [See Message] ------------------------
	if blocks[1] == 'see_unknown_message' then
		local check, text = checkChannel(user_id)
		if check then
			api.sendMessage(user_id, text, true)
			return
		end
		local that_id = blocks[2]
		local message = db:get('user:save_unknown_message:'..that_id..':'..user_id)
		local text, keyboard
		if message then
			text = '💖 پیام مخاطب شما:\n\n'..message
			keyboard = {inline_keyboard = {
				{{text = 'پاسخ 👤', callback_data = 'bot:reply_to:'..that_id}},
				{{text = 'بلاک 🚫', callback_data = 'bot:block_unknownchat:'..that_id}}
			}}
			db:del('user:save_unknown_message:'..that_id..':'..user_id)
		else
			text = '⁉️ این پیام توسط ارسال کننده آن حذف شده است.'
		end
		api.editMessageText(user_id, msg.message_id, text, nil, keyboard)
	end
	--------------------- [Reply to Message] -----------------------
	if blocks[1] == 'reply_to' then
		local that_id = blocks[2]
		local keyboard = {inline_keyboard = {{{text = 'بلاک 🚫', callback_data = 'bot:block_unknownchat:'..that_id}}}}
		db:setex('user:reply_unknown_message:'..user_id, (86400 * 10), that_id)
		api.editMessageReplyMarkup(user_id, msg.message_id, keyboard)
		api.sendMessage(user_id, 'لطفا پاسخ خود را ارسال کنید.\n'
		..'در صورتی که می خواهید آن را لغو کنید، دستور /start را ارسال کنید.')
	end
	--------------------- [Block him] -----------------------
	if blocks[1] == 'block_unknownchat' then
		local that_id = blocks[2]
		if not db:get('try_agian:'..user_id) then
			api.answerCallbackQuery(msg.cb_id, '🚫 آیا از انجام این کار مطمئن هستید؟ در صورتی که مطمئن هستید دوباره روی این دکمه بزنید.', true)
			db:setex('try_agian:'..user_id, 3600, true)
			return
		end
		db:sadd('user:block_unknownchat:'..user_id, that_id)
		api.answerCallbackQuery(msg.cb_id, 'کاربر مورد نظر بلاک شد.', true)
		api.editMessageText(user_id, msg.message_id, msg.original_text)
	end
	-------------------------------- [Select Method] ----------------------------------
	if blocks[1] == 'online_order' then
		api.answerCallbackQuery(msg.cb_id, 'سرویس مورد نظرتان را انتخاب کنید...')
		local text = ([[
🔸 مایل هستید کدام سرویس را خریداری کنید؟

1- سرویس 1 ماهه (*4,000* تومان)
2- سرویس 3 ماهه (*10,000* تومان)
		]])
		local keyboard = {inline_keyboard = {
			{{text = 'سرویس دوم 💵', callback_data = 'bot:serviceTwo'},
			{text = 'سرویس اول 💵', callback_data = 'bot:serviceOne'}},
			{{text = 'برگشت 🔙', callback_data = 'bot:balance'}}
		}}
		api.editMessageText(user_id, msg.message_id, text, true, keyboard)
	end
	-------------------------------- [Order] -------------------------------------
	if blocks[1] == 'serviceOne' or blocks[1] == 'serviceTwo' then
		local ser, keyboard
		api.editMessageText(user_id, msg.message_id, 'در حال ساخت لینک پرداخت...')
		if blocks[1] == 'serviceOne' then
			ser = 1
		else
			ser = 2
		end
		local res = api.performRequest(('http://pay.tehroniaco.com/req.php?id=%s&plan=%s&bot_id=%s'):format(user_id, ser, bot.id))
		local a = JSON.decode(res)
		if not a or not res then
			api.editMessageText(user_id, msg.message_id, 'مشکلی در ساخت لینک پرداخت به وجود آماده است! لطفا آن را به پشتیبانی اطلاع دهید.')
			return
		end
		if a.status == 'true' then
			keyboard = {inline_keyboard = {
				{{text = 'پرداخت 💵', url = a.link}},
				{{text = 'برگشت 🔙', callback_data = 'bot:online_order'}}
			}}
			text = 'برای پرداخت روی دکمه زیر بزنید.'
			api.editMessageText(user_id, msg.message_id, text, true, keyboard)
		end
	end
	-------------------------------- [Invite Friends] ----------------------------
	if blocks[1] == 'invite_friends' then
		local text = ([[
🔸 اضافه کردن دوستان:

شما می توانید توسط لینک زیر دوستان خود را به ربات اضافه کنید و حساب #ویژه دریافت کنید !

• نکته اول: توجه داشته باشید تنها کاربرانی را می توانید به ربات اضافه کنید که قبلا در ربات ثبت نشدند.
• نکته دوم: با اضافه کردن هر عضو جدید 500 تومن به اعتبار شما اضافه خواهد شد (اطلاعات بیشتر در بخش افزایش اعتبار)

🔻 لینک مخصوص شما:
https://t.me/%s?start=invite_user_%s
		]]):format(bot.username, user_id)
		api.answerCallbackQuery(msg.cb_id, '🔹 فقط کافیه لینک زیر را برای دوستان خود ارسال کنید تا از خدمات حساب ویژه برخوردار شوید.', true)
		api.editMessageText(user_id, msg.message_id, text, 'html', backKeyboard())
	end
	-------------------------------- [Support] -------------------------------
	if blocks[1] == 'support' then
		local text = ([[
👩🏻‍💻 لطفا پیام خود را برای پشتیبانی ارسال کنید.

در صورتی که کار شما با پشتیبانی تمام شد، توسط دستور "/start" چت با پشتیبان را به اتمام برسانید.

%s
		]]):format('@'..bot.username)
		api.editMessageText(user_id, msg.message_id, text, true)
		db:set('support:user:'..user_id, true)
	end
	-------------------------------- [Info] --------------------------------
	if blocks[1] == 'info_of_me' then
		local check, text = checkChannel(user_id)
		if check then
			api.sendMessage(user_id, text, true)
			return
		end
		local hash = 'info:'..user_id
		local name = db:hget(hash, 'name')
		local age = db:hget(hash, 'age')
		local city = db:hget(hash, 'city')
		local sex = db:hget(hash, 'sex')
		local text = ([[
👒 مشخصات من:

• نام: %s
• سن: %s
• محل زندگی: %s
• جنسیت: %s

%s
		]]):format(name, age, city, sex, '@'..bot.username)
		api.answerCallbackQuery(msg.cb_id, '👒 مشخصات من...')
		api.editMessageText(user_id, msg.message_id, text, 'html', backKeyboard())
	end
	-------------------------------- [Rules] --------------------------------
	if blocks[1] == 'rules' then
		local text = ([[
⁉️ نکات مهم درباره این ربات:

1- استفاده از این ربات به منظور تبلیغات، ممنوع می باشد.
2- فرستادن محتویات غیر اخلاقی، سیاسی و ... به شدت ممنوع می باشد و در صورت مشاهده، از استفاده از ربات محروم می شوید.

%s
		]]):format('@'..bot.username)
		api.answerCallbackQuery(msg.cb_id, '⁉️ نکات مهم درباره این ربات...')
		api.editMessageText(user_id, msg.message_id, text, 'html', backKeyboard())
	end
	-------------------------------- [Chat] --------------------------------
	------------------ [Random Chat] ------------------
	if blocks[1] == 'random_chat' then
		local check, text = checkChannel(user_id)
		if check then
			api.sendMessage(user_id, text, true)
			return
		end
		local text, keyboard
		api.answerCallbackQuery(msg.cb_id, 'در حال اتصال به یک کاربر ...')
		api.deleteMessage(user_id, msg.message_id)
		text = '‍🙋🏻‍♂️🙋🏻 در حال اتصال به یک کاربر...\nلطفا صبر کنید...'
		keyboard = inChat()
		api.sendMessage(user_id, text, true, keyboard)
		local hash = 'random_chat:waiting_users'
		local users = db:smembers(hash)
		db:sadd(hash, user_id)
		for i = 1, #users do
			if next(users) then
				if user_id ~= users[i] then
					if not db:sismember('user:blocked_users:'..user_id, users[i]) then
						if is_vip(user_id) then
							api.sendMessage(users[i], '🙋🏻‍♂️🙋🏻 کاربر ویژه مورد نظر پیدا شد! هم اکنون می توانید با آن چت کنید.')
						else
							api.sendMessage(users[i], '🙋🏻‍♂️🙋🏻 کاربر مورد نظر پیدا شد! هم اکنون می توانید با آن چت کنید.')
						end
						if is_vip(users[i]) then
							api.sendMessage(user_id, '🙋🏻‍♂️🙋🏻 کاربر ویژه مورد نظر پیدا شد! هم اکنون می توانید با آن چت کنید.')
						else
							api.sendMessage(user_id, '🙋🏻‍♂️🙋🏻 کاربر مورد نظر پیدا شد! هم اکنون می توانید با آن چت کنید.')
						end
						db:set('found_new_user:'..user_id, users[i])
						db:set('found_new_user:'..users[i], user_id)
						db:srem(hash, user_id)
						db:srem(hash, users[i])
						break
					end
				end
			end
		end
	end
	------------------ [Opposite Chat] ------------------
	if blocks[1] == 'opposite_chat' then
		if not is_vip(user_id) then
			api.answerCallbackQuery(msg.cb_id, '🔻 برای استفاده از این قابلیت، شما باید حساب ویژه داشته باشید.\n'
			..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
			return
		end
		local text, keyboard
		api.answerCallbackQuery(msg.cb_id, 'در حال اتصال به جنس مخالف...')
		api.deleteMessage(user_id, msg.message_id)
		text = '💑 در حال اتصال به جنس مخالف...\nلطفا صبر کنید...'
		keyboard = inChat()
		api.sendMessage(user_id, text, true, keyboard)
		local sexuality = db:hget('info:'..user_id, 'sex')
		local hash = 'opposite_chat:waiting_users'
		local users = db:smembers(hash)
		db:sadd(hash, user_id)
		for i = 1, #users do
			if next(users) then
				if db:hget('info:'..users[i], 'sex') ~= sexuality then
					if user_id ~= users[i] then
						if not db:sismember('user:blocked_users:'..user_id, users[i]) then
							api.sendMessage(user_id, '💑 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							api.sendMessage(users[i], '💑 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							db:set('found_new_user:'..user_id, users[i])
							db:set('found_new_user:'..users[i], user_id)
							db:srem(hash, user_id)
							db:srem(hash, users[i])
							break
						end
					end
				end
			end
		end
	end
	------------------ [Same Chat] ------------------
	if blocks[1] == 'same_chat' then
		if not is_vip(user_id) then
			api.answerCallbackQuery(msg.cb_id, '🔻 برای استفاده از این قابلیت، شما باید حساب ویژه داشته باشید.\n'
			..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
			return
		end
		local text, keyboard
		api.answerCallbackQuery(msg.cb_id, 'در حال اتصال به هم جنس...')
		api.deleteMessage(user_id, msg.message_id)
		text = '👩‍❤️‍👩 در حال اتصال به هم جنس...\nلطفا صبر کنید...'
		keyboard = inChat()
		api.sendMessage(user_id, text, true, keyboard)
		local sexuality = db:hget('info:'..user_id, 'sex')
		local hash = 'same_chat:waiting_users'
		local users = db:smembers(hash)
		db:sadd(hash, user_id)
		for i = 1, #users do
			if next(users) then
				if db:hget('info:'..users[i], 'sex') == sexuality then
					if user_id ~= users[i] then
						if not db:sismember('user:blocked_users:'..user_id, users[i]) then
							api.sendMessage(user_id, '👩‍❤️‍👩 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							api.sendMessage(users[i], '👩‍❤️‍👩 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							db:set('found_new_user:'..user_id, users[i])
							db:set('found_new_user:'..users[i], user_id)
							db:srem(hash, user_id)
							db:srem(hash, users[i])
							break
						end
					end
				end
			end
		end
	end
	------------------ [City Chat] ------------------
	if blocks[1] == 'city_chat' then
		if not is_vip(user_id) then
			api.answerCallbackQuery(msg.cb_id, '🔻 برای استفاده از این قابلیت، شما باید حساب ویژه داشته باشید.\n'
			..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
			return
		end
		local text, keyboard
		api.answerCallbackQuery(msg.cb_id, 'در حال اتصال به هم شهری...')
		api.deleteMessage(user_id, msg.message_id)
		text = '🔥 در حال اتصال به هم شهری...\nلطفا صبر کنید...'

		api.sendMessage(user_id, text, true, keyboard)
		local city = db:hget('info:'..user_id, 'city')
		local hash = 'city_chat:waiting_users'
		local users = db:smembers(hash)
		db:sadd(hash, user_id)
		for i = 1, #users do
			if next(users) then
				if db:hget('info:'..users[i], 'city') == city then
					if user_id ~= users[i] then
						if not db:sismember('user:blocked_users:'..user_id, users[i]) then
							api.sendMessage(user_id, '🔥 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							api.sendMessage(users[i], '🔥 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							db:set('found_new_user:'..user_id, users[i])
							db:set('found_new_user:'..users[i], user_id)
							db:srem(hash, user_id)
							db:srem(hash, users[i])
							break
						end
					end
				end
			end
		end
	end
	------------------ [Age Chat] ------------------
	if blocks[1] == 'age_chat' then
		if not is_vip(user_id) then
			api.answerCallbackQuery(msg.cb_id, '🔻 برای استفاده از این قابلیت، شما باید حساب ویژه داشته باشید.\n'
			..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
			return
		end
		local text, keyboard
		api.answerCallbackQuery(msg.cb_id, 'در حال اتصال به مخاطب هم سن شما...')
		api.deleteMessage(user_id, msg.message_id)
		text = '🚶🏻 در حال اتصال به مخاطب هم سن شما...\nلطفا صبر کنید...'
		keyboard = inChat()
		api.sendMessage(user_id, text, true, keyboard)
		local age = db:hget('info:'..user_id, 'age')
		local hash = 'age_chat:waiting_users'
		local users = db:smembers(hash)
		db:sadd(hash, user_id)
		for i = 1, #users do
			if next(users) then
				if db:hget('info:'..users[i], 'age') == age then
					if user_id ~= users[i] then
						if not db:sismember('user:blocked_users:'..user_id, users[i]) then
							api.sendMessage(user_id, '🚶🏻 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							api.sendMessage(users[i], '🚶🏻 کاربر مورد نظر شما پیدا شد! هم اکنون می توانید با آن چت کنید.')
							db:set('found_new_user:'..user_id, users[i])
							db:set('found_new_user:'..users[i], user_id)
							db:srem(hash, user_id)
							db:srem(hash, users[i])
							break
						end
					end
				end
			end
		end
	end
	-------------------------------- [End Chat] --------------------------------
	--------------- [Resume Chat] ---------------
	if blocks[1] == 'resume_chat' then
		api.answerCallbackQuery(msg.cb_id, 'شما "ادامه گفتگو" را انتخاب کردید...')
		api.editMessageText(user_id, msg.message_id, 'به گفتگو خود ادامه دهید...')
	end
	--------------- [End Chat] ---------------
	if blocks[1] == 'end_chat' then
		local that_id = blocks[2]
		api.sendMessage(that_id, '🔻 مخاطب چت با شما را خاتمه داد.', true, {remove_keyboard = true})
		local keyboard1 = {inline_keyboard = {
			{{text = 'رد شدن 🔚', callback_data = 'bot:skip:'..user_id}, {text = 'بلاک کردن 📵', callback_data = 'bot:block_user:'..user_id}}
		}}
		api.sendMessage(that_id, '⁉️ آیا می خواهید آن را بلاک کنید؟', true, keyboard1)
		db:del('found_new_user:'..that_id)
		delete_waiting_users(that_id)
		-------           -------           -------            -------           -------
		api.deleteMessage(user_id, msg.message_id)
		api.sendMessage(user_id, '🔻 چت پایان یافت.', true, {remove_keyboard = true})
		local keyboard2 = {inline_keyboard = {
			{{text = 'رد شدن 🔚', callback_data = 'bot:skip:'..that_id}, {text = 'بلاک کردن 📵', callback_data = 'bot:block_user:'..that_id}}
		}}
		api.sendMessage(user_id, '⁉️ آیا می خواهید مخاطب را بلاک کنید؟', true, keyboard2)
		db:del('found_new_user:'..user_id)
		delete_waiting_users(user_id)
	end
	--------------- [Skip User] ---------------
	if blocks[1] == 'skip' then
		api.answerCallbackQuery(msg.cb_id, 'شما مخاطب را بلاک نکردید ...')
		api.editMessageText(user_id, msg.message_id, '👨🏻‍💻 دوست دارید با چه کسی چت کنید؟ از دکمه های زیر، یکی را به دلخواه انتخاب کنید.', true, chatKeyboard())
	end
	--------------- [Block User] ---------------
	if blocks[1] == 'block_user' then
		local that_id = blocks[2]
		local text = '🔸 به چه دلیلی می خواهید کاربر را بلاک کنید؟'
		local keyboard = {inline_keyboard = {
			{{text = 'تبلیغات می فرستاد 😤', callback_data = 'bot:block_user_true:'..that_id}},
			{{text = 'پُر رو بود 😒', callback_data = 'bot:block_user_true:'..that_id}, {text = 'جنسیتش دروغ بود 😑', callback_data = 'bot:block_user_true:'..that_id}},
			{{text = 'بلاکش نکن 🔚', callback_data = 'bot:skip:'..that_id}}
		}}
		api.editMessageText(user_id, msg.message_id, text, true, keyboard)
	end
	-------------- [Block User] ---------------
	if blocks[1] == 'block_user_true' then
		local that_id = blocks[2]
		db:sadd('user:blocked_users:'..user_id, that_id)
		db:sadd('user:blocked_users:'..that_id, user_id)
		api.editMessageText(user_id, msg.message_id, '🔻 مخاطب مورد نظر شما با موفقیت بلاک شد.\n\n'
		..'👨🏻‍💻 دوست دارید با چه کسی چت کنید؟ از دکمه های زیر، یکی را به دلخواه انتخاب کنید.', true, chatKeyboard())
	end
	-------------------------------- [Payment] -----------------------------------
	-------------------- [Balance] --------------------
	if blocks[1] == 'balance' then
		local text = ([[
💖 بخش افزایش اعتبار:

شما توسط این بخش می توانید اعتبار حساب خودتان را افزایش دهید و از خدمات حساب ویژه برخوردار شوید.

🔻 برخی از امکانات حساب ویژه:
• مشاهده اطلاعات کاربری که با آن چت می کنید.
• چت با جنس مخالف، چت با هم شهری، چت با هم سن، چت با هم جنس.
• فرستادن رسانه های خاص در چت ها.
• فرستادن آیدی و لینک در چت ها.
• فرستادن شماره موبایل در چت ها.
• و ...

🔸 برای افزایش اعتبار 2 روش وجود دارد!
• روش اول: دعوت دوستانتان به ربات و دریافت 500 تومن به ازای هر دعوت
• روش دوم: خرید حساب ویژه از طریق درگاه اینترنتی

👥 دعوت دوستان:
شما می توانید دوستان خود را با لینک مخصوص خودتان به ربات دعوت کنید و به ازای هر دعوت مبلغ 500 تومان به حساب شما افزوده خواهد شد.
سپس می توانید از اعتبار حساب خود برای خرید حساب ویژه استفاده کنید.

• برای مشاهده میزان اعتبار خود و سایر تنظیمات می توانید به بخش "اعتبار من" در منوی اصلی مراجعه کنید.
• برای پیدا کردن لینک مخصوص خودتان روی دکمه "دعوت دوستان" بزنید.

💵 بخش خرید اینترنتی:
در صورتی که شما نمی توانید از روش اول برای افزایش اعتبار استفاده کنید، می توانید هزینه آن را به صورت آنلاین بپردازید.

حساب های ویژه به صورت 1 ماهه و 3 ماهه ارائه می شوند که در صورت تمایل به خرید آن، می توانید روی دکمه "خرید اینترنتی" بزنید.

%s
		]]):format('@'..bot.username)
		local keyboard = {inline_keyboard = {
			{{text = 'خرید اینترنتی 💵', callback_data = 'bot:online_order'}, {text = 'خرید از اعتبار حساب 💎', callback_data = 'bot:credit_order'}},
			{{text = 'دعوت دوستان 👥', callback_data = 'bot:invite_friends'}},
			{{text = 'برگشت 🔙', callback_data = 'bot:back_to_menu'}}
		}}
		api.editMessageText(user_id, msg.message_id, text, 'html', keyboard)
	end
	----------------------- [My Account] -------------------------
	if blocks[1] == 'myaccount' then
		local cr
		if is_vip(user_id) then
			cr = 'اشتراک ویژه'
		else
			cr = 'اشتراک رایگان'
		end
		local expire = db:ttl('bot:charge_user:'..user_id)
		if expire then
			expire = math.floor(expire/86400) + 1
		else
			expire = 0
		end
		local invited = (db:scard('user:invited_by:'..user_id) * 500) or 0
		local text = ([[
💰 اعتبار من:

در زیر می توانید مشخصات حساب خود را مشاهده کنید.

• نوع اشتراک: <code>%s</code>
• تاریخ انقضا سرویس: <b>%s روز دیگر</b>
• اعتبار من: <b>%s</b> تومان

%s
		]]):format(cr, expire, invited, '@'..bot.username)
		local keyboard = {inline_keyboard = {
			{{text = 'افزایش اعتبار 💖', callback_data = 'bot:balance'}},
			{{text = 'برگشت 🔙', callback_data = 'bot:back_to_menu'}}
		}}
		api.editMessageText(user_id, msg.message_id, text, 'html', keyboard)
	end
	--------------------- [Credit Order] --------------------
	if blocks[1] == 'credit_order' then
		local text = ([[
🔸 مایل هستید کدام یک از حساب ها را بخرید؟

1. حساب ویژه 1 ماهه (4,000 تومان)
2. حساب ویژه 3 ماهه (10,000 تومان)
		]])
		local keyboard = {inline_keyboard = {
			{{text = 'سرویس سه ماهه 3️⃣', callback_data = 'bot:buy_service_two'}, {text = 'سرویس یک ماهه 1️⃣', callback_data = 'bot:buy_service_one'}},
			{{text = 'برگشت 🔙', callback_data = 'bot:balance'}}
		}}
		api.editMessageText(user_id, msg.message_id, text, 'html', keyboard)
	end
	--------------------- [Buy Service] --------------------
	if blocks[1] == 'buy_service_one' or blocks[1] == 'buy_service_two' then
		local acc = (db:scard('user:invited_by:'..user_id) * 500) or 0
		local text, keyboard, answer, status
		if blocks[1] == 'buy_service_one' then
			if acc >= 4000 then
				answer = 'حساب ویژه یک ماهه فعال شد!'
				db:sadd('buy:vip_account', user_id)
				db:setex('bot:charge_user:'..user_id, (86400 * 30), true)
				text = '✅ حساب ویژه یک ماهه با موفقیت فعال شد.'
			else
				answer = 'شما شارژ کافی برای انجام این تراکنش را ندارید.'
				status = true
			end
		elseif blocks[1] == 'buy_service_two' then
			if acc >= 10000 then
				answer = 'حساب ویژه سه ماهه فعال شد!'
				db:sadd('buy:vip_account', user_id)
				db:setex('bot:charge_user:'..user_id, (86400 * 90), true)
				text = '✅ حساب ویژه سه ماهه با موفقیت فعال شد.'
			else
				answer = 'شما شارژ کافی برای انجام این تراکنش را ندارید.'
				status = true
			end
		end
		api.answerCallbackQuery(msg.cb_id, answer, status)
		if text then
			api.editMessageText(user_id, msg.message_id, text, 'html')
		end
	end
	-------------------------------- [Select Sex] --------------------------------
	if blocks[1] == 'select_sex' then
		if db:get('user:getsex:'..user_id) then
			local per_string
			if blocks[2] == 'girl' then
				per_string = 'دختر'
			else
				per_string = 'پسر'
			end
			db:hset('info:'..user_id, 'sex', per_string)
			db:sadd('users:register', user_id)
			db:sadd('bot:'..blocks[2]..'s', user_id)
			db:del('user:getsex:'..user_id)
			api.editMessageText(user_id, msg.message_id, ('🔹 جنسیت "%s" برای شما ذخیره شد.\n'
			..'🔸 تبریک! ثبت نام شما تکمیل شد. هم اکنون می توانید از خدمات ربات چت ناشناس استفاده کنید.'):format(per_string), true, firstKeyboard())
		else
			api.editMessageText(user_id, msg.message_id, ('زمان شما برای انتخاب جنسیت به اتمام رسیده است. در صورتی که ثبت نام شما تکمیل نشده است، لطفا دوباره دستور /start را بزنید.'))
		end
	end
end

function plugin.onEveryMessage(msg)
	if msg.chat.type == 'private' then
		local user_id = msg.from.id
		local text, keyboard
		------------------ [In Chat] -------------------
		local found_user = db:get('found_new_user:'..user_id)
		if found_user then
			if msg.cb and (not msg.data:match('end_chat') and not msg.data:match('resume_chat')) then
				api.answerCallbackQuery(msg.cb_id, 'لطفا زمانی که در حال چت می باشید، از این دکمه ها استفاده نکنید!', true)
				return false
			end
			if (not msg.text:match('(لغو چت 🚫)') and not msg.text:match('/(start)') and not msg.text:match('/(endchat)')
			and not msg.text:match('(اطلاعات کاربر ℹ️)') and not msg.text:match('resume_chat') and not msg.text:match('end_chat')) then
				if msg.spam then
					if not is_vip(user_id) then
						api.sendReply(msg, '🔻 تنها کاربران ویژه توانایی ارسال لینک و تبلیغات را دارند!\n'
						..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
						return
					end
				end
				if msg.photo then
					api.sendMediaId(found_user, 'photo', msg.photo[#msg.photo].file_id, (msg.caption or ''))
					db:incr('total:photos')
					return
				elseif msg.voice then
					api.sendMediaId(found_user, 'voice', msg.voice.file_id, (msg.caption or ''))
					db:incr('total:voices')
					return
				elseif msg.video then
					api.sendMediaId(found_user, 'video', msg.video.file_id, (msg.caption or ''))
					db:incr('total:videos')
					return
				elseif msg.sticker then
					api.sendMediaId(found_user, 'sticker', msg.sticker.file_id)
					db:incr('total:stickers')
					return
				elseif msg.audio then
					api.sendMediaId(found_user, 'audio', msg.audio.file_id, (msg.caption or ''))
					db:incr('total:audios')
					return
				elseif msg.document then
					if msg.document.mime_type == 'video/mp4' then
						api.sendMediaId(found_user, 'document', msg.document.file_id, (msg.caption or ''))
						db:incr('total:documents')
						return
					else
						if is_vip(user_id) then
							api.sendMediaId(found_user, 'document', msg.document.file_id, (msg.caption or ''))
							db:incr('total:documents')
							return
						else
							api.sendReply(msg, '🔻 تنها کاربران ویژه می توانند فایل ارسال کنند!\n'
							..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
							return
						end
					end
				elseif msg.video_note then
					if is_vip(user_id) then
						api.sendMediaId(found_user, 'video_note', msg.video_note.file_id)
						db:incr('total:video_notes')
						return
					else
						api.sendReply(msg, '🔻 تنها کاربران ویژه می توانند فیلم سلفی ارسال کنند!\n'
						..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
						return
					end
				elseif msg.location then
					if is_vip(user_id) then
						api.sendLocation(found_user, msg.location.latitude, msg.location.longitude)
						db:incr('total:locations')
						return
					else
						api.sendReply(msg, '🔻 تنها کاربران ویژه می توانند لوکیشن ارسال کنند!\n'
						..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
						return
					end
				elseif msg.text then
					if msg.text:match('@') then
						if not is_vip(user_id) then
							api.sendReply(msg, '🔻 تنها کاربران ویژه می توانند آیدی ارسال کنند!\n'
							..'از منوی اصلی و بخش "دریافت حساب ویژه" اقدام به ارتقا حساب خود کنید.')
							return
						end
					end
					api.sendMessage(found_user, msg.text)
					db:incr('total:texts')
					return
				end
			end
		end
		------------------ [Unknown Chat] --------------
		local that_id = db:get('user:send_unknown_message:'..user_id)
		if that_id then
			if msg.cb then
				api.answerCallbackQuery(msg.cb_id, 'در صورتی که می خواهید این عملیات را لغو کنید، دستور /start را ارسال کنید.', true)
				return false
			end
			if not msg.text:match("/(start)") then
				if msg.text:match('([%S_]+)') then
					db:set('user:save_unknown_message:'..user_id..':'..that_id, msg.text)
					db:del('user:send_unknown_message:'..user_id)
					local keyboard = {inline_keyboard = {
						{{text = 'بله ✅', callback_data = 'bot:send_unknown_message:'..that_id}, {text = 'خیر 🚫', callback_data = 'bot:cancel_send:'..that_id}}
					}}
					local text = ('🔸 آیا مطمئن هستید می خواهید این متن را برای مخاطب ارسال کنید؟\n\n%s'):format(msg.text)
					api.sendReply(msg, text, nil, keyboard)
					return
				else
					api.sendReply(msg, '🔻 لطفا فقط متن خود را ارسال کنید.\nدر صورتی که می خواهید این عملیات را لغو کنید، دستور /start را بزنید.')
					return
				end
			end
		end
		------------------ [Reply] ---------------------
		local reply_id = db:get('user:reply_unknown_message:'..user_id)
		if reply_id then
			if msg.cb then
				api.answerCallbackQuery(msg.cb_id, 'در صورتی که می خواهید این عملیات را لغو کنید، دستور /start را ارسال کنید.', true)
				return false
			end
			if not msg.text:match("/(start)") then
				if msg.text:match('([%S_]+)') then
					api.sendMessage(reply_id, '#پاسخ_از_طرف_مخاطب\n\n'..msg.text)
					api.sendReply(msg, '✅ پیام شما با موفقیت ارسال شد.')
					db:del('user:reply_unknown_message:'..user_id)
					return
				else
					api.sendReply(msg, '🔻 لطفا فقط متن خود را ارسال کنید.\nدر صورتی که می خواهید این عملیات را لغو کنید، دستور /start را بزنید.')
					return
				end
			end
		end
		------------------ [Get Name] ------------------
		local get_name = db:get('user:getname:'..user_id)
		if get_name then
			if msg.cb then
				api.answerCallbackQuery(msg.cb_id, 'لطفا زمان ثبت نام از این دکمه ها استفاده نکنید!', true)
				return false
			end
			if msg.text:match('([%S_]+)') then
				text = ('🔹 نام شما به عنوان "%s" ذخیره شد.\n🔸 لطفا سن خود ارسال کنید.'
				..'\n• توجه: سن باید بین 10 تا 65 باشد و همچنین اعداد آن انگلیسی باشد!'):format(msg.text)
				db:hset('info:'..user_id, 'name', msg.text)
				db:setex('user:getage:'..user_id, 3600, true)
				db:del('user:getname:'..user_id)
			else
				text = '🔻 لطفا فقط نام خود را ارسال کنید!'
			end
			api.sendReply(msg, text)
			return
		end
		------------------ [Get Age] ------------------
		local get_age = db:get('user:getage:'..user_id)
		if get_age then
			if msg.cb then
				api.answerCallbackQuery(msg.cb_id, 'لطفا زمان ثبت نام از این دکمه ها استفاده نکنید!', true)
				return false
			end
			if msg.text:match('^(%d+)$') then
				if tonumber(msg.text:match('^(%d+)$')) >= 10 and tonumber(msg.text:match('^(%d+)$')) <= 65 then
					text = ('🔹 سن شما "%s" ذخیره شد.'
					..'\n🔸 لطفا استانی که در آن زندگی می کنید را انتخاب کنید.'):format(msg.text)
					local data = u.loadFile(config.state_path) or {}
					keyboard = {keyboard = {}}
					for num, name in pairs(data) do
						table.insert(keyboard.keyboard, {{text = '• '..name.name}})
					end
					db:hset('info:'..user_id, 'age', msg.text)
					db:setex('user:getstate:'..user_id, 3600, true)
					db:del('user:getage:'..user_id)
				else
					text = '🔻 لطفا عددی بین 10 تا 65 وارد کنید.'
				end
			else
				text = '🔻 لطفا عدد را انگلیسی وارد کنید!'
			end
			api.sendReply(msg, text, true, keyboard)
			return
		end
		------------------ [Get State] ------------------
		local get_state = db:get('user:getstate:'..user_id)
		if get_state then
			if msg.cb then
				api.answerCallbackQuery(msg.cb_id, 'لطفا زمان ثبت نام از این دکمه ها استفاده نکنید!', true)
				return false
			end
			local data = u.loadFile(config.state_path) or {}
			for num, name in pairs(data) do
				if msg.text:match(name.name) then
					local state = msg.text:gsub('• ', '')
					local text_ = ('🔹 محل زندگی شما به عنوان "%s" ذخیره شد.'):format(state)
					local keyboard1 = {remove_keyboard = true}
					api.sendReply(msg, text_, true, keyboard1)
					text = ('🔸 لطفا جنیست خودتان را انتخاب کنید (توجه: جنسیت قابل ویرایش نمی باشد؛ پس آن را با دقت انتخاب کنید)')
					keyboard = {inline_keyboard = {
						{{text = 'دختر 👩🏻‍🎤', callback_data = 'bot:select_sex:girl'}, {text = 'پسر 👨🏼‍💼', callback_data = 'bot:select_sex:boy'}}
					}}
					db:hset('info:'..user_id, 'city', state)
					db:del('user:getstate:'..user_id)
					db:setex('user:getsex:'..user_id, 3600, true)
					break
				else
					text = '🔻لطفا استان را به درستی انتخاب کنید!'
				end
			end
			api.sendReply(msg, text, true, keyboard)
			return
		end
		----------------------- [Support] -----------------------
		local need_support = db:get('support:user:'..user_id)
		if need_support then
			if msg.cb then return false end
			if not msg.text:match('/(start)') then
				api.forwardMessage(config.support, msg.chat.id, msg.message_id)
				return
			end
		end
		---------------------
		if user_id == config.support then
			if msg.text and msg.reply then
				local res = api.sendMessage(msg.reply.forward_from.id, '#پیام_از_طرف_پشتیبان\n\n'..msg.text)
				if res then
					api.sendReply(msg, 'پیام شما ارسال شد ✅')
				else
					api.sendReply(msg, 'پیام ارسال نشد ❌\nاحتمالا کاربر ربات رو بلاک کرده شایدم دلیت اکانت کرده.')
				end
			end
		end
		if is_block(user_id) then
			return false
		end
	end
	return true
end

plugin.triggers = {
	onTextMessage = {
		config.cmd..'(start)$',
		config.cmd..'(endchat)$',
		config.cmd..'(startmod)$',
		config.cmd..'(setvip) (%d+) (%d+)$',
		config.cmd..'(block) (.*)$',
		config.cmd..'(unblock) (.*)$',
		'^/(start) (invite_user)_(%d+)$',
		'^/(start) (unknownchat)_(%d+)$',
		----------------------
		'^(لغو چت 🚫)$',
		'^(اطلاعات کاربر ℹ️)$',
		config.cmd..'(dump)$',
		----------------------
		'(0)\n(.*)\n',
		'(1)\n(.*)\n(.*)-(.*)-(.*)-(.*)-(.*)',

	},
	onCallbackQuery = {
		'^###cb:bot:(select_sex):(.*)$',
		'^###cb:bot:(.*):(%d+)$',
		'^###cb:bot:(.*)$'
	}
}

return plugin
