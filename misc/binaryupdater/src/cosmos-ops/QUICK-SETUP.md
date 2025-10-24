# Quick Setup Guide - cosmos-ops.sh

## 1. Setup Script

```bash
# Download and make executable
chmod +x cosmos-ops.sh

# Create necessary directories
mkdir -p ~/.cosmos-ops
mkdir -p ~/.blockchain_upgrade_logs
```

## 2. Setup Password (Choose One Method)

### Method A: GPG Encrypted (Recommended)
```bash
# Encrypt your keyring password
echo "your-password" | gpg --encrypt --recipient your-email@example.com \
  -o ~/.cosmos-ops/jackal-password.gpg

# Set permissions
chmod 600 ~/.cosmos-ops/jackal-password.gpg
chmod 700 ~/.cosmos-ops
```

### Method B: Manual Entry
Skip password file creation. Script will prompt when needed.

## 3. Update Your Chain Config (jackal.conf)

Add these NEW lines to your existing config:

```yaml
# NEW: RPC endpoint (Tendermint RPC)
rpc_endpoint: http://localhost:26657

# NEW: Chain ID
chain_id: jackal-1

# NEW: Keyring settings
keyring_backend: file
key_name: validator

# NEW: Password file (optional - for GPG method)
password_file: ~/.cosmos-ops/jackal-password.gpg

# NEW: Gas settings
max_gas_fee: 0.1ujkl
gas_adjustment: 1.3
```

## 4. Setup Telegram (Optional)

Create `telegram.conf`:

```yaml
bot_token: YOUR_BOT_TOKEN_FROM_BOTFATHER
chat_id: YOUR_CHAT_ID
enabled: true
```

## 5. Test Installation

```bash
# Test with dry-run
./cosmos-ops.sh --config jackal.conf --balance

# Test voting (dry-run)
./cosmos-ops.sh --config jackal.conf --vote yes --proposal-id 1 --dry-run
```

## 6. Usage Examples

```bash
# Vote on proposal
./cosmos-ops.sh --config jackal.conf --vote yes --proposal-id 24

# Check balance
./cosmos-ops.sh --config jackal.conf --balance

# Withdraw rewards
./cosmos-ops.sh --config jackal.conf --withdraw-rewards

# Auto-vote mode
./cosmos-ops.sh --config jackal.conf --auto-vote yes --interval 360
```

## Files Overview

```
cosmos-ops.sh              # Main script
jackal.conf                # Chain config (extended)
telegram.conf              # Telegram config (optional)
~/.cosmos-ops/            # Password storage
~/.blockchain_upgrade_logs/ # Log files
```

## Important Notes

1. ✅ Your existing `upgrade.sh` still works (no changes needed)
2. ✅ Both scripts use the same `jackal.conf` file
3. ✅ `rpc_url` stays as REST API (for upgrade.sh compatibility)
4. ✅ New `rpc_endpoint` is for Tendermint RPC

## Need Help?

Check the full documentation: `cosmos-ops-documentation.pdf`
