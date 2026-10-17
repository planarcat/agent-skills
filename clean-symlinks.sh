#!/usr/bin/env bash
# 软链接 / 物理拷贝清理工具：清掉各工具 skills 目录里积累的安装残留。
#
# 背景：本仓库的技能靠软链接挂进各工具的 skills 目录（见 install.sh），也可用 --copy
# 装成真实目录。技能改名 / 合并 / 删除、或**仓库换了位置**之后，残留会留在原地。
#
# 四种动作（可组合；**不给动作 = 只体检不删**）：
#   ① --prune      清理失效链接（目标已不存在）——范围固定「全部工具」，无工具选择
#   ② --rm-links   只删软链接（删掉指向本仓库的**有效**链接，不动 install.config 记账）
#   ③ --unlink     解除链接 = 删软链接（同②）+ 把该工具从 install.config 除名
#   ④ --rm-copies  删除物理文件 = 删掉**与仓库内容一致**的同名技能拷贝 / 旧备份
#
# 工具范围（②③④ 通用）：
#   --tool <别名>[,<别名>…]   多选指定工具（别名用 --list-tools 查）
#   --all                    全部工具（不给范围就是全部）
#   --dir <路径>              直接点名目录（可重复；给了它就以它为准，忽略 --tool）
#   --list-tools             只列出发现的工具与别名，不执行
#
# 用法示例：
#   ./clean-symlinks.sh                                 体检：全部工具，只报告
#   ./clean-symlinks.sh --prune                         清掉所有失效链接
#   ./clean-symlinks.sh --rm-links --tool zcode,pi      只删这两个工具的软链接
#   ./clean-symlinks.sh --unlink --all                  全部工具解除链接（含除名）
#   ./clean-symlinks.sh --rm-copies --tool agents       删物理拷贝（仅内容一致的）
#
# 安全约定（按重要性排序）：
#   1. 默认只报告不动手；动作 flag 本身就是"确认执行"，不需要二次确认。
#   2. 删除软链接一律 `rm -f`：只打链接本身，碰不到它的目标。
#   3. ④ 删物理拷贝只删 `diff -rq` **与仓库完全一致**的；有差异的一律保留并告警
#      （那是可能有本地改动的副本，不该由脚本替你裁决）。
#   4. 「指向别处」的链接（别的仓库 / 工具装的）永远不碰，只报告。
#   5. ② 不碰失效链接（那是 ① 的职责）；③ 的除名只影响记账，不删仓库里的东西。
#   6. 退出码：0 = 干净或已按要求清理；1 = 存在失效链接但未清理。
#
# Bash 3.2 兼容（macOS 自带）：不用关联数组、不用 readarray。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$REPO_DIR/install.config"

# 两库并存：本脚本把「同父目录下、名字以 -skills 结尾的兄弟仓」也认作自家
# （公司库 lingchuang-skills 就是 agent-skills 的兄弟仓）。没有兄弟仓时列表为空，行为不变。
SIBLINGS=()
for d in "$(dirname "$REPO_DIR")"/*-skills; do
  [ -d "$d" ] || continue
  if [ "$d" = "$REPO_DIR" ]; then continue; fi
  SIBLINGS+=("$d")
done

# 判断一个链接目标是不是"自家仓库"（本仓或兄弟仓）
is_ours() {
  local t="$1" s
  case "$t" in
    "$REPO_DIR"/*) return 0 ;;
  esac
  for s in "${SIBLINGS[@]+"${SIBLINGS[@]}"}"; do
    case "$t" in
      "$s"/*) return 0 ;;
    esac
  done
  return 1
}

ACT_PRUNE=0
ACT_RMLINKS=0
ACT_UNLINK=0
ACT_RMCOPIES=0
LIST_TOOLS=0
TOOL_SEL=""
DIRS=()

# 没记住安装目录时，顺手看一眼的常见工具技能目录
CANDIDATES=(
  "$HOME/.claude/skills"
  "$HOME/.workbuddy/skills"
  "$HOME/.agents/skills"
  "$HOME/.cursor/skills"
)

die() { echo "错误：$*" >&2; exit 1; }

# 归一化路径：去掉末尾的 / 或 \，便于比对去重（与 install.sh 同口径）
norm_path() { printf '%s' "$1" | sed 's/[\/\\]*$//'; }

# 工具别名：路径去掉 $HOME 前缀、去掉尾部 /skills，再把 / 换成 -、去掉首部 .
# 例：~/.zcode/skills → zcode ｜ ~/.pi/agent/skills → pi-agent
alias_of() {
  local p="$1"
  case "$p" in
    "$HOME"/*) p="${p#"$HOME"/}" ;;
    "$HOME")   p="" ;;
  esac
  p="${p%/skills}"
  p="$(printf '%s' "$p" | tr '/' '-')"
  p="${p#.}"
  printf '%s' "$p" | sed 's/^-\{1,\}//'
}

# 读出 install.config 里记住的安装目录（与 install.sh 同格式：可带 copy/link 前缀）
config_dirs() {
  [ -f "$CONFIG_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    case "$line" in
      copy\ *) printf '%s\n' "${line#copy }" ;;
      link\ *) printf '%s\n' "${line#link }" ;;
      *)       printf '%s\n' "$line" ;;
    esac
  done < "$CONFIG_FILE"
}

# 在 install.config 里划掉一个目录（解除记账；不动已装的文件）
config_forget_dir() {
  local want tmp line
  want="$(norm_path "$1")"
  [ -f "$CONFIG_FILE" ] || return 0
  tmp="$(mktemp)"
  while IFS= read -r line; do
    case "$line" in
      \#*) printf '%s\n' "$line" >> "$tmp"; continue ;;
    esac
    case "$line" in
      copy\ *) cur="${line#copy }" ;;
      link\ *) cur="${line#link }" ;;
      *)       cur="$line" ;;
    esac
    [ "$(norm_path "$cur")" = "$want" ] || printf '%s\n' "$line" >> "$tmp"
  done < "$CONFIG_FILE"
  mv "$tmp" "$CONFIG_FILE"
}

# ---------- 参数 ----------

need_value() { [ $# -ge 2 ] && [ -n "${2:-}" ] || die "$1 需要跟一个值"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prune)     ACT_PRUNE=1; shift ;;
    --rm-links)  ACT_RMLINKS=1; shift ;;
    --unlink)    ACT_UNLINK=1; shift ;;
    --rm-copies) ACT_RMCOPIES=1; shift ;;
    --all)       shift ;;
    --list-tools) LIST_TOOLS=1; shift ;;
    --tool)
      need_value "$1" "${2:-}"
      if [ -n "$TOOL_SEL" ]; then TOOL_SEL="$TOOL_SEL,$2"; else TOOL_SEL="$2"; fi
      shift 2 ;;
    --dir)
      need_value "$1" "${2:-}"
      DIRS+=("${2/#\~/$HOME}"); shift 2 ;;
    -h|--help) awk 'NR>1 && /^set -euo/{exit} NR>1{print}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知参数「$1」（用 --help 看用法）" ;;
  esac
done

# ---------- 发现工具目录 ----------

ALL_ALIASES=()
ALL_DIRS=()

# 加入一个目录（去重；不存在则提示后跳过）
add_dir() {
  local d="$1" e
  d="$(norm_path "$d")"
  [ -n "$d" ] || return 0
  [ -d "$d" ] || return 0
  for e in "${ALL_DIRS[@]+"${ALL_DIRS[@]}"}"; do
    [ "$e" = "$d" ] && return 0
  done
  ALL_DIRS+=("$d")
  ALL_ALIASES+=("$(alias_of "$d")")
}

if [ ${#DIRS[@]} -gt 0 ]; then
  # 显式 --dir：以它为准
  for d in "${DIRS[@]}"; do
    if [ -d "$(norm_path "$d")" ]; then add_dir "$d"; else echo "⚠️  跳过不存在的目录：$(norm_path "$d")" >&2; fi
  done
else
  while IFS= read -r d; do add_dir "$d"; done < <(config_dirs)
  for d in "${CANDIDATES[@]}"; do add_dir "$d"; done
fi

# 按 --tool 过滤（别名精确匹配；未识别的别名直接报错，避免"以为选了其实没选"）
SCAN_DIRS=()
SCAN_ALIASES=()
if [ -n "$TOOL_SEL" ] && [ ${#DIRS[@]} -eq 0 ]; then
  IFS=',' read -r -a wanted <<< "$TOOL_SEL"
  for w in "${wanted[@]}"; do
    w="$(printf '%s' "$w" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$w" ] || continue
    hit=0; i=0
    for a in "${ALL_ALIASES[@]+"${ALL_ALIASES[@]}"}"; do
      if [ "$a" = "$w" ]; then SCAN_DIRS+=("${ALL_DIRS[$i]}"); SCAN_ALIASES+=("$a"); hit=1; fi
      i=$((i + 1))
    done
    [ "$hit" -eq 1 ] || die "工具别名「${w}」不在已发现列表里（用 --list-tools 查看可用别名）"
  done
else
  i=0
  while [ "$i" -lt ${#ALL_DIRS[@]} ]; do
    SCAN_DIRS+=("${ALL_DIRS[$i]}"); SCAN_ALIASES+=("${ALL_ALIASES[$i]}")
    i=$((i + 1))
  done
fi

if [ "$LIST_TOOLS" -eq 1 ]; then
  echo "发现的工具技能目录（--tool 用别名多选，逗号分隔）："
  if [ ${#ALL_DIRS[@]} -eq 0 ]; then
    echo "  （没发现任何目录；用 ./clean-symlinks.sh --dir <目录> 指定）"
  else
    i=0
    for a in "${ALL_ALIASES[@]}"; do
      n="$(ls -A "${ALL_DIRS[$i]}" 2>/dev/null | wc -l | tr -d ' ')"
      echo "  ${a}	${ALL_DIRS[$i]}（${n} 项）"
      i=$((i + 1))
    done
  fi
  echo
  echo "记账文件：${CONFIG_FILE}"
  exit 0
fi

[ ${#SCAN_DIRS[@]} -gt 0 ] || die "没有可扫描的目录（用 --dir <目录> 指定，或先 ./install.sh <目录> 装一次记住它）"

# ---------- 扫描：分类 + 按需处理 ----------

TOTAL=0      # 扫到的软链接总数
OK=0         # 有效：指向本仓库现存技能
STALE=0      # 失效：目标已不存在
OTHER=0      # 指向别处（别的仓库 / 工具装的）
COPY_SAME=0  # 物理拷贝：与仓库内容一致（④ 可删）
COPY_DIFF=0  # 物理拷贝：与仓库内容不一致（一律不删）
REAL=0       # 与仓库无关的真实文件 / 目录（不碰）
REMOVED=0    # 本次删掉的软链接数
RMCOPIES=0   # 本次删掉的物理拷贝数

# 给出承载该技能的仓库根（本仓优先，其次兄弟库）；都不含则输出空
skill_repo_of() {
  local name="$1" s
  if [ -f "$REPO_DIR/$name/SKILL.md" ]; then printf '%s' "$REPO_DIR"; return 0; fi
  for s in "${SIBLINGS[@]+"${SIBLINGS[@]}"}"; do
    if [ -f "$s/$name/SKILL.md" ]; then printf '%s' "$s"; return 0; fi
  done
  return 0
}

# 判断某条目是否是"自家仓库某个技能的物理拷贝"，并处理
# $1=所在目录 $2=条目路径 $3=条目名（可能是 <技能> 或 <技能>.bak-<时间戳>）
handle_real() {
  local tdir="$1" p="$2" base="$3" skill repodir
  repodir="$(skill_repo_of "$base")"
  if [ -n "$repodir" ]; then
    skill="$base"
  else
    case "$base" in
      *.bak-*) skill="${base%%.bak-*}" ;;
      *)       skill="" ;;
    esac
    if [ -n "$skill" ]; then repodir="$(skill_repo_of "$skill")"; fi
    if [ -z "$repodir" ]; then REAL=$((REAL + 1)); return 0; fi
  fi

  if [ -d "$p" ] && diff -rq "$repodir/$skill" "$p" >/dev/null 2>&1; then
    COPY_SAME=$((COPY_SAME + 1))
    if [ "$ACT_RMCOPIES" -eq 1 ]; then
      rm -rf "$p"; RMCOPIES=$((RMCOPIES + 1))
      echo "  ✂ 已删物理拷贝 ${base}（与仓库一致）"
    else
      echo "  📄 物理拷贝：${base}（与仓库一致，--rm-copies 可删）"
    fi
  else
    COPY_DIFF=$((COPY_DIFF + 1))
    echo "  ⛔ 物理拷贝：${base}（与仓库不一致 / 可能是本地改动过的 → **不删**，人工确认）"
  fi
  return 0
}

# 扫描一个目标目录：逐个条目分类，命中动作就执行。计数累加到全局。
scan_dir() {
  local tdir="$1" talias="$2" p base target
  echo "── 扫描：${tdir}（${talias}）"
  for p in "$tdir"/*; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    base="$(basename "$p")"

    if [ ! -L "$p" ]; then
      handle_real "$tdir" "$p" "$base"
      continue
    fi

    TOTAL=$((TOTAL + 1))
    target="$(readlink "$p")"

    if [ ! -e "$p" ]; then
      # ① 失效链接：目标已不存在（仓库搬走 / 技能被删）
      STALE=$((STALE + 1))
      if [ "$ACT_PRUNE" -eq 1 ]; then
        rm -f "$p"; REMOVED=$((REMOVED + 1))
        echo "  ✂ 已删失效链接 ${base} → ${target}"
      else
        echo "  ⚠️ 失效：${base} → ${target}"
      fi
      continue
    fi

    if is_ours "$target"; then
      # ②③ 指向自家仓库（本仓 / 兄弟库）现存技能的**有效**链接
      OK=$((OK + 1))
      if [ "$ACT_RMLINKS" -eq 1 ] || [ "$ACT_UNLINK" -eq 1 ]; then
        rm -f "$p"; REMOVED=$((REMOVED + 1))
        echo "  ✂ 已删链接 ${base}（指向自家仓库）"
      else
        echo "  ✅ 有效：${base} → 自家仓库"
      fi
    else
      OTHER=$((OTHER + 1))
      echo "  ⚪ 指向别处（不动，不归本仓库管）：${base} → ${target}"
    fi
  done
  echo
}

MODE_DESC="体检（只报告，不删）"
ACTIONS=""
[ "$ACT_PRUNE" -eq 1 ]    && ACTIONS="${ACTIONS}①清理失效 "
[ "$ACT_RMLINKS" -eq 1 ]  && ACTIONS="${ACTIONS}②只删软链接 "
[ "$ACT_UNLINK" -eq 1 ]   && ACTIONS="${ACTIONS}③解除链接 "
[ "$ACT_RMCOPIES" -eq 1 ] && ACTIONS="${ACTIONS}④删物理拷贝 "
[ -n "$ACTIONS" ] && MODE_DESC="${ACTIONS}"

echo "软链接 / 物理拷贝清理（仓库：${REPO_DIR}）"
echo "动作：${MODE_DESC}"
if [ "$ACT_PRUNE" -eq 1 ] && [ -n "$TOOL_SEL" ]; then
  echo "提示：① 清理失效一律全扫（按你的口径它没有工具选择），--tool 对它不生效。"
fi
echo
i=0
for d in "${SCAN_DIRS[@]}"; do
  scan_dir "$d" "${SCAN_ALIASES[$i]}"
  i=$((i + 1))
done

# ---------- ③ 解除记账（从 install.config 除名）----------

if [ "$ACT_UNLINK" -eq 1 ]; then
  i=0
  for d in "${SCAN_DIRS[@]}"; do
    config_forget_dir "$d"
    echo "已解除记账：${d}"
    i=$((i + 1))
  done
  echo
fi

# ---------- 汇总 ----------

echo "汇总：软链接 ${TOTAL} 个 ｜ ✅ 有效 ${OK} ｜ ⚠️ 失效 ${STALE} ｜ ⚪ 别处 ${OTHER}"
echo "      物理拷贝 $((COPY_SAME + COPY_DIFF)) 个（与仓库一致 ${COPY_SAME} ｜ 有差异 ${COPY_DIFF}，不删） ｜ 其他真实文件/目录 ${REAL} 个（不碰）"
[ "$REMOVED" -gt 0 ] && echo "本次已删软链接 ${REMOVED} 个。"
[ "$RMCOPIES" -gt 0 ] && echo "本次已删物理拷贝 ${RMCOPIES} 个。"
if [ "$STALE" -gt 0 ] && [ "$ACT_PRUNE" -eq 0 ]; then
  echo
  echo "提示：有 ${STALE} 个失效链接未清理 —— 加 --prune 删除。"
  exit 1
fi
echo
echo "完成。"
