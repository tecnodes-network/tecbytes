#!/bin/bash

# Cosmos Chain Operations Script
# Version: 1.0
# Author: Generated for Cosmos-based chain management
# Features: Vote, Balance, Withdraw, Consensus State, Auto-voting

set -euo pipefail
trap 'echo "❌ Script failed at line $LINENO. Check the error above."; exit 1' ERR

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
TELEGRAM_CONF="$SCRIPT_DIR/telegram.conf"

CONFIG_FILE=""
OPERATION=""
VOTE_OPTION=""
PROPOSAL_ID=""
AUTO_VOTE_INTERVAL=360
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$LOG_DIR"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOG_DIR/cosmos-ops_$(date +%Y%m%d).log"
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
    --config FILE           Chain configuration file (e.g., jackal.conf)

Operations:
    --vote <yes|no|abstain|veto>  Vote on proposal
    --balance                     Check wallet balances
    --withdraw-rewards            Withdraw validator rewards + commission
    --consensus-state             Check consensus state
    --auto-vote <option>          Continuous voting mode

Options:
    --proposal-id ID         Proposal ID for voting
    --interval SECONDS       Auto-vote check interval (default: 360)
    --dry-run               Show what would be done without executing

Examples:
    # Vote on proposal
    $0 --config jackal.conf --vote yes --proposal-id 24
    
    # Check balance
    $0 --config jackal.conf --balance
    
    # Withdraw rewards + commission
    $0 --config jackal.conf --withdraw-rewards
    
    # Check consensus state
    $0 --config jackal.conf --consensus-state
    
    # Auto-vote mode (continuous)
    $0 --config jackal.conf --auto-vote yes --interval 360
    
    # Dry run
    $0 --config jackal.conf --vote yes --proposal-id 24 --dry-run

EOF
    exit 0
}

# Parse arguments
parse_args() {
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
            --help|-h)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "Config file is required"
        show_help
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    if [[ -z "$OPERATION" ]]; then
        log_error "No operation specified"
        show_help
    fi
}

# Parse config file
parse_config() {
    local config_file="$1"
    
    get_config_value() {
        local key="$1"
        local value=""
        if grep -q "^$key:" "$config_file"; then
            value=$(grep "^$key:" "$config_file" | head -1 | sed "s/^$key: *//" | tr -d '"' | tr -d "'")
        fi
        echo "$value"
    }
    
    PROJECT_NAME=$(get_config_value "project_name")
    DAEMON_NAME=$(get_config_value "daemon_name")
    RPC_URL=$(get_config_value "rpc_url")
    RPC_ENDPOINT=$(get_config_value "rpc_endpoint")
    CHAIN_ID=$(get_config_value "chain_id")
    KEYRING_BACKEND=$(get_config_value "keyring_backend")
    KEY_NAME=$(get_config_value "key_name")
    PASSWORD_FILE=$(get_config_value "password_file")
    MAX_GAS_FEE=$(get_config_value "max_gas_fee")
    GAS_ADJUSTMENT=$(get_config_value "gas_adjustment")
    
    PASSWORD_FILE="${PASSWORD_FILE/#~/$HOME}"
    
    # Defaults
    [[ -z "$KEYRING_BACKEND" ]] && KEYRING_BACKEND="file"
    [[ -z "$GAS_ADJUSTMENT" ]] && GAS_ADJUSTMENT="1.3"
    [[ -z "$MAX_GAS_FEE" ]] && MAX_GAS_FEE="1000000"
    
    # Validate required fields
    local missing=()
    [[ -z "$DAEMON_NAME" ]] && missing+=("daemon_name")
    [[ -z "$CHAIN_ID" ]] && missing+=("chain_id")
    [[ -z "$KEY_NAME" ]] && missing+=("key_name")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required config fields: ${missing[*]}"
        exit 1
    fi
    
    log_success "Configuration loaded for: $PROJECT_NAME"
}

# Parse Telegram config
parse_telegram_config() {
    if [[ ! -f "$TELEGRAM_CONF" ]]; then
        log_warn "Telegram config not found: $TELEGRAM_CONF"
        TELEGRAM_ENABLED=false
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
}

# Send Telegram notification
send_telegram() {
    if [[ "$TELEGRAM_ENABLED" != "true" ]]; then
        return
    fi
    
    local message="$1"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" >/dev/null 2>&1 || log_warn "Failed to send Telegram notification"
}

# Get password (GPG or manual)
get_password() {
    local password=""
    
    # Try GPG decryption
    if [[ -n "$PASSWORD_FILE" && -f "$PASSWORD_FILE" ]]; then
        log_info "Decrypting password from: $PASSWORD_FILE"
        password=$(gpg --decrypt "$PASSWORD_FILE" 2>/dev/null) || {
            log_warn "GPG decryption failed, will prompt for password"
            password=""
        }
    fi
    
    # Fallback to manual entry
    if [[ -z "$password" ]]; then
        read -s -p "Enter keyring password for $KEY_NAME: " password
        echo ""
    fi
    
    echo "$password"
}

# Get validator address from key
get_validator_address() {
    local val_addr
    val_addr=$($DAEMON_NAME keys show "$KEY_NAME" --bech val -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null) || {
        log_error "Failed to get validator address from key: $KEY_NAME"
        exit 1
    }
    echo "$val_addr"
}

# Execute transaction with gas estimation and retry
execute_tx() {
    local tx_command="$1"
    local password="$2"
    local gas_adj="${3:-$GAS_ADJUSTMENT}"
    
    log_info "Simulating transaction with gas-adjustment=$gas_adj..."
    
    local tx_result
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $tx_command"
        return 0
    fi
    
    # Execute with password piping
    tx_result=$(echo "$password" | $tx_command --gas auto --gas-adjustment "$gas_adj" --chain-id "$CHAIN_ID" --keyring-backend "$KEYRING_BACKEND" -y 2>&1) || {
        local exit_code=$?
        
        # Check if out of gas
        if echo "$tx_result" | grep -q "out of gas"; then
            log_warn "Transaction out of gas, retrying with higher adjustment..."
            
            # Retry with increased gas
            local new_adj=$(echo "$gas_adj + 0.2" | bc)
            if (( $(echo "$new_adj > 2.5" | bc -l) )); then
                log_error "Gas adjustment exceeded maximum (2.5), aborting"
                return 1
            fi
            
            execute_tx "$tx_command" "$password" "$new_adj"
            return $?
        fi
        
        log_error "Transaction failed:"
        echo "$tx_result" | grep -i "error" || echo "$tx_result"
        return $exit_code
    }
    
    # Extract tx hash
    local txhash
    txhash=$(echo "$tx_result" | grep -o "txhash: [A-F0-9]*" | cut -d' ' -f2)
    
    if [[ -n "$txhash" ]]; then
        log_success "Transaction submitted successfully"
        log_tx "TxHash: $txhash"
        echo "$txhash"
    else
        log_warn "Transaction submitted but couldn't extract hash"
        echo "$tx_result"
    fi
}

# Vote on proposal
vote_on_proposal() {
    local proposal_id="$1"
    local vote_option="$2"
    
    log_info "==========================================
"
    log_info "VOTING ON PROPOSAL #$proposal_id"
    log_info "=========================================="
    
    # Fetch proposal details
    log_info "Fetching proposal details..."
    local proposal_json
    proposal_json=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals/$proposal_id")
    
    local proposal_title
    proposal_title=$(echo "$proposal_json" | jq -r '.proposal.content.title // .proposal.title' 2>/dev/null)
    
    if [[ -n "$proposal_title" && "$proposal_title" != "null" ]]; then
        log_info "Proposal: $proposal_title"
    fi
    
    log_info "Vote option: $vote_option"
    
    # Get password
    local password
    password=$(get_password)
    
    # Build vote command
    local vote_cmd="$DAEMON_NAME tx gov vote $proposal_id $vote_option --from $KEY_NAME"
    
    # Execute
    local txhash
    txhash=$(execute_tx "$vote_cmd" "$password")
    
    if [[ $? -eq 0 ]]; then
        log_success "Vote submitted successfully!"
        
        # Send Telegram notification
        local telegram_msg="🗳️ <b>$PROJECT_NAME Validator</b>%0A"
        telegram_msg+="Voted <b>${vote_option^^}</b> on Proposal #$proposal_id%0A"
        telegram_msg+="Status: Success ✅%0A"
        [[ -n "$txhash" ]] && telegram_msg+="TxHash: <code>$txhash</code>%0A"
        telegram_msg+="Time: $(date '+%Y-%m-%d %H:%M:%S')"
        
        send_telegram "$telegram_msg"
    else
        log_error "Vote submission failed"
        
        local telegram_msg="🗳️ <b>$PROJECT_NAME Validator</b>%0A"
        telegram_msg+="Failed to vote on Proposal #$proposal_id ❌%0A"
        telegram_msg+="Time: $(date '+%Y-%m-%d %H:%M:%S')"
        
        send_telegram "$telegram_msg"
        return 1
    fi
}

# Check balances
check_balance() {
    log_info "=========================================="
    log_info "CHECKING WALLET BALANCE"
    log_info "=========================================="
    
    local address
    address=$($DAEMON_NAME keys show "$KEY_NAME" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null) || {
        log_error "Failed to get address from key: $KEY_NAME"
        exit 1
    }
    
    log_info "Address: $address"
    
    # Get balance
    log_info "Fetching balance..."
    $DAEMON_NAME query bank balances "$address" --chain-id "$CHAIN_ID"
    
    # Get rewards
    local val_addr
    val_addr=$(get_validator_address)
    
    log_info "Fetching rewards..."
    $DAEMON_NAME query distribution rewards "$address" "$val_addr" --chain-id "$CHAIN_ID"
    
    log_success "Balance check completed"
}

# Withdraw rewards and commission
withdraw_rewards() {
    log_info "=========================================="
    log_info "WITHDRAWING REWARDS + COMMISSION"
    log_info "=========================================="
    
    local val_addr
    val_addr=$(get_validator_address)
    
    log_info "Validator address: $val_addr"
    
    # Get password
    local password
    password=$(get_password)
    
    # Build withdraw command with --commission flag
    local withdraw_cmd="$DAEMON_NAME tx distribution withdraw-rewards $val_addr --from $KEY_NAME --commission"
    
    log_info "Withdrawing rewards and commission..."
    
    # Execute
    local txhash
    txhash=$(execute_tx "$withdraw_cmd" "$password")
    
    if [[ $? -eq 0 ]]; then
        log_success "Rewards and commission withdrawn successfully!"
        
        # Send Telegram notification
        local telegram_msg="💰 <b>$PROJECT_NAME Validator</b>%0A"
        telegram_msg+="Withdrew rewards + commission ✅%0A"
        [[ -n "$txhash" ]] && telegram_msg+="TxHash: <code>$txhash</code>%0A"
        telegram_msg+="Time: $(date '+%Y-%m-%d %H:%M:%S')"
        
        send_telegram "$telegram_msg"
    else
        log_error "Withdrawal failed"
        return 1
    fi
}

# Check consensus state
check_consensus_state() {
    log_info "=========================================="
    log_info "CONSENSUS STATE"
    log_info "=========================================="
    
    if [[ -z "$RPC_ENDPOINT" ]]; then
        log_error "rpc_endpoint not configured"
        exit 1
    fi
    
    log_info "Fetching consensus state from: $RPC_ENDPOINT"
    
    # Prevotes
    echo ""
    echo -e "${CYAN}Prevotes:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].prevotes_bit_array'
    
    # Precommits
    echo ""
    echo -e "${CYAN}Precommits:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].precommits_bit_array'
    
    # Round
    echo ""
    echo -e "${CYAN}Round:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height_vote_set[0].round'
    
    # Height
    echo ""
    echo -e "${CYAN}Height:${NC}"
    curl -s "$RPC_ENDPOINT/consensus_state" | jq -r '.result.round_state.height'
    
    echo ""
    log_success "Consensus state check completed"
}

# Auto-vote mode (continuous)
auto_vote_mode() {
    local vote_option="$1"
    local interval="$AUTO_VOTE_INTERVAL"
    
    log_info "=========================================="
    log_info "AUTO-VOTE MODE STARTED"
    log_info "=========================================="
    log_info "Vote option: $vote_option"
    log_info "Check interval: $interval seconds"
    log_warn "⚠️  Will vote $vote_option on ALL proposals (including spam)!"
    
    # Track voted proposals
    local voted_file="/tmp/cosmos-ops-voted-${PROJECT_NAME}.txt"
    touch "$voted_file"
    
    # Send startup notification
    local telegram_msg="🤖 <b>$PROJECT_NAME Auto-Voter</b>%0A"
    telegram_msg+="Auto-vote mode started%0A"
    telegram_msg+="Default vote: <b>${vote_option^^}</b>%0A"
    telegram_msg+="Interval: ${interval}s"
    
    send_telegram "$telegram_msg"
    
    while true; do
        log_info "Checking for new proposals..."
        
        # Get all proposals in voting period
        local proposals_json
        proposals_json=$(curl -s "$RPC_URL/cosmos/gov/v1beta1/proposals?proposal_status=2")
        
        # Extract proposal IDs
        local proposal_ids
        proposal_ids=$(echo "$proposals_json" | jq -r '.proposals[]?.proposal_id // .proposals[]?.id' 2>/dev/null)
        
        if [[ -z "$proposal_ids" ]]; then
            log_info "No proposals in voting period"
        else
            while IFS= read -r prop_id; do
                if [[ -z "$prop_id" || "$prop_id" == "null" ]]; then
                    continue
                fi
                
                # Check if already voted
                if grep -q "^$prop_id$" "$voted_file"; then
                    continue
                fi
                
                log_info "Found new proposal: #$prop_id"
                
                # Vote
                if vote_on_proposal "$prop_id" "$vote_option"; then
                    echo "$prop_id" >> "$voted_file"
                    log_success "Voted on proposal #$prop_id"
                fi
                
                # Small delay between votes
                sleep 5
                
            done <<< "$proposal_ids"
        fi
        
        log_info "Waiting $interval seconds until next check..."
        sleep "$interval"
    done
}

# Main execution
main() {
    log_info "=== Cosmos Chain Operations Started ==="
    
    parse_args "$@"
    parse_config "$CONFIG_FILE"
    parse_telegram_config
    
    case "$OPERATION" in
        vote)
            if [[ -z "$PROPOSAL_ID" ]]; then
                log_error "Proposal ID required for voting"
                exit 1
            fi
            vote_on_proposal "$PROPOSAL_ID" "$VOTE_OPTION"
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
