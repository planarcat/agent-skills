#!/usr/bin/env bash
# 解锁测试目录（去掉 chflags uchg）
#
# 用法：
#   bash unlock-tests.sh                # 解锁默认目录 __tests__ 与 e2e
#   bash unlock-tests.sh __tests__      # 只解锁指定目录
#
# ⚠️ 解锁 = 你要改测试 = 必须留痕。改完记得再跑一次 lock-tests.sh 锁回去。
set -euo pipefail

if ! command -v chflags >/dev/null 2>&1; then
  echo "本机不支持 chflags（非 macOS）→ 跳过解锁，不影响流程。"
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
  if [ -e "$p" ]; then
    chflags -R nouchg "$p"
    echo "已解锁：$p"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  echo "没有找到测试目录，无需解锁。"
fi

cat <<'EOF'

⚠️ 解锁意味着你要改测试，必须在 commit message 里写清：
  - 解锁了哪个目录
  - 为什么改（口径变了 / 用例写错 / …）
  - 改了什么口径

改完记得再跑一次 lock-tests.sh 锁回去。
EOF
