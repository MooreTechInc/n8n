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
WP_DIR="/var/www/html"
WP_DB="wp"
WP_USER="wpadmin"
WP_PASSWORD=$(openssl rand -base64 18)
WP_CONFIG_FILE="$WP_DIR/wp-config.php"
WP_SECRETS_FILE="/root/wp_secrets.env"
NGINX_SITE_CONF="/etc/nginx/sites-available/wordpress"

# ------------------------------
# Clean up previous config & secrets
# ------------------------------
echo "🧹 Cleaning up previous config and secrets..."
[ -f "$WP_CONFIG_FILE" ] && rm -f "$WP_CONFIG_FILE" && echo "✅ Removed $WP_CONFIG_FILE"
[ -f "$WP_SECRETS_FILE" ] && rm -f "$WP_SECRETS_FILE" && echo "✅ Removed $WP_SECRETS_FILE"

# ------------------------------
# Install Required Packages
# ------------------------------
echo "📦 Installing NGINX, PHP, and MySQL..."
apt update
apt install -y nginx php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip mysql-server wget unzip certbot python3-certbot-nginx || {
  echo "❌ Failed to install one or more packages."; exit 1;
}

# ------------------------------
# Start and Enable Services
# ------------------------------
echo "🚀 Starting services..."
systemctl enable nginx && systemctl restart nginx
systemctl enable mysql && systemctl start mysql

# ------------------------------
# MySQL Setup
# ------------------------------
echo "👤 Configuring MySQL..."
DB_EXISTS=$(mysql -sse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$WP_DB'")
if [ "$DB_EXISTS" != "$WP_DB" ]; then
  mysql -e "CREATE DATABASE \`$WP_DB\`;" && echo "✅ Database $WP_DB created"
else
  echo "ℹ️ Database $WP_DB already exists"
fi

USER_EXISTS=$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$WP_USER')")
if [ "$USER_EXISTS" == 1 ]; then
  echo "ℹ️ User $WP_USER exists, updating password..."
  mysql -e "ALTER USER '$WP_USER'@'%' IDENTIFIED BY '$WP_PASSWORD';"
else
  mysql -e "CREATE USER '$WP_USER'@'%' IDENTIFIED BY '$WP_PASSWORD';"
  echo "✅ User $WP_USER created"
fi

mysql -e "GRANT ALL PRIVILEGES ON \`$WP_DB\`.* TO '$WP_USER'@'%';"
mysql -e "FLUSH PRIVILEGES;"
echo "✅ MySQL configuration done."

# ------------------------------
# Download and Configure WordPress
# ------------------------------
echo "📦 Downloading WordPress..."
wget -q -O /tmp/latest.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp/
cp -r /tmp/wordpress/* $WP_DIR
chown -R www-data:www-data $WP_DIR
cp $WP_DIR/wp-config-sample.php $WP_CONFIG_FILE

echo "⚙️ Configuring wp-config.php..."
sed -i "s#database_name_here#$WP_DB#" "$WP_CONFIG_FILE"
sed -i "s#username_here#$WP_USER#" "$WP_CONFIG_FILE"
sed -i "s#password_here#$WP_PASSWORD#" "$WP_CONFIG_FILE"

# ------------------------------
# Configure NGINX for WordPress
# ------------------------------
echo "⚙️ Creating NGINX server block..."
cat > "$NGINX_SITE_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $WP_DIR;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf "$NGINX_SITE_CONF" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
echo "✅ NGINX configured for WordPress."

# ------------------------------
# Obtain SSL Certificate with Certbot
# ------------------------------
echo "🔐 Requesting SSL certificate..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$DOMAIN" || {
  echo "❌ Failed to obtain SSL certificate"; exit 1;
}
echo "✅ SSL certificate installed."

# ------------------------------
# Save secrets
# ------------------------------
echo "🔐 Saving secrets to $WP_SECRETS_FILE..."
{
  echo "DOMAIN=$DOMAIN"
  echo "WP_DB=$WP_DB"
  echo "WP_USER=$WP_USER"
  echo "WP_PASSWORD=$WP_PASSWORD"
} > "$WP_SECRETS_FILE"
chmod 600 "$WP_SECRETS_FILE"

# ------------------------------
# Done
# ------------------------------
echo "✅ WordPress installed successfully!"
echo "🔐 Secrets saved at: $WP_SECRETS_FILE"
echo "🌐 Visit: https://$DOMAIN"