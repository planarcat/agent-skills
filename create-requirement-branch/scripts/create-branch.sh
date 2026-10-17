#!/usr/bin/env bash
# create-branch.sh —— 创建分支技能的一条龙执行脚本（2026-10-13 用户口径）
# 一次调用跑完：建分支(worktree) → 装依赖 → 起本地服务(pm2) → 打印汇报块
# 用法（在目标业务仓内运行）：
#   bash create-branch.sh <U|F|D|S> <需求id> "<标题>" [--to-test]
# 设计原则：所有规则固化在本脚本内，agent 只调用、不判断；规则与技能正文一致，改口径两处同改。

set -e

# ---------- 函数：报错退出（信息给 agent 看，转述给用户）----------
die() { printf '❌ %s\n' "$1" >&2; exit 1; }

# ---------- 函数：取数字串后 4 位，不足左补 0 ----------
last4() { # $1=数字串
  local s="$1"
  while [ ${#s} -lt 4 ]; do s="0$s"; done
  printf '%s' "${s: -4}"
}

# ---------- 入参解析 ----------
POS="$1"; ID="$2"; TITLE="$3"; TO_TEST="${4:-}"
[ -n "$POS" ] && [ -n "$ID" ] && [ -n "$TITLE" ] || die "用法：create-branch.sh <U|F|D|S> <需求id> \"<标题>\" [--to-test]"
case "$POS" in
  U|F|D|S) ;;
  *) die "端位必须是 U/F/D/S（U=用户端 F=工厂端 D=设计器 S=ShopAgent）" ;;
esac

# ---------- 短 id 推导：纯数字 → id 段=后 4 位（长 id 先剥前 10 位再去前导 0）；非纯数字 → 完整 id ----------
case "$ID" in
  *[!0-9]*)
    PREFIXSEG="$ID"
    DIGITS=$(printf '%s' "$ID" | tr -cd '0-9')
    [ -n "$DIGITS" ] || die "id「$ID」不含数字，端口无法推导——问用户要数字 id"
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
    PREFIXSEG="$LAST4"   # 分支名 id 段 = 后 4 位，与 pm2 名/端口同源（2026-10-13 修正：原来短 id 整段进分支名，与文档口径分裂）
    ;;
esac

# ---------- 标题截取：第一个（/( 之前 → 去首尾空白 → 路径分隔符 / 与空白转 - → 剔 git 非法字符 → ≤24 字 ----------
TITLE_SEG=$(printf '%s' "$TITLE" | sed 's/[（(].*//; s|/|-|g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]]\{1,\}/-/g; s/-\{2,\}/-/g; s/^-*//; s/-*$//')
TITLE_SEG=$(printf '%s' "$TITLE_SEG" | tr -d '~^:?*[]\\')
TRUNCATED=""
if [ ${#TITLE_SEG} -gt 24 ]; then TITLE_SEG="${TITLE_SEG:0:24}"; TRUNCATED="（标题已截断）"; fi
[ -n "$TITLE_SEG" ] || die "标题截取后为空，需要有效标题"

# ---------- 分支名 = worktree 目录名（端位与 id 段无连字符，2026-10-14 口径，如 F2962-标题）；合并分支无标题段 ----------
if [ "$TO_TEST" = "--to-test" ]; then
  BRANCH="${POS}${PREFIXSEG}-To-test"
else
  BRANCH="${POS}${PREFIXSEG}-${TITLE_SEG}"
fi

# ---------- 定位 git 仓根（agent 在目标业务仓内运行即可，子目录也行）----------
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || die "不在 git 仓内——先 cd 到目标业务仓再运行"

# ---------- 主分支探测：需求分支 origin/HEAD→main2/main/master；合并分支 main-test/main_test ----------
BRANCHES=$(git ls-remote --heads origin | sed 's|.*refs/heads/||')
[ -n "$BRANCHES" ] || die "拉不到 origin 远端分支列表（网络/权限）"
pick_main() { # $@=候选分支名，返回第一个在远端存在的
  local c
  for c in "$@"; do
    if [ -n "$c" ] && printf '%s\n' "$BRANCHES" | grep -qx "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}
if [ "$TO_TEST" = "--to-test" ]; then
  MAIN=$(pick_main main-test main_test) || die "远端没有 main-test / main_test 测试分支——问用户测试分支叫什么"
else
  DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
  MAIN=$(pick_main "$DEFAULT" main2 main master) || die "远端没有 main2/main/master，origin/HEAD 也无效——问用户主分支叫什么"
fi

# ---------- worktree 落点：一律原仓旁边同级（2026-10-13 口径：不用 Apps/frontend，不设兜底）----------
WT="$(dirname "$REPO")/$BRANCH"

# ---------- 建分支（撞名=复用已有目录，不覆盖不追加序号）----------
if [ -d "$WT" ]; then
  REUSED=1
  echo "↩︎ 目录已存在，直接复用：$WT"
  # 复用的分支若没记过 baseRef（旧流程建的）→ 顺手补记，让它也走事实判定
  if [ -z "$(git -C "$WT" config --get "branch.$BRANCH.baseRef" 2>/dev/null || true)" ]; then
    git -C "$WT" config "branch.$BRANCH.baseRef" "origin/$MAIN"
    echo "   已补记 baseRef=origin/$MAIN（lint 基线出身判定的事实依据）"
  fi
else
  git fetch origin "$MAIN"
  git worktree add "$WT" -b "$BRANCH" "origin/$MAIN" --no-track
  # 记「从哪拉的」：lint 基线出身判定的事实依据（--no-track 不留 upstream、push -u 也不会覆盖它）
  git -C "$WT" config "branch.$BRANCH.baseRef" "origin/$MAIN"
  git -C "$WT" push -u origin HEAD
fi

SHA=$(git rev-parse --short "origin/$MAIN" 2>/dev/null || echo "未知")

# ---------- 装依赖（pnpm 优先 ~/Library/pnpm 绝对路径，退化 PATH；不预检、装完不验证）----------
PNPM="$HOME/Library/pnpm/pnpm"; [ -x "$PNPM" ] || PNPM=$(command -v pnpm || true)
[ -n "$PNPM" ] || die "找不到 pnpm（~/Library/pnpm/pnpm 与 PATH 都没有）"
(cd "$WT" && "$PNPM" install)

# ---------- 复制主仓根被 gitignore 的 .env*（不存在静默跳过；仅新建 worktree 时做一次）----------
if [ "${REUSED:-0}" != "1" ]; then
  cp -f "$REPO"/.env* "$WT"/ 2>/dev/null || true
fi

# ---------- 打印汇报块（agent 原样转述即可）----------
echo ""
echo "已创建需求分支（一条龙脚本）："
echo "  branch:    $BRANCH  $TRUNCATED"
echo "  from:      origin/$MAIN @ $SHA"
if [ "${REUSED:-0}" = "1" ]; then
  echo "  worktree:  $WT（已存在，直接复用）"
else
  echo "  worktree:  $WT"
fi
echo "  upstream:  origin/$BRANCH（自己，不是主分支）"
echo "  baseRef:   origin/$MAIN（记「从哪拉的」——lint 基线出身判定的事实依据，push -u 不会覆盖）"
echo "  进入:      cd $WT"
echo "  install:   pnpm install 已在工作目录执行"
if [ "$TO_TEST" = "--to-test" ]; then
  echo "  next:      合并开发分支改动与解冲突按技能正文「合并分支」节手走（本脚本不起服务）"
else
  echo "  server:    见下方 dev 指令输出（地址 / 日志 / 管理口令全套自带）"
fi

# ---------- 起本地服务（合并分支不起；统一调工作区 dev 指令——pm2/端口/多 IP 单一实现，本脚本不再自养模板，2026-10-14 口径）----------
if [ "$TO_TEST" != "--to-test" ]; then
  WS_ROOT="$(dirname "$(dirname "$REPO")")"   # 业务仓 → Apps/ → 工作区根（ops.sh 所在）
  OPS="$WS_ROOT/ops.sh"
  [ -f "$OPS" ] || die "工作区根没有 ops.sh（$OPS），dev 指令无从调用——原样报给用户"
  # dev（实现源 ops/svc.sh）：按 id 后 4 位定位 worktree → 缺依赖自动 install → 端口=需求号后4位 → pm2 bash 包装启动 → 多 IP 汇报
  # 铁律（2026-10-13 口径）：dev 报错原样上报用户，不检索不排查不修复——svc.sh 由用户优化
  echo ""
  zsh -c "source '$OPS' >/dev/null 2>&1; dev '$LAST4'" || die "dev 指令退出非零——把上方原始输出原样转述给用户，不要自行处理"
fi
