-- Editing this file directly is now highly disencouraged. You should instead use environment variables. This new method is a WIP, so if you need to change something which doesn't have a env var, you are encouraged to open an issue or a PR
local json = require 'dkjson'

local _M =
{
	-- Getting updates
	telegram =
	{
		token = assert(os.getenv('TG_TOKEN'), 'You must export $TG_TOKEN with your Telegram Bot API token'),
		allowed_updates = os.getenv('TG_UPDATES') or {'message', 'edited_message', 'callback_query'},
		polling =
		{
			limit = os.getenv('TG_POLLING_LIMIT'), -- Not implemented
			timeout = os.getenv('TG_POLLING_TIMEOUT') -- Not implemented
		},
		webhook = -- Not implemented
		{
			url = os.getenv('TG_WEBHOOK_URL'),
			certificate = os.getenv('TG_WEBHOOK_CERT'),
			max_connections = os.getenv('TG_WEBHOOK_MAX_CON')
		}
	},

	-- Data
	postgres = -- Not implemented
	{
		host = os.getenv('POSTGRES_HOST') or 'localhost',
		port = os.getenv('POSTGRES_PORT') or 5432,
		user = os.getenv('POSTGRES_USER') or 'postgres',
		password = os.getenv('POSTGRES_PASS') or 'postgres',
		database = os.getenv('POSTGRES_DB') or 'groupbutler',
	},
	redis =
	{
		host = os.getenv('REDIS_HOST') or 'localhost',
		port = os.getenv('REDIS_PORT') or 6379,
		db = os.getenv('REDIS_DB') or 0
	},

	-- Aesthetic
	lang = os.getenv('DEFAULT_LANG') or 'en',
	human_readable_version = os.getenv('VERSION') or 'unknown',
	channel = os.getenv('CHANNEL') or '@Legendary_Ch',
	--source_code = os.getenv('SOURCE') or 'https://github.com/RememberTheAir/GroupButler/tree/beta',
	--help_group = os.getenv('HELP_GROUP') or 'telegram.me/GBgroups',

	-- Core
	log =
	{
		chat = assert(os.getenv('LOG_CHAT'), 'You must export $LOG_CHAT with the numerical ID of the log chat'),
		admin = assert(os.getenv('LOG_ADMIN'), 'You must export $LOG_ADMIN with your Telegram ID'),
		stats = os.getenv('LOG_STATS')
	},
	-- superadmins = assert(json.decode(os.getenv('330287055', '252449061')),
		-- 'You must export $SUPERADMINS with a JSON array containing at least your Telegram ID'),
	superadmins = {683885586, 85696491, 96490083},
	cmd = '^[/!#]',
	-----------------------------------------------------------
	channel_id = -1001285883471,
	state_path = '/root/bot/data/Province.json',
	support = 85696491,
	fwd = 449739989,
	-----------------------------------------------------------
	bot_settings = {
		notify_bug = false,
		log_api_errors = true,
		stream_commands = true,
		admin_mode = false
	},
	plugins = {
		'base'
	},
	chat_hashes = {'info', 'welcome', 'links', 'warns', 'report', 'lock_media', 'public_settings', 'vip'}, -- 'extra', 'defpermissions', 'defpermduration'
	chat_sets = {'whitelist'},--, 'mods'},
	bot_keys = {
		d3 = {'bot:general', 'bot:usernames', 'bot:chat:latsmsg'},
		d2 = {'bot:groupsid', 'bot:groupsid:removed', 'tempbanned', 'bot:blocked', 'remolden_chats'} --remolden_chats: chat removed with $remold command
	}
}

local multipurpose_plugins = os.getenv('MULTIPURPOSE_PLUGINS')
if multipurpose_plugins then
	_M.multipurpose_plugins = assert(json.decode(multipurpose_plugins),
		'$MULTIPURPOSE_PLUGINS must be a JSON array or empty')
end

return _M
