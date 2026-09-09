# VTXBuilder

Public build-worker infrastructure for VTX/Vortex projects.

## Vortex3D private-worker model

Vortex3D is private. VTXBuilder is public and owns the actual GitHub Actions runner used for verification, Android builds, and manual benchmarks.

The private Vortex3D repository sends only an exact source commit SHA and build mode to VTXBuilder using `repository_dispatch`. VTXBuilder then checks out that exact private commit with a narrowly scoped repository secret, performs the build on the VTXBuilder runner, and returns completed outputs to the private Vortex3D repository as prerelease assets.

```text
Vortex3D (private)
  push/main
     |
     | repository_dispatch: source SHA only
     v
VTXBuilder (public Actions run)
  checkout exact private SHA
  repository policy + validation closure
  GCC + Clang tests
  ASan/UBSan + clang-tidy
  VSS
  Android ARM32 + ARM64 native shells
  split + universal debug APKs
  performance smoke
  verification bundle
     |
     | private GitHub prerelease
     v
Vortex3D (private releases)
  APKs + hashes + verification bundle
```

VTXBuilder intentionally uses **no `actions/upload-artifact`** for private Vortex3D worker builds. Successful APKs, verification data, benchmark outputs, and captured detailed build logs are returned only to the private repository. Public workflow logs are kept to stage-level output where practical.

### Required repository secrets

`Arctic403/VTXBuilder` needs:

- `VORTEX_PRIVATE_TOKEN` — fine-grained token restricted to `Arctic403/Vortex3d`, with repository Contents read/write. It is used to read the exact private source commit and create prereleases/assets back in Vortex3D.

`Arctic403/Vortex3d` needs:

- `VTXBUILDER_DISPATCH_TOKEN` — fine-grained token restricted to `Arctic403/VTXBuilder`, with repository Contents read/write so the private repo can send `repository_dispatch` events.

Do not use `secrets: inherit` across this boundary.

### Worker workflow

`.github/workflows/vortex3d-worker.yml` supports:

- `repository_dispatch` from private Vortex3D.
- Manual builds for an exact Vortex3D branch/tag/SHA.
- A five-minute backup watcher that builds `main` only when the corresponding private worker prerelease is missing.
- `full` mode for the complete Vortex3D verification/APK pipeline.
- `benchmark` mode for scaled performance runs returned to the private repository.

## Reusable workflows

The older reusable workflows remain available as lower-level building blocks, but the canonical private Vortex3D path is the public worker above:

- `vortex3d-ci.yml`
- `vortex3d-benchmarks.yml`
- `repo-cleanup.yml`

VTXBuilder contains build orchestration only. Vortex3D product source is checked out ephemerally onto GitHub-hosted workers and is never committed or uploaded as a public VTXBuilder artifact.
