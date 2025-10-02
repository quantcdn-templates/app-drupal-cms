ARG PHP_VERSION=8.4
FROM ghcr.io/quantcdn-templates/app-apache-php:${PHP_VERSION}

# Set document root to Drupal's web directory
ENV DOCUMENT_ROOT=/opt/drupal/web

# Set working directory to Drupal root (parent of web/)
WORKDIR /opt/drupal

# Copy dependency files and required config files first (changes occasionally)
COPY src/composer.json src/composer.lock* src/settings.php src/services.yml src/redis-unavailable.services.yml ./

# Install PHP dependencies (cached until composer files change)
RUN set -eux; \
    export COMPOSER_HOME="$(mktemp -d)"; \
    composer config apcu-autoloader true; \
    composer install --optimize-autoloader --apcu-autoloader --no-dev; \
    rm -rf "$COMPOSER_HOME"

# Copy configuration and scripts (changes occasionally)
COPY .docker/deployment-scripts /quant/deployment-scripts

# Copy custom entrypoint scripts to Quant platform location (if any exist)
COPY .docker/quant/entrypoints/ /quant-entrypoint.d/
RUN if [ "$(ls -A /quant-entrypoint.d/)" ]; then chmod +x /quant-entrypoint.d/*; fi

# Copy custom PHP configuration files (if any exist)
COPY .docker/quant/php.ini.d/ /usr/local/etc/php/conf.d/

# Set up permissions (rarely changes)
RUN chmod +x /quant/deployment-scripts/* && \
    usermod -a -G www-data nobody && \
    usermod -a -G root nobody && \
    usermod -a -G www-data root

# Copy remaining source code (changes frequently - do this last!)
COPY src/ ./

# Copy the BUILT source (including vendor/) to template location for volume initialization
RUN cp -a /opt/drupal /usr/src/drupal-cms && \
    chown -R www-data:www-data /usr/src/drupal-cms && \
    rm -rf /opt/drupal/* && \
    mkdir -p /opt/drupal

# Create volume mount point for persistent Drupal CMS installation
# Volume starts empty; entrypoint copies from /usr/src/drupal-cms/ on first boot
VOLUME /opt/drupal

# Set PATH
ENV PATH=${PATH}:/opt/drupal/vendor/bin

# Copy custom entrypoint script for local development
# (Only used when overridden in docker-compose.override.yml)
COPY .docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-drupal-cms.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-drupal-cms.sh

# Expose ports
EXPOSE 80

# Use standard Apache/PHP entrypoint by default
# In Quant Cloud, the platform wrapper runs /quant-entrypoint.d/ scripts automatically
# For local dev, copy docker-compose.override.yml.example to docker-compose.override.yml
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["apache2-foreground"]