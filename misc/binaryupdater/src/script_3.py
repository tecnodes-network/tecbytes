# Create utility scripts

# Script to check status of blockchain services
status_script = '''#!/bin/bash

# Blockchain Status Checker
# Shows status of configured blockchain services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

echo -e "${BLUE}=== Blockchain Services Status ===${NC}\\n"

# Find all .conf files
for config_file in "$SCRIPT_DIR"/*.conf; do
    if [[ -f "$config_file" && ! "$config_file" =~ template\\.conf$ ]]; then
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
'''

# Script to list and validate configurations
list_configs_script = '''#!/bin/bash

# Configuration Lister and Validator
# Lists all available configurations and validates them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

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

echo -e "${BLUE}=== Available Configurations ===${NC}\\n"

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
'''

# Create a setup script for first-time users
setup_script = '''#!/bin/bash

# First-time Setup Script
# Creates necessary directories and sets permissions

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

echo -e "${BLUE}=== Blockchain Upgrade Script Setup ===${NC}\\n"

# Create necessary directories
echo "Creating directories..."

directories=(
    "$HOME/.blockchain_upgrade_logs"
    "$HOME/.blockchain_backups"
)

for dir in "${directories[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo -e "  ${GREEN}✓${NC} Created: $dir"
    else
        echo -e "  ${YELLOW}✓${NC} Already exists: $dir"
    fi
done

# Make scripts executable
echo -e "\\nSetting script permissions..."

scripts=(
    "upgrade.sh"
    "status.sh"
    "list-configs.sh"
    "setup.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        echo -e "  ${GREEN}✓${NC} Made executable: $script"
    fi
done

# Check sudo access
echo -e "\\nChecking system requirements..."

if sudo -n true 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Sudo access available"
else
    echo -e "  ${YELLOW}⚠${NC} Sudo access required for binary installation"
    echo "    You may be prompted for password during upgrades"
fi

# Check for required tools
required_tools=("wget" "tar" "git" "systemctl")
missing_tools=()

for tool in "${required_tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $tool available"
    else
        echo -e "  ${RED}✗${NC} $tool not found"
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo -e "\\n${YELLOW}Please install missing tools:${NC}"
    echo "  sudo apt update && sudo apt install ${missing_tools[*]}"
fi

echo -e "\\n${BLUE}=== Next Steps ===${NC}"
echo "1. Review and customize configuration files:"
echo "   ./list-configs.sh"
echo ""
echo "2. Test with dry run:"
echo "   ./upgrade.sh --config sui.conf --version v1.58.3 --dry-run"
echo ""
echo "3. Check service status:"
echo "   ./status.sh"
echo ""
echo "4. Perform actual upgrade:"
echo "   ./upgrade.sh --config sui.conf --version v1.58.3"

echo -e "\\n${GREEN}Setup completed!${NC}"
'''

# Save utility scripts
scripts = {
    'status.sh': status_script,
    'list-configs.sh': list_configs_script,
    'setup.sh': setup_script
}

for filename, content in scripts.items():
    with open(filename, 'w') as f:
        f.write(content)

print("✅ Created utility scripts:")
for filename in scripts.keys():
    print(f"   - {filename}")

# Make all scripts executable
import os
import stat

script_files = ['upgrade.sh', 'status.sh', 'list-configs.sh', 'setup.sh']
for script in script_files:
    if os.path.exists(script):
        # Add execute permission for owner
        current_permissions = os.stat(script).st_mode
        os.chmod(script, current_permissions | stat.S_IXUSR)

print("✅ Made all scripts executable")