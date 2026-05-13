#!/bin/bash
set -e

REPO="hosain381/g2ray"
BRANCH="master"

echo "=== نصب پیش‌نیازها ==="
if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y gh
fi

echo "=== احراز هویت ==="
export GH_TOKEN="$GH_PAT"
gh auth status
gh auth setup-git

echo "=== 🧹 پاکسازی همه Codespaceهای قبلی ==="
# گرفتن لیست همه Codespaceها
echo "لیست Codespaceهای فعلی:"
gh codespace list

# متوقف کردن و حذف همه Codespaceها
echo "در حال حذف همه Codespaceها..."
gh codespace delete --all --force 2>&1 || echo "هیچ Codespaceی برای حذف وجود نداشت."
sleep 5

echo "=== 🚀 ساخت Codespace جدید (۵-۷ دقیقه صبر) ==="
gh codespace create --repo "$REPO" --branch "$BRANCH" --machine basicLinux32gb --idle-timeout 60m 2>&1 | tee /tmp/create_output.txt

# استخراج نام — این بار با الگوی ساده‌تر
CODESPACE_NAME=$(grep -oE '[a-z]+-[a-z]+-[a-z]+-[a-z0-9]+' /tmp/create_output.txt | head -1)
if [ -z "$CODESPACE_NAME" ]; then
    echo "❌ نام Codespace پیدا نشد. خروجی خام:"
    cat /tmp/create_output.txt
    exit 1
fi
echo "✅ Codespace: $CODESPACE_NAME"

echo "=== منتظر آماده‌سازی (حداکثر ۶ دقیقه) ==="
for i in {1..36}; do
    STATE=$(gh codespace list --json name,state --jq ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
    if [ "$STATE" = "Available" ]; then
        echo "✅ آماده شد."
        break
    fi
    sleep 10
done

SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"
echo "=== ✅ لینک VLESS ==="
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt
