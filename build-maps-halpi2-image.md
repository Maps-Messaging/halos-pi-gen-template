# Building the HALPI2 Waveshare CAN MAPS Image

This document describes how to build the HALPI2 marine image variant that includes:

- HALPI2 onboard CAN as `can0`
- Waveshare 2-Channel Isolated CAN HAT CH0 as `can1`
- Signal K using `can0`
- MAPS using `can1`
- MAPS runtime data under `/opt/maps_data`

CH1 on the Waveshare CAN HAT is intentionally not enabled because its default chip-select pin conflicts with the HALPI2 SPI0 CS remap.

## Repository layout

The HaLOS template repository and the HaLOS pi-gen repository must be checked out as siblings.

Expected layout:

```text
halos-build/
  halos-pi-gen-template/
  halos-pi-gen/