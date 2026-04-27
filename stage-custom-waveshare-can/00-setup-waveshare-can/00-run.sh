#!/bin/bash -e

# Append the Waveshare 2-Channel Isolated CAN HAT overlay to config.txt.
# Only CH0 is enabled. CH0 lands on SPI0 CE0 (GPIO 8) with IRQ on GPIO 25 —
# both unused by HALPI2. CH1 cannot coexist: SPI0's two CS lines are already
# taken by CH0 (CS0) and the HALPI2 onboard MCP251xFD (CS1, remapped to GPIO 6).
cat files/config.txt.part >>"${ROOTFS_DIR}/boot/firmware/config.txt"

# Pin interface names to SPI paths so the Waveshare CH0 always becomes can1
# regardless of probe order. The HALPI2 onboard MCP251xFD lives on spi0.1;
# the Waveshare MCP2515 sits on spi0.0.
install -D -m 644 files/81-can-names.rules \
    "${ROOTFS_DIR}/etc/udev/rules.d/81-can-names.rules"
