#!/bin/bash
# VendorBoss API — Deploy Script
# Called automatically by the GitHub Actions self-hosted runner on every push to main.
# The runner checks out the latest code before this script runs.

set -e

APP_DIR="/home/drakonus/vendorboss-api"
VENV="$APP_DIR/venv"
SERVICE="vendorboss"

echo "🚀 Starting VendorBoss API deployment..."

# ── 1. Sync latest code into app directory ────────────────────────────────────
echo "📂 Syncing code..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='venv' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.env' \
  "$GITHUB_WORKSPACE/vendorboss-api/" "$APP_DIR/"

# ── 2. Install / update dependencies ─────────────────────────────────────────
echo "📦 Installing dependencies..."
source "$VENV/bin/activate"
pip install --quiet -r "$APP_DIR/requirements.txt"

# ── 3. Restart the service ────────────────────────────────────────────────────
echo "🔄 Restarting service..."
sudo -n systemctl restart "$SERVICE"

# Confirm it came back up
sleep 2
sudo -n systemctl is-active --quiet "$SERVICE" \
  && echo "✅ $SERVICE is running" \
  || (echo "❌ $SERVICE failed to start" && sudo -n journalctl -u "$SERVICE" -n 30 --no-pager && exit 1)

echo "✅ Deployment complete."
