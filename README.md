# Multi-Protocol Subscription Service Setup Guide

## Prerequisites
- Ubuntu 20.04 or newer
- Domain pointed to your server
- Root access

## Step-by-Step Installation

### 1. Initial Server Setup
```bash
apt update
apt upgrade -y
apt install -y python3 python3-pip python3-venv nginx certbot jq
```

### 2. Create Project Directory and Setup Python Environment
```bash
mkdir -p /opt/subscription
cd /opt/subscription
python3 -m venv venv
source venv/bin/activate
pip install flask requests python-dateutil gunicorn
```

### 3. Configure Nginx (Initial HTTP Setup)
```bash
# Remove default config
rm -f /etc/nginx/sites-enabled/default

# Create Nginx configuration
cat > /etc/nginx/sites-available/subscription << 'EOF'
server {
    listen 80;
    server_name your_domain.com;
    
    root /var/www/html;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
```

### 4. Get SSL Certificate
```bash
# Stop nginx temporarily
systemctl stop nginx

# Get certificate
certbot certonly --standalone -d your_domain.com --agree-tos --non-interactive --email admin@your_domain.com

# Start nginx
systemctl start nginx
```

### 5. Configure Nginx with SSL
```bash
cat > /etc/nginx/sites-available/subscription << 'EOF'
server {
    listen 80;
    server_name your_domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name your_domain.com;

    ssl_certificate /etc/letsencrypt/live/your_domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your_domain.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

nginx -t && systemctl restart nginx
```

### 6. Create Configuration File
```bash
cat > /opt/subscription/config.json << EOF
{
  "subscription": {
    "servers": [
      {
        "name": "Server 1",
        "ip": "your_server_ip",
        "port": 443,
        "obfs": "salamander",
        "obfs_password": "your_obfs_password"
      }
    ],
    "subscription_names": {
      "client1": "Provider 1"
    },
    "api": {
      "base_url": "https://your-api-domain",
      "endpoint": "/link"
    },
    "port": 5000
  }
}
EOF
```

### 7. Copy Application Files
Copy your Python application files to `/opt/subscription/src/`

### 8. Create Systemd Service
```bash
cat > /etc/systemd/system/subscription.service << EOF
[Unit]
Description=Subscription Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/subscription
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/subscription/venv/bin/python /opt/subscription/src/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable subscription
systemctl start subscription
```

## Service Management

### Check Service Status
```bash
systemctl status subscription
```

### View Logs
```bash
journalctl -u subscription -f
```

### Restart Service
```bash
systemctl restart subscription
```

## Troubleshooting

### SSL Certificate Issues
```bash
# Renew certificate manually
certbot renew --force-renewal
systemctl restart nginx
```

### Nginx Configuration Test
```bash
nginx -t
```

### Check Ports
```bash
netstat -tulpn | grep -E ':80|:443'
```

### View Error Logs
```bash
tail -f /var/log/nginx/error.log
journalctl -u subscription -f
```

## Adding New Servers

To add a new server, edit `/opt/subscription/config.json` and add server details to the `servers` array:
```json
{
  "name": "New Server",
  "ip": "new_server_ip",
  "port": 443,
  "obfs": "salamander",
  "obfs_password": "new_password"
}
```

After editing, restart the service:
```bash
systemctl restart subscription
```

## Security Recommendations

1. Configure UFW:
```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

2. Secure file permissions:
```bash
chmod 600 /opt/subscription/config.json
```

3. Regular updates:
```bash
apt update && apt upgrade -y
```

## Important Notes
- Replace `your_domain.com` with your actual domain
- Replace `your_server_ip` with your server's IP
- Update API endpoints in config.json
- Ensure your domain's DNS is properly configured
- Make sure ports 80 and 443 are open in your firewall
