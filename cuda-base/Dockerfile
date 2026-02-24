# =============================================================================
# cuda-base — CUDA 13.x + CLANG 18 + MPI environment
# =============================================================================
# GPU-branch equivalent of the cpu toolchain image. Starts from NVIDIA's
# official CUDA developer image so nvcc, cuBLAS, cuSPARSE, and cuRAND dev
# headers are available out of the box — no apt keyring fragility.
#
# This image contains NO scientific libraries. Its only purpose is to provide
# a stable, versioned layer that gpu-tpls builds on top of.
#
# Build:
#   docker build -t ghcr.io/lmolin3/mfem-docker/cuda-base:13.0 \
#                --build-arg CUDA_VERSION=13.0 .
# =============================================================================

ARG CUDA_VERSION=13.1.1
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

ARG LLVM_VERSION=18

USER root
WORKDIR /opt/archives

# ── Create the euler user (absent from the NVIDIA base image) ─────────────────
RUN groupadd -g 1000 euler && \
    useradd  -u 1000 -g euler -m -s /bin/bash euler && \
    echo "euler ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── System packages ───────────────────────────────────────────────────────────
# Two-step: first enable the universe repo (needed for libsuitesparse-dev,
# python3-pip, etc.), then install everything else in one layer.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        lsb-release && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
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
        gnupg \
        libcurl4-openssl-dev \
        libzstd-dev \
        libopenblas-dev \
        python3-pip \
        libopenmpi-dev \
        openmpi-bin \
        gfortran \
        libmetis-dev \
        libparmetis-dev && \
    rm -rf /var/lib/apt/lists/*

# ── CLANG / LLVM ──────────────────────────────────────────────────────────────
RUN curl -sSL https://apt.llvm.org/llvm.sh | bash -s -- ${LLVM_VERSION} && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        clang-${LLVM_VERSION} \
        libclang-${LLVM_VERSION}-dev \
        llvm-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev \
        libomp-dev && \
    apt-get autoremove -y && \
    update-alternatives --install /usr/bin/clang   cc  /usr/bin/clang-${LLVM_VERSION}   100 && \
    update-alternatives --install /usr/bin/clang++ c++ /usr/bin/clang++-${LLVM_VERSION} 100 && \
    pip3 install lit && \
    rm -rf /var/lib/apt/lists/*

# ── Environment ───────────────────────────────────────────────────────────────
ENV OMPI_CC=clang
ENV OMPI_CXX=clang++
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH="${PATH}:/usr/local/cuda/bin"

USER euler
WORKDIR /home/euler
ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/bin/bash", "-i"]
