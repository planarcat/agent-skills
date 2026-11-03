---
name: 界面审查
description: "界面 UI&UX 审查，两段式（审查出清单 ⏸ 用户批准 → 修复取证终验）：用户说「界面审查 / UI 审查 / UI&UX 检查 / 出界面优化清单」时跑审查段——遍历界面状态发现问题，产出可视化优化清单（问题 + file:line 定位 + 怎样改进）后必停；用户审查通过再说「按清单修 / 修 P1-2 / 通过了开始修」才进修复段——按批准范围修复 → before/after 修复证据 → 逐页终验。清单与修复之间必然断连，未经批准不修。四个社区 skill 收编内置在 references/，本技能是唯一入口与编排器。"
---

# 界面审查 · 两段式流水线（ui-review-pipeline）

对**现有界面**做系统性审查与优化，交付一份**可视化优化清单**——有哪些问题（带截图）、怎样改进（定位到 file:line）、改进后结果如何（前后对比证据）。

**核心纪律：清单与修复之间必然断连。** 审查段产出清单后**必停**，等用户审查；用户通过并点名范围后，才进修复段。四个原子 skill 收编在 `references/` 下（只作内部标准，不作为独立技能发现），本技能是编排器：管状态、传契约、设门禁；审查、定位、取证、终验由原子 skill 各自完成。

## 两段模式

| 段 | 触发 | 做什么 | 交付 |
|---|---|---|---|
| **Run A · 审查出清单** | 「界面审查 / UI 审查 / UI&UX 检查 / 出界面优化清单」 | 阶段 1 遍历发现 + 阶段 2a 定位（file:line + ship verdict） | 可视化优化清单 → **⏸ 必停，等用户审查** |
| **Run B · 修复与取证** | 用户审查通过后说「按清单修 / 通过了开始修 / 修 P1-2、P2-1」 | 按批准范围修复（2b）→ 阶段 3 修复证据 → 阶段 4 终验 | 修复 + 前后对比证据 + 终验结论 |

### 硬门禁（跨两段）

- Run A 结束**必须停**：不问"要不要我顺手修掉"、更不直接修。交付语 natural 给出下一步提示（"清单已出，你审查后点名要修哪些"），仅此而已。
- Run B 的启动条件：`.ui-pipeline/state.json` 存在、**用户已明确批准**（整体通过或点名 id）。批准动作记入 state（`approved: true` + 批准范围与时间）；没有 state.json 却被要求修复 → 问一句：是先跑审查，还是要修别的（走 `改动建议`）。
- **范围纪律**：只修 approved 的问题；P3 未被点名就不修；用户点名范围外的"顺手修"一律不做（发现了报告一句即可）。

## 与相邻技能的分工（先判再做）

| 用户要 | 走谁 |
|---|---|
| 审查现有界面问题、出优化清单（Run A）／按清单修复并取证（Run B） | **本技能** |
| 重新设计 / 出方案 / 出高精度原型（改版方向未定） | `界面优化设计`（ui-ux-redesign）；方案定稿后的验证取证可回本技能 |
| 改完只测功能是不是好的 | `类人测试`；要 UI 观感问题清单 → 本技能 Run A |
| 后端逻辑 / 接口正确性 | `代码审查` |

**清单格式沿用 `界面优化设计` 的「优化清单可视化」规范，不另造格式**：一屏内 before / after 对照，每条带**编号 + 严重度（P0 / P1 / P2）+ 问题 + 证据（文件:行 / 实测值）+ 建议修法 + 完成勾选**，按严重度分区（其原文规则：审查类任务已拿到「问题 + 证据」清单，直接转可视化、不另做原型）。本技能补的是它没有的四件事：状态遍历取证（walkthrough）、代码级定位与 ship verdict（ui-audit）、修复后像素证据（proof-of-fix）、终验门禁（visual-acceptance），外加两段式断连纪律。

## Run A · 审查出清单

**先决条件**：① 界面可截图——有浏览器控制能力（如 ZCode 的 `browser-use:control-browser`、Playwright）→ 自行遍历截图；没有 → 用户提供各状态截图。② 代码在本地才能给出 file:line 定位；只有截图时照常出清单，定位栏写「未定位（仅截图）」。

**流程**：

1. **准备**：`date +%F` 定今天日期 → 工作目录建 `.ui-pipeline/`（加 gitignore）→ 读 `工作区配置`（规范源 / `DESIGN.md` / 测试账号，作为判据输入）→ 定页面 URL 与目标代码目录（推断不了问一句）。
2. **阶段 1 · 发现与建议**（`walkthrough/SKILL.md`）：遍历每个 UI 状态截图（默认 / 空 / 加载 / 有数据 / 错误 / 边界）→ 对照启发式清单逐项 ✅⚠️❌（视觉 / 交互 / 内容数据 / 性能打磨）→ 产出 `report.md`：P0–P3 优先级 + 截图引用 + 修复建议。
3. **阶段 2a · 定位**（`ui-audit/SKILL.md`）：问题逐条映射 file:line + ship verdict（release-blocker / fix-this-sprint / backlog）。**只定位，不修复**。
   - **每条问题必须附复现路径（2026-11-03 用户口径）**：入口 / 步骤 / 现象 / 对照基线，四栏缺一不可（格式见下方「问题的复现路径」）。
4. **入册**：问题入 `state.json`（编号 `P<级别>-<序号>`，状态 `open`）。
5. **渲染可视化清单页（硬要求，不是可选项）**：把清单渲染成**单文件 HTML** 落盘 `.ui-pipeline/checklist.html`——「优化清单可视化」格式：一屏内 **before / after 对照**，**before = 现状截图，after = 优化后预期 UI / 交互的渲染示意**——用内联 HTML / CSS 按建议修法做出 mini mockup（颜色 / 间距 / 字号复用 `DESIGN.md` 与项目 token；交互类建议要能看出改动后的关键状态，如新增的按钮、空态动作、骨架屏；**不许用文字说明代替渲染示意**，确无视觉形态的改动才允许文字并标注「无视觉形态」）。每条带**编号 + 严重度（P0 / P1 / P2）+ 问题 + 复现路径（入口 / 步骤 / 现象 / 对照基线）+ 证据（截图 + 文件:行 / 实测值）+ 建议修法 + 完成勾选**（Run A 时全部未勾），按严重度分区；`shots/` 截图用相对路径嵌进页面。**只在对话里贴 Markdown 表、不落这个 HTML = 没有完成交付**。
6. **汇报 → ⏸ 停**：只给 `checklist.html` 的路径（`computer://` 链接）+ Top 3 最值得先看的问题 + 一句"审查后点名要修哪些"；**不在对话里重复全表**。等用户审查，不做任何修复动作。

### 问题的复现路径（每条必填 · 2026-11-03 用户口径）

| 栏 | 写什么 | 例 |
|---|---|---|
| **入口** | 菜单 / 页面 / URL（带参数） | 订单管理（URL 自动带 `?platform=temu`） |
| **步骤** | 可照做的 1→2→3，带页签 / 筛选 / 操作 | 切到 temu 页签 → 找到「生产工厂 / 工厂接单时间」列 |
| **现象** | 看到什么；Console / Network 报什么 | 显示 `2026-09-29 17:50:15`（带年份与秒） |
| **对照基线** | 同路径在基线（如 `main2` / 上一版）是否正常 | 基线显示 `09-29 17:50`，正常 |

**不合格写法**：只写「某处样式不对」「这里有问题」——用户照着复现不出来，等于没报。

## Run B · 修复与取证

**前置**：state.json 存在且含 approved 项；代码在本地；用户已点名范围（整体通过 = 清单里全部 P0–P2，或点名 id）。

**流程**：

1. **阶段 2b · 修复**：按批准范围逐条修复（release-blocker 优先清零）；state 回填 `open → approved → fixed`。**范围纪律**见硬门禁。
2. **阶段 3 · 修复证据**（`proof-of-fix/SKILL.md`）：对已修复问题做 before/after 取证——项目未 onboarding 先跑 `proof-of-fix-setup/SKILL.md`（生成 `.proof-of-fix/config.json` + 冒烟验证，需人在场）；`bin/phase.sh capture` 依赖 Node + Playwright + Pillow，不可用 → **降级**为 before/after 截图对（清单注明证据等级降了）。产出 `evidence/`（result.json + 像素标注图）。
3. **阶段 4 · 终验门禁**（`visual-acceptance/SKILL.md`）：修复后页面重新截图，逐页输出 pass/fail JSON（判据 = 用户会不会看出问题；有 visual-judge 类子代理则独立判）。
4. **回写清单 + 门禁**：把 `checklist.html` 更新——对应条目**完成勾选坐实**、after 列换成**真实修复后截图**（从 `evidence/` 取）、每条附 evidence 路径。全部 pass → state `fixed → verified`，重新交付更新后的 `checklist.html`；**fail → 回流阶段 2b，最多 2 轮**；2 轮后仍 fail → 如实汇报缺口，不假装通过。
5. 修复代码**不自动 commit**；要提交走 `生成提交`。

## 状态与契约

`.ui-pipeline/state.json` 是两段之间唯一的桥——Run A 与 Run B 可能隔了很久、甚至不在同一个会话，靠它衔接，不靠对话记忆：

```
.ui-pipeline/
├── state.json      # 问题列表：id / 描述 / 截图引用 / 优先级 / file:line /
│                   # 状态 open → approved → fixed → verified / 批准范围与时间 / 轮次
├── report.md       # Run A 审查报告（原始素材）
├── checklist.html  # 可视化优化清单（正式交付物：Run A 生成，Run B 回写勾选与 after 截图）
├── shots/          # 各状态截图（before / after）
└── evidence/       # Run B 阶段 3 的 result.json 与标注图
```

- 问题 id `P<级别>-<序号>` 贯穿两段不许换号；每阶段结束**先写 state.json 再汇报**。

## 工具映射（跨工具）

- **截图**：ZCode 用 `browser-use:control-browser`（多视口、多状态遍历）；其他工具用各自的浏览器 / Playwright 能力；都没有 → 向用户要截图，收到后照常跑 Run A。
- **判图**：终验（阶段 4）可调 visual-judge 类子代理（有就调，独立判官）；没有 → 主代理按 `visual-acceptance` 判据自己判。
- 🔴 `references/proof-of-fix/bin/` 是**第三方脚本**，首次运行前先通读一遍再用（来源见 `references/SOURCES.md`）。

## 原子 skill 的路径换算

收编后都在本技能 `references/` 下，原子 skill 原文里的旧路径按此替换：

| 原文写的 | 实际位置 |
|---|---|
| `.claude/skills/proof-of-fix/bin/phase.sh` | `references/proof-of-fix/bin/phase.sh` |
| ui-audit 内部的 `references/…`、`rules/…` | 相对 `references/ui-audit/` 自身目录解析 |
| `docs/proof-of-fix-contract.md` | `references/proof-of-fix/docs/`（缺则按 SKILL.md 内嵌 schema 执行） |

## 边界

- 只审**界面与前端**：后端逻辑归 `代码审查`；产品该不该做归产品决策；整站改版走 `界面优化设计`。
- 语言与用户一致（默认中文）；专有名词保留原文。
- 用户说「不用审查 / 跳过」→ 不跑，一句话确认。

## 来源（详见 references/SOURCES.md）

| 原子 skill | 上游 |
|---|---|
| walkthrough | qdouble/stack-contracts（agentic-ui-walkthrough） |
| ui-audit | mblode/agent-skills @ a3a42a1（skills/ui-audit） |
| proof-of-fix（含 setup） | leonbeckert/claude-proof-of-fix-skill |
| visual-acceptance | MashiroKai/Nebflow（skills/visual-acceptance） |

收编日期 2026-10-31；上游更新需手动同步。

## 触发示例

- 「界面审查一下订单详情页」→ Run A：出清单 → ⏸ 停，等审查
- （用户看完清单）「通过，P1 全修，P2 修前三个，我要前后对比」→ Run B：修复 → 证据 → 终验 → 交付
- 「只修 P1-2 和 P2-1」→ Run B 限定范围，其余保持 open
- 「清单第 3 条口径不对，重新看下」→ 回 Run A 补充/修正该条，仍不修复
- 「改完了吗？给我证据」→ state 里已有 fixed 项时单独补跑阶段 3 / 4
