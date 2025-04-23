#!/bin/bash

set -euo pipefail

# ------------------------------
# Configurable Variables
# ------------------------------
DOMAIN="EFFECTIVEDOMAIN"
CERTBOT_EMAIL="admin@mooretech.io"
SITE_URL="https://$DOMAIN"
SUPPORT_EMAIL="SUPPORT_EMAIL"
MATTERMOST_SECRETS_FILE="/tmp/mattermost_secrets.env"
PGDB_USER="mattermost"
PGDB_PASS="gVPjfuWwfRyyRxR6sW8QuvTiXD98GmmZ3OVK7O"
PGDB_DB="mattermost"
MATTERMOST_DIR="/opt/mattermost"
MATTERMOST_CONFIG="$MATTERMOST_DIR/config/config.json"
MATTERMOST_LOGS="$MATTERMOST_DIR/logs"
MATTERMOST_DATA="$MATTERMOST_DIR/data"
MATTERMOST_BIN="$MATTERMOST_DIR/bin"


# ------------------------------
# Install & Configure PostgreSQL
# ------------------------------
echo "🐘 Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# ------------------------------
# Configure PostgreSQL
# ------------------------------
echo "🐘 Configuring PostgreSQL..."

# Check if the PostgreSQL user exists
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PGDB_USER'")
if [ "$USER_EXISTS" != "1" ]; then
  echo "👤 Creating PostgreSQL user '$PGDB_USER'..."
  sudo -u postgres psql -c "CREATE ROLE $PGDB_USER WITH LOGIN PASSWORD '$PGDB_PASS';"
else
  echo "ℹ️ PostgreSQL user '$PGDB_USER' already exists. Skipping user creation."
fi

# Check if the PostgreSQL database exists
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='mattermost'")
if [ "$DB_EXISTS" != "1" ]; then
  echo "📂 Creating PostgreSQL database 'mattermost'..."
  sudo -u postgres psql -c "CREATE DATABASE mattermost OWNER $PGDB_USER;"
else
  echo "ℹ️ PostgreSQL database 'mattermost' already exists. Skipping database creation."
fi

# Grant privileges to the user on the database
echo "🔑 Granting privileges on database 'mattermost' to user '$PGDB_USER'..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mattermost TO $PGDB_USER;"

# Restart PostgreSQL service
echo "✅ PostgreSQL configured, restarting PostgreSQL service..."
sudo systemctl restart postgresql

# ------------------------------
# add the Mattermost Server repositories:
# ------------------------------
echo "📦 Adding Mattermost Server repositories..."
curl -o- https://deb.packages.mattermost.com/repo-setup.sh | sudo bash -s mattermost

# ------------------------------
# Update the system:
# ------------------------------
echo "📦 Updating the system..."
sudo apt update

# ------------------------------
# Install the Mattermost Server:
# ------------------------------
echo "📦 Installing the Mattermost Server..."
sudo apt install -y mattermost

# ------------------------------
# Configure the Mattermost Server:
# ------------------------------
echo "🛠️  Configuring the Mattermost Server..."
sudo install -C -m 600 -o mattermost -g mattermost /opt/mattermost/config/config.defaults.json /opt/mattermost/config/config.json
sed -i 's#"SiteURL": "",#"SiteURL": "'"$SITE_URL"'",#' /opt/mattermost/config/config.json
sed -i 's#"SupportEmail": "",#"SupportEmail": "'"$SUPPORT_EMAIL"'",#' /opt/mattermost/config/config.json
sed -i "s/mostest/$PGDB_PASS/g" /opt/mattermost/config/config.json
sed -i "s/mattermost_test/$PGDB_DB/g" /opt/mattermost/config/config.json
sed -i "s/mmuser/$PGDB_USER/g" /opt/mattermost/config/config.json

# ------------------------------
# Start the Mattermost Server:
# ------------------------------
echo "🚀 Starting the Mattermost Server..."
sudo systemctl restart mattermost
sudo systemctl enable mattermost
echo "✅ Mattermost Server started and enabled to start on boot."
echo "📦 Mattermost Server installation and configuration completed successfully."

# ------------------------------
# Configure Nginx:
# ------------------------------
echo "🔒 Configuring NGINX..."
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
cat > /etc/nginx/sites-available/mattermost <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
ln -sf /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/mattermost
nginx -t && systemctl reload nginx || {
  echo "❌ NGINX configuration failed."; exit 1;
}
echo "✅ NGINX configuration is valid and reloaded."
# ------------------------------
# Run Certbot
# ------------------------------
echo "🔐 Running Certbot..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $CERTBOT_EMAIL || {
  echo "❌ Failed to run Certbot."; exit 1;
}
echo "✅ Certbot ran successfully and SSL certificate is installed."

# ------------------------------
# Save secrets
# ------------------------------
echo "🔐 Saving secrets to $MATTERMOST_SECRETS_FILE..."
{
  echo "DOMAIN=$DOMAIN"
  echo "SUPPORT_EMAIL=$SUPPORT_EMAIL"
} > "$MATTERMOST_SECRETS_FILE"
chmod 600 "$MATTERMOST_SECRETS_FILE"
echo "✅ Secrets saved to $MATTERMOST_SECRETS_FILE."
# ------------------------------
# Done!
# ------------------------------
echo "✅ All done! Mattermost is live at: $SITE_URL"
echo "🔐 Secrets saved at: $MATTERMOST_SECRETS_FILE"