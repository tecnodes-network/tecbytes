#!/bin/bash

# Debug version - let's see where it's failing
set -euo pipefail
set -x  # Enable debug mode to see each command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.blockchain_upgrade_logs"
BACKUP_DIR="$HOME/.blockchain_backups"
CONFIG_FILE=""
VERSION=""
DOWNLOAD_URL=""
DRY_RUN=false

echo "DEBUG: Script started"
echo "DEBUG: Arguments received: $*"

# Create necessary directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Simple logging for debugging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}"
}

log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }

echo "DEBUG: Functions defined"

# Parse command line arguments
parse_args() {
    echo "DEBUG: Parsing arguments..."
    while [[ $# -gt 0 ]]; do
        echo "DEBUG: Processing argument: $1"
        case $1 in
            --config)
                CONFIG_FILE="$2"
                echo "DEBUG: Config file set to: $CONFIG_FILE"
                shift 2
                ;;
            --version)
                VERSION="$2"
                echo "DEBUG: Version set to: $VERSION"
                shift 2
                ;;
            --url)
                DOWNLOAD_URL="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                echo "DEBUG: Dry run enabled"
                shift
                ;;
            --help)
                echo "Help would be shown here"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo "DEBUG: Finished parsing arguments"
    echo "DEBUG: CONFIG_FILE=$CONFIG_FILE"
    echo "DEBUG: VERSION=$VERSION"
    echo "DEBUG: DRY_RUN=$DRY_RUN"

    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "Config file is required"
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    echo "DEBUG: Config file exists: $CONFIG_FILE"
}

# Simple config parser test
parse_config() {
    local config_file="$1"
    echo "DEBUG: Starting to parse config file: $config_file"

    echo "DEBUG: Config file contents:"
    cat "$config_file"
    echo "DEBUG: End of config file"

    # Test each grep command
    echo "DEBUG: Testing project_name extraction..."
    PROJECT_NAME=$(grep "^project_name:" "$config_file" | sed 's/project_name: *//' | tr -d '"'"'"'') || {
        echo "DEBUG: Failed to extract project_name"
        return 1
    }
    echo "DEBUG: PROJECT_NAME=$PROJECT_NAME"

    echo "DEBUG: Testing download_dir extraction..."
    DOWNLOAD_DIR=$(grep "^download_dir:" "$config_file" | sed 's/download_dir: *//' | tr -d '"'"'"'') || {
        echo "DEBUG: Failed to extract download_dir"
        return 1
    }
    echo "DEBUG: DOWNLOAD_DIR=$DOWNLOAD_DIR"

    echo "DEBUG: Config parsing completed successfully"
}

echo "DEBUG: About to call main"

# Main function
main() {
    log_info "=== Blockchain Binary Upgrade Script Started ==="

    echo "DEBUG: Calling parse_args"
    parse_args "$@"

    echo "DEBUG: Calling parse_config"
    parse_config "$CONFIG_FILE"

    echo "DEBUG: Main function completed"
}

echo "DEBUG: Calling main with arguments: $*"
main "$@"
echo "DEBUG: Script finished"
