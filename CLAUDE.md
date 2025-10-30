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

### 1. Certificate Management (`cert-manager.sh`)
- **Two distinct commands**:
  - **`auto` command**: ACME certificate management
    - Initializes ACME environment
    - Checks certificate validity (30-day threshold)
    - Issues/renews certificates via ACME DNS challenges with `--force` flag
    - Auto-restarts DERPER after successful issuance (if running)
    - No fallback to self-signed certificates
  - **`manual` command**: User-provided certificate management
    - Verifies certificate files exist (`.crt` and `.key`)
    - Reads certificate expiry date
    - Schedules one-time cron job for restart 1 day before expiry
    - No ACME dependencies
- Supports all acme.sh DNS providers using `--dns dns_${PROVIDER}` format
- Clear separation between auto and manual logic

### 2. Service Orchestration (`entrypoint.sh`)
- Routes to correct cert-manager command based on `CERT_MODE`
- **Auto mode**:
  - Runs `cert-manager.sh auto` on startup
  - Sets up daily cron job at 2 AM: `cert-manager.sh auto`
  - Handles certificate issuance and renewal automatically
- **Manual mode**:
  - Runs `cert-manager.sh manual` on startup
  - Verifies certificate files exist
  - Schedules one-time restart before expiry
- Starts cron daemon for both modes
- Configures DERPER server parameters

### 3. Container Configuration (`Dockerfile`)
- Multi-stage build with golang and ubuntu
- Installs derper binary and acme.sh client
- Installs cron for scheduled task management
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

### Option 1: Automatic ACME Certificates (Default)
```bash
cp .env.example .env
# Edit .env with your ACME configuration
docker-compose up -d
```

### Option 2: Manual Certificates (User-Provided)
```bash
cp .env.example .env
# Edit .env and set CERT_MODE=manual
# CERT_MODE=manual

# Create certificate directory
mkdir -p certs

# Copy your certificates (must match DERPER_DOMAIN)
cp your-domain.crt certs/your-domain.com.crt
cp your-domain.key certs/your-domain.com.key

# Update docker-compose.yml to mount certificates
# Add under volumes:
#   - ./certs:/app/acme/derper:ro

docker-compose up -d
```

**Important for manual mode:**
- Certificate files must be named: `${DERPER_DOMAIN}.crt` and `${DERPER_DOMAIN}.key`
- Container will automatically restart 1 day before certificate expiry
- Replace certificates by updating files and restarting container

## Configuration

### Required Environment Variables
- `DERPER_DOMAIN` - Domain name for the DERPER server

### Certificate Configuration
- `CERT_MODE` - Certificate mode: `auto` (automatic ACME) or `manual` (user-provided)
  - **auto mode**: Automatically issue and renew certificates via ACME
  - **manual mode**: Use user-provided certificates, auto-restart before expiry
- `ACME_EMAIL` - Email for ACME registration (required for auto mode)
- `ACME_DNS_PROVIDER` - DNS provider code (cf, ali, dp, aws, etc.)
- `ACME_HOME` - ACME data directory (/app/acme)
- Provider-specific credentials (CF_Token, Ali_Key, etc.)

### DERPER Server Settings
- `DERPER_CERT_DIR` - Certificate directory (/app/acme/derper)
- `DERPER_ADDR` - HTTPS listen address (:443)
- `DERPER_HTTP_PORT` - HTTP port (80)
- `DERPER_STUN` - Enable STUN server (true)
- `DERPER_STUN_PORT` - STUN port (3478)
- `DERPER_VERIFY_CLIENTS` - Enable client verification (false)
- `DERPER_VERIFY_CLIENT_URL` - Client verification URL (optional)
- `DERPER_EXTRA_ARGS` - Additional derper command-line arguments (optional)

## File Structure

```
docker-derper-acme/
├── Dockerfile              # Container build configuration
├── docker-compose.yml      # Service orchestration
├── cert-manager.sh         # Certificate management script (auto/manual commands)
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
5. **Note:** No self-signed fallback - ACME must succeed or service will fail

### DERPER Server Issues
1. Check port availability (443, 80, 3478)
2. Verify certificate files exist
3. Review DERPER configuration parameters
4. Check container networking
5. If container fails to start, check certificate issuance logs

### Common Commands
```bash
# View logs
docker-compose logs -f derper

# Check certificate status
docker exec derper openssl x509 -in /app/acme/derper/yourdomain.crt -text -noout

# Check certificate expiry date
docker exec derper openssl x509 -enddate -noout -in /app/acme/derper/yourdomain.crt

# Run certificate management manually
# For auto mode: check and renew if needed
docker exec derper /app/cert-manager.sh auto

# For manual mode: verify certificates and reschedule restart
docker exec derper /app/cert-manager.sh manual

# Check scheduled jobs
docker exec derper crontab -l

# Restart service
docker-compose restart derper
```

## Development Notes

- The project uses simplified DNS provider configuration
- ACME functionality is required in auto mode - no self-signed fallback
- **Auto mode**: Certificate check runs daily at 2 AM via cron
- **Manual mode**: One-time restart scheduled using cron, 1 day before certificate expiry
- Only issues new certificates when expiring within 30 days
- Auto-restart on certificate renewal (only if derper is running)
- Health checks verify HTTP endpoint availability
- Manual certificates support wildcard certs and enterprise PKI
- Scheduled tasks can be viewed with `crontab -l` command (manual mode)

## Future Enhancements

- Support for multiple domains
- Integration with external certificate stores
- Monitoring and alerting for certificate expiry
- Automated backup of certificate data