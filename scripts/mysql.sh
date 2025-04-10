#!/bin/bash

set -e

MYSQL_USER="n8n"
MYSQL_DB="n8n"
ALLOW_EXTERNAL_ACCESS=true

# Generate secure password
if command -v openssl &> /dev/null; then
    MYSQL_PASSWORD=$(openssl rand -base64 18)
else
    echo "❌ openssl not found"
    exit 1
fi

echo "🔐 Generated secure password for MySQL user."

# Save to .env
echo "MYSQL_USER=$MYSQL_USER" > mysql_secrets.env
echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> mysql_secrets.env
echo "MYSQL_DB=$MYSQL_DB" >> mysql_secrets.env
chmod 600 mysql_secrets.env

echo "📦 Installing MySQL..."

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

echo "🚀 Starting MySQL..."
sudo systemctl enable mysql
sudo systemctl start mysql

echo "👤 Creating MySQL user and database..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\`;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DB\`.* TO '$MYSQL_USER'@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

if [ "$ALLOW_EXTERNAL_ACCESS" = true ]; then
    echo "🌐 Configuring MySQL for external access..."
    sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
fi

echo "✅ MySQL setup complete!"
echo "📄 Credentials saved to: mysql_secrets.env"
