# From Basement to Internet: Exposing Local AI Models to Production Tools

*How I built a production-grade tunnel to use my local AI server in Warp, Cursor, and beyond*

---

Last year, I started running AI models locally. Ollama, llama.cpp, and eventually a self-hosted router called 9router that lets me manage multiple model providers through a single OpenAI-compatible API.

It was great. Fast inference, no API costs, full privacy. But there was a problem.

**My AI clients couldn't reach it.**

Tools like Warp and Cursor expect an HTTPS endpoint. They work with cloud APIs that have valid TLS certificates. My local server? Running on `http://localhost:20128` with no encryption, unreachable from outside my machine.

I needed a tunnel.

## The Problem with Simple Tunnels

I'd used ngrok before. It's simple: `ngrok http 20128`, get a public URL, done. But ngrok's free tier has limitations — random URLs, bandwidth caps, sessions that expire.

For daily use with production tools, I needed something more reliable. Something with a domain I controlled. Something that would just *work* after a reboot.

The ideal solution:

- **Permanent URL** — `api.mydomain.com`, not `https://abc123.ngrok.io`
- **Valid HTTPS** — Clients need real TLS certificates
- **Automatic recovery** — Tunnel restarts after crashes or reboots
- **Free** — Because I'm cheap and this shouldn't cost money

## The Two-Layer Approach

After some experimentation, I landed on a two-layer architecture:

### Layer 1: Caddy (Local HTTPS)

Caddy is a reverse proxy that automatically handles TLS. With `tls internal`, it generates self-signed certificates on the fly.

```nginx
api.local {
    tls internal
    reverse_proxy localhost:20128
}
```

Why bother with local HTTPS? Some tools and libraries require HTTPS even for local connections. Browser-based dev tools, certain SDKs, and some AI clients validate certificates. Caddy lets these tools work without modifying them.

### Layer 2: Cloudflare Tunnel (Public Internet)

Cloudflare Tunnel (formerly Argo Tunnel) creates an outbound connection from your server to Cloudflare's edge. No inbound ports needed. No firewall configuration. Just a persistent connection that Cloudflare then terminates with proper HTTPS.

The tunnel runs as a macOS `launchd` service — the macOS equivalent of systemd. It starts at login, respawns on crash, and just keeps running.

```yaml
tunnel: abc123-def456
credentials-file: /Users/me/.cloudflared/abc123-def456.json

ingress:
  - hostname: api.mydomain.com
    service: http://localhost:20128
  - service: http_status:404
```

Now `https://api.mydomain.com/v1` points to my local server.

## Why This Matters for AI Development

Here's the thing about local AI models: they're *fast* for development. When you're building prompts, iterating on agentic workflows, or debugging LLM integrations, you don't want to wait for cloud API responses or burn through tokens.

But you also want to use your favorite tools. Warp's AI features. Cursor's autocomplete. The growing ecosystem of AI-powered development environments.

These tools are built for the cloud API paradigm. OpenAI-compatible endpoints, HTTPS, API keys. Local models broke that model — until now.

With this tunnel, I get:

- **Latency** — Sub-millisecond instead of 100ms+ to cloud APIs
- **Cost** — Zero per-token fees
- **Privacy** — Prompts never leave my machine
- **Compatibility** — Use any OpenAI-compatible client with my local models

## The Technical Details

### Why Cloudflare Tunnel?

I evaluated a few options:

- **ngrok** — Good, but free tier limitations are real
- **Cloudflare Tunnel** — Free, permanent URLs, solid infrastructure
- **Let's Encrypt + reverse proxy** — Requires port forwarding, complex setup

Cloudflare Tunnel won because it doesn't require inbound firewall rules. The connection originates from my machine to Cloudflare. My router's NAT doesn't matter. The tunnel just works.

### Why launchd?

I initially tried running cloudflared with `launchd` because I wanted reliability. A tunnel that dies isn't a tunnel — it's a hassle.

`launchd` on macOS provides:
- Automatic startup at login
- Crash recovery
- Standardized service management
- Log file rotation

The plist configuration is straightforward:

```xml
<key>KeepAlive</key>
<true/>
<key>RunAtLoad</key>
<true/>
```

### The Caddy Layer

Caddy handles the TLS termination locally. This matters for clients that validate certificates or require HTTPS for other reasons.

For simple use cases, you can skip Caddy and point Cloudflare Tunnel directly at your HTTP server. But if you see SSL errors or HTTPS-related issues in your client, Caddy solves them.

## What I Learned

1. **Outbound tunnels are easier than inbound** — Don't fight NAT when you don't have to
2. **launchd is underutilized** — It handles persistence better than background screen sessions
3. **Cloudflare's free tier is generous** — Unlimited tunnels, no bandwidth limits for the tunnel itself
4. **Two layers add resilience** — If Caddy fails, the tunnel still works; if tunnel fails, Caddy still serves local traffic

## The Setup Script

To make this reproducible, I wrote a setup script that handles:

- Dependency installation
- Cloudflare authentication
- Tunnel creation
- DNS routing
- Service installation

One command to rule them all:

```bash
./setup.sh
```

The script asks for your tunnel name, subdomain, and port, then configures everything automatically.

## What's Next

This setup has been running on my Mac for months now. It's not glamorous — it's infrastructure. The kind of thing that just works until you need to explain it to someone else.

If you're running local AI models and want to use them with production tools, I hope this saves you the debugging time I put in.

The repo is at [github.com/vianhanif/local-tunnel](https://github.com/vianhanif/local-tunnel) if you want to fork it or adapt it for your setup.

---

*No affiliates. No tracking. Just a tunnel from your basement to the internet.*
