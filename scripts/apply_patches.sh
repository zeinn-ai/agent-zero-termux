#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Patch Script
# =================================
# This script applies patches to make Agent Zero work on Termux
# Run this after cloning the agent-zero repository
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A0_DIR="${1:-$HOME/agent-zero}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[PATCH]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[DONE]${NC} $1"
}

# Check if agent-zero exists
if [ ! -d "$A0_DIR" ]; then
    echo "Agent Zero not found at $A0_DIR"
    echo "Usage: $0 [agent-zero-directory]"
    exit 1
fi

cd "$A0_DIR"

# ============================================
# Patch 1: Create Termux runtime helper
# ============================================
log_info "Creating Termux runtime helper..."

cat > "$A0_DIR/python/helpers/termux_runtime.py" << 'TERMUX_RUNTIME_EOF'
"""
Termux Runtime Helper
Provides Termux-specific functionality and patches for Agent Zero
"""

import os
import sys
import platform
import subprocess

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

def get_shell():
    """Get the shell to use for code execution"""
    if is_termux():
        return os.environ.get('SHELL', '/data/data/com.termux/files/usr/bin/bash')
    return os.environ.get('SHELL', '/bin/bash')

def get_python():
    """Get Python executable path"""
    if is_termux():
        return os.path.join(get_termux_prefix(), 'bin', 'python')
    return sys.executable

def get_node():
    """Get Node.js executable path"""
    if is_termux():
        return os.path.join(get_termux_prefix(), 'bin', 'node')
    return 'node'

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
    os.environ.setdefault('DISABLE_KOKORO', 'true')
    
    # Fix library paths
    lib_path = os.path.join(get_termux_prefix(), 'lib')
    if 'LD_LIBRARY_PATH' in os.environ:
        os.environ['LD_LIBRARY_PATH'] = f"{lib_path}:{os.environ['LD_LIBRARY_PATH']}"
    else:
        os.environ['LD_LIBRARY_PATH'] = lib_path

def check_dependencies():
    """Check if required dependencies are installed"""
    deps = {
        'python': get_python(),
        'node': get_node(),
        'ipython': 'ipython',
        'git': 'git'
    }
    
    missing = []
    for name, cmd in deps.items():
        try:
            subprocess.run([cmd, '--version'], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            missing.append(name)
    
    return missing

# Auto-patch when imported
if is_termux():
    patch_for_termux()
TERMUX_RUNTIME_EOF

log_success "Termux runtime helper created"

# ============================================
# Patch 2: Create Termux shell session handler
# ============================================
log_info "Creating Termux shell session handler..."

cat > "$A0_DIR/python/helpers/shell_termux.py" << 'SHELL_TERMUX_EOF'
"""
Termux Shell Helper
Provides local shell execution for Termux environment using PTY
"""

import os
import sys
import asyncio
import subprocess
import pty
import select
import signal
import fcntl
import termios
import struct
from typing import Optional, Tuple
from python.helpers.termux_runtime import is_termux, get_shell, get_termux_home

class TermuxInteractiveSession:
    """Interactive shell session optimized for Termux using PTY"""
    
    def __init__(self, log=None, cwd: Optional[str] = None):
        self.log = log
        self.cwd = cwd or get_termux_home()
        self.process = None
        self.master_fd = None
        self.full_output = ""
        self._connected = False
        self._lock = asyncio.Lock()
        
    async def connect(self):
        """Start an interactive shell session"""
        async with self._lock:
            if self._connected:
                return
            
            shell = get_shell()
            
            # Create pseudo-terminal
            self.master_fd, slave_fd = pty.openpty()
            
            # Set terminal size
            try:
                winsize = struct.pack('HHHH', 40, 120, 0, 0)  # rows, cols, xpixel, ypixel
                fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, winsize)
            except:
                pass
            
            # Make master non-blocking
            flags = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
            fcntl.fcntl(self.master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            
            # Environment for shell
            env = self._get_env()
            
            # Start shell process
            self.process = subprocess.Popen(
                [shell, '-i'],
                stdin=slave_fd,
                stdout=slave_fd,
                stderr=slave_fd,
                cwd=self.cwd,
                env=env,
                preexec_fn=os.setsid
            )
            
            os.close(slave_fd)
            self._connected = True
            
            # Wait for initial prompt and clear it
            await asyncio.sleep(0.3)
            await self.read_output(timeout=1, reset_full_output=True)
        
    def _get_env(self):
        """Get environment for shell"""
        env = os.environ.copy()
        env['TERM'] = 'xterm-256color'
        env['PS1'] = 'termux@agent0:\\w$ '
        env['HISTFILE'] = ''  # Disable history to reduce noise
        env['HISTSIZE'] = '0'
        return env
        
    async def send_command(self, command: str):
        """Send a command to the shell"""
        if not self._connected:
            await self.connect()
            
        # Reset output for new command
        self.full_output = ""
        
        # Ensure command ends with newline
        if not command.endswith('\n'):
            command += '\n'
        
        # Write command to terminal
        try:
            os.write(self.master_fd, command.encode('utf-8'))
        except OSError as e:
            # Try reconnecting
            await self.close()
            await self.connect()
            os.write(self.master_fd, command.encode('utf-8'))
        
    async def read_output(
        self, 
        timeout: float = 1, 
        reset_full_output: bool = False
    ) -> Tuple[str, str]:
        """Read output from the shell"""
        if reset_full_output:
            self.full_output = ""
            
        partial_output = ""
        end_time = asyncio.get_event_loop().time() + timeout
        
        while asyncio.get_event_loop().time() < end_time:
            try:
                # Use select for non-blocking read
                readable, _, _ = select.select([self.master_fd], [], [], 0.1)
                
                if readable:
                    try:
                        data = os.read(self.master_fd, 4096)
                        if data:
                            text = data.decode('utf-8', errors='replace')
                            # Clean up control characters
                            text = self._clean_output(text)
                            partial_output += text
                            self.full_output += text
                    except (OSError, IOError) as e:
                        if e.errno == 11:  # EAGAIN - no data available
                            await asyncio.sleep(0.05)
                            continue
                        break
                else:
                    # No data available, wait a bit
                    await asyncio.sleep(0.05)
                    
            except Exception as e:
                break
                
        return self.full_output, partial_output
    
    def _clean_output(self, text: str) -> str:
        """Clean control characters from output"""
        import re
        # Remove ANSI escape sequences
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        text = ansi_escape.sub('', text)
        # Remove other control characters but keep newlines and tabs
        text = ''.join(c if c.isprintable() or c in '\n\t\r' else '' for c in text)
        return text
        
    async def close(self):
        """Close the shell session"""
        async with self._lock:
            if self.process:
                try:
                    # Try graceful shutdown first
                    os.write(self.master_fd, b'exit\n')
                    await asyncio.sleep(0.2)
                except:
                    pass
                    
                try:
                    os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                    await asyncio.sleep(0.1)
                    os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
                except:
                    pass
                    
                self.process = None
                
            if self.master_fd is not None:
                try:
                    os.close(self.master_fd)
                except:
                    pass
                self.master_fd = None
                
            self._connected = False
            self.full_output = ""
    
    @property
    def is_connected(self):
        return self._connected


# Alias for compatibility
LocalInteractiveSessionTermux = TermuxInteractiveSession
SHELL_TERMUX_EOF

log_success "Termux shell session handler created"

# ============================================
# Patch 3: Modify runtime.py to detect Termux
# ============================================
log_info "Patching runtime detection..."

# Create a patch file for runtime.py
if [ -f "$A0_DIR/python/helpers/runtime.py" ]; then
    # Check if already patched
    if ! grep -q "termux_runtime" "$A0_DIR/python/helpers/runtime.py"; then
        # Add import at the beginning
        sed -i '1i\# Termux compatibility patch\ntry:\n    from python.helpers.termux_runtime import is_termux, patch_for_termux\n    if is_termux():\n        patch_for_termux()\nexcept ImportError:\n    pass\n' "$A0_DIR/python/helpers/runtime.py"
        log_success "runtime.py patched"
    else
        log_info "runtime.py already patched"
    fi
fi

# ============================================
# Patch 4: Modify shell_local.py to use Termux session
# ============================================
log_info "Patching local shell handler..."

if [ -f "$A0_DIR/python/helpers/shell_local.py" ]; then
    # Check if already patched
    if ! grep -q "TermuxInteractiveSession" "$A0_DIR/python/helpers/shell_local.py"; then
        # Add Termux fallback at the end of the file
        cat >> "$A0_DIR/python/helpers/shell_local.py" << 'SHELL_LOCAL_PATCH'

# Termux compatibility - use Termux session if on Termux
try:
    from python.helpers.termux_runtime import is_termux
    if is_termux():
        from python.helpers.shell_termux import TermuxInteractiveSession
        # Override LocalInteractiveSession with Termux version
        _OriginalLocalSession = LocalInteractiveSession
        class LocalInteractiveSession(TermuxInteractiveSession):
            """Termux-compatible local interactive session"""
            pass
except ImportError:
    pass
SHELL_LOCAL_PATCH
        log_success "shell_local.py patched"
    else
        log_info "shell_local.py already patched"
    fi
fi

# ============================================
# Patch 5: Create Termux-specific settings handler
# ============================================
log_info "Creating Termux settings handler..."

cat > "$A0_DIR/python/helpers/termux_settings.py" << 'TERMUX_SETTINGS_EOF'
"""
Termux Settings Handler
Provides default settings for Termux environment
"""

import os
from python.helpers.termux_runtime import is_termux, get_termux_home

def get_termux_defaults():
    """Get default settings for Termux"""
    if not is_termux():
        return {}
    
    return {
        # Disable Docker/SSH
        'code_exec_ssh_enabled': False,
        'dockerized': False,
        
        # Local paths
        'work_dir': os.path.join(get_termux_home(), 'agent-zero', 'work_dir'),
        'memory_dir': os.path.join(get_termux_home(), 'agent-zero', 'memory'),
        'knowledge_dir': os.path.join(get_termux_home(), 'agent-zero', 'knowledge'),
        
        # Disable unsupported features
        'browser_agent_enabled': False,
        'whisper_enabled': False,
        'tts_enabled': False,
        
        # Use lighter alternatives
        'embedding_provider': 'openai',  # Use API-based embeddings
        'vector_store': 'chromadb',  # Lighter than FAISS
    }

def apply_termux_settings(settings: dict) -> dict:
    """Apply Termux defaults to settings if on Termux"""
    if not is_termux():
        return settings
    
    defaults = get_termux_defaults()
    for key, value in defaults.items():
        if key not in settings:
            settings[key] = value
    
    return settings
TERMUX_SETTINGS_EOF

log_success "Termux settings handler created"

# ============================================
# Patch 6: Disable browser agent if not available
# ============================================
log_info "Patching browser agent import..."

# Create a stub for browser_use if not available
cat > "$A0_DIR/python/helpers/browser_stub.py" << 'BROWSER_STUB_EOF'
"""
Browser Stub
Provides a stub for browser functionality when browser-use is not available
"""

import os
from python.helpers.termux_runtime import is_termux

class BrowserStub:
    """Stub class for browser functionality"""
    
    def __init__(self, *args, **kwargs):
        self._disabled = True
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, *args):
        pass
    
    async def navigate(self, url):
        raise NotImplementedError("Browser agent not available on Termux")
    
    async def get_page_content(self):
        raise NotImplementedError("Browser agent not available on Termux")

def get_browser_class():
    """Get browser class - stub if on Termux or browser-use not available"""
    if is_termux() or os.environ.get('DISABLE_BROWSER_AGENT'):
        return BrowserStub
    
    try:
        from browser_use import Browser
        return Browser
    except ImportError:
        return BrowserStub
BROWSER_STUB_EOF

log_success "Browser stub created"

# ============================================
# Patch 7: Create node evaluation script
# ============================================
log_info "Creating Node.js evaluation script..."

mkdir -p "$A0_DIR/exe"
cat > "$A0_DIR/exe/node_eval.js" << 'NODE_EVAL_EOF'
#!/usr/bin/env node
/**
 * Node.js Code Evaluation Script for Agent Zero
 * Used by the code execution tool to run JavaScript code
 */

const vm = require('vm');
const util = require('util');

// Get code from command line arguments
const code = process.argv.slice(2).join(' ');

if (!code) {
    console.error('Usage: node node_eval.js <code>');
    process.exit(1);
}

// Create a sandbox with common globals
const sandbox = {
    console: console,
    require: require,
    process: process,
    Buffer: Buffer,
    setTimeout: setTimeout,
    setInterval: setInterval,
    clearTimeout: clearTimeout,
    clearInterval: clearInterval,
    Promise: Promise,
    JSON: JSON,
    Math: Math,
    Date: Date,
    Array: Array,
    Object: Object,
    String: String,
    Number: Number,
    Boolean: Boolean,
    RegExp: RegExp,
    Error: Error,
    __dirname: process.cwd(),
    __filename: 'eval.js'
};

try {
    // Create context
    const context = vm.createContext(sandbox);
    
    // Execute code
    const script = new vm.Script(code, { filename: 'eval.js' });
    const result = script.runInContext(context, {
        timeout: 30000,  // 30 second timeout
        displayErrors: true
    });
    
    // Print result if not undefined
    if (result !== undefined) {
        if (typeof result === 'object') {
            console.log(util.inspect(result, { depth: null, colors: false }));
        } else {
            console.log(result);
        }
    }
} catch (error) {
    console.error('Error:', error.message);
    if (error.stack) {
        console.error(error.stack);
    }
    process.exit(1);
}
NODE_EVAL_EOF

chmod +x "$A0_DIR/exe/node_eval.js"
log_success "Node.js evaluation script created"

# ============================================
# Patch 8: Create run scripts
# ============================================
log_info "Creating run scripts..."

cat > "$A0_DIR/run_termux.sh" << 'RUN_TERMUX_EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# Agent Zero - Termux Run Script
# Start the Agent Zero web UI on Termux
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================"
echo "   Agent Zero - Termux Edition"
echo "======================================${NC}"

# Check virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Virtual environment not found. Creating...${NC}"
    python -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$SCRIPT_DIR/requirements_termux.txt" 2>/dev/null || \
    pip install -r "$SCRIPT_DIR/requirements.txt"
else
    source "$VENV_DIR/bin/activate"
fi

# Set Termux-specific environment
export TERMUX_MODE=true
export DOCKERIZED=false
export CODE_EXEC_SSH_ENABLED=false
export DISABLE_BROWSER_AGENT=true
export DISABLE_WHISPER=true

# Load .env file if exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${BLUE}Loading configuration from .env${NC}"
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Default port and host
PORT="${WEB_UI_PORT:-8080}"
HOST="${WEB_UI_HOST:-0.0.0.0}"

# Show access information
echo ""
echo -e "${GREEN}Starting Agent Zero Web UI...${NC}"
echo -e "${YELLOW}Local access:${NC} http://localhost:$PORT"
echo -e "${YELLOW}Network access:${NC} http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-ip'):$PORT"
echo ""
echo -e "${CYAN}Press Ctrl+C to stop${NC}"
echo ""

# Prepare and run
cd "$SCRIPT_DIR"
python prepare.py --dockerized=false 2>/dev/null || true
exec python run_ui.py --host="$HOST" --port="$PORT" --dockerized=false
RUN_TERMUX_EOF

chmod +x "$A0_DIR/run_termux.sh"

# Also create a simple start script
cat > "$A0_DIR/start.sh" << 'START_SH_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Quick start script - just runs run_termux.sh
exec "$(dirname "$0")/run_termux.sh" "$@"
START_SH_EOF

chmod +x "$A0_DIR/start.sh"

log_success "Run scripts created"

# ============================================
# Done!
# ============================================
echo ""
echo -e "${GREEN}======================================"
echo "   Patches Applied Successfully!"
echo "======================================${NC}"
echo ""
echo -e "Agent Zero is now ready for Termux."
echo ""
echo -e "To start: ${CYAN}cd $A0_DIR && ./start.sh${NC}"
echo ""
