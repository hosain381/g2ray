#!/bin/bash
URL="https://ifconfig.me"   # اینجا هر آدرسی را می‌توانی جایگزین کنی
echo "Fetching $URL ..."
curl -s -L --max-time 15 "$URL"
