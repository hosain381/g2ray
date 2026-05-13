#!/bin/bash
set -e  # توقف در صورت بروز خطا (بدون set -x برای امنیت)

REPO="hosain381/g2ray"
BRANCH="main"

# --- ۱. نصب GitHub CLI (اگر نصب نباشد) ---
echo "=== نصب پیش‌نیازها ==="
if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

# --- ۲. احراز هویت امن (بدون چاپ توکن) ---
echo "=== احراز هویت در GitHub CLI ==="
export GH_TOKEN="$GH_PAT"
gh auth status  # فقط برای بررسی

# تنظیم git برای استفاده از اعتبارنامه gh
gh auth setup-git

# پیکربندی git برای commit
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# --- ۳. ایجاد فایل‌های ضروری برای راه‌اندازی خودکار Xray ---
echo "=== ایجاد اسکریپت راه‌انداز Xray ==="
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

# --- ۴. ثبت تغییرات در مخزن ---
echo "=== ثبت و ارسال تغییرات ==="
git add .devcontainer/start-xray.sh .devcontainer/devcontainer.json
if git diff --staged --quiet; then
    echo "تغییری برای commit وجود ندارد."
else
    git commit -m "افزودن راه‌انداز خودکار Xray"
    git push origin "$BRANCH"  # امن با gh auth setup-git
fi

# --- ۵. مدیریت Codespace ---
echo "=== حذف Codespace قدیمی (در صورت وجود) ==="
gh codespace delete --codespace super-duper-acorn-x5qrgwwr5rq9h9qpv 2>/dev/null || echo "Codespace قدیمی وجود نداشت."

echo "=== ساخت Codespace جدید (۵-۷ دقیقه صبر کنید) ==="
gh codespace create --repo "$REPO" --branch "$BRANCH" --machine basicLinux32gb --idle-timeout 60m 2>&1 | tee /tmp/create_output.txt

CODESPACE_NAME=$(grep -oE 'codespace-[a-zA-Z0-9]+-[a-zA-Z0-9]+' /tmp/create_output.txt | tail -1)
if [ -z "$CODESPACE_NAME" ]; then
    echo "❌ نتوانستیم نام Codespace جدید را پیدا کنیم."
    exit 1
fi
echo "✅ Codespace جدید: $CODESPACE_NAME"

echo "=== منتظر آماده‌سازی (حداکثر ۶ دقیقه) ==="
for i in {1..36}; do
    STATE=$(gh codespace list --repo "$REPO" --json name,state --jq ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
    if [ "$STATE" = "Available" ]; then
        echo "✅ Codespace آماده شد."
        break
    fi
    sleep 10
done

# --- ۶. لینک نهایی ---
SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"
echo "=== ✅ لینک VLESS شما ==="
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt

echo "تمام. می‌توانید لینک را از فایل vless_link.txt بردارید."
