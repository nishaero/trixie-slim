FROM debian:trixie-slim
# ================================
# SECURE & FLEXIBLE PROFILE
# ================================
# Based on Bitnami patterns with security hardening:
# - Minimal base packages only
# - install_packages utility for runtime flexibility
# - Secure sudo configuration for package management
# - Non-root user with controlled privilege escalation
# ================================

# Set OCI-compliant labels for security and compliance
LABEL maintainer="nishaero" \
      org.opencontainers.image.title="trixie-slim" \
      org.opencontainers.image.description="Minimal Debian Trixie base with secure install_packages utility" \
      org.opencontainers.image.source="https://github.com/nishaero/trixie-slim" \
      org.opencontainers.image.vendor="nishaero" \
      org.opencontainers.image.licenses="MIT" \
      security.profile="secure-flexible" \
      security.non-root="true" \
      security.sudo-enabled="install_packages-only"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ================================
# INSTALL BASE DEPENDENCIES
# ================================
# Install only essential base packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tini \
    sudo \
    procps \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ================================
# CREATE NON-ROOT USER
# ================================
RUN groupadd -r appuser --gid=1001 && \
    useradd -r -g appuser --uid=1001 --home-dir=/app --shell=/bin/bash appuser && \
    mkdir -p /app /tmp/.appuser && \
    chown -R appuser:appuser /app /tmp/.appuser && \
    chmod 1777 /tmp

# ================================
# CONFIGURE SECURE SUDO
# ================================
# Configure sudo: Only allow install_packages, no password, no shell access
RUN echo '#!/bin/bash\n\
set -e\n\
set -u\n\
set -o pipefail\n\
\n\
# Security: Must run via sudo as appuser\n\
if [ "$EUID" -ne 0 ]; then\n\
  echo "Error: install_packages must be run with sudo" >&2\n\
  exit 1\n\
fi\n\
\n\
# Update package lists\n\
apt-get update\n\
\n\
# Install packages with security flags\n\
apt-get install -y --no-install-recommends "$@"\n\
\n\
# Comprehensive cleanup\n\
apt-get clean\n\
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*\n\
rm -rf /var/cache/apt/archives/*' > /usr/local/bin/install_packages && \
    chmod 755 /usr/local/bin/install_packages && \
    echo 'appuser ALL=(root) NOPASSWD: /usr/local/bin/install_packages' > /etc/sudoers.d/install_packages && \
    chmod 440 /etc/sudoers.d/install_packages && \
    echo 'Defaults!install_packages !requiretty' >> /etc/sudoers.d/install_packages

# Configure locale support (minimal - only C.UTF-8)
RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ================================
# SECURITY HARDENING
# ================================
# 1. Remove setuid/setgid binaries (except sudo which is needed)
RUN find / -xdev -perm /6000 -type f ! -path /usr/bin/sudo -exec chmod a-s {} \; 2>/dev/null || true

# 2. Remove world-writable files and directories (except /tmp, /var/tmp)
RUN find / -xdev -type d -perm /0002 -not -path "/tmp*" -not -path "/var/tmp*" -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null || true && \
    find / -xdev -type f -perm /0002 -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null || true

# 3. Minimize attack surface - remove documentation, logs, and caches
RUN rm -rf \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /var/cache/debconf/* \
    /var/log/* \
    /usr/share/common-licenses/* \
    /usr/share/lintian/* \
    /usr/share/bug/* 2>/dev/null || true && \
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

# 4. Secure file permissions
RUN chmod 755 /usr/bin/* /usr/sbin/* /bin/* /sbin/* 2>/dev/null || true && \
    chmod 700 /root 2>/dev/null || true && \
    chmod 1777 /tmp /var/tmp

# 5. Create minimal directory structure for apps
RUN mkdir -p /app/.config /app/.cache && \
    chown -R appuser:appuser /app

# ================================
# RUNTIME CONFIGURATION
# ================================
# Set tini as entrypoint for proper signal handling (PID 1 zombie reaping)
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/bin/bash"]

# Switch to non-root user by default
USER appuser
WORKDIR /app

# ================================
# USAGE NOTES:
# ================================
# Non-root user can install packages:
#   sudo install_packages <package-names>
# 
# In derived Dockerfile:
#   USER root
#   RUN install_packages nodejs npm
#   USER appuser
# ================================
