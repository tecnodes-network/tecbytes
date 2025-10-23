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
```
project_name: sui
download_dir: ~/sui/bin
binary_dir: /usr/local/bin
service_name: sui-mainnet.service
binary_names: sui,sui-tool,sui-node
platform: ubuntu-x86_64
upgrade_method: download
download_url_template: https://github.com/MystenLabs/sui/releases/download/mainnet-{VERSION}/sui-mainnet-{VERSION}-{PLATFORM}.tgz

```


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

# Cosmovisor Module Enhancement - 22.10.25

This update introduces robust Cosmovisor support for Cosmos-based runner nodes, with *no changes to Sui, Substrate, and traditional direct-binary flows*.

---

## 🆕 New Features

- **Cosmovisor Support**: When `cosmovisor_mode: true` in your config, the script:
    - Accepts `--proposal-id <id>` to fetch upgrade plan name from on-chain proposal via RPC
    - Accepts `--cosmovisor-upgrade-name <name>` to specify plan name directly (for emergencies or manual uploads)
    - Accepts `--reuse-existing-upgrade` to allow emergency overwrites of existing Cosmovisor upgrade folders
    - All file/folder paths and binary names are configurable
- **Modular**: Sui/Substrate/other chains *unaffected*; Cosmovisor logic lives in its own function and only runs for configs with `cosmovisor_mode: true`
- **Smart Directory and Binary Handling**: Correctly prepares upgrades in `$COSMOVISOR_HOME/upgrades/<upgrade_name>/bin/`
- **DRY RUN**: Outputs an exact step-by-step plan for Cosmovisor path/plan upgrades, so you know precisely what will happen before any changes
- **Clear Config Comments**: Each cosmos.conf option now includes a comment for clarity

---

## ⚙️ New Config Keys (cosmos.conf example)

```yaml
project_name: gaia                                  # Chain/project name for logging
rpc_url: "https://rpc.cosmoshub.strange.labs:443"   # Chain RPC endpoint, used to fetch proposal/plans
daemon_name: gaiad                                  # Binary name, e.g. gaiad, osmosisd
cosmovisor_mode: true                               # If true, enables cosmovisor-centric upgrades
cosmovisor_home: ~/.gaia/cosmovisor                 # Path to cosmovisor home base dir
binary_dir: /usr/local/bin                          # Fallback install dir (for non-cosmovisor compatibility)
binary_names: gaiad                                 # One or more, for future multi-binary upgrades
platform: linux-amd64                              # Platform identifier for any templating
upgrade_method: compile                            # use 'download' or 'compile'
build_command: make build                          # build command for binary compilation
build_binary_path: build/gaiad                      # path to built binary relative to project root
```

---

## 🛠️ New CLI Options

```bash
./upgrade.sh --config cosmos.conf --version v17.0.0 --proposal-id 17 --dry-run
./upgrade.sh --config cosmos.conf --version v17.0.0 --cosmovisor-upgrade-name v17         # for manual plan name
./upgrade.sh --config cosmos.conf --version v16.1.1 --cosmovisor-upgrade-name v16 --reuse-existing-upgrade
```

---

## 🔍 DRY RUN Example Output

```bash
========= COSMOVISOR DRY RUN ==========
Upgrade plan name: v17
Binary target: /home/user/.gaia/cosmovisor/upgrades/v17/bin/gaiad
Binary source: v17.0.0 (build/download source: build/gaiad)
Will NOT restart services. Cosmovisor will swap at upgrade block.
Commands run: (build, copy, verify binary version).
=======================================
```

---

## 🚀 How to Apply This Update

1. **Replace your existing `upgrade.sh` with the new script.**
    - Backup old version: `cp upgrade.sh upgrade_old.sh`
    - Move new script in place: `cp <NEW_DOWNLOAD_PATH>/upgrade.sh ./upgrade.sh`
2. **Overwrite or create a new cosmos.conf for Cosmos chains, using the commented template.**
    - Review and update your settings for your actual node folder names/paths.
3. **Install jq if not present (required for proposal extraction):**
    ```bash
    sudo apt-get install jq
    ```
4. **Test with dry run:**
    ```bash
    ./upgrade.sh --config cosmos.conf --version v17.0.0 --proposal-id 17 --dry-run
    ```
    - Should print planned actions before any change!
5. **To upgrade Sui, Substrate, or legacy chains:**
    - No changes needed; their existing configs and flows will not be affected by the upgrade.
6. **Review logs and outputs to confirm the correct path and binary have been staged.**

---

## 🛑 If Any Issue

- Revert to previous backup: `cp upgrade_old.sh upgrade.sh`
- Troubleshoot with `--dry-run` and verbose output
- Validate config file with `validate_config.sh` (if installed)

---

**This upgrade makes Cosmos-based node management with Cosmovisor 100% scriptable and safe, while keeping your other networks and configs unchanged.**
