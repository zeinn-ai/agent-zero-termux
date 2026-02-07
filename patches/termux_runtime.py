"""
Termux Runtime Helper
=====================
Provides Termux-specific functionality and patches for Agent Zero
This module is auto-imported when running on Termux to configure the environment.
"""

import os
import sys
import platform
import subprocess
from typing import Optional, Dict, Any

# Constants
TERMUX_PREFIX = '/data/data/com.termux/files/usr'
TERMUX_HOME = '/data/data/com.termux/files/home'

def is_termux() -> bool:
    """
    Check if running on Termux
    
    Returns:
        True if running on Termux, False otherwise
    """
    return os.path.exists("/data/data/com.termux")

def is_android() -> bool:
    """
    Check if running on Android (Termux or other)
    
    Returns:
        True if running on Android
    """
    return 'ANDROID_ROOT' in os.environ or is_termux()

def get_termux_home() -> str:
    """
    Get Termux home directory
    
    Returns:
        Path to Termux home directory
    """
    return os.environ.get('HOME', TERMUX_HOME)

def get_termux_prefix() -> str:
    """
    Get Termux prefix directory (like /usr on Linux)
    
    Returns:
        Path to Termux prefix
    """
    return os.environ.get('PREFIX', TERMUX_PREFIX)

def get_shell() -> str:
    """
    Get the default shell to use for code execution
    
    Returns:
        Path to shell executable
    """
    if is_termux():
        termux_shell = os.path.join(get_termux_prefix(), 'bin', 'bash')
        if os.path.exists(termux_shell):
            return termux_shell
    return os.environ.get('SHELL', '/bin/bash')

def get_python() -> str:
    """
    Get Python executable path
    
    Returns:
        Path to Python executable
    """
    if is_termux():
        termux_python = os.path.join(get_termux_prefix(), 'bin', 'python')
        if os.path.exists(termux_python):
            return termux_python
    return sys.executable

def get_node() -> str:
    """
    Get Node.js executable path
    
    Returns:
        Path to Node.js executable
    """
    if is_termux():
        termux_node = os.path.join(get_termux_prefix(), 'bin', 'node')
        if os.path.exists(termux_node):
            return termux_node
    return 'node'

def get_ipython() -> str:
    """
    Get IPython executable path
    
    Returns:
        Path to IPython executable
    """
    if is_termux():
        termux_ipython = os.path.join(get_termux_prefix(), 'bin', 'ipython')
        if os.path.exists(termux_ipython):
            return termux_ipython
    return 'ipython'

def ensure_tmp_dir() -> str:
    """
    Ensure tmp directory exists and return its path
    
    Returns:
        Path to tmp directory
    """
    if is_termux():
        tmp_dir = os.path.join(get_termux_home(), '.cache', 'agent-zero')
    else:
        tmp_dir = os.path.join(os.path.expanduser('~'), '.cache', 'agent-zero')
    
    os.makedirs(tmp_dir, exist_ok=True)
    return tmp_dir

def patch_environment():
    """
    Patch environment variables for Termux compatibility
    """
    if not is_termux():
        return
    
    # Set Termux mode flag
    os.environ['TERMUX_MODE'] = 'true'
    os.environ['DOCKERIZED'] = 'false'
    
    # Set tmp directory
    tmp_dir = ensure_tmp_dir()
    os.environ.setdefault('TMPDIR', tmp_dir)
    os.environ.setdefault('TEMP', tmp_dir)
    os.environ.setdefault('TMP', tmp_dir)
    
    # Disable Docker/SSH code execution
    os.environ.setdefault('CODE_EXEC_SSH_ENABLED', 'false')
    
    # Disable unsupported features
    os.environ.setdefault('DISABLE_BROWSER_AGENT', 'true')
    os.environ.setdefault('DISABLE_WHISPER', 'true')
    os.environ.setdefault('DISABLE_KOKORO', 'true')
    os.environ.setdefault('DISABLE_TTS', 'true')
    
    # Fix library paths
    lib_path = os.path.join(get_termux_prefix(), 'lib')
    current_ld_path = os.environ.get('LD_LIBRARY_PATH', '')
    if lib_path not in current_ld_path:
        os.environ['LD_LIBRARY_PATH'] = f"{lib_path}:{current_ld_path}" if current_ld_path else lib_path
    
    # Set proper locale
    os.environ.setdefault('LANG', 'en_US.UTF-8')
    os.environ.setdefault('LC_ALL', 'en_US.UTF-8')

def patch_for_termux():
    """
    Apply all necessary patches for Termux compatibility
    This is the main entry point for Termux patching.
    """
    if not is_termux():
        return
    
    patch_environment()
    
    # Log that we're in Termux mode
    print("[Termux] Running in Termux mode")
    print(f"[Termux] Home: {get_termux_home()}")
    print(f"[Termux] Shell: {get_shell()}")

def check_dependencies() -> Dict[str, bool]:
    """
    Check if required dependencies are installed
    
    Returns:
        Dictionary of dependency names and their availability
    """
    deps = {
        'python': get_python(),
        'node': get_node(),
        'ipython': get_ipython(),
        'git': 'git',
        'bash': get_shell()
    }
    
    results = {}
    for name, cmd in deps.items():
        try:
            result = subprocess.run(
                [cmd, '--version'], 
                capture_output=True, 
                check=True,
                timeout=5
            )
            results[name] = True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            results[name] = False
    
    return results

def get_termux_info() -> Dict[str, Any]:
    """
    Get information about the Termux environment
    
    Returns:
        Dictionary with Termux environment information
    """
    if not is_termux():
        return {'is_termux': False}
    
    return {
        'is_termux': True,
        'is_android': is_android(),
        'home': get_termux_home(),
        'prefix': get_termux_prefix(),
        'shell': get_shell(),
        'python': get_python(),
        'node': get_node(),
        'dependencies': check_dependencies(),
        'arch': platform.machine(),
        'platform': platform.platform(),
    }

# Auto-patch when imported on Termux
if is_termux():
    patch_for_termux()
