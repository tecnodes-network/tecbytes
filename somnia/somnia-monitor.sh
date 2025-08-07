#!/bin/bash

# Somnia Network Validator Monitoring Script
# Monitors validator status and block sync

# Configuration
METRICS_URL="http://localhost:9004/metrics"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/xxx"
NODE_NAME="Tecnodes Testnet Validator"
STATE_FILE="/tmp/somnia_monitor_state"
LOCK_FILE="/tmp/somnia_monitor.lock"

# Node Type Configuration
# Set to "validator" for validator nodes or "fullnode" for regular full nodes
# Validator nodes: Monitor both block sync AND validator status (in_current_epoch)
# Full nodes: Monitor only block sync (skip in_current_epoch checks)
NODE_TYPE="validator"  # Change to "fullnode" for non-validator nodes

# External RPC Configuration
EXTERNAL_RPC_CHECK="yes"                                    # Enable/disable external RPC comparison (yes/no)
EXTERNAL_RPCS="https://api.infra.mainnet.somnia.network"    # Comma-separated RPC URLs
BLOCK_LAG_THRESHOLD=120                                     # Blocks behind before WARNING alert
RPC_TIMEOUT=10                                              # Timeout for RPC calls (seconds)
MIN_SUCCESSFUL_RPCS=1                                       # Minimum successful RPC responses needed

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to send Discord notification
send_discord_alert() {
    local title="$1"
    local description="$2"
    local color="$3"  # 16711680 = red, 16776960 = yellow, 65280 = green
    
    local payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$title",
        "description": "$description",
        "color": $color,
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
        "footer": {
            "text": "$NODE_NAME"
        },
        "fields": [
            {
                "name": "Node",
                "value": "$NODE_NAME",
                "inline": true
            },
            {
                "name": "Time",
                "value": "$(date '+%Y-%m-%d %H:%M:%S UTC')",
                "inline": true
            }
        ]
    }]
}
EOF
    )
    
    curl -s -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK" > /dev/null
    if [ $? -eq 0 ]; then
        log "${GREEN}Discord notification sent: $title${NC}"
    else
        log "${RED}Failed to send Discord notification${NC}"
    fi
}

# Function to check if script is already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "${YELLOW}Script already running (PID: $pid), exiting${NC}"
            exit 0
        else
            log "${YELLOW}Removing stale lock file${NC}"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
}

# Function to fetch metric value
get_metric() {
    local metric_name="$1"
    curl -s "$METRICS_URL" | grep "^$metric_name " | awk '{print $2}'
}

# Function to convert hex to decimal
hex_to_decimal() {
    local hex_value="$1"
    # Remove 0x prefix if present
    hex_value=${hex_value#0x}
    # Convert to decimal
    echo $((16#$hex_value))
}

# Function to query external RPC for block height
get_external_block_height() {
    local rpc_url="$1"
    local response
    
    # Query with timeout
    response=$(curl -s --max-time $RPC_TIMEOUT \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        -H "Content-Type: application/json" \
        "$rpc_url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Extract result field and convert hex to decimal
        local hex_block=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$hex_block" ] && [[ "$hex_block" =~ ^0x[0-9a-fA-F]+$ ]]; then
            hex_to_decimal "$hex_block"
            return 0
        fi
    fi
    
    return 1
}

# Function to get network block height from multiple RPCs
get_network_block_height() {
    local IFS=','
    local rpcs=($EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_block=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)  # Trim whitespace
        if [ -n "$rpc" ]; then
            local block_height
            if block_height=$(get_external_block_height "$rpc"); then
                ((successful_rpcs++))
                if [ "$block_height" -gt "$highest_block" ]; then
                    highest_block=$block_height
                fi
                rpc_results+="✅ $rpc: $block_height\n"
                # Log to stderr to avoid interfering with function return value
                log "${GREEN}RPC Success: $rpc returned block $block_height${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                # Log to stderr to avoid interfering with function return value
                log "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    # Store results for potential error reporting
    LAST_RPC_RESULTS="$rpc_results"
    LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge $MIN_SUCCESSFUL_RPCS ]; then
        echo $highest_block
        return 0
    else
        return 1
    fi
}

# Function to read previous state
read_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        PREV_BLOCK_HEIGHT=0
        PREV_EPOCH_STATUS=1
        PREV_CHECK_TIME=0
        CONSECUTIVE_FAILS=0
        PREV_NETWORK_BLOCK=0
        CONSECUTIVE_RPC_FAILS=0
        PREV_BLOCK_LAG=0
    fi
    
    # For full nodes, epoch status is not relevant
    if [ "$NODE_TYPE" = "fullnode" ]; then
        PREV_EPOCH_STATUS="N/A"
    fi
}

# Function to write current state
write_state() {
    cat > "$STATE_FILE" << EOF
PREV_BLOCK_HEIGHT=$1
PREV_EPOCH_STATUS=$2
PREV_CHECK_TIME=$3
CONSECUTIVE_FAILS=$4
PREV_NETWORK_BLOCK=$5
CONSECUTIVE_RPC_FAILS=$6
PREV_BLOCK_LAG=$7
EOF
}

# Main monitoring function
monitor_node() {
    local current_time=$(date +%s)
    
    # Fetch current metrics
    local current_block_height=$(get_metric "ledger_block_number")
    local current_epoch_status="N/A"
    
    # Only check validator status for validator nodes
    if [ "$NODE_TYPE" = "validator" ]; then
        current_epoch_status=$(get_metric "in_current_epoch")
    fi
    
    # Validate metrics were fetched
    if [ -z "$current_block_height" ] || ([ "$NODE_TYPE" = "validator" ] && [ -z "$current_epoch_status" ]); then
        log "${RED}CRITICAL: Failed to fetch metrics from $METRICS_URL${NC}"
        ((CONSECUTIVE_FAILS++))
        
        local node_type_desc=$([ "$NODE_TYPE" = "validator" ] && echo "Validator Node" || echo "Full Node")
        
        # Send immediate alert on first failure (critical issue)
        if [ $CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "🚨 CRITICAL: Node Metrics Unavailable" \
                "**URGENT: Node appears to be DOWN!**\n\nUnable to fetch metrics from $node_type_desc.\n\n**Node Type:** $node_type_desc\n**Metrics URL:** $METRICS_URL\n**Status:** Node may be completely down or metrics port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if node process is running\n• Verify metrics port is accessible\n• Check system resources\n• Review node logs" \
                16711680
        # Follow-up alerts for persistent failures
        elif [ $CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "🚨 CRITICAL: Node Still Down" \
                "Node has been unresponsive for $CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Still unable to fetch metrics\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $CONSECUTIVE_FAILS -eq 12 ]; then  # ~1 hour
            send_discord_alert "🚨 CRITICAL: Node Down for 1+ Hour" \
                "Node has been unresponsive for over 1 hour ($CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Extended outage detected\n\n**THIS MAY RESULT IN SLASHING PENALTIES**" \
                16711680
        fi
        
        write_state "$PREV_BLOCK_HEIGHT" "$PREV_EPOCH_STATUS" "$current_time" "$CONSECUTIVE_FAILS" "$PREV_NETWORK_BLOCK" "$CONSECUTIVE_RPC_FAILS" "$PREV_BLOCK_LAG"
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((CONSECUTIVE_FAILS * 5))
        local node_type_desc=$([ "$NODE_TYPE" = "validator" ] && echo "Validator Node" || echo "Full Node")
        
        send_discord_alert "✅ Node Recovered" \
            "$node_type_desc is back online and responding.\n\n**Outage Duration:** ~${outage_duration} minutes ($CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Block:** $current_block_height" \
            65280
        
        log "${GREEN}Node recovered after $CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    CONSECUTIVE_FAILS=0
    
    # External RPC comparison (if enabled)
    local current_network_block=0
    local current_block_lag=0
    local network_status=""
    
    if [ "$EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_block=$(get_network_block_height); then
            # Reset RPC fails and send recovery notification if needed
            if [ $CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "✅ External RPC Endpoints Recovered" \
                    "External RPC endpoints are responding again.\n\n**Outage Duration:** $CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Block:** $current_network_block" \
                    65280
                
                log "${GREEN}External RPCs recovered after $CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            CONSECUTIVE_RPC_FAILS=0
            
            current_block_lag=$((current_network_block - current_block_height))
            
            if [ $current_block_lag -gt 0 ]; then
                network_status=" (${current_block_lag} blocks behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "${GREEN}Network comparison: Local=$current_block_height, Network=$current_network_block$network_status${NC}"
            
            # Check for significant block lag
            if [ $current_block_lag -gt $BLOCK_LAG_THRESHOLD ]; then
                # Check if lag is increasing (getting worse)
                local lag_trend=""
                if [ $PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -gt $PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag increasing: was $PREV_BLOCK_LAG blocks behind)"
                elif [ $PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -lt $PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag decreasing: was $PREV_BLOCK_LAG blocks behind, catching up)"
                fi
                
                local node_type_desc=$([ "$NODE_TYPE" = "validator" ] && echo "Validator" || echo "Full Node")
                local status_info=""
                
                if [ "$NODE_TYPE" = "validator" ]; then
                    status_info="**Validator Status:** $([ "$current_epoch_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                fi
                
                # Only alert if lag is significant and not improving rapidly
                if [ $current_block_lag -gt $((BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_block_lag -gt $PREV_BLOCK_LAG ]; then
                    send_discord_alert "⚠️ WARNING: Node Falling Behind Network" \
                        "Node is significantly behind the network.\n\n**Node Type:** $node_type_desc\n**Local Block:** $current_block_height\n**Network Block:** $current_network_block\n**Blocks Behind:** $current_block_lag$lag_trend\n$status_info\n**Successful RPCs:** $LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((CONSECUTIVE_RPC_FAILS++))
            log "${YELLOW}Failed to fetch network block height from external RPCs (attempt $CONSECUTIVE_RPC_FAILS)${NC}"
            
            # Send immediate alert on first RPC failure
            if [ $CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "⚠️ WARNING: External RPC Endpoints Unreachable" \
                    "Cannot fetch network block height for comparison.\n\n**Impact:** Unable to detect if node is falling behind network\n**RPC Results:**\n$LAST_RPC_RESULTS\n**Local monitoring continues:** Block sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            # Alert for persistent RPC failures
            elif [ $CONSECUTIVE_RPC_FAILS -eq 6 ]; then  # ~30 minutes
                send_discord_alert "⚠️ WARNING: External RPCs Down for 30+ Minutes" \
                    "External RPC endpoints have been unavailable for $CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues\n\n**Consider checking:**\n• Network connectivity\n• RPC endpoint status\n• Firewall/proxy settings" \
                    16776960
            fi
            
            # Keep previous values for network comparison
            current_network_block=$PREV_NETWORK_BLOCK
            current_block_lag=$PREV_BLOCK_LAG
        fi
    fi
    
    # Log current status based on node type
    if [ "$NODE_TYPE" = "validator" ]; then
        log "${GREEN}Current Status: Epoch=$current_epoch_status, Block=$current_block_height$network_status${NC}"
    else
        log "${GREEN}Current Status: Block=$current_block_height (Full Node)$network_status${NC}"
    fi
    
    # Check validator status only for validator nodes
    if [ "$NODE_TYPE" = "validator" ]; then
        # Check if validator is out of active set (CRITICAL)
        if [ "$current_epoch_status" = "0" ] && [ "$PREV_EPOCH_STATUS" = "1" ]; then
            send_discord_alert "🚨 CRITICAL: Validator Removed from Active Set" \
                "**URGENT ACTION REQUIRED**\n\nValidator has been removed from the active validator set!\n\n**Current Status:** Out of active set (0)\n**Previous Status:** In active set (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check validator logs\n• Verify staking requirements\n• Check slashing conditions\n• Review uptime metrics" \
                16711680
                
        elif [ "$current_epoch_status" = "1" ] && [ "$PREV_EPOCH_STATUS" = "0" ]; then
            send_discord_alert "✅ Validator Restored to Active Set" \
                "Validator has been restored to the active validator set.\n\n**Current Status:** In active set (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                65280
        fi
    fi
    
    # Check local block progression (applies to both validator and full nodes)
    if [ $PREV_BLOCK_HEIGHT -gt 0 ] && [ $((current_time - PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_block_height" -le "$PREV_BLOCK_HEIGHT" ]; then
            local time_diff=$((current_time - PREV_CHECK_TIME))
            local node_type_desc=$([ "$NODE_TYPE" = "validator" ] && echo "Validator" || echo "Full Node")
            local status_info=""
            
            if [ "$NODE_TYPE" = "validator" ]; then
                status_info="**Validator Status:** $([ "$current_epoch_status" = "1" ] && echo "Active" || echo "Inactive")\n"
            fi
            
            local network_info=""
            if [ "$EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_block -gt 0 ]; then
                network_info="**Network Block:** $current_network_block\n**Network is Progressing:** $([ $current_network_block -gt $PREV_NETWORK_BLOCK ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "⚠️ WARNING: Local Block Sync Stalled" \
                "Local node has stopped producing/syncing new blocks.\n\n**Node Type:** $node_type_desc\n**Current Block:** $current_block_height\n**Previous Block:** $PREV_BLOCK_HEIGHT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info$status_info\n**Possible causes:**\n• Node synchronization problems\n• Consensus issues\n• Local node malfunction" \
                16776960
        else
            local blocks_synced=$((current_block_height - PREV_BLOCK_HEIGHT))
            local time_diff=$((current_time - PREV_CHECK_TIME))
            local blocks_per_min=$(echo "scale=2; $blocks_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "${GREEN}Local blocks syncing normally: +$blocks_synced blocks in ${time_diff}s (${blocks_per_min} blocks/min)${NC}"
        fi
    fi
    
    # Save current state
    write_state "$current_block_height" "$current_epoch_status" "$current_time" "$CONSECUTIVE_FAILS" "$current_network_block" "$CONSECUTIVE_RPC_FAILS" "$current_block_lag"
}

# Main execution
main() {
    local node_type_desc=$([ "$NODE_TYPE" = "validator" ] && echo "Validator Node" || echo "Full Node")
    local rpc_status=$([ "$EXTERNAL_RPC_CHECK" = "yes" ] && echo "with External RPC Comparison" || echo "Local Only")
    log "${GREEN}Starting Somnia Network monitoring for $node_type_desc ($rpc_status)...${NC}"
    
    # Validate NODE_TYPE
    if [ "$NODE_TYPE" != "validator" ] && [ "$NODE_TYPE" != "fullnode" ]; then
        log "${RED}ERROR: NODE_TYPE must be 'validator' or 'fullnode'. Current value: '$NODE_TYPE'${NC}"
        exit 1
    fi
    
    # Validate EXTERNAL_RPC_CHECK
    if [ "$EXTERNAL_RPC_CHECK" != "yes" ] && [ "$EXTERNAL_RPC_CHECK" != "no" ]; then
        log "${RED}ERROR: EXTERNAL_RPC_CHECK must be 'yes' or 'no'. Current value: '$EXTERNAL_RPC_CHECK'${NC}"
        exit 1
    fi
    
    # Validate external RPC configuration if enabled
    if [ "$EXTERNAL_RPC_CHECK" = "yes" ]; then
        if [ -z "$EXTERNAL_RPCS" ]; then
            log "${RED}ERROR: EXTERNAL_RPCS cannot be empty when EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        # Count RPCs
        local IFS=','
        local rpcs=($EXTERNAL_RPCS)
        local rpc_count=${#rpcs[@]}
        log "${GREEN}External RPC comparison enabled: $rpc_count RPC(s) configured${NC}"
        log "${GREEN}Block lag threshold: $BLOCK_LAG_THRESHOLD blocks${NC}"
    else
        log "${YELLOW}External RPC comparison disabled${NC}"
    fi
    
    # Set up cleanup on exit
    trap cleanup EXIT
    
    # Check if already running
    check_lock
    
    # Read previous state
    read_state
    
    # Run monitoring
    monitor_node
    
    log "${GREEN}Monitoring check completed for $node_type_desc${NC}"
}

# Run main function
main "$@"
