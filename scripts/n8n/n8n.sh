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
CERTBOT_EMAIL="admin@mooretech.io"
N8N_SECRETS_FILE="/tmp/n8n_secrets.env"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/MooreTechInc/n8n/refs/heads/main/scripts/n8n/docker-compose.yaml"
DOCKER_COMPOSE_FILE="/tmp/docker-compose.yml"

# ------------------------------
# Validate dependencies
# ------------------------------
for cmd in curl openssl sed docker docker-compose; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Required command $cmd is not installed."
    exit 1
  fi
done

# ------------------------------
# Install Required Packages
# ------------------------------
echo "📦 Installing NGINX, Certbot, Docker if missing..."
apt update
for pkg in nginx certbot python3-certbot-nginx docker.io docker-compose; do
  dpkg -s "$pkg" &> /dev/null || apt install -y "$pkg"
done

# ------------------------------
# Start and Enable Services
# ------------------------------
echo "🚀 Starting services..."
systemctl enable --now nginx
systemctl enable --now docker

# ------------------------------
# Download docker-compose.yml
# ------------------------------
echo "🌐 Downloading docker-compose file from $DOCKER_COMPOSE_URL"
curl -fsSL "$DOCKER_COMPOSE_URL" -o "$DOCKER_COMPOSE_FILE" || {
  echo "❌ Failed to download docker-compose file."
  exit 1
}

# ------------------------------
# Generate secrets
# ------------------------------
echo "🔐 Generating secrets..."
DB_POSTGRESDB_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')
N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)

# Save for reference
cat > "$N8N_SECRETS_FILE" <<EOF
# Generated on $(date)
DB_POSTGRESDB_PASSWORD=$DB_POSTGRESDB_PASSWORD
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
EOF
chmod 600 "$N8N_SECRETS_FILE"

# ------------------------------
# Replace variables in compose file
# ------------------------------
echo "🔧 Replacing placeholders in docker-compose..."
sed -i "s/DOMAIN/$DOMAIN/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/POPASS/$DB_POSTGRESDB_PASSWORD/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/ENCK/$N8N_ENCRYPTION_KEY/g" "$DOCKER_COMPOSE_FILE"

# ------------------------------
# Clean and Deploy Docker Compose Stack
# ------------------------------
echo "🧼 Cleaning up previous Docker Compose stack..."
cd /tmp
docker-compose -f "$DOCKER_COMPOSE_FILE" down --volumes --remove-orphans || true

echo "🐳 Bringing up a fresh Docker Compose stack..."
docker-compose -f "$DOCKER_COMPOSE_FILE" pull
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate


# ------------------------------
# Wait for NGINX to expose N8N
# ------------------------------
echo "⏳ Waiting for NGINX and services to come online..."
sleep 5  # You may replace with health checks if needed

# ------------------------------
# Configure NGINX (basic reverse proxy)
# ------------------------------
NGINX_CONF="/etc/nginx/sites-available/n8n"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/n8n
nginx -t && systemctl reload nginx

# ------------------------------
# Obtain Let's Encrypt Certificate
# ------------------------------
echo "🔐 Requesting TLS certificate from Let's Encrypt..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL"

# ------------------------------
# Done!
# ------------------------------
echo "🎉 n8n setup complete and available at: https://$DOMAIN"
echo "🔑 Credentials:"
echo "  - Username: admin"
echo "  - Password: $DB_POSTGRESDB_PASSWORD"
echo "📁 Secrets saved in: $N8N_SECRETS_FILE"


