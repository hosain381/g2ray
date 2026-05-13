#!/bin/bash
CODESPACE_NAME="super-duper-acorn-x5qrgwwr5rq9h9qpv"
SNI="${CODESPACE_NAME}-443.app.github.dev"

echo "=== تست اتصال TCP به پورت ۴۴۳ ==="
# تلاش برای برقراری اتصال TCP (با timeout کوتاه)
timeout 5 bash -c "echo >/dev/tcp/${SNI}/443" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ پورت ۴۴۳ باز است (TCP connection successful)"
else
    echo "❌ پورت ۴۴۳ بسته است یا در دسترس نیست"
fi

echo ""
echo "=== تست TLS handshake (گرفتن گواهی) ==="
# تلاش برای گرفتن گواهی SSL
echo | timeout 5 openssl s_client -connect "${SNI}:443" -servername "${SNI}" 2>&1 | grep -E "subject=|issuer=|Verify return code"
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ TLS handshake موفقیت‌آمیز بود"
else
    echo "❌ TLS handshake شکست خورد"
fi

echo ""
echo "=== تلاش برای صحبت با Xray با یه درخواست HTTP ساده ==="
# Xray با xhttp ممکنه به یه درخواست HTTP معمولی جواب نده، ولی ما چک می‌کنیم
curl -s -o /dev/null -w "HTTP code: %{http_code}\n" --connect-timeout 5 --max-time 10 "https://${SNI}/" || echo "Curl failed"
