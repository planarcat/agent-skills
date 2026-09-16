#!/usr/bin/env python3
"""把三层报告技能打包成"可移植版"，供其他 AI 工具使用。

用法：
    python3 export-portable.py                                   # 只导出，默认输出到当前目录 ./report-skill-portable/
    python3 export-portable.py -o /自定义/输出目录                # 只导出，指定目录
    python3 export-portable.py --merge /path/to/AGENTS.md         # 合并进已有的 AGENTS.md（幂等，可反复跑）
    python3 export-portable.py --merge /path/AGENTS.md --lite     # 合并精简版（约 1/4 体积）

技能源目录自动从脚本自身位置推导（脚本位于 <技能根>/report-pipeline/scripts/），
所以仓库拷到哪台机器、哪个技能目录都能跑，无需改路径。
技能不放在一起时用 `--skills-root /path/to/skills` 手动指定。

--merge 的行为：
    · 目标文件不存在 → 直接创建
    · 目标文件已有本技能的标记块 → 只替换标记块内内容，别的内容一个字不动
    · 目标文件存在但没有标记块 → 先把原文件备份成 AGENTS.md.bak-时间戳，再追加标记块
    反复跑不会重复堆叠，源文件改了重跑即更新。

产出四件（默认输出目录）：
  1. AGENTS.md                    单文件完整版（任何工具都能读：Cursor / Codex / ChatGPT 自定义指令）
  2. AGENTS.lite.md               单文件精简版（只含规范原文 + 模板）
  3. report-skills.zip            三个技能目录原样打包（支持 Agent Skills 的工具直接用）
  4. README_移植说明.md            三条移植路线的具体做法

设计原则：不手写副本。每次重新运行即重新生成，杜绝"两份内容打架"。
"""
from __future__ import annotations

import hashlib
import os
import re
import shutil
import sys
import zipfile
from datetime import datetime
from pathlib import Path

SKILLS_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = Path.cwd() / "report-skill-portable"

SKILL_DIRS = ["report-pipeline", "report-draft-filter", "report-writer"]

# 顺序即效力顺序：规范原文优先，其次采集 → 分拣 → 成型
SECTIONS = [
    ("第一部分 · 规范原文（最高标准，冲突以本部分为准）", "report-writer", "references/spec.md"),
    ("第二部分 · 采集层 report-pipeline（什么时候记、记什么）", "report-pipeline", "SKILL.md"),
    ("第二部分附 · 素材卡格式细则", "report-pipeline", "references/card-format.md"),
    ("第三部分 · 分拣层 report-draft-filter（哪些写、哪些剔除）", "report-draft-filter", "SKILL.md"),
    ("第三部分附 · 工作小结 → 日报草稿 指导文档", "report-draft-filter", "references/gather-to-draft.md"),
    ("第四部分 · 成型层 report-writer（日报长什么样）", "report-writer", "SKILL.md"),
    ("第四部分附 · 日报填写模板", "report-writer", "references/templates.md"),
]

FRONTMATTER = re.compile(r"^---\n.*?\n---\n", re.S)

# 精简版：只保底线（规范红线 + 填写模板），塞得进自定义指令输入框
LITE_SECTIONS = [
    ("规范原文（最高标准，冲突以本部分为准）", "report-writer", "references/spec.md"),
    ("日报填写模板与合规自检清单", "report-writer", "references/templates.md"),
]

LITE_HEADER = """# 日报编写规则 · 精简版

> 脚本自动生成，勿手工编辑。完整版见同目录 `AGENTS.md`。
> 本版只含**规范原文 + 填写模板**，体积约为完整版的四分之一。
> 丢了采集与分拣的细则，写出来的初稿需要人工补责任内联和去噪。

## 三条必须先知道的

1. **只写日报**，不写周报/周评/月报；日报截止每日 21:00。
2. **规范 > 用户口径 > 工具建议**，一切冲突回下方规范原文裁定。
3. **日报七模块顺序**：产出 → 进行中 → 卡点 → 失误 → 明日计划 → 异常与协调 → 复盘。
   产出与明日计划每条必带「标准:可验收结果」，每条必带责任内联。

---
"""


def build_lite(out: Path) -> Path:
    parts: list[str] = [LITE_HEADER]
    for title, skill, rel in LITE_SECTIONS:
        path = SKILLS_ROOT / skill / rel
        if not path.is_file():
            parts.append(f"\n# {title}\n\n> ⚠️ 缺失文件：`{path}`\n")
            continue
        parts.append(f"\n# {title}\n\n<!-- 源文件：{skill}/{rel} -->\n\n")
        text = read(path)
        parts.append(strip_frontmatter(text) if rel == "SKILL.md" else text)
        if not parts[-1].endswith("\n"):
            parts.append("\n")
        parts.append("\n---\n")
    out_file = out / "AGENTS.lite.md"
    out_file.write_text("".join(parts), encoding="utf-8")
    return out_file


def strip_frontmatter(text: str) -> str:
    return FRONTMATTER.sub("", text, count=1).lstrip("\n")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def build_agents_md(out: Path) -> tuple[Path, list[str], int]:
    parts: list[str] = [
        "# 日报编写规则 · 通用版\n",
        "\n",
        "> 本文件由脚本自动生成，**请勿手工编辑**——改了会在下次导出时丢失。\n",
        f"> 来源：`{SKILLS_ROOT}/{{report-pipeline, report-draft-filter, report-writer}}`\n",
        "> 重新生成：`python3 export-portable.py`\n",
        "\n",
        "## 生效范围\n",
        "\n",
        "- **只写日报**，不写周报/周评/月报；日报截止每日 21:00。\n",
        "\n",
        "## 最高原则\n",
        "\n",
        "**规范 > 用户口径 > 工具建议。** 任何冲突，回第一部分（规范原文）裁定。\n",
        "\n",
        "## 怎么用\n",
        "\n",
        "- 支持 Agent Skills 的工具：用 `report-skills.zip` 里的三个技能目录（各自 SKILL.md + references），别用本文件。\n",
        "- 只支持单文件规则的工具（Cursor / Codex / ChatGPT 自定义指令 / 任意聊天窗口）：把本文件全文贴进系统提示或存成 AGENTS.md。\n",
        "\n",
        "## 三层结构\n",
        "\n",
        "```\n",
        "采集 report-pipeline      阶段落卡 → 日末归并成日报\n",
        "分拣 report-draft-filter  去噪 / 归类 / 合并\n",
        "成型 report-writer        套七模块 + 责任内联 + 红线自查（附规范原文）\n",
        "```\n",
        "\n",
        "---\n",
    ]

    seen: dict[str, str] = {}
    dupes: list[str] = []
    included = 0

    for title, skill, rel in SECTIONS:
        path = SKILLS_ROOT / skill / rel
        if not path.is_file():
            parts.append(f"\n# {title}\n\n> ⚠️ 缺失文件：`{path}`\n")
            continue
        text = read(path)
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if digest in seen:
            dupes.append(f"{skill}/{rel}（与 {seen[digest]} 内容相同，已跳过）")
            continue
        seen[digest] = f"{skill}/{rel}"
        included += 1
        parts.append(f"\n# {title}\n\n<!-- 源文件：{skill}/{rel} -->\n\n")
        parts.append(strip_frontmatter(text) if rel == "SKILL.md" else text)
        if not parts[-1].endswith("\n"):
            parts.append("\n")
        parts.append("\n---\n")

    if dupes:
        parts.append("\n## 重复文件说明（自动去重）\n\n")
        for d in dupes:
            parts.append(f"- {d}\n")
        parts.append(
            "\n同名指导文档在两个技能下各存了一份。导出时已去重，"
            "但**源目录里的两份仍需人工合并为一份**，否则未来会再次出现口径打架。\n"
        )

    out_file = out / "AGENTS.md"
    out_file.write_text("".join(parts), encoding="utf-8")
    return out_file, dupes, included


def build_zip(out: Path) -> Path:
    zip_path = out / "report-skills.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for skill in SKILL_DIRS:
            src = SKILLS_ROOT / skill
            if not src.is_dir():
                continue
            for file in sorted(src.rglob("*")):
                if file.is_file():
                    zf.write(file, arcname=str(Path("skills") / file.relative_to(SKILLS_ROOT)))
    return zip_path


README = f"""# 报告编写技能 · 移植说明

> 自动生成，勿手工编辑。来源：`{SKILLS_ROOT}` 下的三个技能目录。

## 这套技能包含什么

三层结构，8 个文件：

| 层 | 技能 | 文件 |
|---|---|---|
| 规范（最高标准） | report-writer | `references/spec.md` |
| 采集 | report-pipeline | `SKILL.md`、`references/card-format.md` |
| 分拣 | report-draft-filter | `SKILL.md`、`references/gather-to-draft.md` |
| 成型 | report-writer | `SKILL.md`、`references/templates.md` |
| 工具（仅移植时需要） | report-pipeline | `scripts/export-portable.py` |

依赖关系：**采集 → 分拣 → 成型**，全部只依赖纯 Markdown，无外部服务、无网络。
导出脚本零第三方依赖（Python 标准库），源目录从脚本位置自动推导，换机器不用改路径。

**零配置**：技能装好即可用，不需要改任何路径。

- **数据跟着工作区走**：素材卡、日报写在各自工作区内的
  `.workbuddy/reports/{{cards,daily}}/`，不写进技能目录——技能目录永远只读、保持干净。
- **项目名从素材取**：技能里不含项目清单，项目名一律取当天素材里的称呼，所以换业务、换项目都不用改技能。
- 唯一写死的是报告作者本人姓名（何成标）。

## 路线 A：目标工具支持 Agent Skills（Claude Code / WorkBuddy 等）

技能目录格式（`SKILL.md` + YAML frontmatter + `references/`）是通用约定，直接拷贝即可：

```bash
# 解压
unzip report-skills.zip -d /tmp/report-skills

# 拷到目标工具的技能目录
cp -r /tmp/report-skills/skills/*  ~/.claude/skills/          # Claude Code
cp -r /tmp/report-skills/skills/*  ~/.workbuddy/skills/       # WorkBuddy
```

拷完新开一个会话，说「写今天的日报」验证是否被加载。

## 路线 B：目标工具只支持单文件规则（Cursor / Codex / ChatGPT）

两个版本，按目标工具塞不塞得下选：

| 文件 | 体积 | 适用 |
|---|---|---|
| `AGENTS.md` | 约 81 KB（≈25k tokens） | 长上下文的 CLI Agent，能吃下全部规则 |
| `AGENTS.lite.md` | 约 25 KB（≈8k tokens） | 自定义指令输入框、上下文吃紧的窗口 |

放哪：

| 工具 | 放哪 |
|---|---|
| Codex / 多数 CLI Agent | 项目根目录 `AGENTS.md`，或 `~/.codex/AGENTS.md` 全局 |
| Cursor | 项目根 `.cursor/rules/report.mdc`，正文用 AGENTS.md 内容，frontmatter 加 `alwaysApply: true` |
| ChatGPT / 豆包 / 任意聊天窗口 | 贴进「自定义指令 / 系统提示」；塞不下就用 `AGENTS.lite.md` |

单文件版没有"按需加载"能力，全部规则常驻上下文。上下文吃紧时按此优先级裁剪：
**规范原文 > 成型层 > 采集层 > 分拣层**。

## 路线 B-2：项目里已经有 AGENTS.md，怎么合进去

**不要直接覆盖**——别人的项目规则会没。用合并模式，幂等、可反复跑：

```bash
# 全量版合进去
python3 export-portable.py --merge /path/to/你的项目/AGENTS.md

# 只想塞精简版（体积约 1/4）
python3 export-portable.py --merge /path/to/你的项目/AGENTS.md --lite
```

行为：

| 情况 | 结果 |
|---|---|
| 目标文件不存在 | 直接新建 |
| 已有标记块 | **只替换块内内容**，块外一个字不动；重复跑不会堆叠 |
| 没有标记块 | 先备份成 `AGENTS.md.bak-时间戳`，再在末尾追加标记块 |

标记块长这样，夹在中间的内容可以随时删除来"卸载"：

```
<!-- BEGIN:report-skill 由 export-portable.py 生成，勿手工编辑，重跑脚本即更新 -->
（规则正文）
<!-- END:report-skill -->
```

**替代做法（不想让 82 KB 常驻）**：把生成的 `AGENTS.md` 改名叫 `docs/报告编写规则.md`
放进项目，再在项目 AGENTS.md 里加一行「生成日报前先读 `docs/报告编写规则.md`」。
代价是只有提到报告类需求时才可能被读到，不像合并版那样常驻，更省上下文。

## 路线 C：手工转述（不推荐，但最省事）

把 `AGENTS.md` 的第一部分（规范原文）连同日报模板一起给人看，让它照着写。
代价：会丢掉责任内联格式、失误栏口径、术语白化这些细则，写出来的东西大概率被打回。

## 移植后要不要改东西

**不用改路径，不用配项目**：

1. **技能目录只读**——素材卡 / 日报写在**各自的工作区**里
   （`<工作区>/.workbuddy/reports/`，或该工作区自己规范指定的位置），
   不写进技能目录。哪份工作属于哪个工作区，数据就落在哪儿。
2. **项目名**——技能里不含项目清单，项目名一律取自当天素材，换业务不用改技能。
3. 唯一写死的是报告作者本人姓名（何成标）；给别人用改这一处即可。

> 一天跨多个工作区时，素材会分散在各自的工作区里（工作内容归位）。
> 出日报时按 SKILL.md「跨工作区怎么收齐」的顺序收齐；找不齐就问用户，
> 不要拿别的日期或别的事项顶替。

## 维护纪律

- `AGENTS.md` 是**生成物**，不要手改。源文件改了以后重新跑一次导出脚本。
- 三层技能各自的 `SKILL.md` 才是源。改口径只改那里。
- 目前 `gather-to-draft.md` 在两个技能下各有一份（同内容）。
  **建议合并为一份**，避免将来只改了一处、另一处还停在旧口径（2026-09-16 已发生过一次）。
"""


BEGIN_MARK = "<!-- BEGIN:report-skill 由 export-portable.py 生成，勿手工编辑，重跑脚本即更新 -->"
END_MARK = "<!-- END:report-skill -->"
BLOCK_RE = re.compile(re.escape(BEGIN_MARK) + r".*?" + re.escape(END_MARK), re.S)


def merge_into(target: Path, body: str) -> str:
    """把规则块幂等地合并进已有文件：有标记块就替换，没有就备份后追加。"""
    block = f"{BEGIN_MARK}\n\n{body.rstrip()}\n\n{END_MARK}\n"
    target.parent.mkdir(parents=True, exist_ok=True)

    if not target.exists():
        target.write_text(block, encoding="utf-8")
        return f"目标不存在，已新建（{target.stat().st_size / 1024:.1f} KB）"

    original = target.read_text(encoding="utf-8")

    if BLOCK_RE.search(original):
        updated = BLOCK_RE.sub(lambda _m: block.rstrip(), original, count=1)
        if updated == original:
            return "标记块已是最新，无需改动"
        target.write_text(updated, encoding="utf-8")
        return f"已替换标记块内内容，块外内容未动（{target.stat().st_size / 1024:.1f} KB）"

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = target.with_name(f"{target.name}.bak-{stamp}")
    shutil.copy2(target, backup)
    target.write_text(original.rstrip() + "\n\n" + block, encoding="utf-8")
    return (
        f"原文件无标记块，已在末尾追加（{target.stat().st_size / 1024:.1f} KB）；"
        f"原文已备份为 {backup.name}"
    )


def main() -> int:
    global SKILLS_ROOT
    out = DEFAULT_OUT
    merge_target: Path | None = None
    use_lite = False

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--merge":
            i += 1
            if i >= len(args):
                print("--merge 后面要跟目标文件路径，例如 --merge ./AGENTS.md")
                return 2
            merge_target = Path(args[i]).expanduser().resolve()
        elif a == "--skills-root":
            i += 1
            if i >= len(args):
                print("--skills-root 后面要跟技能根目录")
                return 2
            SKILLS_ROOT = Path(args[i]).expanduser().resolve()
        elif a == "--lite":
            use_lite = True
        elif a in ("-o", "--out"):
            i += 1
            if i >= len(args):
                print("-o 后面要跟输出目录")
                return 2
            out = Path(args[i]).expanduser().resolve()
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            out = Path(a).expanduser().resolve()
        i += 1

    missing = [d for d in SKILL_DIRS if not (SKILLS_ROOT / d / "SKILL.md").is_file()]
    if missing:
        print(f"技能根目录：{SKILLS_ROOT}")
        print(f"  找不到这些技能：{', '.join(missing)}")
        print("  三个技能要在同一个父目录下（脚本所在目录往上两级即该父目录）。")
        print("  技能不在一起时，用 --skills-root /path/to/skills 指定。")
        return 3

    out.mkdir(parents=True, exist_ok=True)

    agents, dupes, included = build_agents_md(out)
    lite = build_lite(out)
    zip_path = build_zip(out)
    readme = out / "README_移植说明.md"
    readme.write_text(README, encoding="utf-8")

    print(f"输出目录：{out}")
    print(f"  {agents.name}                 {agents.stat().st_size / 1024:.1f} KB（含 {included} 个源文件）")
    print(f"  {lite.name}            {lite.stat().st_size / 1024:.1f} KB（精简版）")
    print(f"  {zip_path.name}            {zip_path.stat().st_size / 1024:.1f} KB")
    print(f"  {readme.name}     {readme.stat().st_size / 1024:.1f} KB")
    for d in dupes:
        print(f"  [去重] {d}")

    if merge_target is not None:
        source = lite if use_lite else agents
        print()
        print(f"合并目标：{merge_target}")
        print(f"  {merge_into(merge_target, source.read_text(encoding='utf-8'))}")
        print("  提示：重跑本命令即可更新，标记块以外的内容不会被改动。")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
