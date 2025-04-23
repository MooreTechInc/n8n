0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT


curl \           
        -X POST \
        -H "Authorization: Bearer 0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT" \
        -H "Content-Type: application/json" \
        -d '{"name":"my-server","location":"nbg1","datacenter":"nbg1-dc3","server_type":"cpx11","start_after_create":true,"image":"ubuntu-20.04","placement_group":1,"ssh_keys":["my-ssh-key"],"volumes":[123],"networks":[456],"firewalls":[{"firewall":38}],"user_data":"#cloud-config\nruncmd:\n- [touch, /root/cloud-init-worked]\n","labels":{"environment":"prod","example.com/my":"label","just-a-key":""},"automount":false,"public_net":{"enable_ipv4":false,"enable_ipv6":false,"ipv4":null,"ipv6":null}}' \
        "https://api.hetzner.cloud/v1/servers"



curl \
	-X POST \
	-H "Authorization: Bearer 0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT" \
	-H "Content-Type: application/json" \
	-d '{
        "name": "my-resource",
        "type": "ipv4",
        "datacenter": "fsn1-dc8",
        "assignee_type": "server",
        "auto_delete": true,
        }' \
        "https://api.hetzner.cloud/v1/primary_ips"


curl \
	-X POST \
	-H "Authorization: Bearer 0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT" \
	-H "Content-Type: application/json" \
	-d '{"name":"my-server","datacenter":"nbg1-dc3","server_type":"cpx11","start_after_create":true,"image":"ubuntu-20.04","placement_group":1,"ssh_keys":["my-ssh-key"],"volumes":[123],"networks":[456],"firewalls":[{"firewall":38}],"user_data":"#cloud-config\nruncmd:\n- [touch, /root/cloud-init-worked]\n","labels":{"environment":"prod","example.com/my":"label","just-a-key":""},"automount":false,"public_net":{"enable_ipv4":false,"enable_ipv6":false,"ipv4":188.245.158.142}}' \
	"https://api.hetzner.cloud/v1/servers"


curl -X POST \
  -H "Authorization: Bearer 0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "n8ntest",
    "datacenter": "nbg1-dc3",
    "server_type": "CX52",
    "start_after_create": true,
    "image": "ubuntu-20.04",
    "labels": {
      "environment": "n8n-test",
    },
    "automount": false,
    "public_net": {
      "enable_ipv4": true,
      "enable_ipv6": false
    }
  }' \
  "https://api.hetzner.cloud/v1/servers"


curl \
	-H "Authorization: Bearer 0LcVJr6MZnNqtixLhKO2jDsLJobeJRhAtgl0amxHC4Rn3n5tmhrxl0EOQy7DrmVT" \
	"https://api.hetzner.cloud/v1/firewalls"


{
    "name": "{{ $('SelfHost/HostForMe').item.json.body.subdomain }}",
    "datacenter": "nbg1-dc3",
    "server_type": "cpx41",
    "start_after_create": true,
    "image": "ubuntu-24.04",
    "ssh_keys": [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCg2GB5VT7otneTxcESJ9KRtE6w8wx38TyC9KY6vsqSRZfN+mfP/FK/7zyfO0jVEm5tt2CMYc49m6QiSg/NXllE2ILtutRwe057Q7pz5DTmGj0+XndsIqPs4auhWkkLP4JnkZqR1LupD8J8uFio7r72b2k/yhamkxz4T3zp4CoTTl9h9rIL9CObJCZ9N79W9LkJQzlw/nRaKwagemhMo2HdGaRpPQynridM2YP0fgJjlvPjqPfPBjg/tpYZK89RWZ3cE1+w2XO42w4MTWRbbiJvH8K051ZQ8DOWs9yqZAQ9GSROvNEBkWbhgGwiJSz2DXKOqNnTsh8ESqezzR31YyjG9xpDkcLykmqg8cUmW5D3jxA/vr0n0lYD4jNX24w7URXEZgOM3MuE7alPzJ9cb5F6h5gpjQ42ZJ0XxWwXE0D7WLiwSCdmIMzwSSJ7h30Pz1lzx8sSFwmkFBgBv7wYbStPjdnx/FYJiRTW5mCCrle0xxG0iwNKe0w3KQqu10nNcu0= amdavamc@Amdavas-MacBook-Pro.local"
    ],
    "labels": {
      "environment": "{{ $('SelfHost/HostForMe').item.json.body.subdomain }}"
    },
    "firewalls": [
      {
        "firewall": "1913092"
      }
    ],
    "automount": false,
    "public_net": {
      "enable_ipv4": true,
      "enable_ipv6": false
    }
  }