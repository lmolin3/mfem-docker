# =============================================================================
# docker-bake.hcl — MFEM-ECM2 Container Build Orchestration
# =============================================================================
#
# Requires: docker buildx (included in Docker Desktop and Docker Engine >= 23)
#
# QUICK START
# -----------
# Build foundation layers first (prerequisite for everything):
#   docker buildx bake bases
#
# Then build CPU or GPU images:
#   docker buildx bake cpu
#   docker buildx bake gpu          # builds sm_90 (Hopper H100/H200) by default
#
# Build everything:
#   docker buildx bake all
#
# Override parallelism or a library version without editing this file:
#   NUM_JOBS=4 docker buildx bake cpu
#   docker buildx bake cpu-tpls --set cpu-tpls.args.hypre_version=2.32.0
#
# Push to registry after building:
#   docker buildx bake bases --push
#
# NOTE: Build order matters for cross-image dependencies.
# Stage 1 (bases) must be pushed to the registry before Stage 2 (cpu/gpu)
# can pull them as FROM base images. See README.md for CI pipeline guidance.
#
# GPU ARCHITECTURE NOTE
# ---------------------
# The `gpu` group builds sm_90 (Hopper H100/H200) only by default to avoid
# exhausting builder resources with parallel CUDA compilations (each arch can take
# 30+ minutes and several GB of RAM). To build a specific architecture, reference
# its named target directly:
#   docker buildx bake gpu-tpls-sm80    # Ampere   A100
#   docker buildx bake gpu-tpls-sm90    # Hopper   H100/H200  (same as `gpu`)
#   docker buildx bake gpu-tpls-sm120   # Blackwell RTX (Pro 6000 / RTX 50xx)
# To build all architectures: docker buildx bake gpu-all
# All three targets are always available regardless of the default group.
# =============================================================================

# ── Registry ──────────────────────────────────────────────────────────────────
variable "REGISTRY" {
  default = "ghcr.io/lmolin3/mfem-docker"
}

# ── Parallelism ───────────────────────────────────────────────────────────────
variable "NUM_JOBS" {
  default = "8"
}

# ── Library versions (single source of truth) ─────────────────────────────────
# Change a version here and it propagates to every affected image automatically.
variable "LLVM_VERSION"    { default = "18" }
variable "CUDA_VERSION"    { default = "13.1.1" }
variable "HYPRE_VERSION"   { default = "2.31.0" }
variable "SUPERLU_VERSION" { default = "8.2.1" }
variable "GSLIB_VERSION"   { default = "1.0.9" }
variable "SUNDIALS_VERSION"{ default = "6.6.1" }
variable "HDF5_VERSION"    { default = "1.14.5" }
variable "NETCDF_VERSION"  { default = "4.9.2" }
variable "VALGRIND_VERSION"{ default = "3.22.0" }
variable "PETSC_VERSION"   { default = "3.21.4" }

# =============================================================================
# STAGE 1 — Foundation images
# These must be built and pushed before any Stage 2 image can be built.
# =============================================================================

# ── toolchain ─────────────────────────────────────────────────────────────────
# CLANG 18 + MPI env on top of ghcr.io/mfem/containers/base:latest.
# All CPU images inherit from this.
target "toolchain" {
  context    = "./toolchain"
  dockerfile = "Dockerfile"
  args = {
    LLVM_VERSION = LLVM_VERSION
  }
  tags = [
    "${REGISTRY}/toolchain:latest",
    "${REGISTRY}/toolchain:clang${LLVM_VERSION}",
  ]
  platforms = ["linux/amd64"]
}

# ── cuda-base ─────────────────────────────────────────────────────────────────
# CUDA 13.x developer toolkit + CLANG 18 + MPI env.
# All GPU images inherit from this. No scientific libraries here.
target "cuda-base" {
  context    = "./cuda-base"
  dockerfile = "Dockerfile"
  args = {
    CUDA_VERSION = CUDA_VERSION
    LLVM_VERSION = LLVM_VERSION
  }
  tags = [
    "${REGISTRY}/cuda-base:${CUDA_VERSION}",
    "${REGISTRY}/cuda-base:latest",
  ]
  platforms = ["linux/amd64"]
}

# =============================================================================
# STAGE 2 — CPU images (require toolchain in registry)
# =============================================================================

# ── cpu-tpls ──────────────────────────────────────────────────────────────────
# Optimised CPU TPLs: HYPRE · SuperLU · GSLIB · SUNDIALS · HDF5 · NetCDF
#                     Enzyme · Valgrind
target "cpu-tpls" {
  context    = "./cpu-tpls"
  dockerfile = "Dockerfile"
  args = {
    TOOLCHAIN_IMAGE  = "${REGISTRY}/toolchain:latest"
    num_jobs         = NUM_JOBS
    hypre_version    = HYPRE_VERSION
    superlu_version  = SUPERLU_VERSION
    gslib_version    = GSLIB_VERSION
    sundials_version = SUNDIALS_VERSION
    hdf5_version     = HDF5_VERSION
    netcdf_version   = NETCDF_VERSION
    valgrind_version = VALGRIND_VERSION
  }
  tags = [
    "${REGISTRY}/cpu-tpls:latest",
  ]
  platforms = ["linux/amd64"]
}

# ── cpu-tpls-debug ────────────────────────────────────────────────────────────
# Debug CPU TPLs (-O0, no AVX-512): HYPRE · SuperLU · PETSc (+ MUMPS/SLEPc)
#                                   GSLIB · SUNDIALS · NetCDF · Valgrind
target "cpu-tpls-debug" {
  context    = "./cpu-tpls-debug"
  dockerfile = "Dockerfile"
  args = {
    TOOLCHAIN_IMAGE  = "${REGISTRY}/toolchain:latest"
    num_jobs         = NUM_JOBS
    hypre_version    = HYPRE_VERSION
    superlu_version  = SUPERLU_VERSION
    petsc_version    = PETSC_VERSION
    gslib_version    = GSLIB_VERSION
    sundials_version = SUNDIALS_VERSION
    netcdf_version   = NETCDF_VERSION
    valgrind_version = VALGRIND_VERSION
  }
  tags = [
    "${REGISTRY}/cpu-tpls:debug",
  ]
  platforms = ["linux/amd64"]
}

# =============================================================================
# STAGE 2 — GPU images (require cuda-base in registry)
# Matrix expands to one named target per CUDA architecture:
#   gpu-tpls-sm80   → sm_80  Ampere   (A100)
#   gpu-tpls-sm90   → sm_90  Hopper   (H100, H200)
#   gpu-tpls-sm120  → sm_120 Blackwell RTX (Pro 6000, RTX 50xx)
# =============================================================================

target "gpu-tpls" {
  name = "gpu-tpls-sm${item.sm}"

  matrix = {
    item = [
      { sm = "80"  },
      { sm = "90"  },
      { sm = "120" },
    ]
  }

  context    = "./gpu-tpls"
  dockerfile = "Dockerfile"
  args = {
    CUDA_BASE_IMAGE  = "${REGISTRY}/cuda-base:${CUDA_VERSION}"
    num_jobs         = NUM_JOBS
    cuda_arch_sm     = item.sm
    hypre_version    = HYPRE_VERSION
    superlu_version  = SUPERLU_VERSION
    gslib_version    = GSLIB_VERSION
    sundials_version = SUNDIALS_VERSION
    hdf5_version     = HDF5_VERSION
    netcdf_version   = NETCDF_VERSION
    valgrind_version = VALGRIND_VERSION
  }
  tags = [
    "${REGISTRY}/gpu-tpls:sm${item.sm}",
  ]
  platforms = ["linux/amd64"]
}

# =============================================================================
# Groups — convenient targets for selective or complete builds
# =============================================================================

# Foundation layers (build and push these first)
group "bases" {
  targets = ["toolchain", "cuda-base"]
}

# All CPU images
group "cpu" {
  targets = ["cpu-tpls", "cpu-tpls-debug"]
}

# Default GPU build — sm_90 (Hopper H100/H200) only.
# Building all architectures in parallel exhausts builder resources.
# To build a specific architecture use its named target:
#   docker buildx bake gpu-tpls-sm80    # Ampere A100
#   docker buildx bake gpu-tpls-sm120   # Blackwell RTX Pro 6000 / RTX 50xx
# To build all architectures:
#   docker buildx bake gpu-all
group "gpu" {
  targets = ["gpu-tpls-sm90"]
}

# All GPU architectures (A100 + H100/H200 + Blackwell RTX)
group "gpu-all" {
  targets = ["gpu-tpls-sm80", "gpu-tpls-sm90", "gpu-tpls-sm120"]
}

# Everything
group "all" {
  targets = ["bases", "cpu", "gpu"]
}
