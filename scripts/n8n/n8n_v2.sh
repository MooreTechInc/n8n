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
DOCKER_COMPOSE_URL="https://your-server.com/docker-compose.yml"
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
# (Optional) Run Docker Compose
# ------------------------------
echo "🚀 Starting n8n stack..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d


# ------------------------------
# Generate secrets
# ------------------------------
echo "🔐 Generating secrets..."
DB_POSTGRESDB_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')
N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')

# Save for reference
cat > "$N8N_SECRETS_FILE" <<EOF
# Generated on $(date)
DB_POSTGRESDB_PASSWORD=$DB_POSTGRESDB_PASSWORD
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD
EOF
chmod 600 "$N8N_SECRETS_FILE"

# ------------------------------
# Replace variables in compose file
# ------------------------------
echo "🔧 Replacing placeholders in docker-compose..."
sed -i "s/DOMAIN/$DOMAIN/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/POPASS/$DB_POSTGRESDB_PASSWORD/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/ENCK/$N8N_ENCRYPTION_KEY/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/N8N_BASIC_AUTH_PASSWORD/$N8N_BASIC_AUTH_PASSWORD/g" "$DOCKER_COMPOSE_FILE"
echo "🎉 n8n stack deployed at https://$DOMAIN"

echo "✅ docker-compose file configured and secrets saved at $N8N_SECRETS_FILE"

