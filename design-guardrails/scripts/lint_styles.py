#!/usr/bin/env python3
"""界面样式 lint —— 检查硬编码值，强制走设计 token。

用法
----
    python3 lint_styles.py                          # 自动探测界面文件
    python3 lint_styles.py --dir ./web              # 指定目录
    python3 lint_styles.py --files a.css b.html     # 指定文件
    python3 lint_styles.py --exclude tokens.css --exclude "*.min.css"
    python3 lint_styles.py --allow-hex "#fff"       # 放行特定色值

规则
----
1. 硬编码颜色（#hex / rgb() / rgba() / hsl()）→ 应走 var(--c-*)
2. 硬编码 px 字号（font-size: 14px）        → 应走 var(--fs-*)
3. 裸数字 z-index（z-index: 9999）          → 应走 var(--z-*)；0 / -1 放行

豁免
----
文件名含 token / variables / theme 的样式文件自动豁免（它们本就是定义值的地方）。

退出码：0 = 通过，1 = 有违规。
"""
import argparse
import fnmatch
import glob
import os
import re
import sys

SCAN_EXT = {".css", ".less", ".scss", ".sass", ".styl", ".html", ".htm", ".vue",
            ".jsx", ".tsx", ".svelte", ".astro", ".js", ".ts"}
SKIP_DIRS = {"node_modules", ".git", "dist", "build", ".next", "out", "coverage",
             "vendor", ".venv", "venv", "__pycache__", ".cache", ".output"}
TOKEN_FILE_HINT = re.compile(r"(tokens?|variables?|theme|_vars?|design[-_]?system)", re.I)

HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")
FUNC_COLOR = re.compile(r"\b(rgba?|hsla?)\s*\(")
FS_PX = re.compile(r"font-size\s*:\s*\d+(\.\d+)?px")
ZINDEX = re.compile(r"z-index\s*:\s*(-?\d+)")
ZINDEX_ALLOW = {"0", "-1"}


def collect_files(args):
    """按参数收集待检查文件；未指定则自动探测常见界面目录。"""
    if args.files:
        return [f for f in args.files if os.path.isfile(f)]
    roots = []
    if args.dir:
        roots = [args.dir]
    else:
        for cand in ("web", "src", "public", "app", "assets", "styles", "pages", "components"):
            if os.path.isdir(cand):
                roots.append(cand)
        roots += [f for f in glob.glob("*.html") + glob.glob("*.css")]
    out = []
    for r in roots:
        if os.path.isfile(r):
            if os.path.splitext(r)[1].lower() in SCAN_EXT:
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
    for pat in excludes:
        if fnmatch.fnmatch(base, pat) or fnmatch.fnmatch(path, pat):
            return True
    return False


def norm_hex(h):
    """把 #abc / #aabbcc / #aabbccdd 归一成 6 位小写，便于比较。"""
    h = h.lower().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return h[:6]


def is_comment(stripped):
    """CSS/HTML/JS 的行首注释。注意：# 在 CSS 里是 id 选择器，不是注释。"""
    return (stripped.startswith("/*") or stripped.startswith("*") or
            stripped.startswith("//") or stripped.startswith("<!--"))


def check_file(path, allow_hex, with_rgba=False):
    violations = []
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return violations
    for ln, line in enumerate(lines, 1):
        s = line.strip()
        if is_comment(s):
            continue
        for m in HEX.finditer(line):
            if norm_hex(m.group(0)) in allow_hex:
                continue
            violations.append((ln, "硬编码颜色 %s → 用 var(--c-*)" % m.group(0)))
        if with_rgba:
            for m in FUNC_COLOR.finditer(line):
                violations.append((ln, "硬编码颜色 %s(...) → 用 var(--c-*)" % m.group(1)))
        for _ in FS_PX.finditer(line):
            violations.append((ln, "硬编码字号 → 用 var(--fs-*)"))
        for m in ZINDEX.finditer(line):
            if m.group(1) not in ZINDEX_ALLOW:
                violations.append((ln, "裸 z-index %s → 用 var(--z-*)" % m.group(1)))
    return violations


def main():
    ap = argparse.ArgumentParser(description="界面样式 lint：强制走设计 token")
    ap.add_argument("--dir", help="扫描目录")
    ap.add_argument("--files", nargs="*", help="只检查这些文件")
    ap.add_argument("--exclude", action="append", default=[], help="豁免 glob（可多次）")
    ap.add_argument("--allow-hex", action="append", default=[], help="放行的色值（可多次）")
    ap.add_argument("--with-rgba", action="store_true",
                    help="同时把 rgba()/hsl() 视为违规（默认关闭：遮罩与阴影常直接写 rgba）")
    args = ap.parse_args()

    allow_hex = {norm_hex(h) for h in args.allow_hex}
    files = collect_files(args)
    if not files:
        print("没有找到可检查的文件（用 --dir 或 --files 指定）")
        return 0

    total = []
    checked = 0
    for f in files:
        if is_exempt(f, args.exclude):
            continue
        checked += 1
        for ln, msg in check_file(f, allow_hex, args.with_rgba):
            total.append("%s:%d  %s" % (f, ln, msg))

    if total:
        print("STYLE LINT FAILED (%d violations in %d files):" % (len(total), checked))
        for v in total[:60]:
            print("  -", v)
        if len(total) > 60:
            print("  ... 还有 %d 条" % (len(total) - 60))
        return 1
    print("STYLE LINT PASSED: %d files, no hardcoded colors/font-sizes/z-index" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
