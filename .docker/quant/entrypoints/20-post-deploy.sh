#!/bin/bash

# Run post-deployment scripts.
if [ "$QUANT_ENV_TYPE" == "development" ]; then
    /quant/deployment-scripts/post-deploy-development.sh
elif [ "$QUANT_ENV_TYPE" == "production" ]; then
    /quant/deployment-scripts/post-deploy-production.sh
elif [ "$QUANT_ENV_TYPE" == "local" ]; then
    echo "Local development mode - skipping post-deploy scripts"
else
    echo "Unknown environment type: $QUANT_ENV_TYPE"
fi
