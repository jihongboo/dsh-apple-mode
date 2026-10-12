# Alternative: Xcode MCP tools in every session

The plugin's bundle patch declares **Apple Mode** with the MCP client scoped to
that preset, so ~26 large tool schemas (~6k+ tokens/request) are only paid by
sessions that opt in. To get the Xcode MCP tools in **every** session instead,
insert the client row at the profile level.

## Profile patch (DSH 0.2.0+)

Append to `~/.dsh/profiles/<profile>/cordis.patch.yml` (for the web profile:
`~/.dsh/profiles/web/cordis.patch.yml`):

```yaml
- insert:
    - id: mcp-xcode
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: xcode
        transport: stdio
        command: xcrun
        args: ['mcpbridge']
        toolCallTimeoutMs: 120000
```

Then restart DSH. Every session gets the `mcp__xcode__*` tools, regardless of
preset.

> The `- insert:` wrapper matters: a patch row **without** it targets an
> existing row by `id` and only overrides its config — an id that does not
> exist yet is silently ignored. See the loader docs for the patch semantics.

## Use one path, not both

Two live `dsh-mcp-client` instances with the same `serverName: xcode` collide —
the later one fails to load. If you add the global row, remove `mcp-xcode` from
the preset (edit `cordis.patch.yml` in this repo, or override the `preset-apple`
row from your profile patch).

## Trade-offs

- **+** No need to select a preset; the tools are always present.
- **−** Every session pays the tool-schema token cost (roughly +6k tokens per
  request before compaction, per our measurements).
- **−** The Xcode Intelligence-style persona still lives in the preset; the
  global row only adds the tools.

## Picking which Xcode

`command: xcrun` follows `xcode-select`. Switch globally with
`sudo xcode-select -s <Xcode.app>/Contents/Developer`, or per launch with
`DEVELOPER_DIR=<Xcode.app>/Contents/Developer dsh web`. To drive a specific
**running** Xcode instance, add `env: { MCP_XCODE_PID: '<pid>' }`.

## DSH 0.1.x

The same `- insert:` row works there; the on-disk preset mechanism in
`install.sh` is what differs. See the README's version compatibility table.
