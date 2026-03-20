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
#   docker run --cap-add=SYS_PTRACE --rm -it \
#     -p 8080:8080 \
#     -v mfem:/home/euler/mfem \
#     ghcr.io/lmolin3/mfem-docker/cpu-tpls:vscode
#
#   VS Code : http://localhost:8080  (password: mfem)
# =============================================================================
ARG CPU_TPLS_IMAGE=ghcr.io/lmolin3/mfem-docker/cpu-tpls:latest
FROM ${CPU_TPLS_IMAGE}

ARG CODE_SERVER_VERSION=4.100.0

USER root

# ── Fix HOME for euler user ───────────────────────────────────────────────────
RUN usermod -d /home/euler euler && \
    mkdir -p /home/euler && \
    chown euler:euler /home/euler

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        libarchive-tools \
    && rm -rf /var/lib/apt/lists/*

# ── Install code-server ───────────────────────────────────────────────────────
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb" \
        -o /tmp/code-server.deb && \
    dpkg -i /tmp/code-server.deb && \
    rm /tmp/code-server.deb

# ── code-server configuration ─────────────────────────────────────────────────
RUN mkdir -p /home/euler/.config/code-server && \
    cat > /home/euler/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: mfem
cert: false
EOF
RUN chown -R euler:euler /home/euler/.config

# ── Install clangd extension ──────────────────────────────────────────────────
USER euler
ENV HOME=/home/euler
WORKDIR /home/euler

RUN mkdir -p ${HOME}/.local/share/code-server/extensions && \
    cd ${HOME}/.local/share/code-server/extensions && \
    curl -L https://openvsxorg.blob.core.windows.net/resources/llvm-vs-code-extensions/vscode-clangd/0.1.21/llvm-vs-code-extensions.vscode-clangd-0.1.21.vsix > clangd.vsix && \
    bsdtar -xvf clangd.vsix extension && \
    mv extension llvm-vs-code-extensions.vscode-clangd-0.1.21 && \
    rm clangd.vsix

EXPOSE 8080

ENTRYPOINT ["code-server", "--config", "/home/euler/.config/code-server/config.yaml"]
CMD ["."]