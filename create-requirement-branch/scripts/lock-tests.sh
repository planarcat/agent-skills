#!/usr/bin/env bash
# 锁测试目录（macOS 内核级只读：chflags -R uchg）
#
# 用法：
#   bash lock-tests.sh                  # 锁默认目录 __tests__ 与 e2e
#   bash lock-tests.sh __tests__        # 只锁指定目录
#
# 说明：这是「内核级」约束 —— 上锁后连 agent 自己都写不进去，
# 要改测试必须先显式解锁（见 unlock-tests.sh），是一道拦得住"顺手改测试"的硬闸。
set -euo pipefail

if ! command -v chflags >/dev/null 2>&1; then
  echo "本机不支持 chflags（非 macOS）→ 跳过上锁，不影响流程。"
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIRS=("$@")
if [ ${#DIRS[@]} -eq 0 ]; then
  DIRS=(__tests__ e2e)
fi

found=0
for d in "${DIRS[@]}"; do
  p="$ROOT/$d"
  if [ -d "$p" ]; then
    chflags -R uchg "$p"
    echo "已上锁：$p"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  echo "仓里没有测试目录（__tests__ / e2e）→ 不锁，也不新建空目录凑数。"
fi

echo
echo "提示：解锁用 bash unlock-tests.sh；解锁后改测试，commit message 里必须写清为什么改、改了什么口径。"
