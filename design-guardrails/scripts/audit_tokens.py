#!/usr/bin/env python3
"""现状盘点 —— 扫描现有前端代码，抽出"实际在用的设计规范"。

用途：**已有项目**提升界面水平时的第 2 步。规范不用发明，它已经存在于代码里，
只是没人写下来。本脚本把隐含规范抽成明文，并标出不一致与历史债。

用法
----
    python3 audit_tokens.py                      # 自动探测界面文件
    python3 audit_tokens.py --dir ./web          # 指定目录
    python3 audit_tokens.py --top 20             # 每类显示前 20（默认 12）
    python3 audit_tokens.py --json out.json      # 同时输出机器可读结果
    python3 audit_tokens.py --exclude tokens.css

产出
----
四类值的频次统计：颜色 / 字号 / 间距 / 圆角
- 高频（≥3 次）= 事实规范，建议写进 DESIGN.md 并在 tokens 里命名
- 低频（1–2 次）= 疑似历史债或一次性微调，逐个决策：收敛 or 保留
- 另附"非 4 倍数间距"清单（8pt 网格的偏离项）

本脚本**只读不改**。
"""
import argparse
import collections
import fnmatch
import glob
import json
import os
import re
import sys

SCAN_EXT = {".css", ".less", ".scss", ".html", ".vue", ".jsx", ".tsx", ".svelte", ".astro"}
SKIP_DIRS = {"node_modules", ".git", "dist", "build", ".next", "out", "coverage",
             "vendor", ".venv", "venv", "__pycache__", ".cache", ".output"}
TOKEN_FILE_HINT = re.compile(r"(tokens?|variables?|theme|_vars?)", re.I)

RE_HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")
RE_FUNC_COLOR = re.compile(r"\b(rgba?|hsla?)\([^)]*\)")
RE_FONT_SIZE = re.compile(r"font-size\s*:\s*(\d+(?:\.\d+)?(?:px|rem|em))")
RE_SPACING = re.compile(
    r"\b(padding|margin|gap|row-gap|column-gap)(?:-(?:top|right|bottom|left))?\s*:\s*([^;{}\n]+)")
RE_RADIUS = re.compile(r"border-radius\s*:\s*([^;{}\n]+)")
RE_PX = re.compile(r"(\d+(?:\.\d+)?)px")


def collect_files(args):
    if args.files:
        return [f for f in args.files if os.path.isfile(f)]
    roots = [args.dir] if args.dir else []
    if not roots:
        for cand in ("web", "src", "public", "app", "assets", "styles", "pages", "components"):
            if os.path.isdir(cand):
                roots.append(cand)
        roots += glob.glob("*.html") + glob.glob("*.css")
    out = []
    for r in roots:
        if os.path.isfile(r):
            out.append(r)
            continue
        for dirpath, dirnames, filenames in os.walk(r):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for fn in filenames:
                if os.path.splitext(fn)[1].lower() in SCAN_EXT:
                    out.append(os.path.join(dirpath, fn))
    return sorted(set(out))


def is_exempt(path, excludes):
    base = os.path.basename(path)
    if TOKEN_FILE_HINT.search(base):
        return True
    return any(fnmatch.fnmatch(base, p) or fnmatch.fnmatch(path, p) for p in excludes)


def norm_hex(h):
    h = h.lower().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return "#" + h[:6]


def scan(files, excludes):
    colors = collections.Counter()
    fonts = collections.Counter()
    spacings = collections.Counter()
    radii = collections.Counter()
    odd_spacings = collections.Counter()
    where = {}

    for f in files:
        if is_exempt(f, excludes):
            continue
        try:
            lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for ln, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith("/*") or s.startswith("*") or s.startswith("//") or s.startswith("<!--"):
                continue
            for m in RE_HEX.finditer(line):
                v = norm_hex(m.group(0))
                colors[v] += 1
                where.setdefault(("color", v), "%s:%d" % (f, ln))
            for m in RE_FUNC_COLOR.finditer(line):
                v = re.sub(r"\s+", "", m.group(0))
                colors[v] += 1
                where.setdefault(("color", v), "%s:%d" % (f, ln))
            for m in RE_FONT_SIZE.finditer(line):
                fonts[m.group(1)] += 1
                where.setdefault(("font", m.group(1)), "%s:%d" % (f, ln))
            for m in RE_SPACING.finditer(line):
                val = m.group(2).strip()
                if "var(" in val or val in ("auto", "0", "0px", "0 auto"):
                    continue
                spacings[val] += 1
                for px in RE_PX.finditer(val):
                    n = float(px.group(1))
                    if n and n % 4 != 0:
                        odd_spacings[val] += 1
            for m in RE_RADIUS.finditer(line):
                val = m.group(1).strip()
                if "var(" in val:
                    continue
                radii[val] += 1
    return colors, fonts, spacings, radii, odd_spacings, where


def show(title, counter, top, where, kind):
    total = sum(counter.values())
    uniq = len(counter)
    print("\n## %s（%d 个不同值，共出现 %d 次）" % (title, uniq, total))
    if not uniq:
        print("  ✅ 没有裸值——该类已全部走 token，不需要盘点")
        return
    hi = [(v, c) for v, c in counter.most_common() if c >= 3]
    lo = [(v, c) for v, c in counter.most_common() if c < 3]
    print("  高频（≥3 次，建议作为规范并命名 token）：")
    for v, c in hi[:top]:
        print("    %-28s %4d 次   %s" % (v, c, where.get((kind, v), "")))
    if not hi:
        print("    （无 —— 说明当前都是零散用法，需要先收敛）")
    if lo:
        print("  低频（1–2 次，逐个决策：收敛 or 保留）：")
        for v, c in lo[:top]:
            print("    %-28s %4d 次   %s" % (v, c, where.get((kind, v), "")))
        if len(lo) > top:
            print("    ... 还有 %d 个低频值" % (len(lo) - top))


def main():
    ap = argparse.ArgumentParser(description="扫描现有代码，抽出隐含的设计规范")
    ap.add_argument("--dir", help="扫描目录")
    ap.add_argument("--files", nargs="*", help="只扫描这些文件")
    ap.add_argument("--exclude", action="append", default=[], help="豁免 glob（可多次）")
    ap.add_argument("--top", type=int, default=12, help="每类显示条数（默认 12）")
    ap.add_argument("--json", dest="json_out", help="同时输出 JSON 到指定文件")
    args = ap.parse_args()

    files = collect_files(args)
    if not files:
        print("没有找到可扫描的文件（用 --dir 或 --files 指定）")
        return 1

    colors, fonts, spacings, radii, odd, where = scan(files, args.exclude)

    print("=" * 68)
    print("现状盘点：从 %d 个文件抽出实际在用的设计值" % len(files))
    print("=" * 68)

    show("颜色", colors, args.top, where, "color")
    show("字号", fonts, args.top, where, "font")
    show("间距", spacings, args.top, where, "space")
    show("圆角", radii, args.top, where, "radius")

    print("\n## 非 4 倍数间距（8pt 网格的偏离项）")
    if odd:
        for v, c in odd.most_common():
            print("    %-28s %4d 次" % (v, c))
        print("  → 逐个决策：并入最近的网格值，或明确保留为微调（记进 DESIGN.md 的已知偏差）")
    else:
        print("  （无）")

    print("\n下一步：把上面的「高频值」写进 DESIGN.md 与 tokens；「低频值」逐个决策。")

    if args.json_out:
        payload = {
            "files_scanned": len(files),
            "colors": dict(colors),
            "font_sizes": dict(fonts),
            "spacings": dict(spacings),
            "radii": dict(radii),
            "off_grid_spacings": dict(odd),
        }
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
        print("JSON 已写出：%s" % args.json_out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
