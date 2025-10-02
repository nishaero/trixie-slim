FROM debian:trixie-slim

# ================================
# HARDENED SECURITY PROFILE
# ================================
# Based on Bitnami and Docker hardened best practices:
# - Minimal attack surface
# - No package managers in final image
# - Strict permission controls
# - Compliance labels for security scanning
# - Read-only filesystem compatible
# ================================

# Set OCI-compliant labels for security and compliance
LABEL maintainer="nishaero" \
      org.opencontainers.image.title="trixie-slim-hardened" \
      org.opencontainers.image.description="Hardened minimal Debian Trixie base image with enterprise security standards" \
      org.opencontainers.image.source="https://github.com/nishaero/trixie-slim" \
      org.opencontainers.image.vendor="nishaero" \
      org.opencontainers.image.licenses="MIT" \
      security.profile="hardened" \
      security.non-root="true" \
      security.read-only-rootfs="supported"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ================================
# STAGE 1: Build and Configuration
# ================================

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
    tini \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Security hardening: Create non-root user for runtime
RUN groupadd -r appuser --gid=1001 && \
    useradd -r -g appuser --uid=1001 --home-dir=/app --shell=/sbin/nologin appuser && \
    mkdir -p /app /tmp/.appuser && \
    chown -R appuser:appuser /app /tmp/.appuser && \
    chmod 1777 /tmp

# Configure locale support (minimal - only C.UTF-8)
RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    install_packages locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8

# ================================
# HARDENING MEASURES
# ================================

# 1. Remove setuid/setgid binaries to prevent privilege escalation
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

# 2. Remove world-writable files and directories (except /tmp, /var/tmp)
RUN find / -xdev -type d -perm /0002 -not -path "/tmp*" -not -path "/var/tmp*" -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null || true && \
    find / -xdev -type f -perm /0002 -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null || true

# 3. Remove package managers and build tools for hardened production use
# Note: This makes the image immutable but significantly reduces attack surface
RUN apt-get purge -y --auto-remove \
    apt \
    dpkg \
    && rm -rf /var/lib/dpkg /var/lib/apt /usr/share/dpkg \
    && rm -f /usr/local/bin/install_packages

# 4. Remove unnecessary binaries and tools
RUN rm -rf \
    /usr/bin/perl* \
    /usr/bin/python* \
    /usr/share/perl* \
    /usr/lib/python* \
    /var/cache/debconf/* 2>/dev/null || true

# 5. Minimize attack surface - remove documentation, logs, and caches
RUN rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /usr/share/locale/* \
    /var/cache/debconf/* \
    /var/log/* \
    /usr/share/common-licenses/* \
    /usr/share/lintian/* \
    /usr/share/bug/* 2>/dev/null || true && \
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

# 6. Secure file permissions
RUN chmod 755 /usr/bin/* /usr/sbin/* /bin/* /sbin/* 2>/dev/null || true && \
    chmod 700 /root 2>/dev/null || true && \
    chmod 1777 /tmp /var/tmp

# 7. Create minimal directory structure for apps
RUN mkdir -p /app/.config /app/.cache && \
    chown -R appuser:appuser /app

# ================================
# RUNTIME CONFIGURATION
# ================================

# Set tini as entrypoint for proper signal handling (PID 1 zombie reaping)
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/bin/bash"]

# Switch to non-root user by default (hardened: cannot install packages)
USER appuser
WORKDIR /app

# ================================
# SECURITY NOTES FOR USERS:
# ================================
# 1. Package managers removed - derive images must install deps in builder stage
# 2. Compatible with --read-only and --cap-drop=ALL flags
# 3. Use multi-stage builds for applications requiring additional packages
# 4. Temporary files should use /tmp with proper permissions
# ================================
