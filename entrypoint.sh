#!/bin/bash

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Generate certificates before starting derper
log "Starting ACME certificate manager..."
/app/acme-manager.sh issue

# Set up certificate renewal cron job if ACME is enabled
if [ "${ACME_ENABLED}" = "true" ]; then
    log "Setting up certificate renewal cron job"
    # Run renewal check every day at 2 AM
    echo "0 2 * * * /app/acme-manager.sh renew" | crontab -
    # Start cron daemon
    service cron start
fi

# Prepare derper command with environment variables
DERPER_ARGS=""

# Set certificate mode to manual since we manage certificates ourselves
DERPER_ARGS="${DERPER_ARGS} -certmode=manual"

# Set certificate directory
if [ -n "${DERPER_CERT_DIR}" ]; then
    DERPER_ARGS="${DERPER_ARGS} -certdir=${DERPER_CERT_DIR}"
fi

# Set domain
if [ -n "${DERPER_DOMAIN}" ]; then
    DERPER_ARGS="${DERPER_ARGS} -hostname=${DERPER_DOMAIN}"
fi

# Set address
if [ -n "${DERPER_ADDR}" ]; then
    DERPER_ARGS="${DERPER_ARGS} -a=${DERPER_ADDR}"
fi

# Set HTTP port
if [ -n "${DERPER_HTTP_PORT}" ]; then
    DERPER_ARGS="${DERPER_ARGS} -http-port=${DERPER_HTTP_PORT}"
fi

# Enable/disable STUN
if [ "${DERPER_STUN}" = "true" ]; then
    DERPER_ARGS="${DERPER_ARGS} -stun"
    if [ -n "${DERPER_STUN_PORT}" ]; then
        DERPER_ARGS="${DERPER_ARGS} -stun-port=${DERPER_STUN_PORT}"
    fi
fi

# Client verification
if [ "${DERPER_VERIFY_CLIENTS}" = "true" ]; then
    DERPER_ARGS="${DERPER_ARGS} -verify-clients"
fi

log "Starting derper with arguments: ${DERPER_ARGS}"

# Start derper
exec derper ${DERPER_ARGS}