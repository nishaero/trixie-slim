# trixie-slim
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://github.com/nishaero/trixie-slim)

Minimal Debian Trixie base image designed for production workloads with security best practices built-in. A lightweight, secure, and MIT-licensed alternative to minideb with Bitnami compatibility.

## Table of Contents
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [Building the Image](#building-the-image)
- [Testing](#testing)
- [Configuration](#configuration)
- [Security Features](#security-features)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [LLM One-Shot Setup Prompt](#llm-one-shot-setup-prompt)
- [License](#license)
- [Support](#support)

## Features
✅ **Lightweight** - Based on official `debian:trixie-slim` (~74MB)
✅ **Secure** - Non-root default user, hardened security configuration
✅ **MIT Licensed** - No copyleft restrictions, free for commercial use
✅ **Bitnami Compatible** - Drop-in replacement for minideb
✅ **Production Ready** - Built with enterprise security standards
✅ **Well Documented** - Comprehensive inline comments and documentation
✅ **CI/CD Integrated** - Automated testing, linting, and security scanning
✅ **Multi-arch Support** - Compatible with amd64, arm64 architectures

## Quick Start

### Pull from GitHub Container Registry (once published)

```bash
# Pull the latest image
docker pull ghcr.io/nishaero/trixie-slim:latest

# Run interactively
docker run --rm -it ghcr.io/nishaero/trixie-slim:latest
```

### Build Locally

```bash
# Clone the repository
git clone https://github.com/nishaero/trixie-slim.git
cd trixie-slim

# Build the image
docker build -t trixie-slim:latest .

# Run the container
docker run --rm -it trixie-slim:latest
```

## Installation

### Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Git (for cloning the repository)
- Basic understanding of Docker and containers

### Building from Source

1. **Clone the Repository**

   ```bash
   git clone https://github.com/nishaero/trixie-slim.git
   cd trixie-slim
   ```

2. **Build the Image**

   ```bash
   docker build -t trixie-slim:latest .
   ```

3. **Verify the Build**

   ```bash
   docker images trixie-slim
   docker run --rm trixie-slim:latest uname -a
   ```

## Usage Examples

### Basic Usage

```bash
# Start an interactive shell
docker run --rm -it trixie-slim:latest

# Run a specific command
docker run --rm trixie-slim:latest echo "Hello from trixie-slim"

# Check image details
docker inspect trixie-slim:latest
```

### Running as Root (when needed)

By default, the container runs as the `appuser` (UID 1001). If you need root access:

```bash
docker run --rm -it --user root trixie-slim:latest
```

### Mounting Application Code

```bash
# Mount current directory to /app
docker run --rm -it -v $(pwd):/app trixie-slim:latest

# With specific permissions
docker run --rm -it --user root -v $(pwd):/app trixie-slim:latest
```

### Using as Base Image

Create your own Dockerfile:

```dockerfile
FROM ghcr.io/nishaero/trixie-slim:latest

# Switch to root to install dependencies
USER root

# Install your application dependencies
RUN install_packages \
    python3 \
    python3-pip \
    git

# Copy application code
COPY --chown=appuser:appuser . /app

# Switch back to non-root user
USER appuser

# Set your command
CMD ["python3", "app.py"]
```

### Using the install_packages Utility

The image includes a custom `install_packages` utility for secure package management:

```bash
# Install packages with automatic cleanup
docker run --rm --user root trixie-slim:latest install_packages curl wget vim

# In a Dockerfile
USER root
RUN install_packages nodejs npm
USER appuser
```

## Building the Image

### Standard Build

```bash
docker build -t trixie-slim:latest .
```

### Build with Custom Tags

```bash
# With version tag
docker build -t trixie-slim:1.0.0 -t trixie-slim:latest .

# With platform specification
docker buildx build --platform linux/amd64,linux/arm64 -t trixie-slim:latest .
```

### Build Arguments (if needed)

The Dockerfile doesn't currently use build arguments, but you can extend it:

```dockerfile
ARG DEBIAN_VERSION=trixie-slim
FROM debian:${DEBIAN_VERSION}
```

## Testing

### Manual Testing

```bash
# Test non-root user
docker run --rm trixie-slim:latest id
# Expected: uid=1001(appuser) gid=1001(appuser)

# Test tini init system
docker run --rm trixie-slim:latest ps aux
# Expected: PID 1 should be tini

# Test locale
docker run --rm trixie-slim:latest locale

# Test install_packages utility
docker run --rm --user root trixie-slim:latest install_packages jq
docker run --rm trixie-slim:latest jq --version

# Test HTTPS connectivity
docker run --rm trixie-slim:latest curl -fsSL https://example.com
```

### Automated Testing

The repository includes GitHub Actions CI/CD pipeline that automatically:

- ✅ Lints the Dockerfile with Hadolint
- ✅ Runs security scans with Trivy
- ✅ Tests runtime functionality
- ✅ Validates locale configuration
- ✅ Checks certificate validity
- ✅ Verifies non-root user operation

See `.github/workflows/ci-cd.yml` for details.

## Configuration

### Environment Variables

The image sets the following environment variables:

```bash
DEBIAN_FRONTEND=noninteractive  # Prevents interactive prompts
LANG=C.UTF-8                     # Default locale
LC_ALL=C.UTF-8                   # All locale categories
```

You can override these when running:

```bash
docker run --rm -e LANG=en_US.UTF-8 trixie-slim:latest
```

### User and Permissions

- **Default User**: `appuser` (UID: 1001, GID: 1001)
- **Home Directory**: `/app`
- **Working Directory**: `/app`
- **Shell**: `/sbin/nologin` (for security)

### Exposed Ports

No ports are exposed by default. Add `EXPOSE` directives in your derived Dockerfile as needed.

## Security Features

### Built-in Security Measures

1. **Non-Root Default User**
   - Runs as `appuser` (UID 1001) by default
   - Limits container breakout impact
   - Can be overridden with `--user` flag if needed

2. **Setuid/Setgid Binary Removal**
   - Removes setuid/setgid bits from all binaries
   - Prevents privilege escalation attacks

3. **Minimal Attack Surface**
   - Removes documentation, man pages, and logs
   - Clears package caches and temp files
   - Only essential utilities installed

4. **Tini Init System**
   - Proper PID 1 signal handling
   - Prevents zombie processes
   - Clean shutdown on SIGTERM/SIGINT

5. **Security Scanning**
   - Automated Trivy vulnerability scans
   - Hadolint Dockerfile linting
   - Regular updates via nightly builds

### Security Best Practices

When using this image:

```bash
# Run with read-only root filesystem
docker run --rm --read-only trixie-slim:latest

# Drop all capabilities
docker run --rm --cap-drop=ALL trixie-slim:latest

# Use security options
docker run --rm --security-opt=no-new-privileges trixie-slim:latest

# Limit resources
docker run --rm --memory=512m --cpus=1 trixie-slim:latest
```

## Architecture

### Directory Structure

```
trixie-slim/
├── .github/
│   └── workflows/
│       └── ci-cd.yml         # CI/CD pipeline configuration
├── Dockerfile                # Main image definition
├── LICENSE                   # MIT License
└── README.md                 # This file
```

### Image Layers

The image is built in optimized layers:

1. Base Debian Trixie Slim
2. Metadata labels
3. Environment variables
4. install_packages utility creation
5. Essential package installation
6. Non-root user creation
7. Locale configuration
8. Security hardening
9. Final cleanup
10. Runtime configuration

### Dependencies

**Base Image**: `debian:trixie-slim`

**Installed Packages**:
- `ca-certificates` - SSL/TLS certificate validation
- `curl` - HTTP client for downloads
- `gnupg` - Cryptographic tools
- `procps` - Process utilities (ps, top, etc.)
- `tini` - Init system for containers
- `locales` - Locale data

## Contributing

Contributions are welcome! Please follow these guidelines:

### How to Contribute

1. **Fork the Repository**

   Click the "Fork" button on GitHub

2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**

   - Follow existing code style
   - Add comments for complex sections
   - Update documentation as needed

4. **Test Your Changes**

   ```bash
   docker build -t trixie-slim:test .
   docker run --rm -it trixie-slim:test
   ```

5. **Commit Your Changes**

   ```bash
   git commit -am "Add: Brief description of changes"
   ```

6. **Push to Your Fork**

   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**

   Open a PR on GitHub with a clear description

### Contribution Guidelines

- ✅ Follow Docker best practices
- ✅ Maintain security-first approach
- ✅ Add inline comments for clarity
- ✅ Update README for new features
- ✅ Ensure CI/CD pipeline passes
- ✅ Test on multiple platforms if possible


## LLM One-Shot Setup Prompt

<details>
<summary>⚡️ Automated End-to-End CI/CD & Hardened Image Creation Prompt (for LLMs)</summary>

Copy and paste this prompt into any LLM to recreate a minimal, secure, multi-arch, Bitnami-style base image pipeline with full CI/CD, semantic tags, Docker Hub/GHCR push, signing, and final validation. Only provide your repo name!

**Prompt:**

You're an expert in secure container image pipelines. I want a reproducible, production-ready, minimal Debian Trixie base image project like Bitnami/minideb, but with improved hardening and modern supply chain security. Please do all of the following, with no further interaction:

- **Create Dockerfile:** ... (rest of LLM prompt as given)

</details>

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### What This Means

✅ **Commercial Use** - Use in proprietary software
✅ **Modification** - Change and adapt as needed
✅ **Distribution** - Share with others
✅ **Private Use** - Use privately without restrictions

❌ **No Liability** - Provided "as is" without warranty
❌ **No Trademark Rights** - Name and trademarks not licensed

### Attribution

While not required, attribution is appreciated:

```
Based on trixie-slim by Nishant Ravi
https://github.com/nishaero/trixie-slim
```

## Support

### Getting Help

- **Documentation**: Read this README thoroughly
- **Issues**: [GitHub Issues](https://github.com/nishaero/trixie-slim/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nishaero/trixie-slim/discussions)

### Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Debian Documentation](https://www.debian.org/doc/)
- [Container Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [OCI Image Specification](https://github.com/opencontainers/image-spec)

### Frequently Asked Questions

**Q: Can I use this in production?**
A: Yes! This image is designed with production use in mind, following security best practices.

**Q: How is this different from minideb?**
A: Similar philosophy but based on Debian Trixie, MIT licensed, and includes additional security hardening.

**Q: Why Trixie instead of Stable?**
A: Trixie (testing) provides newer packages while maintaining good stability. For rock-solid stability, you can modify the Dockerfile to use Debian Stable.

**Q: Can I use this commercially?**
A: Yes! The MIT license allows commercial use without restrictions.

**Q: How do I update the image?**
A: Pull the latest version or rebuild from source. Automated nightly builds pull latest security updates.

---

**Maintained by**: [Nishant Ravi](https://github.com/nishaero)

**Star this repo** if you find it useful! ⭐
