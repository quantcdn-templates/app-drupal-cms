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

# Copy all source files
echo "[copy-drupal-cms] Copying files from $SOURCE_DIR to $TARGET_DIR..."
cp -a "$SOURCE_DIR/." "$TARGET_DIR/"

# Copy config files to proper locations (mimic composer post-install scripts)
echo "[copy-drupal-cms] Copying configuration files to web/sites/default..."
mkdir -p "$TARGET_DIR/web/sites/default"
cp "$TARGET_DIR/settings.php" "$TARGET_DIR/web/sites/default/settings.php" 2>/dev/null || true
cp "$TARGET_DIR/services.yml" "$TARGET_DIR/web/sites/default/services.yml" 2>/dev/null || true
cp "$TARGET_DIR/redis-unavailable.services.yml" "$TARGET_DIR/web/sites/default/redis-unavailable.services.yml" 2>/dev/null || true

# Validate critical files exist
MISSING_FILES=0
if [ ! -f "$TARGET_DIR/web/sites/default/default.settings.php" ]; then
    echo "[copy-drupal-cms] ⚠️  Missing: web/sites/default/default.settings.php"
    MISSING_FILES=1
fi
if [ ! -f "$TARGET_DIR/web/sites/default/settings.php" ]; then
    echo "[copy-drupal-cms] ⚠️  Missing: web/sites/default/settings.php"
    MISSING_FILES=1
fi
if [ ! -f "$TARGET_DIR/web/index.php" ]; then
    echo "[copy-drupal-cms] ⚠️  Missing: web/index.php"
    MISSING_FILES=1
fi
if [ "$MISSING_FILES" -eq 1 ]; then
    echo "[copy-drupal-cms] ❌ Critical files missing after copy — initialization incomplete"
    echo "[copy-drupal-cms] Container will retry initialization on next restart"
    exit 1
fi

# Remove placeholder page now that Drupal's index.php is in place
# (Apache's DirectoryIndex prefers index.html over index.php)
rm -f "$PLACEHOLDER_FILE"
echo "[copy-drupal-cms] Placeholder page removed"

# Set proper ownership
echo "[copy-drupal-cms] Setting ownership..."
chown -R www-data:www-data "$TARGET_DIR"

# Set proper permissions for writable directories
chmod -R 775 "$TARGET_DIR/web/sites/default/files" 2>/dev/null || true
chmod 664 "$TARGET_DIR/web/sites/default/settings.php" 2>/dev/null || true

# Mark initialization as complete — only written after everything succeeds
touch "$MARKER_FILE"
chown www-data:www-data "$MARKER_FILE"

echo "[copy-drupal-cms] ✅ Drupal CMS initialized successfully"
