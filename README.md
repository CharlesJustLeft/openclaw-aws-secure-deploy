# OpenClaw AWS Secure Deploy

[![Security Hardened](https://img.shields.io/badge/security-hardened-green.svg)](docs/vulnerabilities.md)
[![AWS Ready](https://img.shields.io/badge/AWS-EC2%20Ready-orange.svg)](terraform/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Secure deployment guide and automation scripts for running OpenClaw on AWS EC2.**

Deploy your personal AI assistant with enterprise-grade security in under an hour. This project addresses all 10 known OpenClaw vulnerabilities identified by security researchers.

---

## Why This Exists

Security researchers found [1,800+ exposed OpenClaw instances](https://www.shodan.io/search?query=clawdbot-gw) on the public internet with:
- Gateway control planes accessible to anyone
- DM policies allowing strangers to control bots
- Plaintext credentials readable by other processes
- No network isolation for command execution

**This project fixes all of that.**

---

## Quick Start

### Option 1: Automated Setup (Recommended)

SSH into your fresh Ubuntu 24.04 EC2 instance and run:

```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/openclaw-aws-secure-deploy/main/scripts/setup.sh | bash
```

The script will:
1. Harden your server (SSH, firewall, fail2ban)
2. Install Tailscale VPN (you'll authenticate via browser)
3. Install Docker with network isolation
4. Install OpenClaw
5. **Pause** for you to run `openclaw onboard`
6. Configure DM allowlist (prompts for your user ID)
7. Verify everything and set up maintenance

### Option 2: Terraform + Scripts

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/openclaw-aws-secure-deploy.git
cd openclaw-aws-secure-deploy

# Deploy EC2 instance
cd terraform
terraform init
terraform apply

# SSH in and run setup
ssh -i your-key.pem ubuntu@$(terraform output -raw public_ip)
./setup.sh
```

### Option 3: Manual Setup

Follow the [Full Guide](docs/full-guide.md) for step-by-step instructions with detailed explanations.

---

## Vulnerability Coverage

| # | Vulnerability | Status | How We Fix It |
|---|--------------|--------|---------------|
| 1 | Gateway exposed on 0.0.0.0:18789 | ✅ Fixed | UFW + Tailscale VPN + auth token |
| 2 | DM policy allows all users | ✅ Fixed | Allowlist with your user ID only |
| 3 | Sandbox disabled by default | ✅ Fixed | Docker with network=none |
| 4 | Credentials in plaintext | ✅ Fixed | chmod 700/600 permissions |
| 5 | Prompt injection via web content | ⚠️ Mitigated | Defense-in-depth (sandbox + allowlist) |
| 6 | Dangerous commands unblocked | ✅ Fixed | Command blocklist configuration |
| 7 | No network isolation | ✅ Fixed | Docker isolated network |
| 8 | Elevated tool access | 📖 Documented | Recommend Cisco Skill Scanner |
| 9 | No audit logging | ✅ Fixed | Logging enabled + security audits |
| 10 | Weak pairing codes | ✅ Fixed | Rate limiting via fail2ban |

See [docs/vulnerabilities.md](docs/vulnerabilities.md) for detailed explanations.

---

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PUBLIC INTERNET                          │
│                    (Blocked by UFW firewall)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ❌ ALL PORTS BLOCKED
                              │    (except Tailscale UDP 41641)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS EC2 INSTANCE                           │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   │
│  │   UFW         │    │   Tailscale   │    │   OpenClaw    │   │
│  │   Firewall    │───▶│   VPN         │───▶│   Gateway     │   │
│  │               │    │               │    │   127.0.0.1   │   │
│  │ Default: DENY │    │ Encrypted     │    │   :18789      │   │
│  └───────────────┘    └───────────────┘    └───────────────┘   │
│                                                   │             │
│                                            ┌──────┴──────┐      │
│                                            │   Docker    │      │
│                                            │   Sandbox   │      │
│                                            │ network=none│      │
│                                            └─────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ✅ Encrypted Tailscale Tunnel
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR DEVICES ONLY                           │
│              (Authenticated via Tailscale account)              │
└─────────────────────────────────────────────────────────────────┘
```

---

## What's Included

```
openclaw-aws-secure-deploy/
├── scripts/
│   ├── setup.sh              # Master setup script (run this!)
│   ├── maintenance.sh        # Weekly maintenance
│   └── check-security.sh     # Quick security check
├── terraform/                # AWS infrastructure as code
├── config-templates/         # Secure configuration files
└── docs/
    ├── full-guide.md         # Complete step-by-step guide
    ├── vulnerabilities.md    # Security deep-dive
    └── advanced/             # Secrets rotation, backups, etc.
```

---

## Comparison with Other Tools

| Feature | This Project | openclaw-ansible | openclaw-security-scan |
|---------|-------------|------------------|----------------------|
| AWS-specific | ✅ Terraform included | ❌ Generic | ❌ Scanner only |
| Beginner-friendly | ✅ Guided setup | ⚠️ Ansible knowledge needed | ✅ Simple CLI |
| Full deployment | ✅ End-to-end | ✅ End-to-end | ❌ Detection only |
| Explains vulnerabilities | ✅ Detailed docs | ❌ Just fixes | ⚠️ Brief |
| Interactive setup | ✅ Prompts for input | ❌ Config files | N/A |

---

## Prerequisites

Before starting, you need:

- [ ] AWS account with EC2 access
- [ ] [Tailscale account](https://tailscale.com) (free tier works)
- [ ] Tailscale installed on your local machine
- [ ] LLM API key (Anthropic, OpenAI, etc.)
- [ ] Discord/Telegram bot token (if using messaging)
- [ ] Your messaging platform user ID ([how to get it](docs/full-guide.md#getting-your-messaging-platform-user-id))

---

## Support

- **Issues:** [GitHub Issues](https://github.com/YOUR_USERNAME/openclaw-aws-secure-deploy/issues)
- **Discussions:** [GitHub Discussions](https://github.com/YOUR_USERNAME/openclaw-aws-secure-deploy/discussions)
- **OpenClaw Docs:** [docs.openclaw.ai](https://docs.openclaw.ai)

---

## Credits

- Security research by [Cisco AI Defense](https://www.cisco.com), [Vectra AI](https://www.vectra.ai), and community researchers
- Inspired by findings from [@dvulnresearch](https://twitter.com/dvulnresearch), [@UK_Daniel_Card](https://twitter.com/UK_Daniel_Card)
- Built on [OpenClaw](https://openclaw.ai)

---

## License

MIT License - See [LICENSE](LICENSE) for details.
