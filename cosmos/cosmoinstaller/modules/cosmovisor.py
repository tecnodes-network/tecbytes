"""
Cosmos Node Installer - Cosmovisor Module

This module handles Cosmovisor installation and setup.
"""

import os
import getpass
from typing import Dict, Any

from .utils import (
    print_header, print_step, print_success, print_warning, print_error,
    run_command, is_command_available
)

class CosmovisorSetup:
    """Class for setting up Cosmovisor for a Cosmos-based blockchain node."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the Cosmovisor setup with configuration.
        
        Args:
            config: Dictionary containing node configuration
        """
        # Node configuration
        self.binary_name = config.get('binary_name', "")
        self.binary_path = config.get('binary_path', "")
        self.node_home = config.get('node_home', "")
    
    def install_cosmovisor(self) -> None:
        """Install Cosmovisor."""
        print_header("Installing Cosmovisor")
        
        # Check if Cosmovisor is already installed
        if is_command_available("cosmovisor"):
            print_success("Cosmovisor is already installed")
            return
        
        # Install Cosmovisor
        print_step("Installing Cosmovisor")
        run_command("go install github.com/cosmos/cosmos-sdk/cosmovisor/cmd/cosmovisor@latest")
        
        print_success("Cosmovisor installed successfully")
    
    def setup_cosmovisor(self) -> None:
        """Set up Cosmovisor."""
        print_header("Setting Up Cosmovisor")
        
        # Create Cosmovisor directories
        print_step("Creating Cosmovisor directories")
        cosmovisor_dir = f"{self.node_home}/cosmovisor"
        os.makedirs(f"{cosmovisor_dir}/genesis/bin", exist_ok=True)
        os.makedirs(f"{cosmovisor_dir}/upgrades", exist_ok=True)
        
        # Copy binary to Cosmovisor directory
        print_step("Copying binary to Cosmovisor directory")
        run_command(f"cp {self.binary_path} {cosmovisor_dir}/genesis/bin/")

        # Create symbolic links
        print_step("Creating symbolic links")
        run_command(f"ln -sf {cosmovisor_dir}/genesis {cosmovisor_dir}/current -f")
        run_command(f"sudo ln -sf {cosmovisor_dir}/current/bin/{self.binary_name} /usr/local/bin/{self.binary_name} -f")
        
        # Create systemd service file
        self._create_systemd_service()
        
        print_success("Cosmovisor setup completed successfully")
    
    def _create_systemd_service(self) -> None:
        """Create systemd service file for Cosmovisor."""
        print_step("Creating systemd service file")
        
        # Get cosmovisor binary path
        _, cosmovisor_path, _ = run_command("which cosmovisor", exit_on_error=False)
        cosmovisor_path = cosmovisor_path.strip()
        
        # If cosmovisor path not found, use default
        if not cosmovisor_path:
            cosmovisor_path = "/home/$(whoami)/go/bin/cosmovisor"
            print_warning(f"Cosmovisor binary not found, using default path: {cosmovisor_path}")
        
        service_file = f"""[Unit]
Description={self.binary_name} daemon
After=network-online.target

[Service]
User={getpass.getuser()}
ExecStart={cosmovisor_path} run start --home {self.node_home}
Restart=always
RestartSec=3
LimitNOFILE=4096

Environment="DAEMON_NAME={self.binary_name}"
Environment="DAEMON_HOME={self.node_home}"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:{self.node_home}/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
"""
        
        service_path = f"/tmp/{self.binary_name}.service"
        with open(service_path, "w") as f:
            f.write(service_file)
        
        run_command(f"sudo mv {service_path} /etc/systemd/system/")
        run_command("sudo systemctl daemon-reload")
