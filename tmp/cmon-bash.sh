#!/bin/bash

# Multi-Chain Blockchain Monitoring Script
# Supports: Somnia, SUI, EVM-compatible chains, Substrate chains

# ================================
# GLOBAL CONFIGURATION
# ================================
NODE_NAME="TecNodes-Server-1"                              # Server/Node identifier
DISCORD_WEBHOOK="https://discord.com/api/webhooks/"
HEARTBEAT_URL=""                                            # Healthchecks.io URL (optional)

# ================================
# CHAIN ENABLEMENT
# ================================
ENABLE_SOMNIA="yes"                                         # Enable Somnia monitoring (yes/no)
ENABLE_SUI="no"                                             # Enable SUI monitoring (yes/no)
ENABLE_EVM="no"                                             # Enable EVM monitoring (yes/no)
ENABLE_SUBSTRATE="no"                                       # Enable Substrate monitoring (yes/no)
ENABLE_COSMOS="no"                                          # Enable Cosmos monitoring (yes/no)

# ================================
# SOMNIA CONFIGURATION
# ================================
SOMNIA_TYPE="validator"                                     # validator/fullnode
SOMNIA_METRICS_URL="http://localhost:9004/metrics"         # Local metrics endpoint
SOMNIA_EXTERNAL_RPC_CHECK="yes"                            # Enable external RPC comparison (yes/no)
SOMNIA_EXTERNAL_RPCS="https://api.infra.mainnet.somnia.network"  # Comma-separated RPC URLs
SOMNIA_BLOCK_LAG_THRESHOLD=120                             # Blocks behind before WARNING alert
SOMNIA_RPC_TIMEOUT=10                                      # Timeout for RPC calls (seconds)
SOMNIA_MIN_SUCCESSFUL_RPCS=1                               # Minimum successful RPC responses needed

# ================================
# SUI CONFIGURATION (Future)
# ================================
SUI_TYPE="fullnode"                                        # validator/fullnode
SUI_RPC_URL="http://localhost:9000"                       # Local SUI RPC
SUI_EXTERNAL_RPC_CHECK="yes"                              # Enable external RPC comparison
SUI_EXTERNAL_RPCS="https://fullnode.mainnet.sui.io"       # Comma-separated RPC URLs
SUI_BLOCK_LAG_THRESHOLD=100                               # Checkpoints behind before alert

# ================================
# EVM CONFIGURATION (Future)
# ================================
EVM_CHAIN_NAME="Ethereum"                                 # Chain identifier
EVM_RPC_URL="http://localhost:8545"                       # Local EVM RPC
EVM_EXTERNAL_RPC_CHECK="yes"                              # Enable external RPC comparison
EVM_EXTERNAL_RPCS="https://eth.llamarpc.com"              # Comma-separated RPC URLs
EVM_BLOCK_LAG_THRESHOLD=5                                 # Blocks behind before alert

# ================================
# SUBSTRATE CONFIGURATION (Future)
# ================================
SUBSTRATE_CHAIN_NAME="Avail"                              # Chain identifier
SUBSTRATE_TYPE="validator"                                 # validator/fullnode
SUBSTRATE_RPC_URL="http://localhost:9933"                 # Local Substrate RPC
SUBSTRATE_EXTERNAL_RPC_CHECK="yes"                        # Enable external RPC comparison
SUBSTRATE_EXTERNAL_RPCS="https://mainnet.avail.tools"     # Comma-separated RPC URLs
SUBSTRATE_BLOCK_LAG_THRESHOLD=10                          # Blocks behind before alert

# Substrate Validator Configuration (Option C: Manual + Auto-detection)
SUBSTRATE_VALIDATOR_STASH=""                              # Manual stash address (optional, leave empty for auto-detection)
SUBSTRATE_STAKE_THRESHOLD_PERCENT=10                      # Alert if stake drops by this percentage
SUBSTRATE_MIN_STAKE_ALERT=50000                           # Alert if total stake below this amount (in chain units)

# Substrate Chain Parameters (Auto-detected, leave empty for auto-detection)
SUBSTRATE_MAX_VALIDATORS=0                                # Maximum validators in active set (auto-detect or manual)
SUBSTRATE_TOKEN_DECIMALS=0                                # Token decimals (auto-detect or manual: 18 for Avail)
SUBSTRATE_TOKEN_SYMBOL=""                                 # Token symbol (auto-detect or manual: AVAIL)
SUBSTRATE_POSITION_WARNING_THRESHOLD=10                   # Warn when within this many positions of falling out

# ================================
# COSMOS CONFIGURATION
# ================================
COSMOS_CHAIN_NAME="Cosmos Hub"                            # Chain identifier (e.g., "Cosmos Hub", "Osmosis", "Juno")
COSMOS_TYPE="validator"                                   # validator/fullnode
COSMOS_RPC_URL="http://localhost:26657"                  # Local Cosmos RPC
COSMOS_REST_URL="http://localhost:1317"                  # Local Cosmos REST API
COSMOS_EXTERNAL_RPC_CHECK="yes"                          # Enable external RPC comparison
COSMOS_EXTERNAL_RPCS="https://cosmos-rpc.polkachu.com"   # Comma-separated RPC URLs
COSMOS_BLOCK_LAG_THRESHOLD=5                             # Blocks behind before alert

# Cosmos Chain Parameters (Auto-detected, leave empty for auto-detection)
COSMOS_DENOM=""                                          # Base denomination (auto-detect or manual: uatom, uosmo, ujuno)
COSMOS_DENOM_EXPONENT=0                                  # Decimal places (auto-detect or manual: 6 for ATOM, OSMO)
COSMOS_MAX_VALIDATORS=0                                  # Maximum validators in active set (auto-detect or manual: 180 for Cosmos Hub)

# Cosmos Validator Configuration
COSMOS_VALIDATOR_ADDRESS=""                               # Validator operator address (cosmosvaloper...)
COSMOS_STAKE_THRESHOLD_PERCENT=5                         # Alert if stake drops by this percentage
COSMOS_MIN_STAKE_ALERT=100000                            # Alert if total stake below this amount (in base units)
COSMOS_POSITION_WARNING_THRESHOLD=20                     # Warn when within this many positions of falling out

# ================================
# SYSTEM CONFIGURATION
# ================================
STATE_FILE="/tmp/multi_chain_monitor_state"
LOCK_FILE="/tmp/multi_chain_monitor.lock"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================================
# UTILITY FUNCTIONS
# ================================

# Function to log with timestamp and chain info
log() {
    local chain="$1"
    local message="$2"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$chain] $message"
}

# Function to send Discord notification with chain identification
send_discord_alert() {
    local chain="$1"
    local title="$2"
    local description="$3"
    local color="$4"  # 16711680 = red, 16776960 = yellow, 65280 = green
    
    local payload=$(cat <<EOF
{
    "embeds": [{
        "title": "[$chain] $title",
        "description": "$description",
        "color": $color,
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
        "footer": {
            "text": "$NODE_NAME"
        },
        "fields": [
            {
                "name": "Server",
                "value": "$NODE_NAME",
                "inline": true
            },
            {
                "name": "Chain",
                "value": "$chain",
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
        log "$chain" "${GREEN}Discord notification sent: $title${NC}"
    else
        log "$chain" "${RED}Failed to send Discord notification${NC}"
    fi
}
}

# Function to send heartbeat
send_heartbeat() {
    if [ -n "$HEARTBEAT_URL" ]; then
        local enabled_chains=""
        [ "$ENABLE_SOMNIA" = "yes" ] && enabled_chains+="SOMNIA "
        [ "$ENABLE_SUI" = "yes" ] && enabled_chains+="SUI "
        [ "$ENABLE_EVM" = "yes" ] && enabled_chains+="EVM "
        [ "$ENABLE_SUBSTRATE" = "yes" ] && enabled_chains+="SUBSTRATE "
        [ "$ENABLE_COSMOS" = "yes" ] && enabled_chains+="COSMOS "
        
        # Send heartbeat with enabled chains info
        curl -s --max-time 10 --retry 3 \
            --data-urlencode "msg=Monitoring: $enabled_chains" \
            "$HEARTBEAT_URL" > /dev/null
        
        if [ $? -eq 0 ]; then
            log "SYSTEM" "${GREEN}Heartbeat sent successfully${NC}"
        else
            log "SYSTEM" "${YELLOW}Failed to send heartbeat${NC}"
        fi
    fi
}

# Function to check if script is already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "SYSTEM" "${YELLOW}Script already running (PID: $pid), exiting${NC}"
            exit 0
        else
            log "SYSTEM" "${YELLOW}Removing stale lock file${NC}"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
}

# ================================
# AUTO-DETECTION FUNCTIONS
# ================================

# Function to auto-detect Cosmos chain parameters
detect_cosmos_chain_params() {
    log "$COSMOS_CHAIN_NAME" "${BLUE}Auto-detecting chain parameters...${NC}"
    
    # Detect staking parameters (denom and max validators)
    local staking_params_response=$(query_cosmos_rest "$COSMOS_REST_URL" "cosmos/staking/v1beta1/params" 10)
    
    if [ $? -eq 0 ] && [ -n "$staking_params_response" ]; then
        # Extract bond_denom
        local detected_denom=$(echo "$staking_params_response" | grep -o '"bond_denom":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$detected_denom" ]; then
            COSMOS_DETECTED_DENOM="$detected_denom"
            log "$COSMOS_CHAIN_NAME" "${GREEN}Auto-detected denom: $detected_denom${NC}"
        fi
        
        # Extract max_validators
        local detected_max_validators=$(echo "$staking_params_response" | grep -o '"max_validators":[0-9]*' | cut -d':' -f2)
        if [ -n "$detected_max_validators" ] && [ "$detected_max_validators" -gt 0 ]; then
            COSMOS_DETECTED_MAX_VALIDATORS="$detected_max_validators"
            log "$COSMOS_CHAIN_NAME" "${GREEN}Auto-detected max validators: $detected_max_validators${NC}"
        fi
    else
        log "$COSMOS_CHAIN_NAME" "${YELLOW}Failed to detect staking parameters${NC}"
    fi
    
    # Detect denom metadata for exponent (only if we detected the denom)
    if [ -n "$COSMOS_DETECTED_DENOM" ]; then
        local metadata_response=$(query_cosmos_rest "$COSMOS_REST_URL" "cosmos/bank/v1beta1/denoms_metadata/$COSMOS_DETECTED_DENOM" 10)
        
        if [ $? -eq 0 ] && [ -n "$metadata_response" ]; then
            # Find the display denomination and its exponent
            local detected_exponent=$(echo "$metadata_response" | grep -A10 '"display"' | grep -o '"exponent":[0-9]*' | cut -d':' -f2 | head -1)
            if [ -n "$detected_exponent" ] && [ "$detected_exponent" -ge 0 ]; then
                COSMOS_DETECTED_DENOM_EXPONENT="$detected_exponent"
                log "$COSMOS_CHAIN_NAME" "${GREEN}Auto-detected denom exponent: $detected_exponent${NC}"
            else
                # Fallback: common patterns
                case "$COSMOS_DETECTED_DENOM" in
                    "uatom"|"uosmo"|"ujuno"|"ustars") COSMOS_DETECTED_DENOM_EXPONENT=6 ;;
                    "aevmos") COSMOS_DETECTED_DENOM_EXPONENT=18 ;;
                    *) COSMOS_DETECTED_DENOM_EXPONENT=6 ;;  # Default to 6
                esac
                log "$COSMOS_CHAIN_NAME" "${YELLOW}Using fallback exponent: $COSMOS_DETECTED_DENOM_EXPONENT for $COSMOS_DETECTED_DENOM${NC}"
            fi
        else
            # Fallback patterns if metadata query fails
            case "$COSMOS_DETECTED_DENOM" in
                "uatom"|"uosmo"|"ujuno"|"ustars") COSMOS_DETECTED_DENOM_EXPONENT=6 ;;
                "aevmos") COSMOS_DETECTED_DENOM_EXPONENT=18 ;;
                *) COSMOS_DETECTED_DENOM_EXPONENT=6 ;;
            esac
            log "$COSMOS_CHAIN_NAME" "${YELLOW}Metadata query failed, using fallback exponent: $COSMOS_DETECTED_DENOM_EXPONENT${NC}"
        fi
    fi
}
}

# Function to get effective Cosmos chain parameters (detected or configured)
get_cosmos_chain_params() {
    local effective_denom=""
    local effective_exponent=0
    local effective_max_validators=0
    
    # Use detected values if available, otherwise use configured values
    if [ -n "$COSMOS_DETECTED_DENOM" ]; then
        effective_denom="$COSMOS_DETECTED_DENOM"
    elif [ -n "$COSMOS_DENOM" ]; then
        effective_denom="$COSMOS_DENOM"
    else
        effective_denom="uatom"  # Default fallback
    fi
    
    if [ "$COSMOS_DETECTED_DENOM_EXPONENT" -gt 0 ]; then
        effective_exponent="$COSMOS_DETECTED_DENOM_EXPONENT"
    elif [ "$COSMOS_DENOM_EXPONENT" -gt 0 ]; then
        effective_exponent="$COSMOS_DENOM_EXPONENT"
    else
        effective_exponent=6  # Default fallback
    fi
    
    if [ "$COSMOS_DETECTED_MAX_VALIDATORS" -gt 0 ]; then
        effective_max_validators="$COSMOS_DETECTED_MAX_VALIDATORS"
    elif [ "$COSMOS_MAX_VALIDATORS" -gt 0 ]; then
        effective_max_validators="$COSMOS_MAX_VALIDATORS"
    else
        effective_max_validators=100  # Default fallback
    fi
    
    # Export for use in other functions
    EFFECTIVE_COSMOS_DENOM="$effective_denom"
    EFFECTIVE_COSMOS_DENOM_EXPONENT="$effective_exponent"
    EFFECTIVE_COSMOS_MAX_VALIDATORS="$effective_max_validators"
    
    # Determine display token symbol
    case "$effective_denom" in
        "uatom") EFFECTIVE_COSMOS_TOKEN_SYMBOL="ATOM" ;;
        "uosmo") EFFECTIVE_COSMOS_TOKEN_SYMBOL="OSMO" ;;
        "ujuno") EFFECTIVE_COSMOS_TOKEN_SYMBOL="JUNO" ;;
        "ustars") EFFECTIVE_COSMOS_TOKEN_SYMBOL="STARS" ;;
        "aevmos") EFFECTIVE_COSMOS_TOKEN_SYMBOL="EVMOS" ;;
        *) EFFECTIVE_COSMOS_TOKEN_SYMBOL=$(echo "$effective_denom" | sed 's/^u//' | tr '[:lower:]' '[:upper:]') ;;
    esac
    
    log "$COSMOS_CHAIN_NAME" "${GREEN}Effective params: denom=$effective_denom, symbol=$EFFECTIVE_COSMOS_TOKEN_SYMBOL, exponent=$effective_exponent, max_validators=$effective_max_validators${NC}"
}
}

# Function to auto-detect Substrate chain parameters
detect_substrate_chain_params() {
    log "$SUBSTRATE_CHAIN_NAME" "${BLUE}Auto-detecting chain parameters...${NC}"
    
    # Detect system properties (token symbol and decimals)
    local properties_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "system_properties" "[]" 10)
    
    if [ $? -eq 0 ] && [ -n "$properties_response" ]; then
        # Extract token decimals
        local detected_decimals=$(echo "$properties_response" | grep -o '"tokenDecimals":\[[0-9]*\]' | grep -o '[0-9]*' | head -1)
        if [ -n "$detected_decimals" ] && [ "$detected_decimals" -gt 0 ]; then
            SUBSTRATE_DETECTED_TOKEN_DECIMALS="$detected_decimals"
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Auto-detected token decimals: $detected_decimals${NC}"
        fi
        
        # Extract token symbol
        local detected_symbol=$(echo "$properties_response" | grep -o '"tokenSymbol":\["[^"]*"\]' | grep -o '"[^"]*"' | tr -d '"' | tail -1)
        if [ -n "$detected_symbol" ]; then
            SUBSTRATE_DETECTED_TOKEN_SYMBOL="$detected_symbol"
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Auto-detected token symbol: $detected_symbol${NC}"
        fi
    else
        log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}Failed to detect system properties${NC}"
    fi
    
    # Detect validator count from staking module
    local validator_count_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_validatorCount" "[]" 10)
    
    if [ $? -eq 0 ] && [ -n "$validator_count_response" ]; then
        local detected_max_validators=$(echo "$validator_count_response" | grep -o '"result":[0-9]*' | cut -d':' -f2)
        if [ -n "$detected_max_validators" ] && [ "$detected_max_validators" -gt 0 ]; then
            SUBSTRATE_DETECTED_MAX_VALIDATORS="$detected_max_validators"
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Auto-detected max validators: $detected_max_validators${NC}"
        fi
    else
        # Fallback: count active validators from session
        local session_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "session_validators" "[]" 10)
        if [ $? -eq 0 ] && [ -n "$session_response" ]; then
            local active_count=$(echo "$session_response" | grep -o '"[0-9a-zA-Z]*"' | wc -l)
            if [ "$active_count" -gt 0 ]; then
                SUBSTRATE_DETECTED_MAX_VALIDATORS="$active_count"
                log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}Using active validator count as max: $active_count${NC}"
            fi
        fi
        
        if [ "$SUBSTRATE_DETECTED_MAX_VALIDATORS" -eq 0 ]; then
            log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}Failed to detect max validators${NC}"
        fi
    fi
}
}

# Function to get effective Substrate chain parameters (detected or configured)
get_substrate_chain_params() {
    local effective_max_validators=0
    local effective_decimals=0
    local effective_symbol=""
    
    # Use detected values if available, otherwise use configured values
    if [ "$SUBSTRATE_DETECTED_MAX_VALIDATORS" -gt 0 ]; then
        effective_max_validators="$SUBSTRATE_DETECTED_MAX_VALIDATORS"
    elif [ "$SUBSTRATE_MAX_VALIDATORS" -gt 0 ]; then
        effective_max_validators="$SUBSTRATE_MAX_VALIDATORS"
    else
        effective_max_validators=100  # Default fallback
    fi
    
    if [ "$SUBSTRATE_DETECTED_TOKEN_DECIMALS" -gt 0 ]; then
        effective_decimals="$SUBSTRATE_DETECTED_TOKEN_DECIMALS"
    elif [ "$SUBSTRATE_TOKEN_DECIMALS" -gt 0 ]; then
        effective_decimals="$SUBSTRATE_TOKEN_DECIMALS"
    else
        effective_decimals=18  # Default fallback
    fi
    
    if [ -n "$SUBSTRATE_DETECTED_TOKEN_SYMBOL" ]; then
        effective_symbol="$SUBSTRATE_DETECTED_TOKEN_SYMBOL"
    elif [ -n "$SUBSTRATE_TOKEN_SYMBOL" ]; then
        effective_symbol="$SUBSTRATE_TOKEN_SYMBOL"
    else
        effective_symbol="UNIT"  # Default fallback
    fi
    
    # Export for use in other functions
    EFFECTIVE_SUBSTRATE_MAX_VALIDATORS="$effective_max_validators"
    EFFECTIVE_SUBSTRATE_TOKEN_DECIMALS="$effective_decimals"
    EFFECTIVE_SUBSTRATE_TOKEN_SYMBOL="$effective_symbol"
    
    log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Effective params: symbol=$effective_symbol, decimals=$effective_decimals, max_validators=$effective_max_validators${NC}"
}
}

# ================================
# CHAIN-SPECIFIC MODULES
# ================================

# Function to convert hex to decimal
hex_to_decimal() {
    local hex_value="$1"
    # Remove 0x prefix if present
    hex_value=${hex_value#0x}
    # Convert to decimal
    echo $((16#$hex_value))
}

# ================================
# SOMNIA MODULE
# ================================

# Function to fetch Somnia metric value
get_somnia_metric() {
    local metric_name="$1"
    curl -s --max-time $SOMNIA_RPC_TIMEOUT "$SOMNIA_METRICS_URL" | grep "^$metric_name " | awk '{print $2}'
}

# Function to query external RPC for block height (EVM compatible)
get_external_block_height() {
    local rpc_url="$1"
    local timeout="$2"
    local response
    
    # Query with timeout
    response=$(curl -s --max-time $timeout \
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

# Function to get Somnia network block height from multiple RPCs
get_somnia_network_block_height() {
    local IFS=','
    local rpcs=($SOMNIA_EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_block=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)  # Trim whitespace
        if [ -n "$rpc" ]; then
            local block_height
            if block_height=$(get_external_block_height "$rpc" "$SOMNIA_RPC_TIMEOUT"); then
                ((successful_rpcs++))
                if [ "$block_height" -gt "$highest_block" ]; then
                    highest_block=$block_height
                fi
                rpc_results+="✅ $rpc: $block_height\n"
                # Log to stderr to avoid interfering with function return value
                log "SOMNIA" "${GREEN}RPC Success: $rpc returned block $block_height${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                # Log to stderr to avoid interfering with function return value
                log "SOMNIA" "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    # Store results for potential error reporting
    SOMNIA_LAST_RPC_RESULTS="$rpc_results"
    SOMNIA_LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge $SOMNIA_MIN_SUCCESSFUL_RPCS ]; then
        echo $highest_block
        return 0
    else
        return 1
    fi
}

# Function to read Somnia state
read_somnia_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        SOMNIA_PREV_BLOCK_HEIGHT=0
        SOMNIA_PREV_EPOCH_STATUS=1
        SOMNIA_PREV_CHECK_TIME=0
        SOMNIA_CONSECUTIVE_FAILS=0
        SOMNIA_PREV_NETWORK_BLOCK=0
        SOMNIA_CONSECUTIVE_RPC_FAILS=0
        SOMNIA_PREV_BLOCK_LAG=0
    fi
    
    # For full nodes, epoch status is not relevant
    if [ "$SOMNIA_TYPE" = "fullnode" ]; then
        SOMNIA_PREV_EPOCH_STATUS="N/A"
    fi
}

# Function to read all chain states
read_all_states() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        # Somnia state
        SOMNIA_PREV_BLOCK_HEIGHT=0
        SOMNIA_PREV_EPOCH_STATUS=1
        SOMNIA_PREV_CHECK_TIME=0
        SOMNIA_CONSECUTIVE_FAILS=0
        SOMNIA_PREV_NETWORK_BLOCK=0
        SOMNIA_CONSECUTIVE_RPC_FAILS=0
        SOMNIA_PREV_BLOCK_LAG=0
        
        # SUI state
        SUI_PREV_CHECKPOINT=0
        SUI_PREV_CHECK_TIME=0
        SUI_CONSECUTIVE_FAILS=0
        SUI_PREV_NETWORK_CHECKPOINT=0
        SUI_CONSECUTIVE_RPC_FAILS=0
        SUI_PREV_LAG=0
        SUI_PREV_VALIDATOR_STATUS="N/A"
        
        # EVM state
        EVM_PREV_BLOCK_HEIGHT=0
        EVM_PREV_CHECK_TIME=0
        EVM_CONSECUTIVE_FAILS=0
        EVM_PREV_NETWORK_BLOCK=0
        EVM_CONSECUTIVE_RPC_FAILS=0
        EVM_PREV_BLOCK_LAG=0
        
        # Substrate state
        SUBSTRATE_PREV_BLOCK_HEIGHT=0
        SUBSTRATE_PREV_CHECK_TIME=0
        SUBSTRATE_CONSECUTIVE_FAILS=0
        SUBSTRATE_PREV_NETWORK_BLOCK=0
        SUBSTRATE_CONSECUTIVE_RPC_FAILS=0
        SUBSTRATE_PREV_BLOCK_LAG=0
        SUBSTRATE_PREV_VALIDATOR_STATUS="N/A"
        SUBSTRATE_DETECTED_STASH=""
        SUBSTRATE_PREV_STAKE_AMOUNT=0
        SUBSTRATE_PREV_VALIDATOR_PREFS=""
        SUBSTRATE_PREV_POSITION=0
        SUBSTRATE_PREV_MAX_VALIDATORS=0
        SUBSTRATE_DETECTED_MAX_VALIDATORS=0
        SUBSTRATE_DETECTED_TOKEN_DECIMALS=0
        SUBSTRATE_DETECTED_TOKEN_SYMBOL=""
        
        # Cosmos state
        COSMOS_PREV_BLOCK_HEIGHT=0
        COSMOS_PREV_CHECK_TIME=0
        COSMOS_CONSECUTIVE_FAILS=0
        COSMOS_PREV_NETWORK_BLOCK=0
        COSMOS_CONSECUTIVE_RPC_FAILS=0
        COSMOS_PREV_BLOCK_LAG=0
        COSMOS_PREV_VALIDATOR_STATUS="N/A"
        COSMOS_PREV_STAKE_AMOUNT=0
        COSMOS_PREV_COMMISSION=""
        COSMOS_PREV_POSITION=0
        COSMOS_PREV_MAX_VALIDATORS=0
        COSMOS_DETECTED_DENOM=""
        COSMOS_DETECTED_DENOM_EXPONENT=0
        COSMOS_DETECTED_MAX_VALIDATORS=0
        SUBSTRATE_PREV_POSITION=0
        SUBSTRATE_PREV_MAX_VALIDATORS=0
        
        # Cosmos state
        COSMOS_PREV_BLOCK_HEIGHT=0
        COSMOS_PREV_CHECK_TIME=0
        COSMOS_CONSECUTIVE_FAILS=0
        COSMOS_PREV_NETWORK_BLOCK=0
        COSMOS_CONSECUTIVE_RPC_FAILS=0
        COSMOS_PREV_BLOCK_LAG=0
        COSMOS_PREV_VALIDATOR_STATUS="N/A"
        COSMOS_PREV_STAKE_AMOUNT=0
        COSMOS_PREV_COMMISSION=""
        COSMOS_PREV_POSITION=0
        COSMOS_PREV_MAX_VALIDATORS=0
    fi
    
    # For full nodes, validator status is not relevant
    if [ "$SOMNIA_TYPE" = "fullnode" ]; then
        SOMNIA_PREV_EPOCH_STATUS="N/A"
    fi
    if [ "$SUI_TYPE" = "fullnode" ]; then
        SUI_PREV_VALIDATOR_STATUS="N/A"
    fi
    if [ "$SUBSTRATE_TYPE" = "fullnode" ]; then
        SUBSTRATE_PREV_VALIDATOR_STATUS="N/A"
    fi
    if [ "$COSMOS_TYPE" = "fullnode" ]; then
        COSMOS_PREV_VALIDATOR_STATUS="N/A"
    fi
}

# Function to write all chain states
write_all_states() {
    cat > "$STATE_FILE" << EOF
# Somnia state
SOMNIA_PREV_BLOCK_HEIGHT=${SOMNIA_PREV_BLOCK_HEIGHT:-0}
SOMNIA_PREV_EPOCH_STATUS=${SOMNIA_PREV_EPOCH_STATUS:-1}
SOMNIA_PREV_CHECK_TIME=${SOMNIA_PREV_CHECK_TIME:-0}
SOMNIA_CONSECUTIVE_FAILS=${SOMNIA_CONSECUTIVE_FAILS:-0}
SOMNIA_PREV_NETWORK_BLOCK=${SOMNIA_PREV_NETWORK_BLOCK:-0}
SOMNIA_CONSECUTIVE_RPC_FAILS=${SOMNIA_CONSECUTIVE_RPC_FAILS:-0}
SOMNIA_PREV_BLOCK_LAG=${SOMNIA_PREV_BLOCK_LAG:-0}

# SUI state
SUI_PREV_CHECKPOINT=${SUI_PREV_CHECKPOINT:-0}
SUI_PREV_CHECK_TIME=${SUI_PREV_CHECK_TIME:-0}
SUI_CONSECUTIVE_FAILS=${SUI_CONSECUTIVE_FAILS:-0}
SUI_PREV_NETWORK_CHECKPOINT=${SUI_PREV_NETWORK_CHECKPOINT:-0}
SUI_CONSECUTIVE_RPC_FAILS=${SUI_CONSECUTIVE_RPC_FAILS:-0}
SUI_PREV_LAG=${SUI_PREV_LAG:-0}
SUI_PREV_VALIDATOR_STATUS=${SUI_PREV_VALIDATOR_STATUS:-"N/A"}

# EVM state
EVM_PREV_BLOCK_HEIGHT=${EVM_PREV_BLOCK_HEIGHT:-0}
EVM_PREV_CHECK_TIME=${EVM_PREV_CHECK_TIME:-0}
EVM_CONSECUTIVE_FAILS=${EVM_CONSECUTIVE_FAILS:-0}
EVM_PREV_NETWORK_BLOCK=${EVM_PREV_NETWORK_BLOCK:-0}
EVM_CONSECUTIVE_RPC_FAILS=${EVM_CONSECUTIVE_RPC_FAILS:-0}
EVM_PREV_BLOCK_LAG=${EVM_PREV_BLOCK_LAG:-0}

# Substrate state
SUBSTRATE_PREV_BLOCK_HEIGHT=${SUBSTRATE_PREV_BLOCK_HEIGHT:-0}
SUBSTRATE_PREV_CHECK_TIME=${SUBSTRATE_PREV_CHECK_TIME:-0}
SUBSTRATE_CONSECUTIVE_FAILS=${SUBSTRATE_CONSECUTIVE_FAILS:-0}
SUBSTRATE_PREV_NETWORK_BLOCK=${SUBSTRATE_PREV_NETWORK_BLOCK:-0}
SUBSTRATE_CONSECUTIVE_RPC_FAILS=${SUBSTRATE_CONSECUTIVE_RPC_FAILS:-0}
SUBSTRATE_PREV_BLOCK_LAG=${SUBSTRATE_PREV_BLOCK_LAG:-0}
SUBSTRATE_PREV_VALIDATOR_STATUS=${SUBSTRATE_PREV_VALIDATOR_STATUS:-"N/A"}
SUBSTRATE_DETECTED_STASH=${SUBSTRATE_DETECTED_STASH:-""}
SUBSTRATE_PREV_STAKE_AMOUNT=${SUBSTRATE_PREV_STAKE_AMOUNT:-0}
SUBSTRATE_PREV_VALIDATOR_PREFS=${SUBSTRATE_PREV_VALIDATOR_PREFS:-""}
SUBSTRATE_PREV_POSITION=${SUBSTRATE_PREV_POSITION:-0}
SUBSTRATE_PREV_MAX_VALIDATORS=${SUBSTRATE_PREV_MAX_VALIDATORS:-0}
SUBSTRATE_DETECTED_MAX_VALIDATORS=${SUBSTRATE_DETECTED_MAX_VALIDATORS:-0}
SUBSTRATE_DETECTED_TOKEN_DECIMALS=${SUBSTRATE_DETECTED_TOKEN_DECIMALS:-0}
SUBSTRATE_DETECTED_TOKEN_SYMBOL=${SUBSTRATE_DETECTED_TOKEN_SYMBOL:-""}

# Cosmos state
COSMOS_PREV_BLOCK_HEIGHT=${COSMOS_PREV_BLOCK_HEIGHT:-0}
COSMOS_PREV_CHECK_TIME=${COSMOS_PREV_CHECK_TIME:-0}
COSMOS_CONSECUTIVE_FAILS=${COSMOS_CONSECUTIVE_FAILS:-0}
COSMOS_PREV_NETWORK_BLOCK=${COSMOS_PREV_NETWORK_BLOCK:-0}
COSMOS_CONSECUTIVE_RPC_FAILS=${COSMOS_CONSECUTIVE_RPC_FAILS:-0}
COSMOS_PREV_BLOCK_LAG=${COSMOS_PREV_BLOCK_LAG:-0}
COSMOS_PREV_VALIDATOR_STATUS=${COSMOS_PREV_VALIDATOR_STATUS:-"N/A"}
COSMOS_PREV_STAKE_AMOUNT=${COSMOS_PREV_STAKE_AMOUNT:-0}
COSMOS_PREV_COMMISSION=${COSMOS_PREV_COMMISSION:-""}
COSMOS_PREV_POSITION=${COSMOS_PREV_POSITION:-0}
COSMOS_PREV_MAX_VALIDATORS=${COSMOS_PREV_MAX_VALIDATORS:-0}
COSMOS_DETECTED_DENOM=${COSMOS_DETECTED_DENOM:-""}
COSMOS_DETECTED_DENOM_EXPONENT=${COSMOS_DETECTED_DENOM_EXPONENT:-0}
COSMOS_DETECTED_MAX_VALIDATORS=${COSMOS_DETECTED_MAX_VALIDATORS:-0}
EOF
}

# Main Somnia monitoring function
mod_somnia() {
    local current_time=$(date +%s)
    
    log "SOMNIA" "${BLUE}Starting Somnia monitoring...${NC}"
    
    # Fetch current metrics
    local current_block_height=$(get_somnia_metric "ledger_block_number")
    local current_epoch_status="N/A"
    
    # Only check validator status for validator nodes
    if [ "$SOMNIA_TYPE" = "validator" ]; then
        current_epoch_status=$(get_somnia_metric "in_current_epoch")
    fi
    
    # Validate metrics were fetched
    if [ -z "$current_block_height" ] || ([ "$SOMNIA_TYPE" = "validator" ] && [ -z "$current_epoch_status" ]); then
        log "SOMNIA" "${RED}CRITICAL: Failed to fetch metrics from $SOMNIA_METRICS_URL${NC}"
        ((SOMNIA_CONSECUTIVE_FAILS++))
        
        local node_type_desc=$([ "$SOMNIA_TYPE" = "validator" ] && echo "Validator Node" || echo "Full Node")
        
        # Send immediate alert on first failure (critical issue)
        if [ $SOMNIA_CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "SOMNIA" "🚨 CRITICAL: Node Metrics Unavailable" \
                "**URGENT: Node appears to be DOWN!**\n\nUnable to fetch metrics from $node_type_desc.\n\n**Node Type:** $node_type_desc\n**Metrics URL:** $SOMNIA_METRICS_URL\n**Status:** Node may be completely down or metrics port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if node process is running\n• Verify metrics port is accessible\n• Check system resources\n• Review node logs" \
                16711680
        # Follow-up alerts for persistent failures
        elif [ $SOMNIA_CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "SOMNIA" "🚨 CRITICAL: Node Still Down" \
                "Node has been unresponsive for $SOMNIA_CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((SOMNIA_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Still unable to fetch metrics\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $SOMNIA_CONSECUTIVE_FAILS -eq 12 ]; then  # ~1 hour
            send_discord_alert "SOMNIA" "🚨 CRITICAL: Node Down for 1+ Hour" \
                "Node has been unresponsive for over 1 hour ($SOMNIA_CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((SOMNIA_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Extended outage detected\n\n**THIS MAY RESULT IN SLASHING PENALTIES**" \
                16711680
        fi
        
        write_all_states
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $SOMNIA_CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((SOMNIA_CONSECUTIVE_FAILS * 5))
        local node_type_desc=$([ "$SOMNIA_TYPE" = "validator" ] && echo "Validator Node" || echo "Full Node")
        
        send_discord_alert "SOMNIA" "✅ Node Recovered" \
            "$node_type_desc is back online and responding.\n\n**Outage Duration:** ~${outage_duration} minutes ($SOMNIA_CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Block:** $current_block_height" \
            65280
        
        log "SOMNIA" "${GREEN}Node recovered after $SOMNIA_CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    SOMNIA_CONSECUTIVE_FAILS=0
    
    # External RPC comparison (if enabled)
    local current_network_block=0
    local current_block_lag=0
    local network_status=""
    
    if [ "$SOMNIA_EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_block=$(get_somnia_network_block_height); then
            # Reset RPC fails and send recovery notification if needed
            if [ $SOMNIA_CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "SOMNIA" "✅ External RPC Endpoints Recovered" \
                    "External RPC endpoints are responding again.\n\n**Outage Duration:** $SOMNIA_CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Block:** $current_network_block" \
                    65280
                
                log "SOMNIA" "${GREEN}External RPCs recovered after $SOMNIA_CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            SOMNIA_CONSECUTIVE_RPC_FAILS=0
            
            current_block_lag=$((current_network_block - current_block_height))
            
            if [ $current_block_lag -gt 0 ]; then
                network_status=" (${current_block_lag} blocks behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "SOMNIA" "${GREEN}Network comparison: Local=$current_block_height, Network=$current_network_block$network_status${NC}"
            
            # Check for significant block lag
            if [ $current_block_lag -gt $SOMNIA_BLOCK_LAG_THRESHOLD ]; then
                # Check if lag is increasing (getting worse)
                local lag_trend=""
                if [ $SOMNIA_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -gt $SOMNIA_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag increasing: was $SOMNIA_PREV_BLOCK_LAG blocks behind)"
                elif [ $SOMNIA_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -lt $SOMNIA_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag decreasing: was $SOMNIA_PREV_BLOCK_LAG blocks behind, catching up)"
                fi
                
                local node_type_desc=$([ "$SOMNIA_TYPE" = "validator" ] && echo "Validator" || echo "Full Node")
                local status_info=""
                
                if [ "$SOMNIA_TYPE" = "validator" ]; then
                    status_info="**Validator Status:** $([ "$current_epoch_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                fi
                
                # Only alert if lag is significant and not improving rapidly
                if [ $current_block_lag -gt $((SOMNIA_BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_block_lag -gt $SOMNIA_PREV_BLOCK_LAG ]; then
                    send_discord_alert "SOMNIA" "⚠️ WARNING: Node Falling Behind Network" \
                        "Node is significantly behind the network.\n\n**Node Type:** $node_type_desc\n**Local Block:** $current_block_height\n**Network Block:** $current_network_block\n**Blocks Behind:** $current_block_lag$lag_trend\n$status_info\n**Successful RPCs:** $SOMNIA_LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((SOMNIA_CONSECUTIVE_RPC_FAILS++))
            log "SOMNIA" "${YELLOW}Failed to fetch network block height from external RPCs (attempt $SOMNIA_CONSECUTIVE_RPC_FAILS)${NC}"
            
            # Send immediate alert on first RPC failure
            if [ $SOMNIA_CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "SOMNIA" "⚠️ WARNING: External RPC Endpoints Unreachable" \
                    "Cannot fetch network block height for comparison.\n\n**Impact:** Unable to detect if node is falling behind network\n**RPC Results:**\n$SOMNIA_LAST_RPC_RESULTS\n**Local monitoring continues:** Block sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            # Alert for persistent RPC failures
            elif [ $SOMNIA_CONSECUTIVE_RPC_FAILS -eq 6 ]; then  # ~30 minutes
                send_discord_alert "SOMNIA" "⚠️ WARNING: External RPCs Down for 30+ Minutes" \
                    "External RPC endpoints have been unavailable for $SOMNIA_CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((SOMNIA_CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues\n\n**Consider checking:**\n• Network connectivity\n• RPC endpoint status\n• Firewall/proxy settings" \
                    16776960
            fi
            
            # Keep previous values for network comparison
            current_network_block=$SOMNIA_PREV_NETWORK_BLOCK
            current_block_lag=$SOMNIA_PREV_BLOCK_LAG
        fi
    fi
    
    # Log current status based on node type
    if [ "$SOMNIA_TYPE" = "validator" ]; then
        log "SOMNIA" "${GREEN}Current Status: Epoch=$current_epoch_status, Block=$current_block_height$network_status${NC}"
    else
        log "SOMNIA" "${GREEN}Current Status: Block=$current_block_height (Full Node)$network_status${NC}"
    fi
    
    # Check validator status only for validator nodes
    if [ "$SOMNIA_TYPE" = "validator" ]; then
        # Check if validator is out of active set (CRITICAL)
        if [ "$current_epoch_status" = "0" ] && [ "$SOMNIA_PREV_EPOCH_STATUS" = "1" ]; then
            send_discord_alert "SOMNIA" "🚨 CRITICAL: Validator Removed from Active Set" \
                "**URGENT ACTION REQUIRED**\n\nValidator has been removed from the active validator set!\n\n**Current Status:** Out of active set (0)\n**Previous Status:** In active set (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check validator logs\n• Verify staking requirements\n• Check slashing conditions\n• Review uptime metrics" \
                16711680
                
        elif [ "$current_epoch_status" = "1" ] && [ "$SOMNIA_PREV_EPOCH_STATUS" = "0" ]; then
            send_discord_alert "SOMNIA" "✅ Validator Restored to Active Set" \
                "Validator has been restored to the active validator set.\n\n**Current Status:** In active set (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                65280
        fi
    fi
    
    # Check local block progression (applies to both validator and full nodes)
    if [ $SOMNIA_PREV_BLOCK_HEIGHT -gt 0 ] && [ $((current_time - SOMNIA_PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_block_height" -le "$SOMNIA_PREV_BLOCK_HEIGHT" ]; then
            local time_diff=$((current_time - SOMNIA_PREV_CHECK_TIME))
            local node_type_desc=$([ "$SOMNIA_TYPE" = "validator" ] && echo "Validator" || echo "Full Node")
            local status_info=""
            
            if [ "$SOMNIA_TYPE" = "validator" ]; then
                status_info="**Validator Status:** $([ "$current_epoch_status" = "1" ] && echo "Active" || echo "Inactive")\n"
            fi
            
            local network_info=""
            if [ "$SOMNIA_EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_block -gt 0 ]; then
                network_info="**Network Block:** $current_network_block\n**Network is Progressing:** $([ $current_network_block -gt $SOMNIA_PREV_NETWORK_BLOCK ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "SOMNIA" "⚠️ WARNING: Local Block Sync Stalled" \
                "Local node has stopped producing/syncing new blocks.\n\n**Node Type:** $node_type_desc\n**Current Block:** $current_block_height\n**Previous Block:** $SOMNIA_PREV_BLOCK_HEIGHT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info$status_info\n**Possible causes:**\n• Node synchronization problems\n• Consensus issues\n• Local node malfunction" \
                16776960
        else
            local blocks_synced=$((current_block_height - SOMNIA_PREV_BLOCK_HEIGHT))
            local time_diff=$((current_time - SOMNIA_PREV_CHECK_TIME))
            local blocks_per_min=$(echo "scale=2; $blocks_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "SOMNIA" "${GREEN}Local blocks syncing normally: +$blocks_synced blocks in ${time_diff}s (${blocks_per_min} blocks/min)${NC}"
        fi
    fi
    
    # Save current state
    SOMNIA_PREV_BLOCK_HEIGHT=$current_block_height
    SOMNIA_PREV_EPOCH_STATUS=$current_epoch_status
    SOMNIA_PREV_CHECK_TIME=$current_time
    SOMNIA_PREV_NETWORK_BLOCK=$current_network_block
    SOMNIA_PREV_BLOCK_LAG=$current_block_lag
    
    log "SOMNIA" "${BLUE}Somnia monitoring completed${NC}"
    return 0
}

# Function to get simple validator status (for backward compatibility)
get_substrate_validator_status() {
    local full_status=$(get_substrate_comprehensive_validator_status)
    local status=$(echo "$full_status" | cut -d':' -f1)
    
    case "$status" in
        "Active") echo "1" ;;
        "Waiting") echo "0" ;;
        "Inactive") echo "0" ;;
        *) echo "0" ;;
    esac
}

# ================================
# FUTURE CHAIN MODULES (Placeholders)
# ================================

# ================================
# SUI MODULE
# ================================

# Function to query SUI RPC
query_sui_rpc() {
    local rpc_url="$1"
    local method="$2"
    local params="$3"
    local timeout="$4"
    
    local payload='{"jsonrpc":"2.0","method":"'$method'","params":'$params',"id":1}'
    curl -s --max-time $timeout \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$rpc_url" 2>/dev/null
}

# Function to get SUI checkpoint from local node
get_sui_local_checkpoint() {
    local response=$(query_sui_rpc "$SUI_RPC_URL" "sui_getLatestCheckpointSequenceNumber" "[]" 10)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Extract result field (SUI returns string, not hex)
        local checkpoint=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$checkpoint" ] && [[ "$checkpoint" =~ ^[0-9]+$ ]]; then
            echo "$checkpoint"
            return 0
        fi
    fi
    
    return 1
}

# Function to get SUI checkpoint from external RPC
get_sui_external_checkpoint() {
    local rpc_url="$1"
    local timeout="$2"
    local response=$(query_sui_rpc "$rpc_url" "sui_getLatestCheckpointSequenceNumber" "[]" $timeout)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local checkpoint=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$checkpoint" ] && [[ "$checkpoint" =~ ^[0-9]+$ ]]; then
            echo "$checkpoint"
            return 0
        fi
    fi
    
    return 1
}

# Function to get SUI validator status (if validator node)
get_sui_validator_status() {
    if [ "$SUI_TYPE" != "validator" ]; then
        echo "N/A"
        return 0
    fi
    
    # Get current validator set
    local response=$(query_sui_rpc "$SUI_RPC_URL" "suix_getLatestSuiSystemState" "[]" 10)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # This is a simplified check - in practice, you'd need to check if your validator address is in the active set
        # For now, we'll return "Active" if we can get system state, "Inactive" if we can't
        local result=$(echo "$response" | grep -o '"result"')
        if [ -n "$result" ]; then
            echo "1"  # Assume active if we can query system state
            return 0
        fi
    fi
    
    echo "0"  # Assume inactive if query fails
    return 1
}

# Function to get SUI network checkpoint from multiple RPCs
get_sui_network_checkpoint() {
    local IFS=','
    local rpcs=($SUI_EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_checkpoint=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)  # Trim whitespace
        if [ -n "$rpc" ]; then
            local checkpoint
            if checkpoint=$(get_sui_external_checkpoint "$rpc" 10); then
                ((successful_rpcs++))
                if [ "$checkpoint" -gt "$highest_checkpoint" ]; then
                    highest_checkpoint=$checkpoint
                fi
                rpc_results+="✅ $rpc: $checkpoint\n"
                log "SUI" "${GREEN}RPC Success: $rpc returned checkpoint $checkpoint${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                log "SUI" "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    # Store results for potential error reporting
    SUI_LAST_RPC_RESULTS="$rpc_results"
    SUI_LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge 1 ]; then
        echo $highest_checkpoint
        return 0
    else
        return 1
    fi
}

# Main SUI monitoring function
mod_sui() {
    local current_time=$(date +%s)
    
    log "SUI" "${BLUE}Starting SUI monitoring...${NC}"
    
    # Fetch current checkpoint
    local current_checkpoint=$(get_sui_local_checkpoint)
    local current_validator_status="N/A"
    
    # Check validator status if validator node
    if [ "$SUI_TYPE" = "validator" ]; then
        current_validator_status=$(get_sui_validator_status)
    fi
    
    # Validate checkpoint was fetched
    if [ -z "$current_checkpoint" ]; then
        log "SUI" "${RED}CRITICAL: Failed to fetch checkpoint from $SUI_RPC_URL${NC}"
        ((SUI_CONSECUTIVE_FAILS++))
        
        local node_type_desc=$([ "$SUI_TYPE" = "validator" ] && echo "SUI Validator Node" || echo "SUI Full Node")
        
        # Send immediate alert on first failure
        if [ $SUI_CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "SUI" "🚨 CRITICAL: SUI Node Unavailable" \
                "**URGENT: SUI Node appears to be DOWN!**\n\nUnable to fetch checkpoint from $node_type_desc.\n\n**Node Type:** $node_type_desc\n**RPC URL:** $SUI_RPC_URL\n**Status:** Node may be completely down or RPC port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if SUI node process is running\n• Verify RPC port is accessible\n• Check system resources\n• Review SUI node logs" \
                16711680
        elif [ $SUI_CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "SUI" "🚨 CRITICAL: SUI Node Still Down" \
                "SUI node has been unresponsive for $SUI_CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((SUI_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Still unable to fetch checkpoint\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $SUI_CONSECUTIVE_FAILS -eq 12 ]; then
            send_discord_alert "SUI" "🚨 CRITICAL: SUI Node Down for 1+ Hour" \
                "SUI node has been unresponsive for over 1 hour ($SUI_CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((SUI_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Extended outage detected" \
                16711680
        fi
        
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $SUI_CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((SUI_CONSECUTIVE_FAILS * 5))
        local node_type_desc=$([ "$SUI_TYPE" = "validator" ] && echo "SUI Validator Node" || echo "SUI Full Node")
        
        send_discord_alert "SUI" "✅ SUI Node Recovered" \
            "$node_type_desc is back online and responding.\n\n**Outage Duration:** ~${outage_duration} minutes ($SUI_CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Checkpoint:** $current_checkpoint" \
            65280
        
        log "SUI" "${GREEN}SUI node recovered after $SUI_CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    SUI_CONSECUTIVE_FAILS=0
    
    # External RPC comparison (if enabled)
    local current_network_checkpoint=0
    local current_lag=0
    local network_status=""
    
    if [ "$SUI_EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_checkpoint=$(get_sui_network_checkpoint); then
            # Reset RPC fails and send recovery notification if needed
            if [ $SUI_CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "SUI" "✅ SUI External RPC Endpoints Recovered" \
                    "SUI external RPC endpoints are responding again.\n\n**Outage Duration:** $SUI_CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Checkpoint:** $current_network_checkpoint" \
                    65280
                
                log "SUI" "${GREEN}External RPCs recovered after $SUI_CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            SUI_CONSECUTIVE_RPC_FAILS=0
            
            current_lag=$((current_network_checkpoint - current_checkpoint))
            
            if [ $current_lag -gt 0 ]; then
                network_status=" ($current_lag checkpoints behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "SUI" "${GREEN}Network comparison: Local=$current_checkpoint, Network=$current_network_checkpoint$network_status${NC}"
            
            # Check for significant checkpoint lag
            if [ $current_lag -gt $SUI_BLOCK_LAG_THRESHOLD ]; then
                local lag_trend=""
                if [ $SUI_PREV_LAG -gt 0 ] && [ $current_lag -gt $SUI_PREV_LAG ]; then
                    lag_trend=" (lag increasing: was $SUI_PREV_LAG checkpoints behind)"
                elif [ $SUI_PREV_LAG -gt 0 ] && [ $current_lag -lt $SUI_PREV_LAG ]; then
                    lag_trend=" (lag decreasing: was $SUI_PREV_LAG checkpoints behind, catching up)"
                fi
                
                local node_type_desc=$([ "$SUI_TYPE" = "validator" ] && echo "SUI Validator" || echo "SUI Full Node")
                local status_info=""
                
                if [ "$SUI_TYPE" = "validator" ]; then
                    status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                fi
                
                if [ $current_lag -gt $((SUI_BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_lag -gt $SUI_PREV_LAG ]; then
                    send_discord_alert "SUI" "⚠️ WARNING: SUI Node Falling Behind Network" \
                        "SUI node is significantly behind the network.\n\n**Node Type:** $node_type_desc\n**Local Checkpoint:** $current_checkpoint\n**Network Checkpoint:** $current_network_checkpoint\n**Checkpoints Behind:** $current_lag$lag_trend\n$status_info\n**Successful RPCs:** $SUI_LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((SUI_CONSECUTIVE_RPC_FAILS++))
            log "SUI" "${YELLOW}Failed to fetch network checkpoint from external RPCs (attempt $SUI_CONSECUTIVE_RPC_FAILS)${NC}"
            
            if [ $SUI_CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "SUI" "⚠️ WARNING: SUI External RPC Endpoints Unreachable" \
                    "Cannot fetch network checkpoint for comparison.\n\n**Impact:** Unable to detect if SUI node is falling behind network\n**RPC Results:**\n$SUI_LAST_RPC_RESULTS\n**Local monitoring continues:** Checkpoint sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            elif [ $SUI_CONSECUTIVE_RPC_FAILS -eq 6 ]; then
                send_discord_alert "SUI" "⚠️ WARNING: SUI External RPCs Down for 30+ Minutes" \
                    "SUI external RPC endpoints have been unavailable for $SUI_CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((SUI_CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues" \
                    16776960
            fi
            
            current_network_checkpoint=$SUI_PREV_NETWORK_CHECKPOINT
            current_lag=$SUI_PREV_LAG
        fi
    fi
    
    # Log current status
    if [ "$SUI_TYPE" = "validator" ]; then
        log "SUI" "${GREEN}Current Status: Validator=$([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive"), Checkpoint=$current_checkpoint$network_status${NC}"
    else
        log "SUI" "${GREEN}Current Status: Checkpoint=$current_checkpoint (Full Node)$network_status${NC}"
    fi
    
    # Check validator status for validator nodes
    if [ "$SUI_TYPE" = "validator" ]; then
        if [ "$current_validator_status" = "0" ] && [ "$SUI_PREV_VALIDATOR_STATUS" = "1" ]; then
            send_discord_alert "SUI" "🚨 CRITICAL: SUI Validator Removed from Active Set" \
                "**URGENT ACTION REQUIRED**\n\nSUI Validator has been removed from the active validator set!\n\n**Current Status:** Inactive (0)\n**Previous Status:** Active (1)\n**Checkpoint:** $current_checkpoint\n**Network Checkpoint:** $current_network_checkpoint\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check SUI validator logs\n• Verify staking requirements\n• Check slashing conditions\n• Review validator performance" \
                16711680
                
        elif [ "$current_validator_status" = "1" ] && [ "$SUI_PREV_VALIDATOR_STATUS" = "0" ]; then
            send_discord_alert "SUI" "✅ SUI Validator Restored to Active Set" \
                "SUI Validator has been restored to the active validator set.\n\n**Current Status:** Active (1)\n**Checkpoint:** $current_checkpoint\n**Network Checkpoint:** $current_network_checkpoint\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                65280
        fi
    fi
    
    # Check checkpoint progression
    if [ $SUI_PREV_CHECKPOINT -gt 0 ] && [ $((current_time - SUI_PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_checkpoint" -le "$SUI_PREV_CHECKPOINT" ]; then
            local time_diff=$((current_time - SUI_PREV_CHECK_TIME))
            local node_type_desc=$([ "$SUI_TYPE" = "validator" ] && echo "SUI Validator" || echo "SUI Full Node")
            local status_info=""
            
            if [ "$SUI_TYPE" = "validator" ]; then
                status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
            fi
            
            local network_info=""
            if [ "$SUI_EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_checkpoint -gt 0 ]; then
                network_info="**Network Checkpoint:** $current_network_checkpoint\n**Network is Progressing:** $([ $current_network_checkpoint -gt $SUI_PREV_NETWORK_CHECKPOINT ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "SUI" "⚠️ WARNING: SUI Checkpoint Sync Stalled" \
                "SUI node has stopped syncing new checkpoints.\n\n**Node Type:** $node_type_desc\n**Current Checkpoint:** $current_checkpoint\n**Previous Checkpoint:** $SUI_PREV_CHECKPOINT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info$status_info\n**Possible causes:**\n• Node synchronization problems\n• Network connectivity issues\n• SUI node malfunction" \
                16776960
        else
            local checkpoints_synced=$((current_checkpoint - SUI_PREV_CHECKPOINT))
            local time_diff=$((current_time - SUI_PREV_CHECK_TIME))
            local checkpoints_per_min=$(echo "scale=2; $checkpoints_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "SUI" "${GREEN}Checkpoints syncing normally: +$checkpoints_synced checkpoints in ${time_diff}s (${checkpoints_per_min} checkpoints/min)${NC}"
        fi
    fi
    
    # Save current state
    SUI_PREV_CHECKPOINT=$current_checkpoint
    SUI_PREV_CHECK_TIME=$current_time
    SUI_PREV_NETWORK_CHECKPOINT=$current_network_checkpoint
    SUI_PREV_LAG=$current_lag
    SUI_PREV_VALIDATOR_STATUS=$current_validator_status
    
    log "SUI" "${BLUE}SUI monitoring completed${NC}"
    return 0
}

# ================================
# EVM MODULE
# ================================

# Function to get EVM block from external RPC
get_evm_external_block() {
    local rpc_url="$1"
    local timeout="$2"
    local response
    
    response=$(curl -s --max-time $timeout \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        -H "Content-Type: application/json" \
        "$rpc_url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local hex_block=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$hex_block" ] && [[ "$hex_block" =~ ^0x[0-9a-fA-F]+$ ]]; then
            hex_to_decimal "$hex_block"
            return 0
        fi
    fi
    
    return 1
}

# Function to get EVM local block height
get_evm_local_block() {
    get_evm_external_block "$EVM_RPC_URL" 10
}

# Function to get EVM network block height from multiple RPCs
get_evm_network_block_height() {
    local IFS=','
    local rpcs=($EVM_EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_block=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)
        if [ -n "$rpc" ]; then
            local block_height
            if block_height=$(get_evm_external_block "$rpc" 10); then
                ((successful_rpcs++))
                if [ "$block_height" -gt "$highest_block" ]; then
                    highest_block=$block_height
                fi
                rpc_results+="✅ $rpc: $block_height\n"
                log "$EVM_CHAIN_NAME" "${GREEN}RPC Success: $rpc returned block $block_height${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                log "$EVM_CHAIN_NAME" "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    EVM_LAST_RPC_RESULTS="$rpc_results"
    EVM_LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge 1 ]; then
        echo $highest_block
        return 0
    else
        return 1
    fi
}

# Main EVM monitoring function
mod_evm() {
    local current_time=$(date +%s)
    
    log "$EVM_CHAIN_NAME" "${BLUE}Starting $EVM_CHAIN_NAME monitoring...${NC}"
    
    # Fetch current block height
    local current_block_height=$(get_evm_local_block)
    
    # Validate block height was fetched
    if [ -z "$current_block_height" ]; then
        log "$EVM_CHAIN_NAME" "${RED}CRITICAL: Failed to fetch block height from $EVM_RPC_URL${NC}"
        ((EVM_CONSECUTIVE_FAILS++))
        
        # Send immediate alert on first failure
        if [ $EVM_CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "$EVM_CHAIN_NAME" "🚨 CRITICAL: $EVM_CHAIN_NAME Node Unavailable" \
                "**URGENT: $EVM_CHAIN_NAME Node appears to be DOWN!**\n\nUnable to fetch block height from $EVM_CHAIN_NAME Full Node.\n\n**RPC URL:** $EVM_RPC_URL\n**Status:** Node may be completely down or RPC port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if $EVM_CHAIN_NAME node process is running\n• Verify RPC port is accessible\n• Check system resources\n• Review $EVM_CHAIN_NAME node logs" \
                16711680
        elif [ $EVM_CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "$EVM_CHAIN_NAME" "🚨 CRITICAL: $EVM_CHAIN_NAME Node Still Down" \
                "$EVM_CHAIN_NAME node has been unresponsive for $EVM_CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((EVM_CONSECUTIVE_FAILS * 5)) minutes\n**Status:** Still unable to fetch block height\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $EVM_CONSECUTIVE_FAILS -eq 12 ]; then
            send_discord_alert "$EVM_CHAIN_NAME" "🚨 CRITICAL: $EVM_CHAIN_NAME Node Down for 1+ Hour" \
                "$EVM_CHAIN_NAME node has been unresponsive for over 1 hour ($EVM_CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((EVM_CONSECUTIVE_FAILS * 5)) minutes\n**Status:** Extended outage detected" \
                16711680
        fi
        
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $EVM_CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((EVM_CONSECUTIVE_FAILS * 5))
        
        send_discord_alert "$EVM_CHAIN_NAME" "✅ $EVM_CHAIN_NAME Node Recovered" \
            "$EVM_CHAIN_NAME Full Node is back online and responding.\n\n**Outage Duration:** ~${outage_duration} minutes ($EVM_CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Block:** $current_block_height" \
            65280
        
        log "$EVM_CHAIN_NAME" "${GREEN}$EVM_CHAIN_NAME node recovered after $EVM_CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    EVM_CONSECUTIVE_FAILS=0
    
    # External RPC comparison (if enabled)
    local current_network_block=0
    local current_block_lag=0
    local network_status=""
    
    if [ "$EVM_EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_block=$(get_evm_network_block_height); then
            # Reset RPC fails and send recovery notification if needed
            if [ $EVM_CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "$EVM_CHAIN_NAME" "✅ $EVM_CHAIN_NAME External RPC Endpoints Recovered" \
                    "$EVM_CHAIN_NAME external RPC endpoints are responding again.\n\n**Outage Duration:** $EVM_CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Block:** $current_network_block" \
                    65280
                
                log "$EVM_CHAIN_NAME" "${GREEN}External RPCs recovered after $EVM_CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            EVM_CONSECUTIVE_RPC_FAILS=0
            
            current_block_lag=$((current_network_block - current_block_height))
            
            if [ $current_block_lag -gt 0 ]; then
                network_status=" ($current_block_lag blocks behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "$EVM_CHAIN_NAME" "${GREEN}Network comparison: Local=$current_block_height, Network=$current_network_block$network_status${NC}"
            
            # Check for significant block lag
            if [ $current_block_lag -gt $EVM_BLOCK_LAG_THRESHOLD ]; then
                local lag_trend=""
                if [ $EVM_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -gt $EVM_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag increasing: was $EVM_PREV_BLOCK_LAG blocks behind)"
                elif [ $EVM_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -lt $EVM_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag decreasing: was $EVM_PREV_BLOCK_LAG blocks behind, catching up)"
                fi
                
                if [ $current_block_lag -gt $((EVM_BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_block_lag -gt $EVM_PREV_BLOCK_LAG ]; then
                    send_discord_alert "$EVM_CHAIN_NAME" "⚠️ WARNING: $EVM_CHAIN_NAME Node Falling Behind Network" \
                        "$EVM_CHAIN_NAME node is significantly behind the network.\n\n**Local Block:** $current_block_height\n**Network Block:** $current_network_block\n**Blocks Behind:** $current_block_lag$lag_trend\n**Successful RPCs:** $EVM_LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((EVM_CONSECUTIVE_RPC_FAILS++))
            log "$EVM_CHAIN_NAME" "${YELLOW}Failed to fetch network block height from external RPCs (attempt $EVM_CONSECUTIVE_RPC_FAILS)${NC}"
            
            if [ $EVM_CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "$EVM_CHAIN_NAME" "⚠️ WARNING: $EVM_CHAIN_NAME External RPC Endpoints Unreachable" \
                    "Cannot fetch network block height for comparison.\n\n**Impact:** Unable to detect if $EVM_CHAIN_NAME node is falling behind network\n**RPC Results:**\n$EVM_LAST_RPC_RESULTS\n**Local monitoring continues:** Block sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            elif [ $EVM_CONSECUTIVE_RPC_FAILS -eq 6 ]; then
                send_discord_alert "$EVM_CHAIN_NAME" "⚠️ WARNING: $EVM_CHAIN_NAME External RPCs Down for 30+ Minutes" \
                    "$EVM_CHAIN_NAME external RPC endpoints have been unavailable for $EVM_CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((EVM_CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues" \
                    16776960
            fi
            
            current_network_block=$EVM_PREV_NETWORK_BLOCK
            current_block_lag=$EVM_PREV_BLOCK_LAG
        fi
    fi
    
    # Log current status
    log "$EVM_CHAIN_NAME" "${GREEN}Current Status: Block=$current_block_height (Full Node)$network_status${NC}"
    
    # Check block progression
    if [ $EVM_PREV_BLOCK_HEIGHT -gt 0 ] && [ $((current_time - EVM_PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_block_height" -le "$EVM_PREV_BLOCK_HEIGHT" ]; then
            local time_diff=$((current_time - EVM_PREV_CHECK_TIME))
            
            local network_info=""
            if [ "$EVM_EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_block -gt 0 ]; then
                network_info="**Network Block:** $current_network_block\n**Network is Progressing:** $([ $current_network_block -gt $EVM_PREV_NETWORK_BLOCK ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "$EVM_CHAIN_NAME" "⚠️ WARNING: $EVM_CHAIN_NAME Block Sync Stalled" \
                "$EVM_CHAIN_NAME node has stopped syncing new blocks.\n\n**Current Block:** $current_block_height\n**Previous Block:** $EVM_PREV_BLOCK_HEIGHT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info\n**Possible causes:**\n• Node synchronization problems\n• Network connectivity issues\n• $EVM_CHAIN_NAME node malfunction" \
                16776960
        else
            local blocks_synced=$((current_block_height - EVM_PREV_BLOCK_HEIGHT))
            local time_diff=$((current_time - EVM_PREV_CHECK_TIME))
            local blocks_per_min=$(echo "scale=2; $blocks_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "$EVM_CHAIN_NAME" "${GREEN}Blocks syncing normally: +$blocks_synced blocks in ${time_diff}s (${blocks_per_min} blocks/min)${NC}"
        fi
    fi
    
    # Save current state
    EVM_PREV_BLOCK_HEIGHT=$current_block_height
    EVM_PREV_CHECK_TIME=$current_time
    EVM_PREV_NETWORK_BLOCK=$current_network_block
    EVM_PREV_BLOCK_LAG=$current_block_lag
    
    log "$EVM_CHAIN_NAME" "${BLUE}$EVM_CHAIN_NAME monitoring completed${NC}"
    return 0
}

mod_sui() {
    log "SUI" "${YELLOW}SUI monitoring module - Coming soon!${NC}"
    return 0
}

# ================================
# SUBSTRATE MODULE
# ================================

# Function to query Substrate RPC
query_substrate_rpc() {
    local rpc_url="$1"
    local method="$2"
    local params="$3"
    local timeout="$4"
    
    local payload='{"jsonrpc":"2.0","method":"'$method'","params":'$params',"id":1}'
    curl -s --max-time $timeout \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$rpc_url" 2>/dev/null
}

# Function to get Substrate block number from local node
get_substrate_local_block() {
    local response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "chain_getHeader" "[]" 10)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Extract block number from header (hex format)
        local hex_block=$(echo "$response" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$hex_block" ] && [[ "$hex_block" =~ ^0x[0-9a-fA-F]+$ ]]; then
            hex_to_decimal "$hex_block"
            return 0
        fi
    fi
    
    return 1
}

# Function to get Substrate block from external RPC
get_substrate_external_block() {
    local rpc_url="$1"
    local timeout="$2"
    local response=$(query_substrate_rpc "$rpc_url" "chain_getHeader" "[]" $timeout)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local hex_block=$(echo "$response" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$hex_block" ] && [[ "$hex_block" =~ ^0x[0-9a-fA-F]+$ ]]; then
            hex_to_decimal "$hex_block"
            return 0
        fi
    fi
    
    return 1
}

# Function to auto-detect validator stash address
detect_substrate_validator_stash() {
    if [ "$SUBSTRATE_TYPE" != "validator" ]; then
        echo ""
        return 1
    fi
    
    # Try to get validator stash from author_hasSessionKeys
    local response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "author_hasSessionKeys" '[""]' 5)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local has_keys=$(echo "$response" | grep -o '"result":[^,}]*' | cut -d':' -f2)
        if [ "$has_keys" = "true" ]; then
            # Try to get the stash from system_localPeerId and cross-reference
            local peer_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "system_localPeerId" "[]" 5)
            if [ $? -eq 0 ] && [ -n "$peer_response" ]; then
                # This is a simplified detection - in practice, you might need to check session keys
                # For now, we'll try to get it from the validator list and match with our session keys
                local validators_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "session_validators" "[]" 10)
                if [ $? -eq 0 ] && [ -n "$validators_response" ]; then
                    # Extract first validator from the list as a fallback (this is not accurate)
                    # In production, you'd want to match session keys properly
                    local first_validator=$(echo "$validators_response" | grep -o '"[0-9a-zA-Z]*"' | head -1 | tr -d '"')
                    if [ -n "$first_validator" ] && [ ${#first_validator} -gt 40 ]; then
                        echo "$first_validator"
                        return 0
                    fi
                fi
            fi
        fi
    fi
    
    # If auto-detection fails, return empty
    echo ""
    return 1
}

# Function to get validator stash address (Option C: Manual + Auto-detection)
get_substrate_validator_stash() {
    # Option 1: Use manually configured stash address
    if [ -n "$SUBSTRATE_VALIDATOR_STASH" ]; then
        echo "$SUBSTRATE_VALIDATOR_STASH"
        return 0
    fi
    
    # Option 2: Use previously detected stash address
    if [ -n "$SUBSTRATE_DETECTED_STASH" ]; then
        echo "$SUBSTRATE_DETECTED_STASH"
        return 0
    fi
    
    # Option 3: Try to auto-detect
    local detected_stash=$(detect_substrate_validator_stash)
    if [ -n "$detected_stash" ]; then
        SUBSTRATE_DETECTED_STASH="$detected_stash"
        log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Auto-detected validator stash: $detected_stash${NC}"
        echo "$detected_stash"
        return 0
    fi
    
    # No stash address available
    echo ""
    return 1
}

# Function to get comprehensive validator status
get_substrate_comprehensive_validator_status() {
    if [ "$SUBSTRATE_TYPE" != "validator" ]; then
        echo "N/A:N/A:0"
        return 0
    fi
    
    local validator_stash=$(get_substrate_validator_stash)
    if [ -z "$validator_stash" ]; then
        log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}No validator stash address available for status check${NC}"
        echo "Unknown:Unknown:0"
        return 1
    fi
    
    local is_active=0
    local is_waiting=0
    local stake_amount=0
    local commission=""
    
    # Check 1: Is validator in current session validators (active set)
    local session_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "session_validators" "[]" 10)
    if [ $? -eq 0 ] && [ -n "$session_response" ]; then
        if echo "$session_response" | grep -q "$validator_stash"; then
            is_active=1
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator found in active session${NC}" >&2
        fi
    fi
    
    # Check 2: Get staking info from staking_validators
    local staking_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_validators" "[]" 10)
    if [ $? -eq 0 ] && [ -n "$staking_response" ]; then
        if echo "$staking_response" | grep -q "$validator_stash"; then
            is_waiting=1
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator found in staking validators list${NC}" >&2
            
            # Extract commission if available (simplified)
            commission=$(echo "$staking_response" | grep -A5 -B5 "$validator_stash" | grep -o '"commission":[0-9]*' | cut -d':' -f2)
        fi
    fi
    
    # Check 3: Get detailed staking ledger for stake amount
    local ledger_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_ledger" "[\"$validator_stash\"]" 10)
    if [ $? -eq 0 ] && [ -n "$ledger_response" ]; then
        # Extract total stake amount (this is simplified - actual format may vary)
        local raw_stake=$(echo "$ledger_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        if [ -n "$raw_stake" ] && [ "$raw_stake" -gt 0 ]; then
            # Convert from chain units to readable format (divide by 10^decimals)
            # For Avail, it's usually 18 decimals, but this is simplified
            stake_amount=$((raw_stake / 1000000000000000000))  # Assuming 18 decimals
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator stake amount: $stake_amount${NC}" >&2
        fi
    fi
    
    # Check 4: Verify with staking_activeEra
    local era_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_activeEra" "[]" 5)
    if [ $? -eq 0 ] && [ -n "$era_response" ]; then
        local era_index=$(echo "$era_response" | grep -o '"index":[0-9]*' | cut -d':' -f2)
        if [ -n "$era_index" ]; then
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Current era: $era_index${NC}" >&2
        fi
    fi
    
    # Determine overall status
    local status="Inactive"
    if [ $is_active -eq 1 ]; then
        status="Active"
    elif [ $is_waiting -eq 1 ]; then
        status="Waiting"
    fi
    
    # Return: status:commission:stake_amount
    echo "$status:${commission:-Unknown}:$stake_amount"
    return 0
}

# Function to get enhanced Substrate validator information with position tracking
get_substrate_enhanced_validator_info() {
    if [ "$SUBSTRATE_TYPE" != "validator" ]; then
        echo "N/A:N/A:0:0:0"
        return 0
    fi
    
    local validator_stash=$(get_substrate_validator_stash)
    if [ -z "$validator_stash" ]; then
        log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}No validator stash address available for enhanced status check${NC}"
        echo "Unknown:Unknown:0:0:0"
        return 1
    fi
    
    local is_active=0
    local is_waiting=0
    local stake_amount=0
    local commission=""
    local position=0
    local max_validators=0
    
    # Check 1: Is validator in current session validators (active set)
    local session_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "session_validators" "[]" 10)
    if [ $? -eq 0 ] && [ -n "$session_response" ]; then
        if echo "$session_response" | grep -q "$validator_stash"; then
            is_active=1
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator found in active session${NC}" >&2
        fi
        
        # Count total active validators
        max_validators=$(echo "$session_response" | grep -o '"[0-9a-zA-Z]*"' | wc -l)
        
        # Find validator position in active set (simplified)
        if [ $is_active -eq 1 ]; then
            position=$(echo "$session_response" | grep -o '"[0-9a-zA-Z]*"' | nl | grep "$validator_stash" | awk '{print $1}')
        fi
    fi
    
    # Check 2: Get staking info for all validators to determine position
    local staking_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_validators" "[]" 10)
    if [ $? -eq 0 ] && [ -n "$staking_response" ]; then
        if echo "$staking_response" | grep -q "$validator_stash"; then
            is_waiting=1
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator found in staking validators list${NC}" >&2
            
            # Extract commission if available (simplified)
            commission=$(echo "$staking_response" | grep -A5 -B5 "$validator_stash" | grep -o '"commission":[0-9]*' | cut -d':' -f2)
        fi
    fi
    
    # Check 3: Get detailed staking ledger for stake amount
    local ledger_response=$(query_substrate_rpc "$SUBSTRATE_RPC_URL" "staking_ledger" "[\"$validator_stash\"]" 10)
    if [ $? -eq 0 ] && [ -n "$ledger_response" ]; then
        # Extract total stake amount (this is simplified - actual format may vary)
        local raw_stake=$(echo "$ledger_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        if [ -n "$raw_stake" ] && [ "$raw_stake" -gt 0 ]; then
            # Convert from chain units to readable format (divide by 10^decimals)
            # For Avail, it's usually 18 decimals, but this is simplified
            stake_amount=$((raw_stake / 1000000000000000000))  # Assuming 18 decimals
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator stake amount: $stake_amount${NC}" >&2
        fi
    fi
    
    # If we couldn't determine position from active set, try to get approximate position from all validators
    if [ $position -eq 0 ] && [ $is_waiting -eq 1 ]; then
        # This would require sorting all validators by stake amount
        # For now, we'll use a simplified approach
        position=$((max_validators + 10))  # Assume we're just outside active set
    fi
    
    # Use configured max validators if detection failed
    if [ $max_validators -eq 0 ]; then
        max_validators=$SUBSTRATE_MAX_VALIDATORS
    fi
    
    # Determine overall status
    local status="Inactive"
    if [ $is_active -eq 1 ]; then
        status="Active"
    elif [ $is_waiting -eq 1 ]; then
        status="Waiting"
    fi
    
    # Return: status:commission:stake_amount:position:max_validators
    echo "$status:${commission:-Unknown}:$stake_amount:$position:$max_validators"
    return 0
}
}

# Function to assess Substrate validator position risk
assess_substrate_position_risk() {
    local position="$1"
    local max_validators="$2"
    local current_stake="$3"
    local prev_position="$4"
    
    if [ "$position" -eq 0 ] || [ "$max_validators" -eq 0 ]; then
        return 0  # No risk assessment possible
    fi
    
    local positions_from_bottom=$((max_validators - position + 1))
    
    # Format stake amount using detected decimals
    local formatted_stake="$current_stake"
    if [ "$EFFECTIVE_SUBSTRATE_TOKEN_DECIMALS" -gt 0 ] && [ "$current_stake" -gt 0 ]; then
        local divisor=1
        for i in $(seq 1 $EFFECTIVE_SUBSTRATE_TOKEN_DECIMALS); do
            divisor=$((divisor * 10))
        done
        formatted_stake=$(echo "scale=2; $current_stake / $divisor" | bc -l 2>/dev/null || echo "$current_stake")
    fi
    
    # Critical risk: very close to falling out of active set
    if [ "$positions_from_bottom" -le 3 ]; then
        send_discord_alert "$SUBSTRATE_CHAIN_NAME" "🚨 CRITICAL: Validator at High Risk of Falling Out" \
            "**URGENT: Validator position is critically low!**\n\n**Current Position:** $position out of $max_validators\n**Distance from Bottom:** $positions_from_bottom positions\n**Current Stake:** $formatted_stake $EFFECTIVE_SUBSTRATE_TOKEN_SYMBOL\n**Previous Position:** $prev_position\n**Status:** At immediate risk of losing validator status\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**IMMEDIATE ACTION REQUIRED:**\n• Increase validator stake urgently\n• Check for upcoming unbonding\n• Monitor nomination changes\n• Consider emergency staking\n• Review session keys" \
            16711680
    # Warning: within warning threshold
    elif [ "$positions_from_bottom" -le "$SUBSTRATE_POSITION_WARNING_THRESHOLD" ]; then
        send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: Validator Position Risk" \
            "Validator position is approaching the danger zone.\n\n**Current Position:** $position out of $max_validators\n**Distance from Bottom:** $positions_from_bottom positions\n**Current Stake:** $formatted_stake $EFFECTIVE_SUBSTRATE_TOKEN_SYMBOL\n**Previous Position:** $prev_position\n**Warning Threshold:** $SUBSTRATE_POSITION_WARNING_THRESHOLD positions\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Consider taking action:**\n• Monitor stake changes closely\n• Prepare to increase stake if needed\n• Check for any pending unbonding\n• Review nomination strategy" \
            16776960
    fi
    
    # Position change alerts (informational)
    if [ "$prev_position" -gt 0 ] && [ "$position" -ne "$prev_position" ]; then
        local position_change=$((position - prev_position))
        local direction="improved"
        local emoji="📈"
        
        if [ $position_change -gt 0 ]; then
            direction="dropped"
            emoji="📉"
        fi
        
        # Only alert on significant position changes (more than 2 positions)
        if [ "${position_change#-}" -gt 2 ]; then
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "$emoji INFO: Validator Position Changed" \
                "Validator position has $direction significantly.\n\n**Previous Position:** $prev_position\n**Current Position:** $position\n**Change:** $([ $position_change -gt 0 ] && echo "+")$position_change positions\n**Current Stake:** $formatted_stake $EFFECTIVE_SUBSTRATE_TOKEN_SYMBOL\n**Distance from Bottom:** $positions_from_bottom positions\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                2196f3
        fi
    fi
}
}

# Function to get Substrate network block height from multiple RPCs
get_substrate_network_block_height() {
    local IFS=','
    local rpcs=($SUBSTRATE_EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_block=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)
        if [ -n "$rpc" ]; then
            local block_height
            if block_height=$(get_substrate_external_block "$rpc" 10); then
                ((successful_rpcs++))
                if [ "$block_height" -gt "$highest_block" ]; then
                    highest_block=$block_height
                fi
                rpc_results+="✅ $rpc: $block_height\n"
                log "$SUBSTRATE_CHAIN_NAME" "${GREEN}RPC Success: $rpc returned block $block_height${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    SUBSTRATE_LAST_RPC_RESULTS="$rpc_results"
    SUBSTRATE_LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge 1 ]; then
        echo $highest_block
        return 0
    else
        return 1
    fi
}

# Main Substrate monitoring function
mod_substrate() {
    local current_time=$(date +%s)
    
    log "$SUBSTRATE_CHAIN_NAME" "${BLUE}Starting $SUBSTRATE_CHAIN_NAME monitoring...${NC}"
    
    # Auto-detect chain parameters if not cached
    if [ "$SUBSTRATE_DETECTED_MAX_VALIDATORS" -eq 0 ] || [ -z "$SUBSTRATE_DETECTED_TOKEN_SYMBOL" ]; then
        detect_substrate_chain_params
    fi
    
    # Get effective parameters (detected or configured)
    get_substrate_chain_params
    
    # Fetch current block height
    local current_block_height=$(get_substrate_local_block)
    local current_validator_status="N/A"
    local current_stake_amount=0
    local current_commission=""
    local stake_status=""
    
    # Get comprehensive validator status if validator node
    if [ "$SUBSTRATE_TYPE" = "validator" ]; then
        local full_info=$(get_substrate_enhanced_validator_info)
        if [ $? -eq 0 ] && [ -n "$full_info" ]; then
            local status_part=$(echo "$full_info" | cut -d':' -f1)
            current_commission=$(echo "$full_info" | cut -d':' -f2)
            current_stake_amount=$(echo "$full_info" | cut -d':' -f3)
            local current_position=$(echo "$full_info" | cut -d':' -f4)
            local current_max_validators=$(echo "$full_info" | cut -d':' -f5)
            
            # Convert to simple status for compatibility
            case "$status_part" in
                "Active") current_validator_status="1" ;;
                "Waiting") current_validator_status="0" ;;
                "Inactive") current_validator_status="0" ;;
                *) current_validator_status="0" ;;
            esac
            
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator enhanced info: $status_part, Position: $current_position/$current_max_validators, Stake: $current_stake_amount, Commission: $current_commission${NC}"
            
            # Store position info for later use and risk assessment
            SUBSTRATE_CURRENT_POSITION=$current_position
            SUBSTRATE_CURRENT_MAX_VALIDATORS=$current_max_validators
        else
            # Fallback to basic comprehensive status
            local full_status=$(get_substrate_comprehensive_validator_status)
            if [ $? -eq 0 ] && [ -n "$full_status" ]; then
                local status_part=$(echo "$full_status" | cut -d':' -f1)
                current_commission=$(echo "$full_status" | cut -d':' -f2)
                current_stake_amount=$(echo "$full_status" | cut -d':' -f3)
                
                case "$status_part" in
                    "Active") current_validator_status="1" ;;
                    "Waiting") current_validator_status="0" ;;
                    "Inactive") current_validator_status="0" ;;
                    *) current_validator_status="0" ;;
                esac
                
                log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Validator comprehensive status: $status_part, Commission: $current_commission, Stake: $current_stake_amount${NC}"
            else
                current_validator_status=$(get_substrate_validator_status)
                log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}Using fallback validator status check${NC}"
            fi
        fi
    fi
    
    # Validate block height was fetched
    if [ -z "$current_block_height" ]; then
        log "$SUBSTRATE_CHAIN_NAME" "${RED}CRITICAL: Failed to fetch block height from $SUBSTRATE_RPC_URL${NC}"
        ((SUBSTRATE_CONSECUTIVE_FAILS++))
        
        local node_type_desc=$([ "$SUBSTRATE_TYPE" = "validator" ] && echo "$SUBSTRATE_CHAIN_NAME Validator Node" || echo "$SUBSTRATE_CHAIN_NAME Full Node")
        
        # Send immediate alert on first failure
        if [ $SUBSTRATE_CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "🚨 CRITICAL: $SUBSTRATE_CHAIN_NAME Node Unavailable" \
                "**URGENT: $SUBSTRATE_CHAIN_NAME Node appears to be DOWN!**\n\nUnable to fetch block height from $node_type_desc.\n\n**Node Type:** $node_type_desc\n**RPC URL:** $SUBSTRATE_RPC_URL\n**Status:** Node may be completely down or RPC port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if $SUBSTRATE_CHAIN_NAME node process is running\n• Verify RPC port is accessible\n• Check system resources\n• Review $SUBSTRATE_CHAIN_NAME node logs" \
                16711680
        elif [ $SUBSTRATE_CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "🚨 CRITICAL: $SUBSTRATE_CHAIN_NAME Node Still Down" \
                "$SUBSTRATE_CHAIN_NAME node has been unresponsive for $SUBSTRATE_CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((SUBSTRATE_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Still unable to fetch block height\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $SUBSTRATE_CONSECUTIVE_FAILS -eq 12 ]; then
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "🚨 CRITICAL: $SUBSTRATE_CHAIN_NAME Node Down for 1+ Hour" \
                "$SUBSTRATE_CHAIN_NAME node has been unresponsive for over 1 hour ($SUBSTRATE_CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((SUBSTRATE_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Extended outage detected\n\n**THIS MAY RESULT IN SLASHING PENALTIES**" \
                16711680
        fi
        
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $SUBSTRATE_CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((SUBSTRATE_CONSECUTIVE_FAILS * 5))
        local node_type_desc=$([ "$SUBSTRATE_TYPE" = "validator" ] && echo "$SUBSTRATE_CHAIN_NAME Validator Node" || echo "$SUBSTRATE_CHAIN_NAME Full Node")
        
        local recovery_details="**Outage Duration:** ~${outage_duration} minutes ($SUBSTRATE_CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Block:** $current_block_height"
        
        if [ "$SUBSTRATE_TYPE" = "validator" ] && [ -n "$current_stake_amount" ] && [ "$current_stake_amount" -gt 0 ]; then
            recovery_details+="\n**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n**Current Stake:** $current_stake_amount"
        fi
        
        send_discord_alert "$SUBSTRATE_CHAIN_NAME" "✅ $SUBSTRATE_CHAIN_NAME Node Recovered" \
            "$node_type_desc is back online and responding.\n\n$recovery_details" \
            65280
        
        log "$SUBSTRATE_CHAIN_NAME" "${GREEN}$SUBSTRATE_CHAIN_NAME node recovered after $SUBSTRATE_CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    SUBSTRATE_CONSECUTIVE_FAILS=0
    
    # Validator position risk assessment
    if [ "$SUBSTRATE_TYPE" = "validator" ] && [ -n "$SUBSTRATE_CURRENT_POSITION" ] && [ "$SUBSTRATE_CURRENT_POSITION" -gt 0 ]; then
        assess_substrate_position_risk "$SUBSTRATE_CURRENT_POSITION" "$SUBSTRATE_CURRENT_MAX_VALIDATORS" "$current_stake_amount" "$SUBSTRATE_PREV_POSITION"
    fi
    
    # Stake amount monitoring for validators
    if [ "$SUBSTRATE_TYPE" = "validator" ] && [ "$current_stake_amount" -gt 0 ]; then
        # Check for significant stake changes
        if [ "$SUBSTRATE_PREV_STAKE_AMOUNT" -gt 0 ]; then
            local stake_diff=$((SUBSTRATE_PREV_STAKE_AMOUNT - current_stake_amount))
            local stake_percent_change=0
            
            if [ "$SUBSTRATE_PREV_STAKE_AMOUNT" -gt 0 ]; then
                stake_percent_change=$((stake_diff * 100 / SUBSTRATE_PREV_STAKE_AMOUNT))
            fi
            
            # Alert on significant stake decrease
            if [ "$stake_percent_change" -gt "$SUBSTRATE_STAKE_THRESHOLD_PERCENT" ]; then
                send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: Significant Stake Decrease Detected" \
                    "Validator stake has decreased significantly.\n\n**Previous Stake:** $SUBSTRATE_PREV_STAKE_AMOUNT\n**Current Stake:** $current_stake_amount\n**Decrease:** $stake_diff (-${stake_percent_change}%)\n**Threshold:** ${SUBSTRATE_STAKE_THRESHOLD_PERCENT}%\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Possible causes:**\n• Unstaking/unbonding\n• Slashing event\n• Delegator withdrawals\n• Commission changes" \
                    16776960
            # Alert on significant stake increase (informational)
            elif [ "$stake_diff" -lt 0 ] && [ "$((stake_diff * -1 * 100 / SUBSTRATE_PREV_STAKE_AMOUNT))" -gt "$SUBSTRATE_STAKE_THRESHOLD_PERCENT" ]; then
                local increase_percent=$(( (current_stake_amount - SUBSTRATE_PREV_STAKE_AMOUNT) * 100 / SUBSTRATE_PREV_STAKE_AMOUNT ))
                send_discord_alert "$SUBSTRATE_CHAIN_NAME" "📈 INFO: Significant Stake Increase Detected" \
                    "Validator stake has increased significantly.\n\n**Previous Stake:** $SUBSTRATE_PREV_STAKE_AMOUNT\n**Current Stake:** $current_stake_amount\n**Increase:** $((current_stake_amount - SUBSTRATE_PREV_STAKE_AMOUNT)) (+${increase_percent}%)\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    65280
            fi
        fi
        
        # Alert if stake is below minimum threshold
        if [ "$current_stake_amount" -lt "$SUBSTRATE_MIN_STAKE_ALERT" ] && [ "$current_stake_amount" -gt 0 ]; then
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: Validator Stake Below Minimum" \
                "Validator stake is below the configured minimum threshold.\n\n**Current Stake:** $current_stake_amount\n**Minimum Threshold:** $SUBSTRATE_MIN_STAKE_ALERT\n**Status:** $([ "$current_validator_status" = "1" ] && echo "Still Active" || echo "Inactive")\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Risk:** May lose validator status if stake too low" \
                16776960
        fi
        
        stake_status=" (Stake: $current_stake_amount)"
    fi
    
    # External RPC comparison (if enabled)
    local current_network_block=0
    local current_block_lag=0
    local network_status=""
    
    if [ "$SUBSTRATE_EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_block=$(get_substrate_network_block_height); then
            # Reset RPC fails and send recovery notification if needed
            if [ $SUBSTRATE_CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "$SUBSTRATE_CHAIN_NAME" "✅ $SUBSTRATE_CHAIN_NAME External RPC Endpoints Recovered" \
                    "$SUBSTRATE_CHAIN_NAME external RPC endpoints are responding again.\n\n**Outage Duration:** $SUBSTRATE_CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Block:** $current_network_block" \
                    65280
                
                log "$SUBSTRATE_CHAIN_NAME" "${GREEN}External RPCs recovered after $SUBSTRATE_CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            SUBSTRATE_CONSECUTIVE_RPC_FAILS=0
            
            current_block_lag=$((current_network_block - current_block_height))
            
            if [ $current_block_lag -gt 0 ]; then
                network_status=" ($current_block_lag blocks behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Network comparison: Local=$current_block_height, Network=$current_network_block$network_status${NC}"
            
            # Check for significant block lag
            if [ $current_block_lag -gt $SUBSTRATE_BLOCK_LAG_THRESHOLD ]; then
                local lag_trend=""
                if [ $SUBSTRATE_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -gt $SUBSTRATE_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag increasing: was $SUBSTRATE_PREV_BLOCK_LAG blocks behind)"
                elif [ $SUBSTRATE_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -lt $SUBSTRATE_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag decreasing: was $SUBSTRATE_PREV_BLOCK_LAG blocks behind, catching up)"
                fi
                
                local node_type_desc=$([ "$SUBSTRATE_TYPE" = "validator" ] && echo "$SUBSTRATE_CHAIN_NAME Validator" || echo "$SUBSTRATE_CHAIN_NAME Full Node")
                local status_info=""
                
                if [ "$SUBSTRATE_TYPE" = "validator" ]; then
                    status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                    if [ -n "$current_stake_amount" ] && [ "$current_stake_amount" -gt 0 ]; then
                        status_info+="**Stake Amount:** $current_stake_amount\n"
                    fi
                fi
                
                if [ $current_block_lag -gt $((SUBSTRATE_BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_block_lag -gt $SUBSTRATE_PREV_BLOCK_LAG ]; then
                    send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: $SUBSTRATE_CHAIN_NAME Node Falling Behind Network" \
                        "$SUBSTRATE_CHAIN_NAME node is significantly behind the network.\n\n**Node Type:** $node_type_desc\n**Local Block:** $current_block_height\n**Network Block:** $current_network_block\n**Blocks Behind:** $current_block_lag$lag_trend\n$status_info\n**Successful RPCs:** $SUBSTRATE_LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((SUBSTRATE_CONSECUTIVE_RPC_FAILS++))
            log "$SUBSTRATE_CHAIN_NAME" "${YELLOW}Failed to fetch network block height from external RPCs (attempt $SUBSTRATE_CONSECUTIVE_RPC_FAILS)${NC}"
            
            if [ $SUBSTRATE_CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: $SUBSTRATE_CHAIN_NAME External RPC Endpoints Unreachable" \
                    "Cannot fetch network block height for comparison.\n\n**Impact:** Unable to detect if $SUBSTRATE_CHAIN_NAME node is falling behind network\n**RPC Results:**\n$SUBSTRATE_LAST_RPC_RESULTS\n**Local monitoring continues:** Block sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            elif [ $SUBSTRATE_CONSECUTIVE_RPC_FAILS -eq 6 ]; then
                send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: $SUBSTRATE_CHAIN_NAME External RPCs Down for 30+ Minutes" \
                    "$SUBSTRATE_CHAIN_NAME external RPC endpoints have been unavailable for $SUBSTRATE_CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((SUBSTRATE_CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues" \
                    16776960
            fi
            
            current_network_block=$SUBSTRATE_PREV_NETWORK_BLOCK
            current_block_lag=$SUBSTRATE_PREV_BLOCK_LAG
        fi
    fi
    
    # Log current status
    if [ "$SUBSTRATE_TYPE" = "validator" ]; then
        log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Current Status: Validator=$([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive"), Block=$current_block_height$network_status$stake_status${NC}"
    else
        log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Current Status: Block=$current_block_height (Full Node)$network_status${NC}"
    fi
    
    # Check validator status for validator nodes
    if [ "$SUBSTRATE_TYPE" = "validator" ]; then
        if [ "$current_validator_status" = "0" ] && [ "$SUBSTRATE_PREV_VALIDATOR_STATUS" = "1" ]; then
            local alert_details="**URGENT ACTION REQUIRED**\n\n$SUBSTRATE_CHAIN_NAME Validator has been removed from the active validator set!\n\n**Current Status:** Inactive (0)\n**Previous Status:** Active (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')"
            
            if [ -n "$current_stake_amount" ] && [ "$current_stake_amount" -gt 0 ]; then
                alert_details+="\n**Current Stake:** $current_stake_amount"
            fi
            
            if [ -n "$current_commission" ] && [ "$current_commission" != "Unknown" ]; then
                alert_details+="\n**Commission:** $current_commission"
            fi
            
            alert_details+="\n\n**Immediate actions needed:**\n• Check $SUBSTRATE_CHAIN_NAME validator logs\n• Verify staking requirements\n• Check slashing conditions\n• Review validator performance\n• Check session keys\n• Verify stake amount is sufficient"
            
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "🚨 CRITICAL: $SUBSTRATE_CHAIN_NAME Validator Removed from Active Set" \
                "$alert_details" \
                16711680
                
        elif [ "$current_validator_status" = "1" ] && [ "$SUBSTRATE_PREV_VALIDATOR_STATUS" = "0" ]; then
            local recovery_details="$SUBSTRATE_CHAIN_NAME Validator has been restored to the active validator set.\n\n**Current Status:** Active (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')"
            
            if [ -n "$current_stake_amount" ] && [ "$current_stake_amount" -gt 0 ]; then
                recovery_details+="\n**Current Stake:** $current_stake_amount"
            fi
            
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "✅ $SUBSTRATE_CHAIN_NAME Validator Restored to Active Set" \
                "$recovery_details" \
                65280
        fi
    fi
    
    # Check block progression
    if [ $SUBSTRATE_PREV_BLOCK_HEIGHT -gt 0 ] && [ $((current_time - SUBSTRATE_PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_block_height" -le "$SUBSTRATE_PREV_BLOCK_HEIGHT" ]; then
            local time_diff=$((current_time - SUBSTRATE_PREV_CHECK_TIME))
            local node_type_desc=$([ "$SUBSTRATE_TYPE" = "validator" ] && echo "$SUBSTRATE_CHAIN_NAME Validator" || echo "$SUBSTRATE_CHAIN_NAME Full Node")
            local status_info=""
            
            if [ "$SUBSTRATE_TYPE" = "validator" ]; then
                status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                if [ -n "$current_stake_amount" ] && [ "$current_stake_amount" -gt 0 ]; then
                    status_info+="**Stake Amount:** $current_stake_amount\n"
                fi
            fi
            
            local network_info=""
            if [ "$SUBSTRATE_EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_block -gt 0 ]; then
                network_info="**Network Block:** $current_network_block\n**Network is Progressing:** $([ $current_network_block -gt $SUBSTRATE_PREV_NETWORK_BLOCK ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "$SUBSTRATE_CHAIN_NAME" "⚠️ WARNING: $SUBSTRATE_CHAIN_NAME Block Sync Stalled" \
                "$SUBSTRATE_CHAIN_NAME node has stopped syncing new blocks.\n\n**Node Type:** $node_type_desc\n**Current Block:** $current_block_height\n**Previous Block:** $SUBSTRATE_PREV_BLOCK_HEIGHT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info$status_info\n**Possible causes:**\n• Node synchronization problems\n• Network connectivity issues\n• $SUBSTRATE_CHAIN_NAME node malfunction\n• Session key issues (validators)\n• Insufficient stake (validators)" \
                16776960
        else
            local blocks_synced=$((current_block_height - SUBSTRATE_PREV_BLOCK_HEIGHT))
            local time_diff=$((current_time - SUBSTRATE_PREV_CHECK_TIME))
            local blocks_per_min=$(echo "scale=2; $blocks_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "$SUBSTRATE_CHAIN_NAME" "${GREEN}Blocks syncing normally: +$blocks_synced blocks in ${time_diff}s (${blocks_per_min} blocks/min)${NC}"
        fi
    fi
    
    # Save current state
    SUBSTRATE_PREV_BLOCK_HEIGHT=$current_block_height
    SUBSTRATE_PREV_CHECK_TIME=$current_time
    SUBSTRATE_PREV_NETWORK_BLOCK=$current_network_block
    SUBSTRATE_PREV_BLOCK_LAG=$current_block_lag
    SUBSTRATE_PREV_VALIDATOR_STATUS=$current_validator_status
    SUBSTRATE_PREV_STAKE_AMOUNT=$current_stake_amount
    SUBSTRATE_PREV_VALIDATOR_PREFS="$current_commission"
    SUBSTRATE_PREV_POSITION=${SUBSTRATE_CURRENT_POSITION:-0}
    SUBSTRATE_PREV_MAX_VALIDATORS=${SUBSTRATE_CURRENT_MAX_VALIDATORS:-$SUBSTRATE_MAX_VALIDATORS}
    
    log "$SUBSTRATE_CHAIN_NAME" "${BLUE}$SUBSTRATE_CHAIN_NAME monitoring completed${NC}"
    return 0
}

# ================================
# COSMOS MODULE
# ================================

# Function to query Cosmos RPC
query_cosmos_rpc() {
    local rpc_url="$1"
    local endpoint="$2"
    local timeout="$3"
    
    curl -s --max-time $timeout "$rpc_url/$endpoint" 2>/dev/null
}

# Function to query Cosmos REST API
query_cosmos_rest() {
    local rest_url="$1"
    local endpoint="$2"
    local timeout="$3"
    
    curl -s --max-time $timeout "$rest_url/$endpoint" 2>/dev/null
}

# Function to get Cosmos block height from local node
get_cosmos_local_block() {
    local response=$(query_cosmos_rpc "$COSMOS_RPC_URL" "status" 10)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Extract block height from status response
        local block_height=$(echo "$response" | grep -o '"height":"[0-9]*"' | cut -d'"' -f4)
        if [ -n "$block_height" ] && [[ "$block_height" =~ ^[0-9]+$ ]]; then
            echo "$block_height"
            return 0
        fi
    fi
    
    return 1
}

# Function to get Cosmos block from external RPC
get_cosmos_external_block() {
    local rpc_url="$1"
    local timeout="$2"
    local response=$(query_cosmos_rpc "$rpc_url" "status" $timeout)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local block_height=$(echo "$response" | grep -o '"height":"[0-9]*"' | cut -d'"' -f4)
        if [ -n "$block_height" ] && [[ "$block_height" =~ ^[0-9]+$ ]]; then
            echo "$block_height"
            return 0
        fi
    fi
    
    return 1
}

# Function to format Cosmos amount (convert from base units to readable format)
format_cosmos_amount() {
    local amount="$1"
    local exponent="${2:-$EFFECTIVE_COSMOS_DENOM_EXPONENT}"
    
    if [ -z "$amount" ] || [ "$amount" = "0" ]; then
        echo "0"
        return
    fi
    
    # Convert from base units (e.g., uatom to ATOM)
    local divisor=1
    for i in $(seq 1 $exponent); do
        divisor=$((divisor * 10))
    done
    
    echo "scale=2; $amount / $divisor" | bc -l 2>/dev/null || echo "$amount"
}

# Function to get comprehensive Cosmos validator information
get_cosmos_comprehensive_validator_info() {
    if [ "$COSMOS_TYPE" != "validator" ]; then
        echo "N/A:N/A:0:0:0"
        return 0
    fi
    
    if [ -z "$COSMOS_VALIDATOR_ADDRESS" ]; then
        log "$COSMOS_CHAIN_NAME" "${YELLOW}No validator address configured${NC}"
        echo "Unknown:Unknown:0:0:0"
        return 1
    fi
    
    local status="Inactive"
    local commission="Unknown"
    local bonded_tokens=0
    local position=0
    local max_validators=0
    
    # Get validator details
    local validator_response=$(query_cosmos_rest "$COSMOS_REST_URL" "cosmos/staking/v1beta1/validators/$COSMOS_VALIDATOR_ADDRESS" 10)
    
    if [ $? -eq 0 ] && [ -n "$validator_response" ]; then
        # Extract validator status
        local validator_status=$(echo "$validator_response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        
        case "$validator_status" in
            "BOND_STATUS_BONDED") status="Active" ;;
            "BOND_STATUS_UNBONDED") status="Inactive" ;;
            "BOND_STATUS_UNBONDING") status="Unbonding" ;;
            *) status="Unknown" ;;
        esac
        
        # Extract bonded tokens
        local tokens_raw=$(echo "$validator_response" | grep -o '"tokens":"[0-9]*"' | cut -d'"' -f4)
        if [ -n "$tokens_raw" ] && [ "$tokens_raw" -gt 0 ]; then
            bonded_tokens=$tokens_raw
        fi
        
        # Extract commission rate
        local commission_raw=$(echo "$validator_response" | grep -o '"rate":"[0-9.]*"' | cut -d'"' -f4)
        if [ -n "$commission_raw" ]; then
            # Convert from decimal to percentage (multiply by 100)
            commission=$(echo "scale=2; $commission_raw * 100" | bc -l 2>/dev/null || echo "$commission_raw")
        fi
        
        log "$COSMOS_CHAIN_NAME" "${GREEN}Validator details: Status=$status, Tokens=$bonded_tokens, Commission=${commission}%${NC}" >&2
    fi
    
    # Get all validators to determine position and max validators
    local all_validators_response=$(query_cosmos_rest "$COSMOS_REST_URL" "cosmos/staking/v1beta1/validators?pagination.limit=300&status=BOND_STATUS_BONDED" 10)
    
    if [ $? -eq 0 ] && [ -n "$all_validators_response" ]; then
        # Count total bonded validators (this gives us the active set size)
        max_validators=$(echo "$all_validators_response" | grep -o '"operator_address":"[^"]*"' | wc -l)
        
        # Create temporary file to sort validators by bonded tokens
        local temp_file=$(mktemp)
        
        # Extract validator addresses and their bonded tokens
        echo "$all_validators_response" | grep -o '"operator_address":"[^"]*","consensus_pubkey":[^}]*},"jailed":[^,]*,"status":"[^"]*","tokens":"[0-9]*"' | \
        while IFS= read -r line; do
            local addr=$(echo "$line" | grep -o '"operator_address":"[^"]*"' | cut -d'"' -f4)
            local tokens=$(echo "$line" | grep -o '"tokens":"[0-9]*"' | cut -d'"' -f4)
            echo "$tokens $addr"
        done | sort -nr > "$temp_file"
        
        # Find our validator's position
        position=$(grep -n "$COSMOS_VALIDATOR_ADDRESS" "$temp_file" | cut -d':' -f1)
        
        # Clean up
        rm -f "$temp_file"
        
        if [ -z "$position" ]; then
            position=0
        fi
        
        log "$COSMOS_CHAIN_NAME" "${GREEN}Validator ranking: Position $position out of $max_validators active validators${NC}" >&2
    fi
    
    # Return: status:commission:bonded_tokens:position:max_validators
    echo "$status:$commission:$bonded_tokens:$position:$max_validators"
    return 0
}

# Function to get simple validator status (for backward compatibility)
get_cosmos_validator_status() {
    local full_info=$(get_cosmos_comprehensive_validator_info)
    local status=$(echo "$full_info" | cut -d':' -f1)
    
    case "$status" in
        "Active") echo "1" ;;
        "Unbonding") echo "0" ;;
        "Inactive") echo "0" ;;
        *) echo "0" ;;
    esac
}

# Function to get Cosmos network block height from multiple RPCs
get_cosmos_network_block_height() {
    local IFS=','
    local rpcs=($COSMOS_EXTERNAL_RPCS)
    local successful_rpcs=0
    local highest_block=0
    local rpc_results=""
    
    for rpc in "${rpcs[@]}"; do
        rpc=$(echo "$rpc" | xargs)
        if [ -n "$rpc" ]; then
            local block_height
            if block_height=$(get_cosmos_external_block "$rpc" 10); then
                ((successful_rpcs++))
                if [ "$block_height" -gt "$highest_block" ]; then
                    highest_block=$block_height
                fi
                rpc_results+="✅ $rpc: $block_height\n"
                log "$COSMOS_CHAIN_NAME" "${GREEN}RPC Success: $rpc returned block $block_height${NC}" >&2
            else
                rpc_results+="❌ $rpc: Failed\n"
                log "$COSMOS_CHAIN_NAME" "${YELLOW}RPC Failed: $rpc did not respond${NC}" >&2
            fi
        fi
    done
    
    COSMOS_LAST_RPC_RESULTS="$rpc_results"
    COSMOS_LAST_SUCCESSFUL_RPCS=$successful_rpcs
    
    if [ $successful_rpcs -ge 1 ]; then
        echo $highest_block
        return 0
    else
        return 1
    fi
}

# Function to assess validator position risk
assess_validator_position_risk() {
    local chain_name="$1"
    local position="$2"
    local max_validators="$3"
    local warning_threshold="$4"
    local current_stake="$5"
    local prev_position="$6"
    
    if [ "$position" -eq 0 ] || [ "$max_validators" -eq 0 ]; then
        return 0  # No risk assessment possible
    fi
    
    local positions_from_bottom=$((max_validators - position + 1))
    local formatted_stake=$(format_cosmos_amount "$current_stake")
    
    # Critical risk: very close to falling out
    if [ "$positions_from_bottom" -le 5 ]; then
        send_discord_alert "$chain_name" "🚨 CRITICAL: Validator at High Risk of Falling Out" \
            "**URGENT: Validator position is critically low!**\n\n**Current Position:** $position out of $max_validators\n**Distance from Bottom:** $positions_from_bottom positions\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Previous Position:** $prev_position\n**Status:** At immediate risk of losing validator status\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**IMMEDIATE ACTION REQUIRED:**\n• Increase validator stake urgently\n• Check for upcoming unbonding\n• Monitor delegation changes\n• Consider emergency staking" \
            16711680
    # Warning: within warning threshold
    elif [ "$positions_from_bottom" -le "$warning_threshold" ]; then
        send_discord_alert "$chain_name" "⚠️ WARNING: Validator Position Risk" \
            "Validator position is approaching the danger zone.\n\n**Current Position:** $position out of $max_validators\n**Distance from Bottom:** $positions_from_bottom positions\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Previous Position:** $prev_position\n**Warning Threshold:** $warning_threshold positions\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Consider taking action:**\n• Monitor stake changes closely\n• Prepare to increase stake if needed\n• Check for any pending unbonding\n• Review delegation strategy" \
            16776960
    fi
    
    # Position change alerts (informational)
    if [ "$prev_position" -gt 0 ] && [ "$position" -ne "$prev_position" ]; then
        local position_change=$((position - prev_position))
        local direction="improved"
        local emoji="📈"
        
        if [ $position_change -gt 0 ]; then
            direction="dropped"
            emoji="📉"
        fi
        
        # Only alert on significant position changes (more than 3 positions)
        if [ "${position_change#-}" -gt 3 ]; then
            send_discord_alert "$chain_name" "$emoji INFO: Validator Position Changed" \
                "Validator position has $direction significantly.\n\n**Previous Position:** $prev_position\n**Current Position:** $position\n**Change:** $([ $position_change -gt 0 ] && echo "+")$position_change positions\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Distance from Bottom:** $positions_from_bottom positions\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                2196f3
        fi
    fi
}

# Main Cosmos monitoring function
mod_cosmos() {
    local current_time=$(date +%s)
    
    log "$COSMOS_CHAIN_NAME" "${BLUE}Starting $COSMOS_CHAIN_NAME monitoring...${NC}"
    
    # Auto-detect chain parameters if not cached
    if [ -z "$COSMOS_DETECTED_DENOM" ] || [ "$COSMOS_DETECTED_MAX_VALIDATORS" -eq 0 ]; then
        detect_cosmos_chain_params
    fi
    
    # Get effective parameters (detected or configured)
    get_cosmos_chain_params
    
    # Fetch current block height
    local current_block_height=$(get_cosmos_local_block)
    local current_validator_status="N/A"
    local current_stake_amount=0
    local current_commission=""
    local current_position=0
    local current_max_validators=0
    
    # Get comprehensive validator info if validator node
    if [ "$COSMOS_TYPE" = "validator" ]; then
        local full_info=$(get_cosmos_comprehensive_validator_info)
        if [ $? -eq 0 ] && [ -n "$full_info" ]; then
            local status_part=$(echo "$full_info" | cut -d':' -f1)
            current_commission=$(echo "$full_info" | cut -d':' -f2)
            current_stake_amount=$(echo "$full_info" | cut -d':' -f3)
            current_position=$(echo "$full_info" | cut -d':' -f4)
            current_max_validators=$(echo "$full_info" | cut -d':' -f5)
            
            # Convert to simple status for compatibility
            case "$status_part" in
                "Active") current_validator_status="1" ;;
                "Unbonding") current_validator_status="0" ;;
                "Inactive") current_validator_status="0" ;;
                *) current_validator_status="0" ;;
            esac
            
            local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
            log "$COSMOS_CHAIN_NAME" "${GREEN}Validator comprehensive info: $status_part, Position: $current_position/$current_max_validators, Stake: $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL, Commission: $current_commission%${NC}"
        else
            current_validator_status=$(get_cosmos_validator_status)
            log "$COSMOS_CHAIN_NAME" "${YELLOW}Using fallback validator status check${NC}"
        fi
    fi
    
    # Validate block height was fetched
    if [ -z "$current_block_height" ]; then
        log "$COSMOS_CHAIN_NAME" "${RED}CRITICAL: Failed to fetch block height from $COSMOS_RPC_URL${NC}"
        ((COSMOS_CONSECUTIVE_FAILS++))
        
        local node_type_desc=$([ "$COSMOS_TYPE" = "validator" ] && echo "$COSMOS_CHAIN_NAME Validator Node" || echo "$COSMOS_CHAIN_NAME Full Node")
        
        # Send immediate alert on first failure
        if [ $COSMOS_CONSECUTIVE_FAILS -eq 1 ]; then
            send_discord_alert "$COSMOS_CHAIN_NAME" "🚨 CRITICAL: $COSMOS_CHAIN_NAME Node Unavailable" \
                "**URGENT: $COSMOS_CHAIN_NAME Node appears to be DOWN!**\n\nUnable to fetch block height from $node_type_desc.\n\n**Node Type:** $node_type_desc\n**RPC URL:** $COSMOS_RPC_URL\n**Status:** Node may be completely down or RPC port unreachable\n**First Failure:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Immediate actions needed:**\n• Check if $COSMOS_CHAIN_NAME node process is running\n• Verify RPC port is accessible\n• Check system resources\n• Review $COSMOS_CHAIN_NAME node logs" \
                16711680
        elif [ $COSMOS_CONSECUTIVE_FAILS -eq 5 ]; then
            send_discord_alert "$COSMOS_CHAIN_NAME" "🚨 CRITICAL: $COSMOS_CHAIN_NAME Node Still Down" \
                "$COSMOS_CHAIN_NAME node has been unresponsive for $COSMOS_CONSECUTIVE_FAILS consecutive checks.\n\n**Duration:** ~$((COSMOS_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Still unable to fetch block height\n\n**URGENT ACTION REQUIRED**" \
                16711680
        elif [ $COSMOS_CONSECUTIVE_FAILS -eq 12 ]; then
            send_discord_alert "$COSMOS_CHAIN_NAME" "🚨 CRITICAL: $COSMOS_CHAIN_NAME Node Down for 1+ Hour" \
                "$COSMOS_CHAIN_NAME node has been unresponsive for over 1 hour ($COSMOS_CONSECUTIVE_FAILS checks).\n\n**Duration:** ~$((COSMOS_CONSECUTIVE_FAILS * 5)) minutes\n**Node Type:** $node_type_desc\n**Status:** Extended outage detected\n\n**THIS MAY RESULT IN SLASHING PENALTIES**" \
                16711680
        fi
        
        return 1
    fi
    
    # Reset consecutive fails and send recovery notification if needed
    if [ $COSMOS_CONSECUTIVE_FAILS -gt 0 ]; then
        local outage_duration=$((COSMOS_CONSECUTIVE_FAILS * 5))
        local node_type_desc=$([ "$COSMOS_TYPE" = "validator" ] && echo "$COSMOS_CHAIN_NAME Validator Node" || echo "$COSMOS_CHAIN_NAME Full Node")
        
        local recovery_details="**Outage Duration:** ~${outage_duration} minutes ($COSMOS_CONSECUTIVE_FAILS failed checks)\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Current Block:** $current_block_height"
        
        if [ "$COSMOS_TYPE" = "validator" ] && [ "$current_stake_amount" -gt 0 ]; then
            local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
            recovery_details+="\n**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL"
            if [ "$current_position" -gt 0 ]; then
                recovery_details+="\n**Position:** $current_position/$current_max_validators"
            fi
        fi
        
        send_discord_alert "$COSMOS_CHAIN_NAME" "✅ $COSMOS_CHAIN_NAME Node Recovered" \
            "$node_type_desc is back online and responding.\n\n$recovery_details" \
            65280
        
        log "$COSMOS_CHAIN_NAME" "${GREEN}$COSMOS_CHAIN_NAME node recovered after $COSMOS_CONSECUTIVE_FAILS failed attempts (${outage_duration} minutes)${NC}"
    fi
    COSMOS_CONSECUTIVE_FAILS=0
    
    # Validator position risk assessment
    if [ "$COSMOS_TYPE" = "validator" ] && [ "$current_position" -gt 0 ]; then
        assess_validator_position_risk "$COSMOS_CHAIN_NAME" "$current_position" "$current_max_validators" "$COSMOS_POSITION_WARNING_THRESHOLD" "$current_stake_amount" "$COSMOS_PREV_POSITION"
    fi
    
    # Stake amount monitoring for validators
    if [ "$COSMOS_TYPE" = "validator" ] && [ "$current_stake_amount" -gt 0 ]; then
        # Check for significant stake changes
        if [ "$COSMOS_PREV_STAKE_AMOUNT" -gt 0 ]; then
            local stake_diff=$((COSMOS_PREV_STAKE_AMOUNT - current_stake_amount))
            local stake_percent_change=0
            
            if [ "$COSMOS_PREV_STAKE_AMOUNT" -gt 0 ]; then
                stake_percent_change=$((stake_diff * 100 / COSMOS_PREV_STAKE_AMOUNT))
            fi
            
            local formatted_prev_stake=$(format_cosmos_amount "$COSMOS_PREV_STAKE_AMOUNT")
            local formatted_current_stake=$(format_cosmos_amount "$current_stake_amount")
            local formatted_diff=$(format_cosmos_amount "${stake_diff#-}")
            
            # Alert on significant stake decrease
            if [ "$stake_percent_change" -gt "$COSMOS_STAKE_THRESHOLD_PERCENT" ]; then
                send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: Significant Stake Decrease Detected" \
                    "Validator stake has decreased significantly.\n\n**Previous Stake:** $formatted_prev_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Current Stake:** $formatted_current_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Decrease:** $formatted_diff $EFFECTIVE_COSMOS_TOKEN_SYMBOL (-${stake_percent_change}%)\n**Position:** $current_position/$current_max_validators\n**Threshold:** ${COSMOS_STAKE_THRESHOLD_PERCENT}%\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Possible causes:**\n• Unbonding/redelegation\n• Slashing event\n• Delegator withdrawals\n• Commission changes" \
                    16776960
            # Alert on significant stake increase (informational)
            elif [ "$stake_diff" -lt 0 ] && [ "$((stake_diff * -1 * 100 / COSMOS_PREV_STAKE_AMOUNT))" -gt "$COSMOS_STAKE_THRESHOLD_PERCENT" ]; then
                local increase_percent=$(( (current_stake_amount - COSMOS_PREV_STAKE_AMOUNT) * 100 / COSMOS_PREV_STAKE_AMOUNT ))
                send_discord_alert "$COSMOS_CHAIN_NAME" "📈 INFO: Significant Stake Increase Detected" \
                    "Validator stake has increased significantly.\n\n**Previous Stake:** $formatted_prev_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Current Stake:** $formatted_current_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Increase:** $formatted_diff $EFFECTIVE_COSMOS_TOKEN_SYMBOL (+${increase_percent}%)\n**Position:** $current_position/$current_max_validators\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    65280
            fi
        fi
        
        # Alert if stake is below minimum threshold
        if [ "$current_stake_amount" -lt "$COSMOS_MIN_STAKE_ALERT" ] && [ "$current_stake_amount" -gt 0 ]; then
            local formatted_current=$(format_cosmos_amount "$current_stake_amount")
            local formatted_min=$(format_cosmos_amount "$COSMOS_MIN_STAKE_ALERT")
            
            send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: Validator Stake Below Minimum" \
                "Validator stake is below the configured minimum threshold.\n\n**Current Stake:** $formatted_current $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Minimum Threshold:** $formatted_min $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n**Status:** $([ "$current_validator_status" = "1" ] && echo "Still Active" || echo "Inactive")\n**Position:** $current_position/$current_max_validators\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n**Risk:** May lose validator status if stake too low" \
                16776960
        fi
    fi
    
    # External RPC comparison (if enabled)
    local current_network_block=0
    local current_block_lag=0
    local network_status=""
    
    if [ "$COSMOS_EXTERNAL_RPC_CHECK" = "yes" ]; then
        if current_network_block=$(get_cosmos_network_block_height); then
            # Reset RPC fails and send recovery notification if needed
            if [ $COSMOS_CONSECUTIVE_RPC_FAILS -gt 0 ]; then
                send_discord_alert "$COSMOS_CHAIN_NAME" "✅ $COSMOS_CHAIN_NAME External RPC Endpoints Recovered" \
                    "$COSMOS_CHAIN_NAME external RPC endpoints are responding again.\n\n**Outage Duration:** $COSMOS_CONSECUTIVE_RPC_FAILS failed attempts\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')\n**Network Block:** $current_network_block" \
                    65280
                
                log "$COSMOS_CHAIN_NAME" "${GREEN}External RPCs recovered after $COSMOS_CONSECUTIVE_RPC_FAILS failed attempts${NC}"
            fi
            COSMOS_CONSECUTIVE_RPC_FAILS=0
            
            current_block_lag=$((current_network_block - current_block_height))
            
            if [ $current_block_lag -gt 0 ]; then
                network_status=" ($current_block_lag blocks behind network)"
            else
                network_status=" (in sync with network)"
            fi
            
            log "$COSMOS_CHAIN_NAME" "${GREEN}Network comparison: Local=$current_block_height, Network=$current_network_block$network_status${NC}"
            
            # Check for significant block lag
            if [ $current_block_lag -gt $COSMOS_BLOCK_LAG_THRESHOLD ]; then
                local lag_trend=""
                if [ $COSMOS_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -gt $COSMOS_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag increasing: was $COSMOS_PREV_BLOCK_LAG blocks behind)"
                elif [ $COSMOS_PREV_BLOCK_LAG -gt 0 ] && [ $current_block_lag -lt $COSMOS_PREV_BLOCK_LAG ]; then
                    lag_trend=" (lag decreasing: was $COSMOS_PREV_BLOCK_LAG blocks behind, catching up)"
                fi
                
                local node_type_desc=$([ "$COSMOS_TYPE" = "validator" ] && echo "$COSMOS_CHAIN_NAME Validator" || echo "$COSMOS_CHAIN_NAME Full Node")
                local status_info=""
                
                if [ "$COSMOS_TYPE" = "validator" ]; then
                    status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                    if [ "$current_stake_amount" -gt 0 ]; then
                        local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
                        status_info+="**Stake Amount:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n"
                    fi
                    if [ "$current_position" -gt 0 ]; then
                        status_info+="**Position:** $current_position/$current_max_validators\n"
                    fi
                fi
                
                if [ $current_block_lag -gt $((COSMOS_BLOCK_LAG_THRESHOLD * 2)) ] || [ $current_block_lag -gt $COSMOS_PREV_BLOCK_LAG ]; then
                    send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: $COSMOS_CHAIN_NAME Node Falling Behind Network" \
                        "$COSMOS_CHAIN_NAME node is significantly behind the network.\n\n**Node Type:** $node_type_desc\n**Local Block:** $current_block_height\n**Network Block:** $current_network_block\n**Blocks Behind:** $current_block_lag$lag_trend\n$status_info\n**Successful RPCs:** $COSMOS_LAST_SUCCESSFUL_RPCS\n\n**Possible causes:**\n• Network connectivity issues\n• Node synchronization problems\n• High network load\n• Hardware performance issues" \
                        16776960
                fi
            fi
        else
            ((COSMOS_CONSECUTIVE_RPC_FAILS++))
            log "$COSMOS_CHAIN_NAME" "${YELLOW}Failed to fetch network block height from external RPCs (attempt $COSMOS_CONSECUTIVE_RPC_FAILS)${NC}"
            
            if [ $COSMOS_CONSECUTIVE_RPC_FAILS -eq 1 ]; then
                send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: $COSMOS_CHAIN_NAME External RPC Endpoints Unreachable" \
                    "Cannot fetch network block height for comparison.\n\n**Impact:** Unable to detect if $COSMOS_CHAIN_NAME node is falling behind network\n**RPC Results:**\n$COSMOS_LAST_RPC_RESULTS\n**Local monitoring continues:** Block sync monitoring still active\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')" \
                    16776960
            elif [ $COSMOS_CONSECUTIVE_RPC_FAILS -eq 6 ]; then
                send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: $COSMOS_CHAIN_NAME External RPCs Down for 30+ Minutes" \
                    "$COSMOS_CHAIN_NAME external RPC endpoints have been unavailable for $COSMOS_CONSECUTIVE_RPC_FAILS consecutive checks.\n\n**Duration:** ~$((COSMOS_CONSECUTIVE_RPC_FAILS * 5)) minutes\n**Impact:** Cannot compare with network state\n**Status:** Local monitoring continues" \
                    16776960
            fi
            
            current_network_block=$COSMOS_PREV_NETWORK_BLOCK
            current_block_lag=$COSMOS_PREV_BLOCK_LAG
        fi
    fi
    
    # Log current status
    local stake_status=""
    local position_status=""
    
    if [ "$COSMOS_TYPE" = "validator" ]; then
        if [ "$current_stake_amount" -gt 0 ]; then
            local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
            stake_status=" (Stake: $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL)"
        fi
        if [ "$current_position" -gt 0 ]; then
            position_status=" (Pos: $current_position/$current_max_validators)"
        fi
        
        log "$COSMOS_CHAIN_NAME" "${GREEN}Current Status: Validator=$([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive"), Block=$current_block_height$network_status$stake_status$position_status${NC}"
    else
        log "$COSMOS_CHAIN_NAME" "${GREEN}Current Status: Block=$current_block_height (Full Node)$network_status${NC}"
    fi
    
    # Check validator status for validator nodes
    if [ "$COSMOS_TYPE" = "validator" ]; then
        if [ "$current_validator_status" = "0" ] && [ "$COSMOS_PREV_VALIDATOR_STATUS" = "1" ]; then
            local alert_details="**URGENT ACTION REQUIRED**\n\n$COSMOS_CHAIN_NAME Validator has been removed from the active validator set!\n\n**Current Status:** Inactive (0)\n**Previous Status:** Active (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Time:** $(date '+%Y-%m-%d %H:%M:%S')"
            
            if [ "$current_stake_amount" -gt 0 ]; then
                local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
                alert_details+="\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL"
            fi
            
            if [ "$current_position" -gt 0 ]; then
                alert_details+="\n**Position:** $current_position/$current_max_validators"
            fi
            
            if [ -n "$current_commission" ] && [ "$current_commission" != "Unknown" ]; then
                alert_details+="\n**Commission:** ${current_commission}%"
            fi
            
            alert_details+="\n\n**Immediate actions needed:**\n• Check $COSMOS_CHAIN_NAME validator logs\n• Verify staking requirements\n• Check for slashing events\n• Review validator performance\n• Verify stake amount is sufficient\n• Check for jailing status"
            
            send_discord_alert "$COSMOS_CHAIN_NAME" "🚨 CRITICAL: $COSMOS_CHAIN_NAME Validator Removed from Active Set" \
                "$alert_details" \
                16711680
                
        elif [ "$current_validator_status" = "1" ] && [ "$COSMOS_PREV_VALIDATOR_STATUS" = "0" ]; then
            local recovery_details="$COSMOS_CHAIN_NAME Validator has been restored to the active validator set.\n\n**Current Status:** Active (1)\n**Block Height:** $current_block_height\n**Network Block:** $current_network_block\n**Recovery Time:** $(date '+%Y-%m-%d %H:%M:%S')"
            
            if [ "$current_stake_amount" -gt 0 ]; then
                local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
                recovery_details+="\n**Current Stake:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL"
            fi
            
            if [ "$current_position" -gt 0 ]; then
                recovery_details+="\n**Position:** $current_position/$current_max_validators"
            fi
            
            send_discord_alert "$COSMOS_CHAIN_NAME" "✅ $COSMOS_CHAIN_NAME Validator Restored to Active Set" \
                "$recovery_details" \
                65280
        fi
    fi
    
    # Check block progression
    if [ $COSMOS_PREV_BLOCK_HEIGHT -gt 0 ] && [ $((current_time - COSMOS_PREV_CHECK_TIME)) -ge 300 ]; then
        if [ "$current_block_height" -le "$COSMOS_PREV_BLOCK_HEIGHT" ]; then
            local time_diff=$((current_time - COSMOS_PREV_CHECK_TIME))
            local node_type_desc=$([ "$COSMOS_TYPE" = "validator" ] && echo "$COSMOS_CHAIN_NAME Validator" || echo "$COSMOS_CHAIN_NAME Full Node")
            local status_info=""
            
            if [ "$COSMOS_TYPE" = "validator" ]; then
                status_info="**Validator Status:** $([ "$current_validator_status" = "1" ] && echo "Active" || echo "Inactive")\n"
                if [ "$current_stake_amount" -gt 0 ]; then
                    local formatted_stake=$(format_cosmos_amount "$current_stake_amount")
                    status_info+="**Stake Amount:** $formatted_stake $EFFECTIVE_COSMOS_TOKEN_SYMBOL\n"
                fi
                if [ "$current_position" -gt 0 ]; then
                    status_info+="**Position:** $current_position/$current_max_validators\n"
                fi
            fi
            
            local network_info=""
            if [ "$COSMOS_EXTERNAL_RPC_CHECK" = "yes" ] && [ $current_network_block -gt 0 ]; then
                network_info="**Network Block:** $current_network_block\n**Network is Progressing:** $([ $current_network_block -gt $COSMOS_PREV_NETWORK_BLOCK ] && echo "Yes" || echo "No")\n"
            fi
            
            send_discord_alert "$COSMOS_CHAIN_NAME" "⚠️ WARNING: $COSMOS_CHAIN_NAME Block Sync Stalled" \
                "$COSMOS_CHAIN_NAME node has stopped syncing new blocks.\n\n**Node Type:** $node_type_desc\n**Current Block:** $current_block_height\n**Previous Block:** $COSMOS_PREV_BLOCK_HEIGHT\n**Time Since Last Check:** ${time_diff}s\n**Detection Time:** $(date '+%Y-%m-%d %H:%M:%S')\n$network_info$status_info\n**Possible causes:**\n• Node synchronization problems\n• Network connectivity issues\n• $COSMOS_CHAIN_NAME node malfunction\n• Validator jailed (for validators)\n• Insufficient stake (validators)" \
                16776960
        else
            local blocks_synced=$((current_block_height - COSMOS_PREV_BLOCK_HEIGHT))
            local time_diff=$((current_time - COSMOS_PREV_CHECK_TIME))
            local blocks_per_min=$(echo "scale=2; $blocks_synced * 60 / $time_diff" | bc -l 2>/dev/null || echo "N/A")
            log "$COSMOS_CHAIN_NAME" "${GREEN}Blocks syncing normally: +$blocks_synced blocks in ${time_diff}s (${blocks_per_min} blocks/min)${NC}"
        fi
    fi
    
    # Save current state
    COSMOS_PREV_BLOCK_HEIGHT=$current_block_height
    COSMOS_PREV_CHECK_TIME=$current_time
    COSMOS_PREV_NETWORK_BLOCK=$current_network_block
    COSMOS_PREV_BLOCK_LAG=$current_block_lag
    COSMOS_PREV_VALIDATOR_STATUS=$current_validator_status
    COSMOS_PREV_STAKE_AMOUNT=$current_stake_amount
    COSMOS_PREV_COMMISSION="$current_commission"
    COSMOS_PREV_POSITION=$current_position
    COSMOS_PREV_MAX_VALIDATORS=$current_max_validators
    
    log "$COSMOS_CHAIN_NAME" "${BLUE}$COSMOS_CHAIN_NAME monitoring completed${NC}"
    return 0
}

mod_evm() {
    log "EVM" "${YELLOW}EVM monitoring module - Coming soon!${NC}"
    return 0
}

# ================================
# MAIN EXECUTION
# ================================

main() {
    local enabled_chains=""
    [ "$ENABLE_SOMNIA" = "yes" ] && enabled_chains+="SOMNIA "
    [ "$ENABLE_SUI" = "yes" ] && enabled_chains+="SUI "
    [ "$ENABLE_EVM" = "yes" ] && enabled_chains+="EVM "
    [ "$ENABLE_SUBSTRATE" = "yes" ] && enabled_chains+="SUBSTRATE "
    [ "$ENABLE_COSMOS" = "yes" ] && enabled_chains+="COSMOS "
    
    log "SYSTEM" "${GREEN}Starting Multi-Chain Monitoring for: $enabled_chains${NC}"
    log "SYSTEM" "${GREEN}Server: $NODE_NAME${NC}"
    
    # Validate enabled chains configuration
    if [ "$ENABLE_SOMNIA" != "yes" ] && [ "$ENABLE_SUI" != "yes" ] && [ "$ENABLE_EVM" != "yes" ] && [ "$ENABLE_SUBSTRATE" != "yes" ] && [ "$ENABLE_COSMOS" != "yes" ]; then
        log "SYSTEM" "${RED}ERROR: No chains enabled. Please enable at least one chain.${NC}"
        exit 1
    fi
    
    # Validate specific chain configurations
    if [ "$ENABLE_SOMNIA" = "yes" ]; then
        if [ "$SOMNIA_TYPE" != "validator" ] && [ "$SOMNIA_TYPE" != "fullnode" ]; then
            log "SYSTEM" "${RED}ERROR: SOMNIA_TYPE must be 'validator' or 'fullnode'. Current value: '$SOMNIA_TYPE'${NC}"
            exit 1
        fi
        
        if [ "$SOMNIA_EXTERNAL_RPC_CHECK" = "yes" ] && [ -z "$SOMNIA_EXTERNAL_RPCS" ]; then
            log "SYSTEM" "${RED}ERROR: SOMNIA_EXTERNAL_RPCS cannot be empty when SOMNIA_EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        log "SYSTEM" "${GREEN}Somnia configuration validated${NC}"
    fi
    
    if [ "$ENABLE_SUI" = "yes" ]; then
        if [ "$SUI_TYPE" != "validator" ] && [ "$SUI_TYPE" != "fullnode" ]; then
            log "SYSTEM" "${RED}ERROR: SUI_TYPE must be 'validator' or 'fullnode'. Current value: '$SUI_TYPE'${NC}"
            exit 1
        fi
        
        if [ -z "$SUI_RPC_URL" ]; then
            log "SYSTEM" "${RED}ERROR: SUI_RPC_URL cannot be empty when ENABLE_SUI=yes${NC}"
            exit 1
        fi
        
        if [ "$SUI_EXTERNAL_RPC_CHECK" = "yes" ] && [ -z "$SUI_EXTERNAL_RPCS" ]; then
            log "SYSTEM" "${RED}ERROR: SUI_EXTERNAL_RPCS cannot be empty when SUI_EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        log "SYSTEM" "${GREEN}SUI configuration validated${NC}"
    fi
    
    if [ "$ENABLE_EVM" = "yes" ]; then
        if [ -z "$EVM_CHAIN_NAME" ]; then
            log "SYSTEM" "${RED}ERROR: EVM_CHAIN_NAME cannot be empty when ENABLE_EVM=yes${NC}"
            exit 1
        fi
        
        if [ -z "$EVM_RPC_URL" ]; then
            log "SYSTEM" "${RED}ERROR: EVM_RPC_URL cannot be empty when ENABLE_EVM=yes${NC}"
            exit 1
        fi
        
        if [ "$EVM_EXTERNAL_RPC_CHECK" = "yes" ] && [ -z "$EVM_EXTERNAL_RPCS" ]; then
            log "SYSTEM" "${RED}ERROR: EVM_EXTERNAL_RPCS cannot be empty when EVM_EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        log "SYSTEM" "${GREEN}EVM ($EVM_CHAIN_NAME) configuration validated${NC}"
    fi
    
    if [ "$ENABLE_SUBSTRATE" = "yes" ]; then
        if [ "$SUBSTRATE_TYPE" != "validator" ] && [ "$SUBSTRATE_TYPE" != "fullnode" ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_TYPE must be 'validator' or 'fullnode'. Current value: '$SUBSTRATE_TYPE'${NC}"
            exit 1
        fi
        
        if [ -z "$SUBSTRATE_CHAIN_NAME" ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_CHAIN_NAME cannot be empty when ENABLE_SUBSTRATE=yes${NC}"
            exit 1
        fi
        
        if [ -z "$SUBSTRATE_RPC_URL" ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_RPC_URL cannot be empty when ENABLE_SUBSTRATE=yes${NC}"
            exit 1
        fi
        
        if [ "$SUBSTRATE_EXTERNAL_RPC_CHECK" = "yes" ] && [ -z "$SUBSTRATE_EXTERNAL_RPCS" ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_EXTERNAL_RPCS cannot be empty when SUBSTRATE_EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        # Validate substrate chain parameters (if manually configured)
        if [ "$SUBSTRATE_MAX_VALIDATORS" -gt 0 ]; then
            log "SYSTEM" "${GREEN}Using manual max validators: $SUBSTRATE_MAX_VALIDATORS${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect max validators from chain${NC}"
        fi
        
        if [ "$SUBSTRATE_TOKEN_DECIMALS" -gt 0 ]; then
            if [ "$SUBSTRATE_TOKEN_DECIMALS" -gt 18 ]; then
                log "SYSTEM" "${RED}ERROR: SUBSTRATE_TOKEN_DECIMALS cannot be greater than 18. Current value: '$SUBSTRATE_TOKEN_DECIMALS'${NC}"
                exit 1
            fi
            log "SYSTEM" "${GREEN}Using manual token decimals: $SUBSTRATE_TOKEN_DECIMALS${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect token decimals from chain${NC}"
        fi
        
        if [ -n "$SUBSTRATE_TOKEN_SYMBOL" ]; then
            log "SYSTEM" "${GREEN}Using manual token symbol: $SUBSTRATE_TOKEN_SYMBOL${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect token symbol from chain${NC}"
        fi
        
        # Validate staking thresholds
        if ! [[ "$SUBSTRATE_STAKE_THRESHOLD_PERCENT" =~ ^[0-9]+$ ]] || [ "$SUBSTRATE_STAKE_THRESHOLD_PERCENT" -lt 1 ] || [ "$SUBSTRATE_STAKE_THRESHOLD_PERCENT" -gt 100 ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_STAKE_THRESHOLD_PERCENT must be a number between 1 and 100. Current value: '$SUBSTRATE_STAKE_THRESHOLD_PERCENT'${NC}"
            exit 1
        fi
        
        if ! [[ "$SUBSTRATE_MIN_STAKE_ALERT" =~ ^[0-9]+$ ]] || [ "$SUBSTRATE_MIN_STAKE_ALERT" -lt 0 ]; then
            log "SYSTEM" "${RED}ERROR: SUBSTRATE_MIN_STAKE_ALERT must be a positive number. Current value: '$SUBSTRATE_MIN_STAKE_ALERT'${NC}"
            exit 1
        fi
        
        log "SYSTEM" "${GREEN}Substrate ($SUBSTRATE_CHAIN_NAME) configuration validated${NC}"
    fi
    
    if [ "$ENABLE_COSMOS" = "yes" ]; then
        if [ "$COSMOS_TYPE" != "validator" ] && [ "$COSMOS_TYPE" != "fullnode" ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_TYPE must be 'validator' or 'fullnode'. Current value: '$COSMOS_TYPE'${NC}"
            exit 1
        fi
        
        if [ -z "$COSMOS_CHAIN_NAME" ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_CHAIN_NAME cannot be empty when ENABLE_COSMOS=yes${NC}"
            exit 1
        fi
        
        if [ -z "$COSMOS_RPC_URL" ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_RPC_URL cannot be empty when ENABLE_COSMOS=yes${NC}"
            exit 1
        fi
        
        if [ -z "$COSMOS_REST_URL" ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_REST_URL cannot be empty when ENABLE_COSMOS=yes${NC}"
            exit 1
        fi
        
        if [ "$COSMOS_EXTERNAL_RPC_CHECK" = "yes" ] && [ -z "$COSMOS_EXTERNAL_RPCS" ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_EXTERNAL_RPCS cannot be empty when COSMOS_EXTERNAL_RPC_CHECK=yes${NC}"
            exit 1
        fi
        
        # Validate denomination and exponent (if manually configured)
        if [ -n "$COSMOS_DENOM" ]; then
            log "SYSTEM" "${GREEN}Using manual denom: $COSMOS_DENOM${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect denom from chain${NC}"
        fi
        
        if [ "$COSMOS_DENOM_EXPONENT" -gt 0 ]; then
            if [ "$COSMOS_DENOM_EXPONENT" -gt 18 ]; then
                log "SYSTEM" "${RED}ERROR: COSMOS_DENOM_EXPONENT cannot be greater than 18. Current value: '$COSMOS_DENOM_EXPONENT'${NC}"
                exit 1
            fi
            log "SYSTEM" "${GREEN}Using manual denom exponent: $COSMOS_DENOM_EXPONENT${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect denom exponent from chain${NC}"
        fi
        
        if [ "$COSMOS_MAX_VALIDATORS" -gt 0 ]; then
            log "SYSTEM" "${GREEN}Using manual max validators: $COSMOS_MAX_VALIDATORS${NC}"
        else
            log "SYSTEM" "${GREEN}Will auto-detect max validators from chain${NC}"
        fi
        
        # Validate validator-specific settings
        if [ "$COSMOS_TYPE" = "validator" ] && [ -z "$COSMOS_VALIDATOR_ADDRESS" ]; then
            log "SYSTEM" "${YELLOW}WARNING: COSMOS_VALIDATOR_ADDRESS is empty. Validator monitoring will be limited.${NC}"
        fi
        
        # Validate thresholds
        if ! [[ "$COSMOS_STAKE_THRESHOLD_PERCENT" =~ ^[0-9]+$ ]] || [ "$COSMOS_STAKE_THRESHOLD_PERCENT" -lt 1 ] || [ "$COSMOS_STAKE_THRESHOLD_PERCENT" -gt 100 ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_STAKE_THRESHOLD_PERCENT must be a number between 1 and 100. Current value: '$COSMOS_STAKE_THRESHOLD_PERCENT'${NC}"
            exit 1
        fi
        
        if ! [[ "$COSMOS_MIN_STAKE_ALERT" =~ ^[0-9]+$ ]] || [ "$COSMOS_MIN_STAKE_ALERT" -lt 0 ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_MIN_STAKE_ALERT must be a positive number. Current value: '$COSMOS_MIN_STAKE_ALERT'${NC}"
            exit 1
        fi
        
        # Validate configured max validators (if provided)
        if [ "$COSMOS_MAX_VALIDATORS" -gt 0 ] && [ "$COSMOS_MAX_VALIDATORS" -lt 1 ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_MAX_VALIDATORS must be greater than 0 if specified. Current value: '$COSMOS_MAX_VALIDATORS'${NC}"
            exit 1
        fi
        
        if ! [[ "$COSMOS_POSITION_WARNING_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$COSMOS_POSITION_WARNING_THRESHOLD" -lt 1 ]; then
            log "SYSTEM" "${RED}ERROR: COSMOS_POSITION_WARNING_THRESHOLD must be a positive number. Current value: '$COSMOS_POSITION_WARNING_THRESHOLD'${NC}"
            exit 1
        fi
        
        log "SYSTEM" "${GREEN}Cosmos ($COSMOS_CHAIN_NAME) configuration validated${NC}"
    fi
    
    # Set up cleanup on exit
    trap cleanup EXIT
    
    # Check if already running
    check_lock
    
    # Read previous states
    read_all_states
    
    local any_errors=0
    
    # Execute enabled chain modules
    if [ "$ENABLE_SOMNIA" = "yes" ]; then
        if ! mod_somnia; then
            any_errors=1
        fi
    fi
    
    if [ "$ENABLE_SUI" = "yes" ]; then
        if ! mod_sui; then
            any_errors=1
        fi
    fi
    
    if [ "$ENABLE_EVM" = "yes" ]; then
        if ! mod_evm; then
            any_errors=1
        fi
    fi
    
    if [ "$ENABLE_SUBSTRATE" = "yes" ]; then
        if ! mod_substrate; then
            any_errors=1
        fi
    fi
    
    if [ "$ENABLE_COSMOS" = "yes" ]; then
        if ! mod_cosmos; then
            any_errors=1
        fi
    fi
    
    # Send heartbeat (regardless of individual chain errors)
    send_heartbeat
    
    # Save all states
    write_all_states
    
    if [ $any_errors -eq 0 ]; then
        log "SYSTEM" "${GREEN}All enabled chains monitored successfully${NC}"
    else
        log "SYSTEM" "${YELLOW}Some chains reported errors - check individual chain logs${NC}"
    fi
    
    log "SYSTEM" "${GREEN}Multi-chain monitoring cycle completed${NC}"
}

# Run main function
main "$@"
