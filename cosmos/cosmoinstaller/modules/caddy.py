"""
Cosmos Node Installer - Caddy Module

This module handles Caddy installation and setup.
"""

import os
from typing import Dict, Any

from .utils import (
    print_header, print_step, print_success, print_warning, print_error,
    run_command
)

class CaddySetup:
    """Class for setting up Caddy for a Cosmos-based blockchain node."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the Caddy setup with configuration.
        
        Args:
            config: Dictionary containing node configuration
        """
        # Node configuration
        self.chain_id = config.get('chain_id', "")
        self.binary_name = config.get('binary_name', "")
        self.rpc_port = config.get('rpc_port', 26657)
        self.api_port = config.get('api_port', 1317)
        self.grpc_port = config.get('grpc_port', 9090)
        
        # JSON-RPC configuration
        self.json_rpc_enabled = config.get('json_rpc_enabled', False)
        self.json_rpc_port = config.get('json_rpc_port', 8545)
        
        # Caddy configuration
        self.expose_rpc = config.get('expose_rpc', False)
        self.expose_api = config.get('expose_api', False)
        self.expose_grpc = config.get('expose_grpc', False)
        self.expose_json_rpc = config.get('expose_json_rpc', False)
        self.domain = config.get('domain', "")
        self.domain_pattern = config.get('domain_pattern', "")
    

    def install_caddy(self) -> None:
        """Install Caddy."""
        print_header("Installing Caddy")
        
        # Check if Caddy is already installed
        print_step("Checking if Caddy is already installed")
        _, caddy_version, _ = run_command("caddy version || true", exit_on_error=False)
        
        if caddy_version and "v2." in caddy_version:
            print_success(f"Caddy is already installed: {caddy_version.strip()}")
            return
        
        # Install Caddy
        print_step("Installing Caddy")
        run_command("sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https") 
        run_command("curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg") 
        run_command("curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list") 
        run_command("sudo apt-get update")
        run_command("sudo apt-get install -y caddy")
        
        print_success("Caddy installed successfully")

    
    def setup_caddy(self) -> None:
        """Set up Caddy."""
        print_header("Setting Up Caddy")
        
        if not self.domain:
            print_warning("No domain specified, skipping Caddy setup")
            return
        
        # Update Caddyfile
        print_step("Updating Caddyfile")
        self._update_caddyfile()
        
        # Restart Caddy
        print_step("Restarting Caddy")
        run_command("sudo systemctl restart caddy")
        
        print_success("Caddy setup completed successfully")
    
    def _update_caddyfile(self) -> None:
        """Update Caddyfile for Caddy, preserving existing configuration."""
        # Use the full domain as provided in the configuration
        full_domain = self.domain
        
        # Check if Caddyfile exists
        caddyfile_path = "/etc/caddy/Caddyfile"
        temp_caddyfile_path = "/tmp/Caddyfile"
        
        # Create backup of existing Caddyfile if it exists
        if os.path.exists(caddyfile_path):
            print_step("Creating backup of existing Caddyfile")
            run_command(f"sudo cp {caddyfile_path} {caddyfile_path}.bak")
            
            # Read existing Caddyfile
            _, existing_content, _ = run_command(f"sudo cat {caddyfile_path}", exit_on_error=False)
        else:
            existing_content = ""
        
        # Prepare new configuration
        new_config = ""
        
        # Get chain identifier for comments
        chain_identifier = self.chain_id if self.chain_id else self.binary_name
        if not chain_identifier:
            chain_identifier = "Cosmos Node"
        
        # Add comment header for this chain's configuration
        new_config += f"\n# {chain_identifier}\n\n"
        
        # Prepare domain configurations
        domain_configs = []
        
        # Add RPC configuration
        if self.expose_rpc:
            rpc_domain = f"rpc.{full_domain}"
            if rpc_domain not in existing_content:
                domain_configs.append(f"""{rpc_domain} {{
    reverse_proxy localhost:{self.rpc_port}
}}
""")
        
        # Add API configuration
        if self.expose_api:
            api_domain = f"api.{full_domain}"
            if api_domain not in existing_content:
                domain_configs.append(f"""{api_domain} {{
    reverse_proxy localhost:{self.api_port}
}}
""")
        
        # Add gRPC configuration
        if self.expose_grpc:
            grpc_domain = f"grpc.{full_domain}"
            if grpc_domain not in existing_content:
                domain_configs.append(f"""{grpc_domain} {{
    reverse_proxy {{
        to h2c://localhost:{self.grpc_port}
        transport http {{
            versions h2c 2
        }}
    }}
}}
""") 
        
        # Add JSON-RPC configuration if enabled
        if self.expose_json_rpc and self.json_rpc_enabled:
            jsonrpc_domain = f"jsonrpc.{full_domain}"
            if jsonrpc_domain not in existing_content:
                domain_configs.append(f"""{jsonrpc_domain} {{
    reverse_proxy localhost:{self.json_rpc_port}
}}
""")
        
        # Combine existing content with new configurations
        if domain_configs:
            # Write to temporary file
            with open(temp_caddyfile_path, "w") as f:
                f.write(new_config)
                for config in domain_configs:
                    f.write(config)
                f.write("\n")
                
                # Add existing content if it's not empty and doesn't duplicate our new configs
                if existing_content.strip():
                    # Skip any global email configuration
                    lines = existing_content.split("\n")
                    filtered_lines = []
                    skip_block = False
                    brace_count = 0
                    
                    for line in lines:
                        if "{" in line and "email" in line:
                            skip_block = True
                            brace_count = 1
                            continue
                        
                        if skip_block:
                            brace_count += line.count("{")
                            brace_count -= line.count("}")
                            if brace_count <= 0:
                                skip_block = False
                            continue
                        
                        filtered_lines.append(line)
                    
                    existing_content = "\n".join(filtered_lines)
                    f.write(existing_content)
            
            # Move temporary file to Caddyfile location
            run_command(f"sudo mv {temp_caddyfile_path} {caddyfile_path}")
            print_success("Caddyfile updated successfully")
        else:
            print_warning("No new Caddy configurations to add")
