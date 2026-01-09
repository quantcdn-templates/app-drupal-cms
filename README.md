# Drupal CMS Template for Quant Cloud

This template provides a ready-to-deploy [Drupal CMS](https://www.acquia.com/blog/drupal-cms) (formerly Starshot) installation optimized for Quant Cloud.

## What is Drupal CMS?

Drupal CMS is the next generation of Drupal, designed for **UI-managed workflows**. Key features include:

- **Project Browser** - Install modules and themes directly from the admin UI
- **Automatic Updates** - Keep core, modules, and themes updated automatically
- **Recipes** - Apply pre-packaged configurations for common use cases
- **AI Features** - AI-powered site building, content suggestions, and more
- **Modern Admin UI** - Clean, intuitive interface with drag-and-drop dashboards

## Architecture: Mutable Codebase

Unlike traditional Drupal deployments with immutable containers, **Drupal CMS requires a mutable filesystem** to support its UI-managed features.

### How It Works

1. **Container Image** - Contains Drupal CMS source at `/usr/src/drupal-cms/`
2. **Persistent Volume** - EFS volume mounted at `/opt/drupal/`
3. **First Boot** - Entrypoint script copies source files to volume if empty
4. **Subsequent Boots** - Uses existing files from persistent volume
5. **UI Updates** - Module installs, updates, and Recipe applications persist to EFS

This pattern is similar to the WordPress approach, allowing the application to manage itself while maintaining container-based deployment.

## Local Development

For both deployment options, you can develop locally using either Docker Compose or DDEV:

### Option 1: Docker Compose

1. **Clone** your repo (or this template)
2. **Install dependencies**:
   ```bash
   cd src && composer install && cd ..
   ```
3. **Use overrides** (required for local development):
   ```bash
   ls docker-compose.override.yml
   ```
   > **Note**: This override enables testing of entrypoint scripts (like `00-copy-drupal-cms.sh`) that normally run via Quant Cloud's platform wrapper. It also mounts your local `src/` directory for live code changes and disables opcache for faster development.
4. **Start services**:
   ```bash
   docker compose up -d
   ```
5. **Access Drupal** at http://localhost and run through installation

### Option 2: DDEV (Recommended for Developers)

1. **Clone** your repo (or this template)
2. **Install DDEV**: https://ddev.readthedocs.io/en/stable/users/install/
3. **Configure, start, and install dependencies**:
   ```bash
   ddev config --project-type=drupal11 --docroot=src/web
   ddev start
   ddev composer install
   ddev composer drupal:recipe-unpack
   ```
4. **Check status**:
   ```bash
   ddev status
   ```
5. **Access Drupal** at the provided DDEV URL and run through installation
6. **Use DDEV Tools**
DDEV provides additional developer tools like Xdebug, Drush integration, Redis caching, and matches production configuration exactly.

## Deployment to Quant Cloud

The template is pre-configured for Quant Cloud:

- ✅ ARM64-optimized builds
- ✅ EFS-backed persistent volume for `/opt/drupal/`
- ✅ Environment-specific builds (dev vs production)
- ✅ Automatic redeployment on git push
- ✅ Database syncing between environments

## Configuration

### Environment Variables

Standard Drupal database variables are automatically provided by Quant Cloud:

- `DB_HOST` - Database hostname
- `DB_DATABASE` - Database name
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password
- `DB_PORT` - Database port (default: 3306)

### Custom Entrypoints

Add custom initialization scripts to `.docker/quant/entrypoints/` - they run on container startup.

### PHP Configuration

Customize PHP settings in `.docker/quant/php.ini.d/` - see README.md in that directory.

## Drush Support

This template includes Drush (Drupal CLI) pre-installed and configured.

### Local Development

**Docker Compose**
```bash
docker compose exec drupal-cms drush status
docker compose exec drupal-cms drush cr    # Clear cache
docker compose exec drupal-cms drush updb  # Update database
docker compose exec drupal-cms drush cex   # Export configuration
docker compose exec drupal-cms drush cim   # Import configuration
```

**DDEV**
```bash
ddev drush status
ddev drush cr    # Clear cache
ddev drush updb  # Update database
ddev drush cex   # Export configuration
ddev drush cim   # Import configuration
```

### Quant Cloud (via SSH/exec)
```bash
drush status
drush cr
drush pm:enable module_name
drush pm:uninstall module_name
```

## Code Standards

### Find coding standard issues

**Docker Compose**
```bash
docker compose exec drupal-cms vendor/bin/phpcs --standard=Drupal,DrupalPractice src/web/modules/custom src/web/themes/custom
```

**DDEV**
```bash
ddev exec php src/vendor/bin/phpcs --standard=Drupal,DrupalPractice src/web/modules/custom src/web/themes/custom
```

### Fix coding standards automatically

**Docker Compose**
```bash
docker compose exec drupal-cms vendor/bin/phpcbf --standard=Drupal,DrupalPractice src/web/modules/custom src/web/themes/custom
```

**DDEV**
```bash
ddev exec php src/vendor/bin/phpcbf --standard=Drupal,DrupalPractice src/web/modules/custom src/web/themes/custom
```

## Important Notes

### Persistent Volume Required

The entire `/opt/drupal/` directory must be persistent (EFS in Quant Cloud) to support:
- UI-based module/theme installation
- Automatic updates
- Recipe applications
- Custom code added through admin UI

### Updates Through UI vs CI/CD

With Drupal CMS, you can choose:

1. **UI-Managed** (Default) - Use Project Browser and Automatic Updates
2. **CI/CD-Managed** - Disable UI updates and manage through git/composer

To disable UI updates, add to `settings.php`:
```php
$settings['allow_authorize_operations'] = FALSE;
```

### Container Rebuilds

When rebuilding containers:
- Source files in image at `/usr/src/drupal-cms/` are updated
- Existing persistent volume at `/opt/drupal/` is preserved
- To start fresh, delete the EFS volume

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` values
   - Verify database service is running (Quant Cloud manages this)
   - Check network connectivity

2. **Permission Issues**
   - Ensure `src` folder has proper permissions
   - Check Docker volume mounts

3. **Module Installation Issues**
   - Run `composer install` in the `src` directory
   - Clear Drupal cache: `drush cr`
   - Check for PHP memory limits

4. **Port Conflicts**
   - For docker compose, you may see `port is already allocated` errors
   - If you are running DDEV, turn it off with `ddev poweroff`
   - If you are running another app, turn it off with `docker compose -p app-name down`

### Logs

**Docker Compose**
```bash
docker compose logs -f drupal-cms
```

**DDEV**
```bash
ddev logs -f
```

### Accessing the Container

**Docker Compose**
```bash
docker compose exec drupal-cms bash
```

**DDEV**
```bash
ddev ssh
```

## Learn More

- [Drupal CMS Official Site](https://new.drupal.org/drupal-cms)
- [Drupal CMS Blog Post](https://www.acquia.com/blog/drupal-cms)
- [Starshot Initiative](https://drupal.org/about/starshot)
- [Dries' Launch Article](https://dri.es/drupal-cms-1-released)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with both local development and Quant Cloud deployment
5. Check coding standards
6. Submit a pull request

## License

This template is released under the MIT License. See LICENSE file for details.

## Support
 
- GitHub Issues: [Create an issue](https://github.com/quantcdn-templates/app-drupal-cms/issues)
- Documentation: [Quant Cloud Documentation](https://docs.quantcdn.io/)
- Community: [Quant Discord](https://discord.gg/quant)
- Email: [support@quantcdn.io](mailto:support@quantcdn.io)
