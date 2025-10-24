#!/bin/bash

# Blockchain Binary Upgrade Script - Critical Fixes
# Version: 1.4 - Fixed logging capture + auto version detection
# Author: Generated for blockchain node management

set -euo pipefail
trap 'echo "❌ Script failed at line $LINENO. Check the error above."; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
BACKUP_DIR="$HOME/.blockchain_backups"
CONFIG_FILE=""
VERSION=""
DOWNLOAD_URL=""
DRY_RUN=false

PROPOSAL_ID=""
COSMOVISOR_UPGRADE_NAME=""
REUSE_EXISTING_UPGRADE=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# FIXED: Removed tee to avoid capturing log output in variables
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOG_DIR/upgrade_$(date +%Y%m%d).log"
}

log_info() { log "INFO" "$@"; echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { log "WARN" "$@"; echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "ERROR" "$@"; echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { log "SUCCESS" "$@"; echo -e "${GREEN}[SUCCESS]${NC} $*"; }

show_help() {
    cat << EOF
Blockchain Binary Upgrade Script

Usage: $0 --config <config_file> [OPTIONS]

Required:
    --config FILE       Configuration file for the blockchain

Options:
    --version VERSION   Version to upgrade to (auto-detected from proposal if omitted with --proposal-id)
    --url URL          Direct download URL
    --dry-run          Show what would be done
    --help             Show this help

Cosmovisor Options:
    --proposal-id ID              Fetch upgrade info from proposal (auto-detects version)
    --cosmovisor-upgrade-name NAME  Manually specify upgrade plan name
    --reuse-existing-upgrade       Emergency: overwrite existing folder

Examples:
    $0 --config jackal.conf --proposal-id 24                    # Auto-detect version
    $0 --config jackal.conf --version v5.0.0 --proposal-id 24   # Explicit version
    $0 --config sui.conf --version v1.58.3

EOF
}

parse_args() {
    log_info "Parsing command line arguments..."
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                log_info "Config file: $CONFIG_FILE"
                shift 2
                ;;
            --version)
                VERSION="$2"
                log_info "Version: $VERSION"
                shift 2
                ;;
            --url)
                DOWNLOAD_URL="$2"
                log_info "Download URL: $DOWNLOAD_URL"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            --proposal-id)
                PROPOSAL_ID="$2"
                log_info "Proposal ID: $PROPOSAL_ID"
                shift 2
                ;;
            --cosmovisor-upgrade-name)
                COSMOVISOR_UPGRADE_NAME="$2"
                log_info "Cosmovisor upgrade name: $COSMOVISOR_UPGRADE_NAME"
                shift 2
                ;;
            --reuse-existing-upgrade)
                REUSE_EXISTING_UPGRADE=true
                log_info "Emergency mode enabled"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "Config file is required"
        show_help
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_success "Arguments parsed successfully"
}

parse_config() {
    local config_file="$1"
    log_info "Parsing configuration file: $config_file"
    
    get_config_value() {
        local key="$1"
        local value=""
        
        if grep -q "^$key:" "$config_file"; then
            value=$(grep "^$key:" "$config_file" | head -1 | sed "s/^$key: *//" | tr -d '"' | tr -d "'")
        fi
        
        echo "$value"
    }
    
    PROJECT_NAME=$(get_config_value "project_name")
    DOWNLOAD_DIR=$(get_config_value "download_dir")
    BINARY_DIR=$(get_config_value "binary_dir")
    SERVICE_NAME=$(get_config_value "service_name")
    BINARY_NAMES=$(get_config_value "binary_names")
    PLATFORM=$(get_config_value "platform")
    UPGRADE_METHOD=$(get_config_value "upgrade_method")
    DOWNLOAD_URL_TEMPLATE=$(get_config_value "download_url_template")
    GIT_REPO_DIR=$(get_config_value "git_repo_dir")
    BUILD_COMMAND=$(get_config_value "build_command")
    COMPILED_BINARY_PATH=$(get_config_value "compiled_binary_path")
    
    COSMOVISOR_MODE=$(get_config_value "cosmovisor_mode")
    RPC_URL=$(get_config_value "rpc_url")
    DAEMON_NAME=$(get_config_value "daemon_name")
    COSMOVISOR_HOME=$(get_config_value "cosmovisor_home")
    
    DOWNLOAD_DIR="${DOWNLOAD_DIR/#~/$HOME}"
    BINARY_DIR="${BINARY_DIR/#~/$HOME}"
    GIT_REPO_DIR="${GIT_REPO_DIR/#~/$HOME}"
    COSMOVISOR_HOME="${COSMOVISOR_HOME/#~/$HOME}"
    
    local missing_fields=()
    
    [[ -z "$PROJECT_NAME" ]] && missing_fields+=("project_name")
    [[ -z "$DOWNLOAD_DIR" ]] && missing_fields+=("download_dir")
    [[ -z "$UPGRADE_METHOD" ]] && missing_fields+=("upgrade_method")
    
    if [[ "$COSMOVISOR_MODE" != "true" ]]; then
        [[ -z "$BINARY_DIR" ]] && missing_fields+=("binary_dir")
        [[ -z "$BINARY_NAMES" ]] && missing_fields+=("binary_names")
    fi
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        log_error "Missing required fields: ${missing_fields[*]}"
        exit 1
    fi
    
    if [[ "$UPGRADE_METHOD" == "download" && -z "$DOWNLOAD_URL_TEMPLATE" && -z "$DOWNLOAD_URL" ]]; then
        log_error "Download method requires download_url_template or --url"
        exit 1
    fi
    
    if [[ "$UPGRADE_METHOD" == "compile" ]]; then
        [[ -z "$GIT_REPO_DIR" ]] && missing_fields+=("git_repo_dir")
        [[ -z "$BUILD_COMMAND" ]] && missing_fields+=("build_command")
        
        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_error "Compile method missing: ${missing_fields[*]}"
            exit 1
        fi
    fi
    
    if [[ "$COSMOVISOR_MODE" == "true" ]]; then
        [[ -z "$COSMOVISOR_HOME" ]] && missing_fields+=("cosmovisor_home")
        [[ -z "$DAEMON_NAME" ]] && missing_fields+=("daemon_name")
        
        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_error "Cosmovisor mode missing: ${missing_fields[*]}"
            exit 1
        fi
    fi
    
    if [[ ! -d "$DOWNLOAD_DIR" ]]; then
        mkdir -p "$DOWNLOAD_DIR"
    fi
    
    log_success "Configuration loaded for: $PROJECT_NAME"
    log_info "Upgrade method: $UPGRADE_METHOD"
    
    if [[ "$COSMOVISOR_MODE" == "true" ]]; then
        log_info "Cosmovisor mode: ENABLED"
        log_info "Cosmovisor home: $COSMOVISOR_HOME"
        log_info "Daemon name: $DAEMON_NAME"
    else
        log_info "Binary directory: $BINARY_DIR"
        log_info "Binary names: $BINARY_NAMES"
    fi
}

################################################################################
# COSMOVISOR FUNCTIONS - CRITICAL FIXES
################################################################################

# FIXED: Returns ONLY plan name, logs to stderr to avoid variable pollution
get_upgrade_plan_name_from_rpc() {
    local rpc_url="$1"
    local proposal_id="$2"
    
    # All logs go to stderr (>&2) so they don't pollute the return value
    echo -e "${BLUE}[INFO]${NC} Fetching proposal $proposal_id from RPC" >&2
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} jq required but not installed" >&2
        echo "Install with: sudo apt-get install jq" >&2
        exit 1
    fi
    
    local proposal_json
    proposal_json=$(curl -s "$rpc_url/cosmos/gov/v1beta1/proposals/$proposal_id")
    
    if [[ -z "$proposal_json" ]]; then
        echo -e "${RED}[ERROR]${NC} Failed to fetch proposal" >&2
        exit 1
    fi
    
    local plan_name=""
    
    # Try multiple formats
    plan_name=$(echo "$proposal_json" | jq -r '.proposal.messages[]? | select((."@type" == "/cosmos.upgrade.v1beta1.MsgSoftwareUpgrade") or (."@type" == "cosmos.upgrade.v1beta1.MsgSoftwareUpgrade")) | .plan.name' 2>/dev/null | head -1)
    
    if [[ -z "$plan_name" || "$plan_name" == "null" ]]; then
        plan_name=$(echo "$proposal_json" | jq -r '.proposal.content.plan.name' 2>/dev/null)
    fi
    
    if [[ -z "$plan_name" || "$plan_name" == "null" ]]; then
        plan_name=$(echo "$proposal_json" | jq -r '.proposal.plan.name' 2>/dev/null)
    fi
    
    if [[ -z "$plan_name" || "$plan_name" == "null" ]]; then
        plan_name=$(echo "$proposal_json" | jq -r '.plan.name' 2>/dev/null)
    fi
    
    # Clean the plan name
    plan_name=$(echo "$plan_name" | tr 'A-Z ' 'a-z_' | tr -d '"' | tr -d '\n' | xargs)
    
    if [[ -z "$plan_name" || "$plan_name" == "null" ]]; then
        echo -e "${RED}[ERROR]${NC} Could not extract plan name from proposal" >&2
        echo "Use --cosmovisor-upgrade-name to specify manually" >&2
        exit 1
    fi
    
    echo -e "${GREEN}[SUCCESS]${NC} Extracted plan name: $plan_name" >&2
    
    # ONLY return the clean plan name to stdout
    echo "$plan_name"
}

# NEW: Auto-detect version from proposal
get_version_from_proposal() {
    local rpc_url="$1"
    local proposal_id="$2"
    
    echo -e "${BLUE}[INFO]${NC} Attempting to auto-detect version from proposal" >&2
    
    local proposal_json
    proposal_json=$(curl -s "$rpc_url/cosmos/gov/v1beta1/proposals/$proposal_id")
    
    local version=""
    
    # Try to find version in title
    version=$(echo "$proposal_json" | jq -r '.proposal.content.title' 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    
    # Try description
    if [[ -z "$version" ]]; then
        version=$(echo "$proposal_json" | jq -r '.proposal.content.description' 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    fi
    
    # Try plan info
    if [[ -z "$version" ]]; then
        version=$(echo "$proposal_json" | jq -r '.proposal.content.plan.info' 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    fi
    
    if [[ -n "$version" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} Auto-detected version: $version" >&2
        echo "$version"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not auto-detect version" >&2
        echo ""
    fi
}

cosmovisor_upgrade() {
    log_info "=========================================="
    log_info "COSMOVISOR UPGRADE MODE"
    log_info "=========================================="
    
    # Get upgrade name
    local upgrade_name="$COSMOVISOR_UPGRADE_NAME"
    
    if [[ -z "$upgrade_name" && -n "$PROPOSAL_ID" ]]; then
        if [[ -z "$RPC_URL" ]]; then
            log_error "rpc_url must be configured"
            exit 1
        fi
        
        upgrade_name=$(get_upgrade_plan_name_from_rpc "$RPC_URL" "$PROPOSAL_ID")
        log_success "Fetched upgrade plan name: $upgrade_name"
    fi
    
    if [[ -z "$upgrade_name" ]]; then
        log_error "Upgrade name not determined"
        log_error "Use --cosmovisor-upgrade-name or --proposal-id"
        exit 1
    fi
    
    # NEW: Auto-detect version if not provided
    if [[ -z "$VERSION" && -n "$PROPOSAL_ID" ]]; then
        VERSION=$(get_version_from_proposal "$RPC_URL" "$PROPOSAL_ID")
        if [[ -n "$VERSION" ]]; then
            log_success "Auto-detected version: $VERSION"
        else
            log_error "Version required but could not auto-detect"
            log_error "Please provide --version explicitly"
            exit 1
        fi
    fi
    
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        exit 1
    fi
    
    # Normalize
    upgrade_name=$(echo "$upgrade_name" | tr 'A-Z ' 'a-z_' | xargs)
    
    local target_dir="$COSMOVISOR_HOME/upgrades/$upgrade_name/bin"
    
    log_info "Upgrade plan name: $upgrade_name"
    log_info "Target version: $VERSION"
    log_info "Target directory: $target_dir"
    
    if [[ "$REUSE_EXISTING_UPGRADE" == "true" ]]; then
        log_warn "EMERGENCY MODE: Will overwrite $target_dir"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo "COSMOVISOR DRY RUN"
        echo "=========================================="
        echo "Upgrade name: $upgrade_name"
        echo "Version: $VERSION"
        echo "Target: $target_dir/$DAEMON_NAME"
        echo "Method: $UPGRADE_METHOD"
        echo ""
        if [[ "$UPGRADE_METHOD" == "compile" ]]; then
            echo "Would:"
            echo "  1. Git fetch in $GIT_REPO_DIR"
            echo "  2. Checkout $VERSION"
            echo "  3. Run: $BUILD_COMMAND"
            echo "  4. Copy to $target_dir"
        fi
        echo "=========================================="
        return 0
    fi
    
    log_info "Creating target directory..."
    mkdir -p "$target_dir"
    
    local source_binary_path=""
    
    if [[ "$UPGRADE_METHOD" == "compile" ]]; then
        log_info "Compiling from source..."
        
        if [[ ! -d "$GIT_REPO_DIR" ]]; then
            log_error "Git repo not found: $GIT_REPO_DIR"
            exit 1
        fi
        
        cd "$GIT_REPO_DIR"
        
        log_info "Fetching latest changes..."
        # FIXED: Use || true to ignore tag clobber warnings
        git fetch --all --tags || true
        
        log_info "Checking out $VERSION..."
        if ! git checkout "$VERSION"; then
            log_error "Failed to checkout $VERSION"
            log_error "Make sure the tag/branch exists"
            exit 1
        fi
        
        # FIXED: Only clean if make clean works
        if [[ -f "Makefile" ]]; then
            if make -n clean &>/dev/null; then
                log_info "Cleaning previous build..."
                make clean || log_warn "Clean failed, continuing anyway"
            fi
        fi
        
        log_info "Building: $BUILD_COMMAND"
        if ! eval "$BUILD_COMMAND"; then
            log_error "Build failed with command: $BUILD_COMMAND"
            exit 1
        fi
        
        log_success "Compilation completed"
        
        # Find binary
        if [[ -n "$COMPILED_BINARY_PATH" ]]; then
            source_binary_path="$GIT_REPO_DIR/$COMPILED_BINARY_PATH/$DAEMON_NAME"
        else
            if [[ -f "$GIT_REPO_DIR/$DAEMON_NAME" ]]; then
                source_binary_path="$GIT_REPO_DIR/$DAEMON_NAME"
            else
                for subdir in bin build target/release app; do
                    if [[ -f "$GIT_REPO_DIR/$subdir/$DAEMON_NAME" ]]; then
                        source_binary_path="$GIT_REPO_DIR/$subdir/$DAEMON_NAME"
                        break
                    fi
                done
            fi
        fi
    elif [[ "$UPGRADE_METHOD" == "download" ]]; then
        log_error "Download method not yet implemented for Cosmovisor"
        exit 1
    else
        log_error "Invalid upgrade method: $UPGRADE_METHOD"
        exit 1
    fi
    
    if [[ -z "$source_binary_path" || ! -f "$source_binary_path" ]]; then
        log_error "Compiled binary not found: $DAEMON_NAME"
        log_error "Searched in: $GIT_REPO_DIR and subdirs (bin, build, target/release, app)"
        log_error "Compiled binary path config: $COMPILED_BINARY_PATH"
        exit 1
    fi
    
    log_info "Found binary: $source_binary_path"
    
    log_info "Installing to Cosmovisor..."
    cp "$source_binary_path" "$target_dir/$DAEMON_NAME"
    chmod +x "$target_dir/$DAEMON_NAME"
    
    log_success "Binary installed: $target_dir/$DAEMON_NAME"
    
    # Verify
    log_info "Verifying binary..."
    local version_output=""
    for flag in "-V" "--version" "version"; do
        if version_output=$("$target_dir/$DAEMON_NAME" $flag 2>/dev/null); then
            break
        fi
    done
    
    if [[ -n "$version_output" ]]; then
        log_info "Binary version: $version_output"
    else
        log_warn "Could not determine version (may be normal)"
    fi
    
    log_success "=========================================="
    log_success "COSMOVISOR UPGRADE COMPLETED"
    log_success "=========================================="
    log_info "Binary ready: $target_dir/$DAEMON_NAME"
    log_info "Cosmovisor will switch at upgrade height"
    log_info ""
    log_info "Monitor your node with:"
    log_info "  journalctl -u <your-service> -f"
}

################################################################################
# NON-COSMOVISOR FUNCTIONS (STUBS - NOT CHANGED)
################################################################################

backup_binaries() { :; }
stop_service() { :; }
start_service() { :; }
download_binary() { :; }
compile_binary() { :; }
install_binaries() { :; }
verify_binary() { :; }
main_upgrade() { :; }

main() {
    log_info "=== Blockchain Binary Upgrade Script Started ==="
    
    parse_args "$@"
    parse_config "$CONFIG_FILE"
    
    if [[ "$COSMOVISOR_MODE" == "true" ]]; then
        cosmovisor_upgrade
    else
        main_upgrade
    fi
    
    log_info "=== Upgrade Script Completed ==="
}

main "$@"
