#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/home/tom/.local/bin:/home/tom/.local/go/bin:$PATH"

cd "$ROOT_DIR"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script only supports Linux."
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd make
require_cmd wails
require_cmd node
require_cmd npm
require_cmd sudo

echo "Deploying Aerion from branch: $(git branch --show-current)"

if [[ -f .env.local ]]; then
  if rg -q '^GOOGLE_CLIENT_ID=your-client-id\.apps\.googleusercontent\.com$' .env.local; then
    echo "Warning: .env.local still contains the placeholder GOOGLE_CLIENT_ID."
  fi
fi

echo "Building production binary..."
make build

echo "Installing local build to /usr/local..."
sudo make install-linux-built

if command -v flatpak >/dev/null 2>&1 && flatpak info io.github.hkdb.Aerion >/dev/null 2>&1; then
  echo "Removing user Flatpak install so the desktop launcher uses the local build..."
  flatpak uninstall --user -y io.github.hkdb.Aerion
fi

echo
echo "Local deployment complete."
echo "Installed binary: /usr/local/bin/aerion"
echo "If Aerion was running, restart it before testing the new build."
