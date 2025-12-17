
# meta-qcom-docker-setup

A repeatable, interactive Docker-based workflow to build **Yocto/OpenEmbedded images** for **Qualcomm (meta-qcom)** platforms using **kas** + **BitBake**.


# 1) Build the image
docker build --no-cache -t meta-qcom-builder .

# 2) Prepare host workspace (on large disk)
mkdir -p /local/mnt/workspace/meta-qcom-workspace/.kas
sudo chown -R $(id -u):$(id -g) /local/mnt/workspace/meta-qcom-workspace
df -h /local/mnt/workspace/meta-qcom-workspace  # ensure >= 80–100 GB free

# 3) Run the container with UI
docker run -it --rm \
  -v /local/mnt/workspace/meta-qcom-workspace:/workspace \
  -u $(id -u):$(id  -u $(id -u):$(id -g) \

## Contents
- `Dockerfile` — Builds the container with dependencies, seeds `meta-qcom`, sets `HOME=/workspace` and `KAS_WORK_DIR=/workspace/.kas`, installs `kas`, and wires the entrypoint.
- `build-meta-qcom-ui.sh` — Interactive UI to select project, kas YAML, topology (ASoC/AudioReach), and run **FULL** (kas+BitBake) or **REBUILD** (BitBake). It validates layers/distro/machine and warns if disk space is low.

## Prerequisites
- Docker Engine on Ubuntu 22.04 or later.
- Disk space: ≥ 90 GiB free recommended for Yocto builds.

## 1) Host Workspace Setup
```bash
mkdir -p /local/mnt/workspace/meta-qcom-workspace
sudo chown -R $(id -u):$(id -g) /local/mnt/workspace/meta-qcom-workspace
# Optional: pre-create kas dir (bind mount hides image content)
mkdir -p /local/mnt/workspace/meta-qcom-workspace/.kas
# Verify free space:
df -h /local/mnt/workspace/meta-qcom-workspace
```

## 2) Build the Image
```bash
cd /path/to/repo
docker build --no-cache -t meta-qcom-builder .
```
Sanity-check the entrypoint:
```bash
docker inspect -f '{{json .Config.Entrypoint}}' meta-qcom-builder
# Expected: ["/usr/local/bin/build-meta-qcom-ui.sh"]
```

## 3) Run the Container (Interactive UI)
```bash
docker run -it --rm \
  -v /local/mnt/workspace/meta-qcom-workspace:/workspace \
  -u $(id -u):$(id -g) \
  meta-qcom-builder
```
Optional (richer dialog colors):
```bash
docker run -it --rm \
  -v /local/mnt/workspace/meta-qcom-workspace:/workspace \
  -u $(id -u):$(id -g) \
  --env TERM=xterm-256color \
  meta-qcom-builder
```

### UI Flow
1. **Project**: Select existing `/workspace/<project>` or create new.
2. **Target (kas YAML)**: Choose from `../meta-qcom/ci/*.yml`.
3. **Topology**: `ASOC` (Base) or `AR` (AudioReach).
4. **Build Type**: `FULL` (kas + BitBake) or `REBUILD` (BitBake).

### Targets
- ASoC: `bitbake qcom-multimedia-image`
- AudioReach: `bitbake qcom-multimedia-proprietary-image`

Artifacts live under:
```
/workspace/<project>/build/
```

## Troubleshooting
**Container exits immediately**: Ensure `ENTRYPOINT ["/usr/local/bin/build-meta-qcom-ui.sh"]` in Dockerfile, rebuild with `--no-cache`.

**Permissions**: Mounted volume must be writable by mapped UID/GID:
```bash
sudo chown -R $(id -u):$(id -g) /local/mnt/workspace/meta-qcom-workspace
```

**/workspace/.kas missing**: Create on host:
```bash
mkdir -p /local/mnt/workspace/meta-qcom-workspace/.kas
```

**OE-Core banner / target not provided**: Select a QCOM kas YAML that includes `qcom`/`qcom-distro` layers and sets `DISTRO` (`qcom` or `qcom-distro`) and `MACHINE`.

**No space left**: Ensure ≥ 90 GiB free. Clean `build/tmp` for full rebuild:
```bash
rm -rf /local/mnt/workspace/meta-qcom-workspace/<project>/build/tmp
```

## Optional: docker-compose.yml
```yaml
version: "3.8"
services:
  meta-qcom-builder:
    image: meta-qcom-builder:latest
    build:
      context: .
    user: "${UID}:${GID}"
    environment:
      HOME: /workspace
      KAS_WORK_DIR: /workspace/.kas
      TERM: xterm-256color
    volumes:
      - /local/mnt/workspace/meta-qcom-workspace:/workspace
    stdin_open: true
    tty: true
```
Run:
```bash
UID=$(id -u) GID=$(id -g) docker compose up
```

## .gitignore suggestions
```gitignore
**/build/
**/.kas/
**/*.log
**/*.lock
downloads/
sstate-cache/
.DS_Store
*.swp
*.swo
*.tmp
```

## Contributing
- Branch naming: `feature/<short-desc>`
- Use Signed-off-by in commits.
- Open PR with summary and test steps.

## License
Add your preferred license (MIT/Apache-2.0/BSD-3-Clause).
