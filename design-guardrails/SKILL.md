---
name: design-guardrails
description: "Mandatory design guardrails for any UI work, in any project. ALWAYS read this file before the first Write/Edit on UI files (HTML / CSS / Vue / React / JSX / 组件 / 样式文件) in the conversation if not already loaded. Covers: 界面对齐设计规范、场景基调判定、禁止项自查、设置页/仪表盘/空态结构、样式 lint、新旧项目的规范起手与现状盘点。Use for 设计界面, 改界面, 做页面, 写样式, UI, UX, 布局, 排版, 配色, 组件, 美化, 界面不好看, 设计规范, design, UI work, @界面设计规范. Listing in available_skills does not count as compliance; must Read file."
---

# 界面设计规范（design-guardrails）

面向**任意项目**的界面设计约束与流程。与 `development-guardrails`（管代码注释与调试）互补：**那个管代码层，这个管界面层**。

适用任何前端形态：原生 HTML+CSS、Vue、React、小程序、桌面应用界面。

## 强制响应（被发现时必须执行）

1. **Read 本文件**：在本对话中**第一次**即将修改界面文件前，若尚未 Read 过本 `SKILL.md`，**必须先 Read 全文**，再动手。
2. **判定项目状态**：是「新项目」还是「已有项目」？决定走哪条入口（见 §2）。
3. **确认规范文件存在**：项目根有 `DESIGN.md` 吗？
   - **有** → 先 Read 它，它是该项目的视觉唯一真源，优先级**高于本 skill 的通用建议**。
   - **没有** → 走 §2 的「起手」，用 `references/design-md-template.md` 生成骨架。
4. **交活前自查 + 跑 lint**：见 §5。

**禁止**：跳过 Read 直接改界面；项目有 DESIGN.md 却按通用建议改（会破坏该项目自己的取舍）。

## 1. 触发清单

| 场景 | 本 skill |
|---|---|
| 新增/修改界面、样式、布局、组件 | ✅ 必读必守 |
| 用户说"不好看""没设计感""AI 味重" | ✅ 走 §3 质检 |
| 新建项目要起一套设计规范 | ✅ 走 §2 新项目入口 |
| 已有项目要提升界面水平 | ✅ 走 §2 已有项目入口 |
| 只读代码、只解释、不改界面 | — |
| 纯后端 / 数据逻辑 / 命令行工具 | — |

## 2. 两条入口，一条主干

```
新项目   → ① 定基调 → ③ 找方向 → ④ 固规范 → ⑤ 实现 → ⑥ 质检与回灌
已有项目 → ① 定基调 → ② 现状盘点 → ③ 找方向 → ④ 固规范 → ⑤ 实现 → ⑥ 质检与回灌
```

**除「② 现状盘点」外，两类项目完全同轨。**

| 步 | 做什么 | 参考 |
|---|---|---|
| ① 定基调 | 判定"像工具还是像落地页"，锁三个旋钮 | `references/tone-lock.md` |
| ② 现状盘点 | **仅已有项目**：抽出隐含规范、找不一致、补缺、记债 | `scripts/audit_tokens.py` + `references/workflow.md` |
| ③ 找方向 | 生成 3–4 版自包含 HTML 方案 + 对比页供挑选 | `references/concept-gallery.md` |
| ④ 固规范 | 写进 `tokens.css` + `DESIGN.md`（值 + 何时用） | `references/design-md-template.md` |
| ⑤ 实现 | 新项目从零写；已有项目**定点升级，不推倒重来** | `references/anti-patterns.md` |
| ⑥ 质检与回灌 | 审计 → 修 → 把不满意的决策补成一条规则 | `scripts/lint_styles.py` + `references/tooling.md` |

**已有项目的硬纪律**：①不推倒重来 ②不迁移框架 ③**先固规范再动界面**（边改边定规范 = 一边施工一边改图纸）。

## 3. 项目内的文件约定

任何项目都建议有这几个文件（由 §2 的起手生成）：

| 文件 | 作用 | 谁维护 |
|---|---|---|
| `DESIGN.md` | **视觉唯一真源**：token 值 + 何时用 + 禁止项 + 场景基调 | 人与 AI 共同积累 |
| `AGENTS.md` / `CLAUDE.md` | 自动加载的硬规则（几行，指向 DESIGN.md，**不复制 token 值**） | 一次性 |
| `tokens.css`（或等价） | 所有颜色/字号/间距/圆角/阴影/动效变量 | 改值只改这里 |
| `scripts/lint_styles.py` | 机检：硬编码色值 / px 字号 / 裸 z-index | 一次性 |
| `.git/hooks/pre-commit` | 提交时自动跑 lint（可选但强烈建议） | 一次性 |

## 4. 自查清单（速查，详表见 references）

改界面前后逐条过：

**颜色**：只用 token，不写裸色值；语义色不做装饰；一屏 accent ≤2 处；禁渐变/霓虹；颜色不单独承载信息。
**字与间距**：只用 token 档位；不新增第 8 档字号；间距走网格；正文行高 1.5–1.6。
**形状与层级**：圆角容器必须 `overflow:hidden`；阴影/z-index 走 token；展开动画用 `grid-template-rows` 不用 `max-height`；不重复造 keyframes。
**交互**：禁原生 `alert/confirm/prompt`；异步必须有 loading；不首屏空白；空态给"图标 + 一句话 + 主 CTA"；破坏性操作二次确认。

→ 完整清单与出处：`references/anti-patterns.md`
→ 结构模式（设置页 / 仪表盘 / 空态 / 表单）：`references/structure-patterns.md`

## 5. 交活前（必做）

1. 对照 §4 自查，并对这六项自评 1–5 分：**主张 / 层级 / 执行 / 具体性 / 克制 / 变化**，任一项 <3 先改再交。
2. 跑 lint：

```bash
python3 <本skill>/scripts/lint_styles.py --dir <项目web目录>
```

必须 PASSED。

3. 若项目有 `DESIGN.md`，确认本次改动**没有违背其中已有条目**；若确实需要违背，先改规范再改代码。

## 6. 参考文档（按需加载，不要全读）

| 文件 | 什么时候读 |
|---|---|
| `references/tone-lock.md` | 步骤①，判定场景基调与三个旋钮 |
| `references/workflow.md` | 步骤②，已有项目的现状盘点怎么做 |
| `references/concept-gallery.md` | 步骤③，出 3–4 版方案并生成对比页让人挑 |
| `references/anti-patterns.md` | 步骤⑤⑥，写界面与自查 |
| `references/structure-patterns.md` | 做设置页 / 仪表盘 / 空态 / 表单时 |
| `references/tooling.md` | 步骤③⑥，外部工具该用与不该用 |
| `references/design-md-template.md` | 新项目起手，生成 DESIGN.md 骨架 |
| `scripts/audit_tokens.py` | 步骤②，扫描现有代码抽出隐含规范 |
| `scripts/lint_styles.py` | 步骤⑥，机检 |
| `scripts/make_gallery.py` | 步骤③，把多版方案并排成对比页 |
