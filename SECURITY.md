# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT open a public GitHub issue**
2. Email the maintainers directly (see profile)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

## Security Model

This project implements a defense-in-depth approach:

### Layer 1: Network Isolation
- UFW firewall blocks all incoming traffic except Tailscale
- No public ports exposed (not even SSH)
- All access requires Tailscale VPN authentication

### Layer 2: Application Security
- OpenClaw gateway binds to localhost only (127.0.0.1)
- Gateway authentication token required
- DM allowlist restricts who can control the bot

### Layer 3: Execution Isolation
- Docker sandbox for command execution
- Network isolation (network=none) prevents data exfiltration
- Dangerous command blocklist

### Layer 4: Host Hardening
- SSH: key-only authentication, no root login
- fail2ban for brute-force protection
- Automatic security updates enabled
- Restrictive file permissions (700/600)

## Known Limitations

1. **Prompt Injection**: While mitigated through sandboxing and allowlists, prompt injection via malicious content is a fundamental LLM challenge. See [docs/vulnerabilities.md](docs/vulnerabilities.md#5-prompt-injection).

2. **Skills/Plugins**: This project does not vet third-party skills. Use [Cisco's Skill Scanner](https://github.com/cisco-ai-defense/skill-scanner) before installing skills.

3. **Supply Chain**: We recommend only installing OpenClaw from official npm registry.

## Security Auditing

After setup, run:

```bash
openclaw security audit --deep
```

For ongoing monitoring:

```bash
./check-security.sh
```

## Credential Handling

- API keys are stored in `~/.openclaw/` with 600 permissions
- Gateway tokens are auto-generated during setup
- No credentials are logged or transmitted by our scripts

## Updates

Security updates are handled by:
- `unattended-upgrades` for OS packages
- Weekly `maintenance.sh` cron job for OpenClaw updates
- Manual Tailscale updates (they auto-update by default)
