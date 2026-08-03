#!/bin/bash -e
# Bake the MAPS edge kit — INERT. Installs Consul 1.19.2, tailscale, dnsmasq,
# gettext-base, and the edge-kit from maps-edge-platform at EDGE_KIT_REF. The
# only enabled unit is maps-edge-firstboot.service, which is condition-gated on
# /boot/firmware/maps-edge.env: no drop bundle => the image behaves exactly as
# the previous daily. dnsmasq and tailscaled are both explicitly disabled after
# install (their package postinst scripts auto-enable+start them otherwise).
# Activation docs: maps-edge-platform docs/edge-node-onboarding.md.

EDGE_KIT_REF="${EDGE_KIT_REF:-main}"
EDGE_KIT_REPO="Maps-Messaging/maps-edge-platform"
CONSUL_VERSION=1.19.2

echo "Installing MAPS edge kit (ref ${EDGE_KIT_REF})"

# Fetch the platform repo tarball (private -> needs EDGE_KIT_TOKEN in CI).
rm -rf /tmp/edge-kit-src && mkdir -p /tmp/edge-kit-src
curl -fsSL ${EDGE_KIT_TOKEN:+-H "Authorization: Bearer ${EDGE_KIT_TOKEN}"} \
  "https://api.github.com/repos/${EDGE_KIT_REPO}/tarball/${EDGE_KIT_REF}" \
  | tar -xz -C /tmp/edge-kit-src --strip-components=1

install -d "${ROOTFS_DIR}/usr/local/lib/maps-edge/units" \
           "${ROOTFS_DIR}/usr/local/lib/maps-edge/templates" \
           "${ROOTFS_DIR}/etc/systemd/system"
cp -a /tmp/edge-kit-src/edge-kit/templates/. "${ROOTFS_DIR}/usr/local/lib/maps-edge/templates/"
install -m 0755 /tmp/edge-kit-src/edge-kit/maps-edge-activate \
  "${ROOTFS_DIR}/usr/local/lib/maps-edge/maps-edge-activate"
install -m 0755 /tmp/edge-kit-src/ansible/roles/consul_wan_join/files/maps-consul-wan-join \
  "${ROOTFS_DIR}/usr/local/lib/maps-edge/maps-consul-wan-join"
install -m 0644 /tmp/edge-kit-src/edge-kit/units/*.service \
                /tmp/edge-kit-src/edge-kit/units/*.timer \
  "${ROOTFS_DIR}/etc/systemd/system/"
ln -sf /usr/local/lib/maps-edge/maps-edge-activate "${ROOTFS_DIR}/usr/local/bin/maps-edge-activate"

on_chroot << EOF
set -e
apt-get update
apt-get install -y curl unzip gettext-base dnsmasq jq
# dnsmasq stays disabled until activation wires the consul resolver
systemctl disable dnsmasq || true
# tailscale (official repo, bookworm)
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian bookworm main" \
  > /etc/apt/sources.list.d/tailscale.list
apt-get update && apt-get install -y tailscale
# tailscaled's postinst enables (and starts) it, same as dnsmasq -- disable
# it so an image with no drop bundle does not try to reach the tailnet.
# maps-edge-activate brings it back up before calling `tailscale up`
# during activation.
systemctl disable --now tailscaled || true
# consul ${CONSUL_VERSION} (arm64)
curl -fsSL "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_arm64.zip" -o /tmp/consul.zip
unzip -o /tmp/consul.zip -d /usr/local/bin && chmod 0755 /usr/local/bin/consul && rm /tmp/consul.zip
# only the condition-gated firstboot unit is enabled
systemctl enable maps-edge-firstboot.service
EOF

echo "Edge kit baked (inert): consul $("${ROOTFS_DIR}/usr/local/bin/consul" version 2>/dev/null | head -1 || echo ${CONSUL_VERSION})"
