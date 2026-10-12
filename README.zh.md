# dsh-apple-mode

[English](README.md) · [简体中文](README.zh.md)

**DeepSeek Harness（`dsh`）的 Xcode AI 集成模式** —— 一个 agent preset（模式）+ 安装脚本，让 DSH 会话获得完整的 Xcode AI 能力栈：

- **26 个 Xcode MCP 工具**（`mcp__xcode__*`），通过 Apple 官方 `mcpbridge` 桥接
- **Xcode Intelligence 风格的 persona**（Swift 优先、工具辅助、解释/改动分流），改编自 `IDEIntelligenceChat` 提示词模板
- **10 个 Apple 平台技能**（SwiftUI、App Intents、安全加固、bounds safety 等），安装时从你自己的 Xcode 本地生成

> 📌 `dsh-plugin` 话题仓库。DeepSeek Harness 处于开发者预览阶段，自动化场景请锁定具体版本。

## 为什么用"模式（preset）"而不是全局接入 MCP？

三样能力在 DSH 里对应三个不同机制：

| 层 | 能力 | DSH 机制 |
|---|---|---|
| 执行 | 26 个 `mcp__xcode__*` 工具 | `dsh-mcp-client`（挂在 preset 内） |
| 知识 | 10 个 Apple 技能 | `dsh-skill-filesystem`（全局、懒加载） |
| 行为 | Xcode Intelligence persona | agent preset（本仓库） |

若把 MCP **全局**接入，26 个大工具 schema（约 6k+ tokens/请求）会常驻每一个会话。挂在 **preset** 内则只有选择该模式的会话背负成本——建会话时选 **Apple Mode**即获得全套能力，其他会话保持轻量。

## 环境要求

- macOS
- **DeepSeek Harness 0.2.0+**（插件安装路径；桌面端即 0.2.x）。DSH 0.1.x 请用 `install.sh` 的旧版磁盘 preset——见[版本兼容性](#版本兼容性)。
- Xcode 26+（含 `mcpbridge` 与 `xcrun agent skills export`）。使用 MCP 工具时，需要保证 **Xcode 已启动并打开了相应的项目**，并且在 Xcode 弹出的 MCP 接入对话框中点击**允许**（见[使用方法](#使用方法)）。

## 安装

### DSH 0.2.0+（桌面端 / 当前版本）——推荐

用插件管理器安装插件，其 bundle patch 会声明 **Apple Mode** agent preset：

```sh
dsh plugin --profile web add "github:jihongboo/dsh-apple-mode"
```

追加 tag 可锁定已发布版本——推荐这么做，因为不带 tag 的安装会跟随默认分支：

```sh
dsh plugin --profile web add "github:jihongboo/dsh-apple-mode#v1.1.1"
```

（桌面端：**设置 → 插件 → 从 GitHub 安装**。）重启 DSH，新建会话时选择 **Apple Mode**。

> **关于插件管理器的 pnpm 警告**：本包是纯配置包——没有 `scripts`、没有依赖、没有构建步骤（见 `package.json`）。如果市场页提示"pnpm ≥ 10 拒绝执行 git 依赖的 `prepare` 脚本，需要在 `pnpm-workspace.yaml` 里写 `allowBuilds`"，可以放心跳过：本包没有任何需要构建或执行的代码，授权只会无谓地扩大授权面。发布到 npm（见 [docs/publishing.md](docs/publishing.md)）后该警告会彻底消失。

然后本地生成 Apple 技能——插件刻意不重新分发它们：

```sh
git clone https://github.com/jihongboo/dsh-apple-mode.git
cd dsh-apple-mode
./install.sh --skills-only
```

### DSH 0.1.x——旧版磁盘 preset

```sh
git clone https://github.com/jihongboo/dsh-apple-mode.git
cd dsh-apple-mode
./install.sh
```

`install.sh` 会做三件事：

1. **检测你机器上的 Xcode，并让你选择由哪个提供 `mcpbridge`**（见下文）。
2. 安装磁盘 preset → `~/.dsh/.agent-presets/apple/`（已有副本自动备份）。
3. 通过 `xcrun agent skills export` **在你机器上本地生成** 10 个 Xcode 技能到 `~/.agents/skills/`。

> **为什么不直接打包技能？** 技能是 Apple 官方内容。安装时从你自己的 Xcode 生成可以避免重新分发 Apple 内容——仓库只包含我们自己的代码、配置和文档。

### 版本兼容性

DSH 0.2 重做了 agent preset：preset 现在是 **bundle patch 里声明的 `@deepseek-ai/dsh-agent-preset` 行**，注册表不再扫描目录。

| DSH | preset 机制 | 如何获得 Apple Mode |
|---|---|---|
| **0.2.0+**（桌面端） | bundle patch 声明 `@deepseek-ai/dsh-agent-preset` 行 | `dsh plugin --profile web add "github:jihongboo/dsh-apple-mode"` |
| **0.1.x**（旧版 `npx`/brew） | `~/.dsh/.agent-presets/<id>/` 磁盘目录 | `./install.sh` |

技能在**两个版本**上都从 `~/.agents/skills` 发现，所以 `./install.sh --skills-only` 通用。

### 选择 Xcode（多版本共存）

如果装了多个 Xcode（如 `Xcode.app`、`Xcode-beta.app`、`Xcode-26.2.app`），`mcpbridge` 位于各自的 `Contents/Developer/usr/bin`——且只有 Xcode 26+ 才有。

**DSH 0.2.0+**：preset 的 MCP 行执行 `xcrun mcpbridge`，Xcode 由 `xcode-select` 决定：

```sh
sudo xcode-select -s /Applications/Xcode-26.2.app/Contents/Developer   # 全局切换
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer dsh web  # 或单次启动指定
```

要驱动某个**正在运行**的特定 Xcode 实例，在 preset 的 `mcp-xcode` 行加 `env: { MCP_XCODE_PID: '<pid>' }`（改本仓库的 `cordis.patch.yml`，或在 profile patch 里覆盖 `preset-apple` 行）。

**DSH 0.1.x**：`install.sh` 会扫描 `/Applications` 下所有包含 mcpbridge 的安装并提示你选择：

```text
Found Xcode installs providing mcpbridge:
  1) /Applications/Xcode-beta.app/Contents/Developer  (xcode-select default)
  2) /Applications/Xcode.app/Contents/Developer
Choose (1-2, default 1):
```

- **默认** = `xcode-select` 选中的 Xcode → preset 使用 `command: xcrun mcpbridge`（可移植，跟随 `xcode-select` 变化）。
- **选择其他** → 所选 `…/Contents/Developer/usr/bin/mcpbridge` 以绝对路径写进安装后的 preset。
- **非交互**：`./install.sh --xcode /Applications/Xcode.app`（或 `--xcode …/Contents/Developer`）；`./install.sh --list-xcodes` 列出候选。
- **运行时切换、无需重装**：`./install.sh --runtime-selectable` 安装 `bin/mcpbridge` 作为命令；启动 `dsh` 时设置 `DSH_XCODE_DEVELOPER_DIR=/Applications/…/Contents/Developer` 即可切换。（解析顺序：`DSH_XCODE_DEVELOPER_DIR` → `xcrun` → 最新的 `/Applications/Xcode*.app`。）

之后想改：重跑 `./install.sh`、编辑 `~/.dsh/.agent-presets/apple/agent.cordis.yml` 的 `mcp-xcode` 行，或用上面的运行时环境变量。

### 备选：全局接入 MCP（所有会话）

preset 把约 26 个工具 schema 限定在 Apple Mode 会话内。若希望**所有**会话都能用 Xcode MCP 工具，在你的 profile patch（`~/.dsh/profiles/<profile>/cordis.patch.yml`）里插入客户端行：

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

**两种方式二选一**：两个存活的 `serverName: xcode` 实例会冲突，后加载的会失败。详见 [docs/global-mcp.md](docs/global-mcp.md)。

## 使用方法

1. 重启 `dsh`（或直接**新建会话**——preset 只能在空白会话选择）。
2. 建会话时选择 **Apple Mode**。
3. 该会话即可使用：
   - `mcp__xcode__*` 工具——直接操作打开的 Xcode 工作区：`XcodeRead/Write/Update/MV/RM`、`XcodeGlob/Grep/LS`、`UpdateTargetBuildSetting`/`UpdateFileCompilerFlags`、`XcodeListNavigatorIssues`、scheme/运行目标/测试计划切换、`XcodeNewTarget`、`StringCatalogRead/Edit` 等
   - 全部 Apple 平台技能（按需懒加载）
   - Apple 优先、工具辅助的工作方式

> **使用 `mcp__xcode__*` 工具之前：**
> 1. 需要保证 **Xcode 已启动**，并且在其中**打开了要操作的项目/工作区**。
> 2. 首次建立连接时，Xcode 会弹出 **MCP 接入对话框**——请点击**允许**。在点击允许之前，工具调用会被拒绝。

构建/运行/测试仍在终端进行（`xcodebuild`，建议管道到 `xcsift` 获得结构化输出）；MCP 工具集负责工程手术、构建设置、诊断、运行目标与本地化。

## 内容清单

### MCP 工具（26 个，命名空间 `mcp__xcode__*`）

| 分组 | 工具 |
|---|---|
| 工程读写 | `XcodeRead` `XcodeWrite` `XcodeUpdate` `XcodeMV` `XcodeRM` `XcodeMakeDir` |
| 检索 | `XcodeGlob` `XcodeGrep` `XcodeLS` |
| 目标与设置 | `XcodeNewTarget` `XcodeListTemplates` `XcodeListTargets` `UpdateTargetBuildSetting` `UpdateFileCompilerFlags` |
| Scheme/运行/测试 | `XcodeListSchemes` `XcodeSwitchScheme` `XcodeListRunDestinations` `XcodeSwitchRunDestination` `XcodeListTestPlans` `XcodeSwitchTestPlan` |
| 诊断 | `XcodeListNavigatorIssues` `XcodeRefreshCodeIssuesInFile` |
| 本地化 | `StringCatalogRead` `StringCatalogEdit` |
| 窗口 | `XcodeListWindows` `XcodeGetCurrentFile` |

### 技能（10 个，安装时生成）

`swiftui-specialist` · `swiftui-whats-new-27` · `app-intents-specialist` · `app-intents-whats-new-27` · `audit-xcode-security-settings` · `adopt-c-bounds-safety` · `uikit-app-modernization` · `modernize-tests` · `device-interaction` · `building-document-based-swiftui-applications`

## 仓库结构

```text
.
├── presets/apple/            # agent preset：agent.cordis.yml + preset.yml（0.1.x 用）
├── bin/mcpbridge             # 运行时切换用的 mcpbridge 启动器（--runtime-selectable）
├── cordis.patch.yml          # bundle patch：声明 Apple Mode（DSH 0.2+）
├── package.json              # bundle manifest（dsh.bundle.patch）
├── docs/
│   ├── XCODE_AI_INTEGRATION.md  # 完整接入说明（中文）
│   ├── global-mcp.md            # 全局 bundle 与 preset 的取舍
│   └── publishing.md            # 发布到 npm 的步骤
├── install.sh               # 安装 preset + 本地生成技能
├── uninstall.sh
└── LICENSE                  # MIT
```

## 自定义

- **更换 Xcode**：重跑 `./install.sh`（选择器）、`./install.sh --xcode <路径>`（非交互）、`--runtime-selectable` + `DSH_XCODE_DEVELOPER_DIR`，或在 `mcp-xcode` 行加 `env: { MCP_XCODE_PID: '<pid>' }` 指定某个正在运行的实例。详见[选择 Xcode（多版本共存）](#选择-xcode多版本共存)。
- **persona**：编辑同文件的 `persona` 行文本。
- **Xcode 升级后同步技能**：重跑 `./install.sh`（技能整体替换，preset 自动备份）。
- **对齐上游 standard preset**：与 `node_modules/@deepseek-ai/dsh/config/agent-presets/standard/agent.cordis.yml` 做 `diff`。

## 安全说明

- MCP 工具调用**不经过 DSH 文件沙箱**，走工具级审批流程。`XcodeUpdate`/`XcodeWrite` 会直接修改真实 Xcode 工程文件（含 `project.pbxproj`）。
- preset 仅在你主动选择时激活；`install.sh` 不触碰任何全局配置。

## 参与贡献

欢迎 PR 与 issue。如果你发布自己的 DSH 扩展，请打上 [`dsh-plugin`](https://github.com/topics/dsh-plugin) 话题，并考虑提交到 [awesome-dsh-plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin)。

## 许可证

[MIT](LICENSE)。Xcode AI 技能由安装脚本在你的机器上从你自己的 Xcode 生成，仍受 Apple 许可约束；persona 提示词风格改编自 Xcode Intelligence 模板（行为指导，非 Apple 源码文本）。
