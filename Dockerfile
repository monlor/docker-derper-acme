FROM golang:latest AS builder

# Install derper
RUN go install tailscale.com/cmd/derper@main

FROM ubuntu

# Install necessary packages
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Copy derper binary from builder
COPY --from=builder /go/bin/derper /usr/local/bin/derper

# Install acme.sh for certificate management
RUN curl https://get.acme.sh | sh

# Create acme directory
RUN mkdir -p /app/acme

# Copy certificate management script
COPY cert-manager.sh /app/cert-manager.sh
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/cert-manager.sh /app/entrypoint.sh

# Environment variables for derper
ENV DERPER_DOMAIN=
ENV DERPER_CERT_DIR=/app/acme/derper
ENV DERPER_ADDR=:443
ENV DERPER_HTTP_PORT=80
ENV DERPER_STUN=true
ENV DERPER_STUN_PORT=3478
ENV DERPER_VERIFY_CLIENTS=false

# Environment variables for certificate management
ENV CERT_MODE=auto
ENV ACME_EMAIL=your-email@example.com
ENV ACME_DNS_PROVIDER=cf
ENV ACME_HOME=/app/acme

# Expose ports
EXPOSE 443 80 3478/udp

WORKDIR /app

# Use entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
