# VTXBuilder

Public build-worker infrastructure for VTX/Vortex projects.

## Vortex3D local-controller model

Vortex3D is private. VTXBuilder is public and owns the GitHub Actions runner used to build Android artifacts and optional benchmarks.

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
  fast repository hygiene + portability checks
  one Gradle/CMake Android build
  split + universal debug APKs
  APK verification
  provenance
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

VTXBuilder intentionally uses **no `actions/upload-artifact`** for private Vortex3D worker builds. Successful APKs and build metadata are returned only to the private Vortex3D repository. Public workflow logs remain public, so detailed failure logs are captured and returned through private prereleases where practical.

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

`full` mode is intentionally lean. VTXBuilder no longer duplicates Vortex3D's subsystem validation with GCC/Clang matrices, sanitizer rebuilds, clang-tidy rebuilds, VSS rebuilds, explicit duplicate ABI builds, performance smoke passes, or verification bundles. Detailed system/subsystem/UI validation and diagnostics live with Vortex3D itself.

The normal worker path now performs only fast source hygiene/portability checks, one Gradle/CMake Android build using the ABIs configured by Vortex3D, APK verification, and provenance generation. Benchmark mode remains separate and opt-in.

VTXBuilder contains build orchestration only. Vortex3D product source is checked out ephemerally onto GitHub-hosted workers and is never committed or uploaded as a public VTXBuilder artifact.
