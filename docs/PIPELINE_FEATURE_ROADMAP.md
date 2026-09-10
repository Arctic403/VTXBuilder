# Vortex3D Pipeline Feature Roadmap

## Pipeline Status

Current pipeline flow:

```text
Editor
  -> manual build trigger
  -> VTXBuilder private build worker
  -> exact-SHA verification/build
  -> private Vortex3D prerelease
```

## Current Coverage

- End-to-end private build worker
- Manual build triggering only
- Exact source revision resolution
- Repository hygiene and portability checks
- GCC and Clang CTest runs
- ASan/UBSan coverage
- clang-tidy static analysis
- VSS smoke evidence
- ARM32 native Android build
- ARM64 native Android build
- Split and universal APK generation
- APK verification
- Performance smoke benchmarks
- Diagnostics/provenance generation
- Private prerelease artifact return

## Future Improvements

### Build Performance

- Improve cache hit rate for Gradle and reusable dependencies
- Avoid reinstalling stable worker dependencies where the hosted runner already provides them
- Measure stage timings and remove redundant work that does not catch a distinct failure class
- Keep cold-build time visible as a tracked pipeline metric

### Release Pipeline

- Add signed release builds when distribution requires them
- Add explicit release channels
- Add version automation
- Improve release artifact management

### Editor Integration

- Live build status display
- Build history viewer
- Artifact status reporting
- Failure diagnostics viewer

### Verification Rule

VTXBuilder owns heavy verification. Vortex3D should expose stable source, CMake/CTest, Android build entry points, and only lightweight maintained source checks.

Do not add a second feature registry, validation orchestrator, or documentation-driven gate. Add a new verification stage only when it catches a distinct regression class that existing tests/builds cannot cover.

## Repository Alignment

### Editor

- Initiates explicit build requests.
- Resolves returned artifacts by exact source SHA/client correlation.

### VTXBuilder

- Source of truth for build orchestration and heavy verification.
- Owns worker execution, diagnostics, provenance, and artifact return.

### Vortex3D

- Source project consumed by the build pipeline.
- Owns product code, canonical CTest coverage, and lightweight source hygiene/portability checks.
- Owns no GitHub Actions workflows.

All three repositories should stay aligned with this contract.
