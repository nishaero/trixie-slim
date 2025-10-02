FROM debian:trixie-slim

# Set labels for metadata
LABEL maintainer="nishaero" \
      org.opencontainers.image.title="trixie-slim" \
      org.opencontainers.image.description="Minimal Debian Trixie base image with enhanced security and Bitnami compatibility" \
      org.opencontainers.image.source="https://github.com/nishaero/trixie-slim"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Create install_packages utility for secure package installation
RUN echo '#!/bin/bash\n\
set -e\n\
set -u\n\
set -o pipefail\n\
\n\
# Update package lists\n\
apt-get update\n\
\n\
# Install packages with security flags\n\
apt-get install -y --no-install-recommends "$@"\n\
\n\
# Clean up\n\
apt-get clean\n\
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*\n\
rm -rf /var/cache/apt/archives/*' > /usr/local/bin/install_packages && \
    chmod +x /usr/local/bin/install_packages

# Install essential base utilities with security focus
RUN install_packages \
    ca-certificates \
    curl \
    gnupg \
    procps \
    tini \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Security hardening: Create non-root user for runtime
RUN groupadd -r appuser --gid=1001 && \
    useradd -r -g appuser --uid=1001 --home-dir=/app --shell=/sbin/nologin appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

# Configure locale support (required for many applications)
RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    install_packages locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8

# Security: Remove unnecessary setuid/setgid binaries
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} \; || true

# Clean up and minimize attack surface
RUN rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /var/cache/debconf/* \
    /var/log/* && \
    find /var/log -type f -exec truncate -s 0 {} \;

# Set tini as entrypoint for proper signal handling (PID 1 zombie reaping)
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/bin/bash"]

# Switch to non-root user by default (can be overridden)
USER appuser
WORKDIR /app
