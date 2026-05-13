#!/bin/bash
set -e
if [ ! -f /usr/local/bin/xray ]; then
    wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip
    unzip -q /tmp/xray.zip -d /tmp/xray_install
    sudo cp /tmp/xray_install/xray /usr/local/bin/xray
    sudo chmod +x /usr/local/bin/xray
    rm -rf /tmp/xray.zip /tmp/xray_install
fi
sudo pkill xray 2>/dev/null || true
sudo mkdir -p /etc
sudo tee /etc/config.json > /dev/null << 'CONFIG'
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "550e8400-e29b-41d4-a716-446655440000"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "xhttp",
      "xhttpSettings": {
        "mode": "packet-up",
        "path": "/"
      }
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
CONFIG
nohup sudo /usr/local/bin/xray -c /etc/config.json > /tmp/xray.log 2>&1 &
