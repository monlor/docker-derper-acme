#!/bin/bash

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Certificate management based on mode
if [ "${CERT_MODE}" = "manual" ]; then
    log "Certificate mode: manual"
    log "Verifying user-provided certificates and scheduling restart..."
    /app/cert-manager.sh manual

    # Start cron daemon for scheduled restart
    log "Starting cron daemon"
    service cron start
else
    log "Certificate mode: auto"
    log "Checking ACME certificates..."
    /app/cert-manager.sh auto

    # Set up certificate renewal cron job
    log "Setting up certificate renewal cron job (daily at 2 AM)"
    echo "0 2 * * * /app/cert-manager.sh auto" | crontab -

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

# Client verification URL
if [ -n "${DERPER_VERIFY_CLIENT_URL}" ]; then
    DERPER_ARGS="${DERPER_ARGS} -verify-client-url=${DERPER_VERIFY_CLIENT_URL}"
fi

# Extra arguments (for any additional derper parameters)
if [ -n "${DERPER_EXTRA_ARGS}" ]; then
    DERPER_ARGS="${DERPER_ARGS} ${DERPER_EXTRA_ARGS}"
fi

log "Starting derper with arguments: ${DERPER_ARGS}"

# Start derper
exec derper ${DERPER_ARGS}