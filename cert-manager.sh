#!/bin/bash

set -e

# Certificate management script
# Supports automatic ACME issuance and manual user-provided certificates

CERT_DIR="${DERPER_CERT_DIR:-/app/acme/derper}"
ACME_HOME="${ACME_HOME:-/app/acme}"
ACME_SH="${ACME_HOME}/acme.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

init_acme() {
    # Initialize ACME only in auto mode
    if [ "${CERT_MODE}" = "manual" ]; then
        log "Certificate mode is manual, skipping ACME initialization"
        return 0
    fi

    log "Initializing ACME environment"

    # Copy acme.sh if not exists
    if [ ! -f ${ACME_SH} ]; then
        cp -rf $HOME/.acme.sh/* ${ACME_HOME}
        log "Copied acme.sh to ${ACME_HOME}"
    fi

    # Create certs directory
    mkdir -p "${CERT_DIR}"
    log "Certificate directory ready: ${CERT_DIR}"
}

check_acme_config() {
    if [ "${CERT_MODE}" = "manual" ]; then
        log "Certificate mode is manual. Skipping ACME configuration check."
        return 1
    fi

    if [ -z "${DERPER_DOMAIN}" ]; then
        log "ERROR: DERPER_DOMAIN is required when certificate mode is auto"
        return 1
    fi

    if [ -z "${ACME_EMAIL}" ]; then
        log "ERROR: ACME_EMAIL is required when certificate mode is auto"
        return 1
    fi

    return 0
}

check_certificate_validity() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"

    # Certificate doesn't exist
    if [ ! -f "${cert_file}" ]; then
        log "Certificate file not found: ${cert_file}"
        return 1
    fi

    # Check if certificate expires within 30 days (2592000 seconds)
    if ! openssl x509 -checkend 2592000 -noout -in "${cert_file}" 2>/dev/null; then
        log "Certificate for ${domain} will expire within 30 days"
        return 1
    fi

    log "Certificate for ${domain} is valid and not expiring soon"
    return 0
}


issue_certificate() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"
    local key_file="${CERT_DIR}/${domain}.key"

    log "Issuing certificate for domain: ${domain}"

    # Issue certificate using acme.sh with DNS provider (force issue)
    log "Using DNS provider: ${ACME_DNS_PROVIDER}"
    "${ACME_SH}" --issue \
        --home "${ACME_HOME}" \
        -d "${domain}" \
        --dns "dns_${ACME_DNS_PROVIDER}" \
        --accountemail "${ACME_EMAIL}" \
        --force

    # Install certificate to our certs directory
    "${ACME_SH}" --install-cert \
        --home "${ACME_HOME}" \
        -d "${domain}" \
        --cert-file "${cert_file}" \
        --key-file "${key_file}" \
        --fullchain-file "${cert_file}" \
        --reloadcmd "echo 'Certificate installed for ${domain}'"

    if [ -f "${cert_file}" ] && [ -f "${key_file}" ]; then
        log "Certificate successfully generated for ${domain}"
        # Set proper permissions
        chmod 644 "${cert_file}"
        chmod 600 "${key_file}"
        return 0
    else
        log "ERROR: Failed to generate certificate for ${domain}"
        return 1
    fi
}

get_certificate_expiry_date() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"

    if [ ! -f "${cert_file}" ]; then
        log "ERROR: Certificate file not found: ${cert_file}"
        return 1
    fi

    # Get expiry date in epoch seconds
    local expiry_date=$(openssl x509 -enddate -noout -in "${cert_file}" 2>/dev/null | cut -d= -f2)
    if [ -z "${expiry_date}" ]; then
        log "ERROR: Failed to read certificate expiry date"
        return 1
    fi

    # Convert to epoch seconds
    local expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
    if [ -z "${expiry_epoch}" ]; then
        log "ERROR: Failed to convert expiry date to epoch"
        return 1
    fi

    echo "${expiry_epoch}"
    return 0
}

schedule_expiry_restart() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"

    if [ ! -f "${cert_file}" ]; then
        log "ERROR: Certificate file not found: ${cert_file}"
        return 1
    fi

    log "Scheduling auto-restart before certificate expiry"

    # Get certificate expiry date
    local expiry_epoch=$(get_certificate_expiry_date "${domain}")
    if [ -z "${expiry_epoch}" ]; then
        log "ERROR: Failed to get certificate expiry date"
        return 1
    fi

    # Calculate restart time (1 day before expiry)
    local restart_epoch=$((expiry_epoch - 86400))
    local current_epoch=$(date +%s)

    # Check if restart time is in the future
    if [ ${restart_epoch} -le ${current_epoch} ]; then
        log "WARNING: Certificate expires in less than 1 day, immediate restart recommended"
        return 1
    fi

    # Calculate time until restart
    local seconds_until_restart=$((restart_epoch - current_epoch))
    local days_until_restart=$((seconds_until_restart / 86400))

    log "Certificate expires in ${days_until_restart} days"
    log "Auto-restart scheduled for 1 day before expiry"

    # Extract date components for cron
    # date -d (Linux) or date -r (macOS)
    local restart_minute=$(date -d "@${restart_epoch}" '+%M' 2>/dev/null || date -r ${restart_epoch} '+%M' 2>/dev/null)
    local restart_hour=$(date -d "@${restart_epoch}" '+%H' 2>/dev/null || date -r ${restart_epoch} '+%H' 2>/dev/null)
    local restart_day=$(date -d "@${restart_epoch}" '+%d' 2>/dev/null || date -r ${restart_epoch} '+%d' 2>/dev/null)
    local restart_month=$(date -d "@${restart_epoch}" '+%m' 2>/dev/null || date -r ${restart_epoch} '+%m' 2>/dev/null)

    if [ -z "${restart_minute}" ] || [ -z "${restart_hour}" ] || [ -z "${restart_day}" ] || [ -z "${restart_month}" ]; then
        log "ERROR: Failed to extract date components for cron"
        return 1
    fi

    # Format: minute hour day month weekday command
    local cron_expression="${restart_minute} ${restart_hour} ${restart_day} ${restart_month} * pkill -TERM derper"

    log "Cron expression: ${cron_expression}"

    # Set crontab with only the restart job (replaces any existing crontab)
    echo "${cron_expression}" | crontab -

    log "Successfully scheduled restart job via cron"
    return 0
}

cmd_auto() {
    local domain="${DERPER_DOMAIN}"

    # Validate domain is set
    if [ -z "${domain}" ]; then
        log "ERROR: DERPER_DOMAIN is required"
        exit 1
    fi

    # Initialize ACME environment
    init_acme

    # Check if certificate is valid (not expiring within 30 days)
    if check_certificate_validity "${domain}"; then
        log "Certificate is valid, no action needed"
        exit 0
    fi

    # Certificate is missing or expiring, need to obtain/renew
    log "Certificate needs to be obtained or renewed"

    # Check if ACME is configured
    if ! check_acme_config; then
        log "ERROR: ACME is not configured"
        exit 1
    fi

    # Issue certificate via ACME
    log "Attempting to obtain certificate via ACME"
    if ! issue_certificate "${domain}"; then
        log "ERROR: Failed to obtain certificate via ACME"
        exit 1
    fi

    # Certificate was successfully issued, restart derper if running
    if [ -n "$(pgrep derper)" ]; then
        log "Certificate updated, restarting derper service"
        pkill -TERM derper
    else
        log "Certificate obtained, derper not running yet"
    fi
}

cmd_manual() {
    local domain="${DERPER_DOMAIN}"

    # Validate domain is set
    if [ -z "${domain}" ]; then
        log "ERROR: DERPER_DOMAIN is required"
        exit 1
    fi

    # Verify certificate files exist
    local cert_file="${CERT_DIR}/${domain}.crt"
    local key_file="${CERT_DIR}/${domain}.key"

    if [ ! -f "${cert_file}" ]; then
        log "ERROR: Certificate file not found: ${cert_file}"
        log "Please mount your certificate at: ${CERT_DIR}/${domain}.crt"
        exit 1
    fi

    if [ ! -f "${key_file}" ]; then
        log "ERROR: Private key file not found: ${key_file}"
        log "Please mount your private key at: ${CERT_DIR}/${domain}.key"
        exit 1
    fi

    log "Certificate files verified:"
    log "  - Certificate: ${cert_file}"
    log "  - Private key: ${key_file}"

    # Schedule auto-restart before expiry
    log "Scheduling auto-restart before certificate expiry"
    schedule_expiry_restart "${domain}"
}

main() {
    case "${1}" in
        "auto")
            cmd_auto
            ;;
        "manual")
            cmd_manual
            ;;
        *)
            log "Usage: $0 {auto|manual}"
            exit 1
            ;;
    esac
}

main "$@"