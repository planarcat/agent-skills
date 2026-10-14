#!/usr/bin/env bash
# cleanup-branch.sh —— 清理分支技能的一条龙脚本（2026-10-14 用户口径）
# 默认 dry-run：只打印清单，什么都不动；加 --yes 才真删。
# 用法（在目标业务仓内运行，且必须沙箱外执行）：
#   bash cleanup-branch.sh <U|F|D|S> <需求id> [--yes] [--keep-remote] [--allow-shell-suspect]
# 设计原则：规则固化在脚本内，agent 只调用、不判断；规则与技能正文一致，改口径两处同改。
#
# 清理范围（五项 + worktree 目录）：
#   1 本地开发分支  2 本地合并分支(To-test)  3 远程开发分支  4 远程合并分支  5 本地开发服务器(pm2)
#   6 worktree 目录（与分支同名，原仓旁边同级）
# 硬门槛：开发分支必须「已进生产」且「非空壳」——否则拒绝执行（退出码非 0，不做任何删除）。

set -e

die() { printf '❌ %s\n' "$1" >&2; exit 1; }
note() { printf '%s\n' "$1"; }

# ---------- 取数字串后 4 位，不足左补 0（与 create-branch.sh 同源）----------
last4() {
  local s="$1"
  while [ ${#s} -lt 4 ]; do s="0$s"; done
  printf '%s' "${s: -4}"
}

# ---------- 入参解析 ----------
POS="$1"; ID="$2"
[ -n "$POS" ] && [ -n "$ID" ] || die "用法：cleanup-branch.sh <U|F|D|S> <需求id> [--yes] [--keep-remote] [--allow-shell-suspect]"
case "$POS" in
  U|F|D|S) ;;
  *) die "端位必须是 U/F/D/S（U=用户端 F=工厂端 D=设计器 S=ShopAgent）" ;;
esac

shift 2 || true
YES=0; KEEP_REMOTE=0; ALLOW_SUSPECT=0
for a in "$@"; do
  case "$a" in
    --yes) YES=1 ;;
    --keep-remote) KEEP_REMOTE=1 ;;
    --allow-shell-suspect) ALLOW_SUSPECT=1 ;;
    *) die "未知参数：$a（可用 --yes / --keep-remote / --allow-shell-suspect）" ;;
  esac
done

# ---------- 短 id 推导：纯数字 → 后 4 位（长 id 先剥前 10 位再去前导 0）；非纯数字 → 取数字串后 4 位 ----------
case "$ID" in
  *[!0-9]*)
    DIGITS=$(printf '%s' "$ID" | tr -cd '0-9')
    [ -n "$DIGITS" ] || die "id「$ID」不含数字，无法推导分支名——问用户要数字 id"
    LAST4=$(last4 "$DIGITS")
    ;;
  *)
    if [ ${#ID} -gt 10 ]; then
      TAIL=$(printf '%s' "$ID" | cut -c11- | sed 's/^0*//')
      [ -n "$TAIL" ] || TAIL=0
    else
      TAIL="$ID"
    fi
    LAST4=$(last4 "$TAIL")
    ;;
esac

# ---------- 定位仓根 ----------
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || die "不在 git 仓内——先 cd 到目标业务仓再运行"
cd "$REPO"

# ---------- 对齐远程 ----------
git fetch --prune origin >/dev/null 2>&1 || die "git fetch origin 失败（网络 / 权限）"
BRANCHES=$(git ls-remote --heads origin | sed 's|.*refs/heads/||')
[ -n "$BRANCHES" ] || die "拉不到 origin 远端分支列表"

# ---------- 分支探测：生产分支（origin/HEAD → main2/main/master/develop）、测试分支（main-test/main_test/test）----------
pick() {
  local c
  for c in "$@"; do
    if [ -n "$c" ] && printf '%s\n' "$BRANCHES" | grep -qx "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
PROD=$(pick "$DEFAULT" main2 main master develop) || die "判不出生产分支——问用户生产分支叫什么"
TEST=$(pick main-test main_test test) || TEST=""

# ---------- 定位本需求的开发分支 / 合并分支（只认当前规范命名 {端}{id后4位}-…；老命名分支不在范围）----------
DEV=""; TT=""
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  case "$b" in
    "${POS}${LAST4}-To-test"|"${POS}-${LAST4}-To-test") TT="$b"; continue ;;
  esac
  case "$b" in
    "${POS}${LAST4}-"*|"${POS}-${LAST4}-"*) if [ -z "$DEV" ]; then DEV="$b"; fi ;;
  esac
done
[ -n "$DEV" ] || die "本仓找不到 ${POS}${LAST4}-* 的本地开发分支（老命名分支如 dev/hcb/… 不在清理范围，请人工确认）"
[ "$DEV" = "${POS}${LAST4}-To-test" ] && die "匹配到的只有 To-test 分支，缺开发分支——人工确认"

# ---------- 硬门槛①：已进生产 ----------
A=$(git rev-list --count "origin/$PROD..$DEV")
[ "$A" = "0" ] || die "开发分支未合入生产 $PROD（还有 $A 个提交没进）——拒绝清理"

# ---------- 硬门槛②：非空壳（特征①多分支共指 tip；特征②tip 是别人的平台合并提交）----------
TIP=$(git rev-parse "$DEV"); TIPS=$(git rev-parse --short "$DEV")
SHARE=$(git for-each-ref --format='%(objectname)' refs/heads | grep -c "^$TIP" || true)
SUBJ=$(git log -1 --format=%s "$DEV")
SUSPECT=0; EVID=""
if [ "${SHARE:-0}" -ge 2 ]; then
  SUSPECT=1; EVID="${EVID}  - 特征①：tip $TIPS 被 $SHARE 条分支共同指向（基线快照）
"
fi
case "$SUBJ" in
  *合并来自*) SUSPECT=1; EVID="${EVID}  - 特征②：tip 是平台合并提交「${SUBJ}」
" ;;
esac
if [ "$SUSPECT" = "1" ] && [ "$ALLOW_SUSPECT" != "1" ]; then
  printf '❌ 疑似空壳分支，拒绝清理：%s\n' "$DEV" >&2
  printf '%b' "$EVID" >&2
  printf '   口径：空壳分支不清理（它只是停在基线快照上，不是已交付）。\n' >&2
  printf '   确认真不是空壳 → 加 --allow-shell-suspect 重跑；要么先跑 分支合入检查 交叉验证。\n' >&2
  exit 2
fi

# ---------- worktree 路径（按 porcelain 实际路径取，不按分支名拼）----------
WT=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) cur="${line#worktree }" ;;
    "branch "*) if [ "${line#branch }" = "refs/heads/$DEV" ]; then WT="$cur"; fi ;;
  esac
done <<EOF
$(git worktree list --porcelain)
EOF
if [ -n "$WT" ] && [ "$WT" = "$REPO" ]; then
  die "开发分支正在主仓检出（$REPO）——请先切到生产分支再清理"
fi

# ---------- 硬门槛③：worktree 干净 ----------
DIRTY=0
if [ -n "$WT" ] && [ -d "$WT" ]; then
  if [ -n "$(git -C "$WT" status --porcelain)" ]; then DIRTY=1; fi
fi
[ "$DIRTY" = "0" ] || die "worktree 有未提交改动（$WT）——先处理（提交 / stash / 放弃），不许强删"

# ---------- pm2 进程名探测（新格式去掉连字符，历史格式一并找；pm2 不可用则跳过）----------
PM2="$HOME/Library/pnpm/pm2"; [ -x "$PM2" ] || PM2=$(command -v pm2 2>/dev/null || true)
PM2_NAMES=""
if [ -n "$PM2" ]; then
  for n in "${POS}${LAST4}" "${POS}-${LAST4}" "${POS}${LAST4}-To-test" "${POS}-${LAST4}-To-test"; do
    if "$PM2" describe "$n" >/dev/null 2>&1; then PM2_NAMES="${PM2_NAMES}${n}
"; fi
  done
fi

# ---------- To-test 分支可否删：合并结果必须已在测试线或生产线，否则保留 ----------
TT_DELETABLE=0; TT_REASON=""
if [ -n "$TT" ]; then
  T_IN_TEST=99; T_IN_PROD=99
  [ -n "$TEST" ] && T_IN_TEST=$(git rev-list --count "origin/$TEST..$TT")
  T_IN_PROD=$(git rev-list --count "origin/$PROD..$TT")
  if [ "$T_IN_TEST" = "0" ] || [ "$T_IN_PROD" = "0" ]; then
    TT_DELETABLE=1
  else
    TT_REASON="合并结果既不在测试线也不在生产（未进测试 $T_IN_TEST / 未进生产 $T_IN_PROD）——保留，避免丢掉解冲突结果"
  fi
fi

# ---------- 远程分支存在性 ----------
REMOTE_DEV=0; REMOTE_TT=0
if printf '%s\n' "$BRANCHES" | grep -qx "$DEV"; then REMOTE_DEV=1; fi
if [ -n "$TT" ] && printf '%s\n' "$BRANCHES" | grep -qx "$TT"; then REMOTE_TT=1; fi

# ---------- 打印清单（dry-run 与执行都先打印）----------
note ""
note "清理清单（$REPO）："
note "  需求:       ${POS}${LAST4}（id=$ID）"
note "  依据:       已进生产 $PROD（未进生产 0 个提交）$( [ "$SUSPECT" = "1" ] && printf '｜⚠️ 疑似空壳但已 --allow-shell-suspect 放行' )"
note "  worktree:   ${WT:-（无）}"
note "  本地分支:   $DEV (tip $TIPS)"
if [ -n "$TT" ]; then
  if [ "$TT_DELETABLE" = "1" ]; then note "  合并分支:   $TT"; else note "  合并分支:   $TT  ⏭ 跳过——$TT_REASON"; fi
fi
if [ "$KEEP_REMOTE" = "1" ]; then
  note "  远程分支:   保留（--keep-remote）"
else
  [ "$REMOTE_DEV" = "1" ] && note "  远程分支:   origin/$DEV"
  if [ -n "$TT" ] && [ "$TT_DELETABLE" = "1" ] && [ "$REMOTE_TT" = "1" ]; then note "  远程分支:   origin/$TT"; fi
fi
if [ -n "$PM2_NAMES" ]; then
  printf '  开发服务器: ' ; printf '%s\n' "$PM2_NAMES" | tr '\n' ' ' ; note ""
else
  note "  开发服务器: 无同名 pm2 进程"
fi

if [ "$YES" != "1" ]; then
  note ""
  note "（dry-run：未执行任何删除。确认后加 --yes 重跑）"
  exit 0
fi

# ---------- 执行：停服务 → 移 worktree → 删本地分支 → 删远程分支 ----------
note ""
note "开始执行..."

if [ -n "$PM2_NAMES" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    "$PM2" delete "$n" >/dev/null 2>&1 && note "  ✅ pm2 delete $n" || note "  ⚠️ pm2 delete $n 失败（跳过）"
  done <<EOF
$PM2_NAMES
EOF
fi

if [ -n "$WT" ] && [ -d "$WT" ]; then
  git worktree remove "$WT" && note "  ✅ 已移除 worktree：$WT" || die "git worktree remove 失败：$WT"
fi

git branch -d "$DEV" || die "git branch -d 失败：$DEV 未完全合入 → 停下人工确认（禁止换 -D）"
note "  ✅ 已删本地分支：$DEV"
if [ -n "$TT" ] && [ "$TT_DELETABLE" = "1" ]; then
  git branch -d "$TT" && note "  ✅ 已删本地分支：$TT" || note "  ⚠️ $TT 删除失败，已保留"
fi

if [ "$KEEP_REMOTE" != "1" ]; then
  if [ "$REMOTE_DEV" = "1" ]; then
    git push origin --delete "$DEV" >/dev/null 2>&1 && note "  ✅ 已删远程分支：origin/$DEV" || die "git push origin --delete $DEV 失败（原样上报，不重试）"
  fi
  if [ -n "$TT" ] && [ "$TT_DELETABLE" = "1" ] && [ "$REMOTE_TT" = "1" ]; then
    git push origin --delete "$TT" >/dev/null 2>&1 && note "  ✅ 已删远程分支：origin/$TT" || die "git push origin --delete $TT 失败（原样上报，不重试）"
  fi
fi

# ---------- 复查 ----------
note ""
note "复查（以下都不应再出现 ${POS}${LAST4} / ${POS}-${LAST4}）："
git worktree list | grep -iE "${POS}-?${LAST4}" && note "  ⚠️ worktree 仍有残留" || note "  ✅ worktree 无残留"
git branch -a | grep -iE "${POS}-?${LAST4}" && note "  ⚠️ 分支仍有残留" || note "  ✅ 分支无残留"
ls -d "$(dirname "$REPO")"/*${LAST4}* 2>/dev/null && note "  ⚠️ 目录仍有残留" || note "  ✅ 目录无残留"
if [ -n "$PM2" ]; then
  "$PM2" ls 2>/dev/null | grep -iE "${POS}-?${LAST4}" && note "  ⚠️ pm2 仍有残留" || note "  ✅ pm2 无残留"
fi
note ""
note "追溯凭据：被删开发分支 tip = $TIPS（内容已在 origin/$PROD，可随时取回）"
