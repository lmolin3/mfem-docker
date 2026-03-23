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

    
# ── Pre-configure CMake ───────────────────────────────────────────────────────
USER root 

# Create the directory and the file while we are still root to ensure paths exist
RUN mkdir -p /home/euler/cmake-config

# Copy your local file into the image
# (Ensure user-parallel.cmake is in the same directory as your Dockerfile)
COPY user-parallel.cmake /home/euler/cmake-config/user-parallel.cmake

# Fix permissions so the euler user can read/write to it
RUN chown -R euler:euler /home/euler/cmake-config


# ── Setup Tutorial Source and Build ──────────────────────────────────────────
USER euler
WORKDIR /home/euler

# Clone and checkout specific branch
RUN git clone https://github.com/lmolin3/Cardiac-Ablation-ECM2.git /home/euler/source && \
    cd /home/euler/source && \
    git checkout mfem-tutorial-emory

# Create build directory
RUN mkdir -p /home/euler/build

# Configure with your custom CMake file
WORKDIR /home/euler/build
RUN cmake ../source -DUSER_CONFIG=../cmake-config/user-parallel.cmake

# Compile examples (using 20 cores as requested)
# Note: Ensure the build machine has enough RAM for -j 20!
RUN cd examples && make -j 20


EXPOSE 8080

ENTRYPOINT ["code-server", "--config", "/home/euler/.config/code-server/config.yaml"]
CMD ["."]
