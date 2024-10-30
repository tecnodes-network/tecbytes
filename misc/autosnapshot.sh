#!/bin/bash

# Configuration Variables
HOME_DIR="~/avail"
DATA_DIR="$HOME_DIR/data"
SNAPSHOT_DIR="$HOME_DIR/snapshots"
WEB_SNAPSHOT_DIR="/var/www/html/avail/snapshots"
NODE_SERVICE_NAME="avail.service"
RPC_PORT=9944

# Ensure the snapshot directory exists
mkdir -p "$SNAPSHOT_DIR"

# Function to get the latest block number from the running node
get_latest_block() {
    echo "Fetching the latest block number..."
    BLOCK_NUMBER=$(curl -s -H "Content-Type: application/json" -d \
    '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' \
    http://localhost:$RPC_PORT | jq -r '.result.number' | xargs printf "%d\n")
    echo "Latest block number: $BLOCK_NUMBER"
}

# Get the latest block number before stopping the node
get_latest_block

# Stop the Avail node
echo "Stopping the Avail node service..."
sudo systemctl stop "$NODE_SERVICE_NAME"

# Verify the node has stopped
if ! systemctl is-active --quiet "$NODE_SERVICE_NAME"; then
    echo "Node stopped successfully."
else
    echo "Failed to stop the node. Exiting."
    exit 1
fi

# Create a timestamp for the snapshot filenames
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Snapshot filename
SNAPSHOT_FILE="avail_data_snapshot_latest.tar.lz4"

# Create a compressed snapshot of the data directory excluding keystore and network
echo "Creating a compressed snapshot of the data directory..."
tar \
    --exclude='chains/avail_da_mainnet/keystore' \
    --exclude='chains/avail_da_mainnet/network' \
    -cf - -C "$DATA_DIR" . | lz4 - "$SNAPSHOT_DIR/$SNAPSHOT_FILE"

if [ $? -eq 0 ]; then
    echo "Snapshot created successfully: $SNAPSHOT_DIR/$SNAPSHOT_FILE"
else
    echo "Snapshot creation failed. Exiting."
    sudo systemctl start "$NODE_SERVICE_NAME"
    exit 1
fi

# Get the size of the snapshot file in bytes
SNAPSHOT_SIZE=$(stat -c%s "$SNAPSHOT_DIR/$SNAPSHOT_FILE")
echo "Snapshot size: $SNAPSHOT_SIZE bytes"

# Record the datetime
DATETIME=$(date -Iseconds)

# Create JSON file with snapshot information
JSON_FILE="$SNAPSHOT_DIR/snapshot_info_latest.json"
echo "Writing snapshot information to JSON file..."
cat <<EOF > "$JSON_FILE"
{
    "snapshot_file": "$SNAPSHOT_FILE",
    "latest_block": $BLOCK_NUMBER,
    "datetime": "$DATETIME",
    "snapshot_size": $SNAPSHOT_SIZE
}
EOF

echo "Snapshot information saved to: $JSON_FILE"

# Move the snapshot and JSON file to the web server directory
echo "Moving snapshot files to web server directory..."
sudo mkdir -p "$WEB_SNAPSHOT_DIR"
sudo mv "$SNAPSHOT_DIR/$SNAPSHOT_FILE" "$WEB_SNAPSHOT_DIR/"
sudo mv "$JSON_FILE" "$WEB_SNAPSHOT_DIR/"

# Set appropriate permissions
#sudo chmod 644 "$WEB_SNAPSHOT_DIR/$SNAPSHOT_FILE"
#sudo chmod 644 "$WEB_SNAPSHOT_DIR/$(basename "$JSON_FILE")"

# Update symlink to the latest snapshot
echo "Updating symlink to the latest snapshot..."
#sudo ln -sf "$WEB_SNAPSHOT_DIR/$SNAPSHOT_FILE" "$WEB_SNAPSHOT_DIR/avail_data_snapshot_latest.tar.lz4"
#sudo ln -sf "$WEB_SNAPSHOT_DIR/$(basename "$JSON_FILE")" "$WEB_SNAPSHOT_DIR/snapshot_info_latest.json"

echo "Snapshot files moved to: $WEB_SNAPSHOT_DIR"

# Start the Avail node
echo "Starting the Avail node service..."
sudo systemctl start "$NODE_SERVICE_NAME"

# Verify the node has started
if systemctl is-active --quiet "$NODE_SERVICE_NAME"; then
    echo "Node started successfully."
else
    echo "Failed to start the node."
fi

echo "Snapshot process completed."
