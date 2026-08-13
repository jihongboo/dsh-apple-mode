# Alternative: wire the Xcode MCP server into every session

The preset in this repo mounts `dsh-mcp-client` **only for sessions that pick
the Apple mode**, which keeps ~26 large tool schemas (~6k+ tokens/request)
out of ordinary sessions. If you prefer the MCP tools available everywhere
(e.g. you only ever work on Apple projects), use the global bundle instead.

## Global bundle (supported)

This repo ships a bundle manifest (`package.json` → `cordis.patch.yml`) that
wires the server into every session of the profile:

```sh
dsh plugin --profile web add "github:jihongboo/dsh-apple-mode"
```

Restart `dsh --profile web`. Every session gets the `mcp__xcode__*` tools,
regardless of preset. The bundle content is exactly:

```yaml
# cordis.patch.yml in this repo
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: xcrun
    args: ['mcpbridge']
    toolCallTimeoutMs: 120000
```

## Manual profile patch (equivalent)

Add the same row to `~/.dsh/profiles/web/cordis.patch.yml` if you do not want
to install the bundle package.

## Trade-offs

- **+** No need to select a preset; tools are always present.
- **−** Every session pays the tool-schema token cost (roughly +6k tokens per
  request before compaction, per our measurements).
- **−** The Xcode Intelligence persona still lives in the preset; the global
  wiring only adds the tools.

## Notes

- **Use one install path, not both.** The bundle and the preset each register
  `serverName: xcode`; a duplicate `serverName` fails the later instance at
  load. If you want both the mode persona and global tools, remove the
  `mcp-xcode` row from `presets/apple/agent.cordis.yml` before installing the
  bundle.
- Requires Xcode 26+ on `xcode-select`; set `MCP_XCODE_PID` via `env` to pin a
  specific Xcode instance.
