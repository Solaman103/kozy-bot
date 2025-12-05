# Ruby Discord Bot Template

A minimal Discord bot starter using [discordrb](https://github.com/shardlab/discordrb) with environment-based configuration.

## Prerequisites
- Ruby 3.1+ and Bundler installed (for local runs)
- Docker (optional) for containerized runs
- Discord application with a bot token
- Message Content intent enabled for prefix commands; Server Members intent enabled if you use welcome/autorole

## Setup
1. Install dependencies:
   ```sh
   bundle install
   ```
2. Copy `.env.example` to `.env` and fill in your credentials (remove any spaces around `=`):
   ```sh
   cp .env.example .env
   ```
   - `DISCORD_TOKEN`: bot token from the Discord Developer Portal
   - `DISCORD_CLIENT_ID`: application/bot client ID
   - `BOT_PREFIX`: command prefix (defaults to `!`)
   - `SLASH_GUILD_ID`: optional; set a guild ID to register slash commands instantly for that server (global commands can take up to an hour to appear)
   - Optional: `WELCOME_CHANNEL_ID`, `WELCOME_MESSAGE`, `WELCOME_DM_MESSAGE`, `AUTOROLE_ROLE_ID`
3. Run the bot locally:
   ```sh
   bundle exec ruby bot.rb
   ```

## Docker
Build and run with Docker (uses `.env` for config):
```sh
# Build image
docker build -t ruby-discord-bot .

# Run container
docker run --rm \ 
  --env-file .env \ 
  ruby-discord-bot
```

Using docker-compose:
```sh
docker compose up --build
```

## What you get
- `!ping` / `/ping` latency check; `!about` / `/about` info
- `!echo` / `/echo <text>` echo text back
- `!roll [sides]` / `/roll [sides]` (defaults to 100, clamps 2-10000)
- `!serverinfo` / `/serverinfo` server stats (server-only)
- `!userinfo [@user]` / `/userinfo [user]` basic user info
- `!invite` / `/invite` bot invite link (needs `applications.commands` scope)
- Optional welcome message (channel + DM) and autorole when env vars are provided
- Graceful shutdown on Ctrl+C

## Tips
- Keep `.env` private (tokens should never be committed).
- Regenerate your token if it was ever shared.
- Slash commands: they register on boot. If `sync_application_commands` is available in your discordrb version, they sync immediately; otherwise Discord will propagate them automatically. Guild-scoped (`SLASH_GUILD_ID`) appear instantly; global can take up to ~1 hour to show in clients.
