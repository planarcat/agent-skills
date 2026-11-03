---
name: updating-related-pages
description: "在收录新来源后同步更新知识库的关联页面（实体/综述/分析页与交叉链接）。通常由 ingesting-sources 流程触发；用户明确要求「把相关页面一起更新」「补一下交叉链接」时也可单独使用。"
version: 0.5.0
owner_repo: Optima-Chat/kb-skills
---

# Updating Related Pages

在来源 ingest 之后，同步 wiki 的其他部分。

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
   - 只有一个 active KB → 用它
   - 多个 active → 根据库名（`name`）判断与本次任务的相关性；无法判断时列出让用户选
4. 读 `~/kb/<local_dir>/AGENTS.md` 了解该 KB 的契约

## 更新流程

1. 从来源页或 ingest 产出的 affected-page 列表开始
2. 确认哪些 entity、overview 和 analysis 页面需要更新
3. 优先更新现有页面，而不是先新建页面
4. **确保交叉链接**：每个 wiki 页面必须至少被一个其他页面链接到。新建页面时，必须从相关的来源页、实体页或综述页添加链接指向它
5. **更新 `index.md`**：所有新创建的 wiki 页面必须加入 `~/kb/<local_dir>/index.md`（格式：`- [页面标题](wiki/path/file.md): 一句话说明`）
6. 如果这次变更实质性影响了 wiki，在 `~/kb/<local_dir>/log.md` 中追加记录
7. 追加 `~/kb/PROGRESS.md`
8. **自检**：`kb lint --dir ~/kb/<local_dir>`，如果有 issue 先修复再 commit
9. Git 同步：
   ```bash
   cd ~/kb/<local_dir>
   git remote get-url origin &>/dev/null && kb git pull --rebase
   git add -A && git commit -m "update: <更新了哪些页面>"
   git remote get-url origin &>/dev/null && kb git push
   ```

   > **冲突与红线**：`kb git pull --rebase` 冲突时——先 `git rebase --abort` 回到冲突前，改用
   > `kb git pull --no-rebase` 合并；在冲突文件里**保留双方内容**并加一行「⚠️ 冲突待人工裁决」，
   > commit 后告知用户哪几处需要裁决，绝不静默丢弃任何一方。
   > push 失败（4xx/网络）→ 把错误原样报给用户，按提示重试或拆分；**绝不用
   > `git filter-branch` / `push --force` 等重写历史的手段解决推送问题**——#45 实锤：
   > 那会永久抹掉用户 raw/ 里的原件。
   > `kb git` 报 `Unknown command: git`（容器里还是旧版 CLI）时改跑 `kb sync`（带认证先拉后推），并照实告诉用户推送结果。

## 更新规则

更新既有页面时：

- 保持页面的稳定职责
- 把新信息合并进正确的 section，而不是随手堆一段笔记
- 当新来源改变了先前理解时，要让修正过程可见
- 让 source-backed 内容与综合推断保持可区分
- 优先使用可链接的短陈述，而不是长段无结构文字

## 冲突处理

如果新来源与旧页面冲突：

- 不要无解释地删除旧结论
- 记录新的证据
- 更新当前理解
- 让之后的读者仍然看得出分歧在哪里

## 何时创建新页面

只有在下列情况下才应新建页面：

- 新信息引入了一个 recurring concept，但还没有稳定 landing page
- 某个 analysis 或 comparison 已经有独立长期价值
- 现有页面已经过宽，无法干净吸收这次更新

## 最小交付标准

一次成功的 related-page update 至少应留下：

- 被同步更新过的相关页面
- source、entity、overview 和 analysis 页面之间清晰的交叉链接
- 在适用时，对"理解发生变化"有可见处理
