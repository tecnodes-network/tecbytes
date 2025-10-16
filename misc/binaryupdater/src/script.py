# Let's create the main upgrade script and example config files

# First, let's create the main upgrade script
upgrade_script = '''#!/bin/bash

# Blockchain Binary Upgrade Script
# Author: Generated for blockchain node management
# Version: 1.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
BACKUP_DIR="$HOME/.blockchain_backups"
CONFIG_FILE=""
VERSION=""
DOWNLOAD_URL=""
DRY_RUN=false

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

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

Config file should be in YAML format. See example configs for reference.
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --url)
                DOWNLOAD_URL="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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
}

# Parse YAML config file (simple parser for our needs)
parse_config() {
    local config_file="$1"
    
    # Read configuration values
    PROJECT_NAME=$(grep "^project_name:" "$config_file" | sed 's/project_name: *//' | tr -d '"'"'"'')
    DOWNLOAD_DIR=$(grep "^download_dir:" "$config_file" | sed 's/download_dir: *//' | tr -d '"'"'"'')
    BINARY_DIR=$(grep "^binary_dir:" "$config_file" | sed 's/binary_dir: *//' | tr -d '"'"'"'')
    SERVICE_NAME=$(grep "^service_name:" "$config_file" | sed 's/service_name: *//' | tr -d '"'"'"'')
    BINARY_NAMES=$(grep "^binary_names:" "$config_file" | sed 's/binary_names: *//' | tr -d '"'"'"'')
    PLATFORM=$(grep "^platform:" "$config_file" | sed 's/platform: *//' | tr -d '"'"'"'')
    
    # Upgrade method (download or compile)
    UPGRADE_METHOD=$(grep "^upgrade_method:" "$config_file" | sed 's/upgrade_method: *//' | tr -d '"'"'"'')
    
    # For download method
    if [[ -z "$DOWNLOAD_URL" ]]; then
        DOWNLOAD_URL_TEMPLATE=$(grep "^download_url_template:" "$config_file" | sed 's/download_url_template: *//' | tr -d '"'"'"'')
    fi
    
    # For compile method
    GIT_REPO_DIR=$(grep "^git_repo_dir:" "$config_file" | sed 's/git_repo_dir: *//' | tr -d '"'"'"'')
    BUILD_COMMAND=$(grep "^build_command:" "$config_file" | sed 's/build_command: *//' | tr -d '"'"'"'')
    COMPILED_BINARY_PATH=$(grep "^compiled_binary_path:" "$config_file" | sed 's/compiled_binary_path: *//' | tr -d '"'"'"'')
    
    # Expand tilde in paths
    DOWNLOAD_DIR="${DOWNLOAD_DIR/#\\~/$HOME}"
    BINARY_DIR="${BINARY_DIR/#\\~/$HOME}"
    GIT_REPO_DIR="${GIT_REPO_DIR/#\\~/$HOME}"
    
    # Validate required fields
    if [[ -z "$PROJECT_NAME" || -z "$DOWNLOAD_DIR" || -z "$BINARY_DIR" || -z "$BINARY_NAMES" ]]; then
        log_error "Missing required configuration fields"
        exit 1
    fi
    
    log_info "Configuration loaded for project: $PROJECT_NAME"
}

# Create backup of current binaries
backup_binaries() {
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/${PROJECT_NAME}_${backup_timestamp}"
    
    log_info "Creating backup at: $backup_path"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup directory: $backup_path"
        return 0
    fi
    
    mkdir -p "$backup_path"
    
    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    for binary in "${BINARIES[@]}"; do
        binary=$(echo "$binary" | xargs) # trim whitespace
        if [[ -f "$BINARY_DIR/$binary" ]]; then
            cp "$BINARY_DIR/$binary" "$backup_path/"
            log_info "Backed up: $binary"
        else
            log_warn "Binary not found for backup: $BINARY_DIR/$binary"
        fi
    done
    
    # Store backup path for potential rollback
    echo "$backup_path" > "/tmp/last_backup_${PROJECT_NAME}"
}

# Stop service
stop_service() {
    if [[ -n "$SERVICE_NAME" ]]; then
        log_info "Stopping service: $SERVICE_NAME"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would stop service: $SERVICE_NAME"
            return 0
        fi
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            sudo systemctl stop "$SERVICE_NAME"
            log_success "Service stopped: $SERVICE_NAME"
        else
            log_warn "Service was not running: $SERVICE_NAME"
        fi
    else
        log_warn "No service name configured, skipping service stop"
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
        
        # Wait a moment and check if service started successfully
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "Service started successfully: $SERVICE_NAME"
        else
            log_error "Failed to start service: $SERVICE_NAME"
            return 1
        fi
    else
        log_warn "No service name configured, skipping service start"
    fi
}

# Download and extract binary
download_binary() {
    local version="$1"
    local download_url="$2"
    
    # Create version-specific directory
    local version_dir="$DOWNLOAD_DIR/$version"
    mkdir -p "$version_dir"
    cd "$version_dir"
    
    log_info "Downloading binary from: $download_url"
    log_info "Download directory: $version_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download: $download_url"
        log_info "[DRY RUN] Would extract to: $version_dir"
        return 0
    fi
    
    # Download the file
    local filename=$(basename "$download_url")
    wget -O "$filename" "$download_url"
    
    # Extract based on file extension
    if [[ "$filename" =~ \\.tar\\.gz$ || "$filename" =~ \\.tgz$ ]]; then
        tar -xzf "$filename"
    elif [[ "$filename" =~ \\.tar\\.bz2$ ]]; then
        tar -xjf "$filename"
    elif [[ "$filename" =~ \\.zip$ ]]; then
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
    
    cd "$GIT_REPO_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would fetch latest changes"
        log_info "[DRY RUN] Would checkout version: $version"
        log_info "[DRY RUN] Would run build command: $BUILD_COMMAND"
        return 0
    fi
    
    # Fetch latest changes
    log_info "Fetching latest changes..."
    git fetch --all --tags
    
    # Checkout the specified version
    log_info "Checking out version: $version"
    git checkout "$version"
    
    # Clean previous build (optional, but safe)
    if [[ -f "Makefile" ]] && make -n clean &>/dev/null; then
        log_info "Cleaning previous build..."
        make clean
    fi
    
    # Build the binary
    log_info "Building with command: $BUILD_COMMAND"
    eval "$BUILD_COMMAND"
    
    log_success "Compilation completed"
}

# Install binaries
install_binaries() {
    local source_dir="$1"
    
    log_info "Installing binaries from: $source_dir"
    
    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        for binary in "${BINARIES[@]}"; do
            binary=$(echo "$binary" | xargs)
            log_info "[DRY RUN] Would install: $binary to $BINARY_DIR/"
        done
        return 0
    fi
    
    cd "$source_dir"
    
    for binary in "${BINARIES[@]}"; do
        binary=$(echo "$binary" | xargs) # trim whitespace
        
        # Find the binary in the source directory
        local binary_path=""
        if [[ -f "$binary" ]]; then
            binary_path="$binary"
        elif [[ -f "./$binary" ]]; then
            binary_path="./$binary"
        else
            # Search in common subdirectories
            for subdir in bin build target/release app; do
                if [[ -f "$subdir/$binary" ]]; then
                    binary_path="$subdir/$binary"
                    break
                fi
            done
        fi
        
        if [[ -z "$binary_path" ]]; then
            log_error "Binary not found: $binary"
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
    
    # Try common version flags
    local version_output=""
    for flag in "-V" "--version" "version"; do
        if version_output=$("$BINARY_DIR/$binary_name" $flag 2>/dev/null); then
            break
        fi
    done
    
    if [[ -n "$version_output" ]]; then
        log_info "$binary_name version: $version_output"
        
        # Check if expected version is in the output
        if [[ "$version_output" =~ $expected_version ]]; then
            log_success "Version verification passed for $binary_name"
            return 0
        else
            log_warn "Version mismatch for $binary_name. Expected: $expected_version, Got: $version_output"
            return 1
        fi
    else
        log_warn "Could not determine version for $binary_name"
        return 1
    fi
}

# Rollback function
rollback() {
    local backup_file="/tmp/last_backup_${PROJECT_NAME}"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "No backup information found for rollback"
        exit 1
    fi
    
    local backup_path=$(cat "$backup_file")
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        exit 1
    fi
    
    log_warn "Rolling back to backup: $backup_path"
    
    # Stop service
    stop_service
    
    # Restore binaries
    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    for binary in "${BINARIES[@]}"; do
        binary=$(echo "$binary" | xargs)
        if [[ -f "$backup_path/$binary" ]]; then
            sudo cp "$backup_path/$binary" "$BINARY_DIR/"
            log_info "Restored: $binary"
        fi
    done
    
    # Start service
    start_service
    
    log_success "Rollback completed"
}

# Main upgrade function
main_upgrade() {
    local version="$VERSION"
    local download_url="$DOWNLOAD_URL"
    
    # If version is provided but no download URL, construct it from template
    if [[ -n "$version" && -z "$download_url" && -n "$DOWNLOAD_URL_TEMPLATE" ]]; then
        download_url="${DOWNLOAD_URL_TEMPLATE//\{VERSION\}/$version}"
        download_url="${download_url//\{PLATFORM\}/$PLATFORM}"
    fi
    
    log_info "Starting upgrade for $PROJECT_NAME"
    log_info "Upgrade method: $UPGRADE_METHOD"
    log_info "Version: ${version:-'latest'}"
    
    # Create backup
    backup_binaries
    
    # Stop service
    stop_service
    
    local source_dir=""
    
    if [[ "$UPGRADE_METHOD" == "download" ]]; then
        if [[ -z "$download_url" ]]; then
            log_error "No download URL provided or configured"
            exit 1
        fi
        
        download_binary "$version" "$download_url"
        source_dir="$DOWNLOAD_DIR/$version"
        
    elif [[ "$UPGRADE_METHOD" == "compile" ]]; then
        if [[ -z "$version" ]]; then
            log_error "Version is required for compilation method"
            exit 1
        fi
        
        compile_binary "$version"
        
        if [[ -n "$COMPILED_BINARY_PATH" ]]; then
            source_dir="$GIT_REPO_DIR/$COMPILED_BINARY_PATH"
        else
            source_dir="$GIT_REPO_DIR"
        fi
    else
        log_error "Invalid upgrade method: $UPGRADE_METHOD (should be 'download' or 'compile')"
        exit 1
    fi
    
    # Install binaries
    install_binaries "$source_dir"
    
    # Verify installation
    IFS=',' read -ra BINARIES <<< "$BINARY_NAMES"
    local main_binary="${BINARIES[0]}"
    main_binary=$(echo "$main_binary" | xargs)
    
    if ! verify_binary "$main_binary" "$version"; then
        log_error "Binary verification failed"
        log_warn "Consider running rollback if needed"
        exit 1
    fi
    
    # Start service
    if ! start_service; then
        log_error "Failed to start service, consider rollback"
        exit 1
    fi
    
    log_success "Upgrade completed successfully!"
    log_info "Check service status with: systemctl status $SERVICE_NAME"
}

# Main function
main() {
    log_info "=== Blockchain Binary Upgrade Script Started ==="
    
    parse_args "$@"
    parse_config "$CONFIG_FILE"
    
    # Handle special case for rollback
    if [[ "$VERSION" == "rollback" ]]; then
        rollback
        exit 0
    fi
    
    main_upgrade
    
    log_info "=== Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
'''

# Save the script
with open('upgrade.sh', 'w') as f:
    f.write(upgrade_script)

print("✅ Created upgrade.sh script")