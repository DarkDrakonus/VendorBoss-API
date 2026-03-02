#!/bin/bash
# VendorBoss API — Runner Setup
# Run this ONCE on the server to install the GitHub Actions self-hosted runner.
# Everything else (PostgreSQL, Nginx, the service) is already configured.
#
# Usage on server:
#   bash /home/drakonus/vendorboss-api/scripts/runner_setup.sh

set -e

echo "============================================="
echo " VendorBoss — GitHub Actions Runner Setup"
echo "============================================="
echo ""

# ── 1. Allow runner to restart the service without a password prompt ──────────
echo "🔐 Configuring sudoers..."
SUDOERS_LINE="drakonus ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vendorboss-api, /usr/bin/systemctl is-active vendorboss-api, /usr/bin/journalctl -u vendorboss-api *"

if ! sudo grep -qF "vendorboss-api" /etc/sudoers.d/vendorboss 2>/dev/null; then
    echo "$SUDOERS_LINE" | sudo tee /etc/sudoers.d/vendorboss > /dev/null
    sudo chmod 0440 /etc/sudoers.d/vendorboss
    echo "   ✅ Sudoers configured"
else
    echo "   Already configured — skipping"
fi

# ── 2. Runner install instructions ───────────────────────────────────────────
echo ""
echo "============================================="
echo " Now install the GitHub Actions runner:"
echo "============================================="
echo ""
echo "1. Go to your GitHub repo in a browser"
echo "2. Click: Settings → Actions → Runners → New self-hosted runner"
echo "3. Select: Linux, x64"
echo "4. Copy and run each command GitHub shows you in your home directory"
echo ""
echo "   When prompted for:"
echo "   - Runner group: just press Enter"
echo "   - Runner name: press Enter (or type 'dwtest')"
echo "   - Labels: press Enter"
echo "   - Work folder: press Enter"
echo ""
echo "5. Install as a background service (run after the config step):"
echo "   sudo ./svc.sh install"
echo "   sudo ./svc.sh start"
echo ""
echo "6. Verify the runner is online:"
echo "   sudo ./svc.sh status"
echo ""
echo "Then push any change to vendorboss-api/ on main and watch it deploy!"
echo ""
echo "Monitor deployments:  journalctl -u vendorboss-api -f"
echo "Check runner logs:    sudo ./svc.sh status"
echo ""
