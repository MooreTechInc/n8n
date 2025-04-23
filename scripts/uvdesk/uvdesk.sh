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
MYSQL_USER="uvdesk"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')
MYSQL_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')
MYSQL_DATABASE="uvdesk"
NGINX_SITE_CONF="/etc/nginx/sites-available/uvdesk"

# ------------------------------
# Install Required Packages
# ------------------------------
echo "📦 Installing NGINX, MySQL, Certbot, and Docker..."
apt update
apt install -y nginx mysql-server certbot python3-certbot-nginx docker.io || {
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
DB_EXISTS=$(mysql -sse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$MYSQL_DATABASE'")
if [ "$DB_EXISTS" != "$MYSQL_DATABASE" ]; then
  mysql -e "CREATE DATABASE \`$MYSQL_DATABASE\`;" && echo "✅ Database $MYSQL_DATABASE created"
else
  echo "ℹ️ Database $MYSQL_DATABASE already exists"
fi
USER_EXISTS=$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$MYSQL_USER')")
if [ "$USER_EXISTS" == 1 ]; then
  echo "ℹ️ User $MYSQL_USER already exists"
else
  mysql -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" && echo "✅ User $MYSQL_USER created"
  mysql -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost';" && echo "✅ Granted privileges to $MYSQL_USER on $MYSQL_DATABASE"
  mysql -e "FLUSH PRIVILEGES;" && echo "✅ Privileges flushed"
fi

# ------------------------------
# Create NGINX Configuration
# ------------------------------
echo "📝 Creating NGINX configuration..."
cat <<EOL > $NGINX_SITE_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:88;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL
echo "✅ Created $NGINX_SITE_CONF"

# ------------------------------
# Enable NGINX Configuration
# ------------------------------
echo "🔗 Enabling NGINX configuration..."
ln -s $NGINX_SITE_CONF /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# ------------------------------
# Obtain SSL Certificate
# ------------------------------
echo "🔒 Obtaining SSL certificate..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# ------------------------------
# Pull and Run UVdesk Docker Container
# ------------------------------
echo "🐳 Pulling and running UVdesk Docker container..."
docker pull nuttcorp/uvdesk || {
  echo "❌ Failed to pull UVdesk Docker image."; exit 1;
}
docker rm -f uvdesk || true
docker volume rm uvdesk_config || true
docker volume rm uvdesk_db || true
docker volume create uvdesk_config
docker volume create uvdesk_db
docker run -dit -p 88:80 -p 3306:3306 \
-e UVdesk_URL=$DOMAIN \
-e UVdesk_DB_HOST=localhost \
-e UVdesk_DB_NAME=$MYSQL_DATABASE \
-e UVdesk_DB_USER=$MYSQL_USER \
-e UVdesk_DB_PASSWORD=$MYSQL_PASSWORD \
-e UVdesk_DB_PORT=3306 \
-e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
--name uvdesk nuttcorp/uvdesk || {
  echo "❌ Failed to run UVdesk Docker container."; exit 1;
}

# ------------------------------
# Save Secrets
# ------------------------------
echo "🔐 Saving secrets to /tmp/uvdesk_secrets.env..."
{
  echo "DOMAIN=$DOMAIN"
  echo "MYSQL_USER=$MYSQL_USER"
  echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD"
  echo "MYSQL_PASSWORD=$MYSQL_PASSWORD"
  echo "MYSQL_DATABASE=$MYSQL_DATABASE"
} > /tmp/uvdesk_secrets.env
chmod 600 /tmp/uvdesk_secrets.env
echo "✅ Secrets saved to /tmp/uvdesk_secrets.env"

# ------------------------------
# Done
# ------------------------------
echo "✅ UVdesk installed successfully!"
echo "🔐 Secrets saved at: /tmp/uvdesk_secrets.env"