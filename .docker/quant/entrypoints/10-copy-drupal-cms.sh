#!/bin/bash
# Copy Drupal CMS source files to volume on first boot
# This allows the filesystem to be mutable for UI-based updates, Project Browser, and Recipes

set -euo pipefail

SOURCE_DIR="/usr/src/drupal-cms"
TARGET_DIR="/opt/drupal"

echo "[copy-drupal-cms] Checking if Drupal CMS needs to be initialized..."

# Check if target directory is empty or doesn't have key files
if [ ! -f "$TARGET_DIR/composer.json" ] || [ ! -d "$TARGET_DIR/web" ]; then
    echo "[copy-drupal-cms] Initializing Drupal CMS from source..."
    
    # Ensure target directory exists
    mkdir -p "$TARGET_DIR"
    
    # Copy all source files
    echo "[copy-drupal-cms] Copying files from $SOURCE_DIR to $TARGET_DIR..."
    cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    
    # Copy config files to proper locations (mimic composer post-install scripts)
    echo "[copy-drupal-cms] Copying configuration files to web/sites/default..."
    cp "$TARGET_DIR/settings.php" "$TARGET_DIR/web/sites/default/settings.php" 2>/dev/null || true
    cp "$TARGET_DIR/services.yml" "$TARGET_DIR/web/sites/default/services.yml" 2>/dev/null || true
    cp "$TARGET_DIR/redis-unavailable.services.yml" "$TARGET_DIR/web/sites/default/redis-unavailable.services.yml" 2>/dev/null || true
    
    # Set proper ownership
    echo "[copy-drupal-cms] Setting ownership..."
    chown -R www-data:www-data "$TARGET_DIR"
    
    # Set proper permissions for writable directories
    chmod -R 775 "$TARGET_DIR/web/sites/default/files" 2>/dev/null || true
    chmod 664 "$TARGET_DIR/web/sites/default/settings.php" 2>/dev/null || true
    
    echo "[copy-drupal-cms] ✅ Drupal CMS initialized successfully"
else
    echo "[copy-drupal-cms] ✅ Drupal CMS already initialized (persistent volume detected)"
fi
