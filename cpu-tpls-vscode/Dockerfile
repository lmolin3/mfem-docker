# =============================================================================
# cpu-tpls-vscode — CPU TPLs image with VS Code Server (code-server)
# =============================================================================
# Extends cpu-tpls:latest with a browser-accessible VS Code server so
# developers can edit and build MFEM entirely in the browser.
#
# Build (via Bake — preferred):
#   docker buildx bake --file ../docker-bake.hcl cpu-tpls-vscode
#
# Build (manual):
#   docker build -t ghcr.io/lmolin3/mfem-docker/cpu-tpls:vscode .
#
# Run:
#   docker run --rm -it -p 8080:8080 \
#     -v /path/to/mfem:/home/euler/mfem \
#     ghcr.io/lmolin3/mfem-docker/cpu-tpls:vscode
#
#   Then open http://localhost:8080 in your browser.
#   The default password is set via the PASSWORD env var (default: "mfem").
# =============================================================================

ARG CPU_TPLS_IMAGE=ghcr.io/lmolin3/mfem-docker/cpu-tpls:latest
FROM ${CPU_TPLS_IMAGE}

ARG CODE_SERVER_VERSION=4.100.0

USER root

# ── Install code-server ───────────────────────────────────────────────────────
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb" \
        -o /tmp/code-server.deb && \
    dpkg -i /tmp/code-server.deb && \
    rm /tmp/code-server.deb

# ── Default configuration ─────────────────────────────────────────────────────
# Bind on all interfaces so the port can be mapped by docker run -p.
RUN mkdir -p /home/euler/.config/code-server && \
    cat > /home/euler/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: mfem
cert: false
EOF

RUN chown -R euler:euler /home/euler/.config

USER euler
WORKDIR /home/euler

EXPOSE 8080

ENTRYPOINT ["code-server", "--config", "/home/euler/.config/code-server/config.yaml"]
CMD ["."]
