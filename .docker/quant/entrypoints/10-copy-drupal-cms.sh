#!/bin/bash
# Copy Drupal CMS source files to volume on first boot
# This allows the filesystem to be mutable for UI-based updates, Project Browser, and Recipes

set -euo pipefail

SOURCE_DIR="/usr/src/drupal-cms"
TARGET_DIR="/opt/drupal"
MARKER_FILE="$TARGET_DIR/.drupal-cms-initialized"

echo "[copy-drupal-cms] Checking if Drupal CMS needs to be initialized..."

# Use a marker file to detect completed initialization.
# This prevents partial copies from being treated as complete
# (e.g., if a previous boot was killed mid-copy).
if [ -f "$MARKER_FILE" ]; then
    echo "[copy-drupal-cms] ✅ Drupal CMS already initialized (persistent volume detected)"
    exit 0
fi

echo "[copy-drupal-cms] Initializing Drupal CMS from source..."

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Place a temporary placeholder page so Apache doesn't serve a Forbidden error
# while the copy is in progress. Removed after Drupal files are in place.
PLACEHOLDER_FILE="$TARGET_DIR/web/index.html"
mkdir -p "$TARGET_DIR/web"
cat > "$PLACEHOLDER_FILE" <<'PLACEHOLDER'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>Drupal CMS — Initializing</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: #f7f7f7;
            color: #333;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            max-width: 480px;
            padding: 2rem;
        }
        .spinner {
            width: 40px;
            height: 40px;
            margin: 0 auto 1.5rem;
            border: 3px solid #e0e0e0;
            border-top-color: #0678be;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        h1 {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }
        p {
            font-size: 0.95rem;
            color: #666;
            line-height: 1.5;
        }
    </style>
    <script>setTimeout(function(){ location.reload(); }, 15000);</script>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h1>Drupal CMS is initializing</h1>
        <p>The application files are being prepared. This page will refresh automatically.</p>
    </div>
</body>
</html>
PLACEHOLDER
# Add .htaccess with no-cache headers so CDN/proxy layers don't cache the placeholder
PLACEHOLDER_HTACCESS="$TARGET_DIR/web/.htaccess"
cat > "$PLACEHOLDER_HTACCESS" <<'HTACCESS'
<IfModule mod_headers.c>
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
</IfModule>
HTACCESS
chown www-data:www-data "$PLACEHOLDER_FILE" "$PLACEHOLDER_HTACCESS"
echo "[copy-drupal-cms] Placeholder page created"
echo "[copy-drupal-cms] Starting file copy in background — Apache will start now to serve placeholder..."

(
    # Copy into a staging directory on the same volume, then move entries into
    # place. Apache keeps serving the placeholder until web/ is swapped in as the
    # very last step, so no request can hit index.php before vendor/ exists.
    STAGE="$TARGET_DIR/.incoming"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"

    # A shared filesystem costs a network round trip per file operation, so a sequential cp -a of
    # ~41k files takes minutes. Create directories first, then copy files with
    # many parallel workers; a shared filesystem scales with concurrency. cp -a keeps the
    # www-data ownership baked into the image, so no chown -R pass is needed.
    echo "[copy-drupal-cms] Copying files from $SOURCE_DIR to $STAGE (parallel)..."
    START_TS=$(date +%s)
    ( cd "$SOURCE_DIR" && find . -mindepth 1 -type d -print0 \
        | xargs -0 -P 32 -n 200 sh -c 'for d; do mkdir -p "$0/$d"; done' "$STAGE" )
    ( cd "$SOURCE_DIR" && find . \( -type f -o -type l \) -print0 \
        | xargs -0 -P 32 -n 100 cp -a --parents -t "$STAGE" )
    echo "[copy-drupal-cms] Copy finished in $(( $(date +%s) - START_TS ))s"

    # settings.php points config_sync_directory at ../config/default; create it
    # so drush does not report it missing on every deploy.
    mkdir -p "$STAGE/config/default"

    echo "[copy-drupal-cms] Copying configuration files to web/sites/default..."
    mkdir -p "$STAGE/web/sites/default"
    cp "$STAGE/settings.php" "$STAGE/web/sites/default/settings.php" 2>/dev/null || true
    cp "$STAGE/services.yml" "$STAGE/web/sites/default/services.yml" 2>/dev/null || true
    cp "$STAGE/redis-unavailable.services.yml" "$STAGE/web/sites/default/redis-unavailable.services.yml" 2>/dev/null || true

    MISSING_FILES=0
    for f in web/sites/default/default.settings.php web/sites/default/settings.php web/index.php vendor/autoload.php; do
        if [ ! -f "$STAGE/$f" ]; then
            echo "[copy-drupal-cms] ⚠️  Missing: $f"
            MISSING_FILES=1
        fi
    done
    if [ "$MISSING_FILES" -eq 1 ]; then
        echo "[copy-drupal-cms] ❌ Critical files missing after copy — initialization incomplete"
        echo "[copy-drupal-cms] Container will retry initialization on next restart"
        exit 1
    fi

    chmod -R 775 "$STAGE/web/sites/default/files" 2>/dev/null || true
    chmod 664 "$STAGE/web/sites/default/settings.php" 2>/dev/null || true

    # Move everything except web/ into place first, then swap web/ in last.
    echo "[copy-drupal-cms] Moving files into place..."
    for entry in "$STAGE"/* "$STAGE"/.[!.]*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        [ "$name" = "web" ] && continue
        rm -rf "${TARGET_DIR:?}/$name"
        mv "$entry" "$TARGET_DIR/$name"
    done
    mv "$TARGET_DIR/web" "$TARGET_DIR/.web-placeholder"
    mv "$STAGE/web" "$TARGET_DIR/web"
    rm -rf "$TARGET_DIR/.web-placeholder" "$STAGE"
    echo "[copy-drupal-cms] Placeholder page replaced by the real site"

    touch "$MARKER_FILE"
    chown www-data:www-data "$MARKER_FILE"
    echo "[copy-drupal-cms] ✅ Drupal CMS initialized successfully"
) &
disown
