#!/bin/sh
# Installs Drupal Console custom commands
# These are our custom commands used to build sites
set -x

DIRECTORY=~/.console/extend
PACKAGE=dennisdigital/drupal_console_commands
BRANCH=master

# Build package
cd ${DIRECTORY}
PATH="${PHP_FOLDER}/:$PATH" composer require ${PACKAGE}:${BRANCH}-dev

# Copy chain commands
cp vendor/${PACKAGE}/chain/*.yml ../chain

# Copy example sites
cp vendor/${PACKAGE}/sites/*.yml ../sites

drupal debug:site
