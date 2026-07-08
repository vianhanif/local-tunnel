# Local Tunnel

**Permanent HTTPS tunnel for local AI model servers**

Expose your local AI model server to the internet with a production-grade HTTPS connection. This setup powers tools like Warp and Cursor with local AI models.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                  │
│              https://api.yourdomain.com                         │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ HTTPS (Cloudflare)
                              │
┌─────────────────────────────────────────────────────────────────┐
│                 Cloudflare Tunnel (cloudflared)                 │
│              Runs as persistent macOS launchd service           │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ HTTPS (self-signed)
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    Caddy (local reverse proxy)                  │
│              Handles local HTTPS for dev tools                  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ HTTP
                              │
┌─────────────────────────────────────────────────────────────────┐
│              Local AI Model Server (e.g., 9router)              │
│                     http://localhost:20128                      │
└─────────────────────────────────────────────────────────────────┘
```

**Two layers of HTTPS:**

1. **Caddy** — Local HTTPS termination using self-signed certificates. Useful for tools that require HTTPS (some AI clients, browser-based dev tools).
2. **Cloudflare Tunnel** — Public HTTPS tunnel that connects your Mac to your domain, running as a persistent background service.

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- A domain on Cloudflare (free tier works)
- Your local service running (e.g., an OpenAI-compatible API server)

## Quick Start

Run the automated setup script:

```bash
./setup.sh
```

The script will guide you through:
1. Installing dependencies (cloudflared)
2. Authenticating with Cloudflare
3. Creating a tunnel with your domain
4. Installing the launchd service

After setup, your tunnel URL will be: `https://<your-subdomain>/v1`

## Manual Setup

### 1. Install Caddy

```bash
brew install caddy
```

### 2. Configure Caddy

Copy `Caddyfile` to your working directory and edit:

```
api.yourdomain.com {
    tls internal
    reverse_proxy localhost:20128
}
```

Start Caddy:

```bash
caddy start
```

### 3. Add hosts entry (optional)

If using a local-only domain, add to `/etc/hosts`:

```bash
echo '127.0.0.1 api.yourdomain.com' | sudo tee -a /etc/hosts
```

### 4. Install cloudflared

```bash
brew install cloudflared
```

### 5. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

Opens browser — authenticate with your Cloudflare account.

### 6. Create tunnel

```bash
cloudflared tunnel create my-api-tunnel
```

This creates a credentials file at `~/.cloudflared/<TUNNEL_ID>.json`.

### 7. Route DNS

```bash
cloudflared tunnel route dns my-api-tunnel api.yourdomain.com
```

### 8. Configure and install service

Copy and configure files:

```bash
# Install launchd service
cp com.9router.tunnel.plist ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist

# Install tunnel config
cp config.yml ~/.cloudflared/config.yml
```

Edit `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /Users/<USERNAME>/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:20128
  - service: http_status:404
```

Edit `~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist`:
- Replace `<USERNAME>` with your macOS username
- Replace `<TUNNEL_NAME>` with your tunnel name

### 9. Start the service

```bash
launchctl load ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
```

The tunnel starts immediately and will respawn automatically after crashes or reboots.

## Usage

Use the public URL as an OpenAI-compatible endpoint in any AI client:

```
https://api.yourdomain.com/v1
```

### Warp AI

1. Open Warp settings → AI Providers
2. Add custom OpenAI-compatible provider
3. Set endpoint to `https://api.yourdomain.com/v1`
4. Leave API key blank or set whatever your local server expects

### Cursor

1. Settings → AI Settings → Custom Providers
2. Add your endpoint

## Configuration Reference

| Placeholder | Description |
|---|---|
| `<TUNNEL_ID>` | UUID from credentials filename (e.g., `abc123-def456-...`) |
| `<USERNAME>` | Your macOS username |
| `<SUBDOMAIN.YOURDOMAIN.COM>` | Your subdomain (e.g., `api.example.com`) |
| `<PORT>` | Your local service port (e.g., `20128`) |

## File Structure

```
local-tunnel/
├── README.md                   # This file
├── Caddyfile                   # Caddy reverse proxy config
├── config.yml                  # Cloudflare Tunnel config template
├── com.9router.tunnel.plist    # macOS launchd service definition
└── setup.sh                    # Automated setup script
```

## Troubleshooting

### Check tunnel status

```bash
cloudflared tunnel info my-api-tunnel
cloudflared tunnel list
```

### View logs

```bash
# Live logs
tail -f /tmp/cloudflared-tunnel.log

# Error logs
tail -f /tmp/cloudflared-tunnel.err
```

### Check launchd service

```bash
launchctl list | grep cloudflared
```

### Common Issues

| Error | Solution |
|---|---|
| Failed to connect to localhost | Verify your local service is running on the correct port |
| Tunnel not found | Check `<TUNNEL_ID>` in config.yml matches the credentials filename |
| Permission denied | Ensure credentials file path is absolute and readable |

## Cleanup

Remove the launchd service:

```bash
launchctl unload ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
rm ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
```

Delete the tunnel (also removes DNS route):

```bash
cloudflared tunnel delete my-api-tunnel
```

Stop Caddy:

```bash
caddy stop
```
