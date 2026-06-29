# Agent Skills

> 面向 AI 辅助软件开发的结构化方案讨论—执行—锁定工作流

## 简介

本项目为 **Claude Code** 提供一套完整的三阶段 AI 协作技能（Skills），覆盖从方案设计到开发落地再到归档锁定的全生命周期：

| 阶段 | 技能 | 功能 |
|:---|:---|:---|
| 🧠 **讨论** | `plan-discussion` | 多轮方案讨论，自动落盘记录，生成待执行方案 |
| 🔧 **执行** | `plan-execution` | 按方案逐阶段实施开发，产出执行结果文档 |
| 🔒 **锁定** | `plan-lock` | 锁定前核对方案/结果/遗留清单，确认闭环后归档 |
| 📝 **提交** | `generate-commit` | 根据暂存区或对话上下文生成中文 commit message |

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
  │ 不可修改  │     先核对三份清单闭环，再创建 STATUS.md 并重命名
  └────┬─────┘
       │ 下次讨论 → 新主题，继承 UNEXECUTED.md
       ▼
     循环
```

## 项目结构

```
agent-skills/
├── plan-discussion/
│   └── SKILL.md          # 方案讨论技能（~420 行）
├── plan-execution/
│   └── SKILL.md          # 方案执行技能（~260 行）
├── plan-lock/
│   └── SKILL.md          # 方案锁定技能（~115 行）
├── generate-commit/
│   └── SKILL.md          # 生成 commit 技能
├── record-change-log/
│   └── SKILL.md          # 改动日志记录技能
├── record-development-blog/
│   └── SKILL.md          # 开发博客记录技能
├── development-guardrails/
│   └── SKILL.md          # 开发中规范（注释守卫 + 反复修复埋点）
├── change-advice/
│   └── SKILL.md          # 修改建议模式技能
└── README.md
```

项目的全部内容就是这三个 SKILL.md 文件，零依赖，纯 Markdown 规范。

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
改代码前必遵守 development-guardrails：

Part A（任何修改）：必要处补注释，自解释代码不注释，清理失效注释。
Part B（同一 bug 第 3 次修）：先加静默埋点，复现结束只输出一份 [DEBUG:slug] REPORT，修完删除埋点。
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
| **User Rules** | Settings → Rules | 全局 | 最高，始终注入 |
| **Skill** | `~/.agents/skills/` 或 `~/.cursor/skills/` | 全局 | 需 Agent 主动 Read |

> **Skill vs User Rules**：Skill 是参考文档；User Rules 是强制约束。

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

#### 4. 生成 Commit（generate-commit）

说出以下任一关键词即可触发：

- "生成 commit"、"生成提交"、"创建 commit"
- "写 commit"、"帮我 commit"、"commit 一下"

#### 5. 开发中规范（development-guardrails）

改代码时的附加约束。**全局使用请配置 Cursor User Rules**（见上文安装说明），不要只依赖 skill 列表。

| 机制 | 作用 | 局限 |
|---|---|---|
| **User Rules**（全局） | 核心约束注入每次对话 | 需在 Settings → Rules 粘贴 |
| **Skill** | 完整规范（注释规则、collector 示例） | Agent 需主动 Read |

- **Part A 代码注释守卫**：任何代码修改
- **Part B 反复修复控制台埋点**：同一 bug 第 3 次起，复现完成后统一输出一份诊断报告

### 文档输出位置

所有方案文档统一写入项目根目录的 `Plans/` 文件夹，结构如下：

```
Plans/
├── 2026-06-09-clipboard-sync/          # 未锁定主题
│   ├── 01-cross-platform-selection.md   # 第 1 轮讨论
│   ├── 02-performance-strategy.md       # 第 2 轮讨论
│   ├── execution-plan.md                # 待执行方案
│   ├── COMPLETED.md                     # 执行结果确认
│   └── UNEXECUTED.md                    # 未执行/遗留事项
├── 2026-06-01-[LOCKED]-p2p-transfer/    # 已锁定主题
│   ├── 01-architecture-design.md
│   ├── execution-plan.md
│   ├── COMPLETED.md
│   ├── UNEXECUTED.md
│   └── STATUS.md                        # 锁定标志
└── 2026-06-09-quick-note-about-security.md  # 独立讨论文件
```

## 核心设计原则

### 锁定机制

- **唯一入口**：只有 `plan-lock` 可以创建 `STATUS.md` 并锁定主题，其他技能均不得越权
- **明确授权**：只有用户明确表达“锁定主题”或同等直接锁定意图时，才允许进入锁定流程
- **锁定前校验**：必须先核对 `execution-plan.md`、`COMPLETED.md`、`UNEXECUTED.md` 是否形成闭环，发现遗漏不得锁定
- **权限判断**：锁定状态仅以 `STATUS.md` 是否存在为准（文件夹名中的 `[LOCKED]` 前缀仅用于直观显示）
- **不可修改**：锁定后文件夹内所有文件不可再编辑

### 链式继承

- 每个主题执行后，未完成的事项记录在 `UNEXECUTED.md` 中
- 创建新主题时，自动从上一个已锁定主题继承 `UNEXECUTED.md`
- 一个功能一旦被讨论过，只要未曾开发成功、也未曾明确放弃，就持续传递给后续主题

```
主题 A UNEXECUTED v1 → 主题 B UNEXECUTED v2 → 主题 C UNEXECUTED v3 → ...
```

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

不能。锁定后该主题文件夹内的所有文件不可再修改。如需延续，请说"讨论方案"触发新主题，新主题会自动继承上一主题的未完成事项。

## 作者

- GitHub: [@planarcat](https://github.com/planarcat)

## 许可

本项目为零依赖的 Claude Code 技能规范，可自由使用和修改。
