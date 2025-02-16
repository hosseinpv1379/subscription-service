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

    # Add server to temporary file
    if [ ! -f "$TEMP_SERVERS" ]; then
        echo "[]" > "$TEMP_SERVERS"
    fi

    # Add new server to JSON array
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
    
    # Create directories
    mkdir -p /opt/subscription
    
    # Create config.json using the servers from TEMP_SERVERS
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
    
    # Install system packages
    apt-get update
    apt-get install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx

    # Create and activate virtual environment
    python3 -m venv /opt/subscription/venv
    
    # Install Python packages in virtual environment
    /opt/subscription/venv/bin/pip install flask requests python-dateutil gunicorn

    echo -e "${GREEN}Requirements installed successfully${NC}"
}

# Configure Nginx
configure_nginx() {
    echo -e "${BLUE}Configuring Nginx...${NC}"
    
    # Remove default config
    rm -f /etc/nginx/sites-enabled/default

    # Create initial nginx config without SSL
    cat > /etc/nginx/sites-available/subscription << EOF
server {
    listen 80;
    server_name $domain;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    nginx -t && systemctl restart nginx

    echo -e "${BLUE}Obtaining SSL certificate...${NC}"
    
    # Get SSL certificate
    certbot --nginx -d "$domain" --non-interactive --agree-tos --email admin@"$domain"

    echo -e "${GREEN}Nginx configured successfully${NC}"
}

# Install systemd service
install_service() {
    echo -e "${BLUE}Installing systemd service...${NC}"
    
    # Create service file
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

    # Copy application files
    cp -r src/* /opt/subscription/

    # Reload systemd and enable service
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

# Configure servers first
configure_servers

# Run installation steps
configure_service
install_requirements
configure_nginx
install_service

# Cleanup
rm -f "$TEMP_SERVERS"

echo -e "${GREEN}Installation completed!${NC}"
echo -e "You can check the service status with: ${BLUE}systemctl status subscription${NC}"
