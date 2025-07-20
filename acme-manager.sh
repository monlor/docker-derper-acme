#!/bin/bash

set -e

# ACME certificate management script
# Supports multiple DNS providers with Cloudflare as default

CERT_DIR="${DERPER_CERT_DIR:-/app/acme/derper}"
ACME_HOME="${ACME_HOME:-/app/acme}"
ACME_SH="${ACME_HOME}/acme.sh"

# Create certs directory if it doesn't exist
mkdir -p "${CERT_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_acme_config() {
    if [ "${ACME_ENABLED}" != "true" ]; then
        log "ACME is disabled. Skipping certificate generation."
        return 1
    fi

    if [ -z "${DERPER_DOMAIN}" ]; then
        log "ERROR: DERPER_DOMAIN is required when ACME is enabled"
        return 1
    fi

    if [ -z "${ACME_EMAIL}" ]; then
        log "ERROR: ACME_EMAIL is required when ACME is enabled"
        return 1
    fi

    return 0
}


issue_certificate() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"
    local key_file="${CERT_DIR}/${domain}.key"
    
    log "Issuing certificate for domain: ${domain}"
    
    # Issue certificate using acme.sh with DNS provider
    log "Using DNS provider: ${ACME_DNS_PROVIDER}"
    "${ACME_SH}" --issue \
        -d "${domain}" \
        --dns "dns_${ACME_DNS_PROVIDER}" \
        --accountemail "${ACME_EMAIL}" \
        --force
    
    # Install certificate to our certs directory
    "${ACME_SH}" --install-cert \
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

renew_certificates() {
    log "Checking for certificate renewals"
    "${ACME_SH}" --cron --home "${ACME_HOME}"
}

generate_self_signed() {
    local domain="${1}"
    local cert_file="${CERT_DIR}/${domain}.crt"
    local key_file="${CERT_DIR}/${domain}.key"
    
    log "Generating self-signed certificate for ${domain}"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${domain}"
    
    chmod 644 "${cert_file}"
    chmod 600 "${key_file}"
    
    log "Self-signed certificate generated for ${domain}"
}

main() {
    case "${1}" in
        "issue")
            if ! check_acme_config; then
                # Check if we at least have a domain for self-signed cert
                if [ -z "${DERPER_DOMAIN}" ]; then
                    log "ERROR: DERPER_DOMAIN is required for certificate generation"
                    exit 1
                fi
                log "ACME not configured, generating self-signed certificate"
                generate_self_signed "${DERPER_DOMAIN}"
                exit 0
            fi
            
            if ! issue_certificate "${DERPER_DOMAIN}"; then
                log "Certificate issuance failed, generating self-signed certificate"
                generate_self_signed "${DERPER_DOMAIN}"
                exit 1
            fi
            ;;
        "renew")
            if check_acme_config; then
                renew_certificates
            else
                log "ACME not configured, skipping renewal"
            fi
            ;;
        *)
            log "Usage: $0 {issue|renew}"
            exit 1
            ;;
    esac
}

main "$@"