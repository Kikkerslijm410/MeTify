#!/usr/bin/env bash

set -euo pipefail

APP="MeTify"
REPO="https://github.com/Kikkerslijm410/MeTify.git"
BRANCH="7-add-proxmox-support"

clear

echo "======================================="
echo "        ${APP} LXC Installer"
echo "======================================="
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "Run as root."
    exit 1
fi

command -v pct >/dev/null || {
    echo "This script must run on a Proxmox host."
    exit 1
}

NEXTID=$(pvesh get /cluster/nextid)

echo "Available Storages:"
pvesm status
echo ""

read -rp "Container ID [$NEXTID]: " CTID
CTID=${CTID:-$NEXTID}

if pct status "$CTID" >/dev/null 2>&1; then
    echo "Container ID $CTID already exists."
    exit 1
fi

read -rp "Hostname [metify]: " HOSTNAME
HOSTNAME=${HOSTNAME:-metify}

read ores [2]: " CPU
CPU=${CPU:-2}

read -AM MB [512]: " RAM
RAM=${RAM:-512}

read -k GB [10]: " DISK
DISK=${DISK:-10}

echo ""
echo "Container Storage (example: zfs01, local-lvmd -rp "Storage: " STORAGE

if ! pvesm status | awk '{print $1}' | grep -qx "$STORAGE"; then
    echo "Storage '$STORAGE' does not exist."
    exit 1
fi

echo ""
echo "Available Bridges:"
ip -o link show | awk -F': ' '/vmbr/ {print $2}'
echo ""

read -rp "Bridge [vmbr0]: " BRIDGE
BRIDGE=${BRIDGE:-vmbr0}

read -rp "Debian[13]: " DEBIAN
DEBIAN=${DEBIAN:-13}

echo ""
echo "======================================="
echo "Configuration"
echo "======================================="
echo "CTID      : $CTID"
echo "Hostname  : $HOSTNAME"
echo "CPU       : $CPU"
echo "RAM       : ${RAM} MB"
echo "Disk      : ${DISK} GB"
echo "Storage   : $STORAGE"
echo "Bridge    : $BRIDGE"
echo "Debian    : $DEBIAN"
echo ""

read -rp "Continue? (y/N): " CONFIRM

[[ "$CONFIRM" =~ ^]] || exit 0

echo ""
echo "[1/7] Updating template list"

pveam update >/dev/null

TEMPLATE=$(
    pveam available --section system |
    grep "debian-${DEBIAN}-standard" |
    tail -n1 |
    awk '{print $2}'
)

if [[ -z "$TEMPLATE" ]]; then
    echo "Debian ${DEBIAN} template not found."
    exit 1
fi

TEMPLATE_STORAGE="local"

echo "[2/7] Downloading template"

if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

echo "[3/7] Creating container"

pct create "$CTID" \
    "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
    --hostname "$HOSTNAME" \
    --cores "$CPU" \
    --memory "$RAM" \
    --swap "$RAM" \
    --rootfs "${STORAGE}:${DISK}" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp" \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1

echo "[4/7] Starting container"

pct start "$CTID"

sleep 20

echo "[5/7] Installing dependencies"

pct exec "$CTID" -- bash -c '
apt-get update

apt-get install -y \
    git \
    curl \
    ffmpeg \
    python3 \
    python3-pip \
    python3-venv
'

echo "[6/7] Installing MeTify"

pct exec "$CTID" -- bash -c "
git clone \
  --depth 1 \
  --branch ${BRANCH} \
  ${REPO} \
  /opt/metify

cd /opt/metify

python3 -m venv .venv

source .venv/bin/activate

pip install --upgrade pip

pip install -r requirements.txt

mkdir -p /downloads
"

echo "[7/7] Creating service"

pct exec "$CTID" -- bash -c 'cat > /etc/systemd/system/metify.service <<EOF
[Unit]
Description=MeTify
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/metify
Environment=DOWNLOAD_DIR=/downloads
ExecStart=/opt/metify/.venv/bin/python /opt/metify/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl enable metify
pct exec "$CTID" -- systemctl start metify

sleep 5

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

echo ""
echo "======================================="
echo "Installation Complete"
echo "======================================="
echo ""
echo "CTID : $CTID"
echo "IP   : $IP"
echo ""
echo "Open:"
echo "http://${IP}:5000"
echo ""
echo "Logs:"
echo "pct exec ${CTID} -- journalctl -u metify -f"
echo ""
