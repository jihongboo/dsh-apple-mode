# dsh-apple-mode

[English](README.md) · [简体中文](README.zh.md)

**Xcode AI integration mode for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`)** — an agent preset + installer that gives your DSH sessions the full Xcode AI stack:

- **26 Xcode MCP tools** (`mcp__xcode__*`) via Apple's official `mcpbridge`
- **Xcode Intelligence–style persona** (Swift-first, tool-assisted, explain-vs-change classification) adapted from the `IDEIntelligenceChat` prompt templates
- **10 Apple platform skills** (SwiftUI, App Intents, security hardening, bounds safety, …) generated locally from your own Xcode

> 📌 `dsh-plugin` topic repo. DeepSeek Harness is in developer preview — pin an exact `dsh` version for your automation.

## Why a preset (mode) instead of a global MCP wiring?

The three capabilities map onto three different DSH mechanisms:

| Layer | Capability | DSH mechanism |
|---|---|---|
| Execute | 26 `mcp__xcode__*` tools | `dsh-mcp-client` (mounted inside the preset) |
| Knowledge | 10 Apple skills | `dsh-skill-filesystem` (global, lazy-loaded) |
| Behavior | Xcode Intelligence persona | agent preset (this repo) |

Wiring the MCP server **globally** would put ~26 large tool schemas (~6k+ tokens/request) into *every* session. Mounting it inside a **preset** keeps the cost only in sessions that opt in — pick **Apple Mode** when creating a session, and you get the whole stack; other sessions stay lean.

## Requirements

- macOS
- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): `npx @deepseek-ai/dsh web`
- Xcode 26+ (contains `mcpbridge` and `xcrun agent skills export`). To use the MCP tools, Xcode must be **running with the target project open**, and you must click **Allow** on the MCP access dialog Xcode shows (see [Usage](#usage)).

## Install

```sh
git clone https://github.com/jihongboo/dsh-apple-mode.git
cd dsh-apple-mode
./install.sh
```

`install.sh` does three things:

1. **Detects your Xcode installs and lets you choose which one provides `mcpbridge`** (see below).
2. Installs the `apple` agent preset → `~/.dsh/.agent-presets/apple/` (existing copy is backed up).
3. Generates the 10 Xcode AI skills **on your machine** via `xcrun agent skills export` and merges them into `~/.agents/skills/` (the DSH skill root, hot-reloaded by the filesystem watcher).

> **Why no vendored skills?** The skills are Apple-authored guidance. Generating them from your own Xcode at install time avoids redistributing Apple content — the repo ships only our own code, config, and docs.

### Choosing an Xcode (multiple installs)

If you have several Xcode versions (e.g. `Xcode.app`, `Xcode-beta.app`, `Xcode-26.2.app`), `mcpbridge` lives in each one's `Contents/Developer/usr/bin` — and only in Xcode 26+. `install.sh` scans `/Applications` for every install that provides it and prompts you to pick:

```text
Found Xcode installs providing mcpbridge:
  1) /Applications/Xcode-beta.app/Contents/Developer  (xcode-select default)
  2) /Applications/Xcode.app/Contents/Developer
Choose (1-2, default 1):
```

- **Default** = the Xcode selected by `xcode-select` → the preset uses `command: xcrun mcpbridge` (portable; follows future `xcode-select` changes).
- **Pick another** → the chosen `…/Contents/Developer/usr/bin/mcpbridge` is baked into the installed preset as an absolute path.
- **Non-interactive**: `./install.sh --xcode /Applications/Xcode.app` (or `--xcode …/Contents/Developer`); `./install.sh --list-xcodes` prints the candidates.
- **Switch at runtime without reinstalling**: `./install.sh --runtime-selectable` installs `bin/mcpbridge` as the command; set `DSH_XCODE_DEVELOPER_DIR=/Applications/…/Contents/Developer` when launching `dsh` to switch. (Resolution: `DSH_XCODE_DEVELOPER_DIR` → `xcrun` → newest `/Applications/Xcode*.app`.)
- **Drive a specific running Xcode instance**: add `env: { MCP_XCODE_PID: '<pid>' }` to the `mcp-xcode` row of the installed preset.

To change the choice later: re-run `./install.sh`, edit the `mcp-xcode` row in `~/.dsh/.agent-presets/apple/agent.cordis.yml`, or use the runtime env var above.

### Alternative: global bundle (MCP in every session)

```sh
dsh plugin --profile web add "github:jihongboo/dsh-apple-mode"
```

Installs the `cordis.patch.yml` bundle, which wires the Xcode MCP server into **every** session of the profile — no preset selection needed, at the cost of the tool-schema tokens in all sessions. **Use one install path, not both**: each registers `serverName: xcode`, and a duplicate server name fails the later instance at load. See [docs/global-mcp.md](docs/global-mcp.md).

## Usage

1. Restart `dsh` (or just open a **new session** — the preset can only be selected on a blank session).
2. Pick **Apple Mode** as the agent preset when creating the session.
3. The session now has:
   - `mcp__xcode__*` tools — operate the open Xcode workspace: `XcodeRead/Write/Update/MV/RM`, `XcodeGlob/Grep/LS`, `UpdateTargetBuildSetting`/`UpdateFileCompilerFlags`, `XcodeListNavigatorIssues`, scheme/run-destination/test-plan switching, `XcodeNewTarget`, `StringCatalogRead/Edit`, …
   - All Apple platform skills (lazy-loaded on demand).
   - An Apple-first, tool-assisted working style.

> **Before using the `mcp__xcode__*` tools:**
> 1. Xcode must be **running** with the project/workspace you want to work on **opened** in it.
> 2. On first connection, Xcode shows an **MCP access dialog** — click **Allow** (允许). Until you do, tool calls will be rejected.

Build/run/test still happen from the terminal (`xcodebuild`, pipe through [`xcsift`](https://github.com/...) for structured output); the MCP toolset covers project surgery, build settings, diagnostics, destinations, and localization.

## What you get

### MCP tools (26, namespaced `mcp__xcode__*`)

| Group | Tools |
|---|---|
| Project I/O | `XcodeRead` `XcodeWrite` `XcodeUpdate` `XcodeMV` `XcodeRM` `XcodeMakeDir` |
| Search | `XcodeGlob` `XcodeGrep` `XcodeLS` |
| Targets & settings | `XcodeNewTarget` `XcodeListTemplates` `XcodeListTargets` `UpdateTargetBuildSetting` `UpdateFileCompilerFlags` |
| Scheme / destination / tests | `XcodeListSchemes` `XcodeSwitchScheme` `XcodeListRunDestinations` `XcodeSwitchRunDestination` `XcodeListTestPlans` `XcodeSwitchTestPlan` |
| Diagnostics | `XcodeListNavigatorIssues` `XcodeRefreshCodeIssuesInFile` |
| Localization | `StringCatalogRead` `StringCatalogEdit` |
| Windows | `XcodeListWindows` `XcodeGetCurrentFile` |

### Skills (10, generated at install time)

`swiftui-specialist` · `swiftui-whats-new-27` · `app-intents-specialist` · `app-intents-whats-new-27` · `audit-xcode-security-settings` · `adopt-c-bounds-safety` · `uikit-app-modernization` · `modernize-tests` · `device-interaction` · `building-document-based-swiftui-applications`

## Repository layout

```text
.
├── presets/apple/            # The agent preset: agent.cordis.yml + preset.yml
├── bin/mcpbridge             # Runtime-selectable mcpbridge launcher (--runtime-selectable)
├── cordis.patch.yml          # Global-MCP bundle patch (dsh plugin add)
├── package.json              # Bundle manifest (dsh.bundle.patch)
├── docs/
│   ├── XCODE_AI_INTEGRATION.md  # Full integration notes (Chinese)
│   └── global-mcp.md            # Alternative: wire the MCP server into every session
├── install.sh               # Xcode picker + preset install + local skills generation
├── uninstall.sh
└── LICENSE                  # MIT
```

## Customization

- **Different Xcode:** re-run `./install.sh` (picker), `./install.sh --xcode <path>` (non-interactive), `--runtime-selectable` + `DSH_XCODE_DEVELOPER_DIR`, or add `env: { MCP_XCODE_PID: '<pid>' }` to the `mcp-xcode` row to drive a specific running instance. See [Choosing an Xcode](#choosing-an-xcode-multiple-installs).
- **Persona:** edit the `persona` row text in the same file.
- **Sync skills after Xcode updates:** re-run `./install.sh` (skills are replaced, preset is backed up).
- **Keep in sync with upstream `standard` preset:** `diff` against `node_modules/@deepseek-ai/dsh/config/agent-presets/standard/agent.cordis.yml`.

## Security notes

- MCP tool calls do **not** go through the DSH file sandbox — they go through the tool-approval flow. `XcodeUpdate`/`XcodeWrite` modify real Xcode project files (including `project.pbxproj`).
- The preset only activates when you select it; no global config is touched by `install.sh`.

## Contributing

PRs welcome. Open an issue for feature requests. If you publish your own DSH extension, add the [`dsh-plugin`](https://github.com/topics/dsh-plugin) topic for discoverability and consider submitting it to [awesome-dsh-plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin).

## License

[MIT](LICENSE). The Xcode AI skills are generated on your machine from your own Xcode installation and remain subject to Apple's license; the persona prompt style is adapted from Xcode Intelligence templates (behavioral guidance, not Apple source text).
