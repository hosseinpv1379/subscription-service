import json
import os
from typing import Dict, Any, Optional
from dataclasses import dataclass

@dataclass
class ServerConfig:
    name: str
    ip: str
    port: int
    obfs: str
    obfs_password: str

@dataclass
class APIConfig:
    base_url: str
    endpoint: str

@dataclass
class SubscriptionConfig:
    servers: list[ServerConfig]
    subscription_names: Dict[str, str]
    api: APIConfig
    port: int

class ConfigManager:
    def __init__(self, config_path: str = "/opt/subscription/config.json"):
        self.config_path = config_path
        self.config: Dict[str, Any] = self._load_config()

    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            raise Exception(f"Configuration file not found at {self.config_path}")
        except json.JSONDecodeError:
            raise Exception("Invalid JSON in configuration file")

    def get_server_configs(self) -> list[ServerConfig]:
        """Get list of server configurations"""
        servers = self.config['subscription']['servers']
        return [ServerConfig(**server) for server in servers]

    def get_subscription_names(self) -> Dict[str, str]:
        """Get subscription name mappings"""
        return self.config['subscription']['subscription_names']

    def get_api_config(self) -> APIConfig:
        """Get API configuration"""
        return APIConfig(**self.config['subscription']['api'])

    def get_port(self) -> int:
        """Get service port"""
        return self.config['subscription']['port']

    def reload_config(self) -> None:
        """Reload configuration from file"""
        self.config = self._load_config()

    def get_subscription_config(self) -> SubscriptionConfig:
        """Get complete subscription configuration"""
        sub_config = self.config['subscription']
        return SubscriptionConfig(
            servers=[ServerConfig(**s) for s in sub_config['servers']],
            subscription_names=sub_config['subscription_names'],
            api=APIConfig(**sub_config['api']),
            port=sub_config['port']
        )

    def validate_config(self) -> bool:
        """Validate configuration structure and values"""
        required_keys = ['subscription']
        sub_required_keys = ['servers', 'subscription_names', 'api', 'port']
        server_required_keys = ['name', 'ip', 'port', 'obfs', 'obfs_password']
        api_required_keys = ['base_url', 'endpoint']

        try:
            # Check main structure
            for key in required_keys:
                if key not in self.config:
                    raise ValueError(f"Missing required key: {key}")

            sub_config = self.config['subscription']
            # Check subscription structure
            for key in sub_required_keys:
                if key not in sub_config:
                    raise ValueError(f"Missing required subscription key: {key}")

            # Check servers configuration
            for server in sub_config['servers']:
                for key in server_required_keys:
                    if key not in server:
                        raise ValueError(f"Missing required server key: {key}")

            # Check API configuration
            for key in api_required_keys:
                if key not in sub_config['api']:
                    raise ValueError(f"Missing required API key: {key}")

            return True

        except Exception as e:
            print(f"Configuration validation failed: {str(e)}")
            return False

def get_config_manager() -> ConfigManager:
    """Get singleton instance of ConfigManager"""
    if not hasattr(get_config_manager, 'instance'):
        get_config_manager.instance = ConfigManager()
    return get_config_manager.instance
