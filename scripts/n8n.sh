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
N8NDOMAIN="DOMAIN"
N8NIP="IP"

sed -i "s/DOMAIN/$DOMAIN/g" /root/scripts/n8n/n8n_v2.sh
scp /root/scripts/n8n/n8n_v2.sh root@$N8NIP:/tmp/n8n_v2.sh
scp /root/scripts/n8n/docker-compose.yaml root@$$N8NIP:/tmp/docker-compose.yaml
ssh root@$N8NIP "bash /tmp/n8n_v2.sh"