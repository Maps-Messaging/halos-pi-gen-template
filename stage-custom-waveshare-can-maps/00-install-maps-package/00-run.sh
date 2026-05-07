#!/bin/bash -e

echo "Installing MAPS package and HALPI2 configuration"

install -d "${ROOTFS_DIR}/etc/apt/sources.list.d"
install -d "${ROOTFS_DIR}/etc/apt/trusted.gpg.d"
install -d "${ROOTFS_DIR}/usr/share/keyrings"
install -d "${ROOTFS_DIR}/etc/systemd/system/maps.service.d"
install -d "${ROOTFS_DIR}/opt/maps/conf"
install -d "${ROOTFS_DIR}/opt/maps_data"
install -d "${ROOTFS_DIR}/var/log/maps"

on_chroot << EOF
set -e

apt-get update
apt-get install -y curl gnupg ca-certificates

curl -fsSL https://repos.azul.com/azul-repo.key \
  | gpg --dearmor -o /usr/share/keyrings/azul.gpg

echo "deb [arch=arm64,amd64 signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" \
  > /etc/apt/sources.list.d/zulu.list

echo "deb [arch=all] https://repository.mapsmessaging.io/repository/maps_apt_daily/ development main" \
  > /etc/apt/sources.list.d/mapsmessaging-daily.list

curl -fsSL https://repository.mapsmessaging.io/repository/public_key/daily/apt_daily_key.gpg \
  | gpg --dearmor -o /etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg

apt-get update
apt-get install -y maps
systemctl enable maps.service
EOF

cp -a files/etc/systemd/system/maps.service.d/override.conf \
  "${ROOTFS_DIR}/etc/systemd/system/maps.service.d/override.conf"

cp -a files/opt/maps/conf/. \
  "${ROOTFS_DIR}/opt/maps/conf/"

chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/maps.service.d/override.conf"

if [ -f "${ROOTFS_DIR}/etc/maps/maps.env" ]; then
  chmod 0644 "${ROOTFS_DIR}/etc/maps/maps.env"
fi

if [ -f "${ROOTFS_DIR}/etc/systemd/system/maps.service" ]; then
  chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/maps.service"
fi

chmod 0755 "${ROOTFS_DIR}/opt/maps_data"
chmod 0755 "${ROOTFS_DIR}/var/log/maps"

echo "MAPS package and HALPI2 configuration installed"