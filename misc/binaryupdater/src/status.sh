#!/bin/bash

# Blockchain Status Checker
# Shows status of configured blockchain services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Blockchain Services Status ===${NC}\n"

# Find all .conf files
for config_file in "$SCRIPT_DIR"/*.conf; do
    if [[ -f "$config_file" && ! "$config_file" =~ template\.conf$ ]]; then
        # Extract project name and service name
        project_name=$(grep "^project_name:" "$config_file" | sed 's/project_name: *//' | tr -d '"'"'"'')
        service_name=$(grep "^service_name:" "$config_file" | sed 's/service_name: *//' | tr -d '"'"'"'')
        binary_names=$(grep "^binary_names:" "$config_file" | sed 's/binary_names: *//' | tr -d '"'"'"'')
        binary_dir=$(grep "^binary_dir:" "$config_file" | sed 's/binary_dir: *//' | tr -d '"'"'"'')

        if [[ -n "$project_name" ]]; then
            echo -e "${YELLOW}[$project_name]${NC}"

            # Check service status
            if [[ -n "$service_name" ]]; then
                if systemctl is-active --quiet "$service_name"; then
                    echo -e "  Service: ${GREEN}●${NC} $service_name (running)"
                else
                    echo -e "  Service: ${RED}●${NC} $service_name (stopped)"
                fi
            else
                echo -e "  Service: ${YELLOW}●${NC} No service configured"
            fi

            # Check binary versions
            IFS=',' read -ra BINARIES <<< "$binary_names"
            main_binary="${BINARIES[0]}"
            main_binary=$(echo "$main_binary" | xargs)

            if [[ -f "$binary_dir/$main_binary" ]]; then
                echo -e "  Binary: ${GREEN}✓${NC} $main_binary installed"

                # Try to get version
                for flag in "-V" "--version" "version"; do
                    if version_output=$("$binary_dir/$main_binary" $flag 2>/dev/null); then
                        echo -e "  Version: $version_output"
                        break
                    fi
                done
            else
                echo -e "  Binary: ${RED}✗${NC} $main_binary not found"
            fi

            echo
        fi
    fi
done

echo -e "${BLUE}=== Quick Commands ===${NC}"
echo "Check specific service: systemctl status SERVICE_NAME"
echo "View service logs: journalctl -u SERVICE_NAME -f"
echo "Restart service: sudo systemctl restart SERVICE_NAME"
