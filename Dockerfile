FROM n8nio/n8n:latest

USER root

# Alpine packages
RUN apk add --no-cache git curl ca-certificates libc6-compat tzdata && update-ca-certificates

# Install uv (which provides `uv` and `uvx`)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# COPY (not symlink) the binaries to a world-executable location
# and ensure correct perms so the non-root `node` user can run them.
RUN install -m 0755 /root/.local/bin/uv  /usr/local/bin/uv  && \
    install -m 0755 /root/.local/bin/uvx /usr/local/bin/uvx

# Optional: prove they run *during build*
RUN /usr/local/bin/uvx --version && git --version

USER node
