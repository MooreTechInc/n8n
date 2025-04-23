#!/bin/bash
set -euo pipefail

# ------------------------------
# Configurable Variables
# ------------------------------
DOMAIN="EFFECTIVEDOMAIN"
CERTBOT_EMAIL="admin@mooretech.io"
PGDB_USER="nextcloud"
PGDB_PASS="gVPjfuWwfRyyRxR6sW8QuvTiXD98GmmZ3OVK7O"
GUIUSER="admin"
GUIPASS="gVPjfuWwfRyyRxR6sW8QuvTiXD98GmmZ3OVK7O"
PHPVER="8.1"
NCPATH="/var/www/nextcloud"
NCDATA="/var/ncdata"
SCRIPTS="/var/scripts"
VMLOGS="/var/log/nextcloud"
HTTP_CONF="nextcloud-http.conf"
TLS_CONF="nextcloud-tls.conf"
NCREPO="https://download.nextcloud.com/server/releases"
AUT_UPDATES_TIME="3"
SYSVENDOR=$(dmidecode -s system-manufacturer || echo "Unknown")
DISTRO=$(lsb_release -cs || echo "Unknown")

# ------------------------------
# Logging
# ------------------------------
LOGFILE="/var/log/nextcloud_install.log"
exec > >(tee -i "$LOGFILE") 2>&1

# ------------------------------
# Check for Root Privileges
# ------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  This script must be run as root. Switching to root user..."
  exec sudo su -c "$0"
fi

# ------------------------------
# Install Required Packages
# ------------------------------
echo "📦 Installing required packages..."
apt update -q4
apt install -y curl whiptail lshw net-tools apt-utils keyboard-configuration \
  bash-completion htop iputils-ping netplan.io apt-transport-https build-essential \
  nano cron sudo software-properties-common postgresql apache2 php"$PHPVER"-fpm \
  php"$PHPVER"-intl php"$PHPVER"-ldap php"$PHPVER"-imap php"$PHPVER"-gd php"$PHPVER"-pgsql \
  php"$PHPVER"-curl php"$PHPVER"-xml php"$PHPVER"-zip php"$PHPVER"-mbstring php"$PHPVER"-soap \
  php"$PHPVER"-gmp php"$PHPVER"-bz2 php"$PHPVER"-bcmath php-pear redis-server libsmbclient-dev \
  ssl-cert figlet || {
  echo "❌ Failed to install required packages. Exiting."
  exit 1
}

# ------------------------------
# Configure PostgreSQL
# ------------------------------
echo "🐘 Configuring PostgreSQL..."
sudo -u postgres psql <<END
CREATE USER $PGDB_USER WITH PASSWORD '$PGDB_PASS';
CREATE DATABASE nextcloud_db WITH OWNER $PGDB_USER TEMPLATE template0 ENCODING 'UTF8';
END
systemctl restart postgresql.service

# ------------------------------
# Configure Apache
# ------------------------------
echo "🌐 Configuring Apache..."
a2enmod rewrite headers proxy proxy_fcgi setenvif env mime dir authz_core alias mpm_event ssl http2
a2enconf php"$PHPVER"-fpm
systemctl restart apache2.service

# ------------------------------
# Configure PHP
# ------------------------------
echo "⚙️ Configuring PHP..."
cat <<EOF > /etc/php/"$PHPVER"/fpm/pool.d/nextcloud.conf
[Nextcloud]
user = www-data
group = www-data
listen = /run/php/php"$PHPVER"-fpm.nextcloud.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 8
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 3
EOF
systemctl restart php"$PHPVER"-fpm.service

# ------------------------------
# Download and Install Nextcloud
# ------------------------------
echo "⬇️ Downloading and installing Nextcloud..."
wget "$NCREPO"/nextcloud-latest.tar.bz2 -O /tmp/nextcloud.tar.bz2
tar -xjf /tmp/nextcloud.tar.bz2 -C /var/www/
chown -R www-data:www-data "$NCPATH"
rm /tmp/nextcloud.tar.bz2

# ------------------------------
# Configure Nextcloud
# ------------------------------
echo "⚙️ Configuring Nextcloud..."
sudo -u www-data php "$NCPATH"/occ maintenance:install \
  --data-dir="$NCDATA" \
  --database=pgsql \
  --database-name=nextcloud_db \
  --database-user="$PGDB_USER" \
  --database-pass="$PGDB_PASS" \
  --admin-user="$GUIUSER" \
  --admin-pass="$GUIPASS"

# ------------------------------
# Configure Redis
# ------------------------------
echo "🔧 Configuring Redis..."
apt install -y redis-server
systemctl enable redis-server.service
systemctl start redis-server.service

# ------------------------------
# Configure SSL with Certbot
# ------------------------------
echo "🔐 Configuring SSL with Certbot..."
apt install -y certbot python3-certbot-apache
certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" || {
  echo "❌ Failed to configure SSL with Certbot. Exiting."
  exit 1
}

# ------------------------------
# Configure Cron Jobs
# ------------------------------
echo "⏲️ Configuring cron jobs..."
crontab -u www-data -l | { cat; echo "*/5 * * * * php -f $NCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# ------------------------------
# Cleanup
# ------------------------------
echo "🧹 Cleaning up..."
apt autoremove -y
apt autoclean -y

# ------------------------------
# Done!
# ------------------------------
echo "✅ Nextcloud installation completed successfully!"
echo "🌐 Access your Nextcloud instance at: https://$DOMAIN"

# ------------------------------
# Save secrets
# ------------------------------
echo "🔐 Saving secrets to $SCRIPTS/nextcloud_secrets.sh..."
{
  echo "DOMAIN=$DOMAIN"
  echo "PGDB_USER=$PGDB_USER"
  echo "PGDB_PASS=$PGDB_PASS"
  echo "GUIUSER=$GUIUSER"
  echo "GUIPASS=$GUIPASS"
} > "$SCRIPTS"/nextcloud_secrets.sh
chmod 600 "$SCRIPTS"/nextcloud_secrets.sh
echo "✅ Secrets saved to $SCRIPTS/nextcloud_secrets.sh"
# ------------------------------
# Done
# ------------------------------
echo "✅ Nextcloud installed successfully!"
echo "🌐 Access your Nextcloud instance at: https://$DOMAIN"