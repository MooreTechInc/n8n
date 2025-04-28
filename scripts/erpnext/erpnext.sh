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
DOMAIN="EFFECTIVEDOMAIN"
USER_MAIL="admin@mooretech.io"
FRAPPE_PORT=8090  # Non-default internal port

# ------------------------------
# Helper Functions
# ------------------------------
safe_symlink() {
  local source="$1"
  local target="$2"
  if [ -L "$target" ]; then
    echo "🔁 Symlink $target already exists. Skipping."
  elif [ -e "$target" ]; then
    echo "⚠️ $target exists and is not a symlink. Skipping."
  else
    ln -s "$source" "$target" && echo "✅ Created symlink: $target"
  fi
}

install_if_missing() {
  local pkg="$1"
  if ! dpkg -s "$pkg" &> /dev/null; then
    apt install -y "$pkg"
  else
    echo "🔍 Package $pkg already installed. Skipping."
  fi
}

# ------------------------------
# Install Required Packages
# ------------------------------
echo "📦 Installing required packages..."
apt update
for pkg in nginx certbot python3-certbot-nginx docker.io docker-compose git; do
  install_if_missing "$pkg"
done

# ------------------------------
# Start and Enable Services
# ------------------------------
echo "🚀 Starting and enabling services..."
systemctl enable nginx && systemctl restart nginx
systemctl enable docker && systemctl start docker

# ------------------------------
# Run Docker Compose
# ------------------------------
echo "🐳 Setting up frappe_docker..."
if [ ! -d "frappe_docker" ]; then
  git clone https://github.com/frappe/frappe_docker
  cd frappe_docker
else
  cd frappe_docker
  git pull
fi

# Update compose file port mapping if necessary
if ! grep -q "$FRAPPE_PORT" pwd.yml; then
  echo "⚙️ Replacing port in Docker Compose file..."
  sed -i "s/8080:80/$FRAPPE_PORT:80/" pwd.yml || echo "⚠️ Couldn't update port. Please check manually."
  cp pwd.yml docker-compose.yml
fi

# Check if the existing containers are running
if docker ps -q -f name=frappe | grep -q .; then
  echo "🔄 Stopping existing Frappe container..."
  docker-compose -f pwd.yml down
else
  echo "ℹ️ No existing Frappe container found."
fi

docker-compose -f pwd.yml up -d
if docker ps -q -f name=frappe | grep -q .; then
  echo "✅ Frappe container is running."
else
  echo "❌ Frappe container is not running."
  exit 1
fi 

# ------------------------------
# NGINX Configuration
# ------------------------------
echo "🔒 Configuring NGINX reverse proxy..."

NGINX_SITE_PATH="/etc/nginx/sites-available/erpnext"
cat > "$NGINX_SITE_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$FRAPPE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

safe_symlink "$NGINX_SITE_PATH" /etc/nginx/sites-enabled/erpnext

echo "🧪 Testing and reloading NGINX..."
nginx -t && systemctl reload nginx || echo "⚠️ NGINX test failed. Check config manually."

# ------------------------------
# Run Certbot
# ------------------------------
if [[ "$DOMAIN" == "ERPNEXTDOMAIN" ]]; then
  echo "⚠️ DOMAIN is still set to placeholder. Skipping Certbot setup."
else
  echo "🔐 Running Certbot for $DOMAIN..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$USER_MAIL" || {
    echo "⚠️ Certbot failed. Check domain DNS and nginx config.";
    true
  }
fi

# ------------------------------
# Done!
# ------------------------------
echo "🎉 ERPNext setup completed! Access it via: https://$DOMAIN"