---
name: cnb-push-audit
description: 查 CNB( cnb.cool ) 上灵创三仓库（用户端 / 工厂端 / POD）某分支今天/某段时间的推送与提交明细。当用户说「查一下 cnb 上的推送」「今天推了哪些分支」「main2 / main-test 有哪些提交」「核对推送记录」时使用。需要 cnb connector 已连接。
---

# CNB 三仓库推送核查

## 仓库地图（名称与分支命名不一致，别猜）
| 称呼 | 仓库路径 | 主线分支 | 开发分支 |
|---|---|---|---|
| 灵创用户端 | `lcpod/lc/lingchuang-front` | **`main_test`（下划线）**、`main2` | `hcb-dev` |
| 灵创工厂端 | `lcpod/lc/factory-front` | **`main-test`（连字符）**、`main2` | `hcb_dev` |
| POD | `planarcat/pod-server-rust` | **`main`、`test`**（无 main2/main-test） | 带日期的中文名分支 |

仓库页：`https://cnb.cool/<path>`

## 步骤
1. **取今天的时间下界**（since 要 UTC，today 00:00+08 = 前一天 16:00Z）：
   ```
   date -u -v-1d +%Y-%m-%dT16:00:00Z
   ```
2. **逐仓库逐分支拉提交**（--page-size 给大）：
   ```
   cnb git list-commits --repo <path> --sha <branch> --since "<上一步的值>" --page-size 50
   ```
   换时间段就改 `--since` / 可加 `--until`。
3. **解析**：输出是缩进文本（`- sha:` 起块），按块取 `commit.author.name`、`commit.author.date`、`message`。用 python 脚本解析，别用 grep（`name:` 在块内出现多次会串行）：
   ```python
   rec=None; got=False
   for ln in open(f,encoding="utf-8"):
       st=ln.strip()
       if st.startswith("- sha:"): rec={"sha":st.split("sha:")[1].strip()}; got=False
       elif rec is not None:
           if st.startswith("name:") and not got: rec["author"]=st.split("name:")[1].strip(); got=True
           elif st.startswith("date:") and "date" not in rec: rec["date"]=st.split("date:")[1].strip().strip('"')
           elif st.startswith("message:"): rec["msg"]=st.split("message:",1)[1].strip().strip('"')
   ```
4. **识别 PR**：CNB 的合并提交由平台生成在**目标分支**上，message 里带 `合并来自 <head分支> 的合并请求 #NNN`。看该 merge commit 落在哪条分支，就知道这个 PR 合到了哪。`planarcat`/`cnb` 为 committer 的是平台合并，`何成标` 的是本人本地 merge。

## 输出格式
按仓库分表：`时间(+08:00) | 提交人 | PR号 | 内容`；再给「要点」：今日总量 / tip SHA / 非本人推送（同事的提交要单独点出）/ 两线重复的提交。

## 推送结果怎么读成日报口径（衔接 report-writer · **v3**）
- **v3 不再手写进度百分比与状态**（v2 的「合入 main2＝100% / 只合 main-test＝95%」标注已作废）。日报任务行的**状态以 TAPD 为准**，CNB 只用来判断两件事：
  1. **这条代码到哪一步了**（开发分支 → 测试环境 → 生产），写进任务行的「交付物/标准」描述；
  2. **TAPD 状态是不是落后了**。发现「代码已进测试环境、TAPD 还写开发中」→ 提醒用户**先去 TAPD 改状态再交日报**（v3 前置动作；报表与 TAPD 不一致＝虚报，双向）。
- 只合入测试分支 = 交付物写「改动已部署测试环境」；合入生产分支 = 「改动已部署生产环境」。
- **提交日期 ≠ 上线日期**：`--since` 过滤的是提交日期。有的代码是前一天写的、今天才合（09-17 实测 1002757；09-18 实测 1002648 是 09-16 写的、09-18 才合 main-test）。要答「今天写了什么」只取 author date 是今天的；要答「今天上线/合入什么」按合入日期算——**两种口径先问清用户要哪个**，别混着报。
- 汇总时把**平台生成的合并提交**（committer 是 `cnb`/`planarcat`）和**本人写的代码提交**分开数，别把 merge 当成开发量。

## 找仓库或分支的命令（路径不对时）
```
cnb repositories get-group-sub-repos --slug lcpod --descendant all --page-size 100   # 组织可见仓库
cnb git list-branches --repo <path> --page-size 100                                   # 分支列表
```

## 坑
- `main_test` 是用户端、`main-test` 是工厂端，写错直接 404。
- lcpod 组织下**不存在**名为 pod 的仓库；POD 仓库在个人命名空间 `planarcat/pod-server-rust`。
- `get-group-sub-repos` 只返回有权限的仓库（组织显示 44 个仓库但实际只列出 12 个），列不全不代表不存在 → 猜路径前先换方式确认。
- 两线常有同一批开发提交（dev 分支的 commit 同时进 main_test 和 main2），统计时注意去重说明。
- 分支名含中文（如 `dev/hcb/1002757_【产品合成】…`）时 shell 里**必须加引号**；直接搜分支名可能查不到（已合并的分支会被删），改用 PR 合并提交的 sha 反查父提交日期。
- `cnb git get-commit` 只认 `--ref`（不是 `--sha`），且个别 sha 会返回 500，取不到就换路径（查分支列表 / 换 PR 合并提交）。
