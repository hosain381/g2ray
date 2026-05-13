#!/bin/bash
echo "=== تست دامنه‌های کاندید برای تونل ==="
for domain in github.io pages.dev workers.dev trycloudflare.com; do
  echo -n "Testing $domain ... "
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://$domain")
  if [ "$HTTP_CODE" != "000" ]; then
    echo "✅ باز (HTTP $HTTP_CODE)"
  else
    echo "❌ بسته یا تایم‌اوت"
  fi
done
echo "=== پایان تست ==="
