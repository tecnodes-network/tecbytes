"""
Cosmos Node Installer - Sync Module

This module handles node synchronization methods (snapshot, statesync).
"""

import os
import re
import shutil
import tempfile
import json
import requests
from typing import Dict, Any, Optional, Tuple

from .utils import (
    print_header, print_step, print_success, print_warning, print_error,
    run_command, ensure_pv_installed
)

class NodeSync:
    """Class for synchronizing a Cosmos-based blockchain node."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the node sync with configuration.
        
        Args:
            config: Dictionary containing node configuration
        """
        # Node configuration
        self.binary_name = config.get('binary_name', "")
        self.binary_path = config.get('binary_path', "")
        self.node_home = config.get('node_home', "")
        
        # Sync configuration
        self.sync_method = config.get('sync_method', "none")
        self.snapshot_url = config.get('snapshot_url', "")
        self.statesync_rpc = config.get('statesync_rpc', "")
        self.statesync_peer = config.get('statesync_peer', "")
        
        # WASM configuration
        self.wasm_enabled = config.get('wasm_enabled', False)
        self.wasm_url = config.get('wasm_url', "")
    
    def perform_sync(self) -> None:
        """Synchronize the node using the selected method."""
        if self.sync_method == "none":
            print_step("No synchronization method selected, node will sync from scratch")
            return
        
        print_header(f"Synchronizing Node using {self.sync_method.upper()}")
        
        # Ensure pv is installed for download progress
        ensure_pv_installed()
        
        # Backup validator state if it exists
        if os.path.exists(f"{self.node_home}/data/priv_validator_state.json"):
            print_step("Backing up validator state")
            run_command(f"cp {self.node_home}/data/priv_validator_state.json {self.node_home}/priv_validator_state.json.backup")
        
        # Stop the node service if it's running
        print_step("Stopping node service")
        run_command(f"sudo systemctl stop {self.binary_name} || true")
        
        # Reset the node data
        print_step("Resetting node data")
        run_command(f"{self.binary_path} tendermint unsafe-reset-all --home {self.node_home}")
        
        if self.sync_method == "snapshot":
            self._sync_with_snapshot()
        elif self.sync_method == "statesync":
            self._sync_with_statesync()
        
        # Restore validator state if backup exists
        if os.path.exists(f"{self.node_home}/priv_validator_state.json.backup"):
            print_step("Restoring validator state")
            run_command(f"cp {self.node_home}/priv_validator_state.json.backup {self.node_home}/data/priv_validator_state.json")
        
        # Download WASM data if enabled
        if self.wasm_enabled and self.wasm_url:
            self._download_wasm_data()
        
        # Start the node service
        print_step("Starting node service")
        run_command(f"sudo systemctl start {self.binary_name}")
        
        print_success("Node synchronization completed successfully")
    
    def _sync_with_snapshot(self) -> None:
        """Sync using snapshot."""
        print_step("Syncing using snapshot")
        
        if not self.snapshot_url:
            print_error("No snapshot URL provided")
            return
        
        # Create temporary directory
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Download snapshot
            print_step(f"Downloading snapshot from {self.snapshot_url}")
            
            # Get filename from URL
            snapshot_filename = os.path.basename(self.snapshot_url)
            snapshot_path = f"{temp_dir}/{snapshot_filename}"
            
            # Download with progress
            run_command(f"wget -q -O - {self.snapshot_url} | pv -f -b > {snapshot_path}")
            
            # Extract snapshot
            print_step("Extracting snapshot")
            
            if snapshot_filename.endswith(".tar.lz4"):
                run_command(f"lz4 -d {snapshot_path} | pv -f -b | tar -xf - -C {self.node_home}")
            elif snapshot_filename.endswith(".tar.gz"):
                run_command(f"tar -xzf {snapshot_path} -C {self.node_home}")
            else:
                print_error(f"Unsupported snapshot format: {snapshot_filename}")
                return
            
            print_success("Snapshot extracted successfully")
            
        finally:
            # Clean up
            shutil.rmtree(temp_dir)
    
    def _sync_with_statesync(self) -> None:
        """Sync using state-sync."""
        print_step("Syncing using state-sync")
        
        if not self.statesync_rpc or not self.statesync_peer:
            print_error("State-sync RPC URL or peer not provided")
            return
        
        # Get trust height and hash
        print_step("Getting trust height and hash")
        
        trust_height, trust_hash = self._get_trust_height_and_hash()
        if not trust_height or not trust_hash:
            print_error("Failed to get trust height and hash")
            return
        
        # Update config.toml
        print_step("Updating config.toml for state-sync")
        self._update_statesync_config(trust_height, trust_hash)
        
        print_success("State-sync configuration updated successfully")
    
    def _get_trust_height_and_hash(self) -> Tuple[Optional[int], Optional[str]]:
        """
        Get trust height and hash for state-sync.
        
        Returns:
            Tuple of (trust_height, trust_hash)
        """
        try:
            # First try using direct HTTP request for better reliability
            print_step(f"Fetching latest block height from {self.statesync_rpc}")
            response = requests.get(f"{self.statesync_rpc}/block")
            if response.status_code == 200:
                data = response.json()
                latest_height = int(data['result']['block']['header']['height'])
                print_success(f"Latest block height: {latest_height}")
                
                # Calculate trust height (latest height - 2000)
                trust_height = latest_height - 2000
                print_step(f"Using trust height: {trust_height}")
                
                # Get trust hash
                print_step(f"Fetching trust hash for height {trust_height}")
                response = requests.get(f"{self.statesync_rpc}/block?height={trust_height}")
                if response.status_code == 200:
                    data = response.json()
                    trust_hash = data['result']['block_id']['hash']
                    print_success(f"Trust hash: {trust_hash}")
                    return trust_height, trust_hash
        except Exception as e:
            print_warning(f"Error using direct HTTP request: {e}")
            print_step("Falling back to curl command")
        
        # Fallback to curl command
        try:
            # Get latest block height
            print_step(f"Fetching latest block height using curl from {self.statesync_rpc}")
            latest_height_cmd = f"curl -s {self.statesync_rpc}/block | jq -r .result.block.header.height"
            _, latest_height_str, _ = run_command(latest_height_cmd, exit_on_error=False)
            
            if not latest_height_str or not latest_height_str.strip():
                print_error("Failed to get latest block height")
                return None, None
            
            latest_height = int(latest_height_str.strip())
            print_success(f"Latest block height: {latest_height}")
            
            # Calculate trust height (latest height - 2000)
            trust_height = latest_height - 2000
            print_step(f"Using trust height: {trust_height}")
            
            # Get trust hash
            print_step(f"Fetching trust hash for height {trust_height}")
            trust_hash_cmd = f"curl -s \"{self.statesync_rpc}/block?height={trust_height}\" | jq -r .result.block_id.hash"
            _, trust_hash_str, _ = run_command(trust_hash_cmd, exit_on_error=False)
            
            if not trust_hash_str or not trust_hash_str.strip() or trust_hash_str.strip() == "null":
                print_error(f"Failed to get trust hash for height {trust_height}")
                return None, None
            
            trust_hash = trust_hash_str.strip()
            print_success(f"Trust hash: {trust_hash}")
            
            return trust_height, trust_hash
        except Exception as e:
            print_error(f"Error using curl command: {e}")
            return None, None
    
    def _update_statesync_config(self, trust_height: int, trust_hash: str) -> None:
        """
        Update config.toml for state-sync.
        
        Args:
            trust_height: Trust height for state-sync
            trust_hash: Trust hash for state-sync
        """
        config_toml_path = f"{self.node_home}/config/config.toml"
        
        # Read config.toml line by line to avoid TOML parsing issues
        with open(config_toml_path, "r") as f:
            lines = f.readlines()
        
        # Process lines and update state-sync settings
        updated_lines = []
        in_statesync_section = False
        
        for line in lines:
            # Check if we're in the state-sync section
            if "[statesync]" in line:
                in_statesync_section = True
                updated_lines.append(line)
                continue
            
            # Check if we're leaving the state-sync section
            if in_statesync_section and line.strip().startswith("["):
                in_statesync_section = False
            
            # Update state-sync settings
            if in_statesync_section:
                if line.strip().startswith("enable ="):
                    updated_lines.append("enable = true\n")
                elif line.strip().startswith("rpc_servers ="):
                    updated_lines.append(f'rpc_servers = "{self.statesync_rpc},{self.statesync_rpc}"\n')
                elif line.strip().startswith("trust_height ="):
                    updated_lines.append(f"trust_height = {trust_height}\n")
                elif line.strip().startswith("trust_hash ="):
                    updated_lines.append(f'trust_hash = "{trust_hash}"\n')
                elif line.strip().startswith("trust_period ="):
                    updated_lines.append('trust_period = "168h"\n')
                else:
                    updated_lines.append(line)
            else:
                updated_lines.append(line)
        
        # Write updated config.toml
        with open(config_toml_path, "w") as f:
            f.writelines(updated_lines)
    
    def _download_wasm_data(self) -> None:
        """Download WASM data."""
        print_step("Downloading WASM data")
        
        # Create temporary directory
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Download WASM data
            print_step(f"Downloading WASM data from {self.wasm_url}")
            
            # Get filename from URL
            wasm_filename = os.path.basename(self.wasm_url)
            wasm_path = f"{temp_dir}/{wasm_filename}"
            
            # Download with progress
            run_command(f"wget -q -O - {self.wasm_url} | pv -f -b > {wasm_path}")
            
            # Extract WASM data
            print_step("Extracting WASM data")
            
            if wasm_filename.endswith(".tar.lz4"):
                run_command(f"lz4 -d {wasm_path} | pv -f -b | tar -xf - -C {self.node_home}")
            elif wasm_filename.endswith(".tar.gz"):
                run_command(f"tar -xzf {wasm_path} -C {self.node_home}")
            else:
                print_error(f"Unsupported WASM data format: {wasm_filename}")
                return
            
            print_success("WASM data extracted successfully")
            
        finally:
            # Clean up
            shutil.rmtree(temp_dir)
