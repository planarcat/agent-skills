#!/usr/bin/env bash
# 把本仓库的技能安装到 AI 工具的技能目录。
#
# 用法：
#   ./install.sh                            装全部技能到自动探测到的技能目录
#   ./install.sh ~/.claude/skills           装到指定目录
#   ./install.sh ~/.claude/skills report-pipeline report-writer
#                                           只装点名的那几个
#   ./install.sh --link ~/.claude/skills    用软链接代替复制（git pull 后自动生效）
#   ./install.sh --list                     只列出仓库里的技能，不安装
#
# 为什么需要这一步：本仓库的技能都在**顶层目录**，而工具要求
# <技能目录>/<技能名>/SKILL.md。直接把仓库整个 clone 进技能目录会多套一层，
# 技能不会被发现。所以要么拷各技能文件夹，要么用软链接。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK_MODE=0
LIST_ONLY=0
TARGET=""
SKILLS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --link) LINK_MODE=1; shift ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [ -z "$TARGET" ]; then TARGET="$1"; else SKILLS+=("$1"); fi; shift ;;
  esac
done

all_skills() {
  local d
  for d in "$REPO_DIR"/*/; do
    [ -f "${d}SKILL.md" ] && basename "$d"
  done
}

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "仓库里的技能（${REPO_DIR}）："
  all_skills | sed 's/^/  /'
  exit 0
fi

if [ ${#SKILLS[@]} -eq 0 ]; then
  while IFS= read -r name; do SKILLS+=("$name"); done < <(all_skills)
fi

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "错误：仓库里没找到任何带 SKILL.md 的技能目录。" >&2
  exit 1
fi

if [ -z "$TARGET" ]; then
  for cand in "$HOME/.claude/skills" "$HOME/.workbuddy/skills" "$HOME/.agents/skills" "$HOME/.cursor/skills"; do
    if [ -d "$cand" ]; then TARGET="$cand"; break; fi
  done
  TARGET="${TARGET:-$HOME/.claude/skills}"
  echo "未指定目标目录，自动选用：$TARGET"
fi

TARGET="${TARGET/#\~/$HOME}"
mkdir -p "$TARGET"

case "$(cd "$TARGET" && pwd)/" in
  "$REPO_DIR"/*)
    echo "错误：目标目录在仓库内部（${TARGET}），会造成递归。请换一个位置。" >&2
    exit 1
    ;;
esac

ok=0
skip=0
for name in "${SKILLS[@]}"; do
  src="$REPO_DIR/$name"
  if [ ! -f "$src/SKILL.md" ]; then
    echo "  跳过 ${name}（不是技能目录，缺 SKILL.md）"
    skip=$((skip + 1))
    continue
  fi
  dst="$TARGET/$name"
  if [ "$LINK_MODE" -eq 1 ]; then
    rm -rf "$dst"
    ln -s "$src" "$dst"
    echo "  已链接 $name"
  else
    rm -rf "$dst"
    cp -R "$src" "$dst"
    echo "  已安装 $name"
  fi
  ok=$((ok + 1))
done

echo
echo "完成：${ok} 个技能 → ${TARGET}（跳过 ${skip} 个）"
if [ "$LINK_MODE" -eq 0 ]; then
  echo "提示：源仓库更新后要重新跑一次本脚本；想省这一步，用 --link 装软链接。"
fi
