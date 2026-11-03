---
name: agent-html-skills
description: "单文件 HTML 产物工具集（19 个子技能收编自 f-labs-io/agent-html-skills，MIT）：UI 原型与多方案对比、交互式 playground、before/after 对比矩阵、可拖拽脑图、架构图 / ER 图 / SVG 流程图、CSV/JSON 数据浏览器、研究报告 / spec / RFC、幻灯片、时间线路线图、交互式测试清单、一次性数据编辑器、代码审查演示件；支持双向反馈（页面上的操作回传给 agent，需 Node）。当用户说「出个 HTML demo / 做个对比页 / 画个脑图 / 架构图 / ER 图 / 出幻灯片 / 数据浏览器 / 时间线」或需要把方案做成可交互单文件时使用。"
---

# HTML工具集 · 19 个单文件 HTML 子技能（agent-html-skills）

社区技能 `f-labs-io/agent-html-skills`（MIT）的原样收编：**一律产出自包含的单文件 HTML**，打开即用。本技能是路由器——按需求挑子技能执行，子技能标准在 `references/skills/<子技能>/SKILL.md`（原样保留，不作独立技能发现）。

## 子技能一览

| 子技能 | 干什么 |
|---|---|
| `html-design-prototypes` | UI / 屏幕 / 组件 / 动画的对比原型（多方案并排，进选项前先做出来看） |
| `html-brainstorm-grid` | 头脑风暴网格：布局 / 组件 mockup 的多方案一屏对比 |
| `html-interactive-playground` | 参数调优 playground：滑杆 / 开关 / 实时预览（算法、动画、CSS 参数） |
| `html-comparison-matrix` | 对比矩阵：>2 个维度、>3 个候选、带权重的方案对比 |
| `html-mind-map` | 可拖拽脑图 / 概念图 |
| `html-architecture-diagrams` | 系统架构图：微服务地图、依赖图、部署拓扑、数据流 |
| `html-svg-diagrams` | SVG 技术图：流程图、时序图、状态机、数据流 |
| `html-erd-explorer` | ER 图 / 数据库 schema 可视化（可点击表、关系） |
| `html-data-explorer` | CSV / JSON / 日志数据浏览器：可过滤表格、分面、内联图表 |
| `html-research-reports` | 多源研究报告（代码库 / git 历史 / web / MCP 综合） |
| `html-spec-planning` | 项目 spec / 实施计划 / RFC / 提案富文档 |
| `html-slideshow-deck` | 键盘导航幻灯片（演讲 / 汇报 / onboarding） |
| `html-timeline-roadmap` | 时间线 / 路线图：状态 pill、依赖箭头、里程碑 |
| `html-testing-checklist` | 交互式测试清单：按端到端流程组织的真实测试计划 |
| `html-throwaway-editor` | 一次性数据编辑器：拖拽看板、表单式（用完即弃） |
| `html-design-tokens` | 设计 token 展示：色板、字阶、间距、圆角、阴影、动效 |
| `html-code-review` | 代码审查演示件：渲染 diff + 行内注释，讲清一个 PR |
| `html-skills-listen` | 🔌 双向反馈原语：启动本地接收器 + Monitor，HTML 页面上的操作**回传给 agent** |
| `html-skills-stop` | 🔌 关闭本次会话的接收器 |

## 双向反馈（本工具集的招牌能力）

普通用法：生成 HTML → 交付，用户自己看。**双向用法**：先跑 `html-skills-listen` 启动本地接收器（`server.js`，需 Node），再生成带提交按钮的页面（共享件 `assets/submit-handler.js`）——用户在页面上的操作 / 选择 / 批注会提交回本地，agent 读回后继续迭代。形成"生成 → 试用 → 反馈 → 再生成"闭环。用完跑 `html-skills-stop` 关掉。

- 需要 Node 与本地端口；不可用或端口受限 → 降级为静态交付 + 用户口述反馈，不要硬起服务。
- 该机制与本机 `browser-use` 的区别：双向反馈是**用户**在页面上操作；agent 自己操作页面走 `browser-use`。

## 路径换算

子技能原文里的 `assets/…`（blocks 模板、submit-handler.js）→ 本技能 `references/assets/…`；子技能内部相对引用按其所在目录（`references/skills/<子技能>/`）解析。

## 与相邻技能的分工

- **界面/页面怎么改**（方案与原型体系）→ `界面优化设计`；其"单文件 HTML 载体"可直接调用本工具集的具体子技能落地。
- **现有界面审查取证**（问题清单 + 修复前后证据）→ `界面审查`。
- 本技能定位：**快速产出自包含 HTML 件**的执行工具箱，被上述技能或用户直接点名调用；不做方案决策、不做代码修复。

## 来源（详见 references/收编来源-HTML工具集.md）

上游 https://github.com/f-labs-io/agent-html-skills（MIT）@ a9ddeb2，收编日期 2026-10-31；上游更新需手动同步。

## 触发示例

- 「把这两个方案做成一页对比给我看」→ `html-comparison-matrix`（或 `html-design-prototypes`，看比的是 UI 还是选项）
- 「出个能点的原型，我试试再告诉你改哪」→ `html-skills-listen` + `html-design-prototypes`（双向反馈）
- 「给这套设计出个色板 / token 页」→ `html-design-tokens`
- 「把这份 CSV 做成能筛的页面」→ `html-data-explorer`
- 「下周的汇报帮我出个幻灯片」→ `html-slideshow-deck`
