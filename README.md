# MFEM-ECM2 Containers

Custom Docker images for MFEM development at Emory University (ECM2 group). All images provide a complete developer environment — compiler toolchain, scientific TPLs with headers and static libs, and debug tools — so MFEM can be configured and recompiled inside the container without any additional setup.

- **Code repository:** https://github.com/lmolin3/mfem-docker
- **Image registry:** `ghcr.io/lmolin3/mfem-docker`
- Pre-built images are available under the repo's **Packages** tab on GitHub.

For general Docker usage with MFEM, see the [MFEM Docker page](https://mfem.org/tutorial/docker).

---

## Image hierarchy

```
ghcr.io/mfem/containers/base:latest              (upstream MFEM base — not ours)
        │
        ▼
ghcr.io/lmolin3/mfem-docker/toolchain            CLANG 18 + MPI env
        │
   ┌────┴──────────────────────────────────────────────────┐
   ▼                                                        ▼
ghcr.io/lmolin3/mfem-docker/cpu-tpls          ghcr.io/lmolin3/mfem-docker/cuda-base
ghcr.io/lmolin3/mfem-docker/cpu-tpls:debug           │
                                               gpu-tpls:sm90
                                               gpu-tpls:sm100
                                               gpu-tpls:sm120
```

### What each image contains

| Image | Purpose | Key libraries |
|---|---|---|
| `toolchain` | Shared CPU base | CLANG 18, LLVM 18, libomp, MPI env |
| `cuda-base` | Shared GPU base | CUDA 13.x + CLANG 18 + MPI |
| `cpu-tpls:latest` | CPU development | HYPRE · SuperLU · GSLIB · SUNDIALS · HDF5 · NetCDF · Enzyme · Valgrind |
| `cpu-tpls:debug` | Memory debugging | Same minus Enzyme; adds PETSc (debug flags, no AVX-512) |
| `gpu-tpls:sm<N>` | GPU development | HYPRE+CUDA · SuperLU · HDF5 · GSLIB · SUNDIALS+CUDA · NetCDF · Valgrind |

---

## Prerequisites

- Docker Engine ≥ 23 (includes `docker buildx`) **or** Docker Desktop
- For GPU images: NVIDIA Container Toolkit installed on the host

Verify buildx is available:
```bash
docker buildx version
```

---

## Who needs to build what

There are two distinct roles:

**Maintainer** — builds and pushes foundation and TPL images to the registry. This
happens once, or when upgrading a library or CUDA version. Most users never do this.

**User** — builds a single TPL image on top of the already-published foundation
layer. They do not need to touch `toolchain` or `cuda-base`.

---

## Where do built images go?

`docker buildx bake` without any flag only writes to the **local build cache**. The
image is not pushed to the registry and is not visible to `docker images` or
`docker run`. Always append one of:

| Flag | Effect |
|---|---|
| `--push` | Upload to the registry (requires `docker login`) |
| `--load` | Load into the local Docker daemon (`docker run` works immediately) |

```bash
# Load locally for immediate use
docker buildx bake gpu-tpls-sm90 --load

# Push to registry for others to pull
docker buildx bake gpu-tpls-sm90 --push
```

---

## Building images

All builds go through `docker-bake.hcl`. Run commands from this `containers/` directory.

### Maintainer: publish the foundation layers (once)

`toolchain` and `cuda-base` only need to be built and pushed once. After that,
everyone else pulls them automatically. CPU and GPU image builds are fully
independent — building GPU images does not require building any CPU image first.

```bash
docker buildx bake bases --push
```

### User: build a GPU image

If `cuda-base` is already in the registry (the normal case), go straight to:

```bash
# Single architecture, loaded locally
NUM_JOBS=16 docker buildx bake gpu-tpls-sm90 --load

# All three architectures, pushed to registry
NUM_JOBS=16 docker buildx bake gpu --push
```

`cuda-base` is pulled from the registry automatically — you do not need to build it.

### User: build a CPU image

If `toolchain` is already in the registry:

```bash
# Production CPU image, loaded locally
NUM_JOBS=16 docker buildx bake cpu-tpls --load

# Debug CPU image
NUM_JOBS=16 docker buildx bake cpu-tpls-debug --load
```

### Maintainer: build everything and push

```bash
NUM_JOBS=16 docker buildx bake all --push
```

---

## Overriding build parameters

All library versions and the job count are variables at the top of `docker-bake.hcl`. Override any of them from the CLI without editing the file:

```bash
# More parallel compile jobs
NUM_JOBS=40 docker buildx bake cpu-tpls --load

# Upgrade one library for a single build
docker buildx bake cpu-tpls --load \
  --set cpu-tpls.args.hypre_version=2.32.0

# Different CUDA version for all GPU images
CUDA_VERSION=13.1 docker buildx bake gpu --push

# Push to a different registry (e.g. a personal fork or mirror)
REGISTRY=ghcr.io/your-org/containers \
  docker buildx bake all --push
```

---

## Compiling MFEM inside a container

The `cmake_config/` directory contains pre-filled cmake configuration files. Pass one to cmake with `-C`:

| Image | cmake config |
|---|---|
| `cpu-tpls:latest` | `cmake_config/user-parallel-cpu.cmake` |
| `cpu-tpls:debug` | `cmake_config/user-debug-valgrind.cmake` |
| `gpu-tpls:sm90` | `cmake_config/user-parallel-gpu-sm90.cmake` |
| `gpu-tpls:sm100` | `cmake_config/user-parallel-gpu-sm100.cmake` |
| `gpu-tpls:sm120` | `cmake_config/user-parallel-gpu-sm120.cmake` |

**CPU example:**
```bash
docker run --rm -it \
  -v /path/to/mfem:/home/euler/mfem \
  ghcr.io/mfem/containers/cpu-tpls:latest

# Inside the container:
mkdir mfem/build && cd mfem/build
cmake .. -C /path/to/containers/cmake_config/user-parallel-cpu.cmake
make -j 8
```

**GPU example (Hopper / sm_90):**
```bash
docker run --rm -it --gpus all \
  -v /path/to/mfem:/home/euler/mfem \
  ghcr.io/mfem/containers/gpu-tpls:sm90

# Inside the container:
mkdir mfem/build && cd mfem/build
cmake .. -C /path/to/containers/cmake_config/user-parallel-gpu-sm90.cmake
make -j 8
```

---

## Adding a new GPU architecture

### CUDA version compatibility

Not all CUDA versions support all GPU architectures. Before adding a new arch, confirm it is supported by the `CUDA_VERSION` set in `docker-bake.hcl` (currently `13.0`).

| Architecture | GPU examples | Min CUDA | Max CUDA |
|---|---|---|---|
| sm_70 | V100 (Volta) | 9.0 | 12.x (dropped in 13.x) |
| sm_75 | T4, RTX 2080 (Turing) | 10.0 | 13.x |
| sm_80 | A100, RTX 3090 (Ampere) | 11.1 | 13.x |
| sm_86 | RTX 3080/3070, A40 (Ampere) | 11.1 | 13.x |
| sm_89 | RTX 4090, L40 (Ada Lovelace) | 11.8 | 13.x |
| sm_90 | H100, H200 (Hopper) | 12.0 | 13.x |
| sm_100 | B100, B200 (Blackwell) | 12.8 | 13.x |
| sm_120 | Blackwell next-gen | 13.x | 13.x |

If the arch requires a different CUDA version than the current default, override `CUDA_VERSION` in the build command (see step 3 below).

### Steps

**1. Add the arch to the matrix in `docker-bake.hcl`:**
```hcl
target "gpu-tpls" {
  matrix = {
    item = [
      { sm = "90"  },
      { sm = "100" },
      { sm = "120" },
      { sm = "70"  },   # ← add new entry here
    ]
  }
  ...
}
```

**2. Create a cmake config file:**
```bash
# Copy the closest existing config and change the CUDA_ARCH line
cp cmake_config/user-parallel-gpu-sm90.cmake \
   cmake_config/user-parallel-gpu-sm70.cmake
```

Edit the one line in the new file:
```cmake
# cmake_config/user-parallel-gpu-sm70.cmake  (line ~98)
set(CUDA_ARCH "sm_70" CACHE STRING "Target CUDA architecture.")
```

**3. Build the image:**

If the arch is supported by the current CUDA version (see table above):
```bash
docker buildx bake gpu-tpls-sm70
```

If the arch requires a different CUDA version (e.g. sm_70 is not supported by CUDA 13.x):
```bash
# Override CUDA_VERSION for this build only — does not modify docker-bake.hcl
CUDA_VERSION=12.6 docker buildx bake gpu-tpls-sm70
```

If you want the new CUDA version to become the permanent default for this arch,
update the `CUDA_VERSION` variable in `docker-bake.hcl` — but note this affects
all GPU images. For a per-arch CUDA version, override it on the CLI as above.

**4. Push to registry:**
```bash
docker buildx bake gpu-tpls-sm70 --push
```

**5. Use the new cmake config when compiling MFEM:**
```bash
cmake .. -C /path/to/containers/cmake_config/user-parallel-gpu-sm70.cmake
```

---

## Upgrading a library version

1. Edit the version variable in `docker-bake.hcl`, e.g.:
   ```hcl
   variable "HYPRE_VERSION" { default = "2.32.0" }
   ```

2. Update `HYPRE_DIR` in any cmake config that hardcodes the path:
   ```cmake
   set(HYPRE_DIR "/opt/hypre-2.32.0" ...)
   ```

3. Rebuild the affected images:
   ```bash
   docker buildx bake cpu gpu --push
   ```

---

## Upgrading CUDA

CUDA comes from `nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04` on Docker Hub. Before upgrading, confirm the tag exists:
```
https://hub.docker.com/r/nvidia/cuda/tags
```

Then:
```bash
CUDA_VERSION=13.1 docker buildx bake bases gpu --push
```

---

## Directory structure

```
containers/
├── docker-bake.hcl                   Build orchestration (versions, targets, groups)
├── .dockerignore                     Keeps build contexts lean
├── README.md                         This file
│
├── toolchain/
│   └── Dockerfile                    CLANG 18 + MPI — shared CPU base
│
├── cuda-base/
│   └── Dockerfile                    CUDA 13.x + CLANG 18 — shared GPU base
│
├── cpu-tpls/
│   └── Dockerfile                    Optimized CPU TPLs (FROM toolchain)
│
├── cpu-tpls-debug/
│   └── Dockerfile                    Debug CPU TPLs, no AVX-512 (FROM toolchain)
│
├── gpu-tpls/
│   └── Dockerfile                    GPU TPLs, parameterized by cuda_arch_sm
│
└── cmake_config/
    ├── user-parallel-cpu.cmake       CPU Release
    ├── user-parallel-gpu.cmake       GPU Release (default: sm_90)
    ├── user-parallel-gpu-sm90.cmake  GPU Release — Hopper
    ├── user-parallel-gpu-sm100.cmake GPU Release — Blackwell
    ├── user-parallel-gpu-sm120.cmake GPU Release — Blackwell next-gen
    └── user-debug-valgrind.cmake     Debug / Valgrind
```

---

## CI pipeline shape

`docker buildx bake` does not resolve cross-invocation image dependencies automatically. Enforce build order in CI:

```
Stage 1 (parallel):  toolchain  ·  cuda-base         → pushed to registry
Stage 2 (parallel):  cpu-tpls  ·  cpu-tpls-debug     → pulls toolchain
                     gpu-tpls-sm90  ·  sm100  ·  sm120 → pulls cuda-base
```

Gate Stage 2 on Stage 1 completion. Within each stage all jobs are independent and can run in parallel.

---

## Path conventions

Library paths are consistent across images so cmake configs work without modification:

| Path | Contents |
|---|---|
| `/opt/hypre-<version>/` | HYPRE install (`include/` + `lib/`) |
| `/opt/archives/gslib-<version>/build/` | GSLIB build output (not installed) |
| `/usr/local/` | All other TPLs (SuperLU, SUNDIALS, HDF5, NetCDF, PETSc) |
| `/usr/local/cuda/` | CUDA toolkit (`nvcc`, cuBLAS, cuSPARSE) |
| `/usr/local/enzyme/` | Enzyme AD plugin (cpu-tpls only) |

---

## Registry authentication

To push images you need to authenticate with GHCR using a GitHub Personal Access Token (PAT) with `write:packages` scope:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u lmolin3 --password-stdin
```

Images are pushed to `ghcr.io/lmolin3/mfem-docker/<name>:<tag>` and will appear under the **Packages** tab of the GitHub repository at https://github.com/lmolin3/mfem-docker.

> **Note:** In normal workflow, images are built and pushed automatically by GitHub Actions on every merge to `main`. Manual pushes are only needed for local testing or emergency hotfixes. See [Contributing](#contributing) below.

---

## Contributing

### Access model

| Action | Who can do it |
|---|---|
| Pull any image | Anyone (public registry) |
| Push images to GHCR | Only accounts with `write` access to the repo (owner only by default) |
| Push directly to `main` | Blocked — requires a pull request |
| Merge a pull request | Repo owner (lmolin3) |

### Branch protection setup (one-time, done in GitHub)

1. Go to **Settings → Branches → Add branch protection rule**
2. Branch name pattern: `main`
3. Enable:
   - [x] Require a pull request before merging
   - [x] Require approvals (set to 1)
   - [x] Do not allow bypassing the above settings *(uncheck this if you want to be able to force-push yourself)*
4. Click **Save changes**

After this is set, all changes — including your own — must go through a PR.

### Automated image publishing (GitHub Actions)

The workflow at `.github/workflows/publish.yml` handles image builds automatically:

- **On pull request** targeting `main`: images are built but **not pushed** (dry-run to catch build errors early)
- **On merge to `main`**: images are built and **pushed** to `ghcr.io/lmolin3/mfem-docker`

No PAT or manual `docker login` is needed — the workflow uses the built-in `GITHUB_TOKEN` which automatically has `packages: write` permission.

Build order in CI mirrors the local dependency order:
```
Stage 1 (parallel):  toolchain  ·  cuda-base
Stage 2 (parallel):  cpu-tpls  ·  cpu-tpls-debug  ·  gpu-tpls-sm90  ·  sm100  ·  sm120
```

Stage 2 jobs only start after Stage 1 completes (`needs: bases`).

### Submitting changes

```bash
# Fork or create a branch
git checkout -b add-new-arch

# Make your changes (e.g. add sm_89 to docker-bake.hcl)
# ...

# Push and open a PR on GitHub
git push origin add-new-arch
# → open PR at https://github.com/lmolin3/mfem-docker/pulls
```

The PR will trigger a build-only run of the affected images. Once merged, images are pushed automatically.

