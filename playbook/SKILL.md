---
name: playbook
description: 技能总入口：技能地图 + 流程路由 + 状态判定。当用户说「我该用哪个技能」「接下来干什么」「从需求到上线怎么走」「帮我把这件事走完」「整理一下今天的活」，或任务跨多个技能、不确定该进哪个技能时，先读本技能——它按当前流程与状态把你路由到对应的执行技能，再按那个技能的正文执行。**本技能名固定不改**（改名会让 agent 找不到入口）。
---

# Playbook · 总入口与技能地图

> **30 秒读懂**：我不替代任何执行技能。我是**索引 + 路由 + 状态判定**。执行细节一律以目标技能的正文为准，我只负责带路。

## 怎么用我（三步）

1. **读我**（本文件）——拿到技能地图与路由规则。
2. **定位**——按下面「流程路由」找出目标技能；需要外部数据时，先看「资源与依赖」确认前置条件。
3. **执行**——用 Read 打开目标技能的 `SKILL.md` **全文**，按它走。**不要凭记忆复述别的技能的流程。**

## 铁律（别破坏入口）

1. **本技能名固定为 `playbook`，永不改名。** 改名＝ agent 在原来的位置找不到入口。只允许改内容。
2. 给任何技能**改名 / 移动 / 删除**，必须同步三处：**本文件的地图**、仓库根 `install.sh` 的分组、`README.md`。
3. **新增技能必须登记到本文件的「技能地图」**，否则等于没装（agent 找不到）。
4. 技能正文互相引用时用**条件引用**（"装了 X 就读它的 Y 节；没装也不影响"），不要写成硬依赖。

## 开发规范（用户口径）

**开发任务完成后，提交即推送。**

- 在**需求分支**上开发 → 任务/阶段做完就 `git commit`，然后**直接 `git push` 到该分支的远程同名分支**（上游就是它自己），不用每次问。
- **不推主分支、不 `--force`、不开 PR**（除非用户明确要求）。
- 若不在需求分支上（主分支、临时探查分支、无上游）→ 只提交，说明原因，别硬推。
- commit message 走 `generate-commit`；分支创建与命名走 `create-requirement-branch`；逐阶段执行并在每阶段收尾提交推送走 `plan-execution`。

## 可移植性（单个技能也能被单独带走）

**这张地图是"单向索引"，不是依赖。** 地图指向技能；技能**不反向依赖** `playbook`，也不依赖别的技能的文件。所以：

- **把任意单个技能（含技能组）拷到别的工具/机器，它自己能跑** —— 每个技能目录都是自包含的单元（自己的 `SKILL.md` + 自己的 `references/`），没有跨目录的相对路径。
- 带走某个技能时，**不需要**带 `playbook`，也**不需要**改它的内容。
- 唯一要注意的是**文档级指针**：少数技能正文里会写"规范源见 `report-writer/references/spec.md`"这类**同仓库路径**——同仓库或同组一起搬时能解析，只搬单个时那个指针会指空（不影响执行，按技能自带 `references/` 走即可）。
- 已知的软耦合：**日报三件套共用一份规范源**（放在 `report-writer` 里）→ 建议 `report-pipeline` / `report-draft-filter` / `report-writer` **整组移植**。
- 体检命令：仓库根 `./install.sh --lint`（检查每个技能是否自包含、列出文档级跨技能指针、检测**同名参考文件漂移**——同一份文档在多个技能里各留一份时内容必须一致）。
- 移植命令：`./install.sh --copy <目标目录> <技能名…>`；整组用 `--copy --no-entry --group <组名> <目标目录>`（`--no-entry` 不带入口）。

## 技能地图（27 个）

| 分组 | 技能 | 干什么 | 何时读它 |
|---|---|---|---|
| `report` | `report-pipeline` | 采集与共写层：阶段完成即更新共享日报（Reports/daily_work/）里自己会话的块，每个工作节点带 [HH:MM] 时间 | 用户说"记一下/出日报"、多 agent 并行共写日报时 |
| `report` | `report-draft-filter` | 分拣层：口语化小结去噪、归类成共享日报条目 | 用户发来"今天做了啥"的大段文字 |
| `report` | `report-writer` | 收口层：在共享日报上出日报（+ 周报按需）；内附 v3 规范源文档、SOP、模板 | 要成稿、要查合规/虚报口径时 |
| `query` | `cnb-push-audit` | 查 CNB 三仓库某分支的推送/提交明细 | 核对"今天推了什么"、日报要判"代码到哪一步"（需 cnb 连接器） |
| `query` | `tapd-todo-query` | 查 TAPD 待办需求、核对状态与归属 | 要拉任务行、改状态/owner 前（需 tapd 连接器） |
| `tapd` | `tapd-requirement-writing` | 写/重整 TAPD 需求：五段式文案、按功能拆粒度、处理人规则、作废并入、正文内嵌图片 | 要写/重整 TAPD 需求、上传截图时（需 tapd 连接器） |
| `plan` | `plan-discussion` | 多轮方案讨论，落盘 `Plans/` 生成待执行方案 | 说"讨论方案/设计个方案/规划一下" |
| `plan` | `plan-execution` | 按待执行方案逐阶段开发，产出已执行/未执行文档 | 说"开始执行/开工"，且 `Plans/` 有最新主题 |
| `plan` | `plan-lock` | 核对闭环后把主题归档进 `Plans/归档/` | 明确说"锁定/锁吧" |
| `pm` | `prd-authoring` | 写 PRD（背景/目标/非目标/用户故事/AC/埋点/风险） | 说"写 PRD/出需求说明" |
| `pm` | `requirement-clarification` | 需求先澄清，输出「已确认 / 待确认 / 假设」三栏 | 需求模糊、口头、截图 |
| `pm` | `user-story-acceptance` | 拆用户故事 + 验收标准（强制 Given/When/Then） | 说"拆故事/写 AC" |
| `pm` | `competitive-or-feature-brief` | 竞品/功能取舍决策简报 | 说"竞品对比/要不要做" |
| `pm` | `release-note-pm` | 发版说明，三套语气（用户/运营/研发） | 说"写发版说明/changelog" |
| `pm` | `meeting-to-action` | 会议记录 → 决策 + 待办 + 开放问题 | 贴会议纪要/语音转写 |
| `dev` | `development-guardrails` | 改代码前的强制护栏 | **首次 Write/Edit 前必读** |
| `dev` | `change-advice` | 只分析不改码：原因、改动点、风险 | 说"怎么改/为什么报错" |
| `dev` | `change-impact-regression` | 改完后列影响面 + 具体回归方法 | 代码改完收尾时 |
| `dev` | `impact-surface-audit` | 最终复查：挖对**非本功能模块**的隐性辐射 | 明确说"最终复查/影响面检索"（强触发，慎用） |
| `dev` | `full-code-review` | **代码审查**智能分级（L0–L3）：小改单代理快审、按类型定向 2–3 维、提 MR 前六维全量（6 维标准内置在本技能 references/ 下）；只审不代改 | 说「审查一下 / 全面审查 / 快速看一下 / full review」、提交前检查 |
| `dev` | `resolve-merge-conflict` | 解合并冲突；禁止整树覆盖本地修改 | 有冲突/要同步远程时 |
| `dev` | `test-case-authoring` | 测试三件套：写用例 / 补测试 / 让测试变绿 | 说"写测试/加用例" |
| `dev` | `create-requirement-branch` | 建需求分支与 worktree 目录 `{id后4位}-{标题截取}（{id}）`，建完即跑 `pnpm install`（无报错不加检测），产出**一行 `cd` 进入路径**（默认不起服务） | 说"开需求分支" |
| `dev` | `requirement-breakdown` | **开发前需求拆解**：功能点 + 边界/歧义/待确认/验收 + 日报②栏素材 | 建完分支后、需求首次进「开发中」前（日报硬规则） |
| `dev` | `generate-commit` | 生成通俗易懂的 commit message；**在需求分支上提交后直接推送**（用户说"只提交/先别推"才止步） | 说"生成 commit" |
| `journal` | `record-change-log` | **沉淀改动/问题**：短记（`Logs/`，≤100 字）+ 长记（`Blogs/`，第一人称） | 说"编成日志""记录这个问题/编成博客" |
| `journal` | `record-development-blog` | **兼容壳**：已并入 `record-change-log` 的长记模式 | 老触发词照旧命中这里，读到它就转去执行 `record-change-log` |

## 流程路由（按你现在在哪一步）

| 你现在的处境 | 先读 | 接着 |
|---|---|---|
| 需求模糊 / 口头 / 截图 | `requirement-clarification` | → `prd-authoring` 或 `user-story-acceptance` |
| 需求清楚，要技术方案 | `plan-discussion` | → `plan-execution` → `plan-lock` |
| 只要一句"怎么改" | `change-advice` | 不动代码；确认后再进 `development-guardrails` |
| 准备动代码 | `requirement-breakdown`（日报硬规则：进开发中前必须有需求理解）→ `development-guardrails` | 改 → `change-impact-regression` → `generate-commit`（完成后直接推需求分支） |
| 要开新需求分支 | `create-requirement-branch` → `requirement-breakdown` | 并行时用 worktree；拆解完再开工 |
| 合并有冲突 / 要同步远程 | `resolve-merge-conflict` | → `change-impact-regression` |
| 改完要做最终复查 | `impact-surface-audit` | 触发词敏感，别随手用 |
| 要写/补测试 | `test-case-authoring` | 按 Part A/B/C 选 |
| 一天干完要出日报 | `report-pipeline`（随时落卡）→ `report-draft-filter` → `report-writer` | 周报走 `report-writer` 的「附：周报」；**前置动作（TAPD 对齐/补计划时间/查正式线）与成品形态见工作区《日报周报生产流程_SOP.md》** |
| 要核对做了什么 / 任务状态 | `query` 组：`cnb-push-audit`、`tapd-todo-query` | 结果喂给 `report-writer` 的对齐检查 |
| 要发版 / 沉淀记录 | `release-note-pm`、`record-change-log`（短记/长记都在它里面） | — |
| 贴了会议纪要 | `meeting-to-action` | 行动项可转 `prd-authoring` / `plan-discussion` |

## 状态判定（怎么知道现在在哪一步）

先看**手边的物证**，再看用户原话：

- `Plans/<主题>/execution-plan.md` 存在且未归档 → 处在"待执行"→ `plan-execution`
- `Plans/<主题>/COMPLETED.md` + `UNEXECUTED.md` 已齐 → 可 `plan-lock`
- 工作区 `Reports/daily_work/YYYY-MM-DD.md` 已存在 → 处在"日报共写"，→ `report-pipeline` 更新自己会话的块；用户说"出日报" → `report-writer` 收口
- 用户提到具体 TAPD 条目号 / CNB 分支名 → `query` 组
- 刚发生过文件改动（本轮 Write/Edit）→ `change-impact-regression`
- 判断不了：**问一句最短的问题**（"你是要出方案，还是直接改？"），别猜着往下走。

## 资源与依赖（哪些技能会碰外部）

| 类型 | 技能 | 说明 |
|---|---|---|
| 需要连接器 | `cnb-push-audit`（cnb）、`tapd-todo-query` / `tapd-requirement-writing`（tapd） | 未连接时先提示用户连接 |
| 会写盘 | `plan-*`（`Plans/`）、`report-*`（各工作区 `Reports/`）、`record-*`、`prd-authoring`（`Docs/`） | 落点遵守各技能正文 |
| 只读 / 只分析 | `change-advice`、`impact-surface-audit`、`development-guardrails`、`full-code-review` | 不产出业务代码改动 |
| 规范源 | `report-writer` 技能里的 `references/spec.md`（日报/周报规范） | 口径冲突以它为准；日报三件套建议整组移植 |

## 安装与更新（仓库根 `install.sh`）

```bash
./install.sh <安装目录>          # 装到该目录（默认软链接）并记住它；目录必须已存在
./install.sh                     # 以后：更新到所有记住过的目录
./install.sh --group report <目录>  # 只装一组（自动带上入口 playbook）
./install.sh --targets           # 看记住哪些目录、是否还存在
./install.sh --forget <目录>     # 忘掉一个目录
./install.sh --copy              # 不想用软链接时退回拷贝模式
./install.sh --list              # 看技能与分组，不安装
```

**为什么用软链接**：`git pull` 后技能立即生效，不必每次重装。仓库里新增技能时跑一次 `./install.sh` 即可补齐。

**Windows**：PowerShell 不认 `.sh`，用同目录的 `install.ps1`（行为一致，默认用「目录联接」Junction，不需要管理员）：
`powershell -ExecutionPolicy Bypass -File .\install.ps1 $env:USERPROFILE\.claude\skills`；或在 Git Bash 里 `bash install.sh`。

**两条安全约定**：路径**必须先存在**（本工具不创建技能目录），不存在的路径直接跳过；记住的路径每次运行都会重新检查，路径没了就跳过（换机器、Windows 路径拿到 mac 上跑都属于这种情况）。记住的路径写在仓库根 `install.config`（本机状态，不进 git），**连安装模式一起记**——用 `--copy` 装的记成 `copy <路径>`，以后不带参数跑也不会被悄悄换成软链接。

**换模式时的备份**：把"已经有真实目录"的位置改成软链时，只有**内容与仓库不一致**才会留 `<技能名>.bak-<时间戳>`（保住本地改动）；内容一致就直接替换。清理用 `./install.sh --prune-bak`。

**建议**：无论装哪一组，都带上 `playbook`（入口）。找不着北的时候先读它。
