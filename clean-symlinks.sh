#!/usr/bin/env bash
# 软链接清理工具：清掉技能安装目录里积累的软链接残留。
#
# 背景：本仓库的技能靠软链接挂进各工具的 skills 目录（见 install.sh）。
# 技能改名 / 合并 / 删除、或**仓库换了位置**之后，旧链接会留在原地：
#   · 目标已不存在（仓库搬走、技能目录删掉）→ **失效链接**，可安全清理
#   · 仍指向本仓库现存技能 → 有效，属于"已安装"，只是碍眼时可整体摘掉
#
# 与 install.sh --prune 的分工：那个只认"目标在本仓库**当前**路径下"的失效链接，
# 仓库一搬家它就认不出来；本脚本按**链接本身**分类（目标在不在），不依赖仓库路径，
# 所以搬家后的残留也能扫出来。
#
# 用法：
#   ./clean-symlinks.sh                     体检：扫记住的安装目录（只报告、不删）
#   ./clean-symlinks.sh --dir <目录>         指定扫描目录（可重复；给了它就只扫这些）
#   ./clean-symlinks.sh --prune             删除「失效链接」
#   ./clean-symlinks.sh --uninstall         摘掉「指向本仓库」的全部链接（= 卸载已装技能）
#   ./clean-symlinks.sh --help
#
# 安全约定：
#   1. 默认只报告不动手；删除只针对**软链接本身**（rm -f 一个链接不会碰到它的目标）。
#   2. 非软链接的真实目录 / 文件一律不碰，只记一行"有真实目录"的提示。
#   3. --uninstall 也不碰"指向别处"的链接（那是别的仓库 / 工具装的，不归本脚本管）。
#   4. 退出码：0 = 干净或已按要求清理；1 = 存在失效链接但未清理（便于脚本里判断）。
#
# Bash 3.2 兼容（macOS 自带）：不用关联数组、不用 readarray。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$REPO_DIR/install.config"

DO_PRUNE=0
DO_UNINSTALL=0
DIRS=()

# 缺省（没有 install.config 或没给 --dir）时顺手看一眼的工具技能目录
CANDIDATES=(
  "$HOME/.claude/skills"
  "$HOME/.workbuddy/skills"
  "$HOME/.agents/skills"
  "$HOME/.cursor/skills"
)

die() { echo "错误：$*" >&2; exit 1; }

# 归一化路径：去掉末尾的 / 或 \，便于比对去重（与 install.sh 同口径）
norm_path() { printf '%s' "$1" | sed 's/[\/\\]*$//'; }

# 读出 install.config 里记住的安装目录（格式与 install.sh 一致：可带 copy/link 前缀）
config_dirs() {
  [ -f "$CONFIG_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                                                  # 去行内注释
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    case "$line" in
      copy\ *) printf '%s\n' "${line#copy }" ;;
      link\ *) printf '%s\n' "${line#link }" ;;
      *)       printf '%s\n' "$line" ;;
    esac
  done < "$CONFIG_FILE"
}

# ---------- 参数 ----------

need_value() {
  [ $# -ge 2 ] && [ -n "${2:-}" ] || die "$1 需要跟一个目录路径"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prune)     DO_PRUNE=1; shift ;;
    --uninstall) DO_UNINSTALL=1; shift ;;
    --dir)
      need_value "$1" "${2:-}"
      DIRS+=("${2/#\~/$HOME}"); shift 2 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知参数「$1」（用 --help 看用法）" ;;
  esac
done

# ---------- 扫描目录：分类 + 按需清理 ----------

TOTAL=0      # 扫到的软链接总数
OK=0         # 有效：指向本仓库现存技能
STALE=0      # 失效：目标已不存在
OTHER=0      # 指向别处（别的仓库 / 工具装的）
REAL=0       # 真实目录 / 文件（不碰）
REMOVED=0    # 本次实际删掉的链接数

# 扫描一个目标目录：逐条分类，--prune / --uninstall 命中就删。计数累加到全局。
scan_dir() {
  local tdir="$1" p base target
  echo "── 扫描：${tdir}"
  for p in "$tdir"/*; do
    # 空目录 / 通配符没展开时跳过（bash 3.2 没有 nullglob 的习惯写法）
    [ -e "$p" ] || [ -L "$p" ] || continue
    base="$(basename "$p")"

    if [ ! -L "$p" ]; then
      REAL=$((REAL + 1)); continue
    fi

    TOTAL=$((TOTAL + 1))
    target="$(readlink "$p")"

    if [ ! -e "$p" ]; then
      # 目标不存在 → 失效链接
      STALE=$((STALE + 1))
      if [ "$DO_PRUNE" -eq 1 ]; then
        rm -f "$p"; REMOVED=$((REMOVED + 1))
        echo "  ✂ 已删除失效链接 ${base} → ${target}"
      else
        echo "  ⚠️ 失效：${base} → ${target}"
      fi
    elif [ "$DO_UNINSTALL" -eq 1 ]; then
      case "$target" in
        "$REPO_DIR"/*)
          # 目标存在且在本仓库里 → 确认是本脚本所属仓库装的，才敢摘
          rm -f "$p"; REMOVED=$((REMOVED + 1))
          echo "  ✂ 已摘除 ${base}（指向本仓库，已卸载）"
          ;;
        *)
          echo "  ⚪ 指向别处（不动，不归本仓库管）：${base} → ${target}"
          ;;
      esac
    else
      case "$target" in
        "$REPO_DIR"/*) OK=$((OK + 1));       echo "  ✅ 有效：${base} → 本仓库" ;;
        *)             OTHER=$((OTHER + 1)); echo "  ⚪ 指向别处：${base} → ${target}" ;;
      esac
    fi
  done
  echo
}

# ---------- 确定扫描哪些目录 ----------

SCAN_DIRS=()
if [ ${#DIRS[@]} -gt 0 ]; then
  # 显式给了 --dir：只扫这些
  for d in "${DIRS[@]}"; do
    D="$(norm_path "$d")"
    [ -d "$D" ] || { echo "⚠️  跳过不存在的目录：${D}"; continue; }
    SCAN_DIRS+=("$D")
  done
else
  # 默认：记住的安装目录 ∪ 候选目录（去重）
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    D="$(norm_path "$d")"
    [ -d "$D" ] || continue
    dup=0
    for e in "${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}"; do
      [ "$e" = "$D" ] && dup=1
    done
    [ "$dup" -eq 0 ] && SCAN_DIRS+=("$D")
  done < <(config_dirs)
  for d in "${CANDIDATES[@]}"; do
    [ -d "$d" ] || continue
    D="$(norm_path "$d")"
    dup=0
    for e in "${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}"; do
      [ "$e" = "$D" ] && dup=1
    done
    [ "$dup" -eq 0 ] && SCAN_DIRS+=("$D")
  done
fi

[ ${#SCAN_DIRS[@]} -gt 0 ] || die "没有可扫描的目录。用 ./clean-symlinks.sh --dir <安装目录> 指定。"

MODE_DESC="体检（只报告）"
[ "$DO_PRUNE" -eq 1 ] && MODE_DESC="清理失效链接"
[ "$DO_UNINSTALL" -eq 1 ] && MODE_DESC="卸载指向本仓库的链接"
[ "$DO_PRUNE" -eq 1 ] && [ "$DO_UNINSTALL" -eq 1 ] && MODE_DESC="清理失效链接 + 卸载本仓库链接"

echo "软链接清理（仓库：${REPO_DIR}）"
echo "模式：${MODE_DESC}"
echo
for d in "${SCAN_DIRS[@]}"; do scan_dir "$d"; done

# ---------- 汇总 ----------

echo "汇总：软链接 ${TOTAL} 个 ｜ ✅ 有效 ${OK} ｜ ⚠️ 失效 ${STALE} ｜ ⚪ 别处 ${OTHER} ｜ 真实文件/目录 ${REAL} 个（不碰）"
[ "$REMOVED" -gt 0 ] && echo "本次已删除 ${REMOVED} 个链接。"
if [ "$STALE" -gt 0 ] && [ "$DO_PRUNE" -eq 0 ]; then
  echo
  echo "提示：有 ${STALE} 个失效链接未清理 —— 加 --prune 删除；想整体卸载已装技能用 --uninstall。"
  exit 1
fi
echo
echo "完成。"
