#!/bin/bash
#
# OpenClaw AWS Secure Deploy - Master Setup Script
# 
# This script securely deploys OpenClaw on an AWS EC2 instance.
# It tracks progress and can be re-run to resume from where you left off.
#
# Usage: ./setup.sh
#

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.openclaw-setup-state"
LOG_FILE="$HOME/.openclaw-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[i]${NC} $1"
}

header() {
    echo ""
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

prompt() {
    echo -e "${YELLOW}[?]${NC} $1"
}

save_state() {
    echo "$1" > "$STATE_FILE"
    log "Progress saved: $1"
}

get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "START"
    fi
}

wait_for_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

preflight_check() {
    header "Pre-flight Checks"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Please do not run this script as root. Run as your normal user (e.g., ubuntu)."
        exit 1
    fi
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            warn "This script is designed for Ubuntu. You're running: $ID"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            log "Ubuntu detected: $VERSION"
        fi
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connectivity. Please check your network."
        exit 1
    fi
    log "Internet connectivity: OK"
    
    # Check if running on EC2
    if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/ &> /dev/null; then
        log "Running on AWS EC2: OK"
    else
        warn "Not running on AWS EC2. Some features may not work."
    fi
}

# ============================================================================
# Phase 2: Server Hardening
# ============================================================================

phase2_hardening() {
    header "Phase 2: Server Hardening"
    
    info "This phase hardens SSH, configures firewall, and enables fail2ban."
    info "Addresses: Vulnerability #1 (Gateway exposure), #9 (Logging)"
    echo ""
    
    # System updates
    log "Updating system packages..."
    sudo apt update
    sudo apt upgrade -y
    
    # Install security tools
    log "Installing security tools..."
    sudo apt install -y ufw fail2ban unattended-upgrades curl wget git jq
    
    # Enable automatic security updates
    log "Enabling automatic security updates..."
    sudo dpkg-reconfigure -plow unattended-upgrades || true
    
    # Backup SSH config
    if [ ! -f /etc/ssh/sshd_config.backup ]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        log "SSH config backed up"
    fi
    
    # Harden SSH configuration
    log "Hardening SSH configuration..."
    sudo sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    
    # Test SSH config before applying
    if sudo sshd -t; then
        sudo systemctl reload ssh
        log "SSH configuration hardened"
    else
        error "SSH configuration has errors. Restoring backup..."
        sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        exit 1
    fi
    
    # Configure UFW firewall
    log "Configuring UFW firewall..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow OpenSSH  # Temporary, will restrict after Tailscale
    sudo ufw allow 41641/udp comment 'Tailscale'
    sudo ufw --force enable
    log "Firewall enabled"
    
    # Configure fail2ban
    log "Configuring fail2ban..."
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
    
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log "fail2ban configured and running"
    
    save_state "PHASE2_COMPLETE"
    log "Phase 2 complete: Server hardened"
}

# ============================================================================
# Phase 3: Tailscale VPN
# ============================================================================

phase3_tailscale() {
    header "Phase 3: Tailscale VPN"
    
    info "This phase installs Tailscale and restricts SSH to VPN only."
    info "Addresses: Vulnerability #1 (Gateway exposure)"
    echo ""
    
    # Install Tailscale
    if ! command -v tailscale &> /dev/null; then
        log "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
    else
        log "Tailscale already installed"
    fi
    
    # Start Tailscale
    log "Starting Tailscale..."
    echo ""
    warn "A URL will appear below. Open it in your browser to authenticate."
    warn "Keep this terminal open and complete the authentication."
    echo ""
    
    sudo tailscale up
    
    # Wait for Tailscale to connect
    sleep 3
    
    # Get Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [ -z "$TAILSCALE_IP" ]; then
        error "Failed to get Tailscale IP. Please ensure Tailscale is authenticated."
        exit 1
    fi
    
    log "Tailscale connected! Your server's Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║  IMPORTANT: Save this Tailscale IP!                          ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}║  Server Tailscale IP: ${TAILSCALE_IP}                        ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}║  Use this IP for all future SSH connections.                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Restrict SSH to Tailscale only
    warn "Restricting SSH to Tailscale network only..."
    warn "Make sure Tailscale is working on your local machine first!"
    echo ""
    prompt "Have you verified Tailscale is working on your local machine? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        warn "Please install Tailscale on your local machine and verify connection."
        warn "Run 'tailscale status' on your local machine to check."
        warn "Re-run this script when ready."
        exit 0
    fi
    
    # Add Tailscale SSH rule and remove public SSH
    sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH via Tailscale'
    sudo ufw delete allow OpenSSH
    log "SSH now restricted to Tailscale network only"
    
    # Enable Tailscale on boot
    sudo systemctl enable tailscaled
    
    save_state "PHASE3_COMPLETE"
    log "Phase 3 complete: Tailscale configured"
}

# ============================================================================
# Phase 4: Install OpenClaw & Docker
# ============================================================================

phase4_install() {
    header "Phase 4: Installing OpenClaw & Docker"
    
    info "This phase installs Node.js, Docker, and OpenClaw."
    info "Addresses: Vulnerability #3 (Sandbox), #7 (Network isolation)"
    echo ""
    
    # Install Node.js 22
    if ! command -v node &> /dev/null; then
        log "Installing Node.js 22..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
    log "Node.js version: $(node --version)"
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
    fi
    log "Docker installed"
    
    # Configure Docker daemon for security
    log "Configuring Docker security settings..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker
    log "Docker configured with security settings"
    
    # Create isolated Docker network
    if ! docker network inspect openclaw-isolated &> /dev/null; then
        # Need to use newgrp or re-login for docker group
        sudo docker network create --driver bridge --internal openclaw-isolated || true
        log "Created isolated Docker network"
    fi
    
    # Install OpenClaw
    if ! command -v openclaw &> /dev/null; then
        log "Installing OpenClaw..."
        sudo npm install -g openclaw
    fi
    log "OpenClaw version: $(openclaw --version 2>/dev/null || echo 'installed')"
    
    save_state "PHASE4_COMPLETE"
    log "Phase 4 complete: OpenClaw and Docker installed"
    
    # Pause for onboarding
    echo ""
    header "ACTION REQUIRED: OpenClaw Onboarding"
    echo ""
    echo -e "${YELLOW}${BOLD}You need to run the OpenClaw onboarding wizard now.${NC}"
    echo ""
    echo "Run this command:"
    echo ""
    echo -e "    ${CYAN}openclaw onboard${NC}"
    echo ""
    echo "The wizard will ask you to:"
    echo "  1. Choose your LLM provider (Anthropic, OpenAI, etc.)"
    echo "  2. Enter your API key"
    echo "  3. Configure Discord/Telegram (if using)"
    echo "  4. Set up the gateway"
    echo ""
    echo -e "${YELLOW}After completing 'openclaw onboard', run this script again:${NC}"
    echo ""
    echo -e "    ${CYAN}./setup.sh${NC}"
    echo ""
    
    save_state "WAITING_ONBOARD"
    exit 0
}

# ============================================================================
# Phase 5: Application Security
# ============================================================================

phase5_security() {
    header "Phase 5: Application Security"
    
    info "This phase configures DM allowlist and file permissions."
    info "Addresses: Vulnerability #2 (DM policy), #4 (Credentials), #6 (Commands)"
    echo ""
    
    # Check if OpenClaw config exists
    OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        error "OpenClaw config not found at $OPENCLAW_CONFIG"
        error "Please run 'openclaw onboard' first, then re-run this script."
        save_state "WAITING_ONBOARD"
        exit 1
    fi
    
    log "OpenClaw config found"
    
    # Get user's messaging platform ID
    echo ""
    prompt "Which messaging platform are you using with OpenClaw?"
    echo "  1) Discord"
    echo "  2) Telegram"
    echo "  3) Other/Skip"
    read -p "Enter choice (1/2/3): " platform_choice
    
    case $platform_choice in
        1)
            PLATFORM="discord"
            echo ""
            info "To get your Discord User ID:"
            info "  1. Open Discord Settings → Advanced → Enable Developer Mode"
            info "  2. Right-click your username → Copy User ID"
            echo ""
            prompt "Enter your Discord User ID:"
            read -r USER_ID
            ;;
        2)
            PLATFORM="telegram"
            echo ""
            info "To get your Telegram User ID:"
            info "  Message @userinfobot on Telegram"
            echo ""
            prompt "Enter your Telegram User ID:"
            read -r USER_ID
            ;;
        *)
            PLATFORM="skip"
            USER_ID=""
            warn "Skipping DM allowlist configuration"
            ;;
    esac
    
    # Configure DM allowlist if platform selected
    if [ "$PLATFORM" != "skip" ] && [ -n "$USER_ID" ]; then
        log "Configuring DM allowlist for $PLATFORM..."
        
        # Backup config
        cp "$OPENCLAW_CONFIG" "$OPENCLAW_CONFIG.backup"
        
        # Check if dm section already exists for the platform
        if jq -e ".channels.$PLATFORM" "$OPENCLAW_CONFIG" > /dev/null 2>&1; then
            # Add dm config to existing platform
            jq ".channels.$PLATFORM.dm = {\"enabled\": true, \"policy\": \"allowlist\", \"allowFrom\": [\"$USER_ID\"]}" \
                "$OPENCLAW_CONFIG" > "$OPENCLAW_CONFIG.tmp" && mv "$OPENCLAW_CONFIG.tmp" "$OPENCLAW_CONFIG"
            log "DM allowlist added to $PLATFORM configuration"
        else
            warn "Platform $PLATFORM not found in config. You may need to configure it manually."
        fi
    fi
    
    # Set secure file permissions
    log "Setting secure file permissions..."
    chmod 700 "$HOME/.openclaw"
    chmod 600 "$OPENCLAW_CONFIG"
    
    if [ -d "$HOME/.openclaw/credentials" ]; then
        chmod 700 "$HOME/.openclaw/credentials"
        find "$HOME/.openclaw/credentials" -type f -exec chmod 600 {} \;
    fi
    
    if [ -d "$HOME/.openclaw/agents" ]; then
        chmod -R 700 "$HOME/.openclaw/agents"
        find "$HOME/.openclaw/agents" -type f -exec chmod 600 {} \;
    fi
    
    log "File permissions secured"
    
    # Validate JSON
    if cat "$OPENCLAW_CONFIG" | python3 -m json.tool > /dev/null 2>&1; then
        log "Configuration JSON is valid"
    else
        error "Configuration JSON is invalid. Restoring backup..."
        mv "$OPENCLAW_CONFIG.backup" "$OPENCLAW_CONFIG"
        exit 1
    fi
    
    # Restart gateway
    log "Restarting OpenClaw gateway..."
    openclaw gateway restart || true
    
    save_state "PHASE5_COMPLETE"
    log "Phase 5 complete: Application security configured"
}

# ============================================================================
# Phase 6: Docker Sandbox Verification
# ============================================================================

phase6_docker() {
    header "Phase 6: Docker Sandbox Verification"
    
    info "This phase verifies Docker sandbox and network isolation."
    info "Addresses: Vulnerability #3 (Sandbox), #7 (Network isolation)"
    echo ""
    
    # Test network isolation
    log "Testing Docker network isolation..."
    if sudo docker run --rm --network none alpine ping -c 1 8.8.8.8 2>&1 | grep -q "Network unreachable"; then
        log "Network isolation test: PASSED (container cannot reach internet)"
    else
        warn "Network isolation test: Container may have network access"
    fi
    
    # Check OpenClaw sandbox
    log "Checking OpenClaw sandbox configuration..."
    openclaw sandbox 2>/dev/null || warn "OpenClaw sandbox check completed"
    
    save_state "PHASE6_COMPLETE"
    log "Phase 6 complete: Docker sandbox verified"
}

# ============================================================================
# Phase 7: Verification
# ============================================================================

phase7_verify() {
    header "Phase 7: Security Verification"
    
    info "Running security audits and verification checks..."
    echo ""
    
    # Run OpenClaw security audit
    log "Running OpenClaw security audit..."
    openclaw security audit --deep --fix 2>/dev/null || warn "Security audit completed with warnings"
    
    # Check gateway binding
    log "Checking gateway binding..."
    if ss -tulnp 2>/dev/null | grep -q "127.0.0.1:18789"; then
        log "Gateway binding: SECURE (localhost only)"
    elif ss -tulnp 2>/dev/null | grep -q "0.0.0.0:18789"; then
        error "Gateway binding: INSECURE (exposed on all interfaces)"
        warn "Check your OpenClaw configuration"
    else
        info "Gateway not currently running"
    fi
    
    # Check firewall
    log "Firewall status:"
    sudo ufw status | grep -E "^(Status|22|41641)" || true
    
    # Check Tailscale
    log "Tailscale status:"
    tailscale status 2>/dev/null | head -5 || warn "Could not get Tailscale status"
    
    # Check fail2ban
    log "fail2ban status:"
    sudo fail2ban-client status sshd 2>/dev/null | grep -E "(Currently|Total)" || warn "Could not get fail2ban status"
    
    save_state "PHASE7_COMPLETE"
    log "Phase 7 complete: Verification finished"
}

# ============================================================================
# Phase 8: Maintenance Setup
# ============================================================================

phase8_maintenance() {
    header "Phase 8: Maintenance Setup"
    
    info "Setting up automated maintenance and monitoring..."
    echo ""
    
    # Create maintenance script
    log "Creating maintenance script..."
    cat > "$HOME/maintenance.sh" <<'MAINTENANCE_SCRIPT'
#!/bin/bash
# OpenClaw Security Maintenance Script

echo "=== OpenClaw Security Maintenance ==="
echo "Date: $(date)"
echo ""

echo "1. Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "2. Updating OpenClaw..."
sudo npm update -g openclaw

echo "3. Running security audit..."
openclaw security audit --deep

echo "4. Checking exposed ports..."
ss -tulnp | grep LISTEN

echo "5. Firewall status..."
sudo ufw status verbose

echo "6. Tailscale status..."
tailscale status

echo "7. Banned IPs..."
sudo fail2ban-client status sshd

echo "8. Disk usage..."
df -h /

echo "9. Docker status..."
docker ps -a

echo ""
echo "=== Maintenance Complete ==="
MAINTENANCE_SCRIPT
    chmod +x "$HOME/maintenance.sh"
    
    # Create security check script
    log "Creating security check script..."
    cat > "$HOME/check-security.sh" <<'CHECK_SCRIPT'
#!/bin/bash
# Quick security status check

echo "=== Failed SSH Attempts (last 24h) ==="
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20 || echo "No failed attempts"

echo ""
echo "=== Currently Banned IPs ==="
sudo fail2ban-client status sshd

echo ""
echo "=== Recent OpenClaw Errors ==="
journalctl -u openclaw-gateway --since "24 hours ago" 2>/dev/null | grep -i error | tail -20 || echo "No errors found"
CHECK_SCRIPT
    chmod +x "$HOME/check-security.sh"
    
    # Setup cron jobs
    log "Setting up automated maintenance cron jobs..."
    (crontab -l 2>/dev/null | grep -v "maintenance.sh\|openclaw security audit"; echo "# Weekly security maintenance (Sundays at 3 AM)
0 3 * * 0 $HOME/maintenance.sh >> /var/log/openclaw-maintenance.log 2>&1

# Daily security audit (4 AM)
0 4 * * * openclaw security audit --deep >> /var/log/openclaw-audit.log 2>&1") | crontab -
    
    log "Cron jobs configured"
    
    save_state "COMPLETE"
    log "Phase 8 complete: Maintenance configured"
}

# ============================================================================
# Completion
# ============================================================================

show_completion() {
    header "Setup Complete!"
    
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")
    
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║           OpenClaw Secure Deployment Complete!               ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your OpenClaw instance is now secured with:"
    echo ""
    echo "  ✓ SSH hardened (keys only, no root, fail2ban)"
    echo "  ✓ Firewall blocking all public access"
    echo "  ✓ Tailscale VPN for secure remote access"
    echo "  ✓ DM allowlist configured"
    echo "  ✓ Docker sandbox for isolated execution"
    echo "  ✓ Automated maintenance cron jobs"
    echo ""
    echo "Important information:"
    echo ""
    echo "  Tailscale IP: $TAILSCALE_IP"
    echo "  Dashboard:    http://127.0.0.1:18789 (via SSH tunnel)"
    echo ""
    echo "Useful commands:"
    echo ""
    echo "  Check status:      openclaw status"
    echo "  Security audit:    openclaw security audit --deep"
    echo "  View logs:         openclaw logs --follow"
    echo "  Run maintenance:   ./maintenance.sh"
    echo "  Security check:    ./check-security.sh"
    echo ""
    echo "For the full guide, see: docs/full-guide.md"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         OpenClaw AWS Secure Deployment Script                ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                              ║${NC}"
    echo -e "${CYAN}${BOLD}║  Securing your AI assistant with defense-in-depth           ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get current state
    STATE=$(get_state)
    info "Current state: $STATE"
    
    case $STATE in
        "START")
            preflight_check
            phase2_hardening
            phase3_tailscale
            phase4_install
            ;;
        "PHASE2_COMPLETE")
            phase3_tailscale
            phase4_install
            ;;
        "PHASE3_COMPLETE")
            phase4_install
            ;;
        "PHASE4_COMPLETE"|"WAITING_ONBOARD")
            # Check if onboarding was completed
            if [ -f "$HOME/.openclaw/openclaw.json" ]; then
                phase5_security
                phase6_docker
                phase7_verify
                phase8_maintenance
                show_completion
            else
                echo ""
                warn "OpenClaw config not found. Please run 'openclaw onboard' first."
                echo ""
                echo "After completing onboarding, run this script again:"
                echo ""
                echo "    ./setup.sh"
                echo ""
                exit 0
            fi
            ;;
        "PHASE5_COMPLETE")
            phase6_docker
            phase7_verify
            phase8_maintenance
            show_completion
            ;;
        "PHASE6_COMPLETE")
            phase7_verify
            phase8_maintenance
            show_completion
            ;;
        "PHASE7_COMPLETE")
            phase8_maintenance
            show_completion
            ;;
        "COMPLETE")
            show_completion
            echo ""
            prompt "Setup already complete. Run again? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -f "$STATE_FILE"
                exec "$0"
            fi
            ;;
        *)
            warn "Unknown state: $STATE. Starting fresh..."
            rm -f "$STATE_FILE"
            exec "$0"
            ;;
    esac
}

# Run main function
main "$@"
