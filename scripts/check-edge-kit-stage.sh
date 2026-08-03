#!/usr/bin/env bash
# Structural check for the edge-kit stage: valid bash, the inertness guarantees
# present, no secrets. Runs in CI before the (long) image build.
set -euo pipefail
S=stage-custom-waveshare-can-maps/01-install-edge-kit/00-run.sh
bash -n "$S"
grep -q 'maps-edge-firstboot.service' "$S" || { echo "firstboot unit not enabled"; exit 1; }
grep -q 'CONSUL_VERSION=1.19.2' "$S" || { echo "consul pin drifted from 1.19.2"; exit 1; }
! grep -E 'tskey-|BEGIN (EC |RSA )?PRIVATE KEY' "$S" || { echo "secret material in stage"; exit 1; }
# the enable list must contain ONLY the firstboot unit (inertness)
[ "$(grep -c 'systemctl enable ' "$S")" = "1" ] || { echo "extra enabled units break inertness"; exit 1; }
# package postinst scripts auto-enable+start their daemons (dnsmasq,
# tailscaled) -- the count check above can't see that, so every
# daemon-installing package added to this stage must have a matching
# explicit disable, or a freshly-imaged node with no drop bundle would
# come up phoning home / resolving DNS on its own.
grep -q 'systemctl disable dnsmasq' "$S" || { echo "dnsmasq not disabled -- breaks inertness"; exit 1; }
grep -q 'systemctl disable --now tailscaled' "$S" || { echo "tailscaled not disabled -- breaks inertness"; exit 1; }
echo "edge-kit stage check OK"
