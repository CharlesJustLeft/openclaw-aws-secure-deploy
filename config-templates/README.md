# Configuration Templates

These templates provide secure configurations for various components. The `setup.sh` script applies most of these automatically, but you can use them for manual configuration or reference.

## Files

| File | Purpose | Destination |
|------|---------|-------------|
| `docker-daemon.json` | Secure Docker configuration | `/etc/docker/daemon.json` |
| `fail2ban-jail.local` | Brute-force protection | `/etc/fail2ban/jail.local` |
| `sshd_config.secure` | Hardened SSH settings | `/etc/ssh/sshd_config` |
| `dm-allowlist-discord.json` | Discord DM allowlist template | `~/.openclaw/openclaw.json` |

## Usage

### Docker Configuration

```bash
sudo cp docker-daemon.json /etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### fail2ban Configuration

```bash
sudo cp fail2ban-jail.local /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

### SSH Configuration

```bash
# IMPORTANT: Keep your current SSH session open!
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo nano /etc/ssh/sshd_config  # Apply settings from sshd_config.secure
sudo sshd -t  # Test configuration
sudo systemctl reload ssh
# Test connection in a NEW terminal before closing this one!
```

### Discord DM Allowlist

1. Get your Discord User ID:
   - Open Discord Settings → Advanced → Enable Developer Mode
   - Right-click your username → Copy User ID

2. Edit OpenClaw config:
   ```bash
   nano ~/.openclaw/openclaw.json
   ```

3. Add the `dm` block from `dm-allowlist-discord.json` inside `channels.discord`

4. Restart:
   ```bash
   openclaw gateway restart
   ```
