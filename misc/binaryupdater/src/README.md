# Blockchain Binary Upgrade Script

A configurable script for upgrading blockchain node binaries with support for both pre-compiled downloads and source compilation. Designed for Sui, Cosmos-based, Substrate-based, and other blockchain nodes.

## Features

- ✅ **Configurable**: YAML-based configuration files for each blockchain
- ✅ **Two upgrade methods**: Download pre-compiled binaries or compile from source
- ✅ **Safety first**: Automatic backups, service management, and rollback capability
- ✅ **Multiple binaries**: Support for projects with multiple binaries (e.g., Sui: sui, sui-tool, sui-node)
- ✅ **Comprehensive logging**: Detailed logs with timestamps and colored output
- ✅ **Dry run mode**: Test your configuration without making changes
- ✅ **Version verification**: Confirms binary versions after installation
- ✅ **Service management**: Automatic stop/start of systemd services

## Quick Start

1. **Make the script executable**:
   ```bash
   chmod +x upgrade.sh
   ```

2. **Use with existing configurations**:
   ```bash
   # Upgrade Sui to specific version
   ./upgrade.sh --config sui.conf --version v1.58.3

   # Upgrade Cosmos node with direct URL
   ./upgrade.sh --config cosmos.conf --url https://github.com/cosmos/gaia/releases/download/v15.0.0/gaiad-v15.0.0-linux-amd64

   # Test configuration without making changes
   ./upgrade.sh --config substrate.conf --version v1.0.0 --dry-run
   ```

3. **Rollback if needed**:
   ```bash
   ./upgrade.sh --config sui.conf --version rollback
   ```

## Configuration Files

The script uses YAML configuration files. Example configurations are provided for:

- `sui.conf` - Sui blockchain (download method)
- `cosmos.conf` - Cosmos Gaia (download method)  
- `substrate.conf` - Substrate/Polkadot (compile method)
- `osmosis.conf` - Osmosis (compile method)
- `template.conf` - Generic template for new blockchains

### Configuration Options

```yaml
# Basic configuration
project_name: sui                    # Project identifier
download_dir: ~/sui/bin             # Where to download/store binaries
binary_dir: /usr/local/bin          # Where to install binaries
service_name: sui-mainnet.service   # Systemd service name (optional)
binary_names: sui,sui-tool,sui-node # Comma-separated binary names
platform: ubuntu-x86_64            # Platform identifier

# Upgrade method
upgrade_method: download            # 'download' or 'compile'

# For download method
download_url_template: https://github.com/MystenLabs/sui/releases/download/mainnet-{VERSION}/sui-mainnet-{VERSION}-{PLATFORM}.tgz

# For compile method
git_repo_dir: ~/sui/source          # Git repository location
build_command: make build           # Build command
compiled_binary_path: build         # Path relative to repo where binaries are built
```

### Template Variables

- `{VERSION}` - Replaced with the version you specify
- `{PLATFORM}` - Replaced with the platform value from config

## Usage Examples

### Download Method (Sui Example)

```bash
# Upgrade to specific version
./upgrade.sh --config sui.conf --version v1.58.3

# Use direct download URL (overrides template)
./upgrade.sh --config sui.conf --url https://github.com/MystenLabs/sui/releases/download/mainnet-v1.58.3/sui-mainnet-v1.58.3-ubuntu-x86_64.tgz
```

### Compile Method (Substrate Example)

```bash
# Compile specific git tag/version
./upgrade.sh --config substrate.conf --version v1.0.0

# The script will:
# 1. Go to the git repository directory
# 2. Fetch latest changes
# 3. Checkout the specified version
# 4. Run the build command
# 5. Install compiled binaries
```

### Dry Run Mode

Test your configuration without making any changes:

```bash
./upgrade.sh --config sui.conf --version v1.58.3 --dry-run
```

## Directory Structure

The script creates and uses these directories:

```
$HOME/
├── .blockchain_upgrade_logs/    # Log files (upgrade_YYYYMMDD.log)
├── .blockchain_backups/         # Binary backups (PROJECT_YYYYMMDD_HHMMSS/)
└── your-blockchain/
    └── bin/                     # Download directory
        └── v1.58.3/            # Version-specific subdirectory
```

## Safety Features

### Automatic Backups
- Creates timestamped backups before any upgrade
- Stored in `~/.blockchain_backups/`
- Includes all configured binaries

### Service Management
- Safely stops services before binary replacement
- Starts services after successful installation
- Verifies service started correctly

### Rollback Capability
```bash
./upgrade.sh --config your-blockchain.conf --version rollback
```

### Binary Verification
- Checks binary versions after installation
- Supports common version flags (-V, --version, version)
- Warns if version doesn't match expected

## Logging

All operations are logged with timestamps:

- **Console output**: Colored messages for easy reading
- **Log files**: Stored in `~/.blockchain_upgrade_logs/upgrade_YYYYMMDD.log`
- **Log levels**: INFO, WARN, ERROR, SUCCESS

## Creating New Configurations

1. Copy `template.conf` to your blockchain name (e.g., `mychain.conf`)
2. Edit the configuration values:
   - Update URLs, paths, binary names
   - Choose download or compile method
   - Set correct service name
3. Test with `--dry-run` first

### Finding Binary Locations After Compilation

The script searches for compiled binaries in common locations:
- Current directory
- `bin/` subdirectory
- `build/` subdirectory  
- `target/release/` subdirectory (Rust projects)
- `app/` subdirectory

Use `compiled_binary_path` in config to specify exact location.

## Troubleshooting

### Common Issues

1. **Binary not found after compilation**
   - Check `compiled_binary_path` in config
   - Use `--dry-run` to see where script looks
   - Manually verify binary location after build

2. **Service fails to start**
   - Check service status: `systemctl status your-service`
   - Review service logs: `journalctl -u your-service`
   - Use rollback if needed

3. **Permission errors**
   - Script needs sudo access for `/usr/local/bin/`
   - Ensure user can sudo without password for smooth operation

4. **Download failures**
   - Verify URL template variables
   - Check network connectivity
   - Confirm release exists at specified URL

### Debug Mode

Add `set -x` after the shebang line in `upgrade.sh` for verbose debugging.

## Contributing

When adding support for new blockchains:

1. Create a configuration file following existing examples
2. Test with `--dry-run` first
3. Verify all paths and URLs are correct
4. Test both successful upgrade and rollback

## Security Notes

- Script requires sudo privileges for binary installation
- Always test with `--dry-run` first
- Keep backups of important configurations
- Review download URLs before executing
- Monitor service logs after upgrades

## License

This script is provided as-is for blockchain node management. Use at your own risk and always test in non-production environments first.
