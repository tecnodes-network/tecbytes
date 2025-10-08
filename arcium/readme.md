# 🔐 Arcium Testnet Node Installation Guide

> **Tecnodes Validator Setup** - Ubuntu 64-bit Server

---

## 📋 Prerequisites Checklist

- ✅ Docker & Docker Compose (Already installed)
- ✅ Ubuntu Server 64-bit
- ✅ Reliable internet connection
- ✅ Basic command-line familiarity

### 💻 Hardware Requirements

| Component | Requirement |
|-----------|-------------|
| **RAM** | 32GB or more |
| **CPU** | 12 Core or more, 2.8GHz base speed or more |
| **Bandwidth** | Min 1 Gbit/s |
| **GPU** | Currently not used |
| **Disk** | Minimal (not heavily used) |

---

## 🚀 Step 1: Set Up Workspace

Create a dedicated folder for your Arcium node:

```bash
mkdir arcium-node-setup
cd arcium-node-setup
```

Get your public IP address (save this for later):

```bash
curl https://ipecho.net/plain ; echo
```

> **Example outputs:**
> - IPv6: `2a01:4f8:2191:2f5d::2`
> - IPv4: `116.202.212.179`

📝 **Note:** Save the IP address displayed - you'll need it multiple times

---

## 🔧 Step 2: Install Dependencies

### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
```

### Install Solana CLI

```bash
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
```

### Add Solana to PATH

```bash
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
```

### Verify Installation

```bash
solana --version
```

### Install OpenSSL and Git

```bash
sudo apt-get update
sudo apt-get install -y openssl git
```

---

## ⚙️ Step 3: Install Arcium Tooling

Install Arcium CLI and ARX node software:

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://arcium-install.arcium.workers.dev/ | bash
```

Add Arcium to PATH:

```bash
export PATH="$HOME/.arcium/bin:$PATH"
echo 'export PATH="$HOME/.arcium/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify installation:

```bash
arcium --version
arcup --version
```

---

## 🔑 Step 4: Generate Keypairs

> ⚠️ **Important:** You will generate and store these keys yourself. Execute these commands and **SECURELY STORE** the generated files.

### 4.1 Node Authority Keypair
Solana keypair for node identification:

```bash
solana-keygen new --outfile node-keypair.json --no-bip39-passphrase
```

### 4.2 Callback Authority Keypair
Solana keypair for callback computations:

```bash
solana-keygen new --outfile callback-kp.json --no-bip39-passphrase
```

### 4.3 Identity Keypair
PKCS#8 format for node-to-node communication:

```bash
openssl genpkey -algorithm Ed25519 -out identity.pem
```

### Display Public Keys

```bash
echo "=== NODE PUBLIC KEY ==="
solana address --keypair node-keypair.json

echo "=== CALLBACK PUBLIC KEY ==="
solana address --keypair callback-kp.json
```

> 🔒 **Critical:** Store all keypair files securely and create backups!
> - `node-keypair.json`
> - `callback-kp.json`
> - `identity.pem`

---

## 💰 Step 5: Fund Your Accounts

Get your public keys:

```bash
NODE_PUBKEY=$(solana address --keypair node-keypair.json)
CALLBACK_PUBKEY=$(solana address --keypair callback-kp.json)
```

Fund accounts with devnet SOL:

```bash
# Fund node account
solana airdrop 2 $NODE_PUBKEY -u devnet

# Fund callback account
solana airdrop 2 $CALLBACK_PUBKEY -u devnet
```

Verify balances:

```bash
echo "=== NODE ACCOUNT BALANCE ==="
solana balance $NODE_PUBKEY -u devnet

echo "=== CALLBACK ACCOUNT BALANCE ==="
solana balance $CALLBACK_PUBKEY -u devnet
```

> 💡 **Alternative:** If airdrop fails, use web faucet: [https://faucet.solana.com/](https://faucet.solana.com/)

---

## 📡 Step 6: Initialize Node Accounts On-Chain

> ⚠️ **Important:** Replace placeholders before running!
> - `<your-node-offset>`: Choose a large random 8-10 digit number (e.g., 847293561)
> - `<your-node-ip>`: Your public IP from Step 1

```bash
arcium init-arx-accs \
  --keypair-path node-keypair.json \
  --callback-keypair-path callback-kp.json \
  --peer-keypair-path identity.pem \
  --node-offset <your-node-offset> \
  --ip-address <your-node-ip> \
  --rpc-url https://api.devnet.solana.com
```

### Example:

```bash
arcium init-arx-accs \
  --keypair-path node-keypair.json \
  --callback-keypair-path callback-kp.json \
  --peer-keypair-path identity.pem \
  --node-offset 847293561 \
  --ip-address 116.202.212.179 \
  --rpc-url https://api.devnet.solana.com
```

> 📝 **Note:** If you get an error about offset already taken, choose a different number

---

## ⚙️ Step 7: Create Node Configuration File

> ⚠️ **Important:** Replace placeholders before running!
> - `<your-node-offset>`: Same number used in Step 6
> - `<your-IPv4-address>`: Your public IP or use `"0.0.0.0"` to bind to all interfaces

```bash
cat > node-config.toml << 'EOF'
[node]
offset = <your-node-offset>
hardware_claim = 0
starting_epoch = 0
ending_epoch = 9223372036854775807

[network]
address = "<your-IPv4-address>"

[solana]
endpoint_rpc = "https://api.devnet.solana.com"
endpoint_wss = "wss://api.devnet.solana.com"
cluster = "Devnet"
commitment.commitment = "confirmed"
EOF
```

### 🚀 Recommended: Use Dedicated RPC Provider

For better reliability, consider free tier options:
- **Helius**: [https://helius.xyz](https://helius.xyz)
- **QuickNode**: [https://quicknode.com](https://quicknode.com)

If using dedicated RPC, update the config:
```toml
endpoint_rpc = "<your-rpc-provider-url>"
endpoint_wss = "<your-rpc-websocket-url>"
```

---

## 🔗 Step 8A: Create a New Cluster (Option A)

> 📝 Skip to Step 8B if joining an existing cluster

> ⚠️ **Important:** Replace placeholders!
> - `<cluster-offset>`: Choose a unique number (e.g., **272486** spells "ARCIUM" 📞)
> - `<max-nodes>`: Maximum nodes in cluster (e.g., 10)

```bash
arcium init-cluster \
  --keypair-path node-keypair.json \
  --offset <cluster-offset> \
  --max-nodes <max-nodes> \
  --price-per-cu 0 \
  --rpc-url https://api.devnet.solana.com
```

### Example:

```bash
arcium init-cluster \
  --keypair-path node-keypair.json \
  --offset 272486 \
  --max-nodes 10 \
  --price-per-cu 0 \
  --rpc-url https://api.devnet.solana.com
```

---

## 🔗 Step 8B: Join an Existing Cluster (Option B)

> 📝 Skip this if you created your own cluster in Step 8A  
> ⚠️ **Requirement:** You must be invited by the cluster authority first

```bash
arcium join-cluster true \
  --keypair-path node-keypair.json \
  --node-offset <your-node-offset> \
  --cluster-offset <cluster-offset> \
  --rpc-url https://api.devnet.solana.com
```

---

## 🔥 Step 9: Open Firewall Port

```bash
# Open port 8080 for inter-node communication
sudo ufw allow 8080/tcp

# Verify firewall status
sudo ufw status
```

---

## 🐳 Step 10: Deploy Node with Docker

Pull the Arcium ARX node Docker image:

```bash
docker pull arcium/arx-node
```

Create logs directory:

```bash
mkdir -p arx-node-logs
```

Run the ARX node container:

```bash
docker run -d \
  --name arx-node \
  --restart unless-stopped \
  -e NODE_IDENTITY_FILE=/usr/arx-node/node-keys/node_identity.pem \
  -e NODE_KEYPAIR_FILE=/usr/arx-node/node-keys/node_keypair.json \
  -e OPERATOR_KEYPAIR_FILE=/usr/arx-node/node-keys/operator_keypair.json \
  -e CALLBACK_AUTHORITY_KEYPAIR_FILE=/usr/arx-node/node-keys/callback_authority_keypair.json \
  -e NODE_CONFIG_PATH=/usr/arx-node/arx/node_config.toml \
  -v "$(pwd)/node-config.toml:/usr/arx-node/arx/node_config.toml" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/operator_keypair.json:ro" \
  -v "$(pwd)/callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro" \
  -v "$(pwd)/identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro" \
  -v "$(pwd)/arx-node-logs:/usr/arx-node/logs" \
  -p 8080:8080 \
  arcium/arx-node
```

Verify container is running:

```bash
docker ps
```

---

## 📝 Step 11: Create Start Script (Recommended)

Create a reusable start script:

```bash
cat > start.sh << 'EOF'
#!/bin/bash

# Start the ARX node using Docker
docker run -d \
  --name arx-node \
  --restart unless-stopped \
  -e NODE_IDENTITY_FILE=/usr/arx-node/node-keys/node_identity.pem \
  -e NODE_KEYPAIR_FILE=/usr/arx-node/node-keys/node_keypair.json \
  -e OPERATOR_KEYPAIR_FILE=/usr/arx-node/node-keys/operator_keypair.json \
  -e CALLBACK_AUTHORITY_KEYPAIR_FILE=/usr/arx-node/node-keys/callback_authority_keypair.json \
  -e NODE_CONFIG_PATH=/usr/arx-node/arx/node_config.toml \
  -v "$(pwd)/node-config.toml:/usr/arx-node/arx/node_config.toml" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/operator_keypair.json:ro" \
  -v "$(pwd)/callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro" \
  -v "$(pwd)/identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro" \
  -v "$(pwd)/arx-node-logs:/usr/arx-node/logs" \
  -p 8080:8080 \
  arcium/arx-node
EOF

chmod +x start.sh
```

To use the script:

```bash
./start.sh
```

---

## ✅ Step 12: Verify Node Operation

Get your node public key:

```bash
NODE_PUBKEY=$(solana address --keypair-path node-keypair.json)
```

Check node status:

```bash
arcium arx-info $NODE_PUBKEY --rpc-url https://api.devnet.solana.com
```

Check if node is active:

```bash
arcium arx-active $NODE_PUBKEY --rpc-url https://api.devnet.solana.com
```

Monitor Docker logs:

```bash
# Real-time logs (press Ctrl+C to exit)
docker logs -f arx-node

# View recent logs
docker logs --tail 100 arx-node
```

---

## 🛠️ Useful Docker Commands

| Command | Description |
|---------|-------------|
| `docker stop arx-node` | Stop the node |
| `docker start arx-node` | Start the node |
| `docker restart arx-node` | Restart the node |
| `docker rm -f arx-node` | Remove the container |
| `docker logs -f arx-node` | View logs in real-time |
| `docker logs --tail 100 arx-node` | View last 100 log lines |
| `docker ps -a` | Check container status |
| `docker stats arx-node` | Check resource usage |

---

## 🔧 Troubleshooting

### 1. Node Not Starting

```bash
# Verify all keypair files exist
ls -l *.json *.pem

# Check config file validity
cat node-config.toml

# Verify IP accessibility
curl https://ipecho.net/plain ; echo
```

### 2. Account Initialization Failed

```bash
# Check SOL balance
solana balance $NODE_PUBKEY -u devnet

# Verify RPC endpoint
curl https://api.devnet.solana.com -I

# Try a different node offset
```

### 3. Cannot Join Cluster

- ✓ Verify invitation from cluster authority
- ✓ Check cluster has available slots
- ✓ Ensure node is properly initialized

### 4. Docker Issues

```bash
# Check Docker is running
docker ps

# Verify file permissions
ls -l

# Check port availability
sudo netstat -tulpn | grep 8080

# Run container in foreground for debugging
docker run --rm \
  --name arx-node \
  -e NODE_IDENTITY_FILE=/usr/arx-node/node-keys/node_identity.pem \
  -e NODE_KEYPAIR_FILE=/usr/arx-node/node-keys/node_keypair.json \
  -e OPERATOR_KEYPAIR_FILE=/usr/arx-node/node-keys/operator_keypair.json \
  -e CALLBACK_AUTHORITY_KEYPAIR_FILE=/usr/arx-node/node-keys/callback_authority_keypair.json \
  -e NODE_CONFIG_PATH=/usr/arx-node/arx/node_config.toml \
  -v "$(pwd)/node-config.toml:/usr/arx-node/arx/node_config.toml" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro" \
  -v "$(pwd)/node-keypair.json:/usr/arx-node/node-keys/operator_keypair.json:ro" \
  -v "$(pwd)/callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro" \
  -v "$(pwd)/identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro" \
  -v "$(pwd)/arx-node-logs:/usr/arx-node/logs" \
  -p 8080:8080 \
  arcium/arx-node
```

---

## 🔒 Security Best Practices

- 🚫 **NEVER** share your private keys
- 🔐 Store keypairs securely with proper permissions (`chmod 600`)
- 💾 Keep backups of all keypair files in a secure location
- 🛡️ Use firewalls to restrict network access
- 🔄 Keep system and Docker images updated regularly
- 📊 Monitor logs regularly for suspicious activity

---

## 🌐 Recommended RPC Providers

For better reliability, consider using dedicated RPC providers:

| Provider | Free Tier | Link |
|----------|-----------|------|
| **Helius** | ✅ Sufficient for testnet | [helius.xyz](https://helius.xyz) |
| **QuickNode** | ✅ Sufficient for testnet | [quicknode.com](https://quicknode.com) |

Update `node-config.toml` with your RPC endpoints after signup.

---

## 🆘 Support and Community

- 💬 **Discord**: [discord.gg/arcium](https://discord.gg/arcium)
- 📚 **Documentation**: [docs.arcium.com](https://docs.arcium.com)
- 🔧 **Troubleshooting**: [Installation Issues](https://docs.arcium.com/developers/installation#issues)

---

## 🎯 What to Expect

- ✅ Real MPC computations for stress testing
- ✅ Running on Solana devnet (no real economic value)
- ✅ Variable activity depending on testing schedule
- ✅ No rewards enabled yet (pure testing phase)
- ✅ Updates and testing schedules on Discord

---

## 📌 Quick Reference

### Key Files
```
arcium-node-setup/
├── node-keypair.json       # Node authority keypair
├── callback-kp.json        # Callback authority keypair
├── identity.pem            # Identity keypair (PKCS#8)
├── node-config.toml        # Node configuration
├── start.sh                # Start script
└── arx-node-logs/          # Log directory
```

### Important Values
- **Node Offset**: Large random 8-10 digit number
- **Cluster Offset**: 272486 (spells "ARCIUM" 📞)
- **Port**: 8080
- **Network**: Solana Devnet

---

<div align="center">

**Arcium Guide by: Tecnodes**  
*Professional Validator Company - Node operations per ISO27001 Standards*

**Date:** October 2025  
**Network:** Arcium Testnet (Solana Devnet)

---

www.tecnodes.network

</div>
