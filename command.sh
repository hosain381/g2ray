#!/bin/bash
set -e

CODESPACE_NAME="super-duper-acorn-x5qrgwwr5rq9h9qpv"

# نصب GitHub CLI (اگر نصب نیست)
if ! command -v gh &>/dev/null; then
    echo "=== نصب GitHub CLI ==="
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

# احراز هویت با توکن (که از محیط خوانده می‌شود)
echo "=== ورود به GitHub CLI ==="
echo "$GH_PAT" | gh auth login --with-token

# --- عملیات روی Codespace ---
echo "=== بررسی و راه‌اندازی Xray در Codespace ==="
gh codespace ssh -c "$CODESPACE_NAME" -- "bash -s" << 'REMOTE_SCRIPT'
set -e

# نصب Xray اگر موجود نباشد
if [ ! -f /usr/local/bin/xray ]; then
    echo "نصب Xray..."
    wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip
    unzip -q /tmp/xray.zip -d /tmp/xray_install
    sudo cp /tmp/xray_install/xray /usr/local/bin/xray
    sudo chmod +x /usr/local/bin/xray
    rm -rf /tmp/xray.zip /tmp/xray_install
    echo "Xray نصب شد."
else
    echo "Xray از قبل نصب است."
fi

# متوقف کردن Xray قبلی (اگر در حال اجراست)
sudo pkill xray 2>/dev/null || true

# ایجاد پیکربندی G2Ray
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

echo "اجرای Xray..."
nohup sudo /usr/local/bin/xray -c /etc/config.json > /tmp/xray.log 2>&1 &
sleep 2

# بررسی اینکه Xray در حال اجراست
if ps aux | grep -v grep | grep xray > /dev/null; then
    echo "✅ Xray با موفقیت اجرا شد."
else
    echo "❌ Xray اجرا نشد. لاگ:"
    cat /tmp/xray.log
    exit 1
fi
REMOTE_SCRIPT

echo "=== ✅ لینک VLESS نهایی ==="
SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt

echo ""
echo "⚠️ پس از استفاده، Codespace را متوقف کنید:"
echo "gh codespace stop -c $CODESPACE_NAME"
