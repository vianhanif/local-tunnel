# Local Tunnel — Permanent HTTPS Tunnel via Cloudflare + Caddy

## Overview

Two layers of HTTPS for your local service:

- **Caddy** — self-signed local HTTPS (handy for local dev that expects HTTPS)
- **Cloudflare Tunnel (`cloudflared`)** — public HTTPS tunnel to your local machine, managed as a persistent macOS service via `launchd`

Use the public URL as an OpenAI-compatible endpoint in tools like Warp, Cursor, or any AI client pointing at your local model server.

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- A domain on Cloudflare (free tier works)
- Your local service already running (e.g., `http://localhost:20128`)

> 💡 **Automated setup:** Run `./setup.sh` for an interactive script that handles everything.

## Setup

### 1. Install Caddy

```bash
brew install caddy
```

### 2. Configure Caddy

Copy the included `Caddyfile` to your working directory and edit it:

```
# Replace <your-local-domain> with your choice (e.g., local-9router.com)
# Replace <port> with your service port (e.g., 20128)
my-local-domain.example.com {
    tls internal
    reverse_proxy localhost:<port>
}
```

Start Caddy:

```bash
caddy start
```

### 3. Add hosts entry (if using a local-only domain)

**Only needed if using Caddy for local HTTPS with a fake domain.**  
Skip if you only need the public Cloudflare tunnel URL.

```bash
echo '127.0.0.1 my-local-domain.example.com' | sudo tee -a /etc/hosts
```

### 4. Install cloudflared

```bash
brew install cloudflared
```

### 5. Log in to Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser. Authenticate with your Cloudflare account that owns the domain.

### 6. Create a tunnel

```bash
cloudflared tunnel create <tunnel-name>
```

Replace `<tunnel-name>` with something descriptive (e.g., `my-api-tunnel`).  
This generates a `<TUNNEL_ID>.json` credentials file in `~/.cloudflared/`.

### 7. Route DNS

```bash
cloudflared tunnel route dns <tunnel-name> <subdomain.yourdomain.com>
```

This creates a CNAME record pointing `<subdomain.yourdomain.com>` to your tunnel.

### 8. Copy and edit template files

```bash
# Copy and rename so filename matches Label in plist
cp com.9router.tunnel.plist ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
cp config.yml ~/.cloudflared/config.yml
```

Edit `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /Users/<USERNAME>/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: <SUBDOMAIN.YOURDOMAIN.COM>
    service: http://localhost:<PORT>
  - service: http_status:404
```

| Placeholder | Replace with |
|---|---|
| `<TUNNEL_ID>` | The UUID from the credentials filename |
| `<USERNAME>` | Your macOS username |
| `<SUBDOMAIN.YOURDOMAIN.COM>` | Your subdomain from step 7 |
| `<PORT>` | Your local service port |

Edit `~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist` — replace `<USERNAME>`, `<TUNNEL_NAME>`:

| Placeholder | Replace with |
|---|---|
| `<USERNAME>` | Your macOS username |
| `<TUNNEL_NAME>` | The tunnel name from step 6 |

### 9. Load the launchd service

```bash
launchctl load ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
```

The tunnel starts immediately and respawns automatically on crash or reboot.

## Usage

Use the public URL in any tool that supports OpenAI-compatible endpoints:

```
https://<subdomain.yourdomain.com>/v1
```

### Warp example

1. Open Warp
2. Add a custom OpenAI-compatible provider
3. Set endpoint to `https://<subdomain.yourdomain.com>/v1`
4. Leave API key blank (or set whatever your service expects)

## Troubleshooting

| Command | What it does |
|---|---|
| `cloudflared tunnel info <name>` | Show connection status and details |
| `cloudflared tunnel list` | List all tunnels |
| `tail -f /tmp/cloudflared-tunnel.log` | Live tunnel logs |
| `tail -f /tmp/cloudflared-tunnel.err` | Error logs |
| `launchctl list \| grep 9router` | Check if launchd service is running |

### Common issues

- **"Failed to connect to localhost"** — make sure your local service is running on the correct port
- **"Tunnel not found"** — the `<TUNNEL_ID>` in config.yml is wrong; check `~/.cloudflared/` for the JSON file
- **Permission denied** — the credentials file path in config.yml must be absolute and readable

## File structure

```
local-tunnel/
├── README.md                       # This file
├── Caddyfile                       # Caddy config template
├── config.yml                      # Cloudflare tunnel config template
├── com.9router.tunnel.plist        # launchd service definition
└── setup.sh                        # Interactive setup script
```

## Cleanup

Remove the launchd service:

```bash
launchctl unload ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
rm ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
```

Delete the tunnel (this revokes the DNS route):

```bash
cloudflared tunnel delete <tunnel-name>
```

Stop Caddy:

```bash
caddy stop
```

Remove hosts entry (if added):

```bash
# Remove the line you added from /etc/hosts
```
