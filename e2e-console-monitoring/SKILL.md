---
name: e2e-console-monitoring
description: "When adding or improving E2E tests, monitor browser/page console errors and warnings, fail or report on unexpected output, and add minimal targeted console diagnostics only where the test harness cannot observe enough. Use for E2E, 端到端, e2e test, Playwright, Cypress, Puppeteer, WebdriverIO, 集成测试, 浏览器控制台, console error, pageerror, 优化测试用例, 补充 E2E. Read entire SKILL.md before editing E2E specs or related app hooks. Complements development-guardrails (app debug) and change-impact-regression (E2E as regression)."
---

# E2E 控制台监控与诊断输出

在**新增或优化 E2E 用例**时，把**浏览器控制台**（含未捕获异常）当作一等信号：用例应能**采集、断言或归档**控制台问题；仅在现有断言与 trace 仍不足以定位时，**按需**在被测应用或测试辅助代码中增加**有前缀、可开关**的控制台报告。

## 与其他 skill 的关系

| skill | 阶段 | 与本 skill 的分工 |
|:---|:---|:---|
| `development-guardrails` Part B | 手工复现、修 bug | 复现会话 collector + 单次 REPORT；**不替代** E2E 内的持续控制台监听 |
| **本 skill** | 编写/改 E2E | 用例级控制台采集、失败时输出报告、按需 E2E 诊断 log |
| `change-impact-regression` | 改源码后收尾 | 影响面清单里可把相关 E2E 标为必测；本 skill 不负责列影响面 |

**协作约定：** 同一轮若既改 E2E 又改业务源码，改 E2E 时适用本 skill；若还适用 `development-guardrails`，应用内临时埋点仍按 Part B（修完删除），E2E 侧持久化的 `page.on('console')` 等**保留在测试代码**中。

---

## 何时必须执行

满足 **任一** 即 Read 并遵守本 skill：

- 新增、修改、拆分、稳定化 E2E / 端到端 / UI 自动化用例
- 用户要求「看控制台有没有报错」「E2E 要抓 console」
- E2E 失败但截图/trace 看不出原因，需要从控制台补证据
- 为某条用户路径补回归，且该路径曾出现前端 console error / pageerror

**可省略：**

- 纯单元/集成测试（无浏览器）
- 只改 CI 配置且未动用例逻辑
- 用户明确「不用管控制台」

---

## 核心规则

| 必须 | 禁止 |
|:---|:---|
| 每条（或每个 describe）E2E 路径监听 `error` 级 console 与 `pageerror` / 未捕获异常 | 用例通过但页面/console 仍有未解释的 error |
| 失败时在断言或 `afterEach` 中**一次性**输出本轮采集的控制台摘要 | 每个 `console.log` 都打印到 CI 标准输出（刷屏） |
| 已知第三方/环境噪声用 **allowlist** 显式列出并注释原因 | 无 allowlist 地 `expect(console).toBeEmpty()` 导致 flaky |
| 按需加诊断输出：带统一前缀、默认关、仅测试/E2E 环境开 | 为 E2E 永久往生产路径加 `console.log` |
| 代理或本地**跑一遍**相关 E2E（或最小 repro spec）核对控制台 | 只改 spec 不运行就交付 |

---

## 工作流程

```
1. 确认框架（Playwright / Cypress / …）与现有 E2E 基建（fixture、base test）
  → 2. 接入或复用控制台采集（error + pageerror）
  → 3. 运行目标用例，记录现有 console 噪声 → 更新 allowlist
  → 4. 编写/优化步骤与断言；必要时补 wait、network idle、角色选择器
  → 5. 仍缺上下文？按需加 [E2E-DIAG] 诊断点（应用或 test helper）
  → 6. 再跑用例；失败报告须含控制台摘要
  → 7. 交付：说明采集方式、allowlist 新增项、是否加了诊断输出
```

---

## 测试侧：控制台采集（优先框架内置能力）

### Playwright（推荐模式）

在 **fixture 或 `test.beforeEach`** 中挂载，在 **`afterEach` 或断言失败时** 刷出摘要：

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

**断言策略（二选一或组合）：**

- **严格**：步骤结束后 `expect(filtered(entries)).toEqual([])`（`filtered` 去掉 allowlist）
- **软失败 + 硬断言**：先 `test.info().attach('console-report.txt', …)`，再对未 allowlist 的 error 断言

### Cypress

- `cy.window()` 无法回溯历史 console → 在 **`app` 的 `support/e2e.ts`** 用 `Cypress.on('window:before:load', win => { … })` 劫持 `console.error` 写入数组，或在插件层汇总。
- 测试结束用 `cy.wrap(consoleErrors).should('be.empty')` 或自定义 command 输出报告。

### 其他框架

原则相同：**监听 error/warning + 未捕获异常**；失败时把采集结果附到测试输出。项目已有封装时**复用**，不重复造轮子。

---

## Allowlist（已知噪声）

维护在项目内固定位置（如 `e2e/allowed-console-patterns.ts` 或 spec 顶部常量）：

```typescript
/** 第三方脚本或本地 dev 已知无害报错；每条须注释原因与工单/版本去除条件 */
export const ALLOWED_CONSOLE_PATTERNS: RegExp[] = [
  /ResizeObserver loop limit exceeded/,
];
```

- 新增 allowlist 条目时：**必须**注释「为何无害、何时可删」
- 禁止把「还没修的业务 bug」放进 allowlist 换绿

---

## 按需：应用或测试侧诊断输出

仅在 **E2E + trace/network 仍无法解释失败** 时添加，且满足：

1. **前缀统一**：例如 `[E2E-DIAG]`，便于测试 log 与生产 log 区分  
2. **可开关**：`import.meta.env.VITE_E2E_DIAG`、`process.env.E2E_DIAG`、或 `window.__E2E_DIAG__`（仅 test 环境注入）  
3. **点位少而准**：关键状态迁移、路由 guard、提交结果、错误边界 — 每步 3～8 个字段，JSON 一行  
4. **生命周期**：临时排查用的应用内 log，问题解决后**删除或默认关闭**；测试 harness 的采集逻辑**保留**

示例（应用内，仅 E2E 诊断开时）：

```typescript
function e2eDiag(step: string, data: Record<string, unknown>) {
  if (!import.meta.env.VITE_E2E_DIAG) return;
  console.info(`[E2E-DIAG] ${step} ${JSON.stringify(data)}`);
}
```

**与 `development-guardrails` Part B 的区别：** Part B 面向**单次手工复现**、结束 flush **一份** `[DEBUG:slug] REPORT`；E2E 诊断可以是**多步 info** 且由测试运行自动收集，二者可并存，但不要混用同一 slug 规范以免混淆。

---

## 失败时的控制台报告格式

测试失败时，输出或 attach **一份**摘要（便于 CI 与 AI 排查）：

```text
[E2E-CONSOLE-REPORT] spec: auth/login.spec.ts > logs in
[E2E-CONSOLE-REPORT] steps: fill form → submit → expect dashboard
[error] Failed to load resource: 401 /api/me
[pageerror] Cannot read properties of undefined (reading 'role')
[E2E-CONSOLE-REPORT] END
```

Playwright：优先 `test.info().attach`；Cypress：写入 `cy.task`  log 或失败 hook。

---

## 交付清单（向用户说明）

完成 E2E 改动后，简短说明：

- [ ] 控制台如何采集（fixture / 全局 hook / 单 spec）
- [ ] 是否新增或修改 allowlist 及原因
- [ ] 是否运行过相关 spec 及结果
- [ ] 是否新增 `[E2E-DIAG]`（位置、开关 env、是否临时）
- [ ] 失败时能否看到 `[E2E-CONSOLE-REPORT]` 或等价 attach

---

## 质量检查

- 用例绿屏时，是否仍检查了 console（或 strict 模式已断言无未 allowlist 的 error）？
- allowlist 是否过宽？
- 应用内诊断是否已关默认、无生产泄漏？
- 是否与项目现有 E2E 模式（Page Object、storageState、并行）一致？
