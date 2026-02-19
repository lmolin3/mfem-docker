# =============================================================================
# docker-bake.hcl — MFEM-ECM2 Container Builds
# =============================================================================
# Requires: docker buildx (Docker Desktop or Docker Engine >= 23)
#
# Build CPU images:
#   docker buildx bake cpu
#
# Build GPU images (sm_90 / H100 by default):
#   docker buildx bake gpu                  # H100/H200
#   docker buildx bake gpu-tpls-sm80        # A100
#   docker buildx bake gpu-tpls-sm120       # Blackwell RTX (Pro 6000 / RTX 50xx)
#   docker buildx bake gpu-all              # all architectures
#
# Override number of compile jobs:
#   NUM_JOBS=20 docker buildx bake gpu
# =============================================================================

# ── Registry ──────────────────────────────────────────────────────────────────
variable "REGISTRY" {
  default = "ghcr.io/lmolin3/mfem-docker"
}

# ── Parallelism ───────────────────────────────────────────────────────────────
variable "NUM_JOBS" {
  default = "8"
}

# ── Library versions ──────────────────────────────────────────────────────────
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

# ── Base images ───────────────────────────────────────────────────────────────
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

# ── CPU images ────────────────────────────────────────────────────────────────
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

# ── GPU images (sm80=A100  sm90=H100/H200  sm120=Blackwell RTX) ───────────────
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

# ── Groups ────────────────────────────────────────────────────────────────────
group "bases"   { targets = ["toolchain", "cuda-base"] }
group "cpu"     { targets = ["cpu-tpls", "cpu-tpls-debug"] }
group "gpu"     { targets = ["gpu-tpls-sm90"] }
group "gpu-all" { targets = ["gpu-tpls-sm80", "gpu-tpls-sm90", "gpu-tpls-sm120"] }
group "all"     { targets = ["bases", "cpu", "gpu"] }
