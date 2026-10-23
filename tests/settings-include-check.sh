#!/bin/bash
# Reproducible check for 11-ensure-settings-include.sh. No Docker or Drupal needed.
# Usage: bash tests/settings-include-check.sh (needs the full git history)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/.docker/quant/entrypoints/11-ensure-settings-include.sh"
T="$(mktemp -d)"; trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

mkdir -p "$T/web/sites/default"
S="$T/web/sites/default/settings.php"

LEGACY_COMMIT=38b2477f54a7e272f244ab299838d65ae1e11c51   # a shipped template version
mode_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"; }

# Image stand-in: the new thin settings.php and the platform file.
IMG="$T/img"; mkdir -p "$IMG"
cp "$ROOT/src/settings.php" "$ROOT/src/settings.quant.php" "$IMG/"

# Fresh volume dir with a given settings.php. Args: dir, content file.
new_volume() {
    mkdir -p "$1/web/sites/default"
    cp "$2" "$1/web/sites/default/settings.php"
    chmod 444 "$1/web/sites/default/settings.php"
    touch "$1/.drupal-cms-initialized"
}
run() { TARGET_DIR="$1" SOURCE_DIR="$IMG" bash "$SCRIPT" 2>&1; }

git -C "$ROOT" show "$LEGACY_COMMIT:src/settings.php" > "$T/legacy.php"
sed 's/REMOTE_ADDR/HTTP_X_FAKE/' "$T/legacy.php" > "$T/edited.php"
cmp -s "$T/legacy.php" "$T/edited.php" && fail "fixture edit did not change the file"

# (a) Unmodified legacy file is replaced by the thin settings.php.
V="$T/a"; new_volume "$V" "$T/legacy.php"; S="$V/web/sites/default/settings.php"
run "$V" >/dev/null
cmp -s "$S" "$IMG/settings.php" || fail "(a) legacy file not replaced"
[ "$(mode_of "$S")" = 444 ] || fail "(a) mode changed"
[ -e "$S.quant-new" ] && fail "(a) unexpected quant-new"

# (b) Customer-edited legacy file is left byte-identical; settings.php.quant-new is written.
V="$T/b"; new_volume "$V" "$T/edited.php"; S="$V/web/sites/default/settings.php"
OUT="$(run "$V")"
cmp -s "$S" "$T/edited.php" || fail "(b) customer-edited file was modified"
cmp -s "$S.quant-new" "$IMG/settings.php" || fail "(b) quant-new missing or wrong"
echo "$OUT" | grep -qi 'warning' || fail "(b) no warning logged"

# (c) A comment that mentions settings.quant.php does not count as included.
V="$T/c"; new_volume "$V" "$T/edited.php"; S="$V/web/sites/default/settings.php"
chmod u+w "$S"
printf '\n// TODO include settings.quant.php later\n/* include "settings.quant.php"; */\n' >> "$S"
cp "$S" "$T/c-before.php"
run "$V" >/dev/null
cmp -s "$S" "$T/c-before.php" || fail "(c) file was modified"
[ -f "$S.quant-new" ] || fail "(c) comment counted as an include"

# (d) New volume (thin settings.php already includes the platform file): untouched.
V="$T/d"; new_volume "$V" "$IMG/settings.php"; S="$V/web/sites/default/settings.php"
run "$V" >/dev/null
cmp -s "$S" "$IMG/settings.php" || fail "(d) new volume changed"
[ -e "$S.quant-new" ] && fail "(d) unexpected quant-new"
# Not initialised yet: nothing happens.
V="$T/e"; new_volume "$V" "$T/edited.php"; rm "$V/.drupal-cms-initialized"
run "$V" >/dev/null
cmp -s "$V/web/sites/default/settings.php" "$T/edited.php" || fail "touched before init"
# Idempotent on the replaced legacy volume.
run "$T/a" >/dev/null
cmp -s "$T/a/web/sites/default/settings.php" "$IMG/settings.php" || fail "second run changed (a)"

# (f) Unwritable sites/default (non-root): the script must exit 0 and leave settings.php alone.
if [ "$(id -u)" != 0 ]; then
    for kind in edited legacy; do
        V="$T/f-$kind"; new_volume "$V" "$T/$kind.php"; S="$V/web/sites/default/settings.php"
        chmod 555 "$V/web/sites/default"
        RC=0; OUT="$(run "$V")" || RC=$?
        [ "$RC" = 0 ] || fail "(f/$kind) exited $RC on an unwritable directory"
        cmp -s "$S" "$T/$kind.php" || fail "(f/$kind) settings.php changed on a failed write"
        ls "$V/web/sites/default" | grep -q 'tmp' && fail "(f/$kind) temp file left behind"
        echo "$OUT" | grep -qi 'warning' || fail "(f/$kind) no warning logged"
        chmod 755 "$V/web/sites/default"
    done
fi

# (g) Without php, the new settings.php is not reported as unmigrated.
V="$T/g"; new_volume "$V" "$IMG/settings.php"; S="$V/web/sites/default/settings.php"
NOPHP="$T/nophp-bin"; mkdir -p "$NOPHP"
for t in bash cp chmod mv rm cmp grep cut stat sha256sum shasum cat dirname basename mktemp command; do
    p="$(command -v "$t" 2>/dev/null || true)"; [ -n "$p" ] && [ -x "$p" ] && ln -sf "$p" "$NOPHP/$t"
done
OUT="$(PATH="$NOPHP" run "$V")"
[ -e "$S.quant-new" ] && fail "(g) false quant-new without php"
echo "$OUT" | grep -qi 'warning' && fail "(g) false warning without php"

# (h) quant-new is rewritten only when it differs.
V="$T/h"; new_volume "$V" "$T/edited.php"; S="$V/web/sites/default/settings.php"
run "$V" >/dev/null; touch -t "2020${PAD:-}0101${PAD:-}0000" "$S.quant-new"
run "$V" >/dev/null
[ "$(stat -f %m "$S.quant-new" 2>/dev/null || stat -c %Y "$S.quant-new")" -lt 1700000000 ] || fail "(h) quant-new rewritten when identical"

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
[ "$FAILED" = 0 ] || exit 1
echo OK
