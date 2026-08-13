# Xcode AI 能力接入说明（DSH）

把 Xcode 的三样 AI 能力接入 DeepSeek Harness（DSH）的分层方案与使用说明。

## 一、接入了什么

| 层 | 能力 | 来源 | 接入方式 | 生效范围 |
|---|---|---|---|---|
| 执行 | `mcpbridge` 26 个 Xcode MCP 工具 | `xcrun mcpbridge`（Xcode 26+，xcode-select 决定实例） | `dsh-mcp-client`（挂在新模式内） | 仅 Apple 开发模式会话 |
| 知识 | 10 个 Xcode 官方技能（swiftui-specialist、app-intents-specialist、audit-xcode-security-settings、device-interaction、modernize-tests、uikit-app-modernization、swiftui-whats-new-27、adopt-c-bounds-safety、app-intents-whats-new-27、building-document-based-swiftui-applications） | `xcrun agent skills export` | 放入 `~/.agents/skills/`（DSH 技能发现根，watch 自动生效） | 所有会话（懒加载，不占上下文） |
| 行为 | Xcode Intelligence 系统提示词（ToolAssisted / Reasoning / PlannerExecutor 风格） | `IDEIntelligenceChat.framework/.../Resources` | 改编为 agent preset 的 persona | 仅 Apple 开发模式会话 |

### MCP 工具清单（26 个，工具名 `mcp__xcode__*`）

- **工程读写**：`XcodeRead` `XcodeWrite` `XcodeUpdate` `XcodeMV` `XcodeRM` `XcodeMakeDir`
- **检索**：`XcodeGlob` `XcodeGrep` `XcodeLS`
- **目标/设置**：`XcodeNewTarget` `XcodeListTemplates` `XcodeListTargets` `UpdateTargetBuildSetting` `UpdateFileCompilerFlags`
- **Scheme/运行/测试**：`XcodeListSchemes` `XcodeSwitchScheme` `XcodeListRunDestinations` `XcodeSwitchRunDestination` `XcodeListTestPlans` `XcodeSwitchTestPlan`
- **诊断**：`XcodeListNavigatorIssues` `XcodeRefreshCodeIssuesInFile`
- **本地化**：`StringCatalogRead` `StringCatalogEdit`
- **窗口**：`XcodeListWindows` `XcodeGetCurrentFile`

> 构建/运行/测试不走 MCP，用终端 `xcodebuild`（建议管道到 `xcsift` 结构化输出）。

## 二、架构决策：为什么是"新模式 + 独立接入"结合

三样能力角色不同，在 DSH 里映射到不同机制：

1. **MCP 工具 = 执行能力** → `dsh-mcp-client`（工具以 `mcp__xcode__*` 注册）
2. **技能 = 知识能力** → `dsh-skill-filesystem`（懒加载，已自动生效）
3. **提示词 = 行为风格** → **agent preset**（DSH 的"模式"机制，由 persona/指令/工具共同组成）

**不把 MCP 全局接入**的原因：26 个工具 schema 常驻上下文（约 6k+ tokens/请求）。放进新模式后，只有 Apple 模式会话背负这个成本，普通会话不受影响。

## 三、文件清单

```
~/.dsh/.agent-presets/apple/
├── agent.cordis.yml   # 组合文件：改编 persona + mcp-xcode 行 + standard 全量工具
└── preset.yml         # 显示元数据（名称：Apple 开发模式）
```

- 基于 `node_modules/@deepseek-ai/dsh/config/agent-presets/standard/agent.cordis.yml` 复制
- 与 standard 的差异仅两处：`persona` 文本（改编自 Xcode Intelligence 提示词）、新增 `mcp-xcode` 行
- 升级 DSH 后若需对齐 standard 新增行：`diff` 两个文件手工合并

## 四、使用方法

1. **新建会话**（preset 只能在空白会话选择/切换）
2. 在会话创建界面选择 **Apple 开发模式**
3. 会话即可使用：
   - `mcp__xcode__*` 26 个工具（需本机有 Xcode 实例在运行，`xcode-select` 决定连接目标）
   - 全部 Apple 平台技能（按需懒加载）
   - Xcode Intelligence 风格的 persona（Swift 优先、工具辅助、解释/改动分流）

## 五、验证与排障

- 技能：`ls ~/.agents/skills/` 应有 15 个目录；会话技能目录里应看到 `app-intents-*` 等新技能
- 预设发现：GUI 的 preset 列表在打开时会重新读取磁盘（无需重启），新预设立即出现
- MCP 连接失败不影响模式加载（`failOnStartupError: false`）；断线自动重连（指数退避）
- 指定特定 Xcode 实例：在 `agent.cordis.yml` 的 `mcp-xcode` 行加 `env: { MCP_XCODE_PID: '<pid>' }`
- 工具调用超时已调至 120s（`toolCallTimeoutMs`）

## 六、安全注意

- **MCP 工具调用不经过 DSH 文件沙箱**，走工具级审批流程——`XcodeUpdate/Write` 等会直接修改 Xcode 工程文件（含 `project.pbxproj`），审批时会看到对应工具名
- 与 DSH 原生文件工具的边界：MCP 工具操作 Xcode 工程组织，文件工具操作文件系统，persona 已内置该使用原则

## 七、待办（可选）

- [ ] 把 `apple-plugin/rules/apple.md` 复制为工作区 `AGENTS.md`（全局规则，作用于所有模式）
- [ ] 定期执行 `xcrun agent skills export` 同步 Xcode 技能更新（当前已含 10 个官方技能）
- [ ] 试用后按需调整 persona 文本（`~/.dsh/.agent-presets/apple/agent.cordis.yml`）
