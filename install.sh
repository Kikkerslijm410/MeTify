#!/usr/bin/env bash

set -euo pipefail

APP="MeTify"
HOSTNAME="metify"
CPU="2"
RAM="512"
DISK="10"
BRANCH="7-add-proxmox-support"
REPO="https://github.com/Kikkerslijm410/MeTify.git"

echo "====================================="
echo " ${APP} Proxmox Installer"
echo "====================================="
echo ""

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root."
  exit 1
fi

command -v pct >/dev/null || {
  echo "This script must run on a Proxmox host."
  exit 1
}

echo "[1/8] Detecting storage"

ROOTFS_STORAGE=$(
  pvesm status | awk '
    $2=="zfspool" && $3=="active" {print $1; exit}
    $2=="lvmthin" && $3=="active" {print $1; exit}
    $2=="dir" && $3=="active" {print $1; exit}
  '
)

if [[ -z "$ROOTFS_STORAGE" ]]; then
  echo "No valid container storage found."
  exit 1
fi

TEMPLATE_STORAGE=$(
  pvesm status | awk '
    $2=="dir" && $3=="active" {print $1; exit}
  '
)

if [[ -z "$TEMPLATE_STORAGE" ]]; then
  echo "No template storage found."
  exit 1
fi

echo "Container Storage : $ROOTFS_STORAGE"
echo "Template Storage  : $TEMPLATE_STORAGE"

CTID=$(pvesh get /cluster/nextid)

echo "[2/8] Updating templates"
pveam update >/dev/null

TEMPLATE=$(pveam available --section system | \
  grep "debian-13-standard" | \
  tail -n1 | awk '{print $2}')

if [[ -z "$TEMPLATE" ]]; then
  echo "Debian 13 template not found."
  exit 1
fi

if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
  echo "[3/8] Downloading Debian template"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

echo "[4/8] Creating container"

pct create "$CTID" \
  "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CPU" \
  --memory "$RAM" \
  --swap "$RAM" \
  --rootfs "$ROOTFS_STORAGE:$DISK" \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1 \
  --unprivileged 1 \
  --onboot 1

echo "[5/8] Starting container"

pct start "$CTID"

sleep 20

echo "[6/8] Installing dependencies"

pct exec "$CTID" -- bash -c '
export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  git \
  curl \
  ffmpeg \
  python3 \
  python3-pip \
  python3-venv
'

echo "[7/8] Installing MeTify"

pct exec "$CTID" -- bash -c "
git clone --depth 1 \
  --branch $BRANCH \
  $REPO \
  /opt/metify

cd /opt/metify

python3 -m venv .venv

source .venv/bin/activate

pip install --upgrade pip

pip install -r requirements.txt

mkdir -p /downloads
"

echo "[8/8] Creating service"

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

IP=$(pct exec "$CTID" -- hostname -I | awk "{print \$1}")

echo ""
echo "====================================="
echo " Installation Completed"
echo "====================================="
echo ""
echo "Container ID : $CTID"
echo "Storage      : $ROOTFS_STORAGE"
echo "CPU          : $CPU"
echo "RAM          : ${RAM}MB"
echo "Disk         : ${DISK}GB"
echo ""
echo "Open:"
echo "http://${IP}:5000"
echo ""
echo "Logs:"
echo "pct exec $CTID -- journalctl -u metify -f"
echo ""