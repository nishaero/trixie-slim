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
# CREATE NON-ROOT USER & GROUPS
# ================================
RUN groupadd -r -g 1001 appuser && \
    useradd -r -u 1001 -g appuser -m -d /home/appuser -s /bin/bash appuser && \
    mkdir -p /home/appuser && \
    chown -R appuser:appuser /home/appuser

# ================================
# INSTALL_PACKAGES UTILITY
# ================================
# Secure package installation utility inspired by Bitnami
COPY --chmod=755 <<'EOF' /usr/local/bin/install_packages
#!/bin/bash
set -eo pipefail

# Security: Only allow execution via sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: install_packages must be run via sudo"
    exit 1
fi

# Validate arguments
if [ $# -eq 0 ]; then
    echo "Usage: sudo install_packages <package1> [package2 ...]"
    exit 1
fi

# Install packages securely
apt-get update
apt-get install -y --no-install-recommends "$@"
rm -rf /var/lib/apt/lists/*
EOF

# ================================
# SECURE SUDO CONFIGURATION
# ================================
# 1. Disable password requirement for install_packages only
RUN echo 'appuser ALL=(root) NOPASSWD: /usr/local/bin/install_packages' > /etc/sudoers.d/install_packages && \
    chmod 0440 /etc/sudoers.d/install_packages && \
    visudo -c

# ================================
# SECURITY HARDENING
# ================================
# 1. Remove setuid/setgid bits except essential ones
RUN find / -xdev -type f \( -perm -4000 -o -perm -2000 \) \
    ! -path "/usr/bin/sudo" \
    ! -path "/usr/bin/su" \
    ! -path "/usr/lib/dbus-1.0/dbus-daemon-launch-helper" \
    ! -path "/bin/mount" \
    ! -path "/bin/umount" \
    ! -path "/usr/bin/newgrp" \
    ! -path "/usr/bin/chsh" \
    ! -path "/usr/bin/chfn" \
    ! -path "/usr/bin/passwd" \
    ! -path "/usr/bin/gpasswd" \
    -exec chmod -s {} \; 2>/dev/null

# 2. Remove world-writable files and directories (except /tmp, /var/tmp)
RUN find / -xdev -type d -perm /0002 -not -path "/tmp*" -not -path "/var/tmp*" -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null; \
    find / -xdev -type f -perm /0002 -not -path "/proc*" -not -path "/sys*" -exec chmod o-w {} \; 2>/dev/null

# 3. Minimize attack surface - remove documentation, logs, and caches
RUN rm -rf \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /var/cache/debconf/* \
    /var/log/* \
    /usr/share/common-licenses/* \
    /usr/share/lintian/* \
    /usr/share/bug/* 2>/dev/null; \
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null

# 4. Secure file permissions
RUN chmod 755 /usr/bin/* /usr/sbin/* /bin/* /sbin/* 2>/dev/null; \
    chmod 700 /root 2>/dev/null; \
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

# Test commit to trigger pipeline
# Now with .hadolint.yaml to ignore DL3008
