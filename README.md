# dsh-apple-mode

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

Wiring the MCP server **globally** would put ~26 large tool schemas (~6k+ tokens/request) into *every* session. Mounting it inside a **preset** keeps the cost only in sessions that opt in — pick **Apple 开发模式** when creating a session, and you get the whole stack; other sessions stay lean.

## Requirements

- macOS
- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): `npx @deepseek-ai/dsh web`
- Xcode 26+ (contains `mcpbridge` and `xcrun agent skills export`; Xcode must be running for tool calls)

## Install

```sh
git clone https://github.com/jihongboo/dsh-apple-mode.git
cd dsh-apple-mode
./install.sh
```

`install.sh` does two things:

1. Installs the `apple` agent preset → `~/.dsh/.agent-presets/apple/` (existing copy is backed up).
2. Generates the 10 Xcode AI skills **on your machine** via `xcrun agent skills export` and merges them into `~/.agents/skills/` (the DSH skill root, hot-reloaded by the filesystem watcher).

> **Why no vendored skills?** The skills are Apple-authored guidance. Generating them from your own Xcode at install time avoids redistributing Apple content — the repo ships only our own code, config, and docs.

### Alternative: global bundle (MCP in every session)

```sh
dsh plugin --profile web add "github:jihongboo/dsh-apple-mode"
```

Installs the `cordis.patch.yml` bundle, which wires the Xcode MCP server into **every** session of the profile — no preset selection needed, at the cost of the tool-schema tokens in all sessions. **Use one install path, not both**: each registers `serverName: xcode`, and a duplicate server name fails the later instance at load. See [docs/global-mcp.md](docs/global-mcp.md).

## Usage

1. Restart `dsh` (or just open a **new session** — the preset can only be selected on a blank session).
2. Pick **Apple 开发模式** as the agent preset when creating the session.
3. The session now has:
   - `mcp__xcode__*` tools — operate the open Xcode workspace: `XcodeRead/Write/Update/MV/RM`, `XcodeGlob/Grep/LS`, `UpdateTargetBuildSetting`/`UpdateFileCompilerFlags`, `XcodeListNavigatorIssues`, scheme/run-destination/test-plan switching, `XcodeNewTarget`, `StringCatalogRead/Edit`, …
   - All Apple platform skills (lazy-loaded on demand).
   - An Apple-first, tool-assisted working style.

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
├── docs/
│   ├── XCODE_AI_INTEGRATION.md  # Full integration notes (Chinese)
│   └── global-mcp.md            # Alternative: wire the MCP server into every session
├── install.sh               # Preset install + local skills generation
├── uninstall.sh
└── LICENSE                  # MIT
```

## Customization

- **Different Xcode instance:** add `env: { MCP_XCODE_PID: '<pid>' }` to the `mcp-xcode` row in `presets/apple/agent.cordis.yml`.
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
