# Docker DERPER with ACME

A Docker service that runs Tailscale DERPER server with automatic ACME certificate management.

## Features

- Tailscale DERPER server with manual certificate mode
- Automatic SSL certificate generation using ACME
- Support for multiple DNS providers (Cloudflare, Aliyun, DNSPod)
- Certificate auto-renewal with cron jobs
- Fallback to self-signed certificates if ACME fails
- Configurable via environment variables

## Quick Start

1. Copy the environment file:
```bash
cp .env.example .env
```

2. Edit `.env` with your configuration:
```bash
# Required settings
DERPER_DOMAIN=your-domain.com
ACME_ENABLED=true
ACME_EMAIL=your-email@example.com

# For Cloudflare DNS
ACME_DNS_PROVIDER=cf
CF_Token=your_cloudflare_api_token
```

3. Start the service:
```bash
docker-compose up -d
```

## Configuration

### DERPER Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DERPER_DOMAIN` | `your-domain.com` | Domain name for the DERPER server |
| `DERPER_CERT_DIR` | `/app/acme/derper` | Certificate directory |
| `DERPER_ADDR` | `:443` | HTTPS listen address |
| `DERPER_HTTP_PORT` | `80` | HTTP port |
| `DERPER_STUN` | `true` | Enable STUN server |
| `DERPER_STUN_PORT` | `3478` | STUN port |
| `DERPER_VERIFY_CLIENTS` | `false` | Verify Tailscale clients |

### ACME Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `ACME_ENABLED` | `false` | Enable ACME certificate management |
| `ACME_EMAIL` | Required | Email for ACME registration |
| `ACME_DNS_PROVIDER` | `cf` | DNS provider for challenges |

### DNS Provider Configuration

The service supports all DNS providers compatible with acme.sh using the format `dns_${PROVIDER}`. 

Common examples:

#### Cloudflare
```bash
ACME_DNS_PROVIDER=cf
CF_Token=your_api_token
CF_Account_ID=your_account_id  # Optional
CF_Zone_ID=your_zone_id        # Optional
```

#### Aliyun
```bash
ACME_DNS_PROVIDER=ali
Ali_Key=your_access_key
Ali_Secret=your_secret_key
```

#### DNSPod
```bash
ACME_DNS_PROVIDER=dp
DP_Id=your_dnspod_id
DP_Key=your_dnspod_key
```

#### Other Providers
Any DNS provider supported by acme.sh can be used:
```bash
ACME_DNS_PROVIDER=aws        # Amazon Route53
ACME_DNS_PROVIDER=gd         # GoDaddy
ACME_DNS_PROVIDER=namecheap  # Namecheap
# ... and many more
```

See [acme.sh DNS providers list](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for all supported providers and required environment variables.

## Certificate Management

- Certificates are generated to `/app/acme/derper/` as `{domain}.crt` and `{domain}.key`
- DERPER server is configured to use manual certificate mode
- ACME data is stored in `/app/acme/`
- Automatic renewal runs daily at 2 AM via cron
- Self-signed certificates are generated as fallback

## Ports

- `443/tcp` - HTTPS (DERPER server)
- `80/tcp` - HTTP (status/health)
- `3478/udp` - STUN server

## Volume Mounts

- `app_data:/app/acme` - ACME data and certificate storage (unified storage)

## Health Check

The service includes a health check that verifies the HTTP endpoint is responding.

## Logs

View logs with:
```bash
docker-compose logs -f derper
```

## Building

```bash
docker build -t derper-acme .
```

## Security Notes

- Keep your DNS provider API credentials secure
- The service runs with appropriate file permissions for certificates
- ACME account data is persisted in volumes for renewal