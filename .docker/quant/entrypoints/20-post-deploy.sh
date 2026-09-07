#!/bin/bash

# Run post-deployment scripts.
#
# On a first boot the Drupal CMS tree is still being copied onto the volume
# (see 10-copy-drupal-cms.sh). The post-deploy scripts wait for that copy, so
# run them in the background here: Apache must start now to serve the
# placeholder page, or the load balancer health check fails and the task is
# killed before the copy completes. Once the marker exists the scripts run
# inline as before.
MARKER_FILE="/opt/drupal/.drupal-cms-initialized"

run_post_deploy() {
    if [ "$QUANT_ENV_TYPE" == "development" ]; then
        /quant/deployment-scripts/post-deploy-development.sh
    elif [ "$QUANT_ENV_TYPE" == "production" ]; then
        /quant/deployment-scripts/post-deploy-production.sh
    elif [ "$QUANT_ENV_TYPE" == "local" ]; then
        echo "Local development mode - skipping post-deploy scripts"
    else
        echo "Unknown environment type: $QUANT_ENV_TYPE"
    fi
}

if [ -f "$MARKER_FILE" ]; then
    run_post_deploy
else
    echo "[post-deploy] Drupal CMS not initialized yet; running post-deploy in the background once the copy completes"
    run_post_deploy &
    disown
fi
