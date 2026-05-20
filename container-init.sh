#!/bin/bash
set -e

echo "Starting pcscd..."
# pcscd をバックグラウンドで起動
pcscd --foreground --auto-exit --disable-polkit &

# pcscd の起動を少し待つ
sleep 2

echo "Checking smartcard readers:"
pcsc_scan -c || echo "Warning: pcsc_scan failed, but continuing..."

echo "Starting mirakc..."
# compose.yml でマウントしている /etc/mirakc/config.yml を読み込んで実行
# exec を使用して mirakc を PID 1 にします
exec mirakc --config /etc/mirakc/config.yml

