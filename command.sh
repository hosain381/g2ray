#!/bin/bash
set -e

REPO="hosain381/g2ray"
BRANCH="main"

# --- نصب GitHub CLI ---
if ! command -v gh &>/dev/null; then
    echo "=== نصب GitHub CLI ==="
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

echo "=== ورود به GitHub CLI ==="
echo "$GH_PAT" | gh auth login --with-token

# --- کلون مخزن و ویرایش devcontainer.json ---
echo "=== ویرایش devcontainer.json برای راه‌اندازی خودکار Xray ==="
git clone "https://x-access-token:$GH_PAT@github.com/$REPO.git" /tmp/repo
cd /tmp/repo/.devcontainer

# یک اسکریپت راه‌انداز می‌سازیم که Xray را نصب و اجرا کند
cat > start-xray.sh << 'STARTSCRIPT'
#!/bin/bash
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
STARTSCRIPT

chmod +x start-xray.sh

# اضافه کردن دستور postCreateCommand به devcontainer.json
# اگر فایل وجود دارد، postCreateCommand را اضافه/به‌روز می‌کنیم
if [ -f devcontainer.json ]; then
    # با jq کار می‌کنیم (اگر نصب نباشد، نصب می‌کنیم)
    if ! command -v jq &>/dev/null; then
        sudo apt update -qq && sudo apt install -y jq
    fi
    jq '. + {"postCreateCommand": "bash .devcontainer/start-xray.sh"}' devcontainer.json > tmp.json && mv tmp.json devcontainer.json
else
    # اگر فایل نبود، یک فایل ساده می‌سازیم
    cat > devcontainer.json << 'DEVEOF'
{
    "postCreateCommand": "bash .devcontainer/start-xray.sh"
}
DEVEOF
fi

git add start-xray.sh devcontainer.json
git commit -m "Auto-start Xray on Codespace boot"
git push origin "$BRANCH"

# --- بازسازی Codespace موجود ---
echo "=== بازسازی (rebuild) Codespace ==="
gh codespace rebuild --codespace super-duper-acorn-x5qrgwwr5rq9h9qpv 2>&1 || {
    echo "Rebuild ناموفق، تلاش برای ساخت Codespace جدید..."
    gh codespace create --repo "$REPO" --branch "$BRANCH" --machine basicLinux32gb --idle-timeout 60m 2>&1 | tee /tmp/create_output.txt
    CODESPACE_NAME=$(grep -oE 'codespace-[a-zA-Z0-9]+-[a-zA-Z0-9]+' /tmp/create_output.txt | tail -1)
}

# اگر rebuild موفق بود، همان نام قبلی را نگه می‌داریم
if [ -z "$CODESPACE_NAME" ]; then
    CODESPACE_NAME="super-duper-acorn-x5qrgwwr5rq9h9qpv"
fi

echo "=== منتظر آماده‌سازی Codespace (حداکثر ۶ دقیقه) ==="
for i in {1..36}; do
    STATE=$(gh codespace list --repo "$REPO" --json name,state --jq ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
    if [ "$STATE" = "Available" ]; then
        echo "✅ Codespace آماده است."
        break
    fi
    sleep 10
done

# --- لینک نهایی ---
SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"
echo "=== ✅ لینک VLESS ==="
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt
