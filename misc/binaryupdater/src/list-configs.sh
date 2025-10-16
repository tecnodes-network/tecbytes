#!/bin/bash

# Configuration Lister and Validator
# Lists all available configurations and validates them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

validate_config() {
    local config_file="$1"
    local errors=0

    # Required fields
    local required_fields=("project_name" "download_dir" "binary_dir" "binary_names" "upgrade_method")

    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$config_file"; then
            echo -e "    ${RED}✗${NC} Missing required field: $field"
            ((errors++))
        fi
    done

    # Check upgrade method specific fields
    local upgrade_method=$(grep "^upgrade_method:" "$config_file" | sed 's/upgrade_method: *//' | tr -d '"'"'"'')

    if [[ "$upgrade_method" == "download" ]]; then
        if ! grep -q "^download_url_template:" "$config_file"; then
            echo -e "    ${RED}✗${NC} Missing download_url_template for download method"
            ((errors++))
        fi
    elif [[ "$upgrade_method" == "compile" ]]; then
        local compile_fields=("git_repo_dir" "build_command")
        for field in "${compile_fields[@]}"; do
            if ! grep -q "^$field:" "$config_file"; then
                echo -e "    ${RED}✗${NC} Missing required field for compile method: $field"
                ((errors++))
            fi
        done
    fi

    # Check if directories exist (expand ~ to home)
    local download_dir=$(grep "^download_dir:" "$config_file" | sed 's/download_dir: *//' | tr -d '"'"'"'' | sed "s|^~|$HOME|")
    local git_repo_dir=$(grep "^git_repo_dir:" "$config_file" | sed 's/git_repo_dir: *//' | tr -d '"'"'"'' | sed "s|^~|$HOME|")

    if [[ -n "$download_dir" && ! -d "$download_dir" ]]; then
        echo -e "    ${YELLOW}⚠${NC} Download directory does not exist: $download_dir"
    fi

    if [[ -n "$git_repo_dir" && ! -d "$git_repo_dir" ]]; then
        echo -e "    ${YELLOW}⚠${NC} Git repository directory does not exist: $git_repo_dir"
    fi

    if [[ $errors -eq 0 ]]; then
        echo -e "    ${GREEN}✓${NC} Configuration is valid"
    else
        echo -e "    ${RED}✗${NC} Configuration has $errors error(s)"
    fi

    return $errors
}

echo -e "${BLUE}=== Available Configurations ===${NC}\n"

total_configs=0
valid_configs=0

# Find all .conf files
for config_file in "$SCRIPT_DIR"/*.conf; do
    if [[ -f "$config_file" ]]; then
        ((total_configs++))

        filename=$(basename "$config_file")

        # Extract basic info
        project_name=$(grep "^project_name:" "$config_file" | sed 's/project_name: *//' | tr -d '"'"'"'')
        upgrade_method=$(grep "^upgrade_method:" "$config_file" | sed 's/upgrade_method: *//' | tr -d '"'"'"'')
        service_name=$(grep "^service_name:" "$config_file" | sed 's/service_name: *//' | tr -d '"'"'"'')

        echo -e "${YELLOW}$filename${NC}"
        echo "  Project: ${project_name:-'Not specified'}"
        echo "  Method: ${upgrade_method:-'Not specified'}"
        echo "  Service: ${service_name:-'None'}"

        # Validate configuration
        if validate_config "$config_file"; then
            ((valid_configs++))
        fi

        # Show usage example
        if [[ "$filename" != "template.conf" ]]; then
            echo -e "  ${BLUE}Usage:${NC} ./upgrade.sh --config $filename --version VERSION"
        fi

        echo
    fi
done

echo -e "${BLUE}=== Summary ===${NC}"
echo "Total configurations: $total_configs"
echo "Valid configurations: $valid_configs"

if [[ $valid_configs -lt $total_configs ]]; then
    echo -e "${YELLOW}Some configurations need attention. Fix errors before using.${NC}"
fi
