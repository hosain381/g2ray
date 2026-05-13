#!/bin/bash
set -e

REPO="hosain381/g2ray"
BRANCH="main"

# --- نصب GitHub CLI (اگر نباشد) ---
if ! command -v gh &>/dev/null; then
    echo "=== نصب GitHub CLI ==="
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

echo "=== ورود به GitHub CLI ==="
echo "$GH_PAT" | gh auth login --with-token

# --- پیکربندی git برای commit (همان کاربر actions) ---
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# --- ایجاد فایل‌های ضروری در همان workspace (که checkout شده) ---
echo "=== ایجاد start-xray.sh و به‌روزرسانی devcontainer.json ==="
mkdir -p .devcontainer

cat > .devcontainer/start-xray.sh << 'STARTSCRIPT'
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
STARTSCRIPT

chmod +x .devcontainer/start-xray.sh

# به‌روزرسانی devcontainer.json (اگر وجود نداشته باشد، ساخته می‌شود)
if [ -f .devcontainer/devcontainer.json ]; then
    # با jq ادغام می‌کنیم
    sudo apt update -qq && sudo apt install -y jq
    jq '. + {"postCreateCommand": "bash .devcontainer/start-xray.sh"}' .devcontainer/devcontainer.json > tmp.json && mv tmp.json .devcontainer/devcontainer.json
else
    cat > .devcontainer/devcontainer.json << 'DEVEOF'
{
    "postCreateCommand": "bash .devcontainer/start-xray.sh"
}
DEVEOF
fi

# --- Commit و push تغییرات ---
git add .devcontainer/start-xray.sh .devcontainer/devcontainer.json
git commit -m "Auto-start Xray on boot" || echo "No changes to commit"
git push origin "$BRANCH"

# --- حذف Codespace قدیمی (اگر وجود دارد) ---
echo "=== حذف Codespace قبلی ==="
gh codespace delete --codespace super-duper-acorn-x5qrgwwr5rq9h9qpv 2>/dev/null || echo "Codespace قبلی یافت نشد."

# --- ساخت Codespace جدید (با صبر کافی) ---
echo "=== ساخت Codespace جدید (۵-۷ دقیقه صبر) ==="
gh codespace create --repo "$REPO" --branch "$BRANCH" --machine basicLinux32gb --idle-timeout 60m 2>&1 | tee /tmp/create_output.txt

CODESPACE_NAME=$(grep -oE 'codespace-[a-zA-Z0-9]+-[a-zA-Z0-9]+' /tmp/create_output.txt | tail -1)
if [ -z "$CODESPACE_NAME" ]; then
    echo "❌ نتوانستیم نام Codespace را بیابیم. خروجی:"
    cat /tmp/create_output.txt
    exit 1
fi
echo "✅ Codespace جدید: $CODESPACE_NAME"

echo "=== منتظر آماده‌سازی (تا ۶ دقیقه) ==="
for i in {1..36}; do
    STATE=$(gh codespace list --repo "$REPO" --json name,state --jq ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
    if [ "$STATE" = "Available" ]; then
        echo "✅ آماده شد."
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
