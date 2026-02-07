#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Uninstaller
# ================================
# Removes Agent Zero and optionally cleans up all data
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

A0_DIR="${1:-$HOME/agent-zero}"

echo -e "${YELLOW}Agent Zero - Termux Uninstaller${NC}"
echo ""

if [ ! -d "$A0_DIR" ]; then
    echo -e "${RED}Agent Zero not found at $A0_DIR${NC}"
    exit 1
fi

echo "This will remove Agent Zero from your device."
echo ""
echo "Options:"
echo "  1) Remove Agent Zero but keep memory/knowledge data"
echo "  2) Complete removal (delete everything)"
echo "  3) Cancel"
echo ""

read -p "Choose option (1/2/3): " -n 1 -r
echo

case $REPLY in
    1)
        echo -e "${BLUE}Removing Agent Zero (keeping data)...${NC}"
        
        # Backup data
        BACKUP_DIR="$HOME/agent-zero-data-backup-$(date +%Y%m%d)"
        mkdir -p "$BACKUP_DIR"
        
        # Copy important directories
        for dir in memory knowledge instruments tmp/chats; do
            if [ -d "$A0_DIR/$dir" ]; then
                cp -r "$A0_DIR/$dir" "$BACKUP_DIR/"
                echo "Backed up: $dir"
            fi
        done
        
        # Copy .env
        if [ -f "$A0_DIR/.env" ]; then
            cp "$A0_DIR/.env" "$BACKUP_DIR/"
            echo "Backed up: .env"
        fi
        
        # Remove agent-zero
        rm -rf "$A0_DIR"
        
        echo -e "${GREEN}Agent Zero removed.${NC}"
        echo -e "Data backed up to: $BACKUP_DIR"
        ;;
    2)
        echo -e "${RED}WARNING: This will delete ALL Agent Zero data!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        
        if [ "$confirm" = "yes" ]; then
            rm -rf "$A0_DIR"
            rm -rf "$HOME/agent-zero-termux"
            rm -rf "$HOME/.cache/agent-zero"
            echo -e "${GREEN}Agent Zero completely removed.${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    *)
        echo "Cancelled."
        ;;
esac
