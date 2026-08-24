# Agent Skills

> 面向 AI 辅助软件开发与产品协作的 Skills 集合：方案讨论—执行—锁定，以及 PM 需求/发版等工作流

## 简介

本项目为 **Claude Code / Cursor** 提供一套 AI 协作技能（Skills），覆盖研发方案生命周期，并包含产品经理常用技能：

| 阶段 | 技能 | 功能 |
|:---|:---|:---|
| 🧠 **讨论** | `plan-discussion` | 多轮方案讨论，自动落盘记录，生成待执行方案 |
| 🔧 **执行** | `plan-execution` | 按方案逐阶段实施开发，产出执行结果文档 |
| 🔒 **锁定** | `plan-lock` | 锁定前核对方案/结果/遗留清单，确认闭环后归档 |
| 📝 **提交** | `generate-commit` | 根据暂存区或对话上下文生成中文 commit message |
| 🌿 **分支** | `create-requirement-branch` | 建 `dev/hcb/{id}_{标题}`；并行 worktree 默认起本地服务；本仓普通建分支一般不起服务 |
| 🔀 **冲突** | `resolve-merge-conflict` | 本地与远程冲突时：fetch 对照 + 手改修改分支；禁止用远程整树覆盖本地 |
| 📋 **PRD** | `prd-authoring` | 按固定结构写 PRD，落盘 Docs/ 或 Plans/ |
| ❓ **澄清** | `requirement-clarification` | 模糊需求先澄清；已确认 / 待确认 / 假设 |
| ✅ **故事** | `user-story-acceptance` | 用户故事 + Given/When/Then 验收与测试提纲 |
| ⚖️ **取舍** | `competitive-or-feature-brief` | 竞品/功能取舍简报：推荐与不做代价 |
| 📣 **发版** | `release-note-pm` | 对用户 / 对运营 / 对研发三套发版说明 |
| 🗓️ **纪要** | `meeting-to-action` | 会纪要 → 决策、待办（负责人+截止）、开放问题 |

## 工作流概览

```
用户说"讨论方案"
       ↓
  ┌──────────┐
  │ 创建主题  │  ← plan-discussion
  │ 多轮讨论  │     记录每轮对话，生成 execution-plan.md
  └────┬─────┘
       │ 用户说"开始执行"
       ▼
  ┌──────────┐
  │ 逐 Phase  │  ← plan-execution
  │ 执行开发  │     产出 COMPLETED.md + UNEXECUTED.md
  └────┬─────┘
       │ 用户说"锁定主题"
       ▼
  ┌──────────┐
  │ 锁定归档  │  ← plan-lock
  │ 不可修改  │     核对三份清单 → 精简摘要写入 未完成池/
  └────┬─────┘
       │ 下次讨论 → 新主题（不继承）
       ▼
     循环
```

## 项目结构

```
agent-skills/
├── plan-discussion/              # 方案讨论
├── plan-execution/               # 方案执行
├── plan-lock/                    # 方案锁定
├── generate-commit/              # 生成 commit
├── create-requirement-branch/    # 创建需求分支
├── resolve-merge-conflict/       # 手动解决合并冲突（禁止覆盖）
├── record-change-log/            # 改动短日志
├── record-development-blog/      # 开发博客
├── development-guardrails/       # 开发中规范
├── change-impact-regression/     # 影响面与回归
├── change-advice/                # 修改建议（不改代码）
├── test-case-authoring/          # 测试 Part A/B/C
├── impact-surface-audit/         # 最终影响面审计（强触发词）
├── prd-authoring/                # PM：写 PRD
├── requirement-clarification/    # PM：需求澄清
├── user-story-acceptance/        # PM：用户故事 + AC
├── competitive-or-feature-brief/ # PM：功能/竞品简报
├── release-note-pm/              # PM：发版说明（三套语气）
├── meeting-to-action/            # PM：会纪要 → 行动项
└── README.md
```

各技能为独立目录下的 `SKILL.md`，零依赖，纯 Markdown 规范。

## 安装与使用

### 前提条件

- 已安装 [Claude Code](https://claude.ai/code)（Anthropic 官方 CLI Agent）

### 安装

#### Claude Code

将本仓库克隆到 Claude Code 技能目录：

```bash
git clone https://github.com/planarcat/agent-skills.git ~/.claude/skills/agent-skills
# 或将各 skill 文件夹单独复制到 ~/.claude/skills/
```

#### Cursor（全局约束 — 推荐）

Cursor **没有**全局 `.mdc` rule 目录（`~/.cursor/rules/` 不生效）。要让开发中规范在**所有项目**里始终生效，用 **User Rules**：

**1. 添加全局 User Rule（核心，必做）**

1. 打开 **Cursor Settings → Rules → User Rules** → **+ New → User Rule**
2. 名称填 `开发中规范`，内容粘贴：

```
改代码前：若本对话尚未 Read development-guardrails，必须先 Read 该 skill 再动手。

Part A（任何修改）：必要处补注释，自解释代码不注释，清理失效注释。
Part B（问题仍在 / 改完未修好 / 缺运行证据需调试）：先加静默埋点，复现结束只输出一份 [DEBUG:slug] REPORT，修完删除埋点。
```

User Rules 是纯文本、**始终注入每次对话**，不依赖 Agent 主动 Read skill。这是全局约束的唯一可靠方式。

**2. 安装全局 skill（可选，供 Read 时查细节）**

```powershell
# Windows — 任选或两个都装
Copy-Item -Recurse development-guardrails $env:USERPROFILE\.agents\skills\development-guardrails
Copy-Item -Recurse development-guardrails $env:USERPROFILE\.cursor\skills\development-guardrails
```

```bash
# macOS / Linux
cp -r development-guardrails ~/.agents/skills/development-guardrails
cp -r development-guardrails ~/.cursor/skills/development-guardrails
```

| 层级 | 位置 | 作用域 | 可靠性 |
|---|---|---|---|
| **User Rules** | Settings → Rules | 全局 | 最高；要求改代码前 **Read skill** |
| **Skill** | `~/.agents/skills/` 或 `~/.cursor/skills/` | 全局 | description 匹配 + **必须 Read 全文** 才生效 |

> **Skill vs User Rules**：User Rules 强制「先 Read skill」；skill 正文规定 Part A/B 具体做法。二者叠加，不能互相替代。

Claude Code 会自动发现并加载 `SKILL.md` 文件中定义的技能。技能由 YAML frontmatter 中的 `description` 字段触发。

### 触发方式

#### 1. 方案讨论（plan-discussion）

说出以下任一关键词即可触发：

- "讨论方案"、"讨论计划"、"设计一个方案"
- "设计方案"、"制定方案"、"做个方案"
- "规划一下"、"先聊聊怎么做"
- 任何表达"在动手之前先聊清楚怎么做"的意图

#### 2. 方案执行（plan-execution）

说出以下任一关键词即可触发：

- "开始执行"、"执行方案"、"开始开发"
- "按方案做"、"开工"、"动手吧"、"implement"

> **默认只执行 Phase 1**。后续 Phase 会自动移入 `UNEXECUTED.md` 的"计划在未来版本加入"章节。用户可通过"执行全部 Phase"等指令覆盖此默认行为。

#### 3. 方案锁定（plan-lock）

只有明确表达锁定意图才会触发，例如：

- "锁定主题"
- "把这个主题锁定"
- "现在锁吧"
- "确认锁定当前主题"

锁定后会将主题文件夹 **移入 `Plans/归档/`**（保持原名，不创建 `STATUS.md`），并将 `UNEXECUTED.md` 精简写入 `Plans/未完成池/`。

#### 4. 生成 Commit（generate-commit）

说出以下任一关键词即可触发：

- "生成 commit"、"生成提交"、"创建 commit"
- "写 commit"、"帮我 commit"、"commit 一下"

#### 5. 创建需求分支（create-requirement-branch）

说出以下任一关键词即可触发：

- "创建新需求分支"、"开需求分支"、"新建需求分支"
- "从主分支拉个需求分支"
- "用 worktree 并行"、"当前分支还在做别的，另开一条线"

从远程主分支（主分支名可读当前 Git 仓根的 `AGENT.md` / `CLAUDE.md`）创建 `dev/hcb/{需求id}_{需求标题}`。**上游必须是该分支自己**，绝不能跟踪主分支。

当前分支正忙或要并行时：用 **Git Worktree** 在旁路目录建分支，不碰原工作区；再用第二个 Cursor 窗口打开该目录。仅当用户明确「不用 worktree」且工作区允许时，才在本仓 in-place 切换。

**本地服务：** 仅 **worktree 并行**时默认在新目录自动启动（装依赖、换端口避开原窗口，不杀 A 的服务；可说「不起服务」跳过）。本仓**普通新建分支**一般**不**起服务，沿用原窗口已在跑的 dev 即可。

#### 6. 手动解决合并冲突（resolve-merge-conflict）

本地修改分支与远程/其他分支冲突时触发，例如：

- "解决冲突"、"处理合并冲突"、"同步远程有冲突"
- "pull 冲突了"、"别覆盖本地"

**必须** fetch 后比对差异，只在本地修改分支上手改文件。**禁止** `reset --hard`、整树 `checkout` 对方分支、无脑 `--theirs` 等覆盖式解决。

#### 7. 开发中规范（development-guardrails）

改代码时的附加约束。**全局使用请配置 Cursor User Rules**（见上文），并要求改代码前 **Read 本 skill 全文**。

| 机制 | 作用 |
|---|---|
| **User Rules** | 强制「先 Read development-guardrails」 |
| **Skill description** | 匹配改代码/调试/修复等任务，提示必须 Read |
| **Skill 正文** | Part A 注释 + Part B 调试埋点细则 |

- **Part A 代码注释守卫**：任何代码修改
- **Part B 问题调试控制台埋点**：问题未完整解决或缺少运行时证据时，复现全程静默采集，完成后统一输出一份诊断报告

#### 8. 改动影响面与回归（change-impact-regression）

**改完代码、向用户说「好了」之前**，列出受影响的功能/组件/模块，并给出必测与建议测的回归方法。影响面检索**优先调用 GitNexus MCP**（`detect_changes`、`impact`、`api_impact`）。与 guardrails **分工**：guardrails 管改中与调试；本 skill 管改后防间接漂移。

- 可与 `development-guardrails` 同轮使用：先 Read guardrails 再改代码，收尾 Read 本 skill 或按其模板交付
- 触发词示例：「影响面」「回归测试」「改动涉及哪些模块」

安装（与 guardrails 相同目录策略）：

```powershell
Copy-Item -Recurse change-impact-regression $env:USERPROFILE\.agents\skills\change-impact-regression
Copy-Item -Recurse change-impact-regression $env:USERPROFILE\.cursor\skills\change-impact-regression
```

可选 User Rules 补充一行：

```text
非 trivial 源码改动完成后：Read change-impact-regression，交付影响面清单与回归测试方法。
```

#### 9. 测试用例编写（test-case-authoring）

用户说**编写 / 增加 / 优化 / 补充测试或测试用例**（含 E2E）时：

- **Part A 红灯验收**：编写用例时对当前代码**预期为红**；绿了返工用例；**写完不要自动修业务代码**  
- **Part B E2E 控制台**：`console` / `pageerror`、allowlist、`[E2E-DIAG]`、`[E2E-CONSOLE-REPORT]`  
- **Part C 测试驱动调试**：用 spec 查 bug 时 Agent **自跑测试**、按需加采集、读 `[TEST-DEBUG-REPORT]` 后再修产品（与 Part A 区分）

触发词示例：「写测试」「Playwright/E2E」「用测试查原因」「跑 spec 调试」「测试失败排查」

安装：

```powershell
Copy-Item -Recurse test-case-authoring $env:USERPROFILE\.agents\skills\test-case-authoring
Copy-Item -Recurse test-case-authoring $env:USERPROFILE\.cursor\skills\test-case-authoring
```

若曾安装独立 `e2e-console-monitoring`，可删除旧目录，统一使用本 skill。

可选 User Rules：

```text
编写/增加测试：Read test-case-authoring Part A+B。用测试/spec 查 bug：Read Part C，自跑测试并读 [TEST-DEBUG-REPORT] 再改代码。勿与「只写用例不修产品」混用。
```

#### 10. 产品经理技能（P0 / P1）

| 技能 | 触发示例 | 默认落盘 |
|:---|:---|:---|
| `prd-authoring` | 「写 PRD」「出需求说明」 | `Docs/PRD/` 或 `Plans/{主题}/` |
| `requirement-clarification` | 「需求澄清」「口头需求」 | `Docs/需求澄清/` |
| `user-story-acceptance` | 「拆故事」「写 AC」 | `Docs/用户故事/` |
| `competitive-or-feature-brief` | 「竞品对比」「要不要做」 | `Docs/功能简报/` |
| `release-note-pm` | 「写发版说明」「changelog」 | `Docs/发版说明/` |
| `meeting-to-action` | 「会纪要」「纪要转待办」 | `Docs/会纪要/` |

安装示例（PowerShell，可按需复制单个目录）：

```powershell
$dst = "$env:USERPROFILE\.claude\skills"
@(
  'prd-authoring',
  'requirement-clarification',
  'user-story-acceptance',
  'competitive-or-feature-brief',
  'release-note-pm',
  'meeting-to-action'
) | ForEach-Object { Copy-Item -Recurse $_ "$dst\$_" -Force }
```

PM 推荐顺序：模糊需求 → `requirement-clarification` → `prd-authoring` 或 `user-story-acceptance`；取舍用 `competitive-or-feature-brief`；技术方案仍用 `plan-discussion`。

### 文档输出位置

所有方案文档统一写入项目根目录的 `Plans/` 文件夹，结构如下：

```
Plans/
├── 归档/                               # 已锁定主题（只读）
│   └── 2026-06-01-P2P传输/
│       ├── 01-架构设计.md
│       ├── execution-plan.md
│       ├── COMPLETED.md
│       └── UNEXECUTED.md
├── 未完成池/                           # 锁定主题时写入精简摘要
│   └── 2026-06-09-剪贴板同步.md
├── 2026-06-09-剪贴板同步/              # 进行中主题
│   ├── 01-跨平台选型.md                 # 第 1 轮讨论
│   ├── 02-性能策略.md                   # 第 2 轮讨论
│   ├── execution-plan.md                # 待执行方案（三技能固定文件名）
│   ├── COMPLETED.md                     # 执行结果确认
│   └── UNEXECUTED.md                    # 未执行/遗留事项
└── 2026-06-09-登录安全随手记.md         # 独立讨论文件
```

主题文件夹、各轮讨论、独立笔记、`Plans/未完成池/` 摘要名等 **优先中文**；`Plans/` 下固定子目录为 **`归档/`、`未完成池/`**，主题内附件目录为 **`附件/`**；`execution-plan.md` / `COMPLETED.md` / `UNEXECUTED.md` 为三技能固定清单文件名。细则见 `plan-discussion` skill §命名与语言规范。遗留 `Plans/_backlog/`、`assets/` 只读兼容。

## 核心设计原则

### 锁定机制

- **唯一入口**：只有 `plan-lock` 可以将主题移入 `Plans/归档/`，其他技能均不得越权
- **明确授权**：只有用户明确表达“锁定主题”或同等直接锁定意图时，才允许进入锁定流程
- **锁定前校验**：必须先核对 `execution-plan.md`、`COMPLETED.md`、`UNEXECUTED.md` 是否形成闭环，发现遗漏不得锁定
- **未完成归档**：锁定后将 `UNEXECUTED.md` 精简写入 `Plans/未完成池/`
- **权限判断**：主题位于 `Plans/归档/` 下即已锁定（不再使用 `STATUS.md` 或 `[LOCKED]` 前缀）
- **不可修改**：归档后文件夹内所有文件不可再编辑

### 未完成池（Plans/未完成池/）

- `Plans/未完成池/` 是专用文件夹，**不是普通主题**，不参与主题扫描与延续判断（遗留 `Plans/_backlog/` 同等排除）
- 每个主题执行后，未完成事项记录在主题内 `UNEXECUTED.md`
- 锁定主题时，`plan-lock` 将其精简整合，写入 `Plans/未完成池/{与主题文件夹同名的中文名}.md`
- **不做链式继承**：新主题不会自动复制上一主题的遗留清单
- 如需参考历史遗留，用户主动查阅 `Plans/未完成池/`，自行决定是否纳入新方案

### 方案讨论模式 ≠ Claude Code Plan Mode

| | 方案讨论模式（本技能） | Claude Code 内置 Plan Mode |
|---|---|---|
| 编辑文件 | ✅ 可读写 | ❌ 限制 Write/Edit |
| 编辑范围 | **仅限 `Plans/` 目录** | 无法编辑任何文件 |
| 编辑实际代码 | ❌ 禁止 | ❌ 禁止 |
| 目的 | 记录讨论、生成方案文档 | 设计实现方案 |

## 常见问题

**Q: 如果我已有 `Plans/` 目录，安装后会冲突吗？**

不会。技能完全遵循 `Plans/` 目录下的文件组织规则，与已有文件共存。

**Q: 能否跳过讨论阶段直接执行？**

可以。如果你已经手动创建了 `execution-plan.md`，直接说"开始执行"即可触发执行流程。

**Q: 锁定后还能修改吗？**

不能。锁定后该主题文件夹内的所有文件不可再修改。如需延续，请说"讨论方案"创建新主题；历史遗留可查阅 `Plans/未完成池/`。

## 作者

- GitHub: [@planarcat](https://github.com/planarcat)

## 许可

本项目为零依赖的 Claude Code 技能规范，可自由使用和修改。
