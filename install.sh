#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check root access
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Configure service
configure_service() {
    echo -e "Configuring subscription service..."
    
    # Get user input
    read -p "Enter your domain: " domain
    read -p "Enter server IP: " server_ip
    read -p "Enter Hysteria2 port (default: 443): " server_port
    server_port=${server_port:-443}
    
    # Create config.json
    cat > /opt/subscription/config.json << EOF
{
  "subscription": {
    "servers": [
      {
        "name": "Server 1",
        "ip": "$server_ip",
        "port": $server_port,
        "obfs": "salamander",
        "obfs_password": "2bxq67sohw9k1av83vk8f7h2it6v95b63xyitu2f0n50yxbq"
      }
    ],
    "subscription_names": {
      "client1": "Provider 1"
    },
    "api": {
      "base_url": "https://bugde1-alphatm.best",
      "endpoint": "/link"
    },
    "port": 5000
  }
}
EOF
}

# Install required packages
install_requirements() {
    apt-get update
    apt-get install -y python3 python3-pip nginx certbot python3-certbot-nginx
    pip3 install -r requirements.txt
}

# Configure Nginx
configure_nginx() {
    cat > /etc/nginx/sites-available/subscription << EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/
    certbot --nginx -d "$domain" --non-interactive --agree-tos --email admin@"$domain"
    systemctl restart nginx
}

# Install systemd service
install_service() {
    cat > /etc/systemd/system/subscription.service << EOF
[Unit]
Description=Subscription Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/subscription/src/app.py
Restart=always
User=root
WorkingDirectory=/opt/subscription

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable subscription
    systemctl start subscription
}

# Main installation
echo -e "${GREEN}Starting installation...${NC}"

# Create directories and copy files
mkdir -p /opt/subscription
cp -r src/* /opt/subscription/

configure_service
install_requirements
configure_nginx
install_service

echo -e "${GREEN}Installation completed!${NC}"
