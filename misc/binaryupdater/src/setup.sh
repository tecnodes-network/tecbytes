#!/bin/bash

# First-time Setup Script
# Creates necessary directories and sets permissions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Blockchain Upgrade Script Setup ===${NC}\n"

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
echo -e "\nSetting script permissions..."

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
echo -e "\nChecking system requirements..."

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
    echo -e "\n${YELLOW}Please install missing tools:${NC}"
    echo "  sudo apt update && sudo apt install ${missing_tools[*]}"
fi

echo -e "\n${BLUE}=== Next Steps ===${NC}"
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

echo -e "\n${GREEN}Setup completed!${NC}"
