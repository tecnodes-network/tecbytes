# Cosmos node installer

## Features
Modular Design: Choose specific operations instead of going through the full installation process
Full Node Installation: Complete setup from scratch
Node Synchronization: Fast sync using snapshots or state-sync
Caddy Configuration: Expose RPC, API, and gRPC endpoints
Prerequisites Installation: Go and Cosmovisor setup
Node Configuration: Genesis, peers, seeds, and pruning setup
Cosmovisor Setup: Automatic upgrades configuration

## Run
```
python3 main.py --config /path/to/your/config.yaml
```
## Tip
```
python3 -m zipapp cosmoinstaller -o cosmoi.pyz -m "main:main"
echo '#!/usr/bin/env python3' | cat  - cosmoi.pyz > cosmoi
./cosmoi --config celestia.yaml
```

## Updates
 Fix naming conflict between sync_node() method and sync_node_config variable
 Fix gRPC and API settings in app.toml to ensure they're enabled and ports are properly set
 Correct Caddy domain configuration to avoid domain duplication
 Add menu option to start/enable the service
 Add menu option to show the chain logs
 Test and validate all changes
 Deliver final updated code
