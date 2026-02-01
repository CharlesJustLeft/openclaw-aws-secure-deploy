# Monitoring & Alerting Guide

Proactive monitoring helps detect issues before they become critical.

## What to Monitor

### Critical Metrics

| Metric | Why | Alert Threshold |
|--------|-----|-----------------|
| Gateway status | Bot availability | Any downtime |
| Failed SSH attempts | Brute-force attacks | >10 in 5 minutes |
| Disk usage | System stability | >80% |
| Memory usage | Performance | >90% |
| Unauthorized DM attempts | Security breach | Any occurrence |

### Informational Metrics

- API usage/costs
- Response latency
- Session count
- Command execution count

## Built-in Monitoring

### OpenClaw Status

```bash
# Quick status check
openclaw status

# Detailed health check
openclaw health

# Continuous log monitoring
openclaw logs --follow
```

### Security Audit

```bash
# Run security audit
openclaw security audit --deep

# Auto-fix issues
openclaw security audit --deep --fix
```

### Our check-security.sh Script

```bash
./check-security.sh
```

This shows:
- Failed SSH attempts (last 24h)
- Currently banned IPs
- Recent OpenClaw errors

## External Monitoring

### Option 1: AWS CloudWatch (Recommended for AWS)

1. **Install CloudWatch Agent:**
   ```bash
   sudo apt install amazon-cloudwatch-agent
   ```

2. **Configure agent:**
   ```bash
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
   ```

3. **Monitor these logs:**
   - `/var/log/auth.log` (SSH attempts)
   - `/var/log/fail2ban.log` (banned IPs)
   - OpenClaw logs via journald

4. **Create alarms for:**
   - High CPU/Memory
   - Disk usage >80%
   - Multiple failed SSH attempts

### Option 2: Simple Uptime Monitoring

Use free services like:
- [UptimeRobot](https://uptimerobot.com)
- [Healthchecks.io](https://healthchecks.io)

**Heartbeat monitoring:**

```bash
# Add to crontab for heartbeat
*/5 * * * * curl -fsS -m 10 --retry 5 https://hc-ping.com/YOUR-UUID-HERE > /dev/null
```

### Option 3: Telegram/Discord Alerts

Create a simple alert script:

```bash
#!/bin/bash
# alert.sh - Send alert to Discord webhook

WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK"

send_alert() {
    local message="$1"
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"🚨 OpenClaw Alert: $message\"}" \
         "$WEBHOOK_URL"
}

# Check if gateway is running
if ! pgrep -f "openclaw" > /dev/null; then
    send_alert "Gateway is DOWN!"
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 80 ]; then
    send_alert "Disk usage at ${DISK_USAGE}%"
fi

# Check for banned IPs
BANNED=$(sudo fail2ban-client status sshd | grep "Currently banned" | awk '{print $4}')
if [ "$BANNED" -gt 0 ]; then
    send_alert "$BANNED IPs currently banned by fail2ban"
fi
```

Add to crontab:
```bash
*/15 * * * * /home/ubuntu/alert.sh
```

## Log Analysis

### Failed Authentication

```bash
# SSH failures
sudo grep "Failed password" /var/log/auth.log | tail -20

# fail2ban bans
sudo grep "Ban" /var/log/fail2ban.log | tail -20
```

### OpenClaw Activity

```bash
# Recent gateway activity
journalctl -u openclaw-gateway --since "1 hour ago"

# Errors only
journalctl -u openclaw-gateway --since "24 hours ago" | grep -i error
```

### UFW Blocked Traffic

```bash
# Recent blocks
sudo grep "UFW BLOCK" /var/log/syslog | tail -20
```

## Dashboard Setup

### Option 1: Grafana + Prometheus (Advanced)

For production deployments:

1. Install Prometheus node_exporter
2. Configure Prometheus to scrape metrics
3. Set up Grafana dashboard
4. Create alert rules

### Option 2: Simple Status Page

Create a status endpoint script:

```bash
#!/bin/bash
# status-json.sh - Output JSON status

echo "{"
echo "  \"gateway\": \"$(systemctl is-active openclaw-gateway)\","
echo "  \"tailscale\": \"$(tailscale status --json | jq -r '.Self.Online')\","
echo "  \"disk_percent\": $(df / | tail -1 | awk '{print $5}' | tr -d '%'),"
echo "  \"memory_percent\": $(free | grep Mem | awk '{print int($3/$2 * 100)}')"
echo "  \"banned_ips\": $(sudo fail2ban-client status sshd | grep "Currently banned" | awk '{print $4}')"
echo "}"
```

## Alert Response Procedures

### Gateway Down

1. Check status: `systemctl status openclaw-gateway`
2. Check logs: `journalctl -u openclaw-gateway -n 50`
3. Restart: `openclaw gateway restart`
4. If persistent, check config: `openclaw doctor`

### Brute-Force Attack

1. Verify fail2ban is banning: `sudo fail2ban-client status sshd`
2. Review banned IPs: `sudo fail2ban-client status sshd`
3. Check if legitimate IPs blocked (your Tailscale IP should never be blocked)
4. Consider increasing ban time if attacks persist

### Disk Full

1. Check usage: `df -h`
2. Find large files: `sudo du -sh /* | sort -h | tail -20`
3. Clean Docker: `docker system prune -af`
4. Rotate logs: `sudo logrotate -f /etc/logrotate.conf`
5. Remove old backups if necessary

### Unauthorized Access Attempt

1. Immediately review: `./check-security.sh`
2. Check for successful logins: `last`
3. Review OpenClaw commands: `journalctl -u openclaw-gateway | grep -i command`
4. If compromised, follow [backups.md](backups.md) compromise recovery procedure
