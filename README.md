# Factorio Docker

Factorio headless server on a minimal scratch Docker image. See https://wiki.factorio.com/Multiplayer#Setting_Up_a_Multiplayer_Game for configuration.

## Quick Start

Initialize game:
```shell
docker run --rm \
    --volume /data/factorio/saves:/factorio/saves \
    --volume /data/factorio/mods:/factorio/mods \
    ghcr.io/rayschpp/factorio-docker:latest \
    --create saves/new-game.zip
```

Running the server 24/7: 
```shell
docker run \
  --detached \
  --restart unless-stopped \
  --publish 34197:34197/udp \
  --volume /data/factorio/saves:/factorio/saves \
  --volume /data/factorio/mods:/factorio/mods \
  ghcr.io/rayschpp/factorio-docker:latest 
```

## Configuration

### Server Settings

Edit `data/server-settings.json`:

- `name` - Server name in browser
- `description` - Server description
- `visibility.public` - Set to `true` for public servers
- `visibility.lan` - Set to `true` for LAN servers
- `game_password` - Server password
- `max_players` - Player limit (0 = unlimited)

### Public Server Authentication

For public visibility, you need a Factorio.com auth token:

1. Log in at https://factorio.com
2. Go to Profile → Auth Token
3. Copy token to `data/player-data.json`:
   ```json
   {
     "token": "your-token-here"
   }
   ```

## Commands

```bash
# Start server
docker compose up -d

# View logs
docker compose logs -f factorio

# Stop server
docker compose down

# Create a new save (run before first start)
docker compose run --rm factorio --create saves/my-game.zip

# Start with specific save
docker compose run factorio --start-server saves/my-game.zip --server-settings /factorio/data/server-settings.json
```

See: https://wiki.factorio.com/Command_line_parameters

## Volumes

| Path | Purpose |
|------|---------|
| `./saves` | Game save files (.zip) |
| `./mods` | Mod files (.zip) |
| `./data/server-settings.json` | Server configuration |
| `./data/player-data.json` | Factorio.com auth (for public servers) |

## Networking

Port `34197/udp` must be accessible for players to connect.

## Dockerfile

The image uses a multi-stage build:

1. **Builder stage** (`debian:bookworm-slim`): Downloads and extracts Factorio headless
2. **Final stage** (`scratch`): Contains only the binary and required libraries

This results in a minimal ~50-80MB image with no shell or unnecessary tools.
