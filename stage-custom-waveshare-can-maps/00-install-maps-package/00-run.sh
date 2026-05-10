#!/bin/bash -e

echo "Installing MAPS package and HALPI2 configuration"

install -d "${ROOTFS_DIR}/etc/apt/sources.list.d"
install -d "${ROOTFS_DIR}/etc/apt/trusted.gpg.d"
install -d "${ROOTFS_DIR}/usr/share/keyrings"
install -d "${ROOTFS_DIR}/etc/systemd/system/maps.service.d"
install -d "${ROOTFS_DIR}/opt/maps/conf"
install -d "${ROOTFS_DIR}/opt/maps_data"
install -d "${ROOTFS_DIR}/var/log/maps"
install -d "${ROOTFS_DIR}/etc/udev/rules.d"

install -m 0644 files/81-can-names.rules "${ROOTFS_DIR}/etc/udev/rules.d/81-can-names.rules"


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

CONFIG_FILE="${ROOTFS_DIR}/boot/firmware/config.txt"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: ${CONFIG_FILE} not found"
  exit 1
fi

sed -i \
  -e '/^# Waveshare 2-Channel Isolated CAN HAT — CH0 only\.$/,/^# land without moving to SPI1 with a custom overlay\.$/d' \
  -e '/^dtoverlay=spi0-2cs,cs1_pin=6$/d' \
  -e '/^dtoverlay=mcp251xfd,spi0-1,interrupt=26,oscillator=40000000$/d' \
  -e '/^dtoverlay=spi0-2cs$/d' \
  -e '/^dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=25$/d' \
  -e '/^dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=24$/d' \
  "${CONFIG_FILE}"

cat >> "${CONFIG_FILE}" <<'EOF'

# MAPS HALOS CAN profile
# Uses Waveshare 2-Channel Isolated CAN HAT only.
# Onboard HALPI2 CAN is intentionally disabled.

[all]

# Enable SPI for the Waveshare CAN HAT.
dtparam=spi=on

# SPI0 with two standard chip-selects:
# CH0 -> SPI0 CS0 / GPIO 8
# CH1 -> SPI0 CS1 / GPIO 7
dtoverlay=spi0-2cs

# Waveshare 2-Channel Isolated CAN HAT
dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=25
dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=24
EOF

echo "MAPS package and HALPI2 configuration installed"