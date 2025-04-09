"""
Cosmos Node Installer - Main Script

This script provides a menu-driven interface for installing and configuring Cosmos-based blockchain nodes.
"""

import argparse
import os
import sys
from typing import Dict, Any, Optional

# Import modules
from modules.utils import (
    print_header, print_step, print_success, print_warning, print_error,
    get_user_input, get_yes_no_input
)
from modules.config import load_config_file, find_config_file, save_config_to_file
from modules.node import NodeSetup
from modules.sync import NodeSync
from modules.cosmovisor import CosmovisorSetup
from modules.caddy import CaddySetup
from modules.service import ServiceManager

class CosmosNodeInstaller:
    """Main class for the Cosmos Node Installer."""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the installer.
        
        Args:
            config_path: Path to the configuration file
        """
        # Default configuration
        self.config = {
            'chain_id': "",
            'binary_name': "",
            'binary_path': "",
            'node_home': "",
            'moniker': f"node-{int(__import__('time').time())}",
            'go_version': "1.21.0",
            'genesis_url': "",
            'addrbook_url': "",
            'peers': "",
            'seeds': "",
            'pruning_strategy': "default",
            'pruning_keep_recent': "100",
            'pruning_keep_every': "0",
            'pruning_interval': "10",
            'rpc_port': 26657,
            'p2p_port': 26656,
            'api_port': 1317,
            'grpc_port': 9090,
            'grpc_web_port': 9091,
            'prometheus_port': 26660,
            'pprof_port': 6060,
            'proxy_app_port': 26658,
            'json_rpc_enabled': False,
            'json_rpc_port': 8545,
            'json_rpc_ws_port': 8546,
            'sync_method': "none",
            'snapshot_url': "",
            'statesync_rpc': "",
            'statesync_peer': "",
            'wasm_enabled': False,
            'wasm_url': "",
            'expose_rpc': False,
            'expose_api': False,
            'expose_grpc': False,
            'expose_json_rpc': False,
            'domain': "",
            'domain_pattern': "",
            'should_install_prerequisites': True,
            'setup_node_config': True,
            'setup_cosmovisor_config': True,
            'sync_node_config': True,
            'setup_caddy_config': True
        }
        
        # Load configuration if provided
        if config_path:
            self._load_configuration(config_path)
        
        # Initialize modules
        self.node_setup = NodeSetup(self.config)
        self.node_sync = NodeSync(self.config)
        self.cosmovisor_setup = CosmovisorSetup(self.config)
        self.caddy_setup = CaddySetup(self.config)
        self.service_manager = ServiceManager(self.config)
    
    def _load_configuration(self, config_path: str) -> None:
        """
        Load configuration from a YAML file.
        
        Args:
            config_path: Path to the configuration file
        """
        print_header(f"Loading configuration from {config_path}")
        
        config = load_config_file(config_path)
        if not config:
            print_warning("No configuration loaded or empty configuration file")
            return
        
        # Update configuration
        self._update_config_from_yaml(config)
        
        print_success("Configuration loaded successfully")
    
    def _update_config_from_yaml(self, yaml_config: Dict[str, Any]) -> None:
        """
        Update configuration from YAML data.
        
        Args:
            yaml_config: Configuration data from YAML file
        """
        # Node configuration
        if 'node' in yaml_config:
            node_config = yaml_config['node']
            self.config['chain_id'] = node_config.get('chain_id', self.config['chain_id'])
            self.config['binary_name'] = node_config.get('binary_name', self.config['binary_name'])
            self.config['binary_path'] = node_config.get('binary_path', self.config['binary_path'])
            self.config['node_home'] = node_config.get('node_home', self.config['node_home'])
            self.config['moniker'] = node_config.get('moniker', self.config['moniker'])
            self.config['go_version'] = node_config.get('go_version', self.config['go_version'])
        
        # Files configuration
        if 'files' in yaml_config:
            files_config = yaml_config['files']
            self.config['genesis_url'] = files_config.get('genesis_url', self.config['genesis_url'])
            self.config['addrbook_url'] = files_config.get('addrbook_url', self.config['addrbook_url'])
            self.config['peers'] = files_config.get('peers', self.config['peers'])
            self.config['seeds'] = files_config.get('seeds', self.config['seeds'])
        
        # Pruning configuration
        if 'pruning' in yaml_config:
            pruning_config = yaml_config['pruning']
            self.config['pruning_strategy'] = pruning_config.get('strategy', self.config['pruning_strategy'])
            self.config['pruning_keep_recent'] = pruning_config.get('keep_recent', self.config['pruning_keep_recent'])
            self.config['pruning_keep_every'] = pruning_config.get('keep_every', self.config['pruning_keep_every'])
            self.config['pruning_interval'] = pruning_config.get('interval', self.config['pruning_interval'])
        
        # Ports configuration
        if 'ports' in yaml_config:
            ports_config = yaml_config['ports']
            self.config['rpc_port'] = ports_config.get('rpc', self.config['rpc_port'])
            self.config['p2p_port'] = ports_config.get('p2p', self.config['p2p_port'])
            self.config['api_port'] = ports_config.get('api', self.config['api_port'])
            self.config['grpc_port'] = ports_config.get('grpc', self.config['grpc_port'])
            self.config['grpc_web_port'] = ports_config.get('grpc_web', self.config['grpc_web_port'])
            self.config['prometheus_port'] = ports_config.get('prometheus', self.config['prometheus_port'])
            self.config['pprof_port'] = ports_config.get('pprof', self.config['pprof_port'])
            self.config['proxy_app_port'] = ports_config.get('proxy_app', self.config['proxy_app_port'])
            self.config['json_rpc_port'] = ports_config.get('json_rpc', self.config['json_rpc_port'])
            self.config['json_rpc_ws_port'] = ports_config.get('json_rpc_ws', self.config['json_rpc_ws_port'])
        
        # Sync configuration
        if 'sync' in yaml_config:
            sync_config = yaml_config['sync']
            self.config['sync_method'] = sync_config.get('method', self.config['sync_method'])
            self.config['snapshot_url'] = sync_config.get('snapshot_url', self.config['snapshot_url'])
            self.config['statesync_rpc'] = sync_config.get('statesync_rpc', self.config['statesync_rpc'])
            self.config['statesync_peer'] = sync_config.get('statesync_peer', self.config['statesync_peer'])
        
        # WASM configuration
        if 'wasm' in yaml_config:
            wasm_config = yaml_config['wasm']
            self.config['wasm_enabled'] = wasm_config.get('enabled', self.config['wasm_enabled'])
            self.config['wasm_url'] = wasm_config.get('url', self.config['wasm_url'])
        
        # Caddy configuration
        if 'caddy' in yaml_config:
            caddy_config = yaml_config['caddy']
            self.config['expose_rpc'] = caddy_config.get('expose_rpc', self.config['expose_rpc'])
            self.config['expose_api'] = caddy_config.get('expose_api', self.config['expose_api'])
            self.config['expose_grpc'] = caddy_config.get('expose_grpc', self.config['expose_grpc'])
            self.config['expose_json_rpc'] = caddy_config.get('expose_json_rpc', self.config['expose_json_rpc'])
            self.config['domain'] = caddy_config.get('domain', self.config['domain'])
            self.config['domain_pattern'] = caddy_config.get('domain_pattern', self.config['domain_pattern'])
        
        # Installation configuration
        if 'install' in yaml_config:
            install_config = yaml_config['install']
            self.config['should_install_prerequisites'] = install_config.get('prerequisites', self.config['should_install_prerequisites'])
            self.config['setup_node_config'] = install_config.get('node_setup', self.config['setup_node_config'])
            self.config['setup_cosmovisor_config'] = install_config.get('cosmovisor', self.config['setup_cosmovisor_config'])
            self.config['sync_node_config'] = install_config.get('sync_node', self.config['sync_node_config'])
            self.config['setup_caddy_config'] = install_config.get('caddy', self.config['setup_caddy_config'])
        
        # Update module configurations
        self._update_module_configs()
    
    def _update_module_configs(self) -> None:
        """Update module configurations with current config."""
        self.node_setup = NodeSetup(self.config)
        self.node_sync = NodeSync(self.config)
        self.cosmovisor_setup = CosmovisorSetup(self.config)
        self.caddy_setup = CaddySetup(self.config)
        self.service_manager = ServiceManager(self.config)
    
    def display_config_summary(self) -> None:
        """Display a summary of the current configuration."""
        print_header("Configuration Summary")
        
        print("Node Configuration:")
        print(f"Chain ID: {self.config['chain_id']}")
        print(f"Binary Name: {self.config['binary_name']}")
        print(f"Binary Path: {self.config['binary_path']}")
        print(f"Node Home: {self.config['node_home']}")
        print(f"Moniker: {self.config['moniker']}")
        print(f"Go Version: {self.config['go_version']}")
        
        print("\nFiles:")
        print(f"Genesis URL: {self.config['genesis_url']}")
        print(f"Addrbook URL: {self.config['addrbook_url']}")
        print(f"Peers: {self.config['peers']}")
        print(f"Seeds: {self.config['seeds']}")
        
        print("\nPruning:")
        print(f"Strategy: {self.config['pruning_strategy']}")
        print(f"Keep Recent: {self.config['pruning_keep_recent']}")
        print(f"Keep Every: {self.config['pruning_keep_every']}")
        print(f"Interval: {self.config['pruning_interval']}")
        
        print("\nPorts:")
        print(f"RPC: {self.config['rpc_port']}")
        print(f"P2P: {self.config['p2p_port']}")
        print(f"API: {self.config['api_port']}")
        print(f"gRPC: {self.config['grpc_port']}")
        print(f"gRPC Web: {self.config['grpc_web_port']}")
        print(f"Prometheus: {self.config['prometheus_port']}")
        print(f"pprof: {self.config['pprof_port']}")
        print(f"Proxy App: {self.config['proxy_app_port']}")
        
        if self.config['json_rpc_enabled']:
            print(f"JSON-RPC HTTP: {self.config['json_rpc_port']}")
            print(f"JSON-RPC WebSocket: {self.config['json_rpc_ws_port']}")
        
        print("\nSync:")
        print(f"Method: {self.config['sync_method']}")
        print(f"Snapshot URL: {self.config['snapshot_url']}")
        print(f"StateSync RPC: {self.config['statesync_rpc']}")
        print(f"StateSync Peer: {self.config['statesync_peer']}")
        
        print("\nWASM:")
        print(f"Enabled: {'Yes' if self.config['wasm_enabled'] else 'No'}")
        print(f"URL: {self.config['wasm_url']}")
        
        print("\nCaddy:")
        print(f"Expose RPC: {'Yes' if self.config['expose_rpc'] else 'No'}")
        print(f"Expose API: {'Yes' if self.config['expose_api'] else 'No'}")
        print(f"Expose gRPC: {'Yes' if self.config['expose_grpc'] else 'No'}")
        print(f"Expose JSON-RPC: {'Yes' if self.config['expose_json_rpc'] else 'No'}")
        print(f"Domain: {self.config['domain']}")
        print(f"Domain Pattern: {self.config['domain_pattern']}")
        
        print("\nInstallation:")
        print(f"Install Prerequisites: {'Yes' if self.config['should_install_prerequisites'] else 'No'}")
        print(f"Setup Node: {'Yes' if self.config['setup_node_config'] else 'No'}")
        print(f"Setup Cosmovisor: {'Yes' if self.config['setup_cosmovisor_config'] else 'No'}")
        print(f"Sync Node: {'Yes' if self.config['sync_node_config'] else 'No'}")
        print(f"Setup Caddy: {'Yes' if self.config['setup_caddy_config'] else 'No'}")
    
    def show_main_menu(self) -> str:
        """
        Show the main menu and get user choice.
        
        Returns:
            User's menu choice
        """
        print_header("Main Menu")
        print("1. Full installation (prerequisites, node setup, cosmovisor, sync, caddy)")
        print("2. Node synchronization only")
        print("3. Caddy configuration only")
        print("4. Install prerequisites only")
        print("5. Node setup only")
        print("6. Cosmovisor setup only")
        print("7. Display configuration")
        print("8. Start/enable node service")
        print("9. Show node logs")
        print("10. Exit")
        
        choice = input("\nEnter your choice (1-10): ")
        return choice
    
    def gather_all_input(self) -> None:
        """Gather all input from the user."""
        self.node_setup.gather_basic_node_info()
        self.node_setup.gather_files_input()
        self.node_setup.gather_pruning_input()
        self.node_setup.gather_ports_input()
        self._gather_sync_input()
        self._gather_wasm_input()
        self._gather_caddy_input()
        self._gather_install_input()
        
        # Update config from node_setup
        self._update_config_from_node_setup()
    
    def _gather_sync_input(self) -> None:
        """Gather input for node synchronization."""
        print_header("Node Synchronization")
        
        print("Sync methods:")
        print("1. None - Sync from scratch")
        print("2. Snapshot - Sync from a snapshot")
        print("3. State-Sync - Sync using State-Sync")
        
        sync_choice = get_user_input("Choose sync method (1-3)", "1")
        
        if sync_choice == "1":
            self.config['sync_method'] = "none"
        elif sync_choice == "2":
            self.config['sync_method'] = "snapshot"
            self.config['snapshot_url'] = get_user_input("Snapshot URL", self.config['snapshot_url'])
        elif sync_choice == "3":
            self.config['sync_method'] = "statesync"
            self.config['statesync_rpc'] = get_user_input("State-Sync RPC URL", self.config['statesync_rpc'])
            self.config['statesync_peer'] = get_user_input("State-Sync Peer", self.config['statesync_peer'])
        else:
            print_warning("Invalid choice, using none")
            self.config['sync_method'] = "none"
    
    def _gather_wasm_input(self) -> None:
        """Gather input for WASM configuration."""
        print_header("WASM Configuration")
        
        self.config['wasm_enabled'] = get_yes_no_input("Enable WASM", self.config['wasm_enabled'])
        
        if self.config['wasm_enabled']:
            self.config['wasm_url'] = get_user_input("WASM URL", self.config['wasm_url'])
    
    def _gather_caddy_input(self) -> None:
        """Gather input for Caddy configuration."""
        print_header("Caddy Configuration")
        
        self.config['expose_rpc'] = get_yes_no_input("Expose RPC", self.config['expose_rpc'])
        self.config['expose_api'] = get_yes_no_input("Expose API", self.config['expose_api'])
        self.config['expose_grpc'] = get_yes_no_input("Expose gRPC", self.config['expose_grpc'])
        
        # Ask about JSON-RPC if it's enabled
        if self.config['json_rpc_enabled']:
            self.config['expose_json_rpc'] = get_yes_no_input("Expose JSON-RPC", self.config['expose_json_rpc'])
        
        if (self.config['expose_rpc'] or self.config['expose_api'] or 
            self.config['expose_grpc'] or self.config['expose_json_rpc']):
            self.config['domain'] = get_user_input("Domain (e.g., example.com)", self.config['domain'])
            
            if not self.config['domain_pattern'] and self.config['domain']:
                default_pattern = f"*.{self.config['domain']}"
                self.config['domain_pattern'] = get_user_input("Domain pattern for wildcard SSL", default_pattern)
            else:
                self.config['domain_pattern'] = get_user_input("Domain pattern for wildcard SSL", self.config['domain_pattern'])
    
    def _gather_install_input(self) -> None:
        """Gather input for installation options."""
        print_header("Installation Options")
        
        self.config['should_install_prerequisites'] = get_yes_no_input("Install prerequisites", self.config['should_install_prerequisites'])
        self.config['setup_node_config'] = get_yes_no_input("Setup node", self.config['setup_node_config'])
        self.config['setup_cosmovisor_config'] = get_yes_no_input("Setup Cosmovisor", self.config['setup_cosmovisor_config'])
        self.config['sync_node_config'] = get_yes_no_input("Sync node", self.config['sync_node_config'])
        self.config['setup_caddy_config'] = get_yes_no_input("Setup Caddy", self.config['setup_caddy_config'])
    
    def _update_config_from_node_setup(self) -> None:
        """Update config from node_setup object."""
        node_config = self.node_setup.get_config_dict()
        for key, value in node_config.items():
            self.config[key] = value
        
        # Update module configurations
        self._update_module_configs()
    
    def save_config_to_file(self, config_path: str) -> None:
        """
        Save current configuration to a YAML file.
        
        Args:
            config_path: Path to save the configuration file
        """
        # Prepare configuration structure
        yaml_config = {
            "node": {
                "chain_id": self.config['chain_id'],
                "binary_name": self.config['binary_name'],
                "binary_path": self.config['binary_path'],
                "node_home": self.config['node_home'],
                "moniker": self.config['moniker'],
                "go_version": self.config['go_version']
            },
            "files": {
                "genesis_url": self.config['genesis_url'],
                "addrbook_url": self.config['addrbook_url'],
                "peers": self.config['peers'],
                "seeds": self.config['seeds']
            },
            "pruning": {
                "strategy": self.config['pruning_strategy'],
                "keep_recent": self.config['pruning_keep_recent'],
                "keep_every": self.config['pruning_keep_every'],
                "interval": self.config['pruning_interval']
            },
            "ports": {
                "rpc": self.config['rpc_port'],
                "p2p": self.config['p2p_port'],
                "api": self.config['api_port'],
                "grpc": self.config['grpc_port'],
                "grpc_web": self.config['grpc_web_port'],
                "prometheus": self.config['prometheus_port'],
                "pprof": self.config['pprof_port'],
                "proxy_app": self.config['proxy_app_port']
            },
            "sync": {
                "method": self.config['sync_method'],
                "snapshot_url": self.config['snapshot_url'],
                "statesync_rpc": self.config['statesync_rpc'],
                "statesync_peer": self.config['statesync_peer']
            },
            "wasm": {
                "enabled": self.config['wasm_enabled'],
                "url": self.config['wasm_url']
            },
            "caddy": {
                "expose_rpc": self.config['expose_rpc'],
                "expose_api": self.config['expose_api'],
                "expose_grpc": self.config['expose_grpc'],
                "expose_json_rpc": self.config['expose_json_rpc'],
                "domain": self.config['domain'],
                "domain_pattern": self.config['domain_pattern']
            },
            "install": {
                "prerequisites": self.config['should_install_prerequisites'],
                "node_setup": self.config['setup_node_config'],
                "cosmovisor": self.config['setup_cosmovisor_config'],
                "sync_node": self.config['sync_node_config'],
                "caddy": self.config['setup_caddy_config']
            }
        }
        
        # Add JSON-RPC ports if enabled
        if self.config['json_rpc_enabled']:
            yaml_config["ports"]["json_rpc"] = self.config['json_rpc_port']
            yaml_config["ports"]["json_rpc_ws"] = self.config['json_rpc_ws_port']
        
        # Save to file
        save_config_to_file(yaml_config, config_path)
    
    def run(self) -> None:
        """Run the installer."""
        print_header("Cosmos Node Installer")
        
        while True:
            choice = self.show_main_menu()
            
            if choice == "1":  # Full installation
                self.gather_all_input()
                
                if self.config['should_install_prerequisites']:
                    self.node_setup.install_prerequisites()
                
                if self.config['setup_node_config']:
                    self.node_setup.setup_node()
                
                if self.config['setup_cosmovisor_config']:
                    self.cosmovisor_setup.install_cosmovisor()
                    self.cosmovisor_setup.setup_cosmovisor()
                
                if self.config['sync_node_config']:
                    self.node_sync.perform_sync()
                
                if self.config['setup_caddy_config']:
                    self.caddy_setup.install_caddy()
                    self.caddy_setup.setup_caddy()
            elif choice == "2":  # Node synchronization only
                self._gather_sync_input()
                self._update_module_configs()
                self.node_sync.perform_sync()
            elif choice == "3":  # Caddy configuration only
                self._gather_caddy_input()
                self._update_module_configs()
                self.caddy_setup.install_caddy()
                self.caddy_setup.setup_caddy()
            elif choice == "4":  # Install prerequisites only
                self.node_setup.install_prerequisites()
            elif choice == "5":  # Node setup only
                self.node_setup.gather_basic_node_info()
                self.node_setup.gather_files_input()
                self.node_setup.gather_pruning_input()
                self.node_setup.gather_ports_input()
                self._update_config_from_node_setup()
                self.node_setup.setup_node()
            elif choice == "6":  # Cosmovisor setup only
                if not self.config['binary_name'] or not self.config['node_home']:
                    self.node_setup.gather_basic_node_info()
                    self._update_config_from_node_setup()
                self.cosmovisor_setup.install_cosmovisor()
                self.cosmovisor_setup.setup_cosmovisor()
            elif choice == "7":  # Display configuration
                self.display_config_summary()
            elif choice == "8":  # Start/enable node service
                self.service_manager.start_enable_service()
            elif choice == "9":  # Show node logs
                self.service_manager.show_node_logs()
            elif choice == "10":  # Exit
                print_header("Exiting")
                break
            else:
                print_warning("Invalid choice, please try again")

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="Cosmos Node Installer")
    parser.add_argument("--config", help="Path to configuration file")
    args = parser.parse_args()
    
    config_path = args.config
    
    if not config_path:
        config_path = find_config_file()
        if config_path:
            print(f"Found configuration file: {config_path}")
    
    installer = CosmosNodeInstaller(config_path)
    installer.run()

if __name__ == "__main__":
    main()
