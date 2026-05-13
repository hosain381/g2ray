#!/bin/bash
# فعال کردن نمایش خطاها و ذخیره‌ی همه در output.txt
exec 2>&1
set -x  # همه دستورات رو قبل از اجرا نشون بده

REPO="hosain381/g2ray"
BRANCH="main"

echo "=== نصب GitHub CLI (اگر نباشه) ==="
if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

echo "=== ورود به GitHub CLI ==="
echo "$GH_PAT" | gh auth login --with-token

# پیکربندی git
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

echo "=== ایجاد فایل‌های ضروری ==="
mkdir -p .devcontainer

# ساخت start-xray.sh
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

# به‌روزرسانی devcontainer.json
if [ -f .devcontainer/devcontainer.json ]; then
    sudo apt update -qq && sudo apt install -y jq
    jq '. + {"postCreateCommand": "bash .devcontainer/start-xray.sh"}' .devcontainer/devcontainer.json > tmp.json && mv tmp.json .devcontainer/devcontainer.json
else
    cat > .devcontainer/devcontainer.json << 'DEVEOF'
{
    "postCreateCommand": "bash .devcontainer/start-xray.sh"
}
DEVEOF
fi

echo "=== تلاش برای commit و push ==="
git add .devcontainer/start-xray.sh .devcontainer/devcontainer.json
if git diff --staged --quiet; then
    echo "هیچ تغییری برای commit وجود نداره. ادامه می‌دیم."
else
    git commit -m "Auto-start Xray on boot"
    git push origin "$BRANCH" || {
        echo "Push با شکست مواجه شد. تلاش با توکن مستقیم..."
        git push https://x-access-token:$GH_PAT@github.com/$REPO.git "$BRANCH"
    }
fi

echo "=== حذف Codespace قدیمی ==="
gh codespace delete --codespace super-duper-acorn-x5qrgwwr5rq9h9qpv 2>/dev/null || echo "Codespace قدیمی وجود نداشت."

echo "=== ساخت Codespace جدید (۵-۷ دقیقه صبر) ==="
gh codespace create --repo "$REPO" --branch "$BRANCH" --machine basicLinux32gb --idle-timeout 60m 2>&1 | tee /tmp/create_output.txt

CODESPACE_NAME=$(grep -oE 'codespace-[a-zA-Z0-9]+-[a-zA-Z0-9]+' /tmp/create_output.txt | tail -1)
if [ -z "$CODESPACE_NAME" ]; then
    echo "❌ نتونستیم نام Codespace رو پیدا کنیم."
    exit 1
fi
echo "✅ Codespace جدید: $CODESPACE_NAME"

echo "=== منتظر آماده‌سازی (حداکثر ۶ دقیقه) ==="
for i in {1..36}; do
    STATE=$(gh codespace list --repo "$REPO" --json name,state --jq ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
    if [ "$STATE" = "Available" ]; then
        echo "✅ آماده شد."
        break
    fi
    sleep 10
done

# لینک نهایی
SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"
echo "=== ✅ لینک VLESS ==="
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt

echo "تمام."
