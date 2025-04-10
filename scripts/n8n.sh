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
N8N_DOMAIN="n8n.mooretech.io"
NODE_VERSION="22"
N8N_DIR="/home/n8n"
PG_VERSION=16
PG_USER="n8nadmin"
PG_DB="n8n"
ALLOW_EXTERNAL_ACCESS=true
N8N_BASIC_AUTH_USER="admin"
N8N_SMTP_USER="apikey"
N8N_SMTP_PASS="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"
N8N_SMTP_SENDER="Rich noreply@raiaai.com"
N8N_CONFIG_FILE="/root/.n8n/config"
SECRETS_FILE="$N8N_DIR/pg_secrets.env"

# ------------------------------
# Clean up previous config & secrets
# ------------------------------
echo "🧹 Cleaning up previous config and secrets..."
[ -f "$N8N_CONFIG_FILE" ] && rm -f "$N8N_CONFIG_FILE" && echo "✅ Removed $N8N_CONFIG_FILE" || echo "ℹ️ No existing $N8N_CONFIG_FILE found"
[ -f "$SECRETS_FILE" ] && rm -f "$SECRETS_FILE" && echo "✅ Removed $SECRETS_FILE" || echo "ℹ️ No existing $SECRETS_FILE found"

# Confirm deletion
ls -la /root/.n8n/
ls -la /home/n8n/

# ------------------------------
# Generate new secrets
# ------------------------------
echo "🔐 Generating new secure credentials..."
PG_PASSWORD=$(openssl rand -base64 18)
N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 18)

# ------------------------------
# Install PostgreSQL
# ------------------------------
echo "📦 Installing PostgreSQL $PG_VERSION..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  apt update
  if ! dpkg -s postgresql-$PG_VERSION >/dev/null 2>&1; then
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | tee /etc/apt/trusted.gpg.d/postgresql.asc > /dev/null
    apt update
    apt install -y "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"
  else
    echo "✅ PostgreSQL $PG_VERSION already installed."
  fi
else
  echo "❌ Unsupported OS: $OSTYPE"
  exit 1
fi

# ------------------------------
# Start PostgreSQL
# ------------------------------
echo "🚀 Starting PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql

# ------------------------------
# Create PostgreSQL User and Database
# ------------------------------
echo "👤 Ensuring PostgreSQL user and database exist..."

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'" | grep -q 1; then
  echo "⚠️ PostgreSQL user '$PG_USER' exists, dropping and recreating..."
  sudo -u postgres psql -c "DROP ROLE IF EXISTS $PG_USER;"
fi

sudo -u postgres psql -c "CREATE ROLE $PG_USER WITH LOGIN PASSWORD '$PG_PASSWORD' SUPERUSER CREATEDB CREATEROLE INHERIT;"

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PG_DB'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"
else
  echo "ℹ️ PostgreSQL database '$PG_DB' already exists."
fi

# ------------------------------
# Configure PostgreSQL External Access
# ------------------------------
if [ "$ALLOW_EXTERNAL_ACCESS" = true ]; then
  echo "🌐 Configuring PostgreSQL for external access..."
  CONF_FILE=$(find /etc/postgresql/ -name postgresql.conf | head -n 1)
  HBA_FILE=$(find /etc/postgresql/ -name pg_hba.conf | head -n 1)

  sed -i "s|^#listen_addresses = .*|listen_addresses = '*'|g" "$CONF_FILE"
  grep -qF "0.0.0.0/0" "$HBA_FILE" || echo "host    all             all             0.0.0.0/0               md5" | tee -a "$HBA_FILE"
  systemctl restart postgresql
fi

# ------------------------------
# Install nvm and Node.js
# ------------------------------
echo "📦 Installing NVM and Node.js $NODE_VERSION..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
fi

source "$NVM_DIR/nvm.sh"
nvm install $NODE_VERSION
nvm use $NODE_VERSION
nvm alias default $NODE_VERSION

# ------------------------------
# Install pm2 and n8n
# ------------------------------
echo "🚀 Installing pm2 and n8n globally..."
npm install -g pm2 n8n

# ------------------------------
# Run n8n once to generate config
# ------------------------------
echo "⚙️ Running n8n once to generate default config..."
su -c "n8n --help > /dev/null" n8n || true

# ------------------------------
# Read encryption key from generated config
# ------------------------------
if [ -f "$N8N_CONFIG_FILE" ]; then
  N8N_ENCRYPTION_KEY=$(grep 'encryptionKey' "$N8N_CONFIG_FILE" | awk -F '"' '{print $4}')
  echo "🔑 Retrieved encryption key from $N8N_CONFIG_FILE"
else
  echo "❌ Could not find $N8N_CONFIG_FILE to extract encryption key."
  exit 1
fi

# ------------------------------
# Save all secrets
# ------------------------------
cat > "$SECRETS_FILE" <<EOF
PG_USER=$PG_USER
PG_PASSWORD=$PG_PASSWORD
PG_DB=$PG_DB
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
EOF
chmod 600 "$SECRETS_FILE"

# ------------------------------
# Setup ecosystem.config.js
# ------------------------------
echo "🛠️ Setting up PM2 ecosystem config..."
mkdir -p $N8N_DIR
cat > $N8N_DIR/ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "n8n",
      script: "$HOME/.nvm/versions/node/$(nvm current)/bin/n8n",
      autorestart: true,
      watch: true,
      max_memory_restart: "4G",
      env: {
        NODE_ENV: "production",
        TRUST_PROXY: "true",
        N8N_BASIC_AUTH_ACTIVE: "true",
        N8N_BASIC_AUTH_USER: "$N8N_BASIC_AUTH_USER",
        N8N_BASIC_AUTH_PASSWORD: "$N8N_BASIC_AUTH_PASSWORD",
        N8N_HOST: "$N8N_DOMAIN",
        N8N_PROTOCOL: "https",
        N8N_ENCRYPTION_KEY: "$N8N_ENCRYPTION_KEY",
        WEBHOOK_TUNNEL_URL: "https://$N8N_DOMAIN",
        WEBHOOK_URL: "https://$N8N_DOMAIN",
        N8N_EXTERNAL_URL: "https://$N8N_DOMAIN",
        DB_TYPE: "postgresdb",
        DB_POSTGRESDB_HOST: "127.0.0.1",
        DB_POSTGRESDB_DATABASE: "$PG_DB",
        DB_POSTGRESDB_USER: "$PG_USER",
        DB_POSTGRESDB_PASSWORD: "$PG_PASSWORD",
        EXECUTIONS_MODE: "regular",
        NODE_FUNCTION_ALLOW_EXTERNAL: "nodemailer",
        N8N_PUSH_BACKEND: "websocket",
        N8N_EMAIL_MODE: "smtp",
        N8N_SMTP_SENDER: "$N8N_SMTP_SENDER",
        N8N_SMTP_USER: "$N8N_SMTP_USER",
        N8N_SMTP_PASS: "$N8N_SMTP_PASS",
        N8N_SMTP_HOST: "smtp.sendgrid.net",
        N8N_SMTP_PORT: 587,
        NODE_OPTIONS: "--max-old-space-size=4096",
        EXECUTIONS_DATA_SAVE_ON_ERROR: "all",
        EXECUTIONS_DATA_SAVE_ON_SUCCESS: "all",
        EXECUTIONS_DATA_SAVE_ON_PROGRESS: false,
        EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS: false,
        N8N_TRUST_PROXY: true,
        N8N_EDITOR_BASE_URL: "https://$N8N_DOMAIN",
        N8N_HIRING_BANNER_ENABLED: false,
	N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: true,        
	N8N_RUNNERS_ENABLED: true
      }
    }
  ]
};
EOF

# ------------------------------
# Start n8n using pm2
# ------------------------------
echo "🔄 Starting n8n with pm2..."
cd $N8N_DIR
pm2 start ecosystem.config.js
pm2 save
pm2 startup --update-env

# ------------------------------
# Setup NGINX and Certbot
# ------------------------------
echo "🔐 Setting up SSL with Certbot..."
sudo apt install -y nginx certbot python3-certbot-nginx

cat > /etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    server_name $N8N_DOMAIN;

    location / {
	    proxy_pass http://127.0.0.1:5678;
    	proxy_http_version 1.1;
    	proxy_set_header Upgrade $http_upgrade;
    	proxy_set_header Connection "upgrade";
    	proxy_set_header Host $http_host;
    	proxy_set_header X-Real-IP $remote_addr;
    	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    	proxy_set_header X-Forwarded-Proto $scheme;
    	proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
sudo nginx -t && sudo systemctl reload nginx

sudo certbot --nginx -d $N8N_DOMAIN --non-interactive --agree-tos -m admin@$N8N_DOMAIN

# ------------------------------
# Done!
# ------------------------------
echo "✅ All done! n8n is live at: https://$N8N_DOMAIN"
echo "🔑 Basic auth user: $N8N_BASIC_AUTH_USER"
echo "🔑 Password: $N8N_BASIC_AUTH_PASSWORD"
echo "📄 DB credentials saved in pg_secrets.env"