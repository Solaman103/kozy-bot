# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "discordrb"

# Fetch a required environment variable or abort with a helpful message.
def require_env!(key)
  value = ENV[key]
  return value.strip unless value.nil? || value.strip.empty?

  abort("Missing ENV: #{key}. Set it in .env before running the bot.")
end

# Fetch an optional environment variable, returning nil when empty.
def optional_env(key)
  value = ENV[key]
  return nil if value.nil? || value.strip.empty?

  value.strip
end

token = require_env!("DISCORD_TOKEN")
client_id = require_env!("DISCORD_CLIENT_ID")
prefix = optional_env("BOT_PREFIX") || "!"
slash_guild_id = optional_env("SLASH_GUILD_ID")&.to_i

welcome_channel_id = optional_env("WELCOME_CHANNEL_ID")&.to_i
welcome_message = optional_env("WELCOME_MESSAGE") || "Welcome to %{server}, %{user}!"
welcome_dm_message = optional_env("WELCOME_DM_MESSAGE")
autorole_role_id = optional_env("AUTOROLE_ROLE_ID")&.to_i

# Build intents bitmask using the hash-style constants.
intents_mask = Discordrb::INTENTS[:server_messages] | Discordrb::INTENTS[:direct_messages] | Discordrb::INTENTS[:server_members]
intents_mask |= Discordrb::INTENTS[:message_content] if Discordrb::INTENTS.key?(:message_content)

bot = Discordrb::Commands::CommandBot.new(
  token: token,
  client_id: client_id,
  prefix: prefix,
  intents: intents_mask,
  log_mode: :info
)

bot.ready do |_event|
  puts "Connected as #{bot.bot_user.distinct} - Guilds: #{bot.servers.count}"
end

bot.command(:ping, description: "Check latency") do |event|
  latency = (Time.now - event.timestamp).round(3)
  event.respond("Pong! (#{latency}s)")
end

bot.command(:about, description: "Show basic info") do |event|
  event.respond("Hello, I'm #{bot.bot_user.distinct}. Prefix: `#{prefix}`. Try `#{prefix}ping`.")
end

bot.command(:echo, description: "Echo back text", usage: "#{prefix}echo <text>") do |event, *args|
  return event.respond("Usage: #{prefix}echo <text>") if args.empty?

  event.respond(args.join(" "))
end

bot.command(:roll, description: "Roll a die", usage: "#{prefix}roll [sides] (default 100)") do |event, sides = nil|
  sides = Integer(sides || 100) rescue 100
  sides = [[sides, 2].max, 10_000].min
  roll = rand(1..sides)
  event.respond("#{event.user.distinct} rolled #{roll} (1-#{sides})")
end

bot.command(:serverinfo, description: "Show server info") do |event|
  server = event.server
  return event.respond("This command only works in a server.") unless server

  owner = server.owner&.distinct || server.owner_id
  member_count = server.member_count || server.members.count
  event.respond("Server: #{server.name} | Members: #{member_count} | Owner: #{owner}")
end

bot.command(:userinfo, description: "Show user info", usage: "#{prefix}userinfo [@user]") do |event|
  target = event.message.mentions.first || event.user
  event.respond("User: #{target.distinct} | ID: #{target.id}")
end

bot.command(:invite, description: "Get the bot invite link") do |event|
  scopes = "bot%20applications.commands"
  event.respond("Invite me: https://discord.com/api/oauth2/authorize?client_id=#{client_id}&permissions=0&scope=#{scopes}")
end

# Slash commands
register_slash = lambda do |name, description, &block|
  if slash_guild_id
    bot.register_application_command(name, description, guild_ids: [slash_guild_id], &block)
  else
    bot.register_application_command(name, description, &block)
  end
end

register_slash.call(:ping, "Ping the bot")
register_slash.call(:about, "Show basic info")
register_slash.call(:echo, "Echo back text") do |cmd|
  cmd.string("text", "Text to echo", required: true)
end
register_slash.call(:roll, "Roll a die") do |cmd|
  cmd.integer("sides", "Number of sides (2-10000)", required: false)
end
register_slash.call(:serverinfo, "Show server info")
register_slash.call(:userinfo, "Show user info") do |cmd|
  cmd.user("user", "User to inspect", required: false)
end
register_slash.call(:invite, "Get the bot invite link")

if bot.respond_to?(:sync_application_commands)
  begin
    bot.sync_application_commands
    scope = slash_guild_id ? "guild #{slash_guild_id}" : "global"
    puts "Synced slash commands (#{scope})."
  rescue StandardError => e
    warn "Failed to sync slash commands: #{e.class}: #{e.message}"
  end
else
  warn "Skipping slash sync; discordrb version does not support sync_application_commands (commands will register via create/update)."
end

bot.application_command(:ping) do |event|
  event.respond(content: "Pong!")
end

bot.application_command(:about) do |event|
  event.respond(content: "Hello, I'm #{bot.bot_user.distinct}. Try `/ping` or `#{prefix}ping`.")
end

bot.application_command(:echo) do |event|
  event.respond(content: event.options["text"])
end

bot.application_command(:roll) do |event|
  sides = (event.options["sides"] || 100).to_i
  sides = [[sides, 2].max, 10_000].min
  roll = rand(1..sides)
  event.respond(content: "#{event.user.distinct} rolled #{roll} (1-#{sides})")
end

bot.application_command(:serverinfo) do |event|
  server = event.server
  unless server
    event.respond(content: "This command only works in a server.")
    next
  end

  owner = server.owner&.distinct || server.owner_id
  member_count = server.member_count || server.members.count
  event.respond(content: "Server: #{server.name} | Members: #{member_count} | Owner: #{owner}")
end

bot.application_command(:userinfo) do |event|
  user_option = event.options["user"]
  target =
    if user_option
      # user_option is an ID string; try resolving to a member first (for nickname), then fallback to user.
      member = event.server&.member(user_option)
      member || bot.user(user_option) || event.user
    else
      event.user
    end

  event.respond(content: "User: #{target.distinct} | ID: #{target.id}")
end

bot.application_command(:invite) do |event|
  scopes = "bot%20applications.commands"
  event.respond(content: "Invite me: https://discord.com/api/oauth2/authorize?client_id=#{client_id}&permissions=0&scope=#{scopes}")
end

bot.member_join do |event|
  server_name = event.server.name
  user_mention = event.user.mention

  if welcome_channel_id
    channel = bot.channel(welcome_channel_id)
    channel&.send_message(
      welcome_message
        .gsub("%{server}", server_name)
        .gsub("%{user}", user_mention)
    )
  end

  if welcome_dm_message
    event.user.pm(welcome_dm_message.gsub("%{server}", server_name))
  end

  if autorole_role_id
    role = event.server.role(autorole_role_id)
    event.member.add_role(role) if role
  end
end

trap("INT") { bot.stop; exit }
trap("TERM") { bot.stop; exit }

bot.run
