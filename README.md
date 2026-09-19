# Agent Skills

> 面向 AI 辅助软件开发与产品协作的 Skills 集合：方案讨论—执行—锁定，以及 PM 需求/发版等工作流

## 最短路径（先看这个）

**已经在用的机器**：什么都不用做。技能装好后工具会自己发现，直接说话触发即可。

**不知道该用哪个技能**：读入口技能 **`playbook`**。它是技能地图 + 流程路由——按你现在处在哪一步（需求/方案/执行/锁定/汇报），把你指到对应的执行技能。**它不替代任何执行技能，只负责带路。**

**换机器 / 换工具**：克隆一次，**指定技能目录装一次**，之后不用再输路径。

```bash
git clone https://github.com/planarcat/agent-skills ~/agent-skills
cd ~/agent-skills
./install.sh ~/.claude/skills        # 或 ~/.workbuddy/skills，看你用哪个工具
```

**装完一次就记住了**：这个路径会写进仓库根的 `install.config`。以后只要 `cd ~/agent-skills && ./install.sh`，它就会**把仓库技能更新到所有记住过的目录**（换机器、多工具并行都照顾到）。仓库 `git pull` 后技能立即生效，**不必重装**（软链接模式）。

**两条安全约定**：
1. **不主动创建技能目录**——你给的路径必须已存在；不存在就跳过并提示（比如把 Windows 路径拿到 mac 上跑，只会提示"不存在"）。
2. 记住的路径**每次运行都重新检查**：路径没了（换机、盘没挂）就跳过，不会瞎建目录。

`install.config` 是**本机状态**（每行一个路径），已在 `.gitignore` 里，不会进仓库；`./install.sh --targets` 查看、`--forget <目录>` 移除。

**装过一次的模式会被记住**：用 `--copy` 装的目录，记录成 `copy <路径>`，以后不带参数跑**也不会**被悄悄换成软链接（工具不认软链接的机器就靠这条防呆）；软链接装的就是一行裸路径。想改模式，重跑一次带对应参数的安装即可。

**关于 `.bak-<时间戳>` 备份**：只在**目标位置原有真实目录、且内容与仓库不一致**（可能有你的本地改动）时才会产生，原样保留、不删。内容与仓库一致时**直接替换、不备份**。清理用 `./install.sh --prune-bak`（默认只提示，不删）。

**一条铁律**：别把仓库整个 clone 到技能目录里面。工具只往下扫一层，只认 `<技能目录>/<技能名>/SKILL.md`；多套一层就扫不到。`install.sh` 存在的唯一理由就是替你把这一层拆开。

**一条稳定性铁律**：`playbook` 这个入口名**永不改**（改名 = agent 从原来的位置进不来）。技能可以随时增改内容，但改名/移动/删除要同步三处：`playbook` 的地图、`install.sh` 的分组、本 README。

### 各工具的技能目录

| 工具 | 目录 | 备注 |
|:---|:---|:---|
| Claude Code | `~/.claude/skills/<技能名>/SKILL.md` | 也支持项目级 `.claude/skills/`；**支持软链接**（目录里放快捷方式即可） |
| Cursor | `~/.cursor/skills/`、`~/.agents/skills/` | 官方说明**兼容读** `~/.claude/skills/`、`~/.codex/skills/` |
| Codex | `~/.codex/skills/` | — |
| WorkBuddy | `~/.workbuddy/skills/` | — |

**所以装一次就够**：装进 `~/.claude/skills/`，Claude Code / Cursor / Codex 三家都会读到（后两者会兼容扫描 Claude 目录）。不必给每个工具各装一份。

**装完要重启那个工具**才生效——技能名和描述是启动时读入的，之后改描述也要重启；只改正文不用重启。Claude Code 里用 `/skills` 可以确认是否已加载。

### 只想装一部分

`./install.sh` 不带参数会装**全部 25 个技能**。只想要一组就点名分组，不用逐个列技能名：

```bash
./install.sh --group report  ~/.claude/skills    # 日报三件套
./install.sh --group query   ~/.claude/skills    # 数据源核查（CNB 推送 / TAPD 待办）
./install.sh --group plan    ~/.claude/skills    # 方案讨论→执行→锁定
./install.sh --group pm      ~/.claude/skills    # 产品经理常用
./install.sh --group dev     ~/.claude/skills    # 开发与质量（护栏/影响面/冲突/测试/分支/提交）
./install.sh --group journal ~/.claude/skills    # 记录与沉淀（变更日志 / 开发博客）
./install.sh --list                              # 看有哪些技能和分组，不安装
```

**分组安装会自动带上入口 `playbook`**（它只有一个文件，不占地方，但能让 agent 找到北）。`report` 组的取数搭档是 `query` 组：一个查代码推送、一个查 TAPD 待办。

### 安装 / 更新

| 命令 | 作用 |
|:---|:---|
| `./install.sh <目录>` | 装到该目录（**默认软链接**），并**记住这个路径** |
| `./install.sh` | 不带参数：把仓库技能**更新到所有记住过的目录**（日常就用这条） |
| `./install.sh --targets` | 看记住哪些安装目录，并逐个检查是否存在 |
| `./install.sh --forget <目录>` | 忘掉一个目录（已装的文件不动） |
| `./install.sh --copy` | 退回拷贝模式（不使用软链接时） |
| `./install.sh --prune` | 清理指向本仓库但已失效的软链接（对全部记忆目录） |
| `./install.sh --prune-bak` | 清理 `<技能名>.bak-<时间戳>` 旧备份（只在该技能已改挂软链时） |
| `./install.sh --list` | 列技能、分组与记住的目录，不安装 |

举例：

```bash
./install.sh ~/.workbuddy/skills              # WorkBuddy：装一次并记住
./install.sh --group report ~/.claude/skills  # 只装一组（自动带上入口 playbook）
./install.sh ~/.claude/skills report-writer tapd-todo-query   # 点名几个
./install.sh                                  # 以后：一键更新上面所有目录
```

> 软链接模式下，**改内容不用重装**（`git pull` 即生效）；只有在仓库**新增/删除技能**时才需要跑一次 `./install.sh`。

### 把某个技能 / 技能组移植到别处

**入口 `playbook` 只是索引，不是依赖**——地图指向技能，技能不反向依赖 `playbook`，也不依赖别的技能的文件。所以**任意单个技能都可以被单独拷走直接使用**：

```bash
# 只拿一个技能（带它自己的 references/），从仓库产出一个独立文件夹
./install.sh --copy --no-entry ~/export report-writer

# 拿一整组（--no-entry 表示不带入口 playbook）
./install.sh --copy --no-entry --group report ~/export

# 拿全库
./install.sh --copy --no-entry ~/export
```

`--copy` 会**逐技能整体拷贝**（保留各自的 `references/`、`scripts/`），产物就是一个普通文件夹，丢到任何工具的技能目录里都能用，不需要仓库在场。

| 情形 | 怎么做 |
|:---|:---|
| 装到另一台机器 / 另一个工具 | `--copy` 出独立包，或 `git clone` 后在那台机器跑 `./install.sh` |
| 只要几个技能 | 命令末尾点名：`./install.sh --copy ~/export report-writer tapd-todo-query` |
| 离线 / 打包给别人 | `tar -czf skills.tar.gz -C ~/export .` |
| 保留完整历史 | `git archive --format=tar HEAD report-writer | tar -x -C ~/export` |

**自包含性体检**：`./install.sh --lint` —— 检查每个技能目录有没有跳出自身目录的相对路径，列出"文档级跨技能指针"（例如某技能正文写着"规范源见 `report-writer/references/spec.md`"），并检测**同名参考文件漂移**（同一份文档在多个技能里各留一份时，内容必须一致）。

> 唯一的已知软耦合：**日报三件套共用一份规范源**（`spec.md` 放在 `report-writer` 里），建议整组移植；单独搬 `report-pipeline` 或 `report-draft-filter` 也能跑，只是"口径冲突回查"那个指针会指空，改为以它们自带 `references/` 为准。

**移植后入口怎么办**：不装 `playbook` 就按各技能自己的触发词直接唤起，完全够用；装了 `playbook` 就要注意它是**全库地图**——只装了子集时，地图里会列到没装的技能，按需裁掉那几行（或干脆不带入口，用 `--no-entry`）。

**工具不支持 Skill 机制时**：把技能正文（`SKILL.md` + `references/`）直接拷进该工具的规则文件 / 项目根目录的 `AGENTS.md`。早先有个 `report-pipeline/scripts/export-portable.py` 干这件事，但它整份是 v2 口径（七模块 / 责任内联 / 21:00 截止），已于 2026-09-19 删除——**别再用它生成的旧文件**。

## 简介

本项目为 **Claude Code / Cursor** 提供一套 AI 协作技能（Skills），覆盖研发方案生命周期，并包含产品经理常用技能：

| 阶段 | 技能 | 功能 |
|:---|:---|:---|
| 🧭 **入口** | `playbook` | **技能地图 + 流程路由**：按当前流程与状态把你指到执行技能；找不着北先读它 |
| 🧠 **讨论** | `plan-discussion` | 多轮方案讨论，自动落盘记录，生成待执行方案 |
| 🔧 **执行** | `plan-execution` | 按方案逐阶段实施开发，产出执行结果文档 |
| 🔒 **锁定** | `plan-lock` | 锁定前核对方案/结果/遗留清单，确认闭环后归档 |
| 📝 **提交** | `generate-commit` | 根据暂存区或对话上下文生成中文 commit message |
| 🌿 **分支** | `create-requirement-branch` | 建 `{id后4位}-{标题截取}（{id}）` 分支与 worktree 目录，产出物是**一行 `cd` 进入路径**；默认不起服务（要起由你点名） |
| 🔀 **冲突** | `resolve-merge-conflict` | 本地与远程冲突时：fetch 对照 + 手改修改分支；禁止合入对方/测试分支，禁止整树覆盖 |
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
├── record-change-log/            # 改动/问题沉淀：短记 Logs/ + 长记 Blogs/
├── record-development-blog/      # 兼容壳：已并入 record-change-log
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
├── report-pipeline/              # 日报：素材采集与归并
├── report-draft-filter/          # 日报：工作小结 → 日报草稿
├── report-writer/                # 日报：成型（内附规范源文档）
├── cnb-push-audit/               # 取数：CNB 仓库推送/提交核查
├── tapd-todo-query/              # 取数：TAPD 待办需求与状态核对
├── playbook/                     # 入口：技能地图 + 流程路由（名字固定不改）
├── install.sh                    # 安装/更新：默认软链接挂进技能目录
└── README.md
```

各技能为独立目录下的 `SKILL.md`，零依赖，纯 Markdown 规范。

## 安装与使用

### 前提条件

- 已安装 [Claude Code](https://claude.ai/code)（Anthropic 官方 CLI Agent）

### 安装

#### 先克隆到任意目录（**不要直接克隆进技能目录**）

```bash
git clone https://github.com/planarcat/agent-skills.git ~/Documents/agent-skills
cd ~/Documents/agent-skills
```

> ⚠️ 别用 `git clone ... ~/.claude/skills/agent-skills`。技能都在本仓库**顶层**，而工具要求
> `<技能目录>/<技能名>/SKILL.md`——直接克隆进去会多套一层 `agent-skills/`，技能不会被发现。

#### 然后用安装脚本装进工具技能目录

```bash
./install.sh ~/.claude/skills         # 装到该目录（默认软链接），并记住它
./install.sh                          # 以后：更新到所有记住过的目录
./install.sh --group report ~/.claude/skills   # 只装某一组（report / query / plan / pm / dev / journal，自动带上 playbook）
./install.sh ~/.claude/skills report-pipeline report-writer   # 只装点名的那几个
./install.sh --copy ~/.claude/skills  # 不用软链接、退回拷贝模式
./install.sh --targets                # 看记住哪些目录、是否还存在
./install.sh --forget ~/.claude/skills # 忘掉一个目录（不删已装文件）
./install.sh --prune                  # 清理指向本仓库但已失效的软链接
./install.sh --list                   # 列出所有技能与分组，不安装
```

> **技能目录必须先存在**：本工具不替你创建（`mkdir -p ~/.claude/skills` 是你的事）。给了不存在的路径只会提示并跳过。

装完的技能目录长这样（软链接模式：每个技能是指向仓库的快捷方式）：

```
~/.claude/skills/
├── playbook -> ~/agent-skills/playbook            # 入口：技能地图 + 流程路由
├── report-pipeline -> ~/agent-skills/report-pipeline
├── report-draft-filter -> ~/agent-skills/report-draft-filter
├── report-writer -> ~/agent-skills/report-writer
└── ...（其余技能）
```

> 软链接的好处：`git pull` 后技能**立刻**是新版，不必重跑安装。代价：仓库里**新增**技能时要跑一次 `./install.sh` 才会挂上去。

#### 手动装（不用脚本）

```bash
cp -R report-pipeline report-draft-filter report-writer ~/.claude/skills/   # macOS / Linux
```

```powershell
# Windows
$dst = "$env:USERPROFILE\.claude\skills"
'report-pipeline','report-draft-filter','report-writer' | ForEach-Object { Copy-Item -Recurse $_ "$dst\$_" -Force }
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

从远程主分支（主分支名可读当前 Git 仓根的 `AGENT.md` / `CLAUDE.md`）创建需求分支，命名规范 `{id后4位}-{标题截取}（{id}）`（例：`2792-效果图与转平台能力流程重构（1002792）`），worktree 目录与分支同形。**上游必须是该分支自己**，绝不能跟踪主分支。

当前分支正忙或要并行时：用 **Git Worktree** 在旁路目录建分支，不碰原工作区；再用**你惯用的工具**打开该目录（Cursor / VS Code / JB / 命令行型 Agent 都行，见技能正文「跨工具怎么做」）。仅当用户明确「不用 worktree」且工作区允许时，才在本仓 in-place 切换。

**产出物：分支 + worktree 目录 + 一行进入路径**（例：`cd ./Apps/frontend/2792-效果图与转平台能力流程重构（1002792）`）。worktree 位置按序判断：仓库文档约定 → 仓根已有 `Apps/frontend/` 就放那儿 → 兜底 `<原仓父目录>/<原仓名>-wt-<分支名>`。

**本地服务默认不启动**——技能只给路径（和一行备查的启动命令），要跑由你点名；点名时才做依赖检查、换端口避开原窗口、后台起服务那一套。

#### 6. 手动解决合并冲突（resolve-merge-conflict）

本地修改分支与远程/其他分支冲突时触发，例如：

- "解决冲突"、"处理合并冲突"、"同步远程有冲突"
- "pull 冲突了"、"别覆盖本地"

**必须** fetch 后比对差异，只在本地修改分支上手改文件。**禁止**主动 `merge`/`pull` 把对方（含测试分支）合入本地；**禁止** `reset --hard`、整树 `checkout` 对方分支、无脑 `--theirs` 等覆盖式解决。

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

#### 11. 日报编写

三个技能各管一段，按 **采集 → 分拣 → 成型** 的顺序配合。适用范围：**只写日报**（周报 / 周评 / 月报都不写）。

| 技能 | 管什么 | 触发示例 | 默认落盘 |
|:---|:---|:---|:---|
| `report-pipeline` | 采集：什么时候记、记什么、谁提供。阶段完成即追加素材卡，日末归并成稿 | 「记一下」「出日报」「整理今天的工作」 | `<工作区>/.workbuddy/reports/cards/YYYY-MM-DD.md` |
| `report-draft-filter` | 分拣：去噪（旁白/术语/git 细节/编号/未做项）、归类、同类合并 | 「这些哪些该写」「把这段小结整理成日报」 | — |
| `report-writer` | 成型：套七模块、责任内联、红线自查（内附规范原文） | 「按规范写日报」「检查这份汇报合不合规」 | `<工作区>/.workbuddy/reports/daily/日报_YYYY-MM-DD.md` |

提交时限（规范 §4）：日报每日 21:00 前。

**日常怎么用（两拍）：**

```
① 做完一件事  → 说「记一下」，或直接把工作小结 / 语音转写稿丢过来
     → 素材卡写进当前工作区的 .workbuddy/reports/cards/YYYY-MM-DD.md（只追加，不重写）

② 当天收工前  → 说「出日报」
     → 从当天素材卡归并出七模块日报 → .workbuddy/reports/daily/日报_YYYY-MM-DD.md
```

- 不用刻意说「记一下」——发一段工作小结、贴个语音稿，技能都会按采集规则处理。
- 忘了记也能补，只是**精确数字（测试数、耗时、前后对比）当天不记就容易失真**，这是两拍节奏存在的唯一理由。
- 所有文件都在**工作区**里（`<工作区>/.workbuddy/reports/`），不在技能目录下；随时可以直接打开看、手动改。

安装示例：

```bash
cp -R report-pipeline report-draft-filter report-writer ~/.claude/skills/
```

要点：`report-writer/references/spec.md` 是规范**源文档**（逐字收录、不得改写），**冲突一律以它为准**；其中周报、月报两节保留存档，日报/周报正文以 v3 为准。要把这套技能搬到不支持 Skill 机制的工具，直接把 `SKILL.md` 与 `references/` 拷进该工具的规则文件即可（旧的 `export-portable.py` 生成单文件那套已删除，它是 v2 口径）。

**装完即用，零配置**：

- **技能目录只读** — 素材卡 / 日报写在**各自工作区**内的 `.workbuddy/reports/{cards,daily}/`，不写进技能目录。哪份工作属于哪个工作区，数据就落在哪儿，换项目天然分开，技能目录永远干净。
- **项目名不写死** — 技能里不含项目清单，项目名一律取自当天素材，换业务、换项目都不用改技能。
- **一天跨多个工作区** — 素材会分散在各自的工作区里（工作内容归位）；「出日报」时技能按顺序收齐，仍缺就问你在哪个目录。落点在 git 仓库里时，记得把 `.workbuddy/reports/` 加进该仓库的 `.gitignore`。
- 唯一写死的是报告作者本人姓名（何成标）。

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
