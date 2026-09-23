#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" != "--skip-build" ]; then ./build.sh; fi
codesign --verify --deep --strict "TailscaleMenuBar.app"

# Prepare the new bundle before touching the running UI. Keep the previous
# installation for rollback; neither tailscaled nor its watchdog is restarted.
install_stamp="$(date +%Y%m%d-%H%M%S)"
staged_app="/Applications/TailscaleMenuBar.app.staged-$install_stamp"
backup_app="/Applications/TailscaleMenuBar.app.backup-$install_stamp"
test ! -e "$staged_app"
test ! -e "$backup_app"
ditto "TailscaleMenuBar.app" "$staged_app"

pkill -x TailscaleMenuBar 2>/dev/null || true
if [ -e "/Applications/TailscaleMenuBar.app" ]; then
  mv "/Applications/TailscaleMenuBar.app" "$backup_app"
  echo "Previous UI saved to $backup_app"
fi
mv "$staged_app" "/Applications/TailscaleMenuBar.app"

open "/Applications/TailscaleMenuBar.app"
echo "Installed to /Applications/TailscaleMenuBar.app and launched."
