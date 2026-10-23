#!/bin/bash
# Move legacy volumes to the settings.quant.php layout without losing customer edits.
#
# settings.php lives on the volume and is copied there once, so edits to the
# image copy never arrive. Platform settings now live in settings.quant.php in
# the image, and the new settings.php includes it. For a volume whose
# settings.php does not include it yet:
#   - byte-identical to a settings.php this template shipped: replace it with
#     the new settings.php (no customer edits can exist);
#   - anything else: leave it untouched, write settings.php.quant-new beside it
#     and log a warning with the migration steps.

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/opt/drupal}"
SOURCE_DIR="${SOURCE_DIR:-/usr/src/drupal-cms}"
SETTINGS="$TARGET_DIR/web/sites/default/settings.php"
MARKER_FILE="$TARGET_DIR/.drupal-cms-initialized"

# sha256 of every settings.php this template shipped before settings.quant.php.
SHIPPED_HASHES="
$(printf '%s\n' \
    eddbb587069e24c8173551fbb579301771f77e79361d8673910eaff74b335b52 \
    23caeb4b61c1e655d3405e35d117710ed9643fe640007426188bab707b1ea5ed \
    5dcc24611e2fc4707c5be11326aa08f4e76ae12d13e48369938a36bcdeb370e7 \
    0c6e8c6927f78c69929d7472301cc15973ed1a95ea4c744f22c97115a1fb7238 \
    a179abdcb84e2f16cc23491608072700b24def49209e1c313352334c147cbeff \
    d86397774b8dc4ed526e1d1eab27e88401445be2789e9d46c6c21f9255b687e7 \
    0493a559397e3c8b1ba8c9cc51e97e8a5cd4a6f5241cc16a1cbd90fa0561bbd5 \
    ef9faa4459c5e8eef3a2e7a99119f3ef5d1984b78cbb9849be48e2bbc4f81ab4 \
    4f514069020f383328a82ccb803cf8f834e373a2aaf7030937e44e446509115e \
    '')
"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

mode_of() {
    stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

# True when settings.php has a PHP string naming settings.quant.php.
# The PHP tokenizer ignores comments, so a comment does not count.
includes_platform_file() {
    php -r '
        $t = token_get_all(file_get_contents($argv[1]));
        foreach ($t as $x) {
            if (is_array($x) && $x[0] === T_CONSTANT_ENCAPSED_STRING && strpos($x[1], "settings.quant.php") !== false) { exit(0); }
        }
        exit(1);
    ' "$1"
}

is_shipped_version() {
    local hash
    hash=$(sha256_of "$1")
    grep -qx "$hash" <<< "$SHIPPED_HASHES"
}

replace_settings() {
    local mode
    mode=$(mode_of "$SETTINGS")
    chmod u+w "$SETTINGS"
    cp "$SOURCE_DIR/settings.php" "$SETTINGS"
    chmod "$mode" "$SETTINGS"
}

write_proposal() {
    cp "$SOURCE_DIR/settings.php" "$SETTINGS.quant-new"
    echo "[settings-include] WARNING: settings.php has your own changes and does not include settings.quant.php."
    echo "[settings-include] WARNING: Platform updates (for example trusted hosts) do not reach this environment."
    echo "[settings-include] WARNING: settings.php was NOT changed. A new version is in $SETTINGS.quant-new."
    echo "[settings-include] WARNING: To migrate, copy your own settings from settings.php into settings.php.quant-new"
    echo "[settings-include] WARNING: below the include, then rename settings.php.quant-new to settings.php."
}

# First boot: 10-copy-drupal-cms.sh ships the new settings.php with the include.
if [ ! -f "$MARKER_FILE" ] || [ ! -f "$SETTINGS" ] || [ ! -f "$SOURCE_DIR/settings.php" ]; then
    exit 0
fi

if includes_platform_file "$SETTINGS"; then
    echo "[settings-include] settings.php already includes settings.quant.php"
elif is_shipped_version "$SETTINGS"; then
    echo "[settings-include] settings.php is an unmodified template version; replacing it"
    replace_settings
else
    write_proposal
fi
