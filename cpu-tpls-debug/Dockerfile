# =============================================================================
# cpu-tpls-debug — CPU third-party libraries (debug / Valgrind-safe)
# =============================================================================
# Rebuilds all scientific TPLs from scratch with debug-oriented compiler flags:
#   -O0 -g -mno-avx512f
# AVX-512 is disabled to prevent Valgrind from hitting unhandled instruction
# set faults when loading meshes via NetCDF.
#
# Differences from cpu-tpls:
#   - No Enzyme (AD not useful for memory debugging)
#   - PETSc replaces standalone HDF5 (PETSc downloads HDF5 internally)
#   - SUNDIALS links against PETSc
#   - All libraries compiled with -O0 -g -mno-avx512f
#
# Build (via Bake — preferred):
#   docker buildx bake --file ../docker-bake.hcl cpu-tpls-debug
#
# Build (manual):
#   docker build -t ghcr.io/lmolin3/mfem-docker/cpu-tpls:debug \
#                --shm-size=2gb --build-arg num_jobs=40 .
# =============================================================================

ARG TOOLCHAIN_IMAGE=ghcr.io/lmolin3/mfem-docker/toolchain:latest
FROM ${TOOLCHAIN_IMAGE}

ARG num_jobs=8
ARG hypre_version=2.31.0
ARG superlu_version=8.2.1
ARG petsc_version=3.21.4
ARG gslib_version=1.0.9
ARG sundials_version=6.6.1
ARG netcdf_version=4.9.2
ARG valgrind_version=3.22.0

USER root
WORKDIR /opt/archives

# ── HYPRE (CPU-only) ──────────────────────────────────────────────────────────
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

# ── PETSc (debug, downloads MUMPS / SLEPc / ScaLAPACK / HDF5 internally) ─────
# PETSC_ARCH=arch-linux-clang-debug is the canonical name used consistently
# throughout this file — SUNDIALS must reference the same arch string.
RUN git clone -b release --single-branch https://gitlab.com/petsc/petsc.git petsc && \
    cd petsc && git checkout v${petsc_version} && \
    PETSC_DIR=/opt/archives/petsc \
    PETSC_ARCH=arch-linux-clang-debug \
    ./configure \
        --COPTFLAGS="-g -O0 -mno-avx512f" \
        --CXXOPTFLAGS="-g -O0 -mno-avx512f" \
        --FOPTFLAGS="-g -O0 -mno-avx512f" \
        --with-cc=mpicc --with-cxx=mpicxx --with-fc=mpif90 \
        --with-c-support \
        --with-debugging=1 \
        --with-fortran-bindings=0 \
        --with-sowing=0 \
        --with-blaslapack-dir=/usr/lib/x86_64-linux-gnu \
        --with-metis-lib=/usr/lib/x86_64-linux-gnu/libmetis.so \
        --with-metis-include=/usr/include \
        --with-parmetis-lib=/usr/lib/libparmetis.so \
        --with-parmetis-include=/usr/include \
        --with-hypre-dir=/opt/hypre-${hypre_version} \
        --with-superlu_dist-dir=/usr/local \
        --download-mumps \
        --download-slepc \
        --download-scalapack \
        --download-hdf5 \
        --download-hdf5-configure-arguments="--with-zlib=yes" \
        --prefix=/usr/local && \
    make -j ${num_jobs} \
        PETSC_DIR=/opt/archives/petsc \
        PETSC_ARCH=arch-linux-clang-debug all && \
    make PETSC_DIR=/opt/archives/petsc PETSC_ARCH=arch-linux-clang-debug install && \
    cd /opt/archives && rm -rf petsc

# ── GSLIB ─────────────────────────────────────────────────────────────────────
# Built in-place; cmake config reads /opt/archives/gslib-<version>/build/.
RUN curl -fsSL https://github.com/gslib/gslib/archive/v${gslib_version}.tar.gz \
        -o gslib.tar.gz && \
    tar xf gslib.tar.gz && rm gslib.tar.gz && \
    cd gslib-${gslib_version} && \
    make -j ${num_jobs} CC=mpicc MPI=1
# Retained: /opt/archives/gslib-${gslib_version}/build/

# ── SUNDIALS (with PETSc support) ────────────────────────────────────────────
# BUG FIX (original): PETSC_ARCH was "arch-linux-clang-opt" here but
# "arch-linux-clang-debug" in PETSc configure — they must match.
# After a --prefix install, PETSc_ARCH is empty and PETSC_DIR=/usr/local.
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
        -DENABLE_PETSC=ON \
        -DPETSC_DIR=/usr/local \
        -DPETSC_ARCH="" \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ && \
    make -j ${num_jobs} && make install && \
    cd /opt/archives && rm -rf sundials-${sundials_version} sundials-build

# ── NetCDF-C ──────────────────────────────────────────────────────────────────
# HDF5 was installed by PETSc --download-hdf5 into /usr/local
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
