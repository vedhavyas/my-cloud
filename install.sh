#!/bin/zsh

# setup
echo "Setting up Hub..."
script_path=$(realpath "$0")
root_dir=$(dirname "${script_path}")
export CONF_DIR="${root_dir}"/conf
export DATA_DIR="${root_dir}"/data
export SRV_DIR="${root_dir}"/services

# set up dns to cloudflare
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# install
for arg in upgrades docker; do
  if ! "${SRV_DIR}"/"${arg}"/install.sh; then
    exit 1
  fi
done

# start services
for arg in ssh wireguard docker vpn dns; do
  if ! "${SRV_DIR}"/"${arg}"/start.sh; then
    exit 1
  fi
done

# setup script self to run on every boot
# TODO: better name
# sym link to init.d
chmod +x "${script_path}"
ln -sf  "${script_path}" /etc/init.d/hub
# sym link to rc level 3, start last
# https://unix.stackexchange.com/a/83753/310751
ln -sf /etc/init.d/hub /etc/rc3.d/S99hub
echo "Hub installation completed."
