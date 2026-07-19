#!/usr/bin/env bash

set -e

APP="MeTify"
HOSTNAME="metify"
CPU="2"
RAM="512"
DISK="10"
OS_VERSION="13"

REPO="https://github.com/Kikkerslijm410/MeTify.git"
BRANCH="7-add-proxmox-support"

echo "====================================="
echo "  ${APP} Proxmox Installer"
echo "====================================="

if [[ $EUID -ne 0 ]]; then
  echo "Run als root."
  exit 1
fi

CTID=$(pvesh get /cluster/nextid)

echo ""
echo "Container ID : $CTID"
echo "CPU          : $CPU"
echo "RAM          : ${RAM}MB"
echo "Disk         : ${DISK}GB"
echo ""

STORAGE=$(pvesm status | awk '$3=="active" {print $1}' | head -n1)

TEMPLATE=$(pveam available --section system | \
grep "debian-${OS_VERSION}-standard" | \
tail -n1 | awk '{print $2}')

echo "Template: $TEMPLATE"

pveam update >/dev/null

if ! pveam list local | grep -q "$TEMPLATE"; then
  pveam download local "$TEMPLATE"
fi

pct create "$CTID" "local:vztmpl/${TEMPLATE}" \
  --hostname "$HOSTNAME" \
  --cores "$CPU" \
  --memory "$RAM" \
  --swap "$RAM" \
  --rootfs "${STORAGE}:${DISK}" \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

pct start "$CTID"

echo "Wachten op container..."

sleep 15

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

pct exec "$CTID" -- bash -c "
git clone -b ${BRANCH} ${REPO} /opt/metify

cd /opt/metify

python3 -m venv .venv

source .venv/bin/activate

pip install --upgrade pip

pip install -r requirements.txt

mkdir -p /downloads
"

pct exec "$CTID" -- bash -c "cat > /etc/systemd/system/metify.service << EOF
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
EOF"

pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl enable metify
pct exec "$CTID" -- systemctl start metify

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

echo ""
echo "====================================="
echo " INSTALL COMPLETE"
echo "====================================="
echo "CTID : $CTID"
echo "URL  : http://${IP}:5000"
echo ""
echo "Logs:"
echo "pct exec ${CTID} -- journalctl -u metify -f"
echo ""