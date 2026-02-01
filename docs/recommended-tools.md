# Recommended Security Tools

This document lists community and official tools for securing your OpenClaw deployment.

## Official Tools

### openclaw security audit

Built-in CLI tool that checks for common misconfigurations.

```bash
# Basic audit
openclaw security audit

# Deep audit with more checks
openclaw security audit --deep

# Auto-fix safe issues
openclaw security audit --deep --fix
```

**What it checks:**
- File permissions
- Gateway binding
- Credential exposure
- Configuration validity

---

## Community Tools

### openclaw-ansible

**Repository:** [openclaw/openclaw-ansible](https://github.com/openclaw/openclaw-ansible)

Official Ansible playbook for automated secure deployment. Implements 4-layer defense.

**Best for:** Users familiar with Ansible, multi-server deployments

**Vulnerabilities addressed:** #1, #3, #7, #9

```bash
# Clone and run
git clone https://github.com/openclaw/openclaw-ansible
cd openclaw-ansible
ansible-playbook -i inventory.yml site.yml
```

---

### openclaw-security-scan

**Repository:** [legendaryabhi/openclaw-security-scan](https://github.com/legendaryabhi/openclaw-security-scan)

CLI scanner that auto-detects misconfigurations and can auto-fix them.

**Best for:** Quick security audits, CI/CD integration

**Vulnerabilities addressed:** #1, #2, #4, #10

```bash
# Install
curl -sL https://raw.githubusercontent.com/legendaryabhi/openclaw-security-scan/main/scan.sh -o scan.sh
chmod +x scan.sh

# Scan
./scan.sh scan

# Auto-fix
./scan.sh fix --yes
```

---

### Cisco Skill Scanner

**Repository:** [cisco-ai-defense/skill-scanner](https://github.com/cisco-ai-defense/skill-scanner)

Scans skills/plugins for malware, prompt injection, and data exfiltration. Uses static analysis + LLM semantic analysis.

**Best for:** Vetting third-party skills before installation

**Vulnerabilities addressed:** #5, #8 (supply chain)

```bash
# Install
pip install skill-scanner

# Scan a skill
skill-scanner analyze ./my-skill/

# Scan all installed skills
skill-scanner scan ~/.openclaw/skills/
```

**Important:** Use this before installing ANY third-party skill.

---

### Agent Consent Protocol (ACP)

**Repository:** [o1100/Agent-Consent-Protocol](https://github.com/o1100/Agent-Consent-Protocol)

Wraps any agent in a consent-enforced sandbox. Provides credential vault, network isolation, and policy enforcement. The agent never touches raw credentials.

**Best for:** High-security deployments, credential isolation

**Vulnerabilities addressed:** #3, #4, #5, #6, #8

```bash
# Install
npm install -g agent-2fa

# Initialize
acp init

# Store credentials securely
acp secret set GITHUB_TOKEN
# (Enter token - stored encrypted)

# Run OpenClaw through ACP
acp run --network-isolation -- openclaw gateway
```

---

### openclaw-coolify

**Repository:** [essamamdani/openclaw-coolify](https://github.com/essamamdani/openclaw-coolify)

Docker Compose setup with Bitwarden/Pass integration for credential isolation.

**Best for:** Docker-native deployments, password manager integration

**Vulnerabilities addressed:** #3, #4, #7, #8

---

### pottertech/openclaw-secure-start

Security hardening tool mentioned in Cisco blog comments.

**Best for:** Quick hardening of existing deployments

---

## Comparison Matrix

| Tool | Type | Auto-fix | CI/CD Ready | Skill Vetting | Network Isolation |
|------|------|----------|-------------|---------------|-------------------|
| This project | Scripts + Docs | Yes | No | Docs only | Yes |
| openclaw-ansible | Ansible | Yes | Yes | No | Yes |
| openclaw-security-scan | Scanner | Yes | Yes | No | No |
| Cisco Skill Scanner | Scanner | No | Yes | Yes | No |
| ACP | Wrapper | Yes | No | No | Yes |
| openclaw-coolify | Docker | Yes | No | No | Yes |

## When to Use What

### New Deployment (AWS)
1. Use **this project** (openclaw-aws-secure-deploy) for full setup
2. Run **openclaw security audit** after setup
3. Use **Cisco Skill Scanner** before installing skills

### Existing Deployment (Audit)
1. Run **openclaw-security-scan** to find issues
2. Apply fixes manually or use **openclaw security audit --fix**

### High-Security Requirements
1. Use **Agent Consent Protocol (ACP)** for credential isolation
2. Run **Cisco Skill Scanner** on all skills
3. Implement manual approval workflows

### Multi-Server / Enterprise
1. Use **openclaw-ansible** for consistent deployment
2. Integrate **openclaw-security-scan** into CI/CD
3. Regular audits with **Cisco Skill Scanner**

---

## Security Researchers

Notable contributors to OpenClaw security research:

- **Jamieson O'Reilly** ([@dvulnresearch](https://twitter.com/dvulnresearch)) - Original Shodan scans finding 1,800+ exposed instances
- **@UK_Daniel_Card** - Shared exposed instance findings
- **@lucatac0** - Security research and documentation
- **@theonejvo** - Reported leaked API keys and malicious skills
- **Cisco AI Defense** - Comprehensive security analysis
- **Vectra AI** - Agent security research

---

## Reporting Security Issues

If you find a security vulnerability in OpenClaw:

1. **Do NOT** post publicly
2. Report to OpenClaw maintainers via responsible disclosure
3. For this project specifically, see [SECURITY.md](../SECURITY.md)
