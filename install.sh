#!/usr/bin/env bash
set -euo pipefail
clear

echo "======================================="
echo "        MeTify LXC Installer"
echo "======================================="
echo

if [[ $EUID -ne 0 ]]; then
    echo "Run as root."
    exit 1
fi

command -v pct >/dev/null || {
    echo "This script must run on a Proxmox host."
    exit 1
}

NEXTID=$(pvesh get /cluster/nextid)
read -rp "Container ID [100]: " CTID
CTID=${CTID:-$NEXTID}

if pct status "$CTID" >/dev/null 2>&1; then
    echo "Container ID $CTID already exists."
    exit 1
fi

read -rp "Hostname [metify]: " HOSTNAME
HOSTNAME=${HOSTNAME:-metify}

read -rp "RAM MB [512]: " RAM
RAM=${RAM:-512}

read -rp "CPU cores [2]: " CORES
CORES=${CORES:-2}

read -rp "Disk size [10]: " DISK
DISK=${DISK:-10}

echo
echo "Available storage:"
echo "--------------------------------"
pvesm status | awk '{print $1}'
echo "--------------------------------"
echo
read -rp "Storage [local-lvm]: " STORAGE
STORAGE=${STORAGE:-local-lvm}

echo
echo "Container configuration"
echo "--------------------------------"
echo "CTID      : $CTID"
echo "Hostname  : $HOSTNAME"
echo "RAM       : ${RAM}MB"
echo "CPU       : $CORES"
echo "Disk      : ${DISK}GB"
echo "Storage   : $STORAGE"
echo "--------------------------------"
echo

read -rp "Continue? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    exit 0
fi


pveam update

TEMPLATE=$(pveam available | grep debian-12-standard | tail -1 | awk '{print $2}')

if ! pveam list local | grep -q debian-12-standard; then
    pveam download local "$TEMPLATE"
fi

echo
echo "Creating container..."
TEMPLATE_FILE=$(pveam list local | grep debian-13-standard | tail -1 | awk '{print $1}')
echo "Using template: $TEMPLATE_FILE"

pct create "$CTID" "$TEMPLATE_FILE" \
    --hostname "$HOSTNAME" \
    --cores "$CORES" \
    --memory "$RAM" \
    --rootfs "$STORAGE:$DISK" \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1

pct start "$CTID"

echo
echo "Starting container..."
sleep 15

pct exec "$CTID" -- bash -c "
apt update &&
apt install -y git python3 python3-pip python3-venv
"

pct exec "$CTID" -- bash -c "
mkdir -p /opt &&
cd /opt &&
rm -rf metify &&
git clone \
  --depth 1 \
  --branch 7-add-proxmox-support \
  https://github.com/Kikkerslijm410/MeTify.git \
  metify
"

pct exec "$CTID" -- bash -c "
cd /opt/metify &&
python3 -m venv .venv &&
source .venv/bin/activate &&
python -m pip install --upgrade pip &&
python -m pip install -r requirements.txt &&
mkdir -p /downloads
"


pct exec "$CTID" -- bash -c "
cat > /etc/systemd/system/metify.service << EOF
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

User=root
Group=root

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable metify
systemctl restart metify
sleep 3
systemctl --no-pager --full status metify
"

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

echo
echo "================================="
echo " Installation completed!"
echo "================================="
echo
echo "Container ID : $CTID"
echo "IP adress    : $IP"
echo
echo "http://$IP:5000"
