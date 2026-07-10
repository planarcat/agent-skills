---
name: impact-surface-audit
description: "仅在功能修改基本完成、用户明确要求做「最终复查 / 全面影响面检索 / 深度回归审计」时触发，用于系统性挖出改动对**非本功能相关模块**的隐性辐射，尤其是共用组件 / 共用函数 / 样式合约类被改动后，其它引用它的功能模块（如共用选择器被改布局后引起的其它面板白屏这类案例）。触发词严格：「对代码进行影响面检索」「做一次影响面复查」「最终影响面审计」「共用模块辐射检索」「全量影响面复查」「深度回归检查」「full impact audit」「impact surface audit」。⚠️ 平时改代码收尾用 `change-impact-regression`；仅当用户明确说是「最终 / 全面 / 深度 / 全量」的复查、并强调关心「其它无关功能是否被顺带影响」时，才 Read 本 skill。禁止在普通的一次改动收尾中自动触发。"
---

# 影响面深度审计（Impact Surface Audit）

面向**修改基本完成后的最终复查**。目标不是「本次功能是否达标」（那是 `change-impact-regression` 的活儿），而是回答一个更专业化的问题：

> **本轮改动里，有没有哪个共用组件 / 共用函数 / 共用样式 / 共用配置被动过、且它的其它使用方（非本次功能）会被顺带影响？**

典型案例（本 skill 存在的原因）：改共用组件 `ContainerTemplateSelector.vue` 内部滚动区从 `min-height: 100%` 改成 `flex: 1 1 0 + height: 0`，容器蒙版侧宿主 flex 链完整、能正常渲染；但同一组件在**图片羽化 → 图形选择**面板复用时，宿主 (`LayerSettingSubPanelShell / imageCropAttr`) flex 链断裂，子面板整片白屏。这类"改共用模块殃及无关功能"的回归，是 `change-impact-regression` 那种"收尾清单"最容易漏掉的类型。

---

## 与其他 skill 的边界

| skill | 使用时机 | 检索深度 |
|:---|:---|:---|
| `change-advice` | 改之前，先讨论怎么改 | 只分析当前问题 |
| `development-guardrails` | 改之中，注释 / 埋点 | 不做影响面 |
| `change-impact-regression` | **一般改动收尾**（默认自动执行） | 常规 d=1/d=2 upstream + 回归清单 |
| **`impact-surface-audit`（本 skill）** | **用户明确要求「最终 / 深度 / 全面」复查** | **穷尽式扫描共用点 × 所有已知盲区** |
| `record-change-log` / `record-development-blog` | 复查后归档 | — |

**关键差别**：`change-impact-regression` 有可能被自动附带执行；本 skill **只在用户明确用触发词请求时执行**，不做默认附带。

---

## 何时必须触发（严触发）

用户输入含以下**任一强触发词**（大小写不敏感）：

- 「**对代码进行影响面检索**」
- 「**做一次影响面复查**」
- 「**最终影响面审计**」
- 「**共用模块辐射检索**」
- 「**全量影响面复查**」
- 「**深度回归检查**」
- 「**改动的辐射面全面查一下**」
- 「**full impact audit**」
- 「**impact surface audit**」

**弱信号（可疑但不必然）**：用户使用了「全面 / 深度 / 最终 / 全量 / 穷尽 / 复查 / 审计」+「影响 / 回归 / 辐射」组合。此时**先向用户确认一句**「这次要走深度审计流程吗？（比常规收尾更慢，会跨仓查图 + 兜底 grep + 样式合约检查）」再决定是否触发。

**禁止触发的场景**（避免过度打扰）：

- 用户只说「改完了」「帮我看下有没有问题」——用 `change-impact-regression`
- 用户只说「测什么」「有哪些回归」——用 `change-impact-regression`
- 用户还在写代码 / 还在讨论方案——不触发
- 用户明说「简单看一下就行」「不用太细」——不触发

---

## 前置条件

触发本 skill 前，代理必须确认：

1. **本轮改动已完成**（有 commit / 有暂存 / 有工作区 modified）
2. **知道 diff 范围**：能列出被改的所有文件、跨仓情况（是否涉及多个仓库）
3. **知道被改动中包含哪些"共用点"**（组件、util、hook、mixin、样式变量、类型、后端 Service/公共 Bean）——这是本 skill 的检索核心

若前置条件不满足，先补 `git status` / `git diff --stat` / 手工列共用点，再进入下面的工作流。

---

## 工作流总览

```
Phase 0. 索引与工具体检
   ↓
Phase 1. 归纳"共用点"（改动中的公共暴露面）
   ↓
Phase 2. 静态图检索（GitNexus MCP，多角度）
   ↓
Phase 3. 图盲区兜底（grep / IDE 引用 / 依赖分析）
   ↓
Phase 4. 样式 / DOM / 布局合约检查（GitNexus 图不覆盖的领域）
   ↓
Phase 5. 跨仓与运行时耦合（前后端契约、iframe、messaging）
   ↓
Phase 6. 汇总："共用点 → 其它非本功能消费方 → 建议回归"
```

**输出物**：一张表 + 一份「必须回归清单」+ 一份「已排除清单」，交付给用户。**必须显式列出 GitNexus 覆盖不到的领域**，让用户知道哪些是图给的、哪些是 grep 补的、哪些是人肉判断的。

---

## Phase 0：索引与工具体检

在动 GitNexus 之前先做 3 件事：

1. **列可用 MCP**：调用 `list_mcp_resources` / `list_mcp_resource_templates`，确认 `gitnexus`（或 `user-gitnexus`）在线。
2. **读仓库 context**：对本次涉及的每个仓库，`READ gitnexus://repo/{name}/context`，**记录索引 commit 与当前 HEAD 的偏差**。
3. **决定是否重索引**：
   - 图上 commit = HEAD → 直接用
   - 图上 commit 落后 HEAD ≤ 10 且改动**不涉及**新增大量共用点 → 直接用，但在结论里注明「图相对 HEAD 落后 N commits」
   - 图落后 > 10 或本次新增共用点 → **询问用户**是否允许 `pnpm analyze:*` / `npx gitnexus analyze` 重索引

不要不打招呼就重索引（耗时可能很长）。

**CLI vs MCP**：MCP 提供 `resources` 类只读入口；`impact` / `detect_changes` / `cypher` 需要通过 CLI（`gitnexus impact` / `gitnexus cypher` 等）或对应 MCP 工具调用。**已知坑**：`gitnexus detect-changes --scope compare --base-ref X` 在某些版本会退化成"仓库全量陈述"，此时改用 `impact upstream` 逐符号扫描（见 Phase 2）。

---

## Phase 1：归纳"共用点"清单

把本轮 diff 里所有被修改的**对外暴露面**枚举成一张表：

| 类别 | 示例 | 找法 |
|:---|:---|:---|
| **导出函数 / 常量** | `export function foo`、`export const CFG` | `grep -nE 'export (const|function|async function|type|interface|class)'` |
| **共用组件 / SFC** | `packages/ui/*.vue`、`src/components/shared/*` | 组件路径包含 `shared / common / components` |
| **hook / composable / util** | `useX.ts` / `utils/*.ts` | 名字前缀 |
| **共用 store / context / 全局单例** | Pinia store、React context、window.* | grep `defineStore`、`createContext`、全局挂载 |
| **共用样式 / CSS 合约** | 顶层 flex 链、CSS variables、mixin | 改动含 `<style>` / `.less` / `.scss` |
| **共用类型 / interface** | `types.ts` 里被多处 import 的类型 | grep `export (type|interface)` |
| **共用配置 / 常量文件** | `constants.ts`、`env` 使用点 | 改动路径含 `config / constants / env` |
| **后端公共 Bean / 拦截器 / AOP / Filter** | `@Configuration`、`@ControllerAdvice`、`@Aspect` | 注解筛选 |
| **后端跨模块 API** | `*-api` 模块下的 provider / DTO | 路径含 `-api` |
| **DB Schema / 迁移** | flyway / liquibase / SQL | 改动含 `.sql` / `db/migration/` |
| **API 契约** | Controller 路由 / DTO 字段 | 前端 `src/api/*` + 后端 `Controller` |
| **消息 / 事件 / postMessage** | 事件名字符串常量、Bus / EventEmitter | grep `emit(` / `postMessage` |
| **共享静态资源** | 图标、字体、JSON 数据 | 改动路径含 `assets/data` |

**记录时区分**：
- **"本功能内的共用点"**（比如本次容器蒙版新加的 hook 只在容器蒙版侧用）——回归本功能即可
- **"跨功能的共用点"**（比如全站 axios 拦截器依赖的 `getLttk`）——**这才是本 skill 的重点**

---

## Phase 2：静态图检索（GitNexus MCP，多角度）

对 Phase 1 表里每个**跨功能共用点**至少跑一遍以下检索。**每种查法各有盲区，必须组合**。

### 2.1 符号级 upstream 影响面（首选）

```
gitnexus impact <SymbolName> \
  -r <RepoName> \
  -f <FilePath> \
  --direction upstream \
  --depth 2 \
  --summary-only
```

- 目标：拿到 `impactedCount` / `risk` / `direct` / `modules_affected`
- 风险 = MEDIUM/HIGH，或 impactedCount ≥ 10 的符号，**再跑一次不带 `--summary-only`** 拿完整消费方列表
- 命名歧义时用 `-f <file>` 或 `--kind Function|Class|Method|Const` 或 `--uid <uid>`

### 2.2 文件级 IMPORTS 反查（Vue SFC / CSS / 非符号文件必查）

`gitnexus impact` 在**File 类节点**上返回 `Target not found`——所以 Vue 单文件组件、`.vue` / `.less` / `.json` 这类"整文件即单位"的共用点，必须用 Cypher 直接查 `IMPORTS` 边：

```cypher
MATCH (a)-[r:CodeRelation {type:'IMPORTS'}]->(b:File)
WHERE b.filePath CONTAINS '<被改共用文件路径片段>'
RETURN a.filePath AS from, b.filePath AS to
LIMIT 100
```

对每个 importer **再递归一层**（把 importer 当 target 再查一次），构建 d=2 的文件级依赖树。**这一步是本 skill 存在的核心动作**——上面案例里的图片羽化白屏，就是这一层没查到导致的。

### 2.3 diff → 符号 / 执行流映射

```
gitnexus detect-changes --scope <all|staged|unstaged> -r <RepoName>
```

看 `Affected processes` 段落——这是 `impact` 拿不到的**执行流级**证据，特别适合捕获"多个符号协作构成的一条用户路径被打断"。

**注意**：`--scope compare --base-ref X` 目前不可靠（见 Phase 0），别依赖它。

### 2.4 API 路由改动

若 Phase 1 表里出现 Controller / route handler：

```
gitnexus api_impact --route <route> -r <RepoName>
```

拿"路由 → 消费者 → 字段访问"三段式；`shape_check` 做 shape 漂移检查。

### 2.5 跨仓联动

若 diff 涉及多仓（例如后端改 DTO 字段、前端 `src/api` 里对应类型），`gitnexus group_list` + `gitnexus://group/{name}/contracts` 拿契约表。

### 2.6 图裸查（兜底）

`gitnexus cypher --repo X '<query>'` 用来查 schema 里定义了但 CLI 没直接命令的关系：

- 「谁 `ACCESSES` 我改的字段」→ 属性访问漂移
- 「谁 `IMPLEMENTS` 我改的接口」→ 实现类是否需要同步
- 「谁 `EXTENDS` 我改的基类」→ 子类是否漏配

先读 `gitnexus://repo/{name}/schema` 熟悉可用节点/边类型再写查询。

---

## Phase 3：图盲区兜底（grep / IDE / 依赖）

以下场景 GitNexus 图**捕获不到或捕获不全**，必须 grep 补齐：

| 盲区 | 兜底手段 |
|:---|:---|
| **TS type-only imports**（`import type { X }`） | `grep -rn 'X'` 或 `rg` |
| **Vue template 里的组件使用** | 图上的 IMPORTS 边基本能覆盖，但注册组件后**是否真的用了**要看 `<template>`；`rg '<CompCateListWrap' apps/web/src` |
| **prop / event 具体传值** | 需要在 template 中 grep prop 名（如 `manageable`）看具体调用点 |
| **通过字符串引用的符号**（动态 import、`resolveComponent('X')`、`app.component('X', ...)`） | `rg "'X'"` |
| **注解式装配**（Spring `@Autowired`、`@Component` 隔间接注入） | 图捕获，但**AOP / `@ControllerAdvice`** 类的横切影响用注解 grep 更快：`rg '@SaCheckPermission'` |
| **反射 / SPI / ServiceLoader** | 图完全捕获不到；找 `META-INF/services` |
| **构建时代码生成（proto / graphql / openapi）** | 生成物在 build 目录不一定被索引 |
| **CSS class 名字符串命中 DOM** | 见 Phase 4 |

每次 grep 都记录搜到的文件数，若 ≠ 图上 upstream 数，说明有一方漏了，两者取并集。

---

## Phase 4：样式 / DOM / 布局合约检查（图完全不覆盖）

**这是最关键、也最容易漏的领域**。GitNexus 当前 schema 里**没有** STYLE 边、CSS class 边、DOM 层级边、flex 合约边。以下类型改动必须**人肉**审查每个 importer：

- 组件根节点 `display` / `flex` / `grid` / `position` 变更
- 组件内部对**"父级必须有确定高度 / min-height: 0"** 的隐含要求（尤其是 `flex: 1` + `height: 0` 的滚动区写法）
- CSS variables / theme tokens 的新增或语义变化
- z-index / stacking context 边界变化
- 事件冒泡 / capture 阶段的 `stopPropagation` 变化
- `<slot>` 结构、`v-model` 语义变化

**方法**：对 Phase 2.2 拿到的每个 importer，**打开它的 `<template>` + `<style>`**，回答两个问题：

1. 它是否满足新组件的隐含合约？（flex 链是否完整、父级是否有 min-height: 0、slot 是否传对）
2. 用户视觉可见的地方，是否会出现"塌成 0 / 溢出 / 遮挡 / 错层"？

如果无法确定，**必须**在回归清单里把这个 importer 标为「视觉冒烟必测」，并写清"打开 X 面板 → 看 Y 区域是否非空"。

若组件已知有此类隐含合约，建议在其源文件顶部补一条**"宿主合约"注释**（development-guardrails Part A 意义上的守卫注释），例如：

```ts
// 宿主合约：父级链必须 flex + min-height: 0，否则内部滚动区高度算作 0（白屏）
```

---

## Phase 5：跨仓与运行时耦合

以下运行时耦合图也捕获不好，必须专项排查：

- **iframe / postMessage / BroadcastChannel**：消息事件名、payload 字段
- **前端 → 后端 API**：request body / response shape 是否漂移
- **前端 axios 拦截器 / 中间件**：全局请求头、token 注入逻辑
- **权限系统的注解 / RBAC**：`@SaCheckPermission("x:y:z")` 权限码是否与前端 `hasPerm('x:y:z')` 对得上
- **DB schema / 迁移**：本次是否加了列 / 索引 / 唯一约束，读取 SQL 端的模块回归
- **消息队列 / 定时任务**：topic 名、schedule 触发点

对每一项在 Phase 1 命中的都要列出「谁生产、谁消费」，两端都要回归。

---

## Phase 6：汇总与交付

**必须输出以下四段**：

### 6.1 索引状态

- 每个涉及仓库的：**索引 commit vs 当前 HEAD**、**是否重索引**、**样本查询用时**
- 明确说「哪些 phase 用了 MCP、哪些是 grep 兜底、哪些是人肉审查」

### 6.2 共用点 × 其它非本功能消费方（核心表）

```markdown
| 共用点 | 类别 | 直接消费方（d=1） | 跨功能消费方 | 风险 | 检索手段 |
|:---|:---|:---|:---|:---|:---|
| ContainerTemplateSelector.vue | 共用 SFC | 5 个 importer | ⚠️ imageCropAttr / imageGeometryMaskShapeAttr（图片羽化，非本功能） | 中 | Cypher IMPORTS 边 + Phase 4 样式合约 |
| getLttk | util 函数 | request.ts / outpainting.ts / aiJobs.ts | ⚠️ 全站 axios 拦截器 + 所有 AI 面板 | 中 | impact upstream d=2 |
```

**列的顺序按跨功能影响面从大到小**。**没有跨功能消费方**的共用点也要列，但标注「仅本功能内消费，可跳过跨模块回归」。

### 6.3 必须回归清单（Must Regress）

只列**跨功能可能被顺带影响**的场景，每条要有：

- 入口（URL / 菜单 / 按钮）
- 操作步骤（3-7 步）
- 通过标准（"XXX 面板打开后模板网格非空且滚动正常"这种可观测描述）
- 检索依据（引用 6.2 表里哪一行）

**本功能内的常规回归留给 `change-impact-regression`，本 skill 不重复。**

### 6.4 已排除清单（Excluded）

明确列出「查过但确认不受影响」的共用点及理由，避免用户以为漏查。

### 6.5 未覆盖领域（Known Gaps）

诚实列出本次没能自动化查到的领域，例如：

- 「CSS flex 合约靠人肉审 3 个 importer，未做视觉快照测试」
- 「反射 / SPI 未查，本仓无此类使用」
- 「跨仓 group 契约表未启用（未配置 group.yaml）」

---

## 质量自检（交付前）

- [ ] Phase 0 已 READ 每个涉及仓库的 `context`，并声明索引 vs HEAD 偏差
- [ ] Phase 1 共用点表已区分「本功能内」/「跨功能」
- [ ] Phase 2 每个跨功能共用点至少跑过 **符号级 impact + 文件级 IMPORTS Cypher** 两种查法
- [ ] Phase 3 对图盲区做了 grep 兜底并对比数量差
- [ ] Phase 4 对含 `<style>` 改动的共用组件，人肉审查了每个 importer 的宿主合约
- [ ] Phase 5 若涉及 API / 权限 / iframe / DB，做了两端匹配
- [ ] Phase 6 输出的四段完整、消费方均可回溯到证据
- [ ] 交付时明确标注了「哪些是 MCP、哪些是 grep、哪些是人肉」
- [ ] 未把猜测写成必测

---

## 触发示例

**正确触发**：

- 「本次改动基本完成了，**对代码进行影响面检索**，重点看有没有殃及其它无关功能」
- 「帮我做一次**深度回归检查**，尤其是共用组件被改后其它面板」
- 「**共用模块辐射检索**一下」
- 「**最终影响面审计**」
- 「**full impact audit**」

**不应触发（用 `change-impact-regression`）**：

- 「我改完了，有哪些回归要做」
- 「测什么」
- 「影响哪些模块」
- 「commit 前该测什么」

**不应触发（用 `change-advice`）**：

- 「先别改，告诉我怎么改」
- 「这是什么原因」

---

## 反面案例（本 skill 的初始动机）

设计器仓 `4f812dd` 提交里，`ContainerTemplateSelector.vue` 内部滚动区从 `min-height: 100%` 改为 `flex: 1 1 0 + height: 0`，隐含要求"父级链 flex + min-height: 0"。当时的常规收尾漏了两处 importer：

- `LayerSettingWrap.vue → imageCropAttr.vue → ContainerTemplateSelector.vue`（图片羽化 → 选图形）
- `LayerSettingWrap.vue → imageGeometryMaskShapeAttr.vue → ContainerTemplateSelector.vue`

结果：图片羽化图形选择面板整片白屏。原因分层：

1. 用 `gitnexus impact ContainerTemplateSelector` **符号查文件**——返回 `Target not found`（图 schema 里 SFC 是 File 节点，不是符号节点）。
2. 即使改用 Cypher 查到了 5 个 importer，GitNexus **没有 STYLE / 布局合约边**，无法自动判断"其中 2 个宿主 flex 链断裂"。
3. `change-impact-regression` 是"常规收尾"力度，未对每个 importer 逐个开 `<style>` 审查。

本 skill 的存在就是为了在**用户明确要求最终复查**时，把 Phase 2.2（文件级 IMPORTS）+ Phase 4（样式合约人肉审）这两步**强制走完**，堵住这类回归。


---

## 工具与能力（Tools & Capabilities）

本 skill 的所有 Phase 都依赖具体的外部工具或代理能力。**执行时必须**：

1. 在进入每个 Phase 前先声明「本 Phase 需要哪些工具」；
2. 若某个工具不可用 / 未安装 / 未授权 / 调用失败 / 返回明显异常，**不能默默跳过**——必须在交付里显式记录（见下方 §失败与降级报告规范）；
3. 尽量选择等价的降级手段继续推进，而不是直接终止审计。

### 工具与能力全表

| # | 工具 / 能力 | 归类 | 用途 | 出现在哪个 Phase | 常见失败模式 | 降级方案 |
|:---|:---|:---|:---|:---|:---|:---|
| 1 | `list_mcp_resources` / `list_mcp_resource_templates` | MCP 元数据 | 探测可用 MCP 服务器与资源模板 | 0 | MCP 服务器名不匹配（如 `user-gitnexus` vs `gitnexus`）；MCP 服务未启动；返回空 | 直接尝试用 `read_mcp_resource` 拿几个常见 URI；仍失败则跳过 MCP，全走 CLI |
| 2 | `read_mcp_resource` — `gitnexus://repos` | MCP 资源 | 拿到已索引仓库清单、路径、索引 commit | 0 | 资源不存在；返回 stale 数据 | 用 `gitnexus list` CLI |
| 3 | `read_mcp_resource` — `gitnexus://repo/{name}/context` | MCP 资源 | 单仓概览、索引新鲜度、可用工具列表 | 0、2、3 | 仓库未索引；MCP 报 stale | 用 `gitnexus status` / 直接读 `.gitnexus/` 目录 |
| 4 | `read_mcp_resource` — `gitnexus://repo/{name}/schema` | MCP 资源 | 熟悉图 schema，写 Cypher 前必读 | 2.6 | 同上 | 用 `gitnexus cypher 'CALL SHOW_TABLES()'` 之类命令探测 |
| 5 | `read_mcp_resource` — `.../processes` / `.../process/{name}` / `.../clusters` | MCP 资源 | 执行流列表 / 单流追踪 / 功能区域 | 2.3 | 数量截断；processes = 0 | 用 `gitnexus detect-changes` 输出的 Affected processes 字段 |
| 6 | `gitnexus impact` CLI | 图查询 | 符号级 upstream / downstream 影响面 | 2.1 | `Target not found`（对 File 节点、Vue SFC 常见）；命名歧义；`impactedCount: 0 + risk: UNKNOWN` | 转用 Phase 2.2 的 Cypher IMPORTS 反查；或加 `-f` / `--kind` / `--uid` 消歧 |
| 7 | `gitnexus cypher` CLI | 图裸查 | 文件级 IMPORTS 反查、`ACCESSES` / `IMPLEMENTS` / `EXTENDS` 关系 | 2.2、2.6 | Cypher 语法错误（如 `type()` 函数不存在）；变量未在作用域 | 参照 `schema` 资源的 example_queries；改用 `[r:CodeRelation {type:'X'}]` 语法 |
| 8 | `gitnexus detect-changes` CLI | diff→图映射 | 把当前 git diff 映射到符号 + Affected processes | 2.3 | `--scope compare --base-ref` 在部分版本退化为全量陈述；`--scope all/staged/unstaged` 需要工作区脏 | 逐符号 `impact upstream` 兜底；或直接 `git diff --name-only` + 对每个文件跑 Phase 2.1/2.2 |
| 9 | `gitnexus api_impact` / `route_map` / `shape_check` CLI | API 图 | 路由/handler/字段消费者分析 | 2.4 | 前端未被索引；后端路由注解未识别 | 前端 `src/api` 目录 grep 路由字符串；前后端各自 `grep -rn` 字段名 |
| 10 | `gitnexus group_list` / `gitnexus://group/{name}/contracts` | 跨仓契约 | 多仓库 group 契约表 | 2.5 | 未配置 group.yaml；contracts 为空 | 手工列前后端契约对应关系，标注为"手工"数据源 |
| 11 | `gitnexus analyze` CLI | 索引更新 | 索引落后时重新构建 | 0（可选） | 耗时长；WSL/HF 镜像不通；索引损坏 | **必须先征询用户**；征询被拒则继续用旧索引并在报告注明"图相对 HEAD 落后 N commits" |
| 12 | `gitnexus list` CLI | 元数据 | 快速列已索引仓库（等价 #2） | 0 | CLI 不在 PATH（尤其是 WSL 内） | 直接读 `~/.gitnexus/registry.json` |
| 13 | Shell / PowerShell / WSL bash | 系统 | 跑所有 CLI、grep、git 命令 | 全 Phase | WSL 未启动；PATH 缺失；CRLF/换行问题；heredoc 语法差异 | 换 shell（PowerShell ↔ bash）；写脚本到临时文件再 `sed -i 's/\r$//'` 修复行尾 |
| 14 | `git status` / `git diff --stat` / `git log` | Git | 摸清本轮 diff、涉及仓库、commit 范围 | 0、1 | 工作区在多仓根（如工作区非仓库）；已 stash | 逐仓 `cd Apps/xxx && git ...` |
| 15 | grep / ripgrep (`rg`) | 全文检索 | 图盲区兜底（type-only import、字符串引用、注解、CSS class） | 3 | 目录太大超时；未安装 `rg` | 退化到 `grep -rn`；分目录跑 |
| 16 | 源码阅读（`<template>` / `<style>` / Java 注解） | AI 能力 | Phase 4 样式合约人肉审；Phase 5 前后端契约核对 | 4、5 | 文件过大；样式散落多文件；被 `<style scoped>` 或 CSS-in-JS 隐藏 | 分段读；先看根节点样式，再看嵌套滚动容器 |
| 17 | IDE 静态诊断（`read_lints` 等） | AI 能力 | 快速拿当前文件类型 / lint 报错 | 4、6 | 大 monorepo 时未跑；报错噪声 | 命令行跑 `pnpm typecheck` / `mvn compile` |
| 18 | 项目脚本（`pnpm test` / `pnpm typecheck` / `mvn` 等） | 运行时 | 跑单测 / 全量 typecheck / 后端编译作为兜底验证 | 6 | 依赖未装；耗时；网络需求 | 只对本轮改动相关模块跑；报告注明"XX 未跑" |
| 19 | `update_plan`（如果代理宿主提供） | 状态追踪 | 声明进入每个 Phase | 全 Phase | 宿主不支持 | 用文本条目手工追踪 |
| 20 | 用户交互（询问是否重索引 / 是否允许跑重活） | 协作 | 关键路径决策 | 0、6 | 用户不响应；用户明确拒绝 | 走最保守方案（不重索引，继续），并在报告显式声明 |

### 使用原则

- **MCP 优先，CLI 兜底，grep 补漏，人肉最后**——顺序不可颠倒（否则会漏 Phase 2.2 的文件级 IMPORTS 边）。
- **每次工具调用后必须校验输出**：`impactedCount: 0 + risk: UNKNOWN` 在 `impact` 里几乎等同于"没查到"，不能当"无影响"来用；`error` 字段出现即视为该次调用失败。
- **不许"假装用过"**：如果 MCP / CLI 没真的跑通，就不要在报告里编造 impactedCount / d=1 数字。宁可标记"未用"。

---

## 失败与降级报告规范

**Phase 6 的交付里必须包含一段「工具与能力可用性报告」**（作为 6.1 的一部分或独立成 6.0）。样例格式：

```markdown
## 工具与能力可用性

| 工具 / 能力 | 状态 | 说明 |
|:---|:---|:---|
| GitNexus MCP `gitnexus://repos` | ✅ 可用 | 4 个仓库在线 |
| GitNexus MCP `gitnexus://repo/laitu-designer/context` | ✅ 可用；⚠️ 索引落后 HEAD 0 commits | 无需重索引 |
| `gitnexus impact <SFC 名>` | ❌ 失败 | `Target not found`——SFC 是 File 节点，不是符号；已改用 Cypher IMPORTS 反查（Phase 2.2）补齐 |
| `gitnexus detect-changes --scope compare --base-ref X` | ⚠️ 退化 | 返回全仓统计而非 diff 范围；已放弃该模式，改用逐符号 `impact upstream` |
| `gitnexus cypher '…type()…'` | ❌ 失败 | Catalog exception: function TYPE does not exist；已改用 `[r:CodeRelation {type:'IMPORTS'}]` 语法通过 |
| `gitnexus analyze` | ⏭️ 未运行 | 用户未授权重索引；索引落后 HEAD 0 commits，可以接受 |
| `gitnexus api_impact` | ⏭️ 未使用 | 本轮无 API 路由改动 |
| Cypher 裸查（`ACCESSES` / `IMPLEMENTS`） | ⏭️ 未使用 | 本轮无接口 / 属性访问级改动 |
| WSL bash | ✅ 可用 | 用于所有 CLI 调用 |
| PowerShell heredoc → bash 脚本 | ⚠️ 首次失败 | CRLF 问题，已 `sed -i 's/\r$//'` 修复 |
| grep / rg 兜底 | ✅ 使用 | 用于 TS type-only 引用、CSS class 命中、Spring `@SaCheckPermission` 计数 |
| IDE `read_lints` | ⏭️ 未使用 | 本轮无 lint 目标 |
| `pnpm typecheck` / `mvn compile` | ✅ 已跑 | typecheck 8/8 绿；后端相关模块 mvn compile 通过 |
| 用户交互（确认重索引） | ✅ 已征询 | 用户回复继续用现索引 |

**结论**：GitNexus MCP 静态图覆盖了 X% 的检索目标；`gitnexus impact` 对 Vue SFC 类文件级共用点无效，已通过 Cypher IMPORTS 反查 100% 补齐；样式 / CSS flex 合约不在图 schema 内，靠 Phase 4 人肉审 N 个 importer 兜底。
```

### 状态标记

| 图标 | 含义 |
|:---|:---|
| ✅ 可用 | 工具正常运行且返回有意义结果 |
| ⚠️ 部分可用 / 降级 | 工具能跑但结果异常（返回退化、需 workaround），已用降级方案 |
| ❌ 失败 | 工具不可用 / 报错 / 无有效返回；必须说明**用什么手段填了这个缺** |
| ⏭️ 未使用 | 本轮工作范围用不到；**必须说明为何用不到**（避免让用户以为漏查） |

### 报告规则

1. **每个在 §工具与能力全表 中列出的工具**，交付时都要在这张表出现一行，状态不能省略。
2. **每个 ❌ 或 ⚠️ 的工具**必须给出：失败现象 + 降级手段 + 降级后是否补齐了该 Phase 目标。
3. **每个 ⏭️ 未使用**都要给出跳过原因，不能只写"未用"。
4. 若某个 Phase 的核心工具全线失败（例如 GitNexus MCP + CLI 都不可用），**必须在报告的"未覆盖领域（Known Gaps）"里以醒目方式标注**——不能让用户以为该 Phase 走完了。

