#!/bin/bash
set -euo pipefail

CONFIG_FILE="/workspace/.build-config"

msg() {
  echo "======================================"
  echo "$1"
  echo "======================================"
}

run_with_logs() {
  local cmd="$1"
  local msgtxt="$2"
  msg "$msgtxt"
  local start_time; start_time=$(date +%s)
  bash -lc "$cmd"
  local end_time; end_time=$(date +%s)
  local elapsed=$((end_time - start_time))
  echo "✅ Completed in $((elapsed / 60)) min $((elapsed % 60)) sec"
  echo "LAST_BUILD_TIME=$elapsed" >> "$CONFIG_FILE" || true
}

# Ensure HOME and KAS work dir exist for kas
init_env_basics() {
  export HOME="${HOME:-/workspace}"
  export KAS_WORK_DIR="${KAS_WORK_DIR:-/workspace/.kas}"
  mkdir -p "$KAS_WORK_DIR"
}

# --- Seed meta-qcom into /workspace ---
seed_meta_qcom() {
  if [ ! -w "/workspace" ]; then
    whiptail --msgbox "Workspace (/workspace) is not writable.\nFix host directory permissions or run with -u $(id -u):$(id -g)." 12 78
    exit 1
  fi

  if [ ! -d "/workspace/meta-qcom/.git" ]; then
    echo "Seeding /workspace/meta-qcom from /opt/src/meta-qcom ..."
    mkdir -p /workspace/meta-qcom || true
    if ! rsync -a --delete /opt/src/meta-qcom/ /workspace/meta-qcom/ 2>/dev/null; then
      echo "Rsync failed, falling back to git clone..."
      rm -rf /workspace/meta-qcom
      git clone https://github.com/qualcomm-linux/meta-qcom.git -b master /workspace/meta-qcom
    fi
  fi
}

select_project_name() {
  mapfile -t existing_projects < <(find /workspace -maxdepth 1 -mindepth 1 -type d \
    ! -name meta-qcom \
    -printf '%f\n' | sort)

  local MENU_ITEMS=() i
  for ((i=0; i<${#existing_projects[@]}; i++)); do
    MENU_ITEMS+=("$((i+1))" "${existing_projects[$i]}")
  done
  MENU_ITEMS+=("NEW" "Create a new project")

  local choice
  choice=$(whiptail --title "Select Project" --menu "Choose an existing project or create new:" 20 78 12 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)

  if [ "$choice" == "NEW" ] || [ -z "$choice" ]; then
    PROJECT_NAME=$(whiptail --inputbox "Enter new project directory name:" 10 60 3>&1 1>&2 2>&3)
    [ -z "$PROJECT_NAME" ] && { echo "No project name provided"; exit 1; }
    mkdir -p "/workspace/$PROJECT_NAME"
  else
    PROJECT_NAME="${existing_projects[$((choice-1))]}"
  fi
  cd "/workspace/$PROJECT_NAME"
}

select_target() {
  if [ ! -d "../meta-qcom/ci" ]; then
    whiptail --msgbox "Directory ../meta-qcom/ci not found. Ensure seeding/cloning succeeded." 10 60
    exit 1
  fi
  mapfile -t TARGETS < <(ls -1 ../meta-qcom/ci/*.yml 2>/dev/null)
  if [ ${#TARGETS[@]} -eq 0 ]; then
    whiptail --msgbox "No kas YAML files found under ../meta-qcom/ci/" 10 60
    exit 1
  fi
  local MENU_ITEMS=() i
  for ((i=0; i<${#TARGETS[@]}; i++)); do
    MENU_ITEMS+=("$((i+1))" "${TARGETS[$i]}")
  done
  local choice
  choice=$(whiptail --title "Select Target" --menu "Choose a kas target YAML:" 20 78 12 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
  [ -z "$choice" ] && { echo "No target selected"; exit 1; }
  TARGET="$(realpath "${TARGETS[$((choice-1))]}")"
}

select_topology() {
  local topo
  topo=$(whiptail --title "Select Topology" --radiolist "Choose topology:" 15 60 2 \
    "ASOC" "Base (ASoC)" ON \
    "AR"   "Overlay (AudioReach)" OFF 3>&1 1>&2 2>&3)
  TOPOLOGY=${topo:-ASOC}
}

check_disk_space() {
  local free_mb; free_mb=$(df -Pm . | awk 'NR==2{print $4}')
  local need_mb=81920
  if [ "$free_mb" -lt "$need_mb" ]; then
    whiptail --msgbox "Insufficient free space in $(pwd).\nFree: $((free_mb/1024)) GiB, Required: $((need_mb/1024)) GiB (>=80 GiB).\nBuild may fail. Consider mounting a larger volume." 12 78
  fi
}

has_oe_init() {
  local workdir="${KAS_WORK_DIR:-/workspace/.kas}"
  [ -n "$(find "$workdir" -type f -name oe-init-build-env 2>/dev/null | head -n1)" ]
}

resolve_and_source_kas_env() {
  local workdir="${KAS_WORK_DIR:-/workspace/.kas}"
  local OE_INIT
  OE_INIT=$(find "$workdir" -type f -name oe-init-build-env -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  if [ -z "$OE_INIT" ]; then
    whiptail --msgbox "Kas environment not initialized under $workdir.\nRunning 'kas build' automatically to create it..." 12 78
    pushd /workspace >/dev/null
    run_with_logs "env KAS_WORK_DIR=\"$KAS_WORK_DIR\" kas build \"$TARGET\"" "Running kas build..."
    popd >/dev/null
    OE_INIT=$(find "$workdir" -type f -name oe-init-build-env -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
    if [ -z "$OE_INIT" ]; then
      whiptail --msgbox "Still cannot locate oe-init-build-env under $workdir after kas build.\nPlease verify the selected YAML in ../meta-qcom/ci/." 12 78
      exit 1
    fi
  fi
  # shellcheck disable=SC1090
  source "$OE_INIT" build
}

have_qcom_layer() {
  bitbake-layers show-layers 2>/dev/null | grep -Eq '\b(meta-)?qcom\b'
}
have_qcom_distro_layer() {
  bitbake-layers show-layers 2>/dev/null | grep -Eq '\b(meta-)?qcom-distro\b'
}

check_qcom_layers_and_conf() {
  if ! have_qcom_layer; then
    whiptail --msgbox "Qualcomm layer (meta-qcom/qcom) not present in BBLAYERS.\nSelect a kas YAML that includes Qualcomm layers and sets DISTRO/MACHINE." 12 78
    exit 1
  fi
  if ! have_qcom_distro_layer; then
    whiptail --msgbox "Qualcomm distro layer (meta-qcom-distro/qcom-distro) not present in BBLAYERS.\nChoose a QCOM kas YAML that includes distro settings." 12 78
    exit 1
  fi
  local d m
  d=$(grep -E '^DISTRO *= *' conf/local.conf | sed -E 's/.*"([^"]+)".*/\1/' || true)
  m=$(grep -E '^MACHINE *= *' conf/local.conf | sed -E 's/.*"([^"]+)".*/\1/' || true)
  if [ -z "$d" ] || [ -z "$m" ]; then
    whiptail --msgbox "DISTRO or MACHINE is not set in conf/local.conf.\nPlease select a kas YAML that configures them." 12 78
    exit 1
  fi
  if ! echo "$d" | grep -qE '^qcom(|-distro)$'; then
    whiptail --msgbox "DISTRO is '$d'. Expected a Qualcomm distro (e.g., 'qcom' or 'qcom-distro').\nYou may be sourcing the wrong env or using a non-QCOM kas YAML." 12 78
    exit 1
  fi
  whiptail --msgbox "Environment OK\n\nDISTRO: $d\nMACHINE: $m\n\nProceeding to BitBake..." 12 60
}

# --- Main flow ---
init_env_basics
seed_meta_qcom

# Config selection
if [ -f "$CONFIG_FILE" ]; then
  if whiptail --title "Previous Config Found" --yesno "Reuse previous config?" 10 60; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    cd "/workspace/$PROJECT_NAME"
  else
    select_project_name
    select_target
    select_topology
    {
      echo "PROJECT_NAME=\"$PROJECT_NAME\""
      echo "TARGET=\"$TARGET\""
      echo "TOPOLOGY=\"$TOPOLOGY\""
    } > "$CONFIG_FILE"
  fi
else
  select_project_name
  select_target
  select_topology
  {
    echo "PROJECT_NAME=\"$PROJECT_NAME\""
    echo "TARGET=\"$TARGET\""
    echo "TOPOLOGY=\"$TOPOLOGY\""
  } > "$CONFIG_FILE"
fi

while true; do
  build_type=$(whiptail --title "Build Type" --radiolist "Choose build type:" 15 60 3 \
    "FULL" "Full build (kas + bitbake)" ON \
    "REBUILD" "Rebuild only (bitbake)" OFF \
    "EXIT" "Exit session" OFF 3>&1 1>&2 2>&3)
  [ "$build_type" == "EXIT" ] && break

  if grep -q "LAST_BUILD_TIME" "$CONFIG_FILE"; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    ETA=$((LAST_BUILD_TIME / 60))
    whiptail --msgbox "Estimated time for this build: ~${ETA} minutes" 10 60
  fi

  check_disk_space

  if [ "$build_type" == "FULL" ]; then
    init_env_basics
    pushd /workspace >/dev/null
    run_with_logs "env KAS_WORK_DIR=\"$KAS_WORK_DIR\" kas build \"$TARGET\"" "Running kas build..."
    popd >/dev/null
  fi

  cd "/workspace/$PROJECT_NAME"

  resolve_and_source_kas_env
  check_qcom_layers_and_conf

  if [ "$TOPOLOGY" == "ASOC" ]; then
    run_with_logs "bitbake qcom-multimedia-image" "Building ASoC image..."
  elif [ "$TOPOLOGY" == "AR" ]; then
    run_with_logs "bitbake qcom-multimedia-proprietary-image" "Building AudioReach image..."
  fi

  whiptail --msgbox "Build completed successfully!" 10 60
done
