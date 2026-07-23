#!/usr/bin/env bash
set -euo pipefail
clear

echo "======================================="
echo "        MeTify LXC Installer"
echo "======================================="
echo

# ID
NEXTID=$(pvesh get /cluster/nextid)
read -rp "Container ID: " CTID
CTID=${CTID:-$NEXTID}

if pct status "$CTID" >/dev/null 2>&1; then
    echo "Container ID $CTID already exists."
    exit 1
fi

# Hostname
read -rp "Hostname [default: metify]: " HOSTNAME
HOSTNAME=${HOSTNAME:-metify}

# RAM
read -rp "RAM MB [default: 512]: " RAM
RAM=${RAM:-512}

# CPU cores
read -rp "CPU cores [default: 2]: " CORES
CORES=${CORES:-2}

# DISK size
read -rp "Disk size [default: 10]: " DISK
DISK=${DISK:-10}

# Template selection
echo "Available templates:"
echo "--------------------------------"

mapfile -t TEMPLATES < <(pveam list local | awk '{print $1}' | grep -E 'debian|ubuntu')

for i in "${!TEMPLATES[@]}"; do
    echo "$((i+1))) ${TEMPLATES[$i]}"
done

echo "--------------------------------"
read -rp "Template number: " TEMPLATE_NUM

if [[ ! "$TEMPLATE_NUM" =~ ^[0-9]+$ ]] || [ "$TEMPLATE_NUM" -lt 1 ] || [ "$TEMPLATE_NUM" -gt "${#TEMPLATES[@]}" ]; then
    echo "Invalid template selection."
    exit 1
fi

TEMPLATE_FILE="${TEMPLATES[$((TEMPLATE_NUM-1))]}"

# Storage selection
echo "Available storage:"
echo "--------------------------------"

mapfile -t STORAGES < <(pvesm status | awk 'NR>1 {print $1}')

for i in "${!STORAGES[@]}"; do
    echo "$((i+1))) ${STORAGES[$i]}"
done

echo "--------------------------------"
read -rp "Storage number: " STORAGE_NUM
STORAGE_NUM=${STORAGE_NUM:-1}

if [[ ! "$STORAGE_NUM" =~ ^[0-9]+$ ]] || [ "$STORAGE_NUM" -lt 1 ] || [ "$STORAGE_NUM" -gt "${#STORAGES[@]}" ]; then
    echo "Invalid storage selection."
    exit 1
fi

STORAGE="${STORAGES[$((STORAGE_NUM-1))]}"

echo
echo "Container configuration"
echo "--------------------------------"
echo "CTID      : $CTID"
echo "Hostname  : $HOSTNAME"
echo "RAM       : ${RAM}MB"
echo "CPU       : $CORES"
echo "Disk      : ${DISK}GB"
echo "Storage   : $STORAGE"
echo "Template  : $TEMPLATE_FILE"
echo "--------------------------------"
echo
read -rp "Continue? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    exit 0
fi

pveam update

echo
echo "Creating container..."

pct create "$CTID" "$TEMPLATE_FILE" \
    --hostname "$HOSTNAME" \
    --cmode shell \
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
apt install -y git python3 python3-pip python3-venv ffmpeg
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
./.venv/bin/python -m pip install --upgrade pip &&
./.venv/bin/python -m pip install -r requirements.txt &&
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
ExecStart=/opt/metify/.venv/bin/python3 /opt/metify/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable metify
systemctl restart metify
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
