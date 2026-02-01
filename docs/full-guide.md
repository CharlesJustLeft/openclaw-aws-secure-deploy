# OpenClaw Secure Deployment Guide for AWS

## Complete Security Hardening: From Fresh Ubuntu to Hardened AI Server

**Estimated Time:** 45-60 minutes  
**Difficulty:** Intermediate  
**Last Updated:** January 2026

> **Note:** This is the detailed manual guide. For automated setup, use the [setup.sh script](../scripts/setup.sh) instead.
> 
> For vulnerability details, see [vulnerabilities.md](vulnerabilities.md).
> For recommended security tools, see [recommended-tools.md](recommended-tools.md).

---

## Table of Contents

1. [Pre-Flight Checklist](#pre-flight-checklist)
2. [Phase 1: AWS Instance Setup](#phase-1-aws-instance-setup)
3. [Phase 2: Basic Server Hardening](#phase-2-basic-server-hardening)
4. [Phase 3: Private Networking with Tailscale](#phase-3-private-networking-with-tailscale)
5. [Phase 4: Installing OpenClaw](#phase-4-installing-openclaw)
6. [Phase 5: Application-Level Security](#phase-5-application-level-security)
7. [Phase 6: Docker Sandbox Setup](#phase-6-docker-sandbox-setup)
8. [Phase 7: Credential Isolation (Advanced)](#phase-7-credential-isolation-advanced)
9. [Phase 8: Verification & Testing](#phase-8-verification--testing)
10. [Phase 9: Ongoing Maintenance](#phase-9-ongoing-maintenance)
11. [Troubleshooting Guide](#troubleshooting-guide)

---

## Pre-Flight Checklist

Before you begin, ensure you have:

- [ ] AWS account with billing alerts configured
- [ ] Tailscale account created (https://tailscale.com - free tier works)
- [ ] Tailscale installed on your local machine (Mac/Windows/Linux)
- [ ] Your messaging platform user ID (Telegram, Discord, Slack, WhatsApp, etc. - see [Getting Your User ID](#getting-your-messaging-platform-user-id) below)
- [ ] API keys ready: Anthropic, OpenAI, or other LLM provider
- [ ] SSH key pair generated on your local machine
- [ ] Notepad ready to record important IPs and tokens

### Getting Your Messaging Platform User ID

OpenClaw supports multiple messaging platforms. Here's how to get your user ID for each:

| Platform | How to Get Your User ID |
|----------|------------------------|
| **Telegram** | Message [@userinfobot](https://t.me/userinfobot) on Telegram - it will reply with your numeric ID |
| **Discord** | Enable Developer Mode (Settings → App Settings → Advanced → Developer Mode), then right-click your username and select "Copy User ID" |
| **Slack** | Click your profile picture → Profile → ⋮ (More) → Copy member ID. Or use the Slack API: your ID starts with `U` (e.g., `U01ABC123`) |
| **WhatsApp** | Your phone number in international format without `+` (e.g., `14155551234` for US number +1-415-555-1234) |
| **Signal** | Your phone number in international format (same as WhatsApp) |
| **iMessage** | Your Apple ID email or phone number associated with iMessage |

**Note:** You can configure multiple user IDs in the `allowFrom` array to support multiple platforms or multiple authorized users:

```json
"allowFrom": ["telegram:123456789", "discord:987654321", "slack:U01ABC123"]
```

### Critical: Understand the Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PUBLIC INTERNET                          │
│                    (Attackers, Scanners, Shodan)                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ❌ BLOCKED by UFW
                              │    (except Tailscale handshake)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS EC2 INSTANCE                           │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   │
│  │   UFW         │    │   Tailscale   │    │   OpenClaw    │   │
│  │   Firewall    │───▶│   (VPN)       │───▶│   Gateway     │   │
│  │               │    │               │    │   :18789      │   │
│  │ Only allows:  │    │ Creates       │    │   localhost   │   │
│  │ - SSH via     │    │ encrypted     │    │   only        │   │
│  │   Tailscale   │    │ tunnel        │    │               │   │
│  │ - Tailscale   │    │               │    │               │   │
│  │   UDP 41641   │    │               │    │               │   │
│  └───────────────┘    └───────────────┘    └───────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ✅ Encrypted Tailscale Tunnel
                              │    (100.x.x.x address space)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR LOCAL MACHINE                          │
│                   (MacBook, Windows PC, etc.)                   │
│                                                                 │
│  Tailscale IP: 100.x.x.x (YOUR machine)                        │
│  Server's Tailscale IP: 100.y.y.y (DIFFERENT - use this!)      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: AWS Instance Setup

### Step 1.1: Launch EC2 Instance

1. Log into AWS Console → EC2 → Launch Instance
2. Configure:
   - **Name:** `openclaw-secure`
   - **AMI:** Ubuntu Server 24.04 LTS (HVM), SSD Volume Type
   - **Instance type:** m7i-flex.large
   - **Key pair:** Select your existing key or create new one
   - **Network settings:** 
     - Create security group
     - Allow SSH from Anywhere initially (we'll lock this down later, otherwise you won't be able to connect to the instance)
   - **Storage:** 30 GB gp3 (minimum)

3. Launch and wait for "Running" status

### Step 1.2: Download Your SSH Key
When you create an EC2 instance, AWS gives you a .pem key file. Save it somewhere accessible (e.g., Desktop or ~/.ssh/).
Fix permissions (SSH requires this):
bashchmod 400 ~/Desktop/"Your Key Name.pem"

### Step 1.3: Connect to Your Instance
bashssh -i ~/Desktop/"Your Key Name.pem" ubuntu@YOUR_AWS_PUBLIC_IP
```

**Notes:**
- Get `YOUR_AWS_PUBLIC_IP` from EC2 Console → Instances → Public IPv4 address
- If your filename has spaces, use quotes around the path
- If you see "Permission denied (publickey)", check the filename is exact and permissions are 400

**Success looks like:**
```
ubuntu@ip-172-31-x-x:~$
You're now on the AWS server. All following commands run there.

### Step 1.4: AWS Billing Protection

**Do this now before you forget:**

1. AWS Console → Billing → Budgets → Create budget
2. Set a monthly budget (e.g., $50)
3. Add alert at 80% threshold
4. Enable MFA on your AWS root account
  AWS Console → Click your account name (top right) → Security credentials
  Scroll to Multi-factor authentication (MFA)
  Click Assign MFA device
  Choose Authenticator app
  Scan the QR code with an authenticator app on your phone:
    Google Authenticator (free)
    Authy (free)
    1Password (if you use it)
  Enter two consecutive codes from the app
  Click Assign MFA

---

## Phase 2: Basic Server Hardening

### Step 2.1: System Update

```bash
# Update package lists and upgrade all packages
sudo apt update && sudo apt upgrade -y

# Install essential security tools
sudo apt install -y ufw fail2ban unattended-upgrades curl wget git

# Enable automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
# Select "Yes" when prompted
```

### Step 2.2: Create Non-Root User (if using root)

```bash
# Skip if you're already using 'ubuntu' user
sudo adduser openclaw
sudo usermod -aG sudo openclaw

# Copy SSH keys to new user
sudo mkdir -p /home/openclaw/.ssh
sudo cp ~/.ssh/authorized_keys /home/openclaw/.ssh/
sudo chown -R openclaw:openclaw /home/openclaw/.ssh
sudo chmod 700 /home/openclaw/.ssh
sudo chmod 600 /home/openclaw/.ssh/authorized_keys
```

### Step 2.3: Lock Down SSH

```bash
# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit SSH configuration
sudo nano /etc/ssh/sshd_config
```

**Use Ctrl+W (search) to find each setting and modify these lines (remove # if commented):**

```
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

**Save and apply:**

```bash
# Test configuration (IMPORTANT - don't skip!)
sudo sshd -t

# If no errors, reload SSH
sudo systemctl reload ssh

# Verify SSH is still working (in a NEW terminal, keep current one open!)
# ssh -i ~/.ssh/your-key.pem ubuntu@YOUR_AWS_PUBLIC_IP
```

⚠️ **CHECKPOINT:** Open a new terminal and verify you can still SSH in before continuing!

### Step 2.4: Configure Firewall (Initial - Public Access)

```bash
# Reset UFW to defaults
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (temporarily from anywhere - we'll restrict this after Tailscale)
sudo ufw allow OpenSSH

# Allow Tailscale UDP (required for Tailscale to work)
sudo ufw allow 41641/udp comment 'Tailscale'

# Enable firewall
sudo ufw --force enable

# Verify status
sudo ufw status verbose
```

**Expected output:**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere
41641/udp                  ALLOW IN    Anywhere
```

### Step 2.5: Enable Brute-Force Protection

```bash
# fail2ban should already be installed
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create local config
sudo nano /etc/fail2ban/jail.local
```

**Add this content:**

```ini
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
```

**Apply configuration:**

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

---

## Phase 3: Private Networking with Tailscale

### ⚠️ CRITICAL: Read This Before Proceeding

This is where people get locked out. Follow these steps **exactly in order**:

1. Install Tailscale
2. Verify Tailscale is connected
3. Test SSH via Tailscale IP (while public SSH still works)
4. **Only then** disable public SSH

### Step 3.1: Install Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale and authenticate
sudo tailscale up

# You'll see a URL - open it in your browser and authenticate
# Example: https://login.tailscale.com/a/abc123xyz
```

### Step 3.2: Verify Tailscale Connection

```bash
# Check Tailscale status
tailscale status

# Get your server's Tailscale IP
tailscale ip -4
```

**Write down your server's Tailscale IP:**
```
SERVER_TAILSCALE_IP="100.x.x.x"  # This is your SERVER's Tailscale IP
```

### Step 3.3: Verify Tailscale on Your Local Machine

**On your Mac/PC (not the server):**

```bash
# Check Tailscale is running
tailscale status

# You should see your server listed:
# 100.x.x.x   openclaw-secure   ubuntu   linux   -
```

### Step 3.4: Test SSH via Tailscale (Critical Step!)

**Keep your current SSH session open.** In a **new terminal** on your local machine:

```bash
# Test SSH using Tailscale IP
ssh -i ~/.ssh/your-key.pem ubuntu@SERVER_TAILSCALE_IP

# Example:
ssh -i ~/.ssh/your-key.pem ubuntu@100.122.251.23
```

✅ **Only proceed if this works!**

### Step 3.5: Restrict SSH to Tailscale Only

**Now that Tailscale SSH is confirmed working:**

```bash
# Allow SSH only from Tailscale network (100.64.0.0/10)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH via Tailscale'

# Remove public SSH access
sudo ufw delete allow OpenSSH

# Verify the change
sudo ufw status numbered
```

**Expected output:**
```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    100.64.0.0/10 (Tailscale)
[ 2] 41641/udp                  ALLOW IN    Anywhere
```

### Step 3.6: Final Tailscale Verification

```bash
# From your LOCAL machine, verify:

# 1. Public IP should NOT work anymore
ssh -i ~/.ssh/your-key.pem ubuntu@YOUR_AWS_PUBLIC_IP
# Expected: Connection timed out or refused

# 2. Tailscale IP should work
ssh -i ~/.ssh/your-key.pem ubuntu@SERVER_TAILSCALE_IP
# Expected: Successful login
```

### Step 3.7: Configure Tailscale to Start on Boot

```bash
sudo systemctl enable tailscaled
```

---

## Phase 4: Installing OpenClaw

### Step 4.1: Install Node.js 22

```bash
# Install Node.js 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version  # Should show v22.x.x
npm --version   # Should show 10.x.x
```

### Step 4.2: Install OpenClaw

```bash
# Install OpenClaw globally
sudo npm install -g openclaw

# Run initial diagnostics
openclaw doctor
```

### Step 4.3: Install Docker (for Sandboxing)

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to docker group (no sudo needed for docker commands)
sudo usermod -aG docker $USER

# Apply group change (or log out and back in)
newgrp docker

# Verify Docker works
docker run hello-world

# Enable Docker on boot
sudo systemctl enable docker
```

### Step 4.4: Initial OpenClaw Setup

```bash
# Run the setup wizard
openclaw onboard

# This will guide you through:
# - Choosing your LLM provider (Anthropic, OpenAI, Moonshot, etc.)
# - Setting your API key
# - Configuring your messaging channel (Discord, Telegram, etc.)
# - Gateway setup (choose "local" for this setup)
# - Optional: shell completion script installation
```

**During the Discord setup, you'll need to:**

1. **Create a Discord Bot** (if you haven't already):
   - Go to https://discord.com/developers/applications
   - Click "New Application" and give it a name
   - Go to "Bot" section → Click "Add Bot"
   - Copy the bot token (you'll paste this during onboard)

2. **Enable Message Content Intent** (REQUIRED):
   - In Discord Developer Portal → Your App → Bot
   - Scroll down to "Privileged Gateway Intents"
   - Enable **"Message Content Intent"**
   - Save changes

3. **Invite the bot to your server**:
   - Go to OAuth2 → URL Generator
   - Select scopes: `bot`, `applications.commands`
   - Select permissions: `Send Messages`, `Read Message History`, `Read Messages/View Channels`
   - Copy the generated URL and open it to invite the bot

**Note:** After onboard completes, run diagnostics:

```bash
openclaw doctor
```

---

## Phase 5: Application-Level Security (Discord)

This phase configures application-level security for your OpenClaw instance with Discord.

**Note:** The `openclaw onboard` wizard already configured many security settings automatically, including:
- Gateway token authentication
- Gateway bound to localhost (127.0.0.1)
- Discord channel allowlist mode

This phase adds the **DM allowlist** to ensure only your Discord user ID can control the bot.

### Step 5.1: Get Your Discord User ID

Before configuring the allowlist, you need your Discord user ID:

1. Open Discord and go to **User Settings** → **Advanced**
2. Enable **Developer Mode**
3. Close settings, then click on your own profile picture
4. Click **"Copy User ID"**
5. Save this number (e.g., `1118908675717877760`)

### Step 5.2: Configure Discord DM Allowlist

The onboarding wizard created `~/.openclaw/openclaw.json`. You need to add the DM allowlist configuration to the Discord channel section.

```bash
# Edit the OpenClaw configuration
nano ~/.openclaw/openclaw.json
```

Find the `"channels"` section (near the bottom of the file). It will look something like this:

```json
"channels": {
  "discord": {
    "enabled": true,
    "token": "YOUR_BOT_TOKEN",
    "groupPolicy": "allowlist",
    "guilds": {}
  }
}
```

**Add the `"dm"` block** inside the `"discord"` object (don't forget the comma after `"guilds": {}`):

```json
"channels": {
  "discord": {
    "enabled": true,
    "token": "YOUR_BOT_TOKEN",
    "groupPolicy": "allowlist",
    "guilds": {},
    "dm": {
      "enabled": true,
      "policy": "allowlist",
      "allowFrom": ["YOUR_DISCORD_USER_ID"]
    }
  }
}
```

**Example with a real user ID:**

```json
"channels": {
  "discord": {
    "enabled": true,
    "token": "MTQ2NzQ2MjUy...",
    "groupPolicy": "allowlist",
    "guilds": {},
    "dm": {
      "enabled": true,
      "policy": "allowlist",
      "allowFrom": ["1118908675717877760"]
    }
  }
}
```

**Save and exit:** `Ctrl+O`, Enter, `Ctrl+X`

### Step 5.3: Verify JSON Syntax

Before restarting, verify the JSON is valid:

```bash
cat ~/.openclaw/openclaw.json | python3 -m json.tool > /dev/null && echo "JSON is valid!"
```

If you see "JSON is valid!", proceed. If you see an error, check for:
- Missing commas between sections
- Missing or extra braces `{` `}`
- Typos in key names

### Step 5.4: Secure File Permissions

```bash
# Secure the main config directory
chmod 700 ~/.openclaw

# Secure the credentials directory
chmod 700 ~/.openclaw/credentials

# Secure the config file
chmod 600 ~/.openclaw/openclaw.json
```

### Step 5.5: Restart and Verify

```bash
# Restart the gateway to apply changes
openclaw gateway restart

# Check status
openclaw status

# Run security audit
openclaw security audit --deep
```

The security audit should show no critical issues related to file permissions.

### What This Configuration Does

| Setting | Protection |
|---------|------------|
| `"dm.policy": "allowlist"` | Only approved Discord users can DM the bot |
| `"dm.allowFrom": ["YOUR_ID"]` | Your Discord user ID is explicitly approved |
| `"groupPolicy": "allowlist"` | Bot ignores messages from unapproved servers/channels |
| File permissions (700/600) | Config files only readable by you |

### Troubleshooting

**Bot not responding after changes:**
1. Check JSON syntax: `cat ~/.openclaw/openclaw.json | python3 -m json.tool`
2. Check gateway status: `openclaw gateway status`
3. Check logs: `openclaw logs --follow`
4. Restart gateway: `openclaw gateway restart`

**"Unrecognized keys" error:**
OpenClaw's config schema may differ from documentation. Run `openclaw doctor --fix` to remove invalid keys, then re-add only the `"dm"` section as shown above.

**JSON syntax errors (missing comma, missing brace):**
Common mistakes when editing JSON:
- Forgetting the comma after `"guilds": {}` when adding the `"dm"` block
- Missing closing braces `}`

Always validate your JSON after editing:
```bash
cat ~/.openclaw/openclaw.json | python3 -m json.tool > /dev/null && echo "JSON is valid!"
```

---

## Phase 6: Docker Sandbox Setup

### Step 6.1: Verify Docker Sandbox

```bash
# Check OpenClaw sandbox status
openclaw sandbox

# OpenClaw manages its sandbox automatically. If you need to manually pull:
docker pull openclaw/sandbox:latest
```

**Note:** The `openclaw sandbox` command (without arguments) shows sandbox status. OpenClaw configures sandbox settings automatically during setup.

### Step 6.2: Configure Docker Network Isolation

```bash
# Create an isolated network for OpenClaw
docker network create --driver bridge --internal openclaw-isolated

# Verify the network has no external access
docker network inspect openclaw-isolated | grep -A5 "Internal"
# Should show: "Internal": true
```

### Step 6.3: Test Sandbox Isolation

```bash
# Test that sandbox has no network access
docker run --rm --network none alpine ping -c 1 8.8.8.8
# Expected: ping: bad address '8.8.8.8' (network unreachable)
```

### Step 6.4: Configure Docker Security (Advanced)

```bash
# Create Docker daemon security configuration
sudo nano /etc/docker/daemon.json
```

**Add:**

```json
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
```

```bash
# Reload systemd and restart Docker to apply
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**Note:** If you see a warning about unit files changed on disk, the `daemon-reload` command resolves it.

---

## Phase 7: Credential Isolation (Advanced)

This section implements the "use but not see" pattern for credentials.

### Option A: Using Composio (Recommended for Gmail/GitHub/Slack)

```bash
# Install Composio CLI
pip install composio

# Or via npm
npm install -g composio-core
```

**Set up brokered authentication:**

1. Go to https://app.composio.dev
2. Create account and get API key
3. Connect your integrations (Gmail, GitHub, etc.) via their OAuth flow
4. Your tokens are stored in Composio's vault, not on your server

```bash
# Add Composio API key to your environment
echo "COMPOSIO_API_KEY=your-composio-key" >> ~/.openclaw/.env
```

**Create a skill that uses Composio:**

```bash
mkdir -p ~/.openclaw/skills/secure-gmail
nano ~/.openclaw/skills/secure-gmail/SKILL.md
```

```yaml
---
name: secure-gmail
description: Read emails using Composio (credentials never touch this server)
metadata:
  openclaw:
    requires:
      env: ["COMPOSIO_API_KEY"]
---

# Secure Gmail Access

This skill uses Composio for brokered authentication.
The agent can READ and DRAFT emails but CANNOT send or delete.

## Usage
- "Check my latest emails"
- "Summarize unread emails"
- "Draft a reply to [person]"
```

### Option B: Using Agent Consent Protocol (ACP)

```bash
# Install ACP
npm install -g agent-2fa

# Initialize ACP
acp init

# Store credentials in ACP vault (encrypted)
acp secret set GITHUB_TOKEN
# (Enter your token when prompted - it's stored encrypted)

# Run OpenClaw through ACP wrapper
acp run --network-isolation -- openclaw gateway
```

### Option C: Local Password Manager Integration (Bitwarden)

```bash
# Install Bitwarden CLI
sudo snap install bw

# Login and unlock
bw login
bw unlock

# Store session key
export BW_SESSION="your-session-key"

# Now OpenClaw skills can use:
# bw get password "anthropic-api-key"
# without the key being in plaintext files
```

---

## Phase 8: Verification & Testing

### Step 8.1: Security Audit

```bash
# Run OpenClaw's built-in security audit
openclaw security audit --deep

# If issues found, auto-fix safe ones:
openclaw security audit --deep --fix
```

### Step 8.2: Manual Security Check

```bash
# Check for open ports exposed to the internet
ss -tulnp | grep LISTEN

# Verify no sensitive ports are bound to 0.0.0.0 (all interfaces)
# OpenClaw gateway should show 127.0.0.1:18789, NOT 0.0.0.0:18789

# Check firewall is active
sudo ufw status verbose
```

### Step 8.3: Verify Gateway Binding

```bash
# Check what ports are listening and WHERE
ss -tulnp | grep 18789

# GOOD output (localhost only):
# tcp  LISTEN  0  128  127.0.0.1:18789  0.0.0.0:*

# BAD output (exposed to network):
# tcp  LISTEN  0  128  0.0.0.0:18789    0.0.0.0:*
```

### Step 8.4: Shodan Verification (Before)

Before your instance is fully locked down, check if it's visible:

```bash
# From your LOCAL machine, check your AWS public IP on Shodan
# Go to: https://www.shodan.io/host/YOUR_AWS_PUBLIC_IP

# Or search for OpenClaw instances:
# https://www.shodan.io/search?query=clawdbot-gw
# https://www.shodan.io/search?query="Clawdbot+Control"
```

### Step 8.5: External Port Scan

```bash
# From a DIFFERENT machine (not your server or local machine)
# Or use an online port scanner like https://www.yougetsignal.com/tools/open-ports/

nmap -Pn YOUR_AWS_PUBLIC_IP

# Expected result after hardening:
# All 1000 scanned ports are filtered
# (or only 41641/udp for Tailscale)
```

### Step 8.6: Verify Tailscale-Only Access

```bash
# Test 1: Public IP should NOT respond to HTTP
curl --connect-timeout 5 http://YOUR_AWS_PUBLIC_IP:18789
# Expected: Connection timed out

# Test 2: Tailscale IP SHOULD respond (with auth required)
curl --connect-timeout 5 http://SERVER_TAILSCALE_IP:18789
# Expected: 401 Unauthorized (auth required) - this is correct!
```

### Step 8.7: Test Discord DM Allowlist

1. **Message your bot** from your approved Discord account → Should respond normally
2. **Have a friend message your bot** (from a different Discord account) → Should show pairing code or be ignored
3. **Check the pairing list:**

```bash
openclaw pairing list discord
```

### Step 8.8: Verify Discord Connection

```bash
# Check Discord channel status
openclaw status

# Look for:
# │ Discord  │ ON      │ OK     │ token config... │
```

If Discord shows "OK", your bot is connected and responding.

---

## Phase 9: Ongoing Maintenance

### Step 9.1: Create Maintenance Script

```bash
nano ~/maintenance.sh
```

```bash
#!/bin/bash
# OpenClaw Security Maintenance Script

echo "=== OpenClaw Security Maintenance ==="
echo "Date: $(date)"
echo ""

# Update system
echo "1. Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Update OpenClaw
echo "2. Updating OpenClaw..."
sudo npm update -g openclaw

# Run security audit
echo "3. Running security audit..."
openclaw security audit --deep

# Check listening ports
echo "4. Checking exposed ports..."
ss -tulnp | grep LISTEN

# Check firewall status
echo "5. Firewall status..."
sudo ufw status verbose

# Check Tailscale status
echo "6. Tailscale status..."
tailscale status

# Check fail2ban
echo "7. Banned IPs..."
sudo fail2ban-client status sshd

# Check disk space
echo "8. Disk usage..."
df -h /

# Check Docker
echo "9. Docker status..."
docker ps -a

echo ""
echo "=== Maintenance Complete ==="
```

```bash
chmod +x ~/maintenance.sh
```

### Step 9.2: Set Up Automated Updates

```bash
# Create a cron job for weekly maintenance
crontab -e
```

**Add:**
```
# Weekly security maintenance (Sundays at 3 AM)
0 3 * * 0 /home/ubuntu/maintenance.sh >> /var/log/openclaw-maintenance.log 2>&1

# Daily security audit
0 4 * * * openclaw security audit --deep >> /var/log/openclaw-audit.log 2>&1
```

### Step 9.3: Set Up Log Monitoring

```bash
# Create a simple log watcher
nano ~/check-security.sh
```

```bash
#!/bin/bash
# Check for security anomalies

# Check for failed SSH attempts
echo "=== Failed SSH Attempts (last 24h) ==="
sudo grep "Failed password" /var/log/auth.log | tail -20

# Check for banned IPs
echo ""
echo "=== Currently Banned IPs ==="
sudo fail2ban-client status sshd

# Check OpenClaw logs for suspicious activity
echo ""
echo "=== Recent OpenClaw Errors ==="
journalctl -u openclaw-gateway --since "24 hours ago" | grep -i error | tail -20
```

```bash
chmod +x ~/check-security.sh
```

### Step 9.4: Credential Rotation Schedule

Set reminders to rotate these regularly:

| Credential | Rotation Frequency | How to Rotate |
|------------|-------------------|---------------|
| Gateway Token | Every 90 days | Regenerate and update ~/.openclaw/.env |
| API Keys | Every 90 days | Generate new key in provider dashboard |
| SSH Keys | Every 365 days | Generate new keypair, update authorized_keys |
| Tailscale | As needed | `tailscale logout` then `tailscale up` |

---

## Troubleshooting Guide

### Problem: Locked Out After Firewall Changes

**Prevention (ALWAYS do this):**
```bash
# Before making firewall changes, set a cron job to disable UFW in 10 minutes
echo "sudo ufw disable" | at now + 10 minutes

# Make your changes
sudo ufw ...

# If everything works, cancel the safety net:
atrm $(atq | head -1 | cut -f1)
```

**Recovery if locked out:**
1. Use AWS EC2 Console → Connect → Session Manager (if configured)
2. Or: Stop instance → Detach volume → Attach to rescue instance → Edit firewall config → Reattach

### Problem: SSH Connection Refused via Tailscale

**Diagnosis:**
```bash
# On your LOCAL machine:
tailscale status
# Verify your server shows as "online"

# Check you're using the SERVER's Tailscale IP, not your own
tailscale ip -4  # This is YOUR IP - don't use this
```

**Common mistakes:**
- Using your own Tailscale IP instead of server's
- Tailscale not connected on local machine
- Firewall blocking before Tailscale was ready

### Problem: OpenClaw Gateway Not Starting

```bash
# Check logs
journalctl -u openclaw-gateway -n 50

# Check if port is already in use
ss -tulnp | grep 18789

# Check config syntax
cat ~/.openclaw/openclaw.json | python3 -m json.tool

# Try manual start with debug
OPENCLAW_LOG_LEVEL=debug openclaw gateway
```

### Problem: Docker Sandbox Fails

```bash
# Check Docker is running
sudo systemctl status docker

# Check user is in docker group
groups | grep docker

# Rebuild sandbox image
openclaw sandbox setup

# Check Docker logs
docker logs $(docker ps -lq)
```

### Problem: Bot Responds to Unknown Users

```bash
# Verify Discord DM allowlist is configured
cat ~/.openclaw/openclaw.json | grep -A10 '"dm"'

# Check pairing approvals
openclaw pairing list discord

# Verify your Discord user ID is in the allowFrom list
# Your ID should appear in the "dm.allowFrom" array

# Restart OpenClaw after config changes
openclaw gateway restart
```

### Problem: Shodan Still Shows My Instance

1. Verify gateway binds to 127.0.0.1 not 0.0.0.0
2. Check UFW is enabled: `sudo ufw status`
3. Wait 24-48 hours for Shodan cache to update
4. Request removal: https://www.shodan.io/contact

---

## Quick Reference Commands

```bash
# Start OpenClaw
openclaw gateway

# Run in background with systemd
sudo systemctl start openclaw-gateway
sudo systemctl enable openclaw-gateway  # Start on boot

# Check status
openclaw status
tailscale status
sudo ufw status

# Security audit
openclaw security audit --deep

# View logs
journalctl -u openclaw-gateway -f

# SSH tunnel for dashboard (from local machine)
ssh -N -L 18789:127.0.0.1:18789 -i ~/.ssh/your-key.pem ubuntu@SERVER_TAILSCALE_IP

# Then access: http://localhost:18789 in your browser
```

---

## Security Checklist Summary

Before going live, verify:

- [ ] SSH only accessible via Tailscale (test from public IP fails)
- [ ] Gateway binds to 127.0.0.1 only (`openclaw status` shows "bind: loopback")
- [ ] UFW shows only Tailscale + SSH rules
- [ ] fail2ban is active
- [ ] Discord DM allowlist configured with your Discord user ID
- [ ] Discord groupPolicy set to "allowlist"
- [ ] File permissions: `~/.openclaw` = 700, `openclaw.json` = 600
- [ ] `openclaw security audit --deep` passes with no critical issues
- [ ] Discord bot responds only to your approved account

---

## What You've Achieved

After completing this guide, your OpenClaw instance has:

| Security Layer | Protection |
|----------------|------------|
| **Network** | Only accessible via encrypted Tailscale VPN |
| **Firewall** | All ports blocked except Tailscale handshake |
| **SSH** | Key-only, no passwords, Tailscale-only, fail2ban protected |
| **Gateway** | Token authentication required, localhost binding |
| **Discord Auth** | DM allowlist restricts bot to your Discord user ID only |
| **Discord Groups** | groupPolicy allowlist ignores unapproved servers |
| **Pairing** | Unknown users receive pairing code, must be approved |
| **Credentials** | Secure file permissions (600/700) |
| **Monitoring** | Command logging enabled, security audits available |

**Your OpenClaw is secured at multiple layers - network, firewall, application, and user authorization.**

---

*Guide version 1.0 - January 2026*
*Based on security research from Cisco, Vectra AI, Snyk, and community contributors*
