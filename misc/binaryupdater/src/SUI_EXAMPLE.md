# Sui Upgrade Example

This file shows exactly how to upgrade your Sui node using the upgrade script, based on your manual process.

## Your Current Manual Process vs Script

### Manual Process:
1. cd ~/sui/bin
2. mkdir v1.58.3 && cd v1.58.3
3. wget https://github.com/MystenLabs/sui/releases/download/mainnet-v1.58.3/sui-mainnet-v1.58.3-ubuntu-x86_64.tgz
4. tar xvf sui-mainnet-v1.58.3-ubuntu-x86_64.tgz
5. ./sui -V  # Check version
6. sudo systemctl stop sui-mainnet.service
7. sudo cp sui sui-tool sui-node /usr/local/bin/
8. sudo systemctl start sui-mainnet.service

### With Upgrade Script:
```bash
./upgrade.sh --config sui.conf --version v1.58.3
```

That's it! The script does everything automatically.

## Step-by-Step First Time Setup

### 1. Run setup script (first time only):
```bash
./setup.sh
```

### 2. Review Sui configuration:
```bash
cat sui.conf
```

The configuration looks like this:
```yaml
project_name: sui
download_dir: ~/sui/bin
binary_dir: /usr/local/bin
service_name: sui-mainnet.service
binary_names: sui,sui-tool,sui-node
platform: ubuntu-x86_64
upgrade_method: download
download_url_template: https://github.com/MystenLabs/sui/releases/download/mainnet-{VERSION}/sui-mainnet-{VERSION}-{PLATFORM}.tgz
```

### 3. Test with dry run (see what it would do):
```bash
./upgrade.sh --config sui.conf --version v1.58.3 --dry-run
```

### 4. Perform actual upgrade:
```bash
./upgrade.sh --config sui.conf --version v1.58.3
```

## What the Script Does (Same as Your Manual Process)

1. **Creates backup** of current binaries in ~/.blockchain_backups/
2. **Creates version directory** ~/sui/bin/v1.58.3/
3. **Downloads binary** using the URL template
4. **Extracts archive** automatically
5. **Checks version** of new binary
6. **Stops service** sui-mainnet.service
7. **Copies binaries** sui, sui-tool, sui-node to /usr/local/bin/
8. **Starts service** sui-mainnet.service
9. **Verifies** service started correctly
10. **Logs everything** with timestamps

## Advanced Usage

### Use specific download URL (skip template):
```bash
./upgrade.sh --config sui.conf --url https://github.com/MystenLabs/sui/releases/download/mainnet-v1.58.3/sui-mainnet-v1.58.3-ubuntu-x86_64.tgz
```

### Check status after upgrade:
```bash
./status.sh
systemctl status sui-mainnet.service
journalctl -u sui-mainnet.service -f
```

### Rollback if something goes wrong:
```bash
./upgrade.sh --config sui.conf --version rollback
```

## Safety Features

✅ **Automatic backups** before any changes
✅ **Service management** (stop before, start after)
✅ **Version verification** confirms correct version installed
✅ **Rollback capability** if upgrade fails
✅ **Detailed logging** of all operations
✅ **Dry run mode** to test before actual upgrade

## Troubleshooting

### If upgrade fails:
1. Check logs: `tail -f ~/.blockchain_upgrade_logs/upgrade_$(date +%Y%m%d).log`
2. Check service: `systemctl status sui-mainnet.service`
3. Rollback: `./upgrade.sh --config sui.conf --version rollback`

### If service won't start:
1. Check service logs: `journalctl -u sui-mainnet.service -f`
2. Check binary permissions: `ls -la /usr/local/bin/sui*`
3. Test binary manually: `/usr/local/bin/sui -V`

## Log Locations

- **Upgrade logs**: `~/.blockchain_upgrade_logs/upgrade_YYYYMMDD.log`
- **Backups**: `~/.blockchain_backups/sui_YYYYMMDD_HHMMSS/`
- **Downloads**: `~/sui/bin/v1.58.3/` (version-specific directories)

## Comparison: Time Saved

| Task | Manual Time | Script Time |
|------|-------------|-------------|
| Download & extract | 2-3 minutes | Automatic |
| Version check | 30 seconds | Automatic |
| Service stop/start | 1 minute | Automatic |
| Binary copy | 30 seconds | Automatic |
| Create backup | Not done manually | Automatic |
| Logging | Not done | Automatic |
| **Total** | **5+ minutes + no backup** | **30 seconds + full backup** |

The script also eliminates human error and provides consistent, logged upgrades.