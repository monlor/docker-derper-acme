# Docker DERPER with ACME - Claude.md

## Project Overview

This project implements a Docker service that runs Tailscale DERPER server with automatic ACME certificate management. The service combines:

- **Tailscale DERPER server** - For secure relay connections
- **ACME certificate management** - Automatic SSL/TLS certificate issuance and renewal
- **Multiple DNS provider support** - Compatible with 200+ DNS providers via acme.sh
- **Fallback mechanisms** - Self-signed certificates when ACME fails
- **Container orchestration** - Docker Compose for easy deployment

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   acme.sh       │    │  DERPER Server  │    │   Certificate   │
│   DNS Challenge │────▶   Manual Mode    │────▶   Storage      │
│   Auto-renewal  │    │   Port 443/80   │    │ /app/acme/derper│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Key Components

### 1. Certificate Management (`acme-manager.sh`)
- Issues certificates via ACME DNS challenges
- Supports all acme.sh DNS providers using `--dns dns_${PROVIDER}` format
- Generates self-signed certificates as fallback
- Handles certificate renewal via cron jobs

### 2. Service Orchestration (`entrypoint.sh`)
- Generates certificates before starting DERPER
- Configures DERPER server with manual certificate mode
- Sets up automatic renewal cron jobs
- Manages service lifecycle

### 3. Container Configuration (`Dockerfile`)
- Multi-stage build with golang and ubuntu
- Installs derper binary and acme.sh client
- Sets up proper directory structure and permissions
- Configures environment variables

## Build and Test Commands

### Build
```bash
docker build -t derper-acme .
```

### Test Certificate Generation
```bash
./quick-test.sh
```

### Full Test Suite
```bash
./test-certs.sh
```

### Deploy
```bash
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

## Configuration

### Required Environment Variables
- `DERPER_DOMAIN` - Domain name for the DERPER server
- `ACME_EMAIL` - Email for ACME registration (if ACME enabled)

### ACME Configuration
- `ACME_ENABLED` - Enable/disable ACME certificate management
- `ACME_DNS_PROVIDER` - DNS provider code (cf, ali, dp, aws, etc.)
- `ACME_HOME` - ACME data directory (/app/acme)
- Provider-specific credentials (CF_Token, Ali_Key, etc.)

### DERPER Server Settings
- `DERPER_CERT_DIR` - Certificate directory (/app/acme/derper)
- `DERPER_ADDR` - HTTPS listen address (:443)
- `DERPER_HTTP_PORT` - HTTP port (80)
- `DERPER_STUN` - Enable STUN server (true)

## File Structure

```
docker-derper-acme/
├── Dockerfile              # Container build configuration
├── docker-compose.yml      # Service orchestration
├── acme-manager.sh         # Certificate management script
├── entrypoint.sh          # Service startup script
├── .env.example           # Environment configuration template
├── README.md              # User documentation
├── CLAUDE.md              # This file - project context
├── quick-test.sh          # Quick functionality test
├── test-certs.sh          # Comprehensive test suite
└── test-simplified.sh     # DNS provider test
```

## Security Considerations

- Certificates stored with proper permissions (644 for .crt, 600 for .key)
- DERPER server runs in manual certificate mode for security
- Self-signed fallback prevents service failure
- DNS provider credentials passed via environment variables
- Container runs with minimal privileges
- Unified storage in `/app/acme` simplifies volume management

## DNS Provider Support

The service supports all DNS providers compatible with acme.sh:

- **Cloudflare** - `ACME_DNS_PROVIDER=cf`
- **Amazon Route53** - `ACME_DNS_PROVIDER=aws`
- **Aliyun** - `ACME_DNS_PROVIDER=ali`
- **DNSPod** - `ACME_DNS_PROVIDER=dp`
- **GoDaddy** - `ACME_DNS_PROVIDER=gd`
- **Namecheap** - `ACME_DNS_PROVIDER=namecheap`
- And 200+ more providers

See [acme.sh DNS API documentation](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for complete list.

## Troubleshooting

### Certificate Issues
1. Check ACME configuration in logs
2. Verify DNS provider credentials
3. Confirm domain DNS settings
4. Review certificate file permissions

### DERPER Server Issues
1. Check port availability (443, 80, 3478)
2. Verify certificate files exist
3. Review DERPER configuration parameters
4. Check container networking

### Common Commands
```bash
# View logs
docker-compose logs -f derper

# Check certificate status
docker exec derper openssl x509 -in /app/acme/derper/yourdomain.crt -text -noout

# Manual certificate renewal
docker exec derper /app/acme-manager.sh renew

# Restart service
docker-compose restart derper
```

## Development Notes

- The project uses simplified DNS provider configuration
- ACME functionality can be disabled for testing
- Self-signed certificates ensure service availability
- Certificate renewal runs daily at 2 AM via cron
- Health checks verify HTTP endpoint availability

## Future Enhancements

- Support for multiple domains
- Integration with external certificate stores
- Monitoring and alerting for certificate expiry
- Support for HTTP-01 challenges as fallback
- Automated backup of certificate data