#!/usr/bin/env bash
set -euo pipefail

DMG_URL="${PARAVIEW_DMG_URL:-https://www.paraview.org/files/v5.13/ParaView-5.13.3-MPI-OSX11.0-Python3.10-arm64.dmg}"
DMG_PATH="${PARAVIEW_DMG_PATH:-/tmp/ParaView-5.13.3-MPI-OSX11.0-Python3.10-arm64.dmg}"
MOUNT_POINT="/Volumes/ParaView-5.13.3"
APP_NAME="ParaView-5.13.3.app"
APP_SOURCE="${MOUNT_POINT}/${APP_NAME}"
APP_DEST="${PARAVIEW_APP_DEST:-$HOME/Applications/${APP_NAME}}"

download_dmg() {
  local -a curl_args
  curl_args=(-L --fail -o "$DMG_PATH" "$DMG_URL")
  if [[ -f "$DMG_PATH" ]]; then
    echo "Resuming ParaView download at: $DMG_PATH"
    curl_args=(-L -C - --fail -o "$DMG_PATH" "$DMG_URL")
  else
    echo "Downloading ParaView from: $DMG_URL"
  fi
  curl "${curl_args[@]}"
}

mount_dmg() {
  hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse
}

mkdir -p "$(dirname "$APP_DEST")"

cleanup() {
  if mount | grep -q "on ${MOUNT_POINT} "; then
    hdiutil detach "$MOUNT_POINT" >/dev/null
  fi
}
trap cleanup EXIT

if [[ -d "$APP_DEST" ]]; then
  echo "ParaView is already installed at: $APP_DEST" >&2
  exit 0
fi

if [[ ! -f "$DMG_PATH" ]]; then
  download_dmg
fi

echo "Mounting DMG: $DMG_PATH"
if ! mount_dmg; then
  download_dmg
  mount_dmg
fi

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Expected app bundle not found: $APP_SOURCE" >&2
  exit 1
fi

echo "Installing app to: $APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"

echo "ParaView installed at: $APP_DEST"
