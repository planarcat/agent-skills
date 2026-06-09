# Agent Skills

> 面向 AI 辅助软件开发的结构化方案讨论—执行—锁定工作流

## 简介

本项目为 **Claude Code** 提供一套完整的三阶段 AI 协作技能（Skills），覆盖从方案设计到开发落地再到归档锁定的全生命周期：

| 阶段 | 技能 | 功能 |
|:---|:---|:---|
| 🧠 **讨论** | `plan-discussion` | 多轮方案讨论，自动落盘记录，生成待执行方案 |
| 🔧 **执行** | `plan-execution` | 按方案逐阶段实施开发，产出执行结果文档 |
| 🔒 **锁定** | `plan-lock` | 确认完成后锁定归档，防止误改 |

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
  │ 不可修改  │     创建 STATUS.md，重命名文件夹
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
└── README.md
```

项目的全部内容就是这三个 SKILL.md 文件，零依赖，纯 Markdown 规范。

## 安装与使用

### 前提条件

- 已安装 [Claude Code](https://claude.ai/code)（Anthropic 官方 CLI Agent）

### 安装

将本仓库克隆到你的 Claude Code 技能目录或项目路径下：

```bash
git clone https://github.com/planarcat/agent-skills.git
```

Claude Code 会自动发现并加载 `SKILL.md` 文件中定义的技能。技能由 YAML frontmatter 中的 `description` 字段中的中文关键词触发。

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

说出以下任一关键词即可触发：

- "执行完成"、"确认完成"、"本主题完成"
- "锁定主题"、"开发完成"、"任务完成"
- "可以锁定了"、"没问题了"、"就这样"

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
