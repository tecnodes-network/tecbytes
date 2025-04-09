"""
Cosmos Node Installer - Node Module

This module handles node setup and configuration.
"""

import os
import re
import getpass
from typing import Dict, Any

from .utils import (
    print_header, print_step, print_success, print_warning, print_error,
    run_command, get_user_input, get_yes_no_input
)

class NodeSetup:
    """Class for setting up a Cosmos-based blockchain node."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the node setup with configuration.
        
        Args:
            config: Dictionary containing node configuration
        """
        # Node configuration
        self.chain_id = config.get('chain_id', "")
        self.binary_name = config.get('binary_name', "")
        self.binary_path = config.get('binary_path', "")
        self.node_home = config.get('node_home', "")
        self.moniker = config.get('moniker', f"node-{int(__import__('time').time())}")
        self.go_version = config.get('go_version', "1.21.0")
        
        # Files configuration
        self.genesis_url = config.get('genesis_url', "")
        self.addrbook_url = config.get('addrbook_url', "")
        self.peers = config.get('peers', "")
        self.seeds = config.get('seeds', "")
        
        # Pruning configuration
        self.pruning_strategy = config.get('pruning_strategy', "default")
        self.pruning_keep_recent = config.get('pruning_keep_recent', "100")
        self.pruning_keep_every = config.get('pruning_keep_every', "0")
        self.pruning_interval = config.get('pruning_interval', "10")
        
        # Ports configuration
        self.rpc_port = config.get('rpc_port', 26657)
        self.p2p_port = config.get('p2p_port', 26656)
        self.api_port = config.get('api_port', 1317)
        self.grpc_port = config.get('grpc_port', 9090)
        self.grpc_web_port = config.get('grpc_web_port', 9091)
        self.prometheus_port = config.get('prometheus_port', 26660)
        self.pprof_port = config.get('pprof_port', 6060)
        self.proxy_app_port = config.get('proxy_app_port', 26658)
        
        # JSON-RPC configuration
        self.json_rpc_enabled = config.get('json_rpc_enabled', False)
        self.json_rpc_port = config.get('json_rpc_port', 8545)
        self.json_rpc_ws_port = config.get('json_rpc_ws_port', 8546)
        
        # Add this line to capture the expose_json_rpc value
        self.expose_json_rpc = config.get('expose_json_rpc', True)  # Default to True if not specified
    
    def get_config_dict(self) -> Dict[str, Any]:
        """
        Get configuration as dictionary.
        
        Returns:
            Dictionary containing node configuration
        """
        return {
            'chain_id': self.chain_id,
            'binary_name': self.binary_name,
            'binary_path': self.binary_path,
            'node_home': self.node_home,
            'moniker': self.moniker,
            'go_version': self.go_version,
            'genesis_url': self.genesis_url,
            'addrbook_url': self.addrbook_url,
            'peers': self.peers,
            'seeds': self.seeds,
            'pruning_strategy': self.pruning_strategy,
            'pruning_keep_recent': self.pruning_keep_recent,
            'pruning_keep_every': self.pruning_keep_every,
            'pruning_interval': self.pruning_interval,
            'rpc_port': self.rpc_port,
            'p2p_port': self.p2p_port,
            'api_port': self.api_port,
            'grpc_port': self.grpc_port,
            'grpc_web_port': self.grpc_web_port,
            'prometheus_port': self.prometheus_port,
            'pprof_port': self.pprof_port,
            'proxy_app_port': self.proxy_app_port,
            'json_rpc_enabled': self.json_rpc_enabled,
            'json_rpc_port': self.json_rpc_port,
            'json_rpc_ws_port': self.json_rpc_ws_port
        }
    
    def install_prerequisites(self) -> None:
        """Install prerequisites."""
        print_header("Installing Prerequisites")
        
        # Update package list
        print_step("Updating package list")
        run_command("sudo apt-get update")
        
        # Install dependencies
        print_step("Installing dependencies")
        run_command("sudo apt-get install -y build-essential curl jq git lz4 wget")
        
        # Install Go
        self._install_go()
        
        print_success("Prerequisites installed successfully")
    
    def _install_go(self) -> None:
        """Install Go."""
        print_step(f"Installing Go {self.go_version}")
        
        # Check if Go is already installed
        _, go_version, _ = run_command("go version || true", exit_on_error=False)
        
        if f"go{self.go_version}" in go_version:
            print_success(f"Go {self.go_version} is already installed")
            return
        
        # Download and install Go
        run_command(f"wget -q https://golang.org/dl/go{self.go_version}.linux-amd64.tar.gz") 
        run_command("sudo rm -rf /usr/local/go")
        run_command(f"sudo tar -C /usr/local -xzf go{self.go_version}.linux-amd64.tar.gz")
        run_command(f"rm go{self.go_version}.linux-amd64.tar.gz")
        
        # Add Go to PATH
        home_dir = os.path.expanduser("~")
        bashrc_path = f"{home_dir}/.bashrc"
        
        with open(bashrc_path, "r") as f:
            bashrc_content = f.read()
        
        go_path_line = 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin'
        
        if go_path_line not in bashrc_content:
            with open(bashrc_path, "a") as f:
                f.write(f"\n{go_path_line}\n")
        
        # Update current session PATH
        os.environ["PATH"] = f"{os.environ['PATH']}:/usr/local/go/bin:{home_dir}/go/bin"
        
        print_success(f"Go {self.go_version} installed successfully")
    
    def gather_basic_node_info(self) -> None:
        """Gather basic node information from user."""
        print_header("Basic Node Information")
        
        self.chain_id = get_user_input("Chain ID", self.chain_id)
        self.binary_name = get_user_input("Binary name", self.binary_name)
        self.binary_path = get_user_input("Binary path", self.binary_path or f"/usr/local/bin/{self.binary_name}")
        
        default_home = self.node_home or f"{os.path.expanduser('~')}/.{self.binary_name}"
        self.node_home = get_user_input("Node home directory", default_home)
        
        self.moniker = get_user_input("Node moniker", self.moniker)
    
    def gather_files_input(self) -> None:
        """Gather input for files."""
        print_header("Files")
        
        self.genesis_url = get_user_input("Genesis URL", self.genesis_url)
        self.addrbook_url = get_user_input("Address book URL", self.addrbook_url)
        self.peers = get_user_input("Peers (comma-separated)", self.peers)
        self.seeds = get_user_input("Seeds (comma-separated)", self.seeds)
    
    def gather_pruning_input(self) -> None:
        """Gather input for pruning."""
        print_header("Pruning")
        
        print("Pruning strategies:")
        print("1. default - Default pruning strategy")
        print("2. nothing - No pruning")
        print("3. everything - Prune everything")
        print("4. custom - Custom pruning")
        
        pruning_choice = get_user_input("Choose pruning strategy (1-4)", "1")
        
        if pruning_choice == "1":
            self.pruning_strategy = "default"
        elif pruning_choice == "2":
            self.pruning_strategy = "nothing"
        elif pruning_choice == "3":
            self.pruning_strategy = "everything"
        elif pruning_choice == "4":
            self.pruning_strategy = "custom"
            self.pruning_keep_recent = get_user_input("Keep recent", self.pruning_keep_recent)
            self.pruning_keep_every = get_user_input("Keep every", self.pruning_keep_every)
            self.pruning_interval = get_user_input("Interval", self.pruning_interval)
        else:
            print_warning("Invalid choice, using default")
            self.pruning_strategy = "default"
    
    def gather_ports_input(self) -> None:
        """Gather input for ports."""
        print_header("Ports")
        
        self.rpc_port = int(get_user_input("RPC port", str(self.rpc_port)))
        self.p2p_port = int(get_user_input("P2P port", str(self.p2p_port)))
        self.api_port = int(get_user_input("API port", str(self.api_port)))
        self.grpc_port = int(get_user_input("gRPC port", str(self.grpc_port)))
        self.grpc_web_port = int(get_user_input("gRPC-Web port", str(self.grpc_web_port)))
        self.prometheus_port = int(get_user_input("Prometheus port", str(self.prometheus_port)))
        self.pprof_port = int(get_user_input("pprof port", str(self.pprof_port)))
        self.proxy_app_port = int(get_user_input("Proxy app port", str(self.proxy_app_port)))
    
    def setup_node(self) -> None:
        """Set up the node."""
        print_header("Setting Up Node")
        
        # Initialize node
        self._initialize_node()
        
        # Check if binary supports JSON-RPC (before app.toml exists)
        self._check_json_rpc_support()
        
        # Configure node
        self._configure_node()
        
        print_success("Node setup completed successfully")
    
    def _check_json_rpc_support(self) -> None:
        """Check if the binary supports JSON-RPC."""
        print_step("Checking for JSON-RPC support")
        
        # Try to determine if the binary supports JSON-RPC by checking help output
        _, help_output, _ = run_command(f"{self.binary_path} --help", exit_on_error=False)
        
        # Look for EVM or JSON-RPC related terms in help output
        if "evm" in help_output.lower() or "json-rpc" in help_output.lower() or "jsonrpc" in help_output.lower():
            print_success("Detected potential JSON-RPC support")
            self.json_rpc_enabled = True
            return
        
        # Check if this is a known chain with JSON-RPC support
        known_json_rpc_chains = ["evmos", "ethermint", "althea", "canto", "injective", "sei"]
        for chain in known_json_rpc_chains:
            if chain in self.binary_name.lower() or chain in self.chain_id.lower():
                print_success(f"Detected JSON-RPC support (known chain: {chain})")
                self.json_rpc_enabled = True
                return
        
        print_step("No JSON-RPC support detected")
    
    def _initialize_node(self) -> None:
        """Initialize the node."""
        print_step("Initializing node")
        
        # Create node home directory
        os.makedirs(self.node_home, exist_ok=True)
        
        # Check if node is already initialized
        if os.path.exists(f"{self.node_home}/config/genesis.json"):
            print_warning("Node is already initialized")
            return
        
        # Initialize node
        run_command(f"{self.binary_path} init {self.moniker} --chain-id {self.chain_id} --home {self.node_home}")
        
        print_success("Node initialized successfully")
    
    def _configure_node(self) -> None:
        """Configure the node."""
        print_step("Configuring node")
        
        # Configure app.toml
        self._configure_app_toml()
        
        # Configure config.toml
        self._configure_config_toml()
        
        # Download genesis file
        if self.genesis_url:
            self._download_genesis()
        
        # Download address book
        if self.addrbook_url:
            self._download_addrbook()
        
        print_success("Node configured successfully")
    
    def _configure_app_toml(self) -> None:
        """Configure app.toml."""
        print_step("Configuring app.toml")
        
        app_toml_path = f"{self.node_home}/config/app.toml"
        
        # Read app.toml line by line to avoid TOML parsing issues
        with open(app_toml_path, "r") as f:
            lines = f.readlines()
        
        # Check if JSON-RPC section exists and if we should disable it
        json_rpc_section_exists = False
        should_disable_json_rpc = False
        
        # Check if expose_json_rpc is explicitly set to False in config
        # This checks both the direct attribute and the caddy section
        if (hasattr(self, 'expose_json_rpc') and self.expose_json_rpc is False):
            should_disable_json_rpc = True
            print_step("JSON-RPC exposure is disabled in configuration, will set enable=false if section exists")
        
        # First scan to check if JSON-RPC section exists
        for line in lines:
            if line.strip() == "[json-rpc]":
                json_rpc_section_exists = True
                print_step("Found [json-rpc] section in app.toml")
                break
        
        # Process lines and update settings
        updated_lines = []
        in_api_section = False
        in_grpc_section = False
        in_grpc_web_section = False
        in_json_rpc_section = False
        
        for line in lines:
            # Check which section we're in
            if line.strip() == "[api]":
                in_api_section = True
                in_grpc_section = False
                in_grpc_web_section = False
                in_json_rpc_section = False
            elif line.strip() == "[grpc]":
                in_api_section = False
                in_grpc_section = True
                in_grpc_web_section = False
                in_json_rpc_section = False
            elif line.strip() == "[grpc-web]":
                in_api_section = False
                in_grpc_section = False
                in_grpc_web_section = True
                in_json_rpc_section = False
            elif line.strip() == "[json-rpc]":
                in_api_section = False
                in_grpc_section = False
                in_grpc_web_section = False
                in_json_rpc_section = True
            elif line.strip().startswith("["):
                in_api_section = False
                in_grpc_section = False
                in_grpc_web_section = False
                in_json_rpc_section = False
            
            # Update API settings
            if in_api_section:
                if line.strip().startswith("enable ="):
                    updated_lines.append("enable = true\n")
                elif line.strip().startswith("address ="):
                    updated_lines.append(f'address = "tcp://0.0.0.0:{self.api_port}"\n')
                else:
                    updated_lines.append(line)
            
            # Update gRPC settings
            elif in_grpc_section:
                if line.strip().startswith("enable ="):
                    updated_lines.append("enable = true\n")
                elif line.strip().startswith("address ="):
                    updated_lines.append(f'address = "0.0.0.0:{self.grpc_port}"\n')
                else:
                    updated_lines.append(line)
            
            # Update gRPC-Web settings - always disable
            elif in_grpc_web_section:
                if line.strip().startswith("enable ="):
                    updated_lines.append("enable = false\n")
                else:
                    updated_lines.append(line)
            
            # Update JSON-RPC settings if needed
            elif in_json_rpc_section:
                if line.strip().startswith("enable =") and should_disable_json_rpc:
                    updated_lines.append("enable = false\n")
                    print_success("Set JSON-RPC enable = false")
                else:
                    updated_lines.append(line)
            
            # Keep other lines unchanged
            else:
                updated_lines.append(line)
        
        # Write updated app.toml
        with open(app_toml_path, "w") as f:
            f.writelines(updated_lines)
    
    def _configure_config_toml(self) -> None:
        """Configure config.toml."""
        print_step("Configuring config.toml")
        
        config_toml_path = f"{self.node_home}/config/config.toml"
        
        # Read config.toml line by line to avoid TOML parsing issues
        with open(config_toml_path, "r") as f:
            lines = f.readlines()
        
        # Process lines and update settings
        updated_lines = []
        in_p2p_section = False
        in_rpc_section = False
        in_tx_index_section = False
        in_instrumentation_section = False
        in_pruning_section = False
        
        for line in lines:
            # Check which section we're in
            if line.strip() == "[p2p]":
                in_p2p_section = True
                in_rpc_section = False
                in_tx_index_section = False
                in_instrumentation_section = False
                in_pruning_section = False
            elif line.strip() == "[rpc]":
                in_p2p_section = False
                in_rpc_section = True
                in_tx_index_section = False
                in_instrumentation_section = False
                in_pruning_section = False
            elif line.strip() == "[tx_index]":
                in_p2p_section = False
                in_rpc_section = False
                in_tx_index_section = True
                in_instrumentation_section = False
                in_pruning_section = False
            elif line.strip() == "[instrumentation]":
                in_p2p_section = False
                in_rpc_section = False
                in_tx_index_section = False
                in_instrumentation_section = True
                in_pruning_section = False
            elif line.strip() == "[pruning]":
                in_p2p_section = False
                in_rpc_section = False
                in_tx_index_section = False
                in_instrumentation_section = False
                in_pruning_section = True
            elif line.strip().startswith("["):
                in_p2p_section = False
                in_rpc_section = False
                in_tx_index_section = False
                in_instrumentation_section = False
                in_pruning_section = False


            # Handle proxy_app setting at the top level (outside any section)
            if line.strip().startswith("proxy_app ="):
                    updated_lines.append(f'proxy_app = "tcp://127.0.0.1:{self.proxy_app_port}"\n')

            # Update P2P settings
            elif in_p2p_section:
                if line.strip().startswith("laddr ="):
                    updated_lines.append(f'laddr = "tcp://0.0.0.0:{self.p2p_port}"\n')
                elif line.strip().startswith("persistent_peers ="):
                    updated_lines.append(f'persistent_peers = "{self.peers}"\n')
                elif line.strip().startswith("seeds ="):
                    updated_lines.append(f'seeds = "{self.seeds}"\n')
                else:
                    updated_lines.append(line)
            
            # Update RPC settings
            elif in_rpc_section:
                if line.strip().startswith("laddr ="):
                    updated_lines.append(f'laddr = "tcp://0.0.0.0:{self.rpc_port}"\n')
                    print("I WAS THERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                elif line.strip().startswith("pprof_laddr ="):
                    updated_lines.append(f'pprof_laddr = "localhost:{self.pprof_port}"\n')
                else:
                    updated_lines.append(line)
            
            # Update tx_index settings
            elif in_tx_index_section:
                if line.strip().startswith("indexer ="):
                    updated_lines.append('indexer = "kv"\n')
                else:
                    updated_lines.append(line)
            
            # Update instrumentation settings
            elif in_instrumentation_section:
                if line.strip().startswith("prometheus ="):
                    updated_lines.append("prometheus = true\n")
                elif line.strip().startswith("prometheus_listen_addr ="):
                    updated_lines.append(f'prometheus_listen_addr = ":{self.prometheus_port}"\n')
                else:
                    updated_lines.append(line)
            
            # Update pruning settings
            elif in_pruning_section:
                if line.strip().startswith("pruning ="):
                    updated_lines.append(f'pruning = "{self.pruning_strategy}"\n')
                elif line.strip().startswith("pruning-keep-recent ="):
                    updated_lines.append(f'pruning-keep-recent = "{self.pruning_keep_recent}"\n')
                elif line.strip().startswith("pruning-keep-every ="):
                    updated_lines.append(f'pruning-keep-every = "{self.pruning_keep_every}"\n')
                elif line.strip().startswith("pruning-interval ="):
                    updated_lines.append(f'pruning-interval = "{self.pruning_interval}"\n')
                else:
                    updated_lines.append(line)
            
            # Keep other lines unchanged
            else:
                updated_lines.append(line)
        
        # Write updated config.toml
        with open(config_toml_path, "w") as f:
            f.writelines(updated_lines)
    
    def _download_genesis(self) -> None:
        """Download genesis file."""
        print_step(f"Downloading genesis file from {self.genesis_url}")
        
        genesis_path = f"{self.node_home}/config/genesis.json"
        
        # Backup existing genesis file
        if os.path.exists(genesis_path):
            run_command(f"cp {genesis_path} {genesis_path}.backup")
        
        # Download genesis file
        if self.genesis_url.endswith(".json"):
            run_command(f"wget -q -O {genesis_path} {self.genesis_url}")
        elif self.genesis_url.endswith(".gz"):
            run_command(f"wget -q -O {genesis_path}.gz {self.genesis_url}")
            run_command(f"gzip -d {genesis_path}.gz")
        elif self.genesis_url.endswith(".zip"):
            run_command(f"wget -q -O {genesis_path}.zip {self.genesis_url}")
            run_command(f"unzip -o {genesis_path}.zip -d {self.node_home}/config/")
            run_command(f"rm {genesis_path}.zip")
        else:
            print_warning(f"Unsupported genesis file format: {self.genesis_url}")
            return
        
        print_success("Genesis file downloaded successfully")
    
    def _download_addrbook(self) -> None:
        """Download address book."""
        print_step(f"Downloading address book from {self.addrbook_url}")
        
        addrbook_path = f"{self.node_home}/config/addrbook.json"
        
        # Backup existing address book
        if os.path.exists(addrbook_path):
            run_command(f"cp {addrbook_path} {addrbook_path}.backup")
        
        # Download address book
        if self.addrbook_url.endswith(".json"):
            run_command(f"wget -q -O {addrbook_path} {self.addrbook_url}")
        elif self.addrbook_url.endswith(".gz"):
            run_command(f"wget -q -O {addrbook_path}.gz {self.addrbook_url}")
            run_command(f"gzip -d {addrbook_path}.gz")
        elif self.addrbook_url.endswith(".zip"):
            run_command(f"wget -q -O {addrbook_path}.zip {self.addrbook_url}")
            run_command(f"unzip -o {addrbook_path}.zip -d {self.node_home}/config/")
            run_command(f"rm {addrbook_path}.zip")
        else:
            print_warning(f"Unsupported address book format: {self.addrbook_url}")
            return
        
        print_success("Address book downloaded successfully")
