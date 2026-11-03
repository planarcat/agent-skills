---
name: linting-the-wiki
description: "检查知识库健康度（断链/孤儿页/索引漂移/过时与矛盾）并做有边界的小修补。当用户说「检查/体检知识库」「知识库有什么问题」「清理一下 KB/wiki」时使用。"
version: 0.7.0
owner_repo: Optima-Chat/kb-skills
---

# Linting The Wiki

检查 wiki 随时间推移后的完整性和可维护性。

## 启动 SOP

0. 自动迁移与同步（后台执行，成功不必汇报；**失败必须告知用户一句**——sync 失败
   意味着本地与远端/企业库脱同步，静默吞掉只会让两边越漂越远）：
   ```bash
   [ -d ~/kb/.git ] && kb migrate
   [ -n "$KB_BACKEND_URL" ] && kb sync
   ```
1. `ls ~/kb/REGISTRY.md`
   - 不存在 → 告诉用户"还没有知识库，需要先创建一个"，引导使用 initializing-kb
2. 读 `~/kb/REGISTRY.md` — 获取所有 active 的 KB 列表
   `local_dir` 列是该库在 `~/kb/` 下的目录名（自己的库 = slug；同事的库 = `<作者>--<slug>`），下文的 `<local_dir>` 都指它。
3. 确定目标 KB：
   - 用户明确指定了 KB slug 或主题 → 直接用
   - 用户说"全部 lint" → 遍历所有 active KB
   - 只有一个 active KB → 用它
   - 多个 active → 列出让用户选
4. 读 `~/kb/<local_dir>/AGENTS.md` 了解该 KB 的契约

## Lint 流程

1. 先跑 CLI 自动扫描：

   ```bash
   kb lint --dir ~/kb/<local_dir>
   ```

   CLI 会检测：断链、index.md 覆盖不足、index entry 格式错误、重复 index entry、孤立页面（无入链）、log.md heading 格式、**活页超期未动**（overview/entities 超 90 天无 git 改动→提醒复核，确认仍有效就在页内更新一行核实注记）、**index.md 超长**（>200 行→拆子索引或精简）、**inbox 积压**（待整理区 >10 条或最老 >7 天→触发下方整理步）。输出为每行一条 issue，退出码 0 表示无问题。

2. 基于 CLI 报告 + 人工阅读，补充 CLI 无法检测的问题（见下方"要检查什么"）
3. 按类型归类所有问题：链接、覆盖度、过时、矛盾、重复、页面规模或索引问题
4. **整理 inbox**（报了 inbox-backlog 时必做）：逐条读 `wiki/inbox/` 的结论页——
   归入正确页型（红线/阈值→对应 overview；实体事实→entity 页；独立结论→analyses），
   建互链、进 index，然后**删除该 inbox 页**；与既有内容矛盾的按「冲突处理」规则标注
5. 除非用户要求更大范围修复，否则只应用小而明确的修补
6. 清楚报告仍未解决的问题
7. 追加 `~/kb/PROGRESS.md`
8. Git 同步：
   ```bash
   cd ~/kb/<local_dir>
   git remote get-url origin &>/dev/null && kb git pull --rebase
   git add -A && git commit -m "lint: <发现N个问题，修复M个>"
   git remote get-url origin &>/dev/null && kb git push
   ```

   > **冲突与红线**：`kb git pull --rebase` 冲突时——先 `git rebase --abort` 回到冲突前，改用
   > `kb git pull --no-rebase` 合并；在冲突文件里**保留双方内容**并加一行「⚠️ 冲突待人工裁决」，
   > commit 后告知用户哪几处需要裁决，绝不静默丢弃任何一方。
   > push 失败（4xx/网络）→ 把错误原样报给用户，按提示重试或拆分；**绝不用
   > `git filter-branch` / `push --force` 等重写历史的手段解决推送问题**——#45 实锤：
   > 那会永久抹掉用户 raw/ 里的原件。
   > `kb git` 报 `Unknown command: git`（容器里还是旧版 CLI）时改跑 `kb sync`（带认证先拉后推），并照实告诉用户推送结果。

## 要检查什么（CLI 之外的人工检查）

CLI 已覆盖断链、孤立页面、index 覆盖和格式问题。以下需要人工判断：

- 被反复提及但没有独立页面的实体或概念
- 本应并入 overview 的 analysis 页面，或反过来的情况
- 新来源进入后仍未更新的旧综述
- `index.md` 与实际长期页面之间的漂移
- 为了清晰起见应被拆分的大页面
- 由于缺少来源而无法回答、但明显值得继续调查的问题

## 修复边界

安全的 lint 修复通常包括：

- 增加缺失链接
- 更新 `index.md`
- 澄清过时标签
- 就地标出矛盾

不要把 lint 变成无边界重写。需要更深层次调整时，明确说出来并停下，除非用户明确要求继续。

## 最小交付标准

一次成功的 lint 至少应留下：

- 一份简短但具体的问题清单
- 已经完成的有边界修复
- 已修复问题与剩余债务之间的清晰区分
- 需要通过新来源或 web search 继续补足的空白点
