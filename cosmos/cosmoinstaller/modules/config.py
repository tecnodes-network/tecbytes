"""
Cosmos Node Installer - Configuration Module

This module handles loading and saving configuration files.
"""

import os
import yaml
from typing import Dict, Optional

from .utils import print_header, print_step, print_success, print_warning, print_error

def load_config_file(config_path: str) -> Dict:
    """
    Load a YAML configuration file.
    
    Args:
        config_path: Path to the YAML configuration file
        
    Returns:
        Dictionary containing the configuration
    """
    try:
        with open(config_path, 'r') as file:
            config = yaml.safe_load(file)
        return config if config else {}
    except Exception as e:
        print_error(f"Failed to load configuration file: {e}")
        return {}

def find_config_file() -> Optional[str]:
    """
    Find a configuration file in the current directory or its parents.
    
    Returns:
        Path to the configuration file, or None if not found
    """
    current_dir = os.getcwd()
    
    # Check current directory first
    for filename in os.listdir(current_dir):
        if filename.endswith('_config.yaml') or filename == 'config.yaml':
            return os.path.join(current_dir, filename)
    
    # Then check parent directories
    parent_dir = os.path.dirname(current_dir)
    if parent_dir != current_dir:  # Avoid infinite loop at root
        for filename in os.listdir(parent_dir):
            if filename.endswith('_config.yaml') or filename == 'config.yaml':
                return os.path.join(parent_dir, filename)
    
    return None

def save_config_to_file(config_data: Dict, config_path: str) -> None:
    """
    Save configuration to a YAML file.
    
    Args:
        config_data: Dictionary containing the configuration
        config_path: Path to save the configuration file
    """
    print_header(f"Saving configuration to {config_path}")
    
    try:
        with open(config_path, "w") as f:
            yaml.dump(config_data, f, default_flow_style=False)
        print_success("Configuration saved successfully")
    except Exception as e:
        print_error(f"Failed to save configuration: {e}")
