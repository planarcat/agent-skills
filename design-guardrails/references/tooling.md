# 外部工具怎么用（tooling）

> 核实日期 2026-10-16。**结论先行：这套能力主要靠 skill 本身 + 你自己的 DESIGN.md，外部工具只装 1–2 个。**

## 该装的

| 工具 | 装法 | 只用来做 |
|---|---|---|
| **Claude Code `/design`**（内置，无需安装） | `claude update` 升级到最新版 | 第 ③ 步出多版方向画板供挑选 |
| **Hallmark** | `npx skills add nutlope/hallmark` | 只用它的 `audit`（体检现有界面）+ `study`（从欣赏的设计提 DNA 导出 design.md） |

Hallmark 是 **agent 侧 skill**，落在 `~/.claude/skills/hallmark/`，**不进项目依赖**。它还有 `build` / `redesign` 两个动词，见下方"不要用"。

## 按需

| 工具 | 什么时候考虑 |
|---|---|
| `cc-design-cli`（`npx cc-design-cli init --ai claude`） | 想要"风格画廊"式挑选且自建画廊不够用时。它要 MCP + 常驻服务，与第③步的自建画廊能力重叠，**先用自建画廊试** |
| **`ui-redesign`** | 需要**深审计**时（312 条规则 / 26 类 / 6 道门禁）。见下方"装它之前先知道三件事" |

### ui-redesign 安装（三个来源，实现不同，别混装）

| 路径 | 命令 | 特点 |
|---|---|---|
| Claude Code 插件市场 | `claude plugin marketplace add GWJian/claude-skills`<br>`claude plugin install ui-redesign@gwj-skills` | 该版本**只生成文档，不改应用代码** |
| GitHub 直取 | 从 `rashee1997/ui-redesign` 取 Skill 文件放入工具 skills 目录 | 会改代码，每步需批准 |
| 通用 npx | `npx skills add https://github.com/boparaiamrit/skills-by-amrit --skill ui-ux-redesign` | 第三方转载，来源需自行确认 |

**三个来源的实现不同**，装之前先确定你要哪一种（"只出方案"还是"会动代码"）。

它的三个旋钮预设与本 skill 的 `tone-lock.md` **逐条一致**（内部工具 3-4/2-3/8-9 · B2B SaaS 6-7/5-6/4-5 · 编辑文档 4-5/2-3/5-6），
说明这套判定是行业共识，不是某家的私有标准。
它生成 3 个可点击原型（`concepts/index.html`）× 挑方向的做法，与本 skill 的 `make_gallery.py` 是同一机制。

**它明确要求"先有 DESIGN.md 再改造"**——与本 skill 第④步"先固规范再动界面"同一条纪律。

## 不要用（以及为什么）

| 不用 | 原因 |
|---|---|
| `frontend-design`、Hallmark `build`、`repaint` | 它们追求"**每页不同指纹**"，与工具型应用要求的一致性**直接冲突**。只有做营销页时才合适 |
| 所有"设计系统生成器"（Aioli、AI Design System Generator、Google Stitch 等） | 会产出**第二套 token 体系**，与项目自己的 tokens 打架——两份真源必然冲突 |
| `Design Intelligence MCP` 一类"设计知识库" | 它的一致性检查只能验证"推荐内部自洽"，验证不了"这东西属不属于本项目已有的系统"；而后者只能来自项目自己的取舍。它的 `recommend_design` 会**整套覆盖**你已定的规范。**要它的知识就当参考书读**（本 skill 的 `structure-patterns.md` 就是这么来的） |
| 代码审查 / a11y / 性能类 MCP | 缺的规则自己加进 `lint_styles.py` 更划算（一条正则 vs 一个常驻服务） |

## 一个判断准则

拿到任何"设计类工具"，先问两句：

1. **它会往我的项目里写值吗？**（token 值、主题、组件实现）→ 会 = 制造第二真源，不要
2. **它追求"每页不同"还是"同类一致"？** → 后者才适合工具型应用

只给判断、只给清单、不落值的工具，才是能用的。

## 用外部工具时的纪律

- 它的**建议要按场景筛**：`hallmark audit` 是按营销页审美训练的，它会建议你"加纹理、破对称、多点动效"——工具型应用要挡掉这些。
- 它的**输出不直接进项目**：先经过项目 DESIGN.md 的过滤，能翻译成项目 token 的才采纳。
- **一次只引一个点**，引完就落进自己的规范，避免出现第二份真源。
