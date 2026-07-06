---
name: test-case-authoring
description: "When the user asks to add, write, improve, or create tests or test cases (编写测试, 增加测试, 测试用例, E2E, 端到端, Playwright, Cypress, spec, unit/integration test), assume they expose a known or suspected defect: run tests after authoring and treat green as likely bad test design unless the user explicitly ignores pass/fail. Do not fix production code after authoring to make tests pass. For browser E2E, monitor console/pageerror, allowlist noise, add [E2E-DIAG] only when needed. Aliases: e2e-console-monitoring (merged). Read entire SKILL.md before writing tests."
---

# 测试用例编写（红灯验收 + E2E 控制台）

当用户说**增加 / 编写 / 优化 / 补充测试或测试用例**（含 E2E）时：

1. **Part A — 红灯验收**：默认用测试钉住当前认为有问题（或待修）的行为；跑绿优先怀疑用例写错；**写完不要自动修产品**消红。  
2. **Part B — E2E 控制台**（仅浏览器 E2E）：监听 console / pageerror，失败时输出报告；按需、可开关地加 `[E2E-DIAG]`。

> 原独立 skill `e2e-console-monitoring` 已并入本文 Part B。

---

# Part A：红灯验收

## 默认假设（最重要）

| 默认 | 含义 |
|:---|:---|
| **要写的是「会失败」的用例** | 对**当前**代码基线运行后，**预期为红（fail）** |
| **跑完是绿的** | 优先怀疑**用例写错了**（断言过弱、测错对象、mock 掉缺陷、setup 不对），应**只改测试**直到能稳定复现问题，或向用户说明为何绿可能是合理的 |
| **编写完成后** | **禁止**自动修改业务/生产源码去消红；只交付用例 + 失败输出 + 简要解读 |
| **用户明确豁免** | 仅当用户明确表示 **「只编写 / 不考虑红还是绿 / 不用跑 / 不用管过不过」** 等，才可不按红灯验收、可不跑测、可不因「绿了」而返工用例 |

## 与其他 skill 的关系

| skill | 关系 |
|:---|:---|
| `change-advice` | 用户说「先别改」时，同样**不改产品代码**；本 skill 额外约束「写完测试也不修产品」 |
| `development-guardrails` Part A | 改测试代码时按需补注释 |
| `development-guardrails` Part B | 用例**本身**跑不通（环境、语法）且缺证据时，可先 Part B；**不等于**去修被测业务。Part B 的 `[DEBUG:slug] REPORT` 与 Part B 本文 `[E2E-DIAG]` 分工不同（见 §E2E 诊断） |
| `change-impact-regression` | 本 skill 管「写测试这一轮」；改产品后的影响面清单仍用 change-impact-regression |

## 何时必须 Part A

- 用户说：编写测试、增加测试、写测试用例、补 spec、单元 / 集成 / **E2E** 用例等  
- 为 bug、回归**新增**断言或新文件  
- 「帮我写个测试复现 xxx」

**可不按红灯验收：** 用户明确只编写、不考虑红绿；纯测试重构且不断言语义；用户**另起任务**要求修到绿。

## Part A 核心规则

| 必须 | 禁止 |
|:---|:---|
| 归纳**预期失败点** | 无预期写烟雾测试糊弄 |
| 编写后**运行**最小范围测试 | 只提交不跑 |
| **红** → 交付失败摘要并**停** | 见红后自动改业务代码 |
| **绿** → §绿灯返工（未豁免时） | 默认把绿当完成 |
| 交付：命令、红/绿、失败在证什么 | 顺手修产品 |

## Part A 工作流程

```
1. 意图：测什么？认为哪里有问题？
  → 2. 框架、目录、同类用例风格
  → 3. 编写用例（断言对准问题，少 mock）
  → 4. 运行测试
  → 5. 红 → §交付物，结束（不修产品）
        绿 → §绿灯返工（除非豁免）
  → 6. 若是 E2E → 继续 Part B
```

## 绿灯返工（仅改测试）

1. 断言过弱  
2. 测错层（mock 替代真实路径）  
3. setup 掩盖问题  
4. assert 了现状而非应有行为  
5. E2E 选错选择器/等待  

仍绿且确信产品已对 → 说明偏差，**仍不修产品**，除非用户改口。

## 交付物（编写完成时）

```markdown
## 测试编写结果

- **文件**：…
- **运行命令**：…
- **结果**：🔴 失败（符合预期） / 🟢 通过（已返工 N 次 / 用户豁免 / 说明）

### 失败摘要（若为红）
- 用例名：…
- 关键断言/错误信息：…
- **表明的问题**（1～3 句）

### E2E 控制台（若适用）
- 采集方式、allowlist 变更、`[E2E-DIAG]` 与 `[E2E-CONSOLE-REPORT]`

### 说明
- 未修改业务源码（除非用户另行要求）。
```

## 用户话术对照

| 用户说法 | 行为 |
|:---|:---|
| 「写测试复现 xxx」 | 红灯验收；红则交付 |
| 「只写测试，不考虑红绿」 | 可绿即停 |
| 「写完并修到绿」 / 「修 bug」 | 新任务，用户明确授权修产品 |
| 「优化 E2E / 抓 console」 | Part A（若在写用例）+ Part B |

---

# Part B：E2E 控制台监控与诊断

在**新增或优化 E2E / 端到端 / UI 自动化**时，把浏览器控制台（含未捕获异常）当作一等信号。

## 何时必须 Part B

- 编写或改动 E2E 用例（与 Part A 常同时触发）  
- 「看控制台有没有报错」「E2E 要抓 console」  
- E2E 失败但 trace 不够，需 console 证据  

**可省略 Part B：** 纯单元/集成（无浏览器）；用户「不用管控制台」。

## Part B 核心规则

| 必须 | 禁止 |
|:---|:---|
| 监听 `error` 级 console 与 `pageerror` | 用例绿但 console 有未解释 error |
| 失败时**一次性**输出控制台摘要 | CI 刷屏 log |
| **allowlist** 已知噪声并注释原因 | 把未修 bug 放进 allowlist 换绿 |
| `[E2E-DIAG]`：前缀统一、默认关、仅 E2E 环境 | 生产路径永久 console.log |
| 跑一遍相关 E2E 核对控制台 | 只改 spec 不跑 |

## Part B 工作流程

```
1. 框架与现有 fixture
  → 2. 接入 console + pageerror 采集
  → 3. 运行 → 记录噪声 → 更新 allowlist
  → 4. 步骤与断言；必要时 wait / 选择器
  → 5. 仍不够？按需 [E2E-DIAG]
  → 6. 再跑；失败含控制台摘要
```

## 测试侧：控制台采集

### Playwright

```typescript
type ConsoleEntry = { type: string; text: string; location?: string };

function attachConsoleMonitor(page: import('@playwright/test').Page, bucket: ConsoleEntry[]) {
  page.on('console', (msg) => {
    const type = msg.type();
    if (type === 'error' || type === 'warning') {
      bucket.push({ type, text: msg.text(), location: msg.location()?.url });
    }
  });
  page.on('pageerror', (err) => {
    bucket.push({ type: 'pageerror', text: err.message });
  });
}

function formatConsoleReport(entries: ConsoleEntry[]): string {
  if (entries.length === 0) return '(no console errors/warnings captured)';
  return entries.map((e) => `[${e.type}] ${e.text}${e.location ? ` @ ${e.location}` : ''}`).join('\n');
}
```

断言：步骤后 `expect(filtered(entries)).toEqual([])`，或 attach 后再断言。

### Cypress

在 `support/e2e.ts` 用 `window:before:load` 劫持 `console.error` 汇总；结束用自定义 command 或 `should('be.empty')`。

### Allowlist

```typescript
/** 每条须注释原因与何时可删 */
export const ALLOWED_CONSOLE_PATTERNS: RegExp[] = [
  /ResizeObserver loop limit exceeded/,
];
```

## 按需：`[E2E-DIAG]`

仅在 trace/network 仍不够时；可开关 env；临时排查用应用内 log，**默认关**；测试 harness 采集**保留**。

```typescript
function e2eDiag(step: string, data: Record<string, unknown>) {
  if (!import.meta.env.VITE_E2E_DIAG) return;
  console.info(`[E2E-DIAG] ${step} ${JSON.stringify(data)}`);
}
```

与 `development-guardrails` Part B：手工复现、单次 `[DEBUG:slug] REPORT`；勿混用 slug 规范。

## 失败时的控制台报告

```text
[E2E-CONSOLE-REPORT] spec: auth/login.spec.ts > logs in
[error] Failed to load resource: 401 /api/me
[pageerror] Cannot read properties of undefined (reading 'role')
[E2E-CONSOLE-REPORT] END
```

---

## 质量检查（全文）

**Part A**

- [ ] 已 Run 测试；未豁免时绿已返工  
- [ ] 未擅自改业务源码消红  
- [ ] 交付含失败摘要与「表明的问题」  

**Part B（E2E）**

- [ ] 已采集 console / pageerror；allowlist 合理  
- [ ] 失败可见 `[E2E-CONSOLE-REPORT]` 或 attach  
- [ ] `[E2E-DIAG]` 默认关、无生产泄漏  
