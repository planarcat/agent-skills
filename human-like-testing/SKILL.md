---
name: 类人测试
description: "Human-like testing ONLY (no fixes): Agent operates a headed browser like a real user (look-snapshot → decide → click/type), explores and exercises the app, collects evidence (console/network/DOM), judges each scenario pass/fail, locates the failing layer, and delivers an evidence-chain test report with suspected root causes and fix directions — but never modifies any code. **Test accounts (lazy-init): read the `testAccounts` array in `Docs/工作区配置.json` first; if the needed role is missing, ask the user for it, append it to that array (keep valid JSON) immediately, and reuse it next time — never guess or self-register an account, never echo credentials into reports.** Use when user says 类人测试, 像人一样测试, 测一下, 自测, 点一遍验收, 测试报告, 验收一下, human-like testing, exploratory testing. Bootstrap rule: read the workspace 测试环境卡 first; if absent, bootstrap one interactively. Works for pure-web SPAs and hybrid shells (Tauri/Electron) via layer-descending. Not for writing test cases (use 测试用例编写), impact audits (use 影响面终审), or code fixes (user decides next step after the report)."
---

# 类人测试（有头浏览器实时操作 + 证据链测试报告，只测不修）

一句话定位：Agent **像真实用户一样**操作有头浏览器——边看边点、逐场景测试、取证、判定通过/不通过；发现问题**停在报告**（含疑似根因与修复建议方向），**不改任何代码**。交付的是**证据链测试报告**，不是口头保证。

## 硬边界（本 skill 不做的事）

- **不改产品代码**：发现 bug 只记录证据与定位，修复由用户决定后续走向
- **不写测试用例文件**：固化用例属于 测试用例编写；本 skill 只在报告里建议哪些场景值得固化
- **不搭测试框架**：不新增依赖、不加配置，只为测试需要的临时 mock 在会话内注入、用后即弃

## 与其他 skill 的分工

| 场景 | 用谁 |
|:---|:---|
| 写测试用例 / 红灯验收 / 测试驱动调试 | 测试用例编写 |
| 改完代码出影响面与回归清单 | 代码审查（影响面与回归） |
| 看完报告后要改：原因分析、修改方案 | 改动建议 / 方案（讨论阶段） |
| **像人一样操作页面，测试并出报告** | **本 skill** |

---

## 第 0 步：读「测试环境卡」（启动必做，跨工作区通用件）

本 skill 方法与项目无关；项目差异全部收敛在一张环境卡里。查找顺序：

1. 工作区根 `AGENTS.md` / `CLAUDE.md` 的「类人测试」章节
2. `docs/testing/测试环境卡.md`（或 `Docs/` 下同名文档）
3. 都没有 → **现场摸底生成**（起服务、看登录、试取证），请用户确认后落卡

环境卡七项，缺一先补齐再开测（**只写"从哪取"，不写明文凭据**）：

```markdown
## 测试环境卡
- 启动：<起 dev 的命令与前置条件>
- 地址：<dev URL / 应用启动方式>
- 登录与凭据：
  - 方式：<表单 / SSO / 短信验证码 / 扫码>
  - 账号：读 `工作区配置.json` 的 `testAccounts`，按 `role` / `end` 选（**缺哪条问用户要哪条**，要到写回 json，下次直接用）
  - 验证码：<交还用户手输 ｜ 测试环境固定码 ｜ 关闭校验>
- 页面形态：纯 Web / Tauri / Electron / 其他混合壳
- 桥接 mock：<如 @tauri-apps/api/mocks 的 mockIPC；无则写"无">
- 取证：<console/network/DOM 怎么拿；混合壳注明哪层可拿>
- 沉淀：<踩坑记录落点>
```

## 测试账号（读 `工作区配置.json` 的 `testAccounts` · 懒初始化 · 2026-10-20 用户口径 / 10-22 改）

**账号是 `工作区配置.json` 的 `testAccounts` 数组的一部分**（2026-10-22 起配置拆成 json 存值 + md 存规矩）——**一条 = 一个身份**：

```json
"testAccounts": [
  { "role": "factory-worker", "end": "F", "username": "<账号>", "password": "<密码>", "desc": "工厂端操作员，只看自己车间", "since": "YYYY-MM-DD" }
]
```

**流程（懒初始化，一步不多）**：

1. 开测前先读 `testAccounts` —— **里面已有需要的身份就直接用**，不再问
2. **没有这条身份 → 问用户一句**："这次要测 <场景>，需要 <某身份> 的账号，给我一个"——**只问当前需要的那条**
3. 用户给了 → **立刻追加进 `testAccounts` 数组**（保持合法 JSON，写完自检一次可解析；下次直接读，不用再问）→ 当次就用
   （**缺项铁律同样适用**：可以建议，不许自己拍值先写后干——见 `工作区配置`）
4. **不做的事**：不预置身份清单、不猜账号、不走注册流程造账号、不在报告与截图里复述密码

**为什么按 `role` 分**：权限差异类 bug（如「操作员不该看到批量下载按钮」）必须用低权身份测——所以**一个身份一条，用到哪个补哪个**，不预先规划。
**一条底线**：只收**测试环境**的号，生产 / 真实个人账号不入配置。

---

## 任务卡：三句话

```text
任务：<测什么，一句话>
环境：<分支或 worktree + 启动方式>
验收：<可判定的通过标准，多个场景就列场景清单>
```

判据示例：「Tab2 激活时列表只含 Tab2 数据，连切 20 次仍正确」「提交后列表出现新行且无 console 报错」。不接受「看起来正常」。没有判据时，与用户对齐后再开测；确属探索性测试（用户就是要你随便点找问题），在报告里注明「探索性」并列出走过的路径。

---

## 类人三标准（全程自检）

1. **决策在线**：每一步看页面实际状态（snapshot）后决定，不回放预写脚本
2. **感官真实**：读真实渲染结果（DOM/截图/控制台/网络），不读代码猜、不直调内部接口造状态
3. **路径与用户一致**：走 UI 入口点按钮、填表单，不绕过界面改 store/调接口

## 感官五件套

| 通道 | 用途 | 纪律 |
|:---|:---|:---|
| snapshot（可访问性树） | 主眼：每步操作前后看结构 | 主通道，文本快照优先于截图 |
| screenshot | 视觉专用：画布内容、布局错位、图片图表 | **禁止只靠截图判数据归属** |
| console_messages | 报错、警告、未捕获 rejection | 每个场景取证必查 |
| network_requests | 响应体对不对、到达顺序、旧请求是否取消 | 每个场景取证必查 |
| evaluate | 读 DOM 文本/属性、JS 状态，精确断言 | **数据归属一律 DOM 断言** |

- 等条件不 sleep：用条件等待，断言前确认相关响应已真正到达（防假绿）

---

## 测试循环（每个场景走一遍）

```
1. 明确该场景的通过判据
2. 像人一样操作：按真实用户路径走 UI（复现路径优先，再走正常路径）
3. 取证三件套：console + network + DOM（缺一不下结论）
4. 判定：通过 / 不通过
   不通过 → 分层定位：接口对 UI 错=前端；接口错=后端（只定位，不修）
5. 稳定性确认：换操作路径 / 边界条件（反向时序、连点 20 次、直接进目标页）
   复测 1~2 次，确认问题非偶发、通过非侥幸
```

单场景最多 3 轮重试，仍无法判定就在报告中如实标注「无法稳定复现」及已试路径。**不进入修复环节**。

## 稳定性条款

- **确定性复现 > 手速碰运气**：竞态/时序类用固定节奏操作序列（evaluate 驱动）重放，不靠快速点击赌概率
- **环境基线固定**：端口、测试账号、数据状态；多会话并行时相互隔离
- **选择器抗演化**：优先 `data-testid`/语义文本；发现易碎选择器**写进报告的「建议补 testid 清单」**，不直接改代码

## 防作弊条款（硬性）

- 禁止放宽判据、跳过场景、减少取证来「凑通过」
- 不通过就是不通过，如实报告；用户审的是证据，不是结论

## 混合壳降维原则（Tauri / Electron）

能降维就降维——同一问题在哪层能复现就在哪层测、就在哪层记录：

1. **Web 层（主战场，~80% bug）**：mock 桥接（Tauri 用 `mockIPC`），浏览器自动化直打 dev URL
2. **Webview 层**：需要真实桥接时开 devtools / 远程调试（CDP）
3. **原生壳层**：窗口/对话框/托盘等特有行为才下沉，OS 级自动化或官方 WebDriver 方案，取证靠日志+截图

---

## 测试报告模板（收尾必交付，落点按环境卡「沉淀」项）

```markdown
# 类人测试报告：<任务一句话>

- 环境：<分支/worktree、地址、测试时间>
- 任务 / 验收判据：<任务卡回显>

## 结果总览
| 场景 | 判据 | 结果 | 备注 |
|:---|:---|:---|:---|
| <场景1> | <判据> | ✅ 通过（复测 N 次） | |
| <场景2> | <判据> | ❌ 不通过（复现 M/2 次） | 详见问题记录 |

## 问题记录（每个不通过场景一份）
### 问题 N：<一句话现象>
- 操作路径：<怎么点出来的>
- 证据：
  - 网络顺序：<关键请求时序与响应体要点>
  - 控制台：<报错原文，或"无">
  - DOM 对比：<期望 vs 实际>
- 分层定位：<前端 / 后端 / 需要更多信息>
- 疑似根因：<一句话推测 + 依据>
- 修复建议方向：<不改代码，只给方向，如"疑似竞态，建议请求序号守卫或 AbortController">

## 建议（可选）
- 值得固化回归的场景：<列场景，交 测试用例编写>
- 建议补 testid 的位置：<列元素，不直接改>

## 结论：<整体判定 + 遗留与风险>
```

## 质量检查（收尾自检）

- [ ] 环境卡已读（或已现场生成）
- [ ] 每个场景判据先于测试
- [ ] 三件套取证完整，缺一未下结论
- [ ] 数据归属用 DOM 断言，非截图
- [ ] 未通过场景已复测确认非偶发
- [ ] **未改任何代码**（含 testid、配置、依赖）
- [ ] 测试报告已按模板交付
