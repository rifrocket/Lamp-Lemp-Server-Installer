#!/bin/bash

# LAMP/LEMP Stack Installer Bootstrap
# This script downloads all necessary files for the complete installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base URL for the repository
BASE_URL="https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/main"

# Files to download
FILES=(
    "install-lamp.sh"
    "utils.sh"
    "config.conf"
    "post-install.sh"
)

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  LAMP/LEMP Stack Installer Bootstrap          ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
    echo "Usage: sudo bash <(curl -s $BASE_URL/bootstrap.sh)"
    exit 1
fi

# Create temporary directory
TEMP_DIR="/tmp/lamp-lemp-installer-$(date +%s)"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo -e "${BLUE}📥 Downloading installer files...${NC}"

# Download files
for file in "${FILES[@]}"; do
    echo -n "  Downloading $file... "
    if wget --no-check-certificate -q "$BASE_URL/$file" -O "$file"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Failed to download $file${NC}"
        exit 1
    fi
done

# Make scripts executable
chmod +x install-lamp.sh post-install.sh

echo ""
echo -e "${GREEN}✅ All files downloaded successfully!${NC}"
echo ""

# Ask user for installation preference
echo -e "${YELLOW}Choose installation mode:${NC}"
echo "1) Quick install (single-file, self-contained)"
echo "2) Full install (modular, with all features)"
echo "3) Just download files (no installation)"
echo ""

while true; do
    read -p "Enter your choice [1-3]: " choice
    case $choice in
        1)
            echo -e "${BLUE}🚀 Starting quick installation...${NC}"
            exec ./install-lamp.sh
            break
            ;;
        2)
            echo -e "${BLUE}🔧 Starting full installation with all features...${NC}"
            # Set environment variable to enable all features
            export LAMP_LEMP_FULL_MODE=true
            exec ./install-lamp.sh
            break
            ;;
        3)
            echo -e "${GREEN}📁 Files downloaded to: $TEMP_DIR${NC}"
            echo "You can now run the installer manually:"
            echo "  cd $TEMP_DIR"
            echo "  sudo ./install-lamp.sh"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
            ;;
    esac
done
