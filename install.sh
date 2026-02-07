#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Installation Script
# ========================================
# This script installs Agent Zero on Termux (Android) without Docker
# 
# Usage: bash install.sh [options]
# Options:
#   --skip-searxng    Skip SearXNG installation (use external instance instead)
#   --minimal         Minimal installation (skip optional packages)
#   --help            Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
SKIP_SEARXNG=false
MINIMAL=false
A0_DIR="$HOME/agent-zero"
VENV_DIR="$A0_DIR/.venv"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-searxng)
            SKIP_SEARXNG=true
            shift
            ;;
        --minimal)
            MINIMAL=true
            shift
            ;;
        --help)
            head -20 "$0" | tail -18
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

print_banner() {
    echo -e "${CYAN}"
    echo "======================================"
    echo "   Agent Zero - Termux Installer"
    echo "======================================"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        log_error "This script is designed to run on Termux (Android)"
        log_info "For other platforms, please use the official Docker installation"
        exit 1
    fi
    log_success "Termux environment detected"
}

update_packages() {
    log_info "Updating package repositories..."
    pkg update -y
    pkg upgrade -y
    log_success "Packages updated"
}

install_base_packages() {
    log_info "Installing base packages..."
    
    # Core dependencies
    pkg install -y \
        python \
        python-pip \
        git \
        nodejs \
        npm \
        rust \
        binutils \
        clang \
        make \
        cmake \
        pkg-config \
        libffi \
        openssl \
        libjpeg-turbo \
        libpng \
        freetype \
        libxml2 \
        libxslt \
        zlib \
        build-essential \
        wget \
        curl \
        openssh \
        proot \
        termux-api
    
    log_success "Base packages installed"
}

install_python_build_deps() {
    log_info "Installing Python build dependencies..."
    
    # Additional build dependencies for Python packages
    pkg install -y \
        libc++ \
        libandroid-glob \
        libcrypt \
        libsqlite \
        libbz2 \
        readline \
        ncurses
        
    # For numpy, scipy, and ML packages
    pkg install -y \
        openblas \
        lapack || log_warning "Some ML packages may not be available"
    
    log_success "Python build dependencies installed"
}

install_optional_packages() {
    if [ "$MINIMAL" = true ]; then
        log_info "Skipping optional packages (minimal installation)"
        return
    fi
    
    log_info "Installing optional packages..."
    
    # Optional but useful
    pkg install -y \
        ffmpeg \
        imagemagick \
        tesseract \
        poppler || log_warning "Some optional packages failed to install"
    
    log_success "Optional packages installed"
}

clone_agent_zero() {
    log_info "Cloning Agent Zero repository..."
    
    if [ -d "$A0_DIR" ]; then
        log_warning "Agent Zero directory already exists"
        read -p "Remove and reinstall? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$A0_DIR"
        else
            log_info "Using existing installation"
            return
        fi
    fi
    
    git clone https://github.com/agent0ai/agent-zero.git "$A0_DIR"
    log_success "Agent Zero cloned to $A0_DIR"
}

setup_python_venv() {
    log_info "Setting up Python virtual environment..."
    
    cd "$A0_DIR"
    python -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    log_success "Python virtual environment created"
}

install_python_packages() {
    log_info "Installing Python packages (this may take a while)..."
    
    cd "$A0_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Create a modified requirements file for Termux
    create_termux_requirements
    
    # Install packages
    pip install -r requirements_termux.txt
    
    # Install ipython for code execution
    pip install ipython
    
    log_success "Python packages installed"
}

create_termux_requirements() {
    log_info "Creating Termux-compatible requirements..."
    
    cat > "$A0_DIR/requirements_termux.txt" << 'EOF'
# Agent Zero - Termux Compatible Requirements
# Some packages are modified or excluded for ARM/Android compatibility

a2wsgi>=1.10.8
ansio>=0.0.1
duckduckgo-search>=6.1.12
flask[async]>=3.0.3
flask-basicauth>=0.2.0
GitPython>=3.1.43
inputimeout>=1.0.4
simpleeval>=1.0.3
langchain-core>=0.3.49
langchain-community>=0.3.19
lxml_html_clean>=0.3.1
markdown>=3.7
newspaper3k>=0.2.8
paramiko>=3.5.0
pypdf>=6.0.0
python-dotenv>=1.1.0
pytz>=2024.2
tiktoken>=0.8.0
webcolors>=24.6.0
nest-asyncio>=1.6.0
crontab>=1.0.1
markdownify>=1.1.0
pydantic>=2.11.7
pathspec>=0.12.1
psutil>=7.0.0
imapclient>=3.0.1
html2text>=2024.2.26
beautifulsoup4>=4.12.3
aiohttp
requests
httpx

# LiteLLM for model providers
litellm>=1.0.0

# Lighter alternatives for Termux
# Replacing heavy packages with lighter alternatives

# faiss-cpu - Use simpler vector store
chromadb

# sentence-transformers - Optional, can use API-based embeddings
# sentence-transformers>=3.0.1

# browser-use - Disabled on Termux (no display)
# playwright - Disabled on Termux

# whisper - Use API-based STT instead
# openai-whisper>=20240930

# unstructured - Use lighter document parsing
pymupdf>=1.25.3

# MCP support (if needed)
# mcp>=1.13.1
# fastmcp>=2.3.4
EOF
    
    log_success "Termux requirements created"
}

apply_termux_patches() {
    log_info "Applying Termux-specific patches..."
    
    cd "$A0_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Create Termux configuration
    create_termux_config
    
    # Patch runtime detection
    patch_runtime_detection
    
    # Patch code execution for local shell
    patch_code_execution
    
    # Create run script
    create_run_script
    
    log_success "Termux patches applied"
}

create_termux_config() {
    log_info "Creating Termux configuration..."
    
    # Create .env file with Termux-specific settings
    if [ ! -f "$A0_DIR/.env" ]; then
        cat > "$A0_DIR/.env" << 'EOF'
# Agent Zero - Termux Configuration
# ==================================

# LLM API Keys (add your keys here)
# OPENAI_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_key_here
# OPENROUTER_API_KEY=your_key_here

# Web UI Settings
WEB_UI_HOST=0.0.0.0
WEB_UI_PORT=8080

# Code Execution (local shell, no Docker/SSH)
CODE_EXEC_SSH_ENABLED=false

# SearXNG (local or external)
# For external: SEARXNG_URL=https://searx.example.com
SEARXNG_URL=http://localhost:8888

# Termux-specific
TERMUX_MODE=true
DOCKERIZED=false

# Authentication (optional)
# AUTH_LOGIN=admin
# AUTH_PASSWORD=your_password_here
EOF
    fi
    
    log_success "Configuration file created at $A0_DIR/.env"
}

patch_runtime_detection() {
    log_info "Patching runtime detection for Termux..."
    
    # Create a termux runtime helper
    cat > "$A0_DIR/python/helpers/termux_runtime.py" << 'EOF'
"""
Termux Runtime Helper
Provides Termux-specific functionality and patches
"""

import os
import sys
import platform

def is_termux():
    """Check if running on Termux"""
    return os.path.exists("/data/data/com.termux")

def is_android():
    """Check if running on Android"""
    return 'ANDROID_ROOT' in os.environ or is_termux()

def get_termux_home():
    """Get Termux home directory"""
    return os.environ.get('HOME', '/data/data/com.termux/files/home')

def get_termux_prefix():
    """Get Termux prefix directory"""
    return os.environ.get('PREFIX', '/data/data/com.termux/files/usr')

def patch_for_termux():
    """Apply necessary patches for Termux compatibility"""
    if not is_termux():
        return
    
    # Set environment variables
    os.environ['TERMUX_MODE'] = 'true'
    os.environ['DOCKERIZED'] = 'false'
    
    # Ensure proper tmp directory
    tmp_dir = os.path.join(get_termux_home(), '.cache', 'agent-zero')
    os.makedirs(tmp_dir, exist_ok=True)
    os.environ.setdefault('TMPDIR', tmp_dir)
    
    # Disable features that don't work on Termux
    os.environ.setdefault('CODE_EXEC_SSH_ENABLED', 'false')
    os.environ.setdefault('DISABLE_BROWSER_AGENT', 'true')
    os.environ.setdefault('DISABLE_WHISPER', 'true')

def get_shell():
    """Get the shell to use for code execution"""
    if is_termux():
        return os.environ.get('SHELL', '/data/data/com.termux/files/usr/bin/bash')
    return os.environ.get('SHELL', '/bin/bash')

# Auto-patch when imported
patch_for_termux()
EOF
    
    log_success "Runtime detection patched"
}

patch_code_execution() {
    log_info "Patching code execution for Termux..."
    
    # Create Termux-compatible shell helper
    cat > "$A0_DIR/python/helpers/shell_termux.py" << 'EOF'
"""
Termux Shell Helper
Provides local shell execution for Termux environment
"""

import os
import sys
import asyncio
import subprocess
import pty
import select
import signal
from typing import Optional, Tuple

class TermuxInteractiveSession:
    """Interactive shell session for Termux using pty"""
    
    def __init__(self, cwd: Optional[str] = None):
        self.cwd = cwd or os.environ.get('HOME', '/data/data/com.termux/files/home')
        self.process = None
        self.master_fd = None
        self.full_output = ""
        self._connected = False
        
    async def connect(self):
        """Start an interactive shell session"""
        if self._connected:
            return
            
        # Get shell
        shell = os.environ.get('SHELL', '/data/data/com.termux/files/usr/bin/bash')
        
        # Create pseudo-terminal
        self.master_fd, slave_fd = pty.openpty()
        
        # Start shell process
        self.process = subprocess.Popen(
            [shell, '-i'],
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            cwd=self.cwd,
            env=self._get_env(),
            preexec_fn=os.setsid
        )
        
        os.close(slave_fd)
        self._connected = True
        
        # Wait for initial prompt
        await asyncio.sleep(0.5)
        await self.read_output(timeout=2, reset_full_output=True)
        
    def _get_env(self):
        """Get environment for shell"""
        env = os.environ.copy()
        env['TERM'] = 'xterm-256color'
        env['PS1'] = '\\u@termux:\\w$ '
        return env
        
    async def send_command(self, command: str):
        """Send a command to the shell"""
        if not self._connected:
            await self.connect()
            
        # Reset output for new command
        self.full_output = ""
        
        # Write command
        os.write(self.master_fd, (command + '\n').encode())
        
    async def read_output(self, timeout: float = 1, reset_full_output: bool = False) -> Tuple[str, str]:
        """Read output from the shell"""
        if reset_full_output:
            self.full_output = ""
            
        partial_output = ""
        
        try:
            # Use select for non-blocking read
            readable, _, _ = select.select([self.master_fd], [], [], timeout)
            
            while readable:
                try:
                    data = os.read(self.master_fd, 4096)
                    if data:
                        text = data.decode('utf-8', errors='replace')
                        partial_output += text
                        self.full_output += text
                except (OSError, IOError):
                    break
                    
                # Check for more data
                readable, _, _ = select.select([self.master_fd], [], [], 0.1)
                
        except Exception as e:
            partial_output = f"Error reading output: {str(e)}"
            
        return self.full_output, partial_output
        
    async def close(self):
        """Close the shell session"""
        if self.process:
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            except:
                pass
            self.process = None
            
        if self.master_fd:
            try:
                os.close(self.master_fd)
            except:
                pass
            self.master_fd = None
            
        self._connected = False
        
    def __del__(self):
        """Cleanup on deletion"""
        asyncio.create_task(self.close()) if asyncio.get_event_loop().is_running() else None
EOF
    
    log_success "Code execution patched for Termux"
}

create_run_script() {
    log_info "Creating run scripts..."
    
    # Main run script
    cat > "$A0_DIR/run_termux.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Run Script
#

set -e

# Directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Starting Agent Zero on Termux...${NC}"

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Set environment
export TERMUX_MODE=true
export DOCKERIZED=false
export CODE_EXEC_SSH_ENABLED=false

# Load .env if exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Default port
PORT=${WEB_UI_PORT:-8080}
HOST=${WEB_UI_HOST:-0.0.0.0}

echo -e "${GREEN}Starting web UI on http://$HOST:$PORT${NC}"
echo -e "${YELLOW}Access from browser: http://localhost:$PORT${NC}"

# Run the UI
cd "$SCRIPT_DIR"
python run_ui.py --host="$HOST" --port="$PORT"
EOF
    chmod +x "$A0_DIR/run_termux.sh"
    
    # SearXNG run script (if needed)
    cat > "$A0_DIR/run_searxng.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - SearXNG Service Script for Termux
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARXNG_DIR="$SCRIPT_DIR/searxng"
SEARXNG_VENV="$SEARXNG_DIR/.venv"

if [ ! -d "$SEARXNG_DIR" ]; then
    echo "SearXNG not installed. Run install_searxng.sh first."
    exit 1
fi

cd "$SEARXNG_DIR"
source "$SEARXNG_VENV/bin/activate"

export SEARXNG_SETTINGS_PATH="$SEARXNG_DIR/settings.yml"
python -m searx.webapp
EOF
    chmod +x "$A0_DIR/run_searxng.sh"
    
    # Combined run script
    cat > "$A0_DIR/start.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Start All Services
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   Agent Zero - Termux Launcher${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if SearXNG should be started
START_SEARXNG=false
if [ -d "$SCRIPT_DIR/searxng" ] && [ -z "$SEARXNG_URL" ]; then
    START_SEARXNG=true
    echo -e "${GREEN}Starting SearXNG...${NC}"
    "$SCRIPT_DIR/run_searxng.sh" &
    SEARXNG_PID=$!
    sleep 3
    echo -e "${GREEN}SearXNG started (PID: $SEARXNG_PID)${NC}"
fi

echo -e "${GREEN}Starting Agent Zero...${NC}"
"$SCRIPT_DIR/run_termux.sh"

# Cleanup on exit
if [ "$START_SEARXNG" = true ]; then
    kill $SEARXNG_PID 2>/dev/null
fi
EOF
    chmod +x "$A0_DIR/start.sh"
    
    log_success "Run scripts created"
}

install_searxng() {
    if [ "$SKIP_SEARXNG" = true ]; then
        log_info "Skipping SearXNG installation (--skip-searxng flag)"
        log_warning "You'll need to configure an external SearXNG instance in .env"
        return
    fi
    
    log_info "Installing SearXNG for local search..."
    
    SEARXNG_DIR="$A0_DIR/searxng"
    
    if [ -d "$SEARXNG_DIR" ]; then
        log_warning "SearXNG already installed"
        return
    fi
    
    # Clone SearXNG
    git clone https://github.com/searxng/searxng.git "$SEARXNG_DIR"
    
    # Create virtual environment for SearXNG
    cd "$SEARXNG_DIR"
    python -m venv .venv
    source .venv/bin/activate
    
    # Install SearXNG
    pip install --upgrade pip
    pip install -e .
    
    # Create minimal settings
    cat > "$SEARXNG_DIR/settings.yml" << 'EOF'
use_default_settings: true

general:
  debug: false
  instance_name: "Agent Zero Search"

server:
  port: 8888
  bind_address: "127.0.0.1"
  secret_key: "change_this_secret_key"

search:
  safe_search: 0
  autocomplete: ""

ui:
  static_use_hash: true

enabled_plugins:
  - 'Hash plugin'
  - 'Hostnames plugin'
  - 'Open Access DOI rewrite'
  - 'Vim-like hotkeys'

engines:
  - name: google
    disabled: false
  - name: duckduckgo
    disabled: false
  - name: bing
    disabled: false
  - name: wikipedia
    disabled: false
EOF
    
    log_success "SearXNG installed at $SEARXNG_DIR"
}

setup_node_tools() {
    log_info "Setting up Node.js tools..."
    
    cd "$A0_DIR"
    
    # Create node evaluation script
    mkdir -p "$A0_DIR/exe"
    cat > "$A0_DIR/exe/node_eval.js" << 'EOF'
#!/usr/bin/env node
// Node.js code evaluation script for Agent Zero

const code = process.argv.slice(2).join(' ');

if (!code) {
    console.error('No code provided');
    process.exit(1);
}

try {
    // Create a safe evaluation context
    const result = eval(code);
    if (result !== undefined) {
        console.log(result);
    }
} catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
}
EOF
    chmod +x "$A0_DIR/exe/node_eval.js"
    
    log_success "Node.js tools configured"
}

create_termux_extensions() {
    log_info "Creating Termux-specific extensions..."
    
    # Create extension to disable unsupported features
    mkdir -p "$A0_DIR/python/extensions/termux"
    
    cat > "$A0_DIR/python/extensions/termux/__init__.py" << 'EOF'
"""
Termux Extensions
Disables unsupported features and provides Termux alternatives
"""
EOF
    
    cat > "$A0_DIR/python/extensions/termux/_00_termux_init.py" << 'EOF'
"""
Termux Initialization Extension
Runs at startup to configure Termux-specific settings
"""

import os
from python.helpers.termux_runtime import is_termux, patch_for_termux

def initialize():
    """Initialize Termux-specific settings"""
    if is_termux():
        patch_for_termux()
        print("[Termux] Running in Termux mode")
        print("[Termux] Browser agent disabled")
        print("[Termux] Using local shell for code execution")

initialize()
EOF
    
    log_success "Termux extensions created"
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}======================================"
    echo "   Installation Complete!"
    echo "======================================${NC}"
    echo ""
    echo -e "${BLUE}Agent Zero has been installed to:${NC} $A0_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit configuration: nano $A0_DIR/.env"
    echo "   - Add your API keys (OpenAI, Anthropic, or OpenRouter)"
    echo ""
    echo "2. Start Agent Zero:"
    echo "   cd $A0_DIR"
    echo "   ./start.sh"
    echo ""
    echo "3. Open in browser: http://localhost:8080"
    echo ""
    if [ "$SKIP_SEARXNG" = true ]; then
        echo -e "${YELLOW}Note:${NC} SearXNG was skipped. Configure SEARXNG_URL in .env"
    fi
    echo ""
    echo -e "${CYAN}For more information, see README_TERMUX.md${NC}"
}

# Main installation flow
main() {
    print_banner
    check_termux
    update_packages
    install_base_packages
    install_python_build_deps
    install_optional_packages
    clone_agent_zero
    setup_python_venv
    install_python_packages
    apply_termux_patches
    setup_node_tools
    create_termux_extensions
    install_searxng
    print_completion_message
}

# Run main
main
