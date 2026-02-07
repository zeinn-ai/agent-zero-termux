"""
Termux Shell Session Handler
============================
Provides local interactive shell execution for Termux environment using PTY.
This replaces the SSH-based execution used in Docker.
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
import re
from typing import Optional, Tuple
from .termux_runtime import is_termux, get_shell, get_termux_home


class TermuxInteractiveSession:
    """
    Interactive shell session optimized for Termux using PTY (pseudo-terminal).
    
    This class provides a way to execute commands in an interactive shell,
    reading output as it becomes available. It's designed to replace the
    SSH-based execution used in the Docker version of Agent Zero.
    """
    
    # ANSI escape sequence pattern for cleaning output
    ANSI_ESCAPE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    
    def __init__(self, log=None, cwd: Optional[str] = None):
        """
        Initialize a new Termux interactive session.
        
        Args:
            log: Optional logger instance
            cwd: Working directory for the shell (defaults to Termux home)
        """
        self.log = log
        self.cwd = cwd or get_termux_home()
        self.process: Optional[subprocess.Popen] = None
        self.master_fd: Optional[int] = None
        self.full_output: str = ""
        self._connected: bool = False
        self._lock = asyncio.Lock()
        
    async def connect(self):
        """
        Start an interactive shell session.
        
        Creates a pseudo-terminal and starts a bash shell connected to it.
        """
        async with self._lock:
            if self._connected:
                return
            
            # Get shell path
            shell = get_shell()
            
            # Create pseudo-terminal pair
            self.master_fd, slave_fd = pty.openpty()
            
            # Set terminal size (rows, cols, xpixel, ypixel)
            try:
                winsize = struct.pack('HHHH', 50, 150, 0, 0)
                fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, winsize)
            except Exception:
                pass  # Ignore if setting size fails
            
            # Make master file descriptor non-blocking
            flags = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
            fcntl.fcntl(self.master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            
            # Prepare environment
            env = self._get_env()
            
            # Ensure working directory exists
            os.makedirs(self.cwd, exist_ok=True)
            
            # Start shell process
            self.process = subprocess.Popen(
                [shell, '-i'],  # Interactive shell
                stdin=slave_fd,
                stdout=slave_fd,
                stderr=slave_fd,
                cwd=self.cwd,
                env=env,
                preexec_fn=os.setsid  # Create new session
            )
            
            # Close slave fd in parent (child has it)
            os.close(slave_fd)
            self._connected = True
            
            # Wait for and discard initial prompt
            await asyncio.sleep(0.3)
            await self.read_output(timeout=1.0, reset_full_output=True)
            self.full_output = ""
    
    def _get_env(self) -> dict:
        """
        Get environment variables for the shell process.
        
        Returns:
            Dictionary of environment variables
        """
        env = os.environ.copy()
        
        # Terminal settings
        env['TERM'] = 'xterm-256color'
        env['COLORTERM'] = 'truecolor'
        
        # Simple prompt for easier parsing
        env['PS1'] = 'agent0@termux:\\w$ '
        env['PS2'] = '> '
        
        # Disable history to reduce noise
        env['HISTFILE'] = ''
        env['HISTSIZE'] = '0'
        env['HISTFILESIZE'] = '0'
        
        # Locale
        env['LANG'] = 'en_US.UTF-8'
        env['LC_ALL'] = 'en_US.UTF-8'
        
        # Termux-specific
        env['TERMUX_MODE'] = 'true'
        
        return env
    
    async def send_command(self, command: str):
        """
        Send a command to the shell.
        
        Args:
            command: The command to execute
        """
        if not self._connected:
            await self.connect()
        
        # Reset output buffer
        self.full_output = ""
        
        # Ensure command ends with newline
        if not command.endswith('\n'):
            command += '\n'
        
        # Try to write command
        try:
            os.write(self.master_fd, command.encode('utf-8'))
        except OSError as e:
            # Connection lost, try reconnecting
            await self.close()
            await self.connect()
            os.write(self.master_fd, command.encode('utf-8'))
    
    async def read_output(
        self,
        timeout: float = 1.0,
        reset_full_output: bool = False
    ) -> Tuple[str, str]:
        """
        Read output from the shell.
        
        Args:
            timeout: Maximum time to wait for output
            reset_full_output: If True, clear the full output buffer first
            
        Returns:
            Tuple of (full_output, partial_output)
        """
        if reset_full_output:
            self.full_output = ""
        
        partial_output = ""
        end_time = asyncio.get_event_loop().time() + timeout
        
        while asyncio.get_event_loop().time() < end_time:
            try:
                # Check if data is available
                readable, _, _ = select.select([self.master_fd], [], [], 0.1)
                
                if readable:
                    try:
                        # Read available data
                        data = os.read(self.master_fd, 8192)
                        if data:
                            # Decode and clean
                            text = data.decode('utf-8', errors='replace')
                            text = self._clean_output(text)
                            partial_output += text
                            self.full_output += text
                    except OSError as e:
                        if e.errno == 11:  # EAGAIN - no data available
                            await asyncio.sleep(0.05)
                            continue
                        break
                else:
                    # No data, brief pause
                    await asyncio.sleep(0.05)
                    
            except Exception:
                break
        
        return self.full_output, partial_output
    
    def _clean_output(self, text: str) -> str:
        """
        Clean control characters and ANSI escapes from output.
        
        Args:
            text: Raw terminal output
            
        Returns:
            Cleaned text
        """
        # Remove ANSI escape sequences
        text = self.ANSI_ESCAPE.sub('', text)
        
        # Remove carriage returns (keep newlines)
        text = text.replace('\r\n', '\n').replace('\r', '')
        
        # Remove other control characters but keep printable and whitespace
        cleaned = []
        for char in text:
            if char.isprintable() or char in '\n\t':
                cleaned.append(char)
        
        return ''.join(cleaned)
    
    async def close(self):
        """
        Close the shell session.
        """
        async with self._lock:
            if self.process:
                try:
                    # Try graceful exit
                    if self.master_fd:
                        os.write(self.master_fd, b'exit\n')
                    await asyncio.sleep(0.2)
                except Exception:
                    pass
                
                try:
                    # Send SIGTERM to process group
                    os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                    await asyncio.sleep(0.1)
                except Exception:
                    pass
                
                try:
                    # Force kill if still running
                    os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
                except Exception:
                    pass
                
                self.process = None
            
            if self.master_fd is not None:
                try:
                    os.close(self.master_fd)
                except Exception:
                    pass
                self.master_fd = None
            
            self._connected = False
            self.full_output = ""
    
    @property
    def is_connected(self) -> bool:
        """Check if the session is connected."""
        return self._connected
    
    def __del__(self):
        """Cleanup on object destruction."""
        if self._connected and asyncio.get_event_loop().is_running():
            asyncio.create_task(self.close())


# Alias for compatibility with existing code
LocalInteractiveSessionTermux = TermuxInteractiveSession


def get_session_class():
    """
    Get the appropriate session class for the current environment.
    
    Returns:
        TermuxInteractiveSession if on Termux, None otherwise
    """
    if is_termux():
        return TermuxInteractiveSession
    return None
