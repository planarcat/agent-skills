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

## 技能地图（24 个）

| 分组 | 技能 | 干什么 | 何时读它 |
|---|---|---|---|
| `report` | `report-pipeline` | 采集层：阶段「先记一笔」落素材卡 → 次日 09:30 前归并 | 用户说"记一下/出日报"、多 agent 并行要汇总时 |
| `report` | `report-draft-filter` | 分拣层：口语化小结去噪、归到 v3 五栏 | 用户发来"今天做了啥"的大段文字 |
| `report` | `report-writer` | 成型层：出日报（+ 周报按需）；内附 v3 规范源文档、SOP、模板 | 要成稿、要查合规/虚报口径时 |
| `query` | `cnb-push-audit` | 查 CNB 三仓库某分支的推送/提交明细 | 核对"今天推了什么"、日报要判"代码到哪一步"（需 cnb 连接器） |
| `query` | `tapd-todo-query` | 查 TAPD 待办需求、核对状态与归属 | 要拉任务行、改状态/owner 前（需 tapd 连接器） |
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
| `dev` | `resolve-merge-conflict` | 解合并冲突；禁止整树覆盖本地修改 | 有冲突/要同步远程时 |
| `dev` | `test-case-authoring` | 测试三件套：写用例 / 补测试 / 让测试变绿 | 说"写测试/加用例" |
| `dev` | `create-requirement-branch` | 建需求分支 `dev/hcb/{id}_{标题}`，并行用 worktree | 说"开需求分支" |
| `dev` | `generate-commit` | 生成通俗易懂的 commit message（默认不推送） | 说"生成 commit" |
| `journal` | `record-change-log` | 把改动过程编成简短变更日志 | 说"将上述改动编成日志" |
| `journal` | `record-development-blog` | 把问题/需求编成开发博客 | 说"记录这个问题/编成博客" |

## 流程路由（按你现在在哪一步）

| 你现在的处境 | 先读 | 接着 |
|---|---|---|
| 需求模糊 / 口头 / 截图 | `requirement-clarification` | → `prd-authoring` 或 `user-story-acceptance` |
| 需求清楚，要技术方案 | `plan-discussion` | → `plan-execution` → `plan-lock` |
| 只要一句"怎么改" | `change-advice` | 不动代码；确认后再进 `development-guardrails` |
| 准备动代码 | `development-guardrails` | 改 → `change-impact-regression` → `generate-commit` |
| 要开新需求分支 | `create-requirement-branch` | 并行时用 worktree |
| 合并有冲突 / 要同步远程 | `resolve-merge-conflict` | → `change-impact-regression` |
| 改完要做最终复查 | `impact-surface-audit` | 触发词敏感，别随手用 |
| 要写/补测试 | `test-case-authoring` | 按 Part A/B/C 选 |
| 一天干完要出日报 | `report-pipeline`（随时落卡）→ `report-draft-filter` → `report-writer` | 周报走 `report-writer` 的「附：周报」 |
| 要核对做了什么 / 任务状态 | `query` 组：`cnb-push-audit`、`tapd-todo-query` | 结果喂给 `report-writer` 的对齐检查 |
| 要发版 / 沉淀记录 | `release-note-pm`、`record-change-log`、`record-development-blog` | — |
| 贴了会议纪要 | `meeting-to-action` | 行动项可转 `prd-authoring` / `plan-discussion` |

## 状态判定（怎么知道现在在哪一步）

先看**手边的物证**，再看用户原话：

- `Plans/<主题>/execution-plan.md` 存在且未归档 → 处在"待执行"→ `plan-execution`
- `Plans/<主题>/COMPLETED.md` + `UNEXECUTED.md` 已齐 → 可 `plan-lock`
- 工作区 `.workbuddy/reports/cards/YYYY-MM-DD.md` 有今天的卡 → 处在"日报采集"，→ `report-pipeline` 归并
- 用户提到具体 TAPD 条目号 / CNB 分支名 → `query` 组
- 刚发生过文件改动（本轮 Write/Edit）→ `change-impact-regression`
- 判断不了：**问一句最短的问题**（"你是要出方案，还是直接改？"），别猜着往下走。

## 资源与依赖（哪些技能会碰外部）

| 类型 | 技能 | 说明 |
|---|---|---|
| 需要连接器 | `cnb-push-audit`（cnb）、`tapd-todo-query`（tapd） | 未连接时先提示用户连接 |
| 会写盘 | `plan-*`（`Plans/`）、`report-*`（各工作区 `.workbuddy/reports/` 与日报/周报文件）、`record-*`、`prd-authoring`（`Docs/`） | 落点遵守各技能正文 |
| 只读 / 只分析 | `change-advice`、`impact-surface-audit`、`development-guardrails` | 不产出业务代码改动 |
| 规范源 | `report-writer/references/spec.md`（日报/周报规范） | 口径冲突以它为准 |

## 安装与更新（仓库根 `install.sh`）

```bash
./install.sh                     # 装全部技能，默认用软链接
./install.sh --group report      # 只装一组（自动带上入口 playbook）
./install.sh --update            # 重扫仓库：补齐漏装的、修复悬空链接
./install.sh --copy              # 不想用软链接时退回拷贝模式
./install.sh --list              # 看技能与分组，不安装
```

**为什么用软链接**：`git pull` 后技能立即生效，不必每次重装。新增技能要跑一次 `--update` 才会被链接进技能目录。

**建议**：无论装哪一组，都带上 `playbook`（入口）。找不着北的时候先读它。
