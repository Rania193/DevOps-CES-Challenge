#!/bin/bash
# =============================================================================
# Update DuckDNS to point to your AWS ELB
# =============================================================================
# 
# Setup:
#   1. Go to https://www.duckdns.org and create a subdomain
#   2. Copy your token from the DuckDNS dashboard
#   3. Run: ./scripts/update-duckdns.sh <subdomain> <token>
#
# Example:
#   ./scripts/update-duckdns.sh datavisyn-demo xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# =============================================================================

set -e

SUBDOMAIN=$1
TOKEN=$2

if [ -z "$SUBDOMAIN" ] || [ -z "$TOKEN" ]; then
  echo "Usage: $0 <subdomain> <token>"
  echo ""
  echo "Example: $0 datavisyn-demo xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  echo ""
  echo "Get your token from: https://www.duckdns.org"
  exit 1
fi

echo "🔍 Fetching Load Balancer URL..."

# Get the ELB hostname
ELB_HOSTNAME=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ELB_HOSTNAME" ]; then
  echo "❌ Could not find ingress-nginx LoadBalancer."
  exit 1
fi

# DuckDNS needs an IP, but we have a hostname. 
# We'll use CNAME-like behavior by resolving the ELB to an IP
echo "🔍 Resolving ELB hostname to IP..."
ELB_IP=$(dig +short "$ELB_HOSTNAME" | head -1)

if [ -z "$ELB_IP" ]; then
  echo "❌ Could not resolve ELB hostname to IP"
  echo "   ELB hostname: $ELB_HOSTNAME"
  echo "   (The ELB might still be provisioning, try again in a minute)"
  exit 1
fi

echo "📡 Updating DuckDNS..."
RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=${ELB_IP}")

if [ "$RESPONSE" = "OK" ]; then
  echo ""
  echo "✅ DuckDNS updated successfully!"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🌐 Your domain: https://${SUBDOMAIN}.duckdns.org"
  echo "📍 Points to:   ${ELB_IP} (${ELB_HOSTNAME})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📝 NEXT STEPS:"
  echo ""
  echo "1. Update GitHub OAuth App callback URL to:"
  echo "   https://${SUBDOMAIN}.duckdns.org/oauth2/callback"
  echo ""
  echo "2. Update helm-values/oauth2-proxy.yaml:"
  echo "   redirect-url: \"https://${SUBDOMAIN}.duckdns.org/oauth2/callback\""
  echo "   cookie-secure: \"true\""
  echo ""
  echo "⚠️  Note: AWS NLB IPs can change. If your domain stops working,"
  echo "    just run this script again to update the IP."
else
  echo "❌ DuckDNS update failed. Response: $RESPONSE"
  echo "   Check your token and subdomain name."
  exit 1
fi

