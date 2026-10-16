#!/usr/bin/env python3
"""方案画廊 —— 把多版设计方案并排展示，供人挑选。

用途：流程第 ③ 步「找方向」。AI 生成 3–4 版独立 HTML 方案后，跑本脚本生成
一个对比页；人打开对比页并排看、挑一版，再回到第 ④ 步固化成规范。

**不依赖任何工具的内置命令**——纯文件操作，任何能写文件的 agent 都能用。

用法
----
    # 1) AI 生成方案到某目录（每版一个独立 HTML）
    #    方案/01-极简.html  方案/02-编辑风.html  方案/03-数据密集.html
    # 2) 生成对比页
    python3 make_gallery.py --dir 方案 --title "首页方案对比"

    # 常用参数
    --out FILE      输出路径（默认 <dir>/对比.html）
    --cols N        每行展示几版（默认 2）
    --filter GLOB   只收匹配的文件（默认 *.html）
    --note TEXT     顶部说明文字

产出：单文件 HTML（无外部依赖），用浏览器直接打开即可。
"""
import argparse
import glob
import html
import os
import sys


def collect(directory, pattern, exclude):
    out = []
    for p in sorted(glob.glob(os.path.join(directory, pattern))):
        if os.path.abspath(p) == os.path.abspath(exclude):
            continue
        if os.path.basename(p).startswith("对比"):
            continue
        out.append(p)
    return out


def style_name(path):
    """从文件名里取出风格名：01-极简.html → 极简"""
    base = os.path.splitext(os.path.basename(path))[0]
    for sep in ("-", "_", " "):
        if sep in base:
            head, _, tail = base.partition(sep)
            if head.strip().isdigit():
                return tail.strip() or base
            return base
    return base


def build(files, title, cols, note):
    cards = []
    for i, p in enumerate(files, 1):
        name = style_name(p)
        rel = os.path.basename(p)
        cards.append(
            '<section class="card">'
            '<header class="card__h">'
            '<span class="num">%d</span>'
            '<span class="name">%s</span>'
            '<a class="open" href="%s" target="_blank" rel="noopener">新窗口打开</a>'
            '</header>'
            '<div class="card__frame"><iframe src="%s" loading="lazy" title="%s"></iframe></div>'
            '</section>' % (i, html.escape(name), html.escape(rel), html.escape(rel), html.escape(name))
        )

    return """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
<style>
  :root {
    --ink: #171d1f; --ink-2: #3c4447; --ink-3: #5b6669; --ink-4: #8a9497;
    --bg: #f2f4f4; --surface: #ffffff; --line: #d9dedf;
    --accent: #0d6a63; --accent-soft: #eaf2f1;
    --sp1: 4px; --sp2: 8px; --sp3: 12px; --sp4: 16px; --sp5: 24px; --sp6: 32px;
    --r-m: 8px; --r-l: 12px;
    --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 13px/1.6 var(--font); }
  .bar {
    position: sticky; top: 0; z-index: 10; display: flex; align-items: center;
    gap: var(--sp4); padding: var(--sp3) var(--sp5);
    background: var(--surface); border-bottom: 1px solid var(--line);
  }
  .bar h1 { margin: 0; font-size: 14px; font-weight: 500; }
  .bar .note { color: var(--ink-3); font-size: 12px; }
  .bar .spacer { flex: 1; }
  .bar .count { color: var(--ink-4); font-size: 12px; }
  main {
    display: grid; gap: var(--sp5); padding: var(--sp5);
    grid-template-columns: repeat(%(cols)d, minmax(0, 1fr));
  }
  @media (max-width: 900px) { main { grid-template-columns: 1fr; } }
  .card {
    background: var(--surface); border: 1px solid var(--line);
    border-radius: var(--r-l); overflow: hidden; display: flex; flex-direction: column;
  }
  .card__h {
    display: flex; align-items: center; gap: var(--sp2);
    padding: var(--sp2) var(--sp3); border-bottom: 1px solid var(--line);
  }
  .num {
    display: inline-flex; align-items: center; justify-content: center;
    width: 20px; height: 20px; border-radius: var(--r-m);
    background: var(--accent-soft); color: var(--accent);
    font-size: 11px; font-weight: 500; flex: none;
  }
  .name { font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .open { margin-left: auto; color: var(--accent); font-size: 12px; text-decoration: none; flex: none; }
  .open:hover { text-decoration: underline; }
  .card__frame { flex: 1; min-height: 520px; background: var(--bg); }
  .card__frame iframe { width: 100%%; height: 100%%; border: 0; display: block; }
  .empty { padding: var(--sp6); text-align: center; color: var(--ink-3); }
</style>
</head>
<body>
<div class="bar">
  <h1>%(title)s</h1>
  <span class="note">%(note)s</span>
  <span class="spacer"></span>
  <span class="count">共 %(n)d 版 · 挑一版告诉 AI 编号</span>
</div>
<main>
%(cards)s
</main>
</body>
</html>
""" % {"title": html.escape(title), "note": html.escape(note), "cols": cols,
       "n": len(files), "cards": "\n".join(cards) or '<p class="empty">目录里没有找到方案文件</p>'}


def main():
    ap = argparse.ArgumentParser(description="把多版设计方案并排展示")
    ap.add_argument("--dir", default=".", help="方案文件所在目录（默认当前目录）")
    ap.add_argument("--out", help="输出路径（默认 <dir>/对比.html）")
    ap.add_argument("--title", default="方案对比", help="页面标题")
    ap.add_argument("--note", default="", help="标题右侧说明")
    ap.add_argument("--cols", type=int, default=2, help="每行展示几版（默认 2）")
    ap.add_argument("--filter", dest="pattern", default="*.html", help="收集的文件模式（默认 *.html）")
    args = ap.parse_args()

    if not os.path.isdir(args.dir):
        print("目录不存在：%s" % args.dir)
        return 1
    out = args.out or os.path.join(args.dir, "对比.html")
    files = collect(args.dir, args.pattern, out)
    if not files:
        print("在 %s 下没有找到匹配 %s 的方案文件" % (args.dir, args.pattern))
        print("提示：每版方案存成独立 HTML，如 01-极简.html / 02-编辑风.html")
        return 1
    html_out = build(files, args.title, args.cols, args.note)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html_out)
    print("已生成对比页：%s" % out)
    print("收录 %d 版：%s" % (len(files), "、".join(style_name(f) for f in files)))
    print("用浏览器打开它，挑一版后告诉 AI 编号即可。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
