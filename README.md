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

```bash
# Install dependencies
cd src && composer install && cd ..

# Copy override file (required for local development)
cp docker-compose.override.yml.example docker-compose.override.yml
# Note: This enables testing of entrypoint scripts (like 00-copy-drupal-cms.sh) that 
# normally run via Quant Cloud's platform wrapper. It also mounts your local src/ 
# directory for live code changes and disables opcache for faster development.

# Start services
docker compose up -d

# Access site
open http://localhost

# View logs
docker compose logs -f drupal-cms

# Access Drush
docker compose exec drupal-cms drush status

# Shell access
docker compose exec drupal-cms bash

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

For Quant Cloud support, contact [support@quantcdn.io](mailto:support@quantcdn.io)
