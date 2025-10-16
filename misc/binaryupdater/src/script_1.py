# Create example configuration files for different blockchain types

# Sui configuration (download method)
sui_config = '''# Sui Blockchain Configuration
project_name: sui
download_dir: ~/sui/bin
binary_dir: /usr/local/bin
service_name: sui-mainnet.service
binary_names: sui,sui-tool,sui-node
platform: ubuntu-x86_64
upgrade_method: download
download_url_template: https://github.com/MystenLabs/sui/releases/download/mainnet-{VERSION}/sui-mainnet-{VERSION}-{PLATFORM}.tgz

# For compile method (alternative)
# upgrade_method: compile
# git_repo_dir: ~/sui/source
# build_command: cargo build --release
# compiled_binary_path: target/release
'''

# Cosmos-based node configuration (download method)
cosmos_config = '''# Cosmos Gaia Configuration  
project_name: gaia
download_dir: ~/cosmos/bin
binary_dir: /usr/local/bin
service_name: gaiad.service
binary_names: gaiad
platform: linux-amd64
upgrade_method: download
download_url_template: https://github.com/cosmos/gaia/releases/download/{VERSION}/gaiad-{VERSION}-{PLATFORM}

# For compile method (alternative)
# upgrade_method: compile
# git_repo_dir: ~/cosmos/gaia
# build_command: make build
# compiled_binary_path: build
'''

# Substrate-based node configuration (compile method)
substrate_config = '''# Substrate-based Node Configuration (Polkadot example)
project_name: polkadot
download_dir: ~/polkadot/bin
binary_dir: /usr/local/bin
service_name: polkadot.service
binary_names: polkadot
platform: ubuntu-x86_64
upgrade_method: compile
git_repo_dir: ~/polkadot/source
build_command: cargo build --release
compiled_binary_path: target/release

# For download method (if available)
# upgrade_method: download
# download_url_template: https://github.com/paritytech/polkadot/releases/download/{VERSION}/polkadot-{PLATFORM}
'''

# Osmosis configuration (compile method)
osmosis_config = '''# Osmosis Configuration
project_name: osmosis
download_dir: ~/osmosis/bin
binary_dir: /usr/local/bin
service_name: osmosisd.service
binary_names: osmosisd
platform: linux-amd64
upgrade_method: compile
git_repo_dir: ~/osmosis/source
build_command: make build
compiled_binary_path: build

# For download method (alternative)
# upgrade_method: download
# download_url_template: https://github.com/osmosis-labs/osmosis/releases/download/{VERSION}/osmosisd-{VERSION}-{PLATFORM}
'''

# Generic template configuration
template_config = '''# Generic Blockchain Configuration Template
# Copy this file and customize for your blockchain

project_name: YOUR_PROJECT_NAME
download_dir: ~/YOUR_PROJECT/bin
binary_dir: /usr/local/bin
service_name: YOUR_SERVICE.service
binary_names: your-binary,other-binary  # comma-separated if multiple
platform: ubuntu-x86_64
upgrade_method: download  # or 'compile'

# For download method
download_url_template: https://github.com/YOUR_ORG/YOUR_REPO/releases/download/{VERSION}/YOUR_BINARY-{VERSION}-{PLATFORM}.tar.gz

# For compile method
# git_repo_dir: ~/YOUR_PROJECT/source
# build_command: make build  # or 'cargo build --release', etc.
# compiled_binary_path: build  # relative path from git_repo_dir where binaries are located

# Notes:
# - {VERSION} will be replaced with the version you specify
# - {PLATFORM} will be replaced with the platform value above
# - Paths starting with ~ will be expanded to your home directory
# - binary_names can be single binary or comma-separated list
# - service_name is optional - leave empty if no systemd service
'''

# Save all config files
configs = {
    'sui.conf': sui_config,
    'cosmos.conf': cosmos_config,
    'substrate.conf': substrate_config,
    'osmosis.conf': osmosis_config,
    'template.conf': template_config
}

for filename, content in configs.items():
    with open(filename, 'w') as f:
        f.write(content)

print("✅ Created configuration files:")
for filename in configs.keys():
    print(f"   - {filename}")