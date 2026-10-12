# Publishing to npm

This package is **configuration-only**: no `scripts`, no dependencies, no build
step. That is deliberate — it is why the plugin manager has nothing to build and
why the "pnpm refuses to run git-dependency prepare scripts / add `allowBuilds`"
warning does not apply to it. Publishing to npm removes that warning entirely,
because the install no longer comes from git source.

## What gets published

`package.json` uses a `files` allowlist (README, LICENSE and `package.json` are
always included):

| Path | Why |
|---|---|
| `cordis.patch.yml` | The bundle patch that declares the **Apple Mode** preset (DSH 0.2+) |
| `presets/apple/` | The on-disk preset for DSH 0.1.x |
| `bin/mcpbridge` | Runtime-selectable mcpbridge launcher (`install.sh --runtime-selectable`) |
| `docs/` | Integration notes and the global-MCP guide |
| `install.sh`, `uninstall.sh` | Skills generation / preset install helpers |
| `README.md`, `README.zh.md`, `LICENSE` | Included automatically |

Check exactly what would ship before publishing:

```sh
npm pack --dry-run
```

## Publish

```sh
# 1. Publish from the tagged commit so the tarball matches a git tag
git fetch --tags
git checkout v1.1.1

# 2. One-time login (account must own the `dsh-apple-mode` name)
npm login

# 3. Publish (unscoped name → public access)
npm publish --access public
```

npm rejects re-publishing an existing version, so bump `version` in
`package.json`, commit, tag (`vX.Y.Z`) and push the tag before each release:

```sh
npm version patch --no-git-tag-version   # or edit package.json by hand
git commit -am "Release vX.Y.Z"
git tag vX.Y.Z && git push origin vX.Y.Z
```

## Verify

```sh
npm view dsh-apple-mode version dist.tarball
npm view dsh-apple-mode dsh          # the bundle manifest must be present
```

## How users install from npm afterwards

```sh
dsh plugin --profile web add dsh-apple-mode
```

The plugin manager then installs a tarball instead of git source: no
`allowBuilds` prompt, faster installs, and the version is pinned by the registry
rather than by a `#tag` suffix.

## Optional: publish from CI

A tag-triggered workflow can run `npm publish` with an `NPM_TOKEN` repository
secret (`npm publish --provenance --access public`). Not set up here: it needs a
granular npm access token and a repository secret, so it stays a manual step
until you want it.
