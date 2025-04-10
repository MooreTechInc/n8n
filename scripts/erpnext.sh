#!/bin/bash

set -euo pipefail

# ------------------------------
# Must run as root
# ------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo or log in as root."
  exit 1
fi

# ------------------------------
# Configurable Variables
# ------------------------------
WP_DOMAIN="erpnext.mooretech.io"

# ------------------------------
# Install Required Packages
# ------------------------------

echo "📦 Installing NGINX, Certbot, and Docker..."
apt update
apt install -y nginx certbot python3-certbot-nginx docker.io docker-compose || {
  echo "❌ Failed to install one or more packages."; exit 1;
}

# ------------------------------
# Start and Enable Services
# ------------------------------
echo "🚀 Starting services..."
systemctl enable nginx && systemctl restart nginx
systemctl enable docker && systemctl start docker

# ------------------------------
# Run Docker Compose
# ------------------------------
echo "🐳 Running Docker Compose..."
curl -O https://raw.githubusercontent.com/frappe/frappe_docker/main/pwd.yml
docker compose -f pwd.yml up -d

# ------------------------------
# NGINX Configuration
# ------------------------------

echo "🔒 Configuring NGINX..."
cat > /etc/nginx/sites-available/erpnext <<EOF
server {
    listen 80;
    server_name $WP_DOMAIN;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/erpnext /etc/nginx/sites-enabled/erpnext
nginx -t && systemctl reload nginx

# ------------------------------
# Run Certbot
# ------------------------------
echo "🔐 Running Certbot..."
certbot --nginx -d $WP_DOMAIN --non-interactive --agree-tos -m admin@$WP_DOMAIN

# ------------------------------
# Done!
# ------------------------------
echo "✅ All done! ERPNext is live at: https://$WP_DOMAIN"



