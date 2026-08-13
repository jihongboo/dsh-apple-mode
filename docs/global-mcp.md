# Alternative: wire the Xcode MCP server into every session

The preset in this repo mounts `dsh-mcp-client` **only for sessions that pick
the Apple mode**, which keeps ~26 large tool schemas (~6k+ tokens/request)
out of ordinary sessions. If you prefer the MCP tools available everywhere
(e.g. you only ever work on Apple projects), wire the server at the profile
level instead.

## Profile patch

Add to `~/.dsh/profiles/web/cordis.patch.yml`:

```yaml
- id: mcp-xcode
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: xcode
    transport: stdio
    command: xcrun
    args: ['mcpbridge']
    toolCallTimeoutMs: 120000
```

Then restart `dsh --profile web`. Every session gets the `mcp__xcode__*`
tools, regardless of preset.

## Trade-offs

- **+** No need to select a preset; tools are always present.
- **−** Every session pays the tool-schema token cost (roughly +6k tokens per
  request before compaction, per our measurements).
- **−** The Xcode Intelligence persona still lives in the preset; the global
  wiring only adds the tools.

## Notes

- `serverName` must be unique across live instances; remove or rename the
  `mcp-xcode` row from the preset's `agent.cordis.yml` if you also use the
  preset (otherwise the two instances collide on the same `serverName`).
- Requires Xcode 26+ on `xcode-select`; set `MCP_XCODE_PID` via `env` to pin a
  specific Xcode instance.
