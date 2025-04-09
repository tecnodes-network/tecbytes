"""
Cosmos Node Installer - Utilities Module

This module contains utility functions for the Cosmos Node Installer.
"""

import os
import subprocess
import sys
from typing import Tuple, Optional

# ANSI color codes for terminal output
COLORS = {
    "reset": "\033[0m",
    "red": "\033[91m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "blue": "\033[94m",
    "magenta": "\033[95m",
    "cyan": "\033[96m",
    "white": "\033[97m",
    "bold": "\033[1m"
}

def print_header(text: str) -> None:
    """Print a header with a specific format."""
    print(f"\n{COLORS['bold']}{COLORS['blue']}=== {text} ==={COLORS['reset']}\n")

def print_step(text: str) -> None:
    """Print a step with a specific format."""
    print(f"{COLORS['cyan']}➜ {text}{COLORS['reset']}")

def print_success(text: str) -> None:
    """Print a success message with a specific format."""
    print(f"{COLORS['green']}✓ {text}{COLORS['reset']}")

def print_warning(text: str) -> None:
    """Print a warning message with a specific format."""
    print(f"{COLORS['yellow']}⚠ {text}{COLORS['reset']}")

def print_error(text: str) -> None:
    """Print an error message with a specific format."""
    print(f"{COLORS['red']}✗ {text}{COLORS['reset']}")

def get_user_input(prompt: str, default: str = "") -> str:
    """Get user input with a default value."""
    if default:
        user_input = input(f"{prompt} [{default}]: ")
        return user_input if user_input else default
    else:
        return input(f"{prompt}: ")

def get_yes_no_input(prompt: str, default: bool = True) -> bool:
    """Get a yes/no input from the user."""
    default_str = "Y/n" if default else "y/N"
    user_input = input(f"{prompt} [{default_str}]: ").lower()
    
    if not user_input:
        return default
    
    return user_input.startswith("y")

def run_command(command: str, exit_on_error: bool = True) -> Tuple[int, str, str]:
    """
    Run a shell command and return the exit code, stdout, and stderr.
    
    Args:
        command: The command to run
        exit_on_error: Whether to exit the script if the command fails
        
    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    print_step(f"Running: {command}")
    
    process = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    stdout, stderr = process.communicate()
    exit_code = process.returncode
    
    if exit_code != 0:
        print_error(f"Command failed with exit code {exit_code}")
        print(f"STDOUT: {stdout}")
        print(f"STDERR: {stderr}")
        
        if exit_on_error:
            print_error("Exiting due to command failure")
            sys.exit(1)
    
    return exit_code, stdout, stderr

def stream_command(command: str) -> None:
    """
    Run a shell command and stream its output directly to the console.
    
    Args:
        command: The command to run
    """
    try:
        subprocess.call(command, shell=True)
    except KeyboardInterrupt:
        print("\nCommand interrupted by user")

def is_command_available(command: str) -> bool:
    """Check if a command is available in the system."""
    return subprocess.call(f"which {command} > /dev/null 2>&1", shell=True) == 0

def is_port_in_use(port: int) -> bool:
    """Check if a port is already in use."""
    return subprocess.call(f"netstat -tuln | grep :{port} > /dev/null 2>&1", shell=True) == 0

def check_common_port_conflicts(port: int) -> bool:
    """Check if a port conflicts with common services."""
    common_ports = [22, 80, 443, 8080, 8443]
    return port in common_ports

def find_next_available_port(start_port: int) -> int:
    """Find the next available port starting from start_port."""
    port = start_port
    while is_port_in_use(port) or check_common_port_conflicts(port):
        port += 1
    return port

def ensure_directory_exists(directory: str) -> None:
    """Ensure a directory exists, creating it if necessary."""
    os.makedirs(directory, exist_ok=True)
    print_success(f"Directory exists: {directory}")

def ensure_pv_installed() -> None:
    """Ensure that pv (pipe viewer) is installed for download progress."""
    if not is_command_available("pv"):
        print_step("Installing pv for download progress")
        run_command("sudo apt-get install -y pv")
        
    print_success("pv is installed")
