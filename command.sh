#!/bin/bash
set -e

# 1. دانلود و نصب Xray
echo "downloading xray"
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip
echo "installing"
unzip -q /tmp/xray.zip -d /tmp/xray_install
sudo cp /tmp/xray_install/xray /usr/local/bin/xray
sudo chmod +x /usr/local/bin/xray
rm -rf /tmp/xray.zip /tmp/xray_install
echo "installed!"

# 2. ایجاد پیکربندی مستقیم (بدون نیاز به فایل در مخزن)
sudo mkdir -p /etc
sudo tee /etc/config.json > /dev/null << 'EOF'
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "550e8400-e29b-41d4-a716-446655440000"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "packet-up",
          "path": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 3. راه‌اندازی Xray در پس‌زمینه و ذخیره لاک
echo "Starting Xray..."
sudo /usr/local/bin/xray -c /etc/config.json > /tmp/xray.log 2>&1 &
sleep 3

# 4. ساخت لینک VLESS نهایی (در Codespace واقعی آدرس پورت ۴۴۳ متفاوت است)
# اینجا صرفاً ساختار لینک را نمایش می‌دهیم.
# برای استفاده در Codespace، باید CODESPACE_NAME را از متغیر محیطی بخوانید.
if [ -n "$CODESPACE_NAME" ]; then
  SNI="${CODESPACE_NAME}-443.app.github.dev"
else
  SNI="YOUR_CODESPACE_NAME_HERE-443.app.github.dev"
fi

VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"

echo "VLESS Link: $VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt
