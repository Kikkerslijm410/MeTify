#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="MeTify"
var_tags="${var_tags:-media,download}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/metify ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping MeTify"
  systemctl stop metify
  msg_ok "Stopped MeTify"

  msg_info "Updating MeTify"
  cd /opt/metify
  git pull

  source venv/bin/activate
  pip install -r requirements.txt

  systemctl start metify
  msg_ok "Updated MeTify"

  exit
}

start
build_container

msg_info "Installing Dependencies"

apt-get update
apt-get install -y \
  git \
  ffmpeg \
  python3 \
  python3-pip \
  python3-venv

msg_ok "Installed Dependencies"

msg_info "Cloning Repository"

git clone https://github.com/Kikkerslijm410/MeTify.git /opt/metify

msg_ok "Repository Cloned"

msg_info "Creating Python Environment"

cd /opt/metify

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

mkdir -p /opt/metify/downloads

msg_ok "Python Environment Ready"

msg_info "Creating Service"

cat <<EOF >/etc/systemd/system/metify.service
[Unit]
Description=MeTify Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/metify
ExecStart=/opt/metify/venv/bin/python /opt/metify/app.py
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable metify
systemctl start metify

msg_ok "Service Created"

IP=$(hostname -I | awk '{print $1}')

msg_ok "Completed Successfully!"

echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access MeTify at:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:5000${CL}"