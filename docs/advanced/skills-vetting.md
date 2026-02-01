# Skills Vetting Guide

Third-party skills are a major attack vector. Cisco found that 26% of 31,000 skills analyzed had vulnerabilities.

## The Risk

Skills can:
- Execute arbitrary code on your server
- Access your credentials
- Exfiltrate data to external servers
- Persist malicious code
- Escalate privileges

The "What Would Elon Do?" skill analyzed by Cisco was functionally malware—it exfiltrated data to external servers while appearing to be a fun productivity tool.

## Before Installing Any Skill

### 1. Check the Source

**Trust hierarchy:**
1. Official OpenClaw skills (highest trust)
2. Skills from verified organizations
3. Popular skills with many users and reviews
4. Unknown developers (lowest trust)

**Red flags:**
- New developer with no history
- Skill claims to be "free version" of paid service
- Promises capabilities that seem too good to be true
- No source code available

### 2. Use Cisco Skill Scanner

**Install:**
```bash
pip install skill-scanner
```

**Scan before installing:**
```bash
# Download skill without installing
git clone https://github.com/developer/skill-name /tmp/skill-review

# Scan it
skill-scanner analyze /tmp/skill-review

# If clean, then install
```

**What the scanner checks:**
- Outbound network calls (data exfiltration)
- File system access patterns
- Credential access attempts
- Prompt injection vulnerabilities
- Obfuscated code

### 3. Manual Code Review

For critical skills, review the code yourself:

**Check for network calls:**
```bash
# Look for outbound requests
grep -r "fetch\|axios\|request\|http\|curl" /path/to/skill
```

**Check for file access:**
```bash
# Look for sensitive file access
grep -r "\.env\|credentials\|\.ssh\|passwd\|shadow" /path/to/skill
```

**Check for shell execution:**
```bash
# Look for command execution
grep -r "exec\|spawn\|system\|eval\|child_process" /path/to/skill
```

### 4. Test in Isolation

Before using in production:

```bash
# Create test environment
mkdir ~/skill-test
cd ~/skill-test

# Install skill in isolation
# Test with non-sensitive data
# Monitor network traffic
```

## Permissions to Watch

| Permission | Risk | When Acceptable |
|------------|------|-----------------|
| Network access | Data exfiltration | API integrations only |
| File system read | Credential theft | Document processing |
| File system write | Persistence | Note-taking, exports |
| Shell execution | Full compromise | Dev tools only |
| Memory access | Session hijacking | Almost never |

## Safe Skill Practices

### 1. Minimal Permissions

Only grant permissions the skill actually needs:

```json
{
  "skills": {
    "weather-skill": {
      "permissions": ["network:api.weather.com"]
    }
  }
}
```

### 2. Network Allowlist

If skill needs network, restrict to specific domains:

```json
{
  "skills": {
    "github-skill": {
      "network": {
        "allowlist": ["api.github.com", "github.com"]
      }
    }
  }
}
```

### 3. Regular Audits

Periodically review installed skills:

```bash
# List all skills
openclaw skills list

# Check each skill's permissions
# Remove unused skills
openclaw skills remove unused-skill
```

## Incident Response

If you suspect a malicious skill:

1. **Disable immediately:**
   ```bash
   openclaw skills disable suspicious-skill
   ```

2. **Isolate the server:**
   ```bash
   sudo ufw default deny outgoing
   ```

3. **Check for damage:**
   ```bash
   # Recent file changes
   find ~/.openclaw -mtime -1 -type f
   
   # Check credentials
   ls -la ~/.openclaw/credentials/
   
   # Network connections
   ss -tulnp
   ```

4. **Rotate all credentials** (assume compromised)

5. **Report the skill** to OpenClaw maintainers

## Recommended Safe Skills

These are generally considered safe (but always verify):

- Official OpenClaw skills
- Skills from major tech companies
- Open-source skills with significant community review

**Always verify even "trusted" skills haven't been compromised in updates.**

## Building Your Own Skills

If you need custom functionality, consider building your own:

1. Start with official skill templates
2. Minimize permissions
3. No hardcoded credentials
4. Input validation for all user data
5. Audit logging for sensitive operations

Resources:
- [OpenClaw Skill Development Guide](https://docs.openclaw.ai/skills)
- [Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
