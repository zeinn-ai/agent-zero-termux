#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Dependency Checker
# ======================================
# Checks if all required dependencies are installed
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Agent Zero - Dependency Checker${NC}"
echo "================================"
echo ""

check_command() {
    local name="$1"
    local cmd="$2"
    local required="$3"
    
    if command -v "$cmd" &> /dev/null; then
        version=$($cmd --version 2>&1 | head -1)
        echo -e "${GREEN}[OK]${NC} $name: $version"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}[MISSING]${NC} $name - REQUIRED"
        else
            echo -e "${YELLOW}[MISSING]${NC} $name - optional"
        fi
        return 1
    fi
}

echo -e "${YELLOW}Core Dependencies:${NC}"
echo ""

# Check core dependencies
core_ok=true
check_command "Python" "python" "required" || core_ok=false
check_command "pip" "pip" "required" || core_ok=false
check_command "Node.js" "node" "required" || core_ok=false
check_command "npm" "npm" "required" || core_ok=false
check_command "Git" "git" "required" || core_ok=false
check_command "Bash" "bash" "required" || core_ok=false

echo ""
echo -e "${YELLOW}Python Environment:${NC}"
echo ""

# Check Python packages
check_python_package() {
    local name="$1"
    local required="$2"
    
    if python -c "import $name" 2>/dev/null; then
        version=$(python -c "import $name; print(getattr($name, '__version__', 'installed'))" 2>/dev/null)
        echo -e "${GREEN}[OK]${NC} $name: $version"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}[MISSING]${NC} $name - REQUIRED"
        else
            echo -e "${YELLOW}[MISSING]${NC} $name - optional"
        fi
        return 1
    fi
}

check_python_package "flask" "required"
check_python_package "langchain_core" "required"
check_python_package "litellm" "required"
check_python_package "chromadb" "optional"
check_python_package "paramiko" "optional"
check_python_package "IPython" "required"

echo ""
echo -e "${YELLOW}Optional Dependencies:${NC}"
echo ""

check_command "IPython" "ipython" "required"
check_command "FFmpeg" "ffmpeg" "optional"
check_command "ImageMagick" "convert" "optional"
check_command "Tesseract OCR" "tesseract" "optional"
check_command "curl" "curl" "optional"
check_command "wget" "wget" "optional"

echo ""
echo -e "${YELLOW}System Information:${NC}"
echo ""

echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo "Termux: $([ -d /data/data/com.termux ] && echo 'Yes' || echo 'No')"
echo "Storage: $(df -h $HOME | tail -1 | awk '{print $4}') free"
echo "Memory: $(free -h | grep Mem | awk '{print $4}') available"

echo ""
if [ "$core_ok" = true ]; then
    echo -e "${GREEN}All core dependencies are installed!${NC}"
    echo "Agent Zero should run correctly."
else
    echo -e "${RED}Some required dependencies are missing.${NC}"
    echo "Install them with: pkg install <package-name>"
fi
echo ""
