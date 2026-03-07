#!/bin/bash
# =============================================================================
# OpenClaw VPS Complete Setup
# Master script that runs harden.sh + install-openclaw.sh in sequence.
#
# This is the ONE-COMMAND setup for a fresh Ubuntu 24.04 VPS provisioned
# with cloud-init. It automates sections 3, 4, and 5 of the hardening guide.
#
# Prerequisites:
#   - Fresh Ubuntu 24.04 VPS with cloud-init applied
#   - Password changed (sudo passwd openclaw)
#   - Tailscale ACLs configured in admin panel
#   - Hetzner Cloud Firewall with port 22 open (temporary)
#
# Usage:
#   ssh openclaw@<PUBLIC_IP>
#   curl -fsSL -o /tmp/setup.sh \
#     https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/setup.sh
#   less /tmp/setup.sh
#   bash /tmp/setup.sh
#
# After completion:
#   1. Connect via Tailscale: ssh openclaw@<TAILSCALE_IP>
#   2. Remove SSH rule from Hetzner Cloud Firewall
#   3. Disable key expiry in Tailscale admin
#   4. Configure API key: openclaw models auth add
#   5. Start OpenClaw: sudo systemctl start openclaw
# =============================================================================

set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "========================================================"
echo "  OpenClaw VPS Complete Setup"
echo "  Sections 3 + 4 + 5"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"
echo ""

# --- Phase 1: Hardening (requires root) ---
info "=== PHASE 1: System Hardening (sections 3-4) ==="
info "This phase requires sudo and will:"
info "  - Harden SSH (CIS Benchmark)"
info "  - Configure auditd, sysctl, AIDE"
info "  - Install Tailscale and close public SSH"
echo ""
info "Downloading harden.sh..."
curl -fsSL -o /tmp/harden.sh "${REPO_BASE}/scripts/harden.sh"
sudo bash /tmp/harden.sh
rm -f /tmp/harden.sh

echo ""
info "Phase 1 complete. You should now be on Tailscale."
echo ""

# --- Phase 2: OpenClaw Installation (as user) ---
info "=== PHASE 2: OpenClaw Installation (section 5) ==="
info "Downloading install-openclaw.sh..."
curl -fsSL -o /tmp/install-openclaw.sh "${REPO_BASE}/scripts/install-openclaw.sh"
bash /tmp/install-openclaw.sh
rm -f /tmp/install-openclaw.sh

echo ""
info "=== SETUP COMPLETE ==="
echo ""
echo "========================================================"
echo "  ALL DONE - Manual steps remaining:"
echo "========================================================"
echo ""
echo "  1. From your Mac:"
echo "     ssh openclaw@<TAILSCALE_IP>"
echo ""
echo "  2. In Hetzner Cloud panel:"
echo "     Remove inbound SSH rule (port 22) from Cloud Firewall"
echo ""
echo "  3. In Tailscale admin (login.tailscale.com/admin/machines):"
echo "     Disable key expiry for the VPS"
echo ""
echo "  4. Configure your LLM API key:"
echo "     openclaw models auth add"
echo ""
echo "  5. Start OpenClaw:"
echo "     sudo systemctl start openclaw"
echo ""
echo "  6. Verify everything:"
echo "     curl -fsSL ${REPO_BASE}/scripts/verify-hardening.sh | sudo bash"
echo ""
echo "========================================================"
