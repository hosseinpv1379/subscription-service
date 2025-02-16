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
       echo '{"subscription":{"servers":[],"subscription_names":{}}}' > "$CONFIG_PATH"
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

# Function to add a provider
add_provider() {
   echo -e "${BLUE}Adding new provider${NC}"
   read -p "Enter provider key (e.g., client1): " key
   read -p "Enter provider name: " name

   if [ ! -f "$CONFIG_PATH" ]; then
       echo '{"subscription":{"servers":[],"subscription_names":{}}}' > "$CONFIG_PATH"
   fi

   # Add new provider
   jq --arg key "$key" \
      --arg name "$name" \
      '.subscription.subscription_names += {($key): $name}' \
      "$CONFIG_PATH" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_PATH"

   restart_services
   echo -e "${GREEN}Provider added successfully${NC}"
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

# Function to list providers
list_providers() {
   if [ -f "$CONFIG_PATH" ]; then
       echo -e "${BLUE}Current providers:${NC}"
       jq -r '.subscription.subscription_names | to_entries[] | "Key: \(.key)\nName: \(.value)\n---"' "$CONFIG_PATH"
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

# Function to remove a provider
remove_provider() {
   if [ ! -f "$CONFIG_PATH" ]; then
       echo -e "${RED}No configuration file found${NC}"
       return
   fi

   echo -e "${BLUE}Current providers:${NC}"
   jq -r '.subscription.subscription_names | keys[]' "$CONFIG_PATH" | nl

   read -p "Enter the number of the provider to remove: " number
   
   # Get the key of the provider to remove
   provider_key=$(jq -r ".subscription.subscription_names | keys[$(($number-1))]" "$CONFIG_PATH")
   
   # Remove the provider
   jq "del(.subscription.subscription_names[\"$provider_key\"])" "$CONFIG_PATH" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_PATH"
   
   restart_services
   echo -e "${GREEN}Provider removed successfully${NC}"
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
   echo -e "\n${BLUE}Management Menu${NC}"
   echo "1. Add server"
   echo "2. List servers"
   echo "3. Remove server"
   echo "4. Add provider"
   echo "5. List providers"
   echo "6. Remove provider"
   echo "7. Exit"
   
   read -p "Select an option: " choice
   
   case $choice in
       1) add_server ;;
       2) list_servers ;;
       3) remove_server ;;
       4) add_provider ;;
       5) list_providers ;;
       6) remove_provider ;;
       7) exit ;;
       *) echo -e "${RED}Invalid option${NC}" ;;
   esac
done
