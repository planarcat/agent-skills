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
  U) REPO_DIGIT=1 ;; F) REPO_DIGIT=2 ;; D) REPO_DIGIT=3 ;; S) REPO_DIGIT=4 ;;
  *) die "端位必须是 U/F/D/S（U=用户端 F=工厂端 D=设计器 S=ShopAgent）" ;;
esac

# ---------- 短 id 推导：纯数字长 id（>10 位）剥前 10 位再去前导 0；非纯数字用完整 id ----------
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
    PREFIXSEG="$TAIL"
    LAST4=$(last4 "$TAIL")
    ;;
esac

# ---------- 标题截取：第一个（/( 之前 → 去首尾空白 → 空白转 - → 剔 git 非法字符 → ≤24 字 ----------
TITLE_SEG=$(printf '%s' "$TITLE" | sed 's/[（(].*//; s/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]]\{1,\}/-/g; s/-\{2,\}/-/g; s/^-*//; s/-*$//')
TITLE_SEG=$(printf '%s' "$TITLE_SEG" | tr -d '~^:?*[]\\')
TRUNCATED=""
if [ ${#TITLE_SEG} -gt 24 ]; then TITLE_SEG="${TITLE_SEG:0:24}"; TRUNCATED="（标题已截断）"; fi
[ -n "$TITLE_SEG" ] || die "标题截取后为空，需要有效标题"

# ---------- 分支名 = worktree 目录名；合并分支无标题段 ----------
if [ "$TO_TEST" = "--to-test" ]; then
  BRANCH="${POS}-${PREFIXSEG}-To-test"
else
  BRANCH="${POS}-${PREFIXSEG}-${TITLE_SEG}"
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
else
  git fetch origin "$MAIN"
  git worktree add "$WT" -b "$BRANCH" "origin/$MAIN" --no-track
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

# ---------- 起本地服务（合并分支不起；启动方式按端位查配置表，agent 不判断）----------
if [ "$TO_TEST" != "--to-test" ]; then
  PM2="$HOME/Library/pnpm/pm2"; [ -x "$PM2" ] || PM2=$(command -v pm2 || true)
  [ -n "$PM2" ] || die "找不到 pm2（~/Library/pnpm/pm2 与 PATH 都没有）"
  NAME="${POS}-${LAST4}"
  # 端口 = 仓库位 + id 后 4 位（固定可推导）
  PORT="${REPO_DIGIT}${LAST4}"
  # 启动方式配置表（改口径只改这里；新仓库首次起服务报错就补一行）
  #   U（用户端）：端口走 VITE_PORT 环境变量（该仓 vite 配置读取），host 走参数
  #   F（工厂端）/ D / S：端口与 host 都走命令行参数
  case "$POS" in
    U) START_ENV="VITE_PORT=${PORT}"; START_ARGS=(dev --host 0.0.0.0) ;;
    *) START_ENV="";                  START_ARGS=(dev --host 0.0.0.0 --port "${PORT}") ;;
  esac
  # 同名 pm2 在跑 → 只报地址不重启；同名残留（非 online）→ 删掉原端口重启
  ONLINE=0
  if "$PM2" describe "$NAME" >/dev/null 2>&1; then
    STATUS=$("$PM2" describe "$NAME" 2>/dev/null | grep -m1 -oE 'online|launching|stopped|errored' || true)
    if [ "$STATUS" = "online" ]; then ONLINE=1
    else "$PM2" delete "$NAME" >/dev/null 2>&1 || true; fi
  fi
  if [ "$ONLINE" != "1" ]; then
    # 在 worktree 根目录执行（cd 进去再跑 pm2，服务工作目录=当前目录，不用 --cwd 中转）
    (cd "$WT" && env ${START_ENV} "$PM2" start "$PNPM" --name "$NAME" -- "${START_ARGS[@]}")
  fi
  IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)
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
echo "  进入:      cd $WT"
echo "  install:   pnpm install 已在工作目录执行"
if [ "$TO_TEST" = "--to-test" ]; then
  echo "  next:      合并开发分支改动与解冲突按技能正文「合并分支」节手走（本脚本不起服务）"
else
  if [ "$ONLINE" = "1" ]; then
    echo "  server:    http://$IP:$PORT（pm2 $NAME 已在跑，未重启）"
  else
    echo "  server:    http://$IP:$PORT（pm2 name=$NAME；起中，约几秒后可访问）"
  fi
  echo "  日志:      pm2 logs $NAME"
fi
