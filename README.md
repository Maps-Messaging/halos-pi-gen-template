# halos-pi-gen-template

A template for building custom [HaLOS](https://halos.fi) images by layering your own [pi-gen](https://github.com/RPi-Distro/pi-gen) stages on top of the HaLOS base image. Fork this repo, adjust a config file, drop your own stage in, and let CI build a flashable `.img.xz` for you.

## What this is

HaLOS images are built with `pi-gen`, the same tool that produces Raspberry Pi OS. Customizing them cleanly means layering your changes on top of the upstream stages instead of forking. This template demonstrates the pattern with a small, working example.

The build assembles three layers, in order:

```
pi-gen (upstream Raspberry Pi OS builder)
   └── halos-pi-gen (HaLOS base + halpi2 + marine + desktop stages)
         └── this template (your custom stages)
```

Each layer adds stages on top of the previous one. Your stages run last and have full access to the rootfs that the lower layers built.

* **pi-gen** — provides `stage0`–`stage4` and the build orchestration.
* **[halos-pi-gen](https://github.com/halos-org/halos-pi-gen)** — adds HaLOS-specific stages: base packaging, HALPI2 hardware support, marine apps (Signal K, InfluxDB, Grafana), the desktop, headless variants, and so on.
* **This template** — adds whatever you want on top: extra packages, pre-configured plugins, branding, additional services.

The build is driven by a config file (e.g. `config.halos-desktop-marine-halpi2-ap-ais`), which lists the stages to run and the image identity, and one or more `stage-custom-*` directories containing the work to do.

## The example variant

The repository ships with one working example:

| Config | Stage | What it does |
|---|---|---|
| `config.halos-desktop-marine-halpi2-ap-ais` | `stage-custom-ais` | Builds a HALPI2 marine image with the [`ais-forwarder`](https://www.npmjs.com/package/ais-forwarder) Signal K plugin pre-installed. |

The `stage-custom-ais` stage downloads the plugin tarball from npm at build time and extracts it into the Signal K data directory inside the image rootfs. Nothing fancy — it is the smallest meaningful customization that demonstrates the pattern.

Use it as a working reference, then replace it with your own stage when forking.

## Quick start

### Build with CI (recommended)

After forking this repo, push to `main`. The workflow at `.github/workflows/build.yml` will build the image on a GitHub-hosted ARM64 runner and create a draft release with the `.img.xz` attached.

```
gh repo fork halos-org/halos-pi-gen-template
# edit, commit, push to your fork's main
# wait ~30-60 minutes
gh release list
```

### Build locally

You need:

* Docker (the build runs inside a Docker container that pi-gen manages)
* `git`
* A local checkout of [`halos-org/halos-pi-gen`](https://github.com/halos-org/halos-pi-gen) at `../halos-pi-gen` (a sibling directory next to this one)

```
git clone https://github.com/halos-org/halos-pi-gen ../halos-pi-gen
./run build config.halos-desktop-marine-halpi2-ap-ais
```

The first build clones a shallow copy of upstream `pi-gen` into `pi-gen/` (gitignored). The output `.img.xz` will be in `pi-gen/deploy/`.

To clean up between builds:

```
./run clean
```

Note that ARM64 emulation under qemu on x86 hosts works but is slow. For practical local development use an ARM64 host (e.g. an Apple Silicon Mac, a Raspberry Pi, or an ARM64 Linux server).

## Customizing

The full lifecycle of forking and adapting this template:

1. **Fork the repo** on GitHub (or use it as a template via "Use this template").

2. **Decide on a name for your variant.** This is the suffix you will use throughout. Pick something short and descriptive: `mybrand`, `weather`, `ham`. The example uses `ais`.

3. **Copy the config file.** From `config.halos-desktop-marine-halpi2-ap-ais` to `config.<your-variant>`. Edit:
   * `IMG_NAME` and `PI_GEN_RELEASE` — your image's display name.
   * `PI_GEN_REPO` — point at your fork's URL.
   * `CONTAINER_NAME` — must be unique if you build multiple variants on the same host.
   * `STAGE_LIST` — replace `stage-custom-ais` with the name of your new stage directory. Keep the rest in order.
   * Anything else (hostname, WiFi country, default password, …) you want to change. See inline comments in the config file for what each variable does.

4. **Copy the stage directory.** From `stage-custom-ais/` to `stage-custom-<your-variant>/`. The structure is:
   ```
   stage-custom-<your-variant>/
     prerun.sh                # boilerplate, usually no edits needed
     NN-<step-name>/
       00-run.sh              # script that runs inside the build container
   ```
   See "How pi-gen stages work" below for the conventions.

5. **Replace the stage's contents** with whatever your image needs. The `00-run.sh` script runs inside the chroot of the rootfs being built, with `${ROOTFS_DIR}` pointing at the rootfs. You have full access — install packages, drop in config files, pre-seed databases, whatever.

6. **Update the CI matrix.** In `.github/workflows/build.yml`, replace the matrix entry's `name` and `config` with your new variant. Or add a second entry alongside the existing one to build both.

7. **Push and watch the build run.** Each push to `main` triggers a build and creates a draft release.

When you have the basics working, that draft release becomes a public release: edit it in the GitHub UI and click "Publish".

## How pi-gen stages work

Each stage is a directory with a numeric or named prefix. Stages run in the order listed in `STAGE_LIST`. Within a stage, scripts run in lexicographic order.

```
stage-custom-ais/
  prerun.sh                            # runs once at the start of the stage
  00-install-sk-plugins/
    00-run.sh                          # runs inside the chroot
    00-run-chroot.sh                   # (alt) runs inside the chroot via systemd-nspawn
    files/                             # (optional) files copied into the rootfs
    00-packages                        # (optional) one package name per line, apt-get installed
```

Key conventions:

* `${ROOTFS_DIR}` — path to the rootfs being built, on the host. Write into it to modify the image.
* `prerun.sh` — sets up the stage. The standard boilerplate calls `copy_previous` if `${ROOTFS_DIR}` does not yet exist, which forks the previous stage's rootfs as a starting point.
* `SKIP` marker file in a stage directory — skips the stage entirely.
* `SKIP_IMAGES` marker — runs the stage but does not produce an intermediate image.

For the full reference, see the [upstream pi-gen README](https://github.com/RPi-Distro/pi-gen#readme).

## Configuration reference

Every variable is documented inline in the config file. A quick map:

| Variable | Purpose |
|---|---|
| `IMG_NAME`, `PI_GEN_RELEASE` | Image display name and release string. |
| `PI_GEN_REPO` | URL embedded in image metadata. |
| `IMG_FILENAME`, `ARCHIVE_FILENAME` | Final output filenames. |
| `CONTAINER_NAME` | Docker container name for the build. |
| `STAGE_LIST` | Ordered list of stages to run. |
| `DEPLOY_COMPRESSION`, `COMPRESSION_LEVEL` | Final image compression. |
| `FIRST_USER_NAME`, `FIRST_USER_PASS` | First-boot login. **Change `FIRST_USER_PASS` for production.** |
| `DISABLE_FIRST_BOOT_USER_RENAME` | Whether the first-run flow may rename the user. |
| `TARGET_HOSTNAME` | First-boot hostname. |
| `WPA_COUNTRY` | WiFi regulatory domain (ISO two-letter code). |
| `ENABLE_SSH` | Whether SSH is enabled out of the box. |

Add any pi-gen variable you need; this list is just the ones the template sets.

## Troubleshooting

**"halos-pi-gen not found at ../halos-pi-gen"** — clone it as a sibling: `git clone https://github.com/halos-org/halos-pi-gen ../halos-pi-gen`.

**Out of disk space during local build** — pi-gen needs ~20 GB free. The CI workflow includes an aggressive disk-cleanup step you can adapt for local use, but the simplest fix is to build on a host with more free space.

**Build hangs or fails partway** — `./run clean` removes the `pi-gen/` working directory and any leftover `pigen_work*` containers. Re-run the build from a clean state.

**dpkg conffile prompts during build** — already worked around by the `run` script, which patches pi-gen's apt invocation to use `--force-confold`.

**"docker: Cannot connect to the Docker daemon"** — start Docker Desktop or `sudo systemctl start docker`.

**ARM64 build is extremely slow on x86_64** — qemu user-mode emulation is correct but slow. Use an ARM64 host or rely on the GitHub Actions workflow's `ubuntu-24.04-arm` runners.

## Links

* HaLOS docs — <https://docs.halos.fi>
* HaLOS website — <https://halos.fi>
* `halos-org/halos-pi-gen` (the HaLOS base layer) — <https://github.com/halos-org/halos-pi-gen>
* Upstream pi-gen — <https://github.com/RPi-Distro/pi-gen>
* `ais-forwarder` Signal K plugin (used in the example) — <https://www.npmjs.com/package/ais-forwarder>
* Signal K — <https://signalk.org>

## License

MIT. See [`LICENSE`](LICENSE).
