#!/bin/bash

# GitHub Release Management Script for LAMP/LEMP Installer
# This script helps manage versions and creates GitHub releases

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get current version
CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  LAMP/LEMP Installer - Release Management     ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "Current version: ${YELLOW}v$CURRENT_VERSION${NC}"
echo ""

# Function to validate version format
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must be in format X.Y.Z (e.g., 2.1.0)${NC}"
        return 1
    fi
    return 0
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi
}

# Function to check if working directory is clean
check_clean_working_dir() {
    if ! git diff-index --quiet HEAD --; then
        echo -e "${RED}Error: Working directory has uncommitted changes${NC}"
        echo "Please commit or stash your changes before creating a release."
        exit 1
    fi
}

# Function to create and push tag
create_tag() {
    local version=$1
    local message=$2
    
    echo -e "${BLUE}Creating tag v$version...${NC}"
    
    # Update VERSION file
    echo "$version" > VERSION
    
    # Update version in main script
    sed -i "s/# Version: .*/# Version: $version/" install-lamp.sh
    
    # Commit version changes
    git add VERSION install-lamp.sh
    git commit -m "Bump version to $version" || true
    
    # Create annotated tag
    git tag -a "v$version" -m "$message"
    
    # Push changes and tag
    git push origin main
    git push origin "v$version"
    
    echo -e "${GREEN}✅ Tag v$version created and pushed successfully!${NC}"
}

# Function to list existing tags
list_tags() {
    echo -e "${BLUE}Existing tags:${NC}"
    git tag -l --sort=-version:refname | head -10
    echo ""
}

# Function to generate release notes
generate_release_notes() {
    local version=$1
    local previous_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    
    echo "## Release v$version"
    echo ""
    echo "### Changes"
    
    if [ -n "$previous_tag" ]; then
        echo ""
        echo "**Commits since $previous_tag:**"
        git log --oneline --no-merges "$previous_tag"..HEAD | sed 's/^/- /'
    else
        echo "- Initial release"
    fi
    
    echo ""
    echo "### Installation"
    echo ""
    echo "**Single-file installation (Recommended):**"
    echo '```bash'
    echo "wget --no-check-certificate -O /tmp/install-lamp.sh https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/v$version/install-lamp.sh"
    echo "chmod +x /tmp/install-lamp.sh"
    echo "sudo /tmp/install-lamp.sh"
    echo '```'
    echo ""
    echo "**Bootstrap installation (Full features):**"
    echo '```bash'
    echo "sudo bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/v$version/bootstrap.sh)"
    echo '```'
}

# Main menu
show_menu() {
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1) Create a new release tag"
    echo "2) List existing tags"
    echo "3) Generate release notes for current version"
    echo "4) Prepare for GitHub release"
    echo "5) Exit"
    echo ""
}

# Main execution
main() {
    check_git_repo
    
    while true; do
        show_menu
        read -p "Enter your choice [1-5]: " choice
        
        case $choice in
            1)
                echo ""
                read -p "Enter new version (current: $CURRENT_VERSION): " new_version
                
                if validate_version "$new_version"; then
                    check_clean_working_dir
                    
                    read -p "Enter release message: " release_message
                    create_tag "$new_version" "$release_message"
                    CURRENT_VERSION=$new_version
                fi
                echo ""
                ;;
                
            2)
                echo ""
                list_tags
                ;;
                
            3)
                echo ""
                echo -e "${BLUE}Release notes for v$CURRENT_VERSION:${NC}"
                echo "=================================="
                generate_release_notes "$CURRENT_VERSION"
                echo ""
                ;;
                
            4)
                echo ""
                echo -e "${BLUE}Preparing GitHub release package...${NC}"
                
                # Create release directory
                RELEASE_DIR="release-v$CURRENT_VERSION"
                mkdir -p "$RELEASE_DIR"
                
                # Copy essential files
                cp install-lamp.sh bootstrap.sh README.md LICENSE CHANGELOG.md VERSION "$RELEASE_DIR/"
                
                # Create archive
                tar -czf "lamp-lemp-installer-v$CURRENT_VERSION.tar.gz" "$RELEASE_DIR"
                zip -r "lamp-lemp-installer-v$CURRENT_VERSION.zip" "$RELEASE_DIR"
                
                # Generate release notes
                generate_release_notes "$CURRENT_VERSION" > "$RELEASE_DIR/RELEASE_NOTES.md"
                
                echo -e "${GREEN}✅ Release package created:${NC}"
                echo "  - Directory: $RELEASE_DIR/"
                echo "  - Archive: lamp-lemp-installer-v$CURRENT_VERSION.tar.gz"
                echo "  - Archive: lamp-lemp-installer-v$CURRENT_VERSION.zip"
                echo "  - Release notes: $RELEASE_DIR/RELEASE_NOTES.md"
                echo ""
                echo -e "${YELLOW}Next steps:${NC}"
                echo "1. Go to GitHub and create a new release"
                echo "2. Upload the archives as release assets"
                echo "3. Copy the release notes to the GitHub release description"
                echo ""
                ;;
                
            5)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
                
            *)
                echo -e "${RED}Invalid choice. Please enter 1-5.${NC}"
                echo ""
                ;;
        esac
    done
}

# Run main function
main "$@"
