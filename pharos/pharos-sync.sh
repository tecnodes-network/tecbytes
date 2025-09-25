#!/bin/bash

RPC="127.0.0.1:18100"
DATA_FILE="/tmp/sync_monitor.dat"

# Get current timestamp
current_timestamp=$(date +%s)
current_time_readable=$(date)

# Get latest block number
latest_hex=$(curl -s $RPC/ \
  -X POST -H "Content-Type: application/json" \
  --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' | jq -r '.result')

latest_dec=$((latest_hex))

# Get sync info
sync_info=$(curl -s $RPC/ \
  -X POST -H "Content-Type: application/json" \
  --data '{"method":"eth_syncing","params":[],"id":1,"jsonrpc":"2.0"}' | jq -r '.result')

echo "=== Pharos Sync Monitor ==="
echo "Current time: $current_time_readable"
echo ""

if [ "$sync_info" == "false" ]; then
  echo "✅ Node is fully synced!"
  echo "Current block: $latest_dec"

  # Update data file for synced state
  echo "$current_timestamp|$latest_dec|synced" > "$DATA_FILE"

else
  # Parse sync info
  current_block_hex=$(echo $sync_info | jq -r '.currentBlock')
  highest_block_hex=$(echo $sync_info | jq -r '.highestBlock')

  current_block_dec=$((current_block_hex))
  highest_block_dec=$((highest_block_hex))
  blocks_remaining=$((highest_block_dec - current_block_dec))

  echo "🔄 Node is syncing..."
  echo "Current block: $current_block_dec"
  echo "Highest block: $highest_block_dec"
  echo "Blocks remaining: $blocks_remaining"
  echo ""

  # Check if we have previous run data
  if [ -f "$DATA_FILE" ]; then
    # Read previous data
    previous_data=$(cat "$DATA_FILE")
    IFS='|' read -r prev_timestamp prev_block prev_status <<< "$previous_data"

    # Calculate time and block differences
    time_diff=$((current_timestamp - prev_timestamp))
    block_diff=$((current_block_dec - prev_block))

    if [ $time_diff -gt 0 ] && [ $block_diff -gt 0 ]; then
      # Calculate sync rates
      blocks_per_second=$(echo "scale=4; $block_diff / $time_diff" | bc -l)
      blocks_per_minute=$(echo "scale=2; $blocks_per_second * 60" | bc -l)

      # Convert time_diff to readable format
      hours=$((time_diff / 3600))
      minutes=$(((time_diff % 3600) / 60))
      seconds=$((time_diff % 60))

      echo "📊 Sync Statistics (since last run):"
      echo "Time elapsed: ${hours}h ${minutes}m ${seconds}s"
      echo "Blocks synced: $block_diff"
      echo "Avg blocks per second: $blocks_per_second"
      echo "Avg blocks per minute: $blocks_per_minute"
      echo ""

      # Estimate completion time
      if (( $(echo "$blocks_per_second > 0" | bc -l) )); then
        seconds_remaining=$(echo "scale=0; $blocks_remaining / $blocks_per_second" | bc -l)
        completion_timestamp=$((current_timestamp + seconds_remaining))
        completion_time=$(date -d "@$completion_timestamp" 2>/dev/null || date -r "$completion_timestamp" 2>/dev/null || echo "Unable to calculate")

        # Convert remaining time to readable format
        days=$((seconds_remaining / 86400))
        hours=$(((seconds_remaining % 86400) / 3600))
        minutes=$(((seconds_remaining % 3600) / 60))
        secs=$((seconds_remaining % 60))

        echo "⏱️  Estimated completion:"
        echo "Time remaining: ${days}d ${hours}h ${minutes}m ${secs}s"
        echo "Estimated completion: $completion_time"
      else
        echo "⚠️  Unable to estimate completion time (no sync progress detected)"
      fi
    else
      echo "ℹ️  First run or no progress since last check"
    fi
  else
    echo "ℹ️  First run - no previous data available"
  fi

  # Update data file
  echo "$current_timestamp|$current_block_dec|syncing" > "$DATA_FILE"
fi

echo ""
echo "Data stored in: $DATA_FILE"
