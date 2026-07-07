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
description

msg_ok "Completed Successfully!"

echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access MeTify at:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:5000${CL}"