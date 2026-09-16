#!/usr/bin/env bash
# 把本仓库的技能安装到 AI 工具的技能目录。
#
# 用法：
#   ./install.sh                            装全部技能到自动探测到的技能目录
#   ./install.sh ~/.claude/skills           装到指定目录
#   ./install.sh --group report ~/.claude/skills
#                                           只装某一组（report / plan / pm）
#   ./install.sh ~/.claude/skills report-pipeline report-writer
#                                           只装点名的那几个
#   ./install.sh --link ~/.claude/skills    用软链接代替复制（git pull 后自动生效）
#   ./install.sh --list                     只列出仓库里的技能与分组，不安装
#
# 为什么需要这一步：本仓库的技能都在**顶层目录**，而工具要求
# <技能目录>/<技能名>/SKILL.md。直接把仓库整个 clone 进技能目录会多套一层，
# 技能不会被发现。所以要么拷各技能文件夹，要么用软链接。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK_MODE=0
LIST_ONLY=0
TARGET=""
GROUP=""
SKILLS=()

# 分组：一条命令装一整套相关的技能。
# 为什么用 case 而不是关联数组：macOS 自带 bash 3.2 不支持 declare -A。
group_skills() {
  case "$1" in
    report|日报) echo "report-pipeline report-draft-filter report-writer" ;;
    plan|方案)   echo "plan-discussion plan-execution plan-lock" ;;
    pm|产品)     echo "prd-authoring requirement-clarification user-story-acceptance competitive-or-feature-brief release-note-pm meeting-to-action" ;;
    *) return 1 ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --link) LINK_MODE=1; shift ;;
    --list) LIST_ONLY=1; shift ;;
    --group)
      if [ $# -lt 2 ]; then
        echo "错误：--group 需要跟一个分组名（report / plan / pm）" >&2
        exit 1
      fi
      GROUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
  echo
  echo "分组（--group <名>）："
  echo "  report  日报三件套         $(group_skills report)"
  echo "  plan    方案讨论→执行→锁定  $(group_skills plan)"
  echo "  pm      产品经理常用        $(group_skills pm)"
  exit 0
fi

if [ -n "$GROUP" ]; then
  if ! grp="$(group_skills "$GROUP")"; then
    echo "错误：未知分组「${GROUP}」。可用分组：report / plan / pm" >&2
    exit 1
  fi
  # shellcheck disable=SC2206
  SKILLS=($grp)
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
    echo "  已链接 ${name}"
  else
    # 旧版曾把运行时数据放在 <技能>/data/（新版已改到各工作区内）。
    # 若还存在就保住，避免误删历史素材卡。
    keep=""
    if [ -d "$dst/data" ]; then
      keep="$(mktemp -d)"
      cp -R "$dst/data/." "$keep/"
    fi
    rm -rf "$dst"
    cp -R "$src" "$dst"
    if [ -n "$keep" ]; then
      mkdir -p "$dst/data"
      cp -R "$keep/." "$dst/data/"
      rm -rf "$keep"
      echo "  已安装 ${name}（保留了原有 data/ 数据）"
    else
      echo "  已安装 ${name}"
    fi
  fi
  ok=$((ok + 1))
done

echo
echo "完成：${ok} 个技能 → ${TARGET}（跳过 ${skip} 个）"
if [ "$LINK_MODE" -eq 0 ]; then
  echo "提示：源仓库更新后要重新跑一次本脚本；想省这一步，用 --link 装软链接。"
fi
