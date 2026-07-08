#!/bin/bash
set -e

echo "=== Local Tunnel Setup ==="
echo ""

# Check prerequisites
command -v brew >/dev/null 2>&1 || { echo "❌ Homebrew required. Install: https://brew.sh"; exit 1; }
command -v cloudflared >/dev/null 2>&1 || { echo "📦 Installing cloudflared..."; brew install cloudflared; }

# Check Cloudflare auth
if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo "🔐 You need to authenticate with Cloudflare first."
    echo "   Running: cloudflared tunnel login"
    echo "   (A browser window will open — log in and select your domain)"
    cloudflared tunnel login
    echo ""
fi

CLOUDFLARED_BIN=$(which cloudflared)

echo "Step 1: Login to Cloudflare"
echo "  → Run: cloudflared tunnel login"
echo "  (opens browser, authenticate with your domain)"
echo ""

read -p "Tunnel name (e.g., my-tunnel): " TUNNEL_NAME
read -p "Subdomain + domain (e.g., api.example.com): " SUBDOMAIN
read -p "Local port (e.g., 20128): " LOCAL_PORT
read -p "Your macOS username: " USERNAME

echo ""
echo "Step 2: Creating tunnel..."
if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
    echo "❌ Tunnel '$TUNNEL_NAME' already exists. Choose a different name."
    exit 1
fi
cloudflared tunnel create "$TUNNEL_NAME"

# Get tunnel ID from the credentials file (named <ID>.json)
CRED_FILE=$(ls -t ~/.cloudflared/*.json 2>/dev/null | head -1)
if [ -z "$CRED_FILE" ]; then
    echo "❌ Failed to create tunnel or locate credentials."
    exit 1
fi
TUNNEL_ID=$(basename "$CRED_FILE" .json)

echo "Step 3: Routing DNS..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$SUBDOMAIN"

echo "Step 4: Generating config..."
# Create config.yml
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /Users/$USERNAME/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $SUBDOMAIN
    service: http://localhost:$LOCAL_PORT
  - service: http_status:404
EOF

echo "Step 5: Installing launchd service..."
mkdir -p ~/Library/LaunchAgents
# Source template is com.9router.tunnel.plist; target name is descriptive for launchd
cp com.9router.tunnel.plist ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
sed -i '' "s/<USERNAME>/$USERNAME/g" ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
sed -i '' "s/<TUNNEL_NAME>/$TUNNEL_NAME/g" ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist
sed -i '' "s|/usr/local/bin/cloudflared|$CLOUDFLARED_BIN|g" ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist

launchctl load ~/Library/LaunchAgents/com.local-tunnel.cloudflared.plist

echo ""
echo "✅ Done! Your tunnel is running at: https://$SUBDOMAIN"
echo ""
echo "To check status: cloudflared tunnel info $TUNNEL_NAME"
