# راهنمای نصب و راه‌اندازی سرویس سابسکریپشن

## پیش‌نیازها
- سرور با سیستم‌عامل Ubuntu 20.04 یا بالاتر
- دسترسی root
- دامنه فعال متصل به IP سرور
- پورت‌های 80 و 443 باز

## نصب از گیت‌هاب

```bash
# کلون کردن مخزن
git clone https://github.com/hosseinpv1379/subscription-service.git
cd subscription-service

# نصب پیش‌نیازها
apt update
apt install -y python3 python3-pip python3-venv nginx certbot jq

# ساخت محیط مجازی پایتون
mkdir -p /opt/subscription
cd /opt/subscription
python3 -m venv venv
source venv/bin/activate
pip install flask requests python-dateutil gunicorn

# کپی فایل‌های برنامه
cp -r ../subscription-service/src/* .
```

## پیکربندی Nginx و SSL

```bash
# حذف کانفیگ پیش‌فرض
rm -f /etc/nginx/sites-enabled/default

# ایجاد کانفیگ جدید - جایگزین your_domain.com با دامنه خود کنید
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

# فعال‌سازی کانفیگ
ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/

# دریافت SSL - جایگزین your_domain.com با دامنه خود کنید
certbot certonly --standalone -d your_domain.com --agree-tos --non-interactive --email admin@your_domain.com

# آپدیت کانفیگ Nginx با SSL
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

# راه‌اندازی مجدد Nginx
nginx -t && systemctl restart nginx
```

## راه‌اندازی سرویس

```bash
# ایجاد فایل سرویس
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

# فعال‌سازی و شروع سرویس
systemctl daemon-reload
systemctl enable subscription
systemctl start subscription
```

## نصب اسکریپت مدیریت

```bash
# کپی اسکریپت مدیریت
cp ../subscription-service/manage-subscription.sh /usr/local/bin/
chmod +x /usr/local/bin/manage-subscription.sh
```

## استفاده از اسکریپت مدیریت

برای مدیریت سرورها و پروایدرها، دستور زیر را اجرا کنید:
```bash
manage-subscription.sh
```

این اسکریپت امکانات زیر را دارد:
1. اضافه کردن سرور جدید
2. نمایش لیست سرورها
3. حذف سرور
4. اضافه کردن پروایدر جدید
5. نمایش لیست پروایدرها
6. حذف پروایدر

## دستورات مفید

بررسی وضعیت سرویس:
```bash
systemctl status subscription
```

مشاهده لاگ‌ها:
```bash
journalctl -u subscription -f
```

راه‌اندازی مجدد سرویس:
```bash
systemctl restart subscription
```

## عیب‌یابی رایج

### مشکل SSL
```bash
certbot renew --force-renewal
systemctl restart nginx
```

### مشکل دسترسی به پورت
```bash
lsof -i :80
lsof -i :443
```

### مشکل فایل لاگ
```bash
tail -f /var/log/nginx/error.log
```

## نکات امنیتی

تنظیم فایروال:
```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

محدود کردن دسترسی‌ها:
```bash
chmod 600 /opt/subscription/config.json
```

## بروزرسانی

برای بروزرسانی سرویس:
```bash
cd /opt/subscription
git pull origin main
systemctl restart subscription
```

## لینک‌های مفید
- [گیت‌هاب پروژه](https://github.com/hosseinpv1379/subscription-service)
- [گزارش مشکلات](https://github.com/hosseinpv1379/subscription-service/issues)

## نکات مهم
- قبل از نصب، از اشاره دامنه به IP سرور مطمئن شوید
- همه‌ی دستورات باید با دسترسی root اجرا شوند
- بعد از هر تغییر در کانفیگ‌ها، سرویس‌ها را ری‌استارت کنید
- از فایل‌های کانفیگ به صورت منظم بکاپ بگیرید
