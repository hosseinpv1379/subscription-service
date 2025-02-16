#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_PATH="/opt/subscription/config.json"
TEMP_FILE="/tmp/temp_config.json"

# Function to add a server
add_server() {
    echo -e "${BLUE}Adding new server configuration${NC}"
    read -p "Enter server name: " name
    read -p "Enter server IP: " ip
    read -p "Enter server port (default: 443): " port
    port=${port:-443}
    read -p "Enter obfuscation password: " obfs_pass

    # Create temporary file if config doesn't exist
    if [ ! -f "$CONFIG_PATH" ]; then
        echo '{"subscription":{"servers":[]}}' > "$CONFIG_PATH"
    fi

    # Add new server
    jq --arg name "$name" \
       --arg ip "$ip" \
       --arg port "$port" \
       --arg pass "$obfs_pass" \
       '.subscription.servers += [{"name": $name, "ip": $ip, "port": ($port|tonumber), "obfs": "salamander", "obfs_password": $pass}]' \
       "$CONFIG_PATH" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_PATH"

    restart_services
    echo -e "${GREEN}Server added successfully${NC}"
}

# Function to list servers
list_servers() {
    if [ -f "$CONFIG_PATH" ]; then
        echo -e "${BLUE}Current server configurations:${NC}"
        jq -r '.subscription.servers[] | "Name: \(.name)\nIP: \(.ip)\nPort: \(.port)\n---"' "$CONFIG_PATH"
    else
        echo -e "${RED}No configuration file found${NC}"
    fi
}

# Function to remove a server
remove_server() {
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${RED}No configuration file found${NC}"
        return
    fi

    echo -e "${BLUE}Current servers:${NC}"
    jq -r '.subscription.servers[] | .name' "$CONFIG_PATH" | nl

    read -p "Enter the number of the server to remove: " number
    
    jq "del(.subscription.servers[$(($number-1))])" "$CONFIG_PATH" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_PATH"
    
    restart_services
    echo -e "${GREEN}Server removed successfully${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${BLUE}Restarting services...${NC}"
    systemctl restart subscription
    systemctl restart nginx
    echo -e "${GREEN}Services restarted successfully${NC}"
}

# Main menu
while true; do
    echo -e "\n${BLUE}Server Management Menu${NC}"
    echo "1. Add server"
    echo "2. List servers"
    echo "3. Remove server"
    echo "4. Exit"
    
    read -p "Select an option: " choice
    
    case $choice in
        1) add_server ;;
        2) list_servers ;;
        3) remove_server ;;
        4) exit ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
