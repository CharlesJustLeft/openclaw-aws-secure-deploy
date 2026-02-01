# Secrets Rotation Guide

Regular rotation of credentials reduces the window of opportunity if any credential is compromised.

## Rotation Schedule

| Credential | Recommended Frequency | Risk if Compromised |
|------------|----------------------|---------------------|
| LLM API Keys | Every 90 days | High billing, data access |
| Gateway Token | Every 90 days | Bot control |
| Discord Bot Token | Every 180 days | Account impersonation |
| SSH Keys | Every 365 days | Server access |
| Tailscale | As needed | Network access |

## How to Rotate

### LLM API Keys (Anthropic, OpenAI, etc.)

1. **Generate new key** in provider dashboard
2. **Update OpenClaw config:**
   ```bash
   nano ~/.openclaw/openclaw.json
   # Update the API key in the models section
   ```
   Or use:
   ```bash
   openclaw configure --section model
   ```
3. **Restart gateway:**
   ```bash
   openclaw gateway restart
   ```
4. **Revoke old key** in provider dashboard (after verifying new key works)

### Gateway Token

1. **Generate new token:**
   ```bash
   # Generate random token
   openssl rand -hex 24
   ```
2. **Update config:**
   ```bash
   nano ~/.openclaw/openclaw.json
   # Update gateway.auth.token
   ```
3. **Restart gateway:**
   ```bash
   openclaw gateway restart
   ```
4. **Update any clients** using the old token

### Discord Bot Token

1. **Go to Discord Developer Portal** → Your Application → Bot
2. **Click "Reset Token"** (this invalidates the old token immediately)
3. **Copy new token**
4. **Update OpenClaw:**
   ```bash
   nano ~/.openclaw/openclaw.json
   # Update channels.discord.token
   ```
5. **Restart gateway:**
   ```bash
   openclaw gateway restart
   ```

### SSH Keys

1. **Generate new key pair** (on your local machine):
   ```bash
   ssh-keygen -t ed25519 -C "openclaw-$(date +%Y%m)"
   ```
2. **Add new public key** to server:
   ```bash
   # SSH with old key
   ssh -i old_key ubuntu@SERVER_TAILSCALE_IP
   
   # Add new public key
   echo "NEW_PUBLIC_KEY_CONTENT" >> ~/.ssh/authorized_keys
   ```
3. **Test new key** (in separate terminal):
   ```bash
   ssh -i new_key ubuntu@SERVER_TAILSCALE_IP
   ```
4. **Remove old key** from server:
   ```bash
   nano ~/.ssh/authorized_keys
   # Delete the old key line
   ```
5. **Delete old key** from local machine (after verifying)

### Tailscale

Tailscale keys typically don't need manual rotation, but if needed:

```bash
# On server
sudo tailscale logout
sudo tailscale up
# Re-authenticate via browser
```

## Automation Tips

### Set Reminders

Add to your calendar:
- Monthly: Review security audit results
- Quarterly: Rotate API keys and gateway token
- Annually: Rotate SSH keys

### Secret Manager Integration

For enterprise deployments, consider:

- **AWS Secrets Manager**: Automatic rotation with Lambda
- **HashiCorp Vault**: Dynamic secrets with TTL
- **Bitwarden/1Password**: Manual but organized rotation

Example with AWS Secrets Manager:
```bash
# Retrieve secret
aws secretsmanager get-secret-value --secret-id openclaw/api-key

# Update secret
aws secretsmanager update-secret --secret-id openclaw/api-key --secret-string "new-key"
```

## After Rotation Checklist

- [ ] New credential works (test functionality)
- [ ] Old credential revoked/deleted
- [ ] Any backup systems updated
- [ ] Documentation updated with rotation date
- [ ] No services failing due to old credentials
