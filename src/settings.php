<?php

// phpcs:ignoreFile

/**
 * @file
 * Site-specific Drupal settings. Edit this file to customise your site.
 *
 * Database, trusted hosts, reverse proxy and cache settings come from
 * settings.quant.php, which ships in the container image so platform updates
 * reach this environment. Add your own settings below the include; they
 * override the platform values.
 *
 * Keep the include block. If it is missing, the container adds it again at the
 * end of this file on the next start.
 */

// Quant platform settings (managed by the image).
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

// Your settings go below this line.
