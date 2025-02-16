from flask import Flask, request, Response
import requests
import base64
import json
from datetime import datetime
from typing import Dict, Optional, Tuple, List
from dataclasses import dataclass
import os

app = Flask(__name__)

def load_config() -> Dict:
   """Load configuration from JSON file"""
   config_path = os.path.join(os.path.dirname(__file__), 'config.json')
   with open(config_path, 'r') as f:
       return json.load(f)

@dataclass
class ServerConfig:
   name: str
   ip: str
   port: int
   obfs: str
   obfs_password: str

class ConfigGenerator:
   def __init__(self, servers: List[ServerConfig]):
       self.servers = servers

   def create_hysteria2_configs(self, token: str, name: str) -> List[str]:
       """Generate Hysteria2 configuration links for all servers"""
       configs = []
       for server in self.servers:
           config = (f"hysteria2://{token}@{server.ip}:{server.port}?"
                    f"fastopen=0&obfs={server.obfs}&"
                    f"obfs-password={server.obfs_password}#{name} - {server.name}\n")
           configs.append(config)
       return configs

   def process_vmess_config(self, config: Dict, expire_time: Optional[int] = None) -> Dict:
       """Process and update VMESS configuration"""
       name = config['ps']
       
       if "Expire:" in name and expire_time:
           time_diff = self.calculate_time_difference(expire_time)
           name = f"{time_diff}"
           
       name = name.replace("Used", 'Used ')\
                  .replace("Total", 'Total ')\
                  .replace("GB", "GB")
       
       config['ps'] = name
       return config

   @staticmethod
   def calculate_time_difference(timestamp: int) -> str:
       """Calculate and format time difference"""
       try:
           target_date = datetime.fromtimestamp(timestamp)
           time_diff = target_date - datetime.now()
           total_hours = time_diff.total_seconds() / 3600

           if time_diff.total_seconds() < 0:
               return "(Expired)"
           elif total_hours < 24:
               hours = int(total_hours)
               minutes = int((total_hours - hours) * 60)
               return f"⏳ {hours}h {minutes}m remaining"
           else:
               remaining_hours = int(time_diff.seconds / 3600)
               return f"⏳ {time_diff.days}d {remaining_hours}h remaining"

       except Exception as e:
           return f"Error calculating time: {str(e)}"

class SubscriptionHandler:
   def __init__(self, config_generator: ConfigGenerator, config: Dict):
       self.generator = config_generator
       self.config = config['subscription']
       self.subscription_names = config['subscription']['subscription_names']
       self.api_config = config['subscription']['api']
       self.default_vmess = config['subscription']['default_vmess']

   def process_subscription(self, token: str, query: str) -> Tuple[str, dict]:
       """Process subscription request and generate configuration"""
       response = requests.get(
           f"{self.api_config['base_url']}{self.api_config['endpoint']}/{token}?client=all"
       )
       sub_info = response.headers.get('subscription-userinfo', '')
       profile_interval = response.headers.get('profile-update-interval', '24')

       try:
           expire_time = int(sub_info.split(';')[5].split('=')[1])
       except:
           expire_time = None

       decoded_configs = base64.b64decode(response.text).decode('utf-8').split("\n")
       processed_configs = [
           f"vmess://{base64.b64encode(base64.b64decode(self.default_vmess)).decode()}\n"
       ]
       
       hysteria_token = None
       for config in decoded_configs:
           if "vmess://" in config:
               vmess_config = json.loads(base64.b64decode(config[8:]))
               processed_config = self.generator.process_vmess_config(vmess_config, expire_time)
               encoded_config = base64.b64encode(json.dumps(processed_config).encode()).decode()
               processed_configs.append(f"vmess://{encoded_config}\n")
           else:
               subscribe_name = self.subscription_names.get(query, "Default")
               processed_configs.append(f"{config} | {subscribe_name}\n")
               if not hysteria_token and config:
                   hysteria_token = config.split('@')[0].split('//')[1]

       if hysteria_token:
           processed_configs.extend(
               self.generator.create_hysteria2_configs(hysteria_token, self.subscription_names.get(query, "Default"))
           )

       return (
           base64.b64encode(''.join(processed_configs).encode('utf-8')),
           {'subscription-userinfo': sub_info, 'profile-update-interval': profile_interval}
       )

# Load configuration at startup
CONFIG = load_config()
SERVERS = [ServerConfig(**server) for server in CONFIG['subscription']['servers']]

@app.route("/link/<string:token>")
def handle_subscription(token):
   try:
       query = request.args.get("client", "")
       
       handler = SubscriptionHandler(ConfigGenerator(SERVERS), CONFIG)
       content, headers = handler.process_subscription(token, query)

       response = Response(
           content,
           mimetype='application/octet-stream; charset=utf-8'
       )

       response.headers.update({
           'Server': 'nginx',
           'Content-Disposition': 'attachment; filename*=UTF-8\'\'Config.txt',
           'Cache-Control': 'no-store, no-cache, must-revalidate',
           'Access-Control-Allow-Origin': '/',
           'Access-Control-Allow-Headers': '',
           'X-Content-Type-Options': 'nosniff',
           'X-XSS-Protection': '1; mode=block',
           'Content-Security-Policy': "frame-ancestors 'self'",
           'Strict-Transport-Security': 'max-age=31536000',
           **headers
       })

       return response

   except Exception as e:
       return str(e), 400

if __name__ == "__main__":
   port = CONFIG['subscription'].get('port', 5000)
   app.run(host='127.0.0.1', port=port)
