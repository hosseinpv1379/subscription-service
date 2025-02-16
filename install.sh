#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Temporary file for servers configuration
TEMP_SERVERS="/tmp/servers.json"

# Function to add a server
add_server() {
    echo -e "${BLUE}Adding new server configuration${NC}"
    read -p "Enter server name: " name
    read -p "Enter server IP: " ip
    read -p "Enter server port (default: 443): " port
    port=${port:-443}
    read -p "Enter obfuscation password (default: 2bxq67sohw9k1av83vk8f7h2it6v95b63xyitu2f0n50yxbq): " obfs_pass
    obfs_pass=${obfs_pass:-"2bxq67sohw9k1av83vk8f7h2it6v95b63xyitu2f0n50yxbq"}

    if [ ! -f "$TEMP_SERVERS" ]; then
        echo "[]" > "$TEMP_SERVERS"
    fi

    tmp=$(mktemp)
    jq --arg name "$name" \
       --arg ip "$ip" \
       --arg port "$port" \
       --arg pass "$obfs_pass" \
       '. += [{"name": $name, "ip": $ip, "port": ($port|tonumber), "obfs": "salamander", "obfs_password": $pass}]' \
       "$TEMP_SERVERS" > "$tmp" && mv "$tmp" "$TEMP_SERVERS"

    echo -e "${GREEN}Server added successfully${NC}"
}

# Function to list servers
list_servers() {
    if [ -f "$TEMP_SERVERS" ]; then
        echo -e "${BLUE}Current server configurations:${NC}"
        jq -r '.[] | "Name: \(.name)\nIP: \(.ip)\nPort: \(.port)\n---"' "$TEMP_SERVERS"
    else
        echo -e "${RED}No servers configured yet${NC}"
    fi
}

# Function to remove a server
remove_server() {
    if [ ! -f "$TEMP_SERVERS" ]; then
        echo -e "${RED}No servers configured yet${NC}"
        return
    fi

    echo -e "${BLUE}Current servers:${NC}"
    jq -r '.[] | .name' "$TEMP_SERVERS" | nl

    read -p "Enter the number of the server to remove: " number
    
    tmp=$(mktemp)
    jq "del(.[$(($number-1)))]" "$TEMP_SERVERS" > "$tmp" && mv "$tmp" "$TEMP_SERVERS"
    
    echo -e "${GREEN}Server removed successfully${NC}"
}

# Server configuration menu
configure_servers() {
    while true; do
        echo -e "\n${BLUE}Server Configuration Menu${NC}"
        echo "1. Add server"
        echo "2. List servers"
        echo "3. Remove server"
        echo "4. Continue with installation"
        echo "5. Exit"
        
        read -p "Select an option: " choice
        
        case $choice in
            1) add_server ;;
            2) list_servers ;;
            3) remove_server ;;
            4) 
                if [ ! -f "$TEMP_SERVERS" ] || [ "$(jq length "$TEMP_SERVERS")" -eq 0 ]; then
                    echo -e "${RED}Please add at least one server before continuing${NC}"
                else
                    break
                fi
                ;;
            5) exit ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Configure service
configure_service() {
    echo -e "${BLUE}Configuring subscription service...${NC}"
    
    read -p "Enter your domain: " domain
    
    mkdir -p /opt/subscription
    
    cat > /opt/subscription/config.json << EOF
{
  "subscription": {
    "servers": $(cat "$TEMP_SERVERS"),
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

    echo -e "${GREEN}Configuration created successfully${NC}"
}

# Install required packages
install_requirements() {
    echo -e "${BLUE}Installing required packages...${NC}"
    
    apt-get update
    apt-get install -y python3 python3-pip python3-venv python3-full nginx certbot

    mkdir -p /opt/subscription
    python3 -m venv /opt/subscription/venv
    
    /opt/subscription/venv/bin/pip install --no-cache-dir flask==3.0.0 requests==2.31.0 python-dateutil==2.8.2 gunicorn==21.2.0

    echo -e "${GREEN}Requirements installed successfully${NC}"
}

# Configure Nginx
configure_nginx() {
    echo -e "${BLUE}Configuring Nginx...${NC}"
    
    systemctl stop nginx

    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/subscription
    rm -f /etc/nginx/sites-enabled/subscription

    # Create nginx config without SSL
    cat > /etc/nginx/sites-available/subscription << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    access_log /var/log/nginx/subscription-access.log;
    error_log /var/log/nginx/subscription-error.log;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    access_log /var/log/nginx/subscription-access.log;
    error_log /var/log/nginx/subscription-error.log;

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$domain/chain.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 90;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/

    # Create webroot directory
    mkdir -p /var/www/html
    chown -R www-data:www-data /var/www/html

    # Get SSL certificate
    certbot certonly --webroot -w /var/www/html -d "$domain" --non-interactive --agree-tos --email "admin@$domain"

    # Test and restart nginx
    nginx -t && systemctl restart nginx

    echo -e "${GREEN}Nginx configured successfully${NC}"
}

# Install systemd service
install_service() {
    echo -e "${BLUE}Installing systemd service...${NC}"
    
    cat > /etc/systemd/system/subscription.service << EOF
[Unit]
Description=Subscription Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
Environment=PYTHONUNBUFFERED=1
WorkingDirectory=/opt/subscription
ExecStart=/opt/subscription/venv/bin/python /opt/subscription/src/app.py

[Install]
WantedBy=multi-user.target
EOF

    cp -r src/* /opt/subscription/

    systemctl daemon-reload
    systemctl enable subscription
    systemctl start subscription

    echo -e "${GREEN}Service installed successfully${NC}"
}

# Main installation
echo -e "${GREEN}Starting installation...${NC}"

# Check root access
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${BLUE}Installing jq...${NC}"
    apt-get update && apt-get install -y jq
fi

# Run installation steps
echo -e "${BLUE}Starting server configuration...${NC}"
configure_servers

echo -e "${BLUE}Creating service configuration...${NC}"
configure_service

echo -e "${BLUE}Installing requirements...${NC}"
install_requirements

echo -e "${BLUE}Configuring Nginx...${NC}"
configure_nginx

echo -e "${BLUE}Installing service...${NC}"
install_service

# Cleanup
rm -f "$TEMP_SERVERS"

echo -e "${GREEN}Installation completed!${NC}"
echo -e "You can check the service status with: ${BLUE}systemctl status subscription${NC}"
