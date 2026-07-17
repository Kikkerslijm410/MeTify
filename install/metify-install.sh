#!/usr/bin/env bash
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors

msg_info "Installing Dependencies"

$STD apt-get update

$STD apt-get install -y \
  git \
  ffmpeg \
  python3 \
  python3-pip \
  python3-venv

msg_ok "Installed Dependencies"

msg_info "Cloning MeTify"

git clone \
  -b 7-add-proxmox-support \
  https://github.com/Kikkerslijm410/MeTify.git \
  /opt/metify

msg_ok "Repository Downloaded"

msg_info "Creating Python Environment"

cd /opt/metify

python3 -m venv .venv

source .venv/bin/activate

pip install --upgrade pip

pip install -r requirements.txt

mkdir -p /downloads

msg_ok "Python Environment Ready"

msg_info "Creating Service"

cat <<EOF >/etc/systemd/system/metify.service
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
EOF

systemctl daemon-reload
systemctl enable metify
systemctl start metify

msg_ok "Service Created"

motd_ssh
customize

msg_ok "Finished Installation"
