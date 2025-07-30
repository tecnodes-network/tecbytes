#!/bin/bash

# Function to create screen, windows, and run commands
create_screen() {
    local screen_name=$1
    local cmd0=$2
    local cmd1=$3

    echo "Setting up screen: $screen_name"

    # Start screen session in detached mode
    screen -dmS "$screen_name"

    # Send command to window 0
    screen -S "$screen_name" -p 0 -X stuff "$cmd0"
    screen -S "$screen_name" -p 0 -X stuff $'\n'

    # Create window 1 and send command
    screen -S "$screen_name" -X screen
    screen -S "$screen_name" -p 1 -X stuff "$cmd1"
    screen -S "$screen_name" -p 1 -X stuff $'\n'
}

# Cross-fi
create_screen "Cross-fi" \
"sudo journalctl -u crossfid.service -f -o cat" \
"curl localhost:36657/status | jq"

# Jackal
create_screen "Jackal" \
"sudo journalctl -u jackal.service -f --no-hostname -o cat | ccze -A" \
"curl localhost:13757/status | jq"

# Seda
create_screen "Seda" \
"sudo journalctl -u sedad -f -o cat" \
"curl localhost:46657/status | jq"

# Supra
create_screen "Supra" \
"tail -f ~/supra/round6/supra_rpc_configs/rpc_node_logs/rpc_node.log" \
"cd ~/supra/round6/supra_rpc_configs/rpc_node_logs"
