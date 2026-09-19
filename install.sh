#!/usr/bin/env bash
# 技能安装 / 更新工具。
#
# 用法：
#   ./install.sh <安装目录> [技能名…]   装到该目录，并**记住这个路径**
#   ./install.sh                        不带参数：把仓库技能**更新到所有记住过的路径**
#   ./install.sh <目录> --group report  只装某一组（report / query / plan / pm / dev / journal）
#                                       分组安装会自动带上入口 playbook
#   ./install.sh --targets              看记住了哪些安装目录（并逐个检查是否存在）
#   ./install.sh --forget <目录>        忘掉一个安装目录（不删已装的文件）
#   ./install.sh --copy <目录>          用拷贝代替软链接（默认软链接）
#   ./install.sh --no-entry             分组安装**不带**入口 playbook（移植用）
#   ./install.sh --prune               清掉指向本仓库但源已不存在的失效软链接（对全部记忆目录）
#   ./install.sh --lint                技能自包含性体检（不安装）
#   ./install.sh --list                列技能与分组，不安装
#   ./install.sh --update              兼容旧写法，等同不带参数
#
# 三条硬规矩（本工具的行为约定）：
#   1. **不主动创建工具的 skills 目录**——目标目录必须已存在，否则跳过并提示。
#   2. 记住的路径每次运行都会**重新检查是否存在**：不存在就跳过（比如换了机器、
#      盘没挂载、Windows 路径拿到 mac 上跑），不会瞎建目录。
#   3. 装过的目录记在仓库根的 `install.config`（每行一个路径，`#` 注释）。
#      该文件是**本机状态**，不要提交到 git（已在 .gitignore 里）。
#
# 为什么需要这一步：本仓库的技能都在**顶层目录**，而工具要求
# <技能目录>/<技能名>/SKILL.md。直接把仓库整个 clone 进技能目录会多套一层，
# 技能不会被发现。所以要么建软链接（默认），要么拷各技能文件夹（--copy）。
#
# 入口技能：playbook —— agent 找不着北时先读它，它按流程与状态把请求路由到执行技能。
# 它属于"入口"，**名字不要改**（改名 = agent 从原来的位置进不来）。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$REPO_DIR/install.config"

LINK_MODE=1          # 默认软链接
LIST_ONLY=0
LINT_ONLY=0
TARGETS_ONLY=0
NO_ENTRY=0
PRUNE=0
FORGET=""
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

# ---------- install.config：记住装过哪些目录 ----------

# 读出所有记住的路径（去掉注释/空行/首尾空白）
config_read() {
  [ -f "$CONFIG_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                 # 去行内注释
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$line" ] && printf '%s\n' "$line"
  done < "$CONFIG_FILE"
}

# 归一化：去掉末尾的 / 或 \，便于比对去重
norm_path() {
  printf '%s' "$1" | sed 's/[\/\\]*$//'
}

# 追加一条（已存在则不动）
config_add() {
  local p="$1" n
  n="$(norm_path "$p")"
  while IFS= read -r old; do
    [ "$(norm_path "$old")" = "$n" ] && return 0
  done < <(config_read)
  if [ ! -f "$CONFIG_FILE" ]; then
    {
      echo "# 技能安装目标（每行一个路径）。本文件是本机状态，不要提交到 git。"
      echo "# 由 ./install.sh <目录> 自动追加；手工增删也可以，改完存盘，下次运行生效。"
      echo "# Windows 路径写在 mac 上不会装（会提示不存在）——这正是期望的行为。"
    } > "$CONFIG_FILE"
  fi
  printf '%s\n' "$n" >> "$CONFIG_FILE"
  echo "  已记住安装目标：${n}"
}

# 删掉一条
config_forget() {
  local p="$1" n tmp
  n="$(norm_path "$p")"
  [ -f "$CONFIG_FILE" ] || { echo "  没有 install.config，无需忘记。"; return 0; }
  tmp="$(mktemp)"
  while IFS= read -r line; do
    case "$line" in
      \#*) printf '%s\n' "$line" >> "$tmp"; continue ;;
    esac
    if [ "$(norm_path "$line")" = "$n" ]; then
      continue
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$CONFIG_FILE"
  mv "$tmp" "$CONFIG_FILE"
  echo "  已忘记安装目标：${n}（已装的文件没动）"
}

all_skills() {
  local d
  for d in "$REPO_DIR"/*/; do
    [ -f "${d}SKILL.md" ] && basename "$d"
  done
}

# ---------- 参数 ----------

while [ $# -gt 0 ]; do
  case "$1" in
    --copy)   LINK_MODE=0; shift ;;
    --link)   LINK_MODE=1; shift ;;   # 兼容旧写法（现在默认就是软链接）
    --update) shift ;;                # 兼容旧写法：等同"不带参数"（更新所有记住的目录）
    --list)   LIST_ONLY=1; shift ;;
    --lint)   LINT_ONLY=1; shift ;;
    --targets) TARGETS_ONLY=1; shift ;;
    --no-entry) NO_ENTRY=1; shift ;;
    --prune)  PRUNE=1; shift ;;
    --forget) FORGET="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
    --group)
      if [ $# -lt 2 ]; then
        echo "错误：--group 需要跟一个分组名（report / query / plan / pm / dev / journal）" >&2
        exit 1
      fi
      GROUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [ -z "$TARGET" ]; then TARGET="$1"; else SKILLS+=("$1"); fi; shift ;;
  esac
done

# ---------- 体检模式（不安装）----------

# 自包含性体检：本仓库的技能都是"能被单独带走"的单元。
# 判据：① 技能目录内不得有跳出自身目录的相对路径；② 正文不得引用别的技能下的文件路径。
if [ "$LINT_ONLY" -eq 1 ]; then
  echo "自包含性体检（${REPO_DIR}）"
  echo "判据：① 不跳出自身目录 ② 不引用别的技能下的文件路径 ③ 同名参考文件不漂移"
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
  # 同名参考文件漂移检查：同一份文档在多个技能里各留一份（为保持各自自包含）时，内容必须一致。
  tmp="$(mktemp)"
  for f in "$REPO_DIR"/*/references/*.md; do
    [ -f "$f" ] || continue
    if command -v md5sum >/dev/null 2>&1; then h="$(md5sum "$f" | awk '{print $1}')"; else h="$(md5 -q "$f")"; fi
    printf '%s\t%s\t%s\n' "$(basename "$f")" "$h" "${f#"$REPO_DIR"/}" >> "$tmp"
  done
  drift=0
  prev_base=""; prev_hash=""; prev_path=""
  while IFS="$(printf '\t')" read -r base h path; do
    if [ "$base" = "$prev_base" ] && [ "$h" != "$prev_hash" ]; then
      drift=$((drift + 1))
      echo "  ⚠ 同名参考文件内容不一致（手工同步漏了）：${base}"
      echo "      ${prev_path}"
      echo "      ${path}"
    fi
    prev_base="$base"; prev_hash="$h"; prev_path="$path"
  done < <(sort "$tmp")
  rm -f "$tmp"
  if [ "$drift" -gt 0 ]; then
    warn=$((warn + drift))
    echo "      → 修正：把两份改成一致（或让其中一份引用另一份）"
  fi
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

# ---------- 看记忆的安装目标 ----------

if [ "$TARGETS_ONLY" -eq 1 ]; then
  echo "记住的安装目标（${CONFIG_FILE}）："
  found=0
  while IFS= read -r p; do
    found=1
    if [ -d "$p" ]; then
      n=$(ls -A "$p" 2>/dev/null | wc -l | tr -d ' ')
      echo "  ✅ ${p}（存在，已有 ${n} 项）"
    else
      echo "  ⚠️  ${p}（不存在——运行时装机会跳过它）"
    fi
  done < <(config_read)
  [ "$found" -eq 0 ] && echo "  （还没有记住任何目录；用 ./install.sh <安装目录> 装一次就会记住）"
  exit 0
fi

if [ -n "$FORGET" ]; then
  config_forget "$FORGET"
  exit 0
fi

# ---------- 列出技能与分组 ----------

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
  echo
  echo "记住的安装目标："
  if [ -f "$CONFIG_FILE" ]; then
    config_read | sed 's/^/  /'
  else
    echo "  （空；用 ./install.sh <安装目录> 装一次就会记住）"
  fi
  exit 0
fi

# ---------- 确定要装哪些技能 ----------

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

if [ ${#SKILLS[@]} -eq 0 ]; then
  SKILLS=()
  while IFS= read -r name; do SKILLS+=("$name"); done < <(all_skills)
fi

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "错误：仓库里没找到任何带 SKILL.md 的技能目录。" >&2
  exit 1
fi

# ---------- 确定要装到哪些目录 ----------

TARGETS=()
if [ -n "$TARGET" ]; then
  TARGETS=("${TARGET/#\~/$HOME}")
else
  while IFS= read -r p; do TARGETS+=("${p/#\~/$HOME}"); done < <(config_read)
  if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "还没有记住任何安装目录。" >&2
    echo >&2
    echo "用法：./install.sh <安装目录> [技能名…]   例如：" >&2
    echo "  ./install.sh ~/.workbuddy/skills      # WorkBuddy" >&2
    echo "  ./install.sh ~/.claude/skills         # Claude Code" >&2
    echo >&2
    echo "本工具**不会**替你创建技能目录。以下是本机已存在的候选（仅提示，未安装）：" >&2
    for cand in "$HOME/.claude/skills" "$HOME/.workbuddy/skills" "$HOME/.agents/skills" "$HOME/.cursor/skills"; do
      [ -d "$cand" ] && echo "  ✅ $cand" >&2
    done
    exit 1
  fi
fi

# 安装一个技能到指定目录。
# 返回码：0=新装/新链接，2=跳过（不是技能目录/目标不存在），3=已是最新
install_one() {
  local tdir="$1" name="$2" src="$REPO_DIR/$2" dst="$tdir/$2" keep ts
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
      echo "  原有 ${name} 目录已挪到 $(basename "$dst").bak-${ts}（未删除，确认后可自行清理）"
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

# ---------- 开工：逐个目标目录 ----------

first_ok=0
for tdir in "${TARGETS[@]}"; do
  echo "── 目标目录：$tdir"
  if [ ! -d "$tdir" ]; then
    echo "  ⚠️  路径不存在，**跳过**（本工具不创建技能目录）。"
    echo "      确认路径写对、或先由该工具自己建好目录，再来装。"
    continue
  fi

  ok=0; skipped=0; fresh=0
  for name in "${SKILLS[@]}"; do
    set +e
    install_one "$tdir" "$name"; rc=$?
    set -e
    case "$rc" in
      0) ok=$((ok + 1)) ;;
      2) skipped=$((skipped + 1)) ;;
      3) fresh=$((fresh + 1)) ;;
    esac
  done
  first_ok=1

  # 顺手报一下失效链接：指向本仓库、但仓库里已经没有这个技能了
  stale=0
  for p in "$tdir"/*; do
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

  if [ "$LINK_MODE" -eq 1 ]; then
    echo "  └ 新链接 ${ok} / 已是最新 ${fresh} / 跳过 ${skipped}"
  else
    echo "  └ 新安装 ${ok} / 已是最新 ${fresh} / 跳过 ${skipped}"
  fi
  [ "$stale" -gt 0 ] && [ "$PRUNE" -eq 0 ] && echo "  └ 另有 ${stale} 个失效链接（见上）"
  echo
done

# 显式给的目标目录：装成功了就记下来，下次不用再输
if [ -n "$TARGET" ] && [ "$first_ok" -eq 1 ]; then
  config_add "${TARGET/#\~/$HOME}"
fi

if [ "$first_ok" -eq 0 ]; then
  echo "没有任何目录被安装（上面每个目标都跳过了）。"
  echo "记忆文件：${CONFIG_FILE}（未新增条目）"
  exit 1
fi

if [ "$LINK_MODE" -eq 1 ]; then
  echo "提示：软链接模式下 git pull 后技能立即生效；仓库里**新增技能**后跑一次 ./install.sh 即可补齐。"
else
  echo "提示：拷贝模式下仓库更新后要重跑一次本工具；想省这一步，去掉 --copy（默认软链接）。"
fi
echo "记忆文件：${CONFIG_FILE}（./install.sh --targets 查看，--forget <目录> 移除）"
echo "入口技能：${ENTRY_SKILL} —— agent 找不着北时先读它，它按流程与状态路由到执行技能。"
