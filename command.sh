#!/bin/bash
CODESPACE_NAME="super-duper-acorn-x5qrgwwr5rq9h9qpv"
SNI="${CODESPACE_NAME}-443.app.github.dev"
VLESS_LINK="vless://550e8400-e29b-41d4-a716-446655440000@${SNI}:443?encryption=none&security=tls&type=xhttp&mode=packet-up"

echo "=== لینک VLESS ==="
echo "$VLESS_LINK"
echo "$VLESS_LINK" > ./vless_link.txt
