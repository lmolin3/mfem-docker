# =============================================================================
# cpu-tpls-vscode — CPU TPLs image with VS Code Server (code-server) + GLVis
# =============================================================================
# Extends cpu-tpls:latest with a browser-accessible VS Code server and
# GLVis JS for in-browser visualization of MFEM simulations.
#
# Build (via Bake — preferred):
#   docker buildx bake --file ../docker-bake.hcl cpu-tpls-vscode
#
# Build (manual):
#   docker build -t ghcr.io/lmolin3/mfem-docker/cpu-tpls:vscode .
#
# Run:
#   docker run --cap-add=SYS_PTRACE --rm -it \
#     -p 8080:8080 -p 8000:8000 -p 3000:3000 \
#     -v mfem:/home/euler/mfem \
#     ghcr.io/lmolin3/mfem-docker/cpu-tpls:vscode
#
#   VS Code : http://localhost:8080  (password: mfem)
#   GLVis   : http://localhost:8000
# =============================================================================
ARG CPU_TPLS_IMAGE=ghcr.io/lmolin3/mfem-docker/cpu-tpls:latest
FROM ${CPU_TPLS_IMAGE}

ARG CODE_SERVER_VERSION=4.100.0

USER root

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor \
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

# ── Log files for supervisord ─────────────────────────────────────────────────
RUN touch /var/log/code-server.log \
          /var/log/glvis-js-webserver.log \
          /var/log/glvis-browser-server.log && \
    chown euler:euler /var/log/code-server.log \
                      /var/log/glvis-js-webserver.log \
                      /var/log/glvis-browser-server.log

# ── GLVis JS dependencies and clone (as euler) ────────────────────────────────
USER euler
WORKDIR /home/euler

RUN curl -L https://github.com/aaugustin/websockets/archive/refs/tags/10.3.tar.gz \
        -o websockets-10.3.tar.gz && \
    tar xzf websockets-10.3.tar.gz && \
    cd websockets-10.3 && \
    pip install --user . && \
    cd .. && rm -rf websockets-10.3 websockets-10.3.tar.gz

RUN git lfs install && \
    git clone --depth=1 https://github.com/GLVis/glvis-js.git

# ── supervisord configuration ─────────────────────────────────────────────────
USER root
ADD supervisord.conf /etc/supervisord.conf

EXPOSE 8080 8000 3000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
