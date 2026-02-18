# =============================================================================
# gpu-tpls — GPU third-party libraries
# =============================================================================
# Builds all scientific computing TPLs with CUDA support on top of cuda-base.
# A single Dockerfile is parameterized by cuda_arch_sm; Docker Bake calls it
# once per target architecture (sm_90, sm_100, sm_120).
#
# cuda_arch_sm is the raw SM number (e.g. "90"), NOT the "sm_90" prefix.
# It is passed directly to:
#   HYPRE  --with-gpu-arch=${cuda_arch_sm}
#   SUNDIALS  -DCMAKE_CUDA_ARCHITECTURES=${cuda_arch_sm}
#
# Libraries included:
#   HYPRE (CUDA) · SuperLU_DIST · HDF5 · GSLIB · SUNDIALS (CUDA) · NetCDF · Valgrind
#
# Build (via Bake — preferred):
#   docker buildx bake --file ../docker-bake.hcl gpu-tpls-sm90
#   docker buildx bake --file ../docker-bake.hcl gpu        # all arches
#
# Build (manual):
#   docker build -t ghcr.io/lmolin3/mfem-docker/gpu-tpls:sm90 \
#                --shm-size=2gb \
#                --build-arg cuda_arch_sm=90 \
#                --build-arg num_jobs=40 .
# =============================================================================

ARG CUDA_BASE_IMAGE=ghcr.io/lmolin3/mfem-docker/cuda-base:13.0
FROM ${CUDA_BASE_IMAGE}

ARG num_jobs=8
ARG cuda_arch_sm=90
ARG hypre_version=2.31.0
ARG superlu_version=8.2.1
ARG gslib_version=1.0.9
ARG sundials_version=6.6.1
ARG hdf5_version=1.14.5
ARG netcdf_version=4.9.2
ARG valgrind_version=3.22.0

USER root
WORKDIR /opt/archives

# ── HYPRE (with CUDA support) ─────────────────────────────────────────────────
# --with-gpu-arch takes the raw SM number (e.g. 90), not the "sm_" prefix.
RUN curl -fsSL https://github.com/hypre-space/hypre/archive/refs/tags/v${hypre_version}.tar.gz \
        -o hypre.tar.gz && \
    tar xzf hypre.tar.gz && rm hypre.tar.gz && \
    cd hypre-${hypre_version}/src && \
    ./configure \
        --prefix=/opt/hypre-${hypre_version} \
        --enable-shared \
        --disable-static \
        --with-cuda \
        --with-gpu-arch=${cuda_arch_sm} \
        --with-cuda-home=/usr/local/cuda \
        CC=clang CXX=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf hypre-${hypre_version}

# ── SuperLU_DIST (CPU; called by HYPRE/SUNDIALS for sparse factorization) ─────
RUN curl -fsSL https://codeload.github.com/xiaoyeli/superlu_dist/tar.gz/refs/tags/v${superlu_version} \
        -o superlu.tar.gz && \
    tar xzf superlu.tar.gz && rm superlu.tar.gz && \
    cd superlu_dist-${superlu_version} && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DTPL_BLAS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libblas.so.3 \
        -DTPL_ENABLE_METISLIB=ON \
        -DTPL_METIS_INCLUDE_DIRS=/usr/include \
        -DTPL_METIS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libmetis.so \
        -DTPL_PARMETIS_INCLUDE_DIRS=/usr/include \
        -DTPL_PARMETIS_LIBRARIES=/usr/lib/libparmetis.so && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf superlu_dist-${superlu_version}

# ── HDF5 (parallel) ───────────────────────────────────────────────────────────
RUN curl -fsSL https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_${hdf5_version}.tar.gz \
        -o hdf5.tar.gz && \
    tar xzf hdf5.tar.gz && rm hdf5.tar.gz && \
    cd hdf5-hdf5_${hdf5_version} && \
    CC=mpicc CXX=mpicxx ./configure \
        --enable-parallel \
        --enable-shared \
        --with-zlib \
        --prefix=/usr/local && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf hdf5-hdf5_${hdf5_version}

# ── GSLIB ─────────────────────────────────────────────────────────────────────
# Built in-place; cmake config reads /opt/archives/gslib-<version>/build/.
# BUG FIX (original gpu/Dockerfile): removed "make install PREFIX=..." and
# the subsequent "ln -s" which failed because the install already created
# the target path. cmake configs point to the build/ directory, not a prefix.
RUN curl -fsSL https://github.com/gslib/gslib/archive/v${gslib_version}.tar.gz \
        -o gslib.tar.gz && \
    tar xf gslib.tar.gz && rm gslib.tar.gz && \
    cd gslib-${gslib_version} && \
    make -j ${num_jobs} CC=mpicc MPI=1
# Retained: /opt/archives/gslib-${gslib_version}/build/

# ── SUNDIALS (with CUDA support) ──────────────────────────────────────────────
# BUG FIX (original gpu/Dockerfile): cmake was run from /opt/archives without
# a build directory, causing in-source build conflicts. Uses explicit build dir.
# CMAKE_CUDA_ARCHITECTURES takes the raw SM integer (e.g. "90").
RUN curl -fsSL https://github.com/LLNL/sundials/releases/download/v${sundials_version}/sundials-${sundials_version}.tar.gz \
        -o sundials.tar.gz && \
    tar xzf sundials.tar.gz && rm sundials.tar.gz && \
    mkdir sundials-build && cd sundials-build && \
    cmake ../sundials-${sundials_version} \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_MPI=ON \
        -DEXAMPLES_INSTALL=OFF \
        -DENABLE_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=${cuda_arch_sm} \
        -DENABLE_HYPRE=ON \
        -DHYPRE_INCLUDE_DIR=/opt/hypre-${hypre_version}/include \
        -DHYPRE_LIBRARY_DIR=/opt/hypre-${hypre_version}/lib \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf sundials-${sundials_version} sundials-build

# ── NetCDF-C ──────────────────────────────────────────────────────────────────
ENV H5DIR=/usr/local
ENV NCDIR=/usr/local
RUN curl -fsSL https://github.com/Unidata/netcdf-c/archive/refs/tags/v${netcdf_version}.tar.gz \
        -o netcdf.tar.gz && \
    tar xzf netcdf.tar.gz && rm netcdf.tar.gz && \
    cd netcdf-c-${netcdf_version} && \
    CC=mpicc \
    CPPFLAGS="-I${H5DIR}/include" \
    LDFLAGS="-L${H5DIR}/lib" \
    ./configure --prefix=${NCDIR} && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf netcdf-c-${netcdf_version}

# ── Valgrind ──────────────────────────────────────────────────────────────────
# Useful for host-side memory analysis. Does not profile CUDA kernels.
# NOTE: ${num_jobs} — original had typo ${njobs}. Fixed.
RUN curl -fsSL https://sourceware.org/pub/valgrind/valgrind-${valgrind_version}.tar.bz2 \
        -o valgrind.tar.bz2 && \
    tar xjf valgrind.tar.bz2 && rm valgrind.tar.bz2 && \
    cd valgrind-${valgrind_version} && \
    ./configure && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf valgrind-${valgrind_version}

# ── Retained paths (referenced by cmake configs) ─────────────────────────────
# /opt/hypre-${hypre_version}/          ← HYPRE_DIR in cmake
# /opt/archives/gslib-${gslib_version}/ ← GSLIB_DIR pointed at build/ subdir

USER euler
WORKDIR /home/euler
ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/bin/bash", "-i"]
