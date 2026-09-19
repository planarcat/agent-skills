#!/usr/bin/env bash
# 把本仓库的技能安装 / 更新到 AI 工具的技能目录。
#
# 用法：
#   ./install.sh                            装全部技能（默认软链接，git pull 后即生效）
#   ./install.sh ~/.claude/skills           装到指定目录
#   ./install.sh --group report ~/.claude/skills
#                                           只装某一组（report / query / plan / pm / dev / journal）
#                                           分组安装会自动带上入口 playbook
#   ./install.sh ~/.claude/skills report-pipeline report-writer
#                                           只装点名的那几个
#   ./install.sh --no-entry --group report   移植用：装一组但**不带入口** playbook
#   ./install.sh --update                   重扫仓库：补齐漏装的、报告失效链接（不动已装好的）
#   ./install.sh --copy [目标目录]          退回拷贝模式（默认是软链接）
#   ./install.sh --prune                    顺手删掉指向本仓库但已失效的软链接
#   ./install.sh --lint                     自包含性体检：单个技能能否被单独带走
#   ./install.sh --list                     只列出技能与分组，不安装
#
# 为什么需要这一步：本仓库的技能都在**顶层目录**，而工具要求
# <技能目录>/<技能名>/SKILL.md。直接把仓库整个 clone 进技能目录会多套一层，
# 技能不会被发现。所以要么建软链接（默认），要么拷各技能文件夹（--copy）。
#
# 入口技能：playbook —— agent 找不着北时先读它，它按流程与状态把请求路由到执行技能。
# 它属于"入口"，**名字不要改**（改名 = agent 从原来的位置进不来）。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK_MODE=1          # 默认软链接
LIST_ONLY=0
LINT_ONLY=0
UPDATE_ONLY=0
NO_ENTRY=0
PRUNE=0
TARGET=""
GROUP=""
SKILLS=()

ENTRY_SKILL="playbook"   # 入口技能：分组安装时自动带上

# 分组：一条命令装一整套相关的技能。
# 为什么用 case 而不是关联数组：macOS 自带 bash 3.2 不支持 declare -A。
group_skills() {
  case "$1" in
    report|日报)  echo "report-pipeline report-draft-filter report-writer" ;;
    query|查询)   echo "cnb-push-audit tapd-todo-query" ;;
    plan|方案)    echo "plan-discussion plan-execution plan-lock" ;;
    pm|产品)      echo "prd-authoring requirement-clarification user-story-acceptance competitive-or-feature-brief release-note-pm meeting-to-action" ;;
    dev|开发)     echo "development-guardrails change-advice change-impact-regression impact-surface-audit resolve-merge-conflict test-case-authoring create-requirement-branch generate-commit" ;;
    journal|记录) echo "record-change-log record-development-blog" ;;
    *) return 1 ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy)   LINK_MODE=0; shift ;;
    --link)   LINK_MODE=1; shift ;;   # 兼容旧写法（现在默认就是软链接）
    --list)   LIST_ONLY=1; shift ;;
    --lint)   LINT_ONLY=1; shift ;;
    --update) UPDATE_ONLY=1; shift ;;
    --no-entry) NO_ENTRY=1; shift ;;  # 移植用：不带入口 playbook
    --prune)  PRUNE=1; shift ;;
    --group)
      if [ $# -lt 2 ]; then
        echo "错误：--group 需要跟一个分组名（report / query / plan / pm / dev / journal）" >&2
        exit 1
      fi
      GROUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [ -z "$TARGET" ]; then TARGET="$1"; else SKILLS+=("$1"); fi; shift ;;
  esac
done

all_skills() {
  local d
  for d in "$REPO_DIR"/*/; do
    [ -f "${d}SKILL.md" ] && basename "$d"
  done
}

# 自包含性体检：本仓库的技能都是"能被单独带走"的单元。
# 判据：① 技能目录内不得有跳出自身目录的相对路径；② 正文不得引用别的技能下的文件路径。
if [ "$LINT_ONLY" -eq 1 ]; then
  echo "自包含性体检（${REPO_DIR}）"
  echo "判据：① 不跳出自身目录 ② 不引用别的技能下的文件路径"
  echo
  warn=0
  tips=0
  for d in "$REPO_DIR"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    name="$(basename "$d")"
    out_of_scope="$(grep -rInE '(\.\./)+[A-Za-z]' "${d}SKILL.md" 2>/dev/null | grep -v '\.\.\./' || true)"
    cross=""
    for other in $(all_skills); do
      [ "$other" = "$name" ] && continue
      if grep -q "${other}/" "${d}SKILL.md" 2>/dev/null; then cross="$cross $other"; fi
    done
    if [ -n "$out_of_scope" ]; then
      warn=$((warn + 1))
      echo "  ⚠ ${name}：发现跳出自身目录的相对路径"
      echo "$out_of_scope" | head -5 | sed 's/^/      /'
    fi
    if [ -n "$cross" ]; then
      tips=$((tips + 1))
      echo "  · ${name}：正文里引用了别的技能下的文件路径 →${cross}"
      echo "      同仓库（或同组一起移植）时能解析；若只搬本技能，这些指针会指空。"
    fi
  done
  if [ "$warn" -eq 0 ] && [ "$tips" -eq 0 ]; then
    echo "  ✅ 全部技能自包含：任意单个技能或技能组都能直接拷走使用（不带入口 playbook 也能跑）。"
  elif [ "$warn" -eq 0 ]; then
    echo "  ✅ 没有真依赖：所有技能都自包含；上面 ${tips} 条只是文档指针，同组一起搬就不会指空。"
  fi
  echo
  echo "移植示例："
  echo "  ./install.sh --copy ~/export report-writer            # 拷一个技能成独立包"
  echo "  ./install.sh --copy --no-entry --group report ~/export # 拷一整组（不带入口）"
  exit 0
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "仓库里的技能（${REPO_DIR}）："
  all_skills | sed 's/^/  /'
  echo
  echo "入口：${ENTRY_SKILL}（技能地图 + 流程路由；找不着北先读它）"
  echo
  echo "分组（--group <名>）："
  echo "  report  日报三件套         $(group_skills report)"
  echo "  query   数据源核查         $(group_skills query)"
  echo "  plan    方案讨论→执行→锁定  $(group_skills plan)"
  echo "  pm      产品经理常用        $(group_skills pm)"
  echo "  dev     开发与质量          $(group_skills dev)"
  echo "  journal 记录与沉淀          $(group_skills journal)"
  exit 0
fi

if [ -n "$GROUP" ]; then
  if ! grp="$(group_skills "$GROUP")"; then
    echo "错误：未知分组「${GROUP}」。可用分组：report / query / plan / pm / dev / journal" >&2
    exit 1
  fi
  # shellcheck disable=SC2206
  if [ "$NO_ENTRY" -eq 1 ]; then
    SKILLS=($grp)                 # 移植用：不带入口
  else
    SKILLS=($grp $ENTRY_SKILL)    # 日常：分组安装自动带上入口
  fi
fi

if [ "$UPDATE_ONLY" -eq 1 ] || [ ${#SKILLS[@]} -eq 0 ]; then
  SKILLS=()
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

# 装一个技能。返回码：0=新装/新链接，2=跳过（不是技能目录），3=已是最新
install_one() {
  local name="$1" src="$REPO_DIR/$1" dst="$TARGET/$1" keep ts
  if [ ! -f "$src/SKILL.md" ]; then
    echo "  跳过 ${name}（不是技能目录，缺 SKILL.md）"
    return 2
  fi

  if [ "$LINK_MODE" -eq 1 ]; then
    # 已经是正确的软链接 → 幂等跳过（这正是日常更新不必重装的原因）
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      echo "  已是最新 ${name}（软链接指向仓库）"
      return 3
    fi
    # 目标位置是真实目录 → 先挪到一边，不直接删（保住可能的本地改动与旧版 data/）
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      ts="$(date +%Y%m%d%H%M%S)"
      mv "$dst" "$dst.bak-$ts"
      echo "  原有 ${name} 目录已挪到 $(basename "$dst").bak-$ts（未删除，确认后可自行清理）"
    fi
    rm -f "$dst"
    ln -s "$src" "$dst"
    echo "  已链接 ${name}"
    return 0
  fi

  # ---- 拷贝模式 ----
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
  return 0
}

ok=0; skipped=0; fresh=0
for name in "${SKILLS[@]}"; do
  set +e
  install_one "$name"; rc=$?
  set -e
  case "$rc" in
    0) ok=$((ok + 1)) ;;
    2) skipped=$((skipped + 1)) ;;
    3) fresh=$((fresh + 1)) ;;
  esac
done

# 顺手报一下失效链接：指向本仓库、但仓库里已经没有这个技能了
stale=0
for p in "$TARGET"/*; do
  [ -L "$p" ] || continue
  case "$(readlink "$p")" in
    "$REPO_DIR"/*)
      if [ ! -e "$p" ]; then
        stale=$((stale + 1))
        if [ "$PRUNE" -eq 1 ]; then
          rm -f "$p"; echo "  已清理失效链接 $(basename "$p")（源已不在仓库）"
        else
          echo "  提示：$(basename "$p") 是失效链接（仓库里已无此技能）；加 --prune 可清理"
        fi
      fi
      ;;
  esac
done

echo
if [ "$LINK_MODE" -eq 1 ]; then
  echo "完成：新链接 ${ok} 个，已是最新 ${fresh} 个，跳过 ${skipped} 个 → ${TARGET}"
  echo "提示：软链接模式下 git pull 后技能立即生效；仓库里新增技能后跑一次 ./install.sh --update 即可补链。"
else
  echo "完成：新安装 ${ok} 个，已是最新 ${fresh} 个，跳过 ${skipped} 个 → ${TARGET}"
  echo "提示：拷贝模式下仓库更新后要重新跑一次本脚本；想省这一步，去掉 --copy（默认软链接）。"
fi
[ "$stale" -gt 0 ] && echo "另：发现 ${stale} 个失效链接（见上），加 --prune 可清理。"
echo "入口技能：${ENTRY_SKILL} —— agent 找不着北时先读它，它按流程与状态路由到执行技能。"
