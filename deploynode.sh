#!/bin/bash
productId="{{ $json.productId | lower }}"
case "$productId" in
  "n8n_id")
    echo "Deploying N8N"
    cd /root/scripts/n8n
    cp n8n.sh n8n-new.sh
    sed -i 's/N8NDOMAIN/{{ $json.body.effectiveDomain }}/g' n8n-new.sh
    scp -o StrictHostKeyChecking=no n8n-new.sh docker-compose.yaml root@{{ $json.body.serverIp }}:/tmp
    rm n8n-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./n8n-new.sh'
    ;;
  "wordpress_id")
    echo "Deploying WordPress"
    cd /root/scripts/wordpress
    cp wordpress.sh wordpress-new.sh
    sed -i 's/WORDPRESSDOMAIN/{{ $json.body.effectiveDomain }}/g' wordpress-new.sh
    scp -o StrictHostKeyChecking=no wordpress-new.sh root@{{ $json.body.serverIp }}:/tmp
    rm wordpress-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./wordpress-new.sh'
    ;;
  "erpnext_id")
    echo "Deploying ERPNext"
    cd /root/scripts/erpnext
    cp erpnext.sh erpnext-new.sh
    sed -i 's/ERPNEXTDOMAIN/{{ $json.body.effectiveDomain }}/g' erpnext-new.sh
    scp -o StrictHostKeyChecking=no erpnext-new.sh root@{{ $json.body.serverIp }}:/tmp
    rm erpnext-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./erpnext-new.sh'
    ;;
  "uvdesk_id")
    echo "Deploying UVDesk"
    cd /root/scripts/uvdesk
    cp uvdesk.sh uvdesk-new.sh
    sed -i 's/ERPNEXTDOMAIN/{{ $json.body.effectiveDomain }}/g' uvdesk-new.sh
    scp -o StrictHostKeyChecking=no uvdesk-new.sh root@{{ $json.body.serverIp }}:/tmp
    rm uvdesk-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./uvdesk-new.sh'
    ;;
  "mattermost_id")
    echo "Deploying Mattermost"
    cd /root/scripts/mattermost
    cp mattermost.sh mattermost-new.sh
    sed -i 's/MATTERMOSTDOMAIN/{{ $json.body.effectiveDomain }}/g' mattermost-new.sh
    scp -o StrictHostKeyChecking=no mattermost-new.sh root@{{ $json.body.serverIp }}:/tmp
    rm mattermost-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./mattermost-new.sh'
    rm mattermost-new.sh
    ;;
  "nextcloud_id")
    echo "Deploying Nextcloud"
    cd /root/scripts/nextcloud
    cp nextcloud.sh nextcloud-new.sh
    sed -i 's/NEXTCLOUDDOMAIN/{{ $json.body.effectiveDomain }}/g' nextcloud-new.sh
    scp -o StrictHostKeyChecking=no nextcloud-new.sh root@{{ $json.body.serverIp }}:/tmp
    rm nextcloud-new.sh
    ssh -o StrictHostKeyChecking=no root@{{ $json.body.serverIp }} 'bash cd /tmp/ && ./nextcloud-new.sh'
    rm nextcloud-new.sh
    ;;
  *)
    echo "Unknown product ID: $productId"
    exit 1
    ;;
esac