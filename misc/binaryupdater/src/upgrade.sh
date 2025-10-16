#!/bin/bash

# Blockchain Binary Upgrade Script - Fixed Version
# Author: Generated for blockchain node management
# Version: 1.1 - Fixed error handling

# Use strict mode but handle errors gracefully
set -euo pipefail

# Trap errors and show what went wrong
trap 'echo "❌ Script failed at line $LINENO. Check the error above."; exit 1' ERR

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
BACKUP_DIR="$HOME/.blockchain_backups"
CONFIG_FILE=""
VERSION=""
DOWNLOAD_URL=""
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create necessary directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_DIR/upgrade_$(date +%Y%m%d).log"
}

log_info() { log "INFO" "$@"; echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { log "WARN" "$@"; echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "ERROR" "$@"; echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { log "SUCCESS" "$@"; echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Help function
show_help() {
    cat << EOF
Blockchain Binary Upgrade Script

Usage: $0 --config <config_file> [OPTIONS]

Required:
    --config FILE       Configuration file for the blockchain

Options:
    --version VERSION   Specific version to upgrade to (overrides config)
    --url URL          Direct download URL (overrides config)
    --dry-run          Show what would be done without executing
    --help             Show this help message

Examples:
    $0 --config sui.conf --version v1.58.3
    $0 --config cosmos.conf --url https://github.com/cosmos/gaia/releases/download/v15.0.0/gaiad-v15.0.0-linux-amd64
    $0 --config substrate.conf --dry-run
EOF
}

# Parse command line arguments
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

# Enhanced config parser with better error handling
parse_config() {
    local config_file="$1"
    log_info "Parsing configuration file: $config_file"

    # Function to safely extract config values
    get_config_value() {
        local key="$1"
        local value=""

        if grep -q "^$key:" "$config_file"; then
            value=$(grep "^$key:" "$config_file" | head -1 | sed "s/^$key: *//" | sed 's/^["'"'"']\|["'"'"']$//g')
        fi

        echo "$value"
    }

    # Read configuration values with error checking
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

    # Expand tilde in paths
    DOWNLOAD_DIR="${DOWNLOAD_DIR/#~/$HOME}"
    BINARY_DIR="${BINARY_DIR/#~/$HOME}"
    GIT_REPO_DIR="${GIT_REPO_DIR/#~/$HOME}"

    # Validate required fields
    local missing_fields=()

    [[ -z "$PROJECT_NAME" ]] && missing_fields+=("project_name")
    [[ -z "$DOWNLOAD_DIR" ]] && missing_fields+=("download_dir")
    [[ -z "$BINARY_DIR" ]] && missing_fields+=("binary_dir")
    [[ -z "$BINARY_NAMES" ]] && missing_fields+=("binary_names")
    [[ -z "$UPGRADE_METHOD" ]] && missing_fields+=("upgrade_method")

    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        log_error "Missing required configuration fields: ${missing_fields[*]}"
        log_error "Please check your configuration file format"
        exit 1
    fi

    # Method-specific validation
    if [[ "$UPGRADE_METHOD" == "download" && -z "$DOWNLOAD_URL_TEMPLATE" && -z "$DOWNLOAD_URL" ]]; then
        log_error "Download method requires download_url_template or --url parameter"
        exit 1
    fi

    if [[ "$UPGRADE_METHOD" == "compile" ]]; then
        [[ -z "$GIT_REPO_DIR" ]] && missing_fields+=("git_repo_dir")
        [[ -z "$BUILD_COMMAND" ]] && missing_fields+=("build_command")

        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_error "Compile method missing required fields: ${missing_fields[*]}"
            exit 1
        fi
    fi

    # Create download directory if it doesn't exist
    if [[ ! -d "$DOWNLOAD_DIR" ]]; then
        log_info "Creating download directory: $DOWNLOAD_DIR"
        mkdir -p "$DOWNLOAD_DIR"
    fi

    log_success "Configuration loaded for project: $PROJECT_NAME"
    log_info "Upgrade method: $UPGRADE_METHOD"
    log_info "Download directory: $DOWNLOAD_DIR"
    log_info "Binary directory: $BINARY_DIR"
    log_info "Binary names: $BINARY_NAMES"
    [[ -n "$SERVICE_NAME" ]] && log_info "Service name: $SERVICE_NAME"
}

# Create backup of current binaries
backup_binaries() {
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/${PROJECT_NAME}_${backup_timestamp}"

    log_info "Creating backup at: $backup_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup directory: $backup_path"
        IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
        for binary in "${BINARIES[@]}"; do
            binary=$(echo "$binary" | xargs)
            log_info "[DRY RUN] Would backup: $BINARY_DIR/$binary"
        done
        return 0
    fi

    mkdir -p "$backup_path"

    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    for binary in "${BINARIES[@]}"; do
        binary=$(echo "$binary" | xargs)
        if [[ -f "$BINARY_DIR/$binary" ]]; then
            cp "$BINARY_DIR/$binary" "$backup_path/"
            log_success "Backed up: $binary"
        else
            log_warn "Binary not found for backup: $BINARY_DIR/$binary"
        fi
    done

    echo "$backup_path" > "/tmp/last_backup_${PROJECT_NAME}"
    log_success "Backup completed"
}

# Stop service
stop_service() {
    if [[ -n "$SERVICE_NAME" ]]; then
        log_info "Stopping service: $SERVICE_NAME"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would stop service: $SERVICE_NAME"
            return 0
        fi

        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            sudo systemctl stop "$SERVICE_NAME"
            log_success "Service stopped: $SERVICE_NAME"
        else
            log_warn "Service was not running: $SERVICE_NAME"
        fi
    else
        log_info "No service configured, skipping service stop"
    fi
}

# Start service
start_service() {
    if [[ -n "$SERVICE_NAME" ]]; then
        log_info "Starting service: $SERVICE_NAME"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would start service: $SERVICE_NAME"
            return 0
        fi

        sudo systemctl start "$SERVICE_NAME"

        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_success "Service started successfully: $SERVICE_NAME"
        else
            log_error "Failed to start service: $SERVICE_NAME"
            return 1
        fi
    else
        log_info "No service configured, skipping service start"
    fi
}

# Download and extract binary
download_binary() {
    local version="$1"
    local download_url="$2"

    local version_dir="$DOWNLOAD_DIR/$version"

    log_info "Download directory: $version_dir"
    log_info "Download URL: $download_url"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create directory: $version_dir"
        log_info "[DRY RUN] Would download: $download_url"
        log_info "[DRY RUN] Would extract archive"
        return 0
    fi

    mkdir -p "$version_dir"
    cd "$version_dir"

    local filename=$(basename "$download_url")
    log_info "Downloading: $filename"

    if ! wget -O "$filename" "$download_url"; then
        log_error "Failed to download: $download_url"
        return 1
    fi

    log_info "Extracting: $filename"
    if [[ "$filename" =~ \.tar\.gz$ || "$filename" =~ \.tgz$ ]]; then
        tar -xzf "$filename"
    elif [[ "$filename" =~ \.tar\.bz2$ ]]; then
        tar -xjf "$filename"
    elif [[ "$filename" =~ \.zip$ ]]; then
        unzip "$filename"
    else
        log_warn "Unknown archive format, treating as binary: $filename"
        chmod +x "$filename"
    fi

    log_success "Download and extraction completed"
}

# Compile from source
compile_binary() {
    local version="$1"

    log_info "Compiling binary for version: $version"
    log_info "Repository directory: $GIT_REPO_DIR"

    if [[ ! -d "$GIT_REPO_DIR" ]]; then
        log_error "Git repository directory not found: $GIT_REPO_DIR"
        exit 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would change to directory: $GIT_REPO_DIR"
        log_info "[DRY RUN] Would fetch latest changes"
        log_info "[DRY RUN] Would checkout version: $version"
        log_info "[DRY RUN] Would run build command: $BUILD_COMMAND"
        return 0
    fi

    cd "$GIT_REPO_DIR"

    log_info "Fetching latest changes..."
    git fetch --all --tags

    log_info "Checking out version: $version"
    git checkout "$version"

    if [[ -f "Makefile" ]] && make -n clean &>/dev/null; then
        log_info "Cleaning previous build..."
        make clean
    fi

    log_info "Building with command: $BUILD_COMMAND"
    eval "$BUILD_COMMAND"

    log_success "Compilation completed"
}

# Install binaries
install_binaries() {
    local source_dir="$1"

    log_info "Installing binaries from: $source_dir"

    if [[ "$DRY_RUN" == "true" ]]; then
        IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
        for binary in "${BINARIES[@]}"; do
            binary=$(echo "$binary" | xargs)
            log_info "[DRY RUN] Would install: $binary to $BINARY_DIR/"
        done
        return 0
    fi

    cd "$source_dir"

    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    for binary in "${BINARIES[@]}"; do
        binary=$(echo "$binary" | xargs)

        local binary_path=""
        if [[ -f "$binary" ]]; then
            binary_path="$binary"
        elif [[ -f "./$binary" ]]; then
            binary_path="./$binary"
        else
            for subdir in bin build target/release app; do
                if [[ -f "$subdir/$binary" ]]; then
                    binary_path="$subdir/$binary"
                    break
                fi
            done
        fi

        if [[ -z "$binary_path" ]]; then
            log_error "Binary not found: $binary"
            log_error "Searched in: . bin build target/release app"
            exit 1
        fi

        log_info "Installing: $binary_path -> $BINARY_DIR/$binary"
        sudo cp "$binary_path" "$BINARY_DIR/"
        sudo chmod +x "$BINARY_DIR/$binary"

        log_success "Installed: $binary"
    done
}

# Verify binary version
verify_binary() {
    local binary_name="$1"
    local expected_version="$2"

    log_info "Verifying binary: $binary_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would verify binary version"
        return 0
    fi

    local version_output=""
    for flag in "-V" "--version" "version"; do
        if version_output=$("$BINARY_DIR/$binary_name" $flag 2>/dev/null); then
            break
        fi
    done

    if [[ -n "$version_output" ]]; then
        log_info "$binary_name version: $version_output"
        return 0
    else
        log_warn "Could not determine version for $binary_name"
        return 1
    fi
}

# Main upgrade function
main_upgrade() {
    local version="$VERSION"
    local download_url="$DOWNLOAD_URL"

    log_info "Starting upgrade for $PROJECT_NAME"
    log_info "Target version: ${version:-'latest'}"

    if [[ "$UPGRADE_METHOD" == "download" ]]; then
        if [[ -z "$download_url" && -n "$DOWNLOAD_URL_TEMPLATE" ]]; then
            download_url="${DOWNLOAD_URL_TEMPLATE//\{VERSION\}/$version}"
            download_url="${download_url//\{PLATFORM\}/$PLATFORM}"
            log_info "Constructed download URL: $download_url"
        fi

        if [[ -z "$download_url" ]]; then
            log_error "No download URL available"
            exit 1
        fi
    fi

    backup_binaries
    stop_service

    local source_dir=""

    if [[ "$UPGRADE_METHOD" == "download" ]]; then
        download_binary "$version" "$download_url"
        source_dir="$DOWNLOAD_DIR/$version"
    elif [[ "$UPGRADE_METHOD" == "compile" ]]; then
        compile_binary "$version"
        if [[ -n "$COMPILED_BINARY_PATH" ]]; then
            source_dir="$GIT_REPO_DIR/$COMPILED_BINARY_PATH"
        else
            source_dir="$GIT_REPO_DIR"
        fi
    else
        log_error "Invalid upgrade method: $UPGRADE_METHOD"
        exit 1
    fi

    install_binaries "$source_dir"

    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    local main_binary="${BINARIES[0]}"
    main_binary=$(echo "$main_binary" | xargs)

    verify_binary "$main_binary" "$version"
    start_service

    log_success "Upgrade completed successfully!"
    [[ -n "$SERVICE_NAME" ]] && log_info "Check service status with: systemctl status $SERVICE_NAME"
}

# Main function
main() {
    log_info "=== Blockchain Binary Upgrade Script Started ==="

    parse_args "$@"
    parse_config "$CONFIG_FILE"

    if [[ "$VERSION" == "rollback" ]]; then
        log_error "Rollback functionality not implemented in this version"
        exit 1
    fi

    main_upgrade

    log_info "=== Upgrade Script Completed ==="
}

main "$@"
