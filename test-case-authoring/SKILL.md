---
name: test-case-authoring
description: "Tests workflow in three parts—pick by user intent. Part A: add/write test cases (编写测试, 增加测试, 测试用例)—expect red on current code, do not fix product after authoring unless user asks. Part B: E2E console/pageerror monitoring when writing or improving browser tests. Part C: test-driven debugging (测试驱动调试, 用测试查, 跑 spec 调试, 测试失败排查, debug with test, failing spec)—Agent runs tests, adds harness diagnostics and console capture as needed, reads [TEST-DEBUG-REPORT] from terminal/attach before fixing product. Read entire SKILL.md. Aliases: e2e-console-monitoring (merged into Part B)."
---

# 测试用例（Part A 编写 + Part B E2E 控制台 + Part C 测试驱动调试）

先判意图，再选 Part（**不可混用默认约束**）：

```
用户要测试相关？
  ├─ 编写/增加/优化用例（钉 bug、补覆盖）→ Part A（+ E2E 时 Part B）
  ├─ 用测试/spec 查原因、跑失败用例、测试驱动调试 → Part C（E2E 叠加 Part B 采集）
  └─ 仅优化 E2E 控制台基建、抓 console → Part B
```

| Part | 典型触发 | 跑测后能否修产品 |
|:---|:---|:---|
| **A 红灯验收** | 写测试、加用例、写 spec 复现 | **否**（默认交付失败用例） |
| **B E2E 控制台** | 编写/改 E2E、监控 console | 随 A 或 C |
| **C 测试驱动调试** | 用测试查 bug、跑 failing spec、测试失败帮我查 | **是**（有 REPORT 后再最小修复） |

> 原 `e2e-console-monitoring` 已并入 Part B。

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
| `development-guardrails` Part B | **手工复现**且无 spec 时用手动 collector + `[DEBUG:slug] REPORT`；**已有/可写 spec 时优先 Part C**。与 `[E2E-DIAG]` / `[TEST-DIAG]` 勿混 slug |
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
| 「跑这个 spec 查原因」「测试失败排查」 | **Part C**（+ E2E 时 Part B） |

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

**Part C 调试 E2E 时：** 默认在 fixture 启用 Part B 采集；失败时将 console 段落并入 `[TEST-DEBUG-REPORT]`（见 Part C §报告格式）。

---

# Part C：测试驱动调试

用**测试 runner** 复现 bug 时：Agent **自行运行**用例，在 **harness / 可开关诊断** 中**按需**加采集点，从终端或 attach 读取 **一份** `[TEST-DEBUG-REPORT]`，**再**做根因判断与修复（可改产品代码）。与 Part A「写完不修产品」**相反**，仅在有 Part C 触发时使用。

## 何时必须 Part C

- 用户要用测试查因：跑 failing spec、测试驱动调试、测试失败帮我查、debug with test  
- 已有失败用例，静态 diff 不足以定位  
- `development-guardrails` Part B 触发，且路径**已有或可写最小 repro spec**（**优先 Part C**，勿先要求用户手工复现）

**不进入 Part C（仍用 Part A）：** 用户明确「只写测试 / 写完别修」；用户只要新增钉住问题的用例并交付红灯。

## Part C 核心规则

| 必须 | 禁止 |
|:---|:---|
| **Agent 自己 Shell 跑**最小范围测试命令 | 只改代码不跑、让用户贴一行断言 diff |
| 证据不足时**先加采集**（fixture console、mock 调用摘要、`TEST_DEBUG` / `[TEST-DIAG]`）再跑第二轮 | 无 REPORT 盲改 `src/` |
| 失败/结束时输出 **一份** `[TEST-DEBUG-REPORT]`（含断言、console、关键 step） | 复现中途散落 log、多次让用户贴片段 |
| 根因结论与修复**仅基于** REPORT + 代码 | 忽略 console / mock 证据猜修 |
| 验证通过（重跑 spec）后**删除**临时 `[TEST-DIAG]` 与应用内临时 log | 永久留调试 log |
| E2E：**复用 Part B** fixture；调试轮次失败报告合并进 TEST-DEBUG-REPORT | 用例绿但 console 有未解释 error 就宣布修好 |

## Part C 工作流程

```
1. 确认 spec 路径或写最小 repro（可临时 test.only / 单文件）
  → 2. 查项目是否已有 extended test / setup（优先复用）
  → 3. 跑一轮 → 读终端输出
  → 4. 证据够？否 → 加 harness 采集（Part B 若 E2E）或 [TEST-DIAG] / network 摘要 hook
  → 5. 再跑 → 生成 [TEST-DEBUG-REPORT]（Agent 从终端/attach 自行读取，勿要求用户复制）
  → 6. 据 REPORT 最小修复（产品或测试）
  → 7. 重跑 spec 验证；清理临时 DIAG；改产品后适用 change-impact-regression
```

## 主动加哪些调试信息（按需）

| 层级 | 何时加 | 方式 |
|:---|:---|:---|
| **Harness** | 默认 E2E / 首次跑失败 | Part B `attachConsoleMonitor`；Vitest/Jest `afterEach` 打印 mock.calls 摘要 |
| **测试步骤** | 不知停在哪一步 | `test.step` / 软断言前 `diag('after-submit', { url, status })` 写入 report 数组 |
| **应用** | trace + harness 仍不够 | `[TEST-DIAG]` 或 `[E2E-DIAG]`，`process.env.TEST_DEBUG` / `VITE_E2E_DIAG`，默认关 |
| **Network** | 怀疑 API | Playwright `page.on('response')` 只记失败 URL/status；勿全量 HAR 刷屏 |

加点位原则：**少而准**；每轮调试只 flush **一份** REPORT。

## `[TEST-DEBUG-REPORT]` 格式

测试失败或 `afterEach` / 全局 teardown 时**打印一次**（Playwright 可 `test.info().attach('test-debug-report.txt', …)`）：

```text
[TEST-DEBUG-REPORT] START
{
  "slug": "login-role-undefined",
  "spec": "auth/login.spec.ts",
  "case": "shows dashboard for admin",
  "command": "pnpm exec playwright test auth/login.spec.ts --reporter=line",
  "assertionError": "Expected …",
  "steps": [
    { "step": "goto-login", "t": 120 },
    { "step": "submit", "t": 890, "status": 401 }
  ],
  "console": [
    { "type": "pageerror", "text": "Cannot read properties of undefined (reading 'role')" }
  ],
  "notes": "optional: mock call summary, last response url"
}
[TEST-DEBUG-REPORT] END
```

Agent **必须**在改产品前从本轮 Shell 输出或 attach 中取得上述区间内容；若缺失字段，补采集后**再跑一轮**，仍只交付一份新 REPORT。

### Playwright：失败时 flush 示例

```typescript
// 临时调试结构，问题关闭后可保留 harness、删 test 内 __report 若仅调试用
test.afterEach(async ({}, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    const body =
      '[TEST-DEBUG-REPORT] START\n' +
      JSON.stringify({ slug: '…', console: consoleBucket, steps: stepLog }, null, 2) +
      '\n[TEST-DEBUG-REPORT] END';
    console.log(body);
    await testInfo.attach('test-debug-report.txt', { body, contentType: 'text/plain' });
  }
});
```

## Part C 与 Part A / guardrails Part B

| | Part A | Part C | guardrails Part B |
|:---|:---|:---|:---|
| 目的 | 交付失败用例 | 查因并修复 | 手工复现无 spec |
| 修产品 | 禁止（默认） | 允许（有 REPORT 后） | 允许（有 REPORT 后） |
| 采集 | 可选 Part B | harness + REPORT 必选 | 应用内 collector |
| 谁跑 | Agent 跑测 | **Agent 跑测并读 REPORT** | Agent 或用户复现 |

## Part C 交付（修复轮次结束时）

- 使用的命令与 spec  
- 引用的 `[TEST-DEBUG-REPORT]` 要点（或确认已从终端读取）  
- 根因一句话 + 改动文件  
- 重跑 spec 结果  
- 已删临时 `[TEST-DIAG]` / 临时 collector（保留 fixture 控制台监听若项目需要）

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

**Part C（测试驱动调试）**

- [ ] Agent 已自行跑 spec，未要求用户零散贴 log  
- [ ] 改产品前已有 `[TEST-DEBUG-REPORT]`（E2E 含 console）  
- [ ] 未与 Part A 混淆（写用例轮次未擅自修产品）  
- [ ] 验证后已清理临时 DIAG；修产品后按需 change-impact-regression  
