#!/bin/bash
echo "=== Starting Secure Tunnel ==="
# نصب یک پروکسی ساده
sudo apt update -qq && sudo apt install -y nginx
# ایجاد یک صفحه HTML که محتوای سایت دیگر را در خود جای دهد
sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<html>
<body>
  <h1>Proxy Active</h1>
  <iframe src="https://ifconfig.me" width="100%" height="500px"></iframe>
</body>
</html>
EOF
sudo systemctl start nginx
# تونل کردن با localhost.run (که دامنه .lhrtunnel.com دارد)
TUNNEL_URL=$(curl -s localhost.run -d "port=80" 2>&1 | grep -oE 'https?://[^ ]+')
# حالا یک لینک Google Translate برای عبور از فیلتر می‌سازیم
echo "Your Proxy URL: https://translate.google.com/translate?hl=en&sl=en&tl=fa&u=$TUNNEL_URL"
