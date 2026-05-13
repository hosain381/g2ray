#!/bin/bash
set -e

echo "=== نصب OpenSSH Server ==="
sudo apt update -qq && sudo apt install -y openssh-server

echo "=== تنظیم SSH برای پروکسی SOCKS5 ==="
mkdir -p ~/.ssh
# تولید یه جفت کلید موقت برای امنیت
ssh-keygen -t rsa -b 4096 -f ~/.ssh/tunnel_key -N "" -q
sudo cp ~/.ssh/tunnel_key.pub /root/authorized_keys_temp
sudo mkdir -p /root/.ssh
sudo touch /root/.ssh/authorized_keys
sudo cat /root/authorized_keys_temp >> /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

echo "=== راه‌اندازی SSH Daemon روی پورت ۴۴۳ ==="
sudo /usr/sbin/sshd -p 443 -o PermitRootLogin=yes -o AllowTcpForwarding=yes &

echo "=== ایجاد تونل عمومی ==="
# استفاده از localhost.run که با SSH کار می‌کنه و دامنه‌ش معمولاً بازه
nohup ssh -o StrictHostKeyChecking=no -R 80:localhost:443 localhost.run > /tmp/tunnel_info.txt 2>&1 &
sleep 10

echo "=== اطلاعات تونل ==="
cat /tmp/tunnel_info.txt
TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9.-]+' /tmp/tunnel_info.txt | head -1)
if [ -n "$TUNNEL_URL" ]; then
    echo "✅ تونل عمومی: $TUNNEL_URL"
    echo "TUNNEL_URL=$TUNNEL_URL" > ./tunnel_info.txt
else
    echo "❌ نتونستیم تونل رو بسازیم."
    echo "TUNNEL_URL=FAILED" > ./tunnel_info.txt
fi

echo "=== ذخیره کلید خصوصی ==="
cat ~/.ssh/tunnel_key
cp ~/.ssh/tunnel_key ./tunnel_key.pem
echo "کلید خصوصی در فایل tunnel_key.pem ذخیره شد."

# نگه داشتن رانر برای ۳۰ دقیقه
echo "رانر تا ۳۰ دقیقه آینده زنده می‌مونه. سریع وصل شو!"
sleep 1800
