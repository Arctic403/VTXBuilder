# Vortex3D Pipeline Feature Roadmap

## Pipeline Status

Current pipeline flow:

```
Editor
  -> Build trigger
  -> VTXBuilder private build worker
  -> Validation and verification
  -> Build artifacts
  -> Vortex3D output
```

## Verified Features

- End-to-end private build worker
- Manual build triggering
- Source revision validation
- Toolchain validation
- Build manifest/provenance validation
- Android artifact generation
- ARM64 build output
- ARM32 build output
- Universal APK output
- Artifact verification
- Diagnostics generation
- VSS validation

## Future Improvements

### Build Performance

- Add GitHub Actions caching
- Cache Gradle dependencies
- Cache Android SDK/NDK components
- Cache reusable build dependencies
- Reduce cold build times

### Release Pipeline

- Add signed release builds
- Add release channels
- Add version automation
- Add release artifact management

### Editor Integration

- Live build status display
- Build history viewer
- Artifact status reporting
- Failure diagnostics viewer

### Verification Improvements

- Expand reproducibility checks
- Improve artifact signing
- Add additional validation stages
- Track build performance metrics

## Repository Alignment Checklist

### Editor

- Responsible for initiating build requests.
- Should remain aligned with the VTXBuilder trigger contract.

### VTXBuilder

- Source of truth for build orchestration.
- Owns validation, worker execution, artifacts, and diagnostics.

### Vortex3D

- Source project consumed by the build pipeline.
- Must expose build inputs expected by VTXBuilder.

All three repositories should be kept aligned with this contract.
