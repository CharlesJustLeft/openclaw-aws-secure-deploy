# Backup & Recovery Guide

Regular backups ensure you can recover from failures, compromises, or accidental data loss.

## What to Back Up

### Critical (Must Backup)

| Path | Contains | Recovery Impact |
|------|----------|-----------------|
| `~/.openclaw/openclaw.json` | Main configuration | Bot won't start without it |
| `~/.openclaw/agents/` | Agent configurations, sessions | Lose conversation history |
| `~/.openclaw/credentials/` | Pairing data, allowlists | Lose approved users |

### Optional (Recommended)

| Path | Contains | Recovery Impact |
|------|----------|-----------------|
| `~/.openclaw/skills/` | Custom skills | Lose custom functionality |
| `/etc/ssh/sshd_config` | SSH configuration | Need to re-harden |
| `/etc/fail2ban/jail.local` | fail2ban config | Need to reconfigure |

### Do NOT Backup (Regenerate Instead)

- API keys (rotate, don't backup)
- Gateway tokens (regenerate)
- Tailscale configuration (re-authenticate)

## Backup Methods

### Method 1: Simple Archive (Manual)

```bash
#!/bin/bash
# backup-openclaw.sh

BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/openclaw_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Create encrypted backup
tar -czf - \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/agents/ \
  ~/.openclaw/credentials/ \
  ~/.openclaw/skills/ \
  /etc/ssh/sshd_config \
  /etc/fail2ban/jail.local \
  2>/dev/null | \
  gpg --symmetric --cipher-algo AES256 -o "$BACKUP_FILE.gpg"

echo "Backup created: $BACKUP_FILE.gpg"

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/openclaw_backup_*.tar.gz.gpg | tail -n +8 | xargs -r rm
```

### Method 2: AWS S3 Backup

```bash
#!/bin/bash
# backup-to-s3.sh

BUCKET="your-backup-bucket"
DATE=$(date +%Y%m%d)

# Create archive
tar -czf /tmp/openclaw_backup.tar.gz \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/agents/ \
  ~/.openclaw/credentials/

# Encrypt and upload
gpg --symmetric --cipher-algo AES256 \
  -o /tmp/openclaw_backup.tar.gz.gpg \
  /tmp/openclaw_backup.tar.gz

aws s3 cp /tmp/openclaw_backup.tar.gz.gpg \
  "s3://$BUCKET/openclaw/backup_$DATE.tar.gz.gpg"

# Cleanup
rm /tmp/openclaw_backup.tar.gz*

echo "Backup uploaded to s3://$BUCKET/openclaw/backup_$DATE.tar.gz.gpg"
```

### Method 3: Automated Daily Backup (Cron)

Add to crontab:
```bash
# Daily backup at 2 AM
0 2 * * * /home/ubuntu/backup-openclaw.sh >> /var/log/openclaw-backup.log 2>&1
```

## Recovery Procedures

### Scenario 1: Configuration Corrupted

```bash
# Restore from backup
gpg -d ~/backups/openclaw_backup_YYYYMMDD.tar.gz.gpg | tar -xzf -

# Restart
openclaw gateway restart
```

### Scenario 2: Full Server Recovery

1. **Launch new EC2 instance** using Terraform
2. **Run setup script** up to Phase 4
3. **Restore backup:**
   ```bash
   gpg -d backup_file.tar.gz.gpg | tar -xzf -
   ```
4. **Complete setup:**
   ```bash
   ./setup.sh
   ```
5. **Verify:**
   ```bash
   openclaw status
   openclaw security audit --deep
   ```

### Scenario 3: Compromise Recovery

If you suspect a compromise:

1. **Isolate immediately:**
   ```bash
   sudo ufw default deny incoming
   sudo ufw default deny outgoing
   ```

2. **Preserve evidence:**
   ```bash
   # Copy logs before they rotate
   sudo cp /var/log/auth.log ~/evidence/
   journalctl -u openclaw-gateway > ~/evidence/openclaw.log
   ```

3. **Rotate ALL credentials** (see [secrets-rotation.md](secrets-rotation.md))

4. **Fresh install recommended:**
   - Launch new instance
   - Restore only configuration (not binaries)
   - Re-verify all settings

## Testing Backups

Regularly test your backup restoration:

```bash
# Create test directory
mkdir /tmp/backup-test
cd /tmp/backup-test

# Restore backup
gpg -d ~/backups/latest_backup.tar.gz.gpg | tar -xzf -

# Verify contents
ls -la
cat .openclaw/openclaw.json | python3 -m json.tool > /dev/null && echo "Config valid"

# Cleanup
rm -rf /tmp/backup-test
```

## Backup Checklist

- [ ] Backup script created and tested
- [ ] Encryption password stored securely (NOT on the server)
- [ ] Automated backups scheduled (cron)
- [ ] Off-server backup location configured (S3, etc.)
- [ ] Recovery procedure documented and tested
- [ ] Old backups cleaned up automatically
