#!/bin/bash

set -e

# ------------------------------
# Configurable Variables
# ------------------------------
PG_VERSION=16
PG_USER="n8n"
PG_DB="n8n"
ALLOW_EXTERNAL_ACCESS=true

# ------------------------------
# Generate Secure Password
# ------------------------------
if command -v openssl &> /dev/null; then
    PG_PASSWORD=$(openssl rand -base64 18)
elif command -v pwgen &> /dev/null; then
    PG_PASSWORD=$(pwgen 20 1)
else
    echo "❌ Neither openssl nor pwgen is installed. Cannot generate secure password."
    exit 1
fi

echo "🔐 Generated secure password for PostgreSQL user."

# Optional: Save to .env or secrets file
echo "PG_USER=$PG_USER" > pg_secrets.env
echo "PG_PASSWORD=$PG_PASSWORD" >> pg_secrets.env
echo "PG_DB=$PG_DB" >> pg_secrets.env
chmod 600 pg_secrets.env

# ------------------------------
# Install PostgreSQL
# ------------------------------
echo "📦 Installing PostgreSQL $PG_VERSION..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt update
    sudo apt install -y "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install postgresql@$PG_VERSION
    brew services start postgresql@$PG_VERSION
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# ------------------------------
# Start and Enable PostgreSQL
# ------------------------------
echo "🚀 Starting PostgreSQL..."

if command -v systemctl &> /dev/null; then
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
fi

# ------------------------------
# Create User and Database
# ------------------------------
echo "👤 Creating PostgreSQL user and database..."

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$PG_USER') THEN
      CREATE ROLE $PG_USER LOGIN PASSWORD '$PG_PASSWORD';
   END IF;
END
\$\$;

CREATE DATABASE $PG_DB OWNER $PG_USER;
EOF

# ------------------------------
# Configure External Access (optional)
# ------------------------------
if [ "$ALLOW_EXTERNAL_ACCESS" = true ]; then
    echo "🌐 Configuring PostgreSQL for external access..."

    CONF_FILE=$(sudo find /etc/postgresql/ -name postgresql.conf)
    HBA_FILE=$(sudo find /etc/postgresql/ -name pg_hba.conf)

    if [[ -f "$CONF_FILE" ]]; then
        sudo sed -i "s/^#listen_addresses = .*/listen_addresses = '*'/" "$CONF_FILE"
    fi

    if [[ -f "$HBA_FILE" ]]; then
        echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$HBA_FILE"
    fi

    sudo systemctl restart postgresql
fi

# ------------------------------
# Done!
# ------------------------------
echo "✅ PostgreSQL setup complete!"
echo "📄 Credentials saved to: pg_secrets.env"
echo "   Username: $PG_USER"
echo "   Database: $PG_DB"
echo "   Password: $PG_PASSWORD"