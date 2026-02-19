# MFEM-ECM2 Containers

Docker images for MFEM development at Emory (ECM2 group). Each image provides a complete build environment — compiler toolchain, scientific TPLs, and debug tools — so MFEM can be configured and compiled inside the container without any additional setup.

- **Registry:** `ghcr.io/lmolin3/mfem-docker` (pre-built images under the repo's **Packages** tab)
- **Requires:** Docker Desktop or Docker Engine ≥ 23

---

## Available images

| Image | Use case | Key libraries |
|---|---|---|
| `cpu-tpls:latest` | CPU development | HYPRE · SuperLU · GSLIB · SUNDIALS · HDF5 · NetCDF · Enzyme · Valgrind |
| `cpu-tpls:debug` | Memory debugging | Same + PETSc, debug flags, no AVX-512 |
| `gpu-tpls:sm80` | GPU / A100 | HYPRE+CUDA · SuperLU · GSLIB · SUNDIALS+CUDA · HDF5 · NetCDF · Valgrind |
| `gpu-tpls:sm90` | GPU / H100, H200 | same |
| `gpu-tpls:sm120` | GPU / Blackwell RTX | same |

---

## Building images

All builds use `docker-bake.hcl`. Run from the repo root.

```bash
# CPU
docker buildx bake cpu --load

# GPU — H100/H200 by default
docker buildx bake gpu --load

# Specific GPU architecture
docker buildx bake gpu-tpls-sm80 --load    # A100
docker buildx bake gpu-tpls-sm120 --load   # Blackwell RTX

# All GPU architectures
docker buildx bake gpu-all --load

# Override compile jobs (default: 8)
NUM_JOBS=20 docker buildx bake gpu --load
```

> **Note:** `--load` makes the image available to `docker run` locally. Use `--push` to upload to the registry instead.

---

## Compiling MFEM inside a container

The `cmake_config/` directory has pre-filled cmake presets. Pass one with `-C`:

| Image | cmake config |
|---|---|
| `cpu-tpls:latest` | `cmake_config/user-parallel-cpu.cmake` |
| `cpu-tpls:debug` | `cmake_config/user-debug-valgrind.cmake` |
| `gpu-tpls:sm80` | `cmake_config/user-parallel-gpu-sm80.cmake` |
| `gpu-tpls:sm90` | `cmake_config/user-parallel-gpu-sm90.cmake` |
| `gpu-tpls:sm120` | `cmake_config/user-parallel-gpu-sm120.cmake` |

**CPU:**
```bash
docker run --rm -it \
  -v /path/to/mfem:/home/euler/mfem \
  ghcr.io/lmolin3/mfem-docker/cpu-tpls:latest

# Inside the container:
mkdir mfem/build && cd mfem/build
cmake .. -C /path/to/cmake_config/user-parallel-cpu.cmake
make -j 8
```

**GPU (H100):**
```bash
docker run --rm -it --gpus all \
  -v /path/to/mfem:/home/euler/mfem \
  ghcr.io/lmolin3/mfem-docker/gpu-tpls:sm90

# Inside the container:
mkdir mfem/build && cd mfem/build
cmake .. -C /path/to/cmake_config/user-parallel-gpu-sm90.cmake
make -j 8
```

---

## Library paths

| Path | Contents |
|---|---|
| `/opt/hypre-<version>/` | HYPRE (`include/` + `lib/`) |
| `/opt/archives/gslib-<version>/build/` | GSLIB build output |
| `/usr/local/` | SuperLU · SUNDIALS · HDF5 · NetCDF · PETSc |
| `/usr/local/cuda/` | CUDA toolkit |
| `/usr/local/enzyme/` | Enzyme AD plugin (cpu-tpls only) |
