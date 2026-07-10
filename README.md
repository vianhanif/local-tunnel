# Local Tunnel

**Permanent HTTPS tunnel for local AI model servers**

Expose your local AI model server to the internet with a production-grade HTTPS connection.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                  │
│              https://<your-domain>                               │
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
│                     http://localhost:<PORT>                      │
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

After setup, your tunnel URL will be: `https://<your-domain>`

## Manual Setup

### 1. Install Caddy

```bash
brew install caddy
```

### 2. Configure Caddy

Copy `Caddyfile` to your working directory and edit:

```
<your-domain> {
    tls internal
    reverse_proxy localhost:<PORT>
}
```

Start Caddy:

```bash
caddy start
```

### 3. Add hosts entry (optional)

If using a local-only domain, add to `/etc/hosts`:

```bash
echo '127.0.0.1 <your-domain>' | sudo tee -a /etc/hosts
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
cloudflared tunnel create <tunnel-name>
```

This creates a credentials file at `~/.cloudflared/<TUNNEL_ID>.json`.

### 7. Route DNS

```bash
cloudflared tunnel route dns <tunnel-name> <your-domain>
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
  - hostname: <your-domain>
    service: http://localhost:<PORT>
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

### 10. Verify

```bash
cloudflared tunnel info <tunnel-name>
```

You should see "CONNECTOR ID" with 1+ active connections.

## Usage

Use the public URL as an OpenAI-compatible endpoint in any AI client:

```
https://<your-domain>/v1
```

### Warp AI

1. Open Warp settings → AI Providers
2. Add custom OpenAI-compatible provider
3. Set endpoint to `https://<your-domain>/v1`
4. Leave API key blank or set whatever your local server expects

### Cursor

1. Settings → AI Settings → Custom Providers
2. Add your endpoint

## Aliases

The following can be added to `~/.zshrc` for convenience:

```bash
alias tunnel-start='if launchctl list com.local-tunnel.cloudflared &>/dev/null; then echo "tunnel already running"; else launchctl load ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist && echo "tunnel started"; fi'
alias tunnel-status='cloudflared tunnel info <tunnel-name>'
alias tunnel-logs='tail -20 /tmp/cloudflared-tunnel.log'
alias tunnel-err='tail -20 /tmp/cloudflared-tunnel.err'
```

## Configuration Reference

| Placeholder | Description |
|---|---|
| `<TUNNEL_ID>` | UUID from credentials filename (e.g., `abc123-def456-...`) |
| `<USERNAME>` | Your macOS username |
| `<your-domain>` | Your subdomain (e.g., `api.example.com`) |
| `<tunnel-name>` | Your tunnel name (e.g., `my-api-tunnel`) |
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
cloudflared tunnel info <tunnel-name>
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
cloudflared tunnel delete <tunnel-name>
```

Stop Caddy:

```bash
caddy stop
```
