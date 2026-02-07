#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero Termux - Quick Start Script
# ======================================
# This is a simplified installer for users who want to get started quickly.
# It downloads and runs the full installer with sensible defaults.
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║                                          ║"
echo "║   Agent Zero - Termux Quick Installer    ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running on Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}Error: This script must be run on Termux (Android)${NC}"
    echo "Please install Termux from F-Droid and run this script inside it."
    exit 1
fi

echo -e "${BLUE}This script will install Agent Zero on your device.${NC}"
echo ""
echo "Requirements:"
echo "  - About 2-4 GB of free storage"
echo "  - Good internet connection"
echo "  - ~15-30 minutes for installation"
echo ""

read -p "Continue with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Starting installation...${NC}"
echo ""

# Update packages first
echo -e "${BLUE}[1/6] Updating package repositories...${NC}"
pkg update -y
pkg upgrade -y

# Install git if not present
if ! command -v git &> /dev/null; then
    echo -e "${BLUE}[2/6] Installing git...${NC}"
    pkg install -y git
else
    echo -e "${BLUE}[2/6] Git already installed${NC}"
fi

# Clone or update the installer repo
INSTALLER_DIR="$HOME/agent-zero-termux"
if [ -d "$INSTALLER_DIR" ]; then
    echo -e "${BLUE}[3/6] Updating installer...${NC}"
    cd "$INSTALLER_DIR"
    git pull || true
else
    echo -e "${BLUE}[3/6] Downloading installer...${NC}"
    git clone https://github.com/YOUR_REPO/agent-zero-termux.git "$INSTALLER_DIR"
fi

# Run the main installer
echo -e "${BLUE}[4/6] Running main installer...${NC}"
cd "$INSTALLER_DIR"
bash install.sh --skip-searxng  # Skip SearXNG for faster install

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗"
echo "║                                          ║"
echo "║   Installation Complete!                 ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Important: Configure your API keys first!${NC}"
echo ""
echo "Run these commands:"
echo ""
echo -e "  ${CYAN}1. Edit configuration:${NC}"
echo "     nano ~/agent-zero/.env"
echo ""
echo -e "  ${CYAN}2. Add your API key (e.g., OpenAI):${NC}"
echo "     OPENAI_API_KEY=sk-your-key-here"
echo ""
echo -e "  ${CYAN}3. Start Agent Zero:${NC}"
echo "     cd ~/agent-zero && ./start.sh"
echo ""
echo -e "  ${CYAN}4. Open in browser:${NC}"
echo "     http://localhost:8080"
echo ""
echo -e "${GREEN}Enjoy using Agent Zero on your Android device!${NC}"
echo ""
