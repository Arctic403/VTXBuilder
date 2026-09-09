# VTXBuilder

Public reusable GitHub Actions workflows for VTX/Vortex projects.

VTXBuilder contains build orchestration only. Product source, assets, shaders, project files, validation data, and build artifacts remain in the calling repository.

## Vortex3D

Private/public Vortex3D repositories can call the full verification pipeline with a tiny workflow:

```yaml
name: Core CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  verify:
    uses: Arctic403/VTXBuilder/.github/workflows/vortex3d-ci.yml@main
```

Manual benchmarks:

```yaml
jobs:
  benchmark:
    uses: Arctic403/VTXBuilder/.github/workflows/vortex3d-benchmarks.yml@main
    with:
      scale: ${{ inputs.scale }}
```

Repository cleanup:

```yaml
permissions:
  contents: write

jobs:
  cleanup:
    uses: Arctic403/VTXBuilder/.github/workflows/repo-cleanup.yml@main
    with:
      paths: |
        build-p0
        android/app/.cxx
```

## Security model

Reusable workflows execute in the caller repository context. `actions/checkout` therefore checks out the caller's source tree, and uploaded artifacts belong to the caller's workflow run. VTXBuilder does not clone, mirror, upload, or publish the caller repository.

No workflow in this repository requests arbitrary repository secrets. The caller controls the `GITHUB_TOKEN` permission ceiling. Vortex3D's normal verification caller uses read-only contents access; only the cleanup caller requests `contents: write` because it may remove accidentally tracked generated files.

For repositories not controlled by Arctic403, pin VTXBuilder to a full commit SHA instead of `@main`.

## Workflows

- `vortex3d-ci.yml` — repository policy, portability, JNI validation closure, GCC/Clang, ASan/UBSan, clang-tidy, VSS, Android ARM32/ARM64 native shell, debug APKs, benchmark smoke, verification diagnostics bundle, final gate.
- `vortex3d-benchmarks.yml` — manual scaled performance benchmarks and artifacts.
- `repo-cleanup.yml` — reusable removal of accidentally tracked generated build trees.

VTXBuilder is intentionally public so build logic can be audited while product source can remain private.
