## 🎯 Main Upgrade Script (upgrade.sh)
A powerful, configurable script that handles:
Both download and compile methods
Automatic backups before any changes
Service management (stop/start systemd services)
Multiple binaries support (perfect for Sui's sui, sui-tool, sui-node)
Version verification after installation
Rollback capability if something goes wrong
Comprehensive logging with timestamps
Dry-run mode for testing

## 🔧 Configuration Files
Ready-to-use configurations for:

sui.conf - Your Sui mainnet setup (download method)

cosmos.conf - Cosmos/Gaia nodes

substrate.conf - Substrate/Polkadot nodes (compile method)

osmosis.conf - Osmosis nodes

template.conf - Template for new blockchains

## 🛠️ Utility Scripts
status.sh - Check all your blockchain services at once

list-configs.sh - Validate and list all configurations

setup.sh - First-time setup (creates directories, sets permissions)

## ✨ Key Features That Solve Your Problems
✅ Configurable: Each blockchain has its own config file

✅ Version templates: Automatic URL construction using {VERSION} placeholder

✅ Multiple binaries: Handles sui, sui-tool, sui-node in one go

✅ Safety first: Creates backups automatically before any changes

✅ Git compilation: Supports git fetch, checkout version, make build

✅ Smart binary detection: Finds compiled binaries in build/, bin/, target/release/, etc.

✅ Service management: Stops/starts your systemd services safely

✅ Logging: Full audit trail of every upgrade

✅ Error handling: Rolls back on failures

## Config example
```project_name: sui
download_dir: ~/sui/bin
binary_dir: /usr/local/bin
service_name: sui-mainnet.service
binary_names: sui,sui-tool,sui-node
platform: ubuntu-x86_64
upgrade_method: download
download_url_template: https://github.com/MystenLabs/sui/releases/download/mainnet-{VERSION}/sui-mainnet-{VERSION}-{PLATFORM}.tgz```


## Examples
```
./upgrade.sh --config sui.conf --version v1.58.3

dry run only
./upgrade.sh --config sui.conf --version v1.58.3 --dry-run

check status:
./status.sh

rollback:
./upgrade.sh --config sui.conf --version rollback
```
