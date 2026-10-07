#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" != "--skip-build" ]; then ./build.sh; fi
codesign --verify --deep --strict "Tailbar.app"

# Prepare the new bundle before touching the running UI. Keep the previous
# installation for rollback; neither tailscaled nor its watchdog is restarted.
install_stamp="$(date +%Y%m%d-%H%M%S)"
staged_app="/Applications/Tailbar.app.staged-$install_stamp"
backup_app="/Applications/Tailbar.app.backup-$install_stamp"
test ! -e "$staged_app"
test ! -e "$backup_app"
ditto "Tailbar.app" "$staged_app"

pkill -x Tailbar 2>/dev/null || true
if [ -e "/Applications/Tailbar.app" ]; then
  mv "/Applications/Tailbar.app" "$backup_app"
  echo "Previous UI saved to $backup_app"
fi
# Before 0.6.0 the app was installed as TailscaleMenuBar.app.
legacy_app="/Applications/TailscaleMenuBar.app"
if [ -e "$legacy_app" ]; then
  pkill -x TailscaleMenuBar 2>/dev/null || true
  mv "$legacy_app" "$legacy_app.backup-$install_stamp"
  echo "Pre-0.6 app moved to $legacy_app.backup-$install_stamp"
fi
mv "$staged_app" "/Applications/Tailbar.app"

open "/Applications/Tailbar.app"
echo "Installed to /Applications/Tailbar.app and launched."
