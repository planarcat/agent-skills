---
name: change-impact-regression
description: "After modifying application source code, produce an impact surface list (features, components, modules) and concrete regression test methods to catch indirect behavior drift. Prefer GitNexus MCP (user-gitnexus: detect_changes, impact, api_impact) when available to map diff to dependents and execution flows. Use when finishing a fix, refactor, or feature; when the user asks for 影响面, 回归测试, 改动范围, 测什么; or alongside development-guardrails after any non-trivial code edit. Must Read before delivering the post-change summary if this skill applies."
---

# 改动影响面与回归测试

在**完成一批源码改动之后**（向用户汇报「改好了」之前），基于真实 diff 与调用关系，列出受影响对象，并给出可执行的回归测试方法。目标是：**覆盖直接改动与合理推断的间接影响**，降低「未改动的模块行为悄悄漂移」的风险。

## 与 development-guardrails 的关系

| skill | 阶段 | 作用 |
|:---|:---|:---|
| `development-guardrails` Part A | 改代码**过程中** | 注释守卫 |
| `development-guardrails` Part B | 排查问题**过程中** | 调试埋点与 REPORT |
| **本 skill** | 改代码**完成后** | 影响面清单 + 回归怎么测 |

**不建议把本 skill 全文并入 `development-guardrails`：** 前者是「改时约束」，本 skill 是「改后交付」；合并会让单次 Read 过长，且 User Rules 已绑定 guardrails。推荐 **独立 skill + guardrails 文末交叉引用**。

**协作约定：** 本对话中若已因改代码适用 `development-guardrails`，在**同一轮改动收尾**时默认同时执行本 skill（无需用户再 @）。

---

## 何时必须执行

满足 **任一** 即在本轮改动收尾产出影响面与回归说明（无源码改动则跳过）：

- 修改了应用源码（`src/`、业务脚本、API、UI 组件等），且改动**非纯格式化/纯注释**
- 用户要求说明影响面、回归范围、怎么测
- 修复 bug、重构、改公共 API/共享状态/配置/路由/权限
- 改动涉及被多处引用的模块、hooks、store、工具函数、样式变量

**可省略（仍建议一句话说明「影响面仅限 X」）：**

- 仅改测试文件且行为与生产代码无关
- 仅改文档、Plans、skill，无源码
- 用户明确「不用写回归清单」

---

## 工作流程

```
1. 归纳本轮 diff（改了什么文件、什么行为）
  → 2. 【优先】GitNexus MCP 检索影响面（见 §GitNexus）
  → 3. 划分：直接改动 vs 间接受影响（图结果 + 人工补全业务名）
  → 4. 按功能/组件/模块列清单并标注风险
  → 5. 为每项给出具体测试方法（优先可命令化）
  → 6. 区分必测 / 建议测，交付给用户
```

---

## GitNexus MCP（检索影响面）

当 Cursor 已启用 **`user-gitnexus`** MCP 且目标仓库已索引时，**必须先尝试**用 GitNexus 补充/校验影响面，再写交付清单。调用前阅读 MCP 工具 schema（`impact`、`detect_changes`、`api_impact` 等）。

### 推荐调用顺序（改后收尾）

| 步骤 | 工具 | 用途 |
|:---|:---|:---|
| 1 | **`detect_changes`** | 将当前 git 改动映射到符号与 **affected processes**，得风险摘要；`scope` 用 `all`（或 `unstaged` / `staged` / `compare`+`base_ref` 视本轮改动范围） |
| 2 | **`impact`** | 对 diff 中**公共/核心符号**（改动的导出函数、类、共享 util）逐个 `direction: "upstream"`；hub 符号先用 `summaryOnly: true`，再按需分页 |
| 3 | **`api_impact`** | 若改动涉及 API 路由/handler，按 `route` 或 `file` 查消费者与字段依赖 |
| 4 | **`context`** / **`explain`**（可选） | 对 d=1 或高风险符号补全文件内上下文、职责说明 |

**深度与回归优先级（写入清单）：**

| GitNexus 深度 | 含义 | 回归建议 |
|:---|:---|:---|
| d=1 | 直接依赖，易直接破坏 | **必测** |
| d=2 | 间接依赖 | **必测或建议测**（结合 risk / affected_processes） |
| d=3 | 传递影响 | **建议测** |

**`detect_changes` 的 affected processes** → 在交付表格「对象」列优先写**执行流/流程名**，并据此设计端到端或场景回归。

### 参数要点

- **`impact`**：`target` + `direction: "upstream"`；歧义时用 `file_path` / `kind` / `target_uid`；默认 `maxDepth: 3`，`minConfidence` 可按需提高到 0.8。
- **多仓库**：按需传 `repo`；索引过期时终端执行 `npx gitnexus analyze`（或项目文档中的索引命令）后重试。

### MCP 不可用时的回退

- 未配置 GitNexus、索引缺失、或工具报错 → **不得**伪造图结果；改用 `git diff` + 代码内 grep/引用搜索，并在交付中注明「未使用 GitNexus，影响面为手工推断」。
- 仍可参考 `gitnexus-impact-analysis` skill 中的风险分级思路，但证据须来自 diff/代码。

---

## 影响面如何梳理

### 直接改动（必列）

- 本轮编辑的文件、函数、组件、路由、配置项
- 用户可见行为或对外契约（API 字段、事件名、props）的变化

### 间接受影响（按证据列，勿臆造）

优先采用 **GitNexus** `detect_changes` / `impact` 的 d≥2 项与 `affected_modules`、`affected_processes`；再人工补全：

从代码事实推断，例如：

- **调用方**：谁 import / 调用了被改符号
- **被调用方**：被改逻辑依赖的下层服务、存储、第三方 SDK
- **共享状态**：同一 store、context、全局单例、缓存键
- **同类路径**：同一 wizard、同一表单族、同一列表页模板
- **配置与开关**：feature flag、环境变量、构建常量

**禁止：** 无依据地写「整个系统都可能受影响」；每一项应能对应到 **diff、GitNexus 结果、或具体文件/符号**。

### 风险等级（清单内标注）

| 等级 | 含义 |
|:---|:---|
| **高** | 公共 API、鉴权、支付、数据写入、核心路径 |
| **中** | 多个页面/服务复用的组件或 util |
| **低** | 仅单页、单入口、或纯展示且契约未变 |

---

## 交付格式（必须包含）

向用户输出以下结构（可 Markdown，表格优先）：

```markdown
## 改动摘要

- {1～3 句话：本轮改了什么、意图是什么}
- 影响面来源：GitNexus MCP（detect_changes / impact / …） / 手工推断 / 混合

## 影响面清单

| 对象 | 类型 | 与本轮改动的关系 | 风险 | 为何可能漂移 |
|:---|:---|:---|:---|:---|
| {功能/模块/组件名} | 功能 / 组件 / 模块 / 执行流 | 直接修改 / d=1 / d=2 / … | 高/中/低 | {一句话} |

## 回归测试

### 必测（改完必做）

| # | 对象 | 测试方法 | 通过标准 |
|:---|:---|:---|:---|
| 1 | … | {手动步骤 或 命令} | {预期现象} |

### 建议测（时间允许）

| # | 对象 | 测试方法 | 通过标准 |
|:---|:---|:---|:---|

## 自动化（如有）

- 命令：`npm test -- …` / `pytest …` / 项目惯用脚本
- 说明：代理**应优先自行运行**仓库内已有测试；失败则纳入影响面再分析

## 未覆盖说明（可选）

- {若存在无法本地验证的项，说明依赖谁、在什么环境测}
```

---

## 测试方法怎么写才「可执行」

每条测试方法至少包含：

1. **入口**：从哪进（URL、菜单、CLI、API 路径）
2. **操作**：关键步骤（3～7 步为宜）
3. **数据**：需要的账号、fixture、开关状态
4. **通过标准**：可见结果、响应码、日志、断言

**优先顺序：**

1. 仓库已有单测/集成测/e2e — 给出**精确命令**与用例名
2. 代理能跑的脚本 — **代理自行跑**，把结果写进汇报
3. 仅人能点的 UI — 给逐步手工清单

**针对「非直接改动对象」：** 必须写清**测什么现象**能发现间接回归（例如：「未改动的列表页仍能排序，因共用同一 `useTable`」）。

---

---

## 与其他 skill 的关系

| skill | 关系 |
|:---|:---|
| `gitnexus-impact-analysis` | GitNexus 工具用法与 d=1/d=2 风险语义；本 skill 在**改后交付**场景下调用 MCP |
| `development-guardrails` | Part A/B 管改中与调试；本 skill 在改后收尾配合 |
| `e2e-console-monitoring` | 影响面清单中若推荐 E2E 回归，具体用例编写/控制台断言见该 skill |
| `test-case-authoring` | 用户主动「写测试」时：红灯验收与禁止写完修产品；与改后回归清单分工不同 |

## 与 Part B 调试的关系

- Part B 解决「**这一个 bug** 怎么拿运行证据」。
- 本 skill 解决「**这一轮改动** 还可能伤到哪里、改完怎么系统性地测一遍」。
- 若 Part B 已给出 `repro` 路径，**必测**中应包含：原 bug 复现路径 + 相关相邻路径各至少 1 条。

---

## 质量自检（交付前）

- [ ] 清单中每一项能对应到 diff、GitNexus 输出或调用/依赖关系
- [ ] 已启用 GitNexus 时：已调用 `detect_changes`（及必要的 `impact` / `api_impact`），或已说明为何未调用
- [ ] 「必测」覆盖所有**直接改动**的用户可见行为
- [ ] 至少 1 条针对**间接受影响**对象的回归（若存在合理间接风险）
- [ ] 未把「未验证的猜测」写成必测
- [ ] 已尝试运行项目内相关自动化测试（若环境允许）

---

## 触发示例

- 改完代码后用户说：「有哪些地方要回归？」
- 「这次改动影响哪些模块？」
- 「帮我列一下测试方法」
- 代理完成 fix/refactor 后向用户汇报前（默认附带本节交付）

**反例（不必单独 Read 本 skill）：**

- 只读代码、只回答架构问题、未改文件
- 用户只要 commit message，且未改源码
