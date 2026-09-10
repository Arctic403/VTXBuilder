# VTXBuilder

Public build-worker infrastructure for VTX/Vortex projects.

## Vortex3D local-controller model

Vortex3D is private. VTXBuilder is public and owns the GitHub Actions runner used for verification, Android builds, and benchmarks.

Vortex3D itself intentionally has **zero GitHub Actions workflows**. Pushing Vortex3D source does not start a build. The supported controller is the local/browser `Arctic403/Editor` workspace:

```text
Editor local workspace
  |
  | one private Vortex3D source commit
  v
Vortex3D (private source only, zero Actions)
  |
  | Editor workflow_dispatches exact source SHA + client id
  v
VTXBuilder (public Actions run)
  checkout exact private SHA
  repository policy + portability checks
  GCC + Clang CTest
  ASan/UBSan + clang-tidy
  VSS smoke evidence
  Android ARM32 + ARM64 native builds
  split + universal debug APKs
  APK verification
  performance smoke
  verification bundle
  |
  | private prerelease tagged with source SHA + client id
  v
Vortex3D (private prereleases)
  |
  | Editor resolves the matching result
  v
Local device
```

The worker is **manual/local-controller triggered only**. There is no Vortex3D `repository_dispatch` workflow and no watcher.

VTXBuilder intentionally uses **no `actions/upload-artifact`** for private Vortex3D worker builds. Successful APKs, verification data, benchmark outputs, and captured detailed build logs are returned only to the private Vortex3D repository. Public workflow logs remain public, so private build output is redirected where practical and detailed diagnostics are returned through private prereleases.

### Required credentials

`Arctic403/VTXBuilder` needs one repository secret:

- `VORTEX_PRIVATE_TOKEN` — fine-grained token restricted to `Arctic403/Vortex3d`, with repository Contents read/write. It reads the exact private source commit and creates private prereleases/assets back in Vortex3D.

The local Editor token needs:

- `Arctic403/Vortex3d`: Contents read/write, so the Editor can push the current local source snapshot and read the private returned release/assets.
- `Arctic403/VTXBuilder`: Actions read/write, so the Editor can dispatch `.github/workflows/vortex3d-worker.yml`.

Vortex3D does not need a dispatch token because it never dispatches or runs an Action.

### Worker workflow

`.github/workflows/vortex3d-worker.yml` supports only `workflow_dispatch` and accepts:

- `source_ref` — exact private Vortex3D branch/tag/SHA to resolve and build.
- `client_id` — optional Editor/local correlation id copied into private success/failure release notes.
- `mode` — `full` or `benchmark`.
- `scale` — benchmark scale when relevant.
- `publish` — return outputs to private Vortex3D releases.

`full` mode performs the complete Vortex3D verification/APK pipeline. CTest is the canonical native correctness gate. VTXBuilder adds independent compiler, sanitizer, static-analysis, Android ABI, APK, VSS, benchmark, diagnostics, and provenance checks without depending on a second Vortex3D validation registry.

VTXBuilder contains build orchestration only. Vortex3D product source is checked out ephemerally onto GitHub-hosted workers and is never committed or uploaded as a public VTXBuilder artifact.
