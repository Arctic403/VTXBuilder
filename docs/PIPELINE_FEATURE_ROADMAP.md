# Vortex3D Pipeline Feature Roadmap

## Pipeline Status

Current pipeline flow:

```text
Editor
  -> manual build trigger
  -> VTXBuilder Android build worker
  -> exact-SHA build
  -> private Vortex3D prerelease
```

## Current Worker Responsibilities

- End-to-end private build worker
- Manual build triggering only
- Exact source revision resolution
- Fast repository hygiene and portability checks
- One Gradle/CMake Android build path
- ARM32 output through the Vortex3D Android configuration
- ARM64 output through the Vortex3D Android configuration
- Split and universal APK generation
- APK verification
- Provenance generation
- Private prerelease artifact return

## Validation Ownership

VTXBuilder is **not** a second validation framework.

Detailed engine, subsystem, renderer, JNI, Android runtime, and UI validation/diagnostics belong to Vortex3D. The normal VTXBuilder build must not repeat those suites through separate compiler matrices or duplicate native rebuilds.

Removed from the normal build path:

- duplicate GCC + Clang CTest builds
- ASan/UBSan rebuild
- clang-tidy rebuild
- VSS rebuild
- explicit duplicate ARM32 native build
- explicit duplicate ARM64 native build
- performance smoke build
- verification-input bundle assembly

Benchmark mode remains separate and opt-in because benchmarks answer a different question from artifact generation.

## Future Improvements

### Build Performance

- Improve Gradle and native build cache hit rate
- Avoid reinstalling stable worker dependencies when already available
- Track the duration of the single Android build path
- Keep normal build work limited to tasks required to produce and verify installable APKs

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

## Repository Alignment

### Editor

- Initiates explicit build requests.
- Resolves returned artifacts by exact source SHA/client correlation.

### VTXBuilder

- Owns build orchestration, APK verification, provenance, and artifact return.
- Does not own Vortex3D subsystem validation logic.

### Vortex3D

- Owns product code and all detailed system/subsystem/UI validation and diagnostics.
- Exposes the Android build configuration consumed by VTXBuilder.
- Owns no GitHub Actions workflows.

All three repositories should stay aligned with this contract.
