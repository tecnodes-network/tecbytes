#!/bin/bash

# Cosmos Chain Operations Script - PRODUCTION VERSION
# Version: 2.1 - Fixed tx success detection + auto-vote password caching
# Author: Blockchain automation toolkit

# ============================================
# DEBUG TOGGLE - Set to true for verbose logs
# ============================================
ENABLE_DEBUG=false

set -euo pipefail
[[ "${DEBUG:-}" == "1" ]] && set -x
trap 'echo "❌ Script failed at line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
TELEGRAM_CONF="$SCRIPT_DIR/telegram.conf"

CONFIG_FILE=""
OPERATION=""
VOTE_OPTION=""
PROPOSAL_ID=""
AUTO_VOTE_INTERVAL=360
DRY_RUN=false
VOTE_ALL=false
CACHED_PASSWORD=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOG_DIR/cosmos-ops_$(date +%Y%m%d).log"
}

log_debug() { 
    [[ "$ENABLE_DEBUG" == "true" ]] || return 0
    log "DEBUG" "$@"
    echo -e "${MAGENTA}[DEBUG]${NC} $*"
}

log_info() { log "INFO" "$@"; echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { log "SUCCESS" "$@"; echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { log "WARN" "$@"; echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "ERROR" "$@"; echo -e "${RED}[ERROR]${NC} $*"; }
log_tx() { log "TX" "$@"; echo -e "${CYAN}[TX]${NC} $*"; }

show_help() {
    cat << EOF
Cosmos Chain Operations Script

Usage: $0 --config <config_file> <operation> [options]

Required:
    --config FILE           Chain configuration file

Operations:
    --vote <yes|no|abstain|veto>  Vote on proposal
    --balance                     Check balances
    --withdraw-rewards            Withdraw rewards
    --consensus-state             Check consensus
    --auto-vote <option>          Auto voting

Options:
    --proposal-id ID         Proposal ID
    --interval SECONDS       Auto-vote interval (360)
    --dry-run               Test mode
    --debug                 Enable debugging

Examples:
    $0 --config jackal.conf --balance
    $0 --config jackal.conf --vote yes --proposal-id 24
    $0 --config jackal.conf --vote yes  (votes on all active)
    $0 --config jackal.conf --auto-vote yes --interval 300

EOF
    exit 0
}

parse_args() {
    log_debug "parse_args() with $# args"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --vote)
                OPERATION="vote"
                VOTE_OPTION="$2"
                shift 2
                ;;
            --balance)
                OPERATION="balance"
                shift
                ;;
            --withdraw-rewards)
                OPERATION="withdraw"
                shift
                ;;
            --consensus-state)
                OPERATION="consensus"
                shift
                ;;
            --auto-vote)
                OPERATION="auto-vote"
                VOTE_OPTION="$2"
                shift 2
                ;;
            --proposal-id)
                PROPOSAL_ID="$2"
                shift 2
                ;;
            --interval)
                AUTO_VOTE_INTERVAL="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --debug)
                ENABLE_DEBUG=true
                set -x
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file required and must exist"
        exit 1
    fi

    if [[ -z "$OPERATION" ]]; then
        log_error "No operation specified"
        show_help
    fi
    
    if [[ "$OPERATION" == "vote" && -z "$PROPOSAL_ID" ]]; then
        VOTE_ALL=true
    fi
}

parse_config() {
    log_debug "Parsing config: $1"
    local config_file="$1"
    
    get_config_value() {
        local key="$1"
        local value=""
        if grep -q "^$key:" "$config_file"; then
            value=$(grep "^$key:" "$config_file" | head -1 | sed "s/^$key: *//" | sed 's/#.*//' | tr -d '"' | tr -d "'" | xargs)
        fi
        echo "$value"
    }
    
    PROJECT_NAME=$(get_config_value "project_name")
    DAEMON_NAME=$(get_config_value "daemon_name")
    CHAIN_HOME=$(get_config_value "chain_home")
    RPC_URL=$(get_config_value "rpc_url")
    RPC_ENDPOINT=$(get_config_value "rpc_endpoint")
    CHAIN_ID=$(get_config_value "chain_id")
    KEYRING_BACKEND=$(get_config_value "keyring_backend")
    KEY_NAME=$(get_config_value "key_name")
    PASSWORD_FILE=$(get_config_value "password_file")
    MAX_GAS_FEE=$(get_config_value "max_gas_fee")
    GAS_ADJUSTMENT=$(get_config_value "gas_adjustment")
    
    # Read addresses from config
    DELEGATOR_ADDRESS=$(get_config_value "delegator_address")
    VALOPER_ADDRESS=$(get_config_value "valoper_address")
    
    CHAIN_HOME="${CHAIN_HOME/#~/$HOME}"
    PASSWORD_FILE="${PASSWORD_FILE/#~/$HOME}"
    
    [[ -z "$KEYRING_BACKEND" ]] && KEYRING_BACKEND="file"
    [[ -z "$GAS_ADJUSTMENT" ]] && GAS_ADJUSTMENT="1.3"
    [[ -z "$MAX_GAS_FEE" ]] && MAX_GAS_FEE="1000000"
    
    log_debug "Configuration parsed:"
    log_debug "  PROJECT_NAME=$PROJECT_NAME"
    log_debug "  DAEMON_NAME=$DAEMON_NAME"
    log_debug "  CHAIN_HOME=$CHAIN_HOME"
    log_debug "  CHAIN_ID=$CHAIN_ID"
    log_debug "  KEYRING_BACKEND=$KEYRING_BACKEND"
    log_debug "  KEY_NAME=$KEY_NAME"
    log_debug "  RPC_ENDPOINT=$RPC_ENDPOINT"
    log_debug "  DELEGATOR_ADDRESS=$DELEGATOR_ADDRESS"
    log_debug "  VALOPER_ADDRESS=$VALOPER_ADDRESS"
    log_debug "  MAX_GAS_FEE=$MAX_GAS_FEE"
    
    local missing=()
    [[ -z "$DAEMON_NAME" ]] && missing+=("daemon_name")
    [[ -z "$CHAIN_ID" ]] && missing+=("chain_id")
    [[ -z "$KEY_NAME" ]] && missing+=("key_name")
    [[ -z "$DELEGATOR_ADDRESS" ]] && missing+=("delegator_address")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required config: ${missing[*]}"
        exit 1
    fi
    
    if [[ -n "$CHAIN_HOME" ]]; then
        DAEMON_CMD="$DAEMON_NAME --home $CHAIN_HOME"
        log_debug "Using daemon with home: $DAEMON_CMD"
    else
        DAEMON_CMD="$DAEMON_NAME"
        log_debug "Using daemon without home: $DAEMON_CMD"
    fi
    
    log_success "Configuration loaded for: $PROJECT_NAME"
}

parse_telegram_config() {
    if [[ ! -f "$TELEGRAM_CONF" ]]; then
        TELEGRAM_ENABLED=false
        log_debug "Telegram config not found"
        return
    fi
    
    get_config_value() {
        local key="$1"
        local value=""
        if grep -q "^$key:" "$TELEGRAM_CONF"; then
            value=$(grep "^$key:" "$TELEGRAM_CONF" | head -1 | sed "s/^$key: *//" | tr -d '"' | tr -d "'")
        fi
        echo "$value"
    }
    
    TELEGRAM_BOT_TOKEN=$(get_config_value "bot_token")
    TELEGRAM_CHAT_ID=$(get_config_value "chat_id")
    TELEGRAM_ENABLED=$(get_config_value "enabled")
    
    [[ "$TELEGRAM_ENABLED" != "true" ]] && TELEGRAM_ENABLED=false
    log_debug "Telegram enabled: $TELEGRAM_ENABLED"
}

send_telegram() {
    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return
    fi
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" >/dev/null 2>&1 || true
}

get_password() {
    log_debug "get_password() for backend: $KEYRING_BACKEND"
    
    # Return cached password if available
    if [[ -n "$CACHED_PASSWORD" ]]; then
        log_debug "Using cached password"
        echo "$CACHED_PASSWORD"
        return
    fi
    
    local password=""
    
    # For auto-vote mode, ALWAYS ask for password (even OS keyring)
    if [[ "$OPERATION" == "auto-vote" ]]; then
        if [[ -n "$PASSWORD_FILE" && -f "$PASSWORD_FILE" ]]; then
            log_info "Decrypting password from: $PASSWORD_FILE"
            password=$(gpg --decrypt "$PASSWORD_FILE" 2>/dev/null) || {
                log_warn "GPG decryption failed"
                password=""
            }
        fi
        
        if [[ -z "$password" ]]; then
            read -s -p "Enter keyring password for $KEY_NAME: " password
            echo ""
        fi
        
        echo "$password"
        return
    fi
    
    # Normal mode - use OS keyring if configured
    if [[ "$KEYRING_BACKEND" == "os" ]]; then
        log_info "Using OS keyring (system will prompt if needed)"
        echo ""
        return
    fi
    
    if [[ -n "$PASSWORD_FILE" && -f "$PASSWORD_FILE" ]]; then
        log_info "Decrypting password from: $PASSWORD_FILE"
        password=$(gpg --decrypt "$PASSWORD_FILE" 2>/dev/null) || {
            log_warn "GPG decryption failed"
            password=""
        }
    fi
    
    if [[ -z "$password" ]]; then
        read -s -p "Enter keyring password for $KEY_NAME: " password
        echo ""
    fi
    
    echo "$password"
}


execute_tx() {
    log_debug "execute_tx() called"
    local tx_command="$1"
    local password="$2"
    local gas_adj="${3:-$GAS_ADJUSTMENT}"
    
    log_info "Executing transaction (gas-adj=$gas_adj)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $tx_command"
        return 0
    fi
    
    local tx_result
    
    if [[ "$KEYRING_BACKEND" == "os" ]]; then
        tx_result=$($tx_command --gas auto --gas-adjustment "$gas_adj" --chain-id "$CHAIN_ID" --keyring-backend "$KEYRING_BACKEND" -y 2>&1) || {
            local exit_code=$?
            
            if echo "$tx_result" | grep -qi "already voted\|already cast"; then
                log_warn "Already voted on this proposal"
                return 2
            fi
            
            if echo "$tx_result" | grep -q "out of gas"; then
                log_warn "Out of gas, retrying..."
                local new_adj=$(echo "$gas_adj + 0.2" | bc)
                if (( $(echo "$new_adj > 2.5" | bc -l) )); then
                    log_error "Gas exceeded limit"
                    return 1
                fi
                execute_tx "$tx_command" "$password" "$new_adj"
                return $?
            fi
            
            log_error "Transaction failed:"
            echo "$tx_result" | grep -i "error" || echo "$tx_result"
            return $exit_code
        }
    else
        tx_result=$(echo "$password" | $tx_command --gas auto --gas-adjustment "$gas_adj" --chain-id "$CHAIN_ID" --keyring-backend "$KEYRING_BACKEND" -y 2>&1) || {
            local exit_code=$?
            
            if echo "$tx_result" | grep -qi "already voted\|already cast"; then
                log_warn "Already voted on this proposal"
                return 2
            fi
            
            if echo "$tx_result" | grep -q "out of gas"; then
                log_warn "Out of gas, retrying..."
                local new_adj=$(echo "$gas_adj + 0.2" | bc)
                if (( $(echo "$new_adj > 2.5" | bc -l) )); then
                    log_error "Gas exceeded limit"
                    return 1
                fi
                execute_tx "$tx_command" "$password" "$new_adj"
                return $?
            fi
            
            log_error "Transaction failed:"
            echo "$tx_result" | grep -i "error" || echo "$tx_result"
            return $exit_code
        }
    fi
    
    # FIX 1: Check transaction success by code field
    local tx_code
    tx_code=$(echo "$tx_result" | grep "^code:" | awk '{print $2}')
    
    if [[ "$tx_code" != "0" && -n "$tx_code" ]]; then
        log_error "Transaction failed with code: $tx_code"
        local raw_log
        raw_log=$(echo "$tx_result" | grep "raw_log:" | cut -d: -f2- | tr -d "'\"")
        [[ -n "$raw_log" ]] && log_error "Error: $raw_log"
        return 1
    fi
    
    local txhash
    txhash=$(echo "$tx_result" | grep -o "txhash: [A-F0-9]*" | cut -d' ' -f2)
    
    if [[ -n "$txhash" ]]; then
        log_success "Transaction submitted"
        log_tx "TxHash: $txhash"
        echo "$txhash"
    else
        log_warn "Transaction submitted but no hash"
    fi
}

check_if_voted() {
    local proposal_id="$1"
    local voter_addr="$2"
    
    log_debug "Checking if $voter_addr voted on proposal $proposal_id"
    
    local vote_result
    vote_result=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals/$proposal_id/votes/$voter_addr" 2>/dev/null)
    
    if echo "$vote_result" | jq -e '.vote' >/dev/null 2>&1; then
        local vote_option
        vote_option=$(echo "$vote_result" | jq -r '.vote.option // .vote.options[0].option' 2>/dev/null)
        echo "$vote_option"
        return 0
    fi
    
    echo ""
    return 1
}

vote_on_proposal() {
    log_debug "vote_on_proposal($1, $2)"
    local proposal_id="$1"
    local vote_option="$2"
    
    log_info "=========================================="
    log_info "VOTING ON PROPOSAL #$proposal_id"
    log_info "=========================================="
    
    local proposal_json
    proposal_json=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals/$proposal_id" 2>/dev/null)
    
    local proposal_title
    proposal_title=$(echo "$proposal_json" | jq -r '.proposal.content.title // .proposal.title' 2>/dev/null)
    
    if [[ -n "$proposal_title" && "$proposal_title" != "null" ]]; then
        log_info "Proposal: $proposal_title"
    fi
    
    log_debug "Using delegator address from config: $DELEGATOR_ADDRESS"
    
    # Check if already voted
    local existing_vote
    existing_vote=$(check_if_voted "$proposal_id" "$DELEGATOR_ADDRESS")
    
    if [[ -n "$existing_vote" ]]; then
        log_warn "Already voted on proposal #$proposal_id with: $existing_vote"
        log_info "Skipping vote"
        return 0
    fi
    
    log_info "Vote: $vote_option"
    
    local password
    password=$(get_password)
    
    local vote_cmd="$DAEMON_CMD tx gov vote $proposal_id $vote_option --from $KEY_NAME"
    
    local txhash
    txhash=$(execute_tx "$vote_cmd" "$password")
    local tx_exit=$?
    
    if [[ $tx_exit -eq 0 ]]; then
        log_success "Vote submitted!"
        
        local telegram_msg="🗳️ <b>$PROJECT_NAME</b>%0A"
        telegram_msg+="Voted <b>${vote_option^^}</b> #$proposal_id ✅%0A"
        [[ -n "$txhash" ]] && telegram_msg+="Hash: <code>$txhash</code>%0A"
        telegram_msg+="$(date '+%Y-%m-%d %H:%M')"
        
        send_telegram "$telegram_msg"
        return 0
    elif [[ $tx_exit -eq 2 ]]; then
        log_warn "Already voted (detected during execution)"
        return 0
    else
        log_error "Vote failed - check error above"
        return 1
    fi
}

vote_all_active() {
    log_debug "vote_all_active($1)"
    local vote_option="$1"
    
    log_info "=========================================="
    log_info "VOTE ALL MODE"
    log_info "=========================================="
    
    local proposals_json
    proposals_json=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals?proposal_status=2" 2>/dev/null)
    
    local proposal_ids
    proposal_ids=$(echo "$proposals_json" | jq -r '.proposals[]?.proposal_id // .proposals[]?.id' 2>/dev/null)
    
    if [[ -z "$proposal_ids" ]]; then
        log_info "No active proposals"
        return 0
    fi
    
    local count=0
    while IFS= read -r prop_id; do
        [[ -z "$prop_id" || "$prop_id" == "null" ]] && continue
        
        log_info "Found proposal: #$prop_id"
        
        if vote_on_proposal "$prop_id" "$vote_option"; then
            ((count++))
        fi
        
        sleep 3
    done <<< "$proposal_ids"
    
    log_success "Voted on $count proposals"
}

check_balance() {
    log_debug "check_balance()"
    log_info "=========================================="
    log_info "WALLET BALANCE"
    log_info "=========================================="
    
    log_info "Address: $DELEGATOR_ADDRESS"
    echo ""
    
    log_info "Balances:"
    $DAEMON_CMD query bank balances "$DELEGATOR_ADDRESS" --chain-id "$CHAIN_ID" --node "$RPC_ENDPOINT" || {
        log_error "Failed to query balances"
        log_error "Check RPC_ENDPOINT: $RPC_ENDPOINT"
        exit 1
    }
    
    if [[ -n "$VALOPER_ADDRESS" ]]; then
        echo ""
        log_info "Rewards:"
        $DAEMON_CMD query distribution rewards "$DELEGATOR_ADDRESS" "$VALOPER_ADDRESS" --chain-id "$CHAIN_ID" --node "$RPC_ENDPOINT" || {
            log_warn "Failed to query rewards"
        }
    else
        log_debug "Skipping rewards query (valoper_address not configured)"
    fi
    
    log_success "Balance check completed"
}

withdraw_rewards() {
    log_debug "withdraw_rewards()"
    log_info "=========================================="
    log_info "WITHDRAW REWARDS"
    log_info "=========================================="
    
    if [[ -z "$VALOPER_ADDRESS" ]]; then
        log_error "valoper_address not configured in config file"
        exit 1
    fi
    
    log_info "Validator: $VALOPER_ADDRESS"
    
    local password
    password=$(get_password)
    
    # FIX 1: Use --fees instead of auto gas
    local withdraw_cmd="$DAEMON_CMD tx distribution withdraw-rewards $VALOPER_ADDRESS --from $KEY_NAME --commission --fees $MAX_GAS_FEE"
    
    local txhash
    txhash=$(execute_tx "$withdraw_cmd" "$password")
    
    if [[ $? -eq 0 ]]; then
        log_success "Rewards withdrawn!"
        
        local telegram_msg="💰 <b>$PROJECT_NAME</b>%0A"
        telegram_msg+="Withdrew rewards ✅%0A"
        [[ -n "$txhash" ]] && telegram_msg+="Hash: <code>$txhash</code>"
        
        send_telegram "$telegram_msg"
    else
        log_error "Withdrawal failed"
        return 1
    fi
}

check_consensus_state() {
    log_debug "check_consensus_state()"
    log_info "=========================================="
    log_info "CONSENSUS STATE"
    log_info "=========================================="
    
    if [[ -z "$RPC_ENDPOINT" ]]; then
        log_error "rpc_endpoint not configured"
        exit 1
    fi
    
    log_info "Endpoint: $RPC_ENDPOINT"
    
    if ! curl -s "$RPC_ENDPOINT/status" >/dev/null 2>&1; then
        log_error "Cannot connect to: $RPC_ENDPOINT"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}Prevotes:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].prevotes_bit_array'
    
    echo ""
    echo -e "${CYAN}Precommits:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].precommits_bit_array'
    
    echo ""
    echo -e "${CYAN}Round:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].round'
    
    echo ""
    echo -e "${CYAN}Height:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height'
    
    echo ""
    log_success "Consensus check completed"
}

auto_vote_mode() {
    log_debug "auto_vote_mode($1)"
    local vote_option="$1"
    local interval="$AUTO_VOTE_INTERVAL"
    
    log_info "=========================================="
    log_info "AUTO-VOTE MODE"
    log_info "=========================================="
    log_info "Vote: $vote_option | Interval: ${interval}s"
    
    # FIXED: Always cache password for auto-vote, even for OS keyring
    log_info "Caching password for unattended operation..."
    CACHED_PASSWORD=$(get_password)
    if [[ "$KEYRING_BACKEND" != "os" && -z "$CACHED_PASSWORD" ]]; then
        log_error "Password required for auto-vote mode"
        exit 1
    fi
    log_success "Password cached (ready for unattended voting)"
    
    local voted_file="/tmp/cosmos-ops-voted-${PROJECT_NAME}.txt"
    touch "$voted_file"
    
    send_telegram "🤖 <b>$PROJECT_NAME Auto-Voter Started</b>%0AVote: ${vote_option^^}%0AInterval: ${interval}s"
    
    while true; do
        log_info "Checking for proposals..."
        
        local proposals_json
        proposals_json=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals?proposal_status=2" 2>/dev/null)
        
        local proposal_ids
        proposal_ids=$(echo "$proposals_json" | jq -r '.proposals[]?.proposal_id // .proposals[]?.id' 2>/dev/null)
        
        if [[ -z "$proposal_ids" ]]; then
            log_info "No active proposals"
        else
            while IFS= read -r prop_id; do
                [[ -z "$prop_id" || "$prop_id" == "null" ]] && continue
                
                grep -q "^$prop_id$" "$voted_file" && continue
                
                log_info "New proposal: #$prop_id"
                
                if vote_on_proposal "$prop_id" "$vote_option"; then
                    echo "$prop_id" >> "$voted_file"
                fi
                
                sleep 5
            done <<< "$proposal_ids"
        fi
        
        log_info "Waiting $interval seconds..."
        sleep "$interval"
    done
}


main() {
    log_info "=== Cosmos Chain Operations Started ==="
    
    parse_args "$@"
    parse_config "$CONFIG_FILE"
    parse_telegram_config
    
    log_debug "Executing operation: $OPERATION"
    
    case "$OPERATION" in
        vote)
            if [[ "$VOTE_ALL" == "true" ]]; then
                vote_all_active "$VOTE_OPTION"
            else
                vote_on_proposal "$PROPOSAL_ID" "$VOTE_OPTION"
            fi
            ;;
        balance)
            check_balance
            ;;
        withdraw)
            withdraw_rewards
            ;;
        consensus)
            check_consensus_state
            ;;
        auto-vote)
            auto_vote_mode "$VOTE_OPTION"
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            exit 1
            ;;
    esac
    
    log_info "=== Operation Completed ==="
}

main "$@"
