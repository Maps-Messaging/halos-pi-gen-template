#!/bin/bash -e

SK_DATA="${ROOTFS_DIR}/var/lib/container-apps/marine-signalk-server-container/data/data"
PLUGIN_NAME="ais-forwarder"
PLUGIN_VERSION="0.4.1"
TARBALL_URL="https://registry.npmjs.org/${PLUGIN_NAME}/-/${PLUGIN_NAME}-${PLUGIN_VERSION}.tgz"

# Download and extract to node_modules (npm tarballs have a "package/" prefix)
mkdir -p "${SK_DATA}/node_modules/${PLUGIN_NAME}"
wget -qO- "${TARBALL_URL}" | tar xz --strip-components=1 -C "${SK_DATA}/node_modules/${PLUGIN_NAME}"

# Set ownership to match Signal K container user (uid 1000)
chown -R 1000:1000 "${SK_DATA}/node_modules/${PLUGIN_NAME}"
