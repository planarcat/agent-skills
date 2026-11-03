---
name: querying-the-wiki
description: "从已有知识库检索并回答问题，值得留的答案沉淀回库。当用户问「我们记过没有/库里有没有…」「查一下知识库/KB/wiki」「之前整理的XX结论是什么」，或话题明显落在某个已建知识库的主题内时使用；或系统提示『企业知识库』一段列出的主题与问题相关时使用。"
version: 0.5.0
owner_repo: Optima-Chat/kb-skills
---

# Querying The Wiki

通过把维护后的 wiki 视为主要知识层来回答问题。

## 启动 SOP

0. 自动迁移与同步（后台执行，成功不必汇报；**失败必须告知用户一句**——sync 失败
   意味着本地与远端/企业库脱同步，静默吞掉只会让两边越漂越远）：
   ```bash
   [ -d ~/kb/.git ] && kb migrate
   [ -n "$KB_BACKEND_URL" ] && kb sync
   ```
1. 检查 `~/kb/REGISTRY.md` 是否存在，并读取表中是否有库条目。
   REGISTRY 不存在或表里没有任何库（只有表头）时，按「还没有知识库」处理。
   - 告诉用户"还没有知识库，需要先创建一个"，引导使用 initializing-kb；停止，不进入检索。
2. 读 `~/kb/REGISTRY.md` — 获取列出的所有 KB 及其 `local_dir`
   `local_dir` 列是该库在 `~/kb/` 下的目录名（自己的库 = slug；同事的库 = `<作者>--<slug>`），下文的 `<local_dir>` 都指它。
   只检索 REGISTRY 列出的库；`~/kb/` 下不在 REGISTRY 里的目录不读（可能是已撤回或已删除库的旧副本）。
3. 确定待检索 KB：
   - 用户点名了库 → 使用 REGISTRY 中对应的库
   - 否则 → 检索 REGISTRY 里所有库的 `wiki/`，按命中选库；不因多库停下问用户
4. 读各待检索库的 `~/kb/<local_dir>/AGENTS.md` 了解契约

## 查询流程

1. **全文检索先行**（#49 P0：库一大 index 导航必失灵，先 grep 缩小范围）：
   将待检索库的每个 `"$HOME/kb/<local_dir>/wiki/"` 路径作为一个元素放入 Bash 数组 `wiki_dirs`；
   使用 `$HOME` 展开绝对路径，不把 `~` 放在双引号内（双引号内的 `~` 不展开）。
   未点名库时必须包含 REGISTRY 里所有库，不能用 `~/kb/*/wiki/` 扫入未登记目录。
   每次 grep 前检查 `${#wiki_dirs[@]}`；若数组为空就不执行 grep，按启动 SOP 第 1 步的「还没有知识库」分支处理并停止检索。
   从问题里取 2-4 个关键词（含同义改写），逐个检索，取所有库的命中并集作候选页，按命中选库。
   Bash 示例（将示例库名替换为 REGISTRY 中确定的待检索库 `local_dir`，逐个替换关键词运行）：
   ```bash
   local_dirs=("research" "alice--operations")
   wiki_dirs=()
   for local_dir in "${local_dirs[@]}"; do
     wiki_dirs+=("$HOME/kb/$local_dir/wiki/")
   done
   if (( ${#wiki_dirs[@]} == 0 )); then
     printf '%s\n' '还没有知识库，需要先创建一个；请使用 initializing-kb。'
   else
     grep -ril "<关键词>" "${wiki_dirs[@]}"
   fi
   ```
   所有关键词都没命中 → 如实回答「库里没有」，再按下方「何时保留结果」判断是否值得补一页。
2. 读命中库的 `~/kb/<local_dir>/index.md`，结合 grep 候选选出最相关的 wiki 页面（grep 命中优先，index 用于导航）
3. 优先基于维护后的页面回答
4. 只有在 wiki 不完整或含混时才回到 raw sources
5. 判断这个答案是否应该被保留。如果应该，选定**一个写回库**：用户点名了库就用点名的；
   否则用答案主要引用的库，引用了多个库时选引用最多的（并列时按 REGISTRY 顺序选第一个）。
   第 6、8、9 步里的 `<local_dir>` 都指这个写回库；页面、index、lint 和 Git 同步统一绑定该库，不为多库各写一份。
6. 如果应该，写进 `~/kb/<local_dir>/wiki/analyses/` 或对应 overview 页面，并：
   - 加入该写回库的 `~/kb/<local_dir>/index.md`
   - 确保该写回库至少有一个其他页面链接到它
7. 如果保留了结果，追加 `~/kb/PROGRESS.md`（工作区级，不在库目录里）
8. 如果写入了新页面：`kb lint --dir ~/kb/<local_dir>`，有 issue 先修复
9. 如果保留了结果，在该写回库执行 Git 同步：
   ```bash
   cd ~/kb/<local_dir>
   git remote get-url origin &>/dev/null && kb git pull --rebase
   git add -A && git commit -m "query: <一句话>"
   git remote get-url origin &>/dev/null && kb git push
   ```

   > **冲突与红线**：`kb git pull --rebase` 冲突时——先 `git rebase --abort` 回到冲突前，改用
   > `kb git pull --no-rebase` 合并；在冲突文件里**保留双方内容**并加一行「⚠️ 冲突待人工裁决」，
   > commit 后告知用户哪几处需要裁决，绝不静默丢弃任何一方。
   > push 失败（4xx/网络）→ 把错误原样报给用户，按提示重试或拆分；**绝不用
   > `git filter-branch` / `push --force` 等重写历史的手段解决推送问题**——#45 实锤：
   > 那会永久抹掉用户 raw/ 里的原件。
   > `kb git` 报 `Unknown command: git`（容器里还是旧版 CLI）时改跑 `kb sync`（带认证先拉后推），并照实告诉用户推送结果。

## Query 规则

回答时：

- 优先使用维护后的 wiki，而不是每次从头重建
- 当答案依赖不完整或过时的 wiki 覆盖时，要说清楚
- 把 source-backed 内容与综合推断区分开
- 标出这个问题是否暴露了 wiki 的结构性空缺
- 在答案中显式引用所使用的 wiki 页面；如果回看了 raw sources，也要说明

## 何时保留结果

在下列情况下，应把结果写回 wiki：

- 同一个问题很可能会再次出现
- 这个答案比较了多个来源或页面
- 这个答案形成了可长期复用的综合
- 这个答案解决了当前 wiki 尚未解释清楚的混乱点

独立的长期输出应进入 `wiki/analyses/`。如果主要是改进某个主题的现有综述，则写入对应 overview 页面。

## 最小交付标准

一次成功的 query 至少应产出：

- 一个直接回答用户问题的结果
- 在答案中明确引用使用了哪些 wiki 页面
- 清楚说明这个结果是否值得被保留
