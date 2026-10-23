#!/bin/bash
# Reproducible check for 11-ensure-settings-include.sh. No Docker or Drupal needed.
# Usage: bash tests/settings-include-check.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/.docker/quant/entrypoints/11-ensure-settings-include.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir -p "$T/web/sites/default"
S="$T/web/sites/default/settings.php"

# 1. Legacy settings.php with a customer edit and no include.
printf '<?php\n$settings["customer_edit"] = TRUE;\n$settings["trusted_host_patterns"] = ["^custom\\.example\\.com$"];\n' > "$S"
chmod 444 "$S"

# 2. No marker: first boot, nothing changes.
TARGET_DIR="$T" bash "$SCRIPT" >/dev/null
grep -q 'settings.quant.php' "$S" && fail "touched settings.php before init"

# 3. Marker present: include appended, customer edit kept, mode kept.
touch "$T/.drupal-cms-initialized"
TARGET_DIR="$T" bash "$SCRIPT" >/dev/null
grep -q 'customer_edit' "$S" || fail "customer edit lost"
grep -q 'settings.quant.php' "$S" || fail "include missing"
[ "$(stat -f %Lp "$S" 2>/dev/null || stat -c %a "$S")" = 444 ] || fail "mode changed"
php -l "$S" >/dev/null || fail "settings.php invalid"

# 4. Idempotent.
BEFORE="$(cksum < "$S")"
TARGET_DIR="$T" bash "$SCRIPT" >/dev/null
[ "$BEFORE" = "$(cksum < "$S")" ] || fail "second run changed the file"

# 5. The shipped thin settings.php loads the platform file and keeps customer hosts.
OUT="$(php -r '
  namespace Symfony\Component\HttpFoundation { class Request {
    const HEADER_X_FORWARDED_FOR = 1; const HEADER_X_FORWARDED_HOST = 2;
    const HEADER_X_FORWARDED_PORT = 4; const HEADER_X_FORWARDED_PROTO = 8; } }
  namespace Drupal\Core\Installer { class InstallerKernel { static function installationAttempted() { return FALSE; } } }
  namespace {
    $app_root = "'"$ROOT"'/src"; $site_path = "sites/default";
    $settings = ["trusted_host_patterns" => ["^custom\\.example\\.com\$"]];
    putenv("QUANT_ENV_TYPE=local");
    include $app_root . "/settings.php";
    echo isset($settings["config_sync_directory"]) ? "platform-loaded " : "platform-MISSING ";
    echo in_array("^custom\\.example\\.com\$", $settings["trusted_host_patterns"]) ? "custom-kept " : "custom-LOST ";
    echo in_array("localhost", $settings["trusted_host_patterns"]) ? "platform-hosts" : "platform-hosts-MISSING";
  }
')"
echo "$OUT"
[ "$OUT" = "platform-loaded custom-kept platform-hosts" ] || fail "thin settings.php: $OUT"
echo OK
