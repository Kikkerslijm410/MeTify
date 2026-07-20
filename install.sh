#!/usr/bin/env bash

set -euo pipefail

APP="MeTify"
REPO="https://github.com/Kikkerslijm410/MeTify.git"
BRANCH="7-add-proxmox-support"

clear

echo "======================================="
echo "        MeTify LXC Installer"
echo "======================================="
echo ""

NEXTID=$(pvesh get /cluster/nextid)

echo "Beschikbare storages:"
pvesm status
echo ""

read -p "Container ID [$NEXTID]: " CTID
CTID=${CTID:-$NEXTID}

read -p "Hostname [metify]: " HOSTNAME
HOSTNAME=${HOSTNAME:-metify}

read -es [2]: " CPU
CPU=${CPU:-2}

read -p "RAM MB]: " RAM
RAM=${RAM:-512}

read - GB [10]: " DISK
DISK=${DISK:-10}

read -p "Container Storage (bv zfs01): " STORAGE ""
echo "Beschikbare bridges:"
ip -o link show | awk -F': ' '/vmbr/ {print $2}'
echo ""

read -p "Bridge [vmbr0]: " BRIDGE
BRIDGE=${BRIDGE:-vmbr0} "Debian versie [13]: " DEBIAN
DEBIAN=${DEBIAN:-13}

echo ""
echo "======================================="
echo "Container ID : $CTID"
echo "Hostname     : $HOSTNAME"
echo "CPU          : $CPU"
echo "RAM          : ${RAM}MB"
echo "Disk         : ${DISK}GB"
echo "Storage      : $STORAGE"
echo "Bridge       : $BRIDGE"
echo "Debian       : $DEBIAN"
echo "======================================="
echo ""

read -p "Doorgaan? (y CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  exit 0
fi

echo ""
echo "[1/7] Template zoeken"

pveam update >/dev/null

TEMPLATE=$(
  pveam available --section system |
  grep "debian-${DEBIAN}-standard" |
  tail -n1 |
  awk '{print $2}'
)

if [[ -z "$TEMPLATE" ]]; then
  echo "Debian template niet gevonden"
  exit 1
fi

TEMPLATE_STORAGE="local"

echo "[2/7] Template downloaden"

if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

echo "[3/7] Container maken"

pct create "$CTID" \
  "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
  --hostname "$HOSTNAME" \
  --cores "$CPU" \
  --memory "$RAM" \
  --swap "$RAM" \
  --rootfs "${STORAGE}:${DISK}" \
  --net0 name=eth0,bridge="$BRIDGE",ip=dhcp \
  --features nesting=1 \
  --unprivileged 1 \
  --onboot 1

echo "[4/7] Container starten"

pct start "$CTID"

sleep 20

echo "[5/7] Dependencies installeren"

pct exec "$CTID" -- bash -c "
apt update

apt install -y \
  git \
  curl \
  ffmpeg \
  python3 \
  python3-pip \
  python3-venv
"

echo "[6/7] MeTify installeren"

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

echo "[7/7] Service aanmaken"

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

sleep 3

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

echo ""
echo "======================================="
echo "Installation Complete"
echo "======================================="
echo ""
echo "Container ID : $CTID"
echo "IP Address   : $IP"
echo ""
echo "Open:"
echo "http://${IP}:5000"
echo ""
echo "Logs:"
echo "pct exec $CTID -- journalctl -u metify -f"
echo ""