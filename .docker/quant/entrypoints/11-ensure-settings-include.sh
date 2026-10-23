#!/bin/bash
# Keep platform-managed settings reaching existing environments.
#
# settings.php lives on the volume and is copied there once, so edits to the
# image copy never arrive. The platform settings now live in settings.quant.php
# inside the image. On a volume whose settings.php predates this change and has
# no include for it, append the include. Customer edits are never overwritten.

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/opt/drupal}"
SETTINGS="$TARGET_DIR/web/sites/default/settings.php"
MARKER_FILE="$TARGET_DIR/.drupal-cms-initialized"

append_include() {
    local mode
    mode=$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS")
    chmod u+w "$SETTINGS"
    cat >> "$SETTINGS" <<'PHP'

// Quant platform settings (managed by the image). Added automatically.
foreach ([
  '/usr/src/drupal-cms/settings.quant.php',
  $app_root . '/settings.quant.php',
] as $quant_settings_file) {
  if (is_readable($quant_settings_file)) {
    include $quant_settings_file;
    break;
  }
}
unset($quant_settings_file);
PHP
    chmod "$mode" "$SETTINGS"
}

# First boot: 10-copy-drupal-cms.sh ships the new settings.php with the include.
if [ ! -f "$MARKER_FILE" ] || [ ! -f "$SETTINGS" ]; then
    exit 0
fi

if grep -q 'settings\.quant\.php' "$SETTINGS"; then
    echo "[settings-include] settings.php already includes settings.quant.php"
    exit 0
fi

echo "[settings-include] Adding the settings.quant.php include to settings.php"
append_include
echo "[settings-include] Done"
