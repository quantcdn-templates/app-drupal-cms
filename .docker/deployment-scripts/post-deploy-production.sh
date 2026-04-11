#!/bin/bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

## PRODUCTION
## This script will run after each deployment completes.
printf "${RED}**Production environment**${NC} post-deploy-production\n"

## Wait for the Drupal CMS file copy to complete (runs in background on first boot).
MARKER_FILE="/opt/drupal/.drupal-cms-initialized"
if [ ! -f "$MARKER_FILE" ]; then
    printf "${YELLOW}Waiting for Drupal CMS initialization to complete...${NC}\n"
    WAIT_SECONDS=0
    MAX_WAIT=300
    while [ ! -f "$MARKER_FILE" ]; do
        sleep 5
        WAIT_SECONDS=$((WAIT_SECONDS + 5))
        echo "  Still waiting... (${WAIT_SECONDS}s elapsed)"
        if [ "$WAIT_SECONDS" -ge "$MAX_WAIT" ]; then
            printf "${RED}Timed out waiting for Drupal CMS initialization after ${MAX_WAIT}s.${NC}\n"
            exit 1
        fi
    done
    printf "${GREEN}Drupal CMS files ready.${NC}\n"
fi

## Check if Drupal is installed
if drush status --fields=bootstrap 2>/dev/null | grep -q "Successful"; then
    echo "Drupal is installed, running post-deploy tasks..."
    
    ## Cache rebuild and database updates.
    drush updb -y
    
    ## Configuration import example.
    #drush cim -y
    
    ## Show the output of drush status.
    drush status
else
    printf "${YELLOW}Drupal CMS not yet installed.${NC} Visit the site URL to complete installation.\n"
fi
