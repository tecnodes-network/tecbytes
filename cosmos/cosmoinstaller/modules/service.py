"""
Cosmos Node Installer - Service Module

This module handles service management for Cosmos nodes.
"""

import subprocess
from typing import Dict, Any

from .utils import (
    print_header, print_step, print_success, print_warning, print_error,
    run_command, stream_command
)

class ServiceManager:
    """Class for managing services for a Cosmos-based blockchain node."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the service manager with configuration.
        
        Args:
            config: Dictionary containing node configuration
        """
        # Node configuration
        self.binary_name = config.get('binary_name', "")
    
    def start_enable_service(self) -> None:
        """Start and enable the node service."""
        print_header("Starting and Enabling Node Service")
        
        if not self.binary_name:
            print_error("Binary name not set, please configure the node first")
            return
        
        service_name = self.binary_name
        
        # Check if service exists
        print_step(f"Checking if {service_name} service exists")
        service_exists_cmd = f"systemctl list-unit-files | grep {service_name}.service"
        exit_code, _, _ = run_command(service_exists_cmd, exit_on_error=False)
        
        if exit_code != 0:
            print_error(f"Service {service_name} does not exist. Please set up the node first.")
            return
        
        # Enable service
        print_step(f"Enabling {service_name} service")
        run_command(f"sudo systemctl enable {service_name}")
        
        # Start service
        print_step(f"Starting {service_name} service")
        run_command(f"sudo systemctl start {service_name}")
        
        # Check service status
        print_step(f"Checking {service_name} service status")
        run_command(f"sudo systemctl status {service_name}")
        
        print_success(f"{service_name} service has been enabled and started")
    
    def show_node_logs(self) -> None:
        """Show the node logs."""
        print_header("Node Logs")
        
        if not self.binary_name:
            print_error("Binary name not set, please configure the node first")
            return
        
        service_name = self.binary_name
        
        # Check if service exists
        print_step(f"Checking if {service_name} service exists")
        service_exists_cmd = f"systemctl list-unit-files | grep {service_name}.service"
        exit_code, _, _ = run_command(service_exists_cmd, exit_on_error=False)
        
        if exit_code != 0:
            print_error(f"Service {service_name} does not exist. Please set up the node first.")
            return
        
        # Show logs
        print_step(f"Showing logs for {service_name}")
        print("\nPress Ctrl+C to exit log view\n")
        
        try:
            # Use stream_command to display logs in real-time
            stream_command(f"sudo journalctl -u {service_name} -f -o cat")
        except KeyboardInterrupt:
            print("\nExited log view")
