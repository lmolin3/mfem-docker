# =============================================================================
# cpu-tpls — CPU third-party libraries (production / optimized)
# =============================================================================
# Builds all scientific computing TPLs for CPU-only, optimized use:
#   HYPRE · SuperLU_DIST · GSLIB · SUNDIALS · HDF5 · NetCDF · Enzyme · Valgrind
#
# This image is intended for day-to-day MFEM development and production runs
# on CPU clusters. It retains headers, static libs, and debug tools so that
# MFEM can be configured and recompiled inside the container.
#
# Build (via Bake — preferred):
#   docker buildx bake --file ../docker-bake.hcl cpu-tpls
#
# Build (manual):
#   docker build -t ghcr.io/lmolin3/mfem-docker/cpu-tpls:latest \
#                --shm-size=2gb --build-arg num_jobs=40 .
# =============================================================================

ARG TOOLCHAIN_IMAGE=ghcr.io/lmolin3/mfem-docker/toolchain:latest
FROM ${TOOLCHAIN_IMAGE}

ARG num_jobs=8
ARG hypre_version=2.31.0
ARG superlu_version=8.2.1
ARG gslib_version=1.0.9
ARG sundials_version=6.6.1
ARG hdf5_version=1.14.5
ARG netcdf_version=4.9.2
ARG valgrind_version=3.22.0

USER root
WORKDIR /opt/archives

# ── HYPRE (CPU-only) ──────────────────────────────────────────────────────────
# Installed to /opt/hypre-<version>/ so cmake configs can find include/ + lib/.
RUN curl -fsSL https://github.com/hypre-space/hypre/archive/refs/tags/v${hypre_version}.tar.gz \
        -o hypre.tar.gz && \
    tar xzf hypre.tar.gz && rm hypre.tar.gz && \
    cd hypre-${hypre_version}/src && \
    ./configure \
        --prefix=/opt/hypre-${hypre_version} \
        --enable-shared \
        --disable-static \
        CC=clang CXX=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf hypre-${hypre_version}

# ── SuperLU_DIST ──────────────────────────────────────────────────────────────
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

# ── GSLIB ─────────────────────────────────────────────────────────────────────
# Built in-place; cmake config reads /opt/archives/gslib-<version>/build/.
# Do NOT run "make install" — it conflicts with the cmake-expected build path.
RUN curl -fsSL https://github.com/gslib/gslib/archive/v${gslib_version}.tar.gz \
        -o gslib.tar.gz && \
    tar xf gslib.tar.gz && rm gslib.tar.gz && \
    cd gslib-${gslib_version} && \
    make -j ${num_jobs} CC=mpicc MPI=1
# Retained: /opt/archives/gslib-${gslib_version}/build/

# ── SUNDIALS (CPU-only) ───────────────────────────────────────────────────────
# Uses an explicit build directory to avoid in-source build ambiguity.
RUN curl -fsSL https://github.com/LLNL/sundials/releases/download/v${sundials_version}/sundials-${sundials_version}.tar.gz \
        -o sundials.tar.gz && \
    tar xzf sundials.tar.gz && rm sundials.tar.gz && \
    mkdir sundials-build && cd sundials-build && \
    cmake ../sundials-${sundials_version} \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_MPI=ON \
        -DEXAMPLES_INSTALL=OFF \
        -DENABLE_HYPRE=ON \
        -DHYPRE_INCLUDE_DIR=/opt/hypre-${hypre_version}/include \
        -DHYPRE_LIBRARY_DIR=/opt/hypre-${hypre_version}/lib \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf sundials-${sundials_version} sundials-build

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

# ── Enzyme (AD plugin for LLVM) ───────────────────────────────────────────────
RUN git clone https://github.com/EnzymeAD/Enzyme.git && \
    cd Enzyme/enzyme && \
    mkdir build && cd build && \
    cmake .. \
        -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake \
        -DCMAKE_INSTALL_PREFIX=/usr/local/enzyme \
        -DLLVM_EXTERNAL_LIT=/usr/local/bin/lit \
        -DENZYME_ENABLE_PLUGINS=ON \
        CC=clang CXX=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf Enzyme

# ── Valgrind ──────────────────────────────────────────────────────────────────
# NOTE: ${num_jobs} — the original Dockerfiles had a typo (${njobs}) that
# silently made Valgrind build single-threaded. Fixed here.
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
