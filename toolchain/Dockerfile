# =============================================================================
# toolchain — CLANG 18 + MPI environment
# =============================================================================
# Shared base for all CPU images. Installs the compiler toolchain and all
# apt-level build prerequisites so downstream images never repeat this work.
#
# Build:
#   docker build -t ghcr.io/lmolin3/mfem-docker/toolchain:latest \
#                --build-arg LLVM_VERSION=18 .
#
# Override LLVM version:
#   docker build --build-arg LLVM_VERSION=19 -t ghcr.io/lmolin3/mfem-docker/toolchain:clang19 .
# =============================================================================

FROM ghcr.io/mfem/containers/base:latest

ARG LLVM_VERSION=18

USER root
WORKDIR /opt/archives

# ── System packages ───────────────────────────────────────────────────────────
# Single layer: all apt-level dependencies used by every downstream image.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        build-essential \
        vim \ 
        cmake \
        gcc \
        curl \
        wget \
        git \
        unzip \
        flex \
        libsuitesparse-dev \
        lsb-release \
        software-properties-common \
        gnupg \
        libcurl4-openssl-dev \
        libzstd-dev \
        libopenblas-dev \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

# ── Add user euler with passwordless sudo ──
RUN id -u euler >/dev/null 2>&1 || useradd -m -s /bin/bash euler && \
    echo 'euler ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/euler && \
    chmod 0440 /etc/sudoers.d/euler

# ── CLANG / LLVM ──────────────────────────────────────────────────────────────
RUN curl -sSL https://apt.llvm.org/llvm.sh | bash -s -- ${LLVM_VERSION} && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        clang-${LLVM_VERSION} \
        libclang-${LLVM_VERSION}-dev \
        llvm-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev \
        libomp-dev && \
    # Remove any older LLVM versions that the mfem base may have installed
    apt-get remove -y llvm-14 clang-14 llvm-14-dev 2>/dev/null || true && \
    apt-get autoremove -y && \
    update-alternatives --install /usr/bin/clang   cc  /usr/bin/clang-${LLVM_VERSION}   100 && \
    update-alternatives --install /usr/bin/clang++ c++ /usr/bin/clang++-${LLVM_VERSION} 100 && \
    pip3 install lit && \
    rm -rf /var/lib/apt/lists/*

# ── MPI compiler wrappers ─────────────────────────────────────────────────────
ENV OMPI_CC=clang
ENV OMPI_CXX=clang++
ENV LD_LIBRARY_PATH=/usr/local/lib
# Pre-export CUDA bin path: harmless here, required in cuda-base
ENV PATH="${PATH}:/usr/local/cuda/bin"

USER euler
WORKDIR /home/euler
ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/bin/bash", "-i"]
