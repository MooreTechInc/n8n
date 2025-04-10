#!/bin/bash

set -e

REDIS_PASSWORD=$(openssl rand -base64 18)
ALLOW_EXTERNAL_ACCESS=true

echo "🔐 Generated secure Redis password."

# Save to env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" > redis_secrets.env
chmod 600 redis_secrets.env

echo "📦 Installing Redis..."
sudo apt update
sudo apt install -y redis-server

echo "🔧 Configuring Redis..."

# Secure Redis with a password
sudo sed -i "s/^# requirepass .*$/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf

if [ "$ALLOW_EXTERNAL_ACCESS" = true ]; then
    sudo sed -i "s/^bind .*/bind 0.0.0.0 ::1/" /etc/redis/redis.conf
    sudo sed -i "s/^protected-mode yes/protected-mode no/" /etc/redis/redis.conf
fi

echo "🚀 Restarting Redis..."
sudo systemctl enable redis-server
sudo systemctl restart redis-server

echo "✅ Redis setup complete!"
echo "📄 Credentials saved to: redis_secrets.env"