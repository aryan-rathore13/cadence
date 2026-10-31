#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d dist/Cadence.app ]]; then bash scripts/build.sh; fi
destination="${CADENCE_INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$destination"
if pgrep -x Cadence >/dev/null; then
  echo "Quit Cadence before replacing the installed application." >&2
  exit 1
fi
ditto dist/Cadence.app "$destination/Cadence.app"
codesign --verify --strict "$destination/Cadence.app"
open "$destination/Cadence.app"
echo "Installed $destination/Cadence.app"
