---
name: ingesting-sources
description: "将新素材（文章/PDF/图片/音频/视频/链接）收录进已有知识库并落成 wiki 页面。当用户说「收录这篇文章」「把这个存到/加到知识库」「加入企业知识库」「归档这份资料」「记到 KB/wiki 里」时使用。"
version: 0.7.0
owner_repo: Optima-Chat/kb-skills
---

# Ingesting Sources

把原始材料做第一次落库，进入持续维护的 wiki 结构。产物不只是摘要，而是一页来源页，以及一份"还有哪些页面需要随之更新"的映射。

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
   - ⚠️ 用户说「加入**企业**知识库/给同事共享」时，看 REGISTRY 的 `scope` 列：目标库是
     `enterprise:<uuid>`（含同事的库）→ 收录后由本技能末尾的「Git 同步」在
     `~/kb/<local_dir>/` 内执行 `kb git push` 推送更新；目标库是
     personal → 收录只进个人库，**不要宣称"已加入企业知识库"**——按 initializing-kb 的
     「企业知识库」一节向用户确认后，用 `kb publish --slug <slug>` 将自己的个人库首次发布为企业库（没有 `kb push` 这个命令）
4. 读 `~/kb/<local_dir>/AGENTS.md` 了解该 KB 的契约

## 获取素材到 raw/

用户可能通过以下方式提供素材：

- 本地文件路径 → `cp <path> ~/kb/<local_dir>/raw/<命名后的文件名>`
- URL → 下载到 `~/kb/<local_dir>/raw/`（用 WebFetch 或 curl）
- 直接贴图/附件 → 保存到 `~/kb/<local_dir>/raw/`

文件命名规则：`YYYY-MM-DD-short-description.{ext}`，保留原始扩展名。

## 按类型读取素材

| 类型 | 扩展名 | 读取方式 |
|------|--------|----------|
| 文本 | `.md` `.txt` | 直接读取 |
| PDF | `.pdf` | 直接读取（Claude 原生支持） |
| 图片 | `.png` `.jpg` `.webp` `.gif` | 用 Read 工具查看图片，生成文本描述 |
| 音频 | `.mp3` `.wav` `.m4a` | 加载 gen skill，调 ASR 转文字 |
| 视频 | `.mp4` `.mov` `.webm` | 加载 ffmpeg skill 提取音频 → ASR 转文字；提取关键帧 → 查看描述 |

如果素材类型不在上表中，尝试直接读取；读不了就告诉用户不支持该格式。

## Ingest 流程

1. 确认素材已在 `~/kb/<local_dir>/raw/` 中（如不在，先执行上方"获取素材"步骤）
2. 按上方类型表读取素材内容
3. 提取主要论点、证据、实体和开放问题
4. 在 `~/kb/<local_dir>/wiki/sources/` 中创建或更新对应页面
5. 列出哪些 entity、overview 和 analysis 页面受到影响
6. 如果任务范围包含来源页之外的更新，交给 updating-related-pages 处理，或执行一次有边界的相关页更新
   - 顺手看一眼 `wiki/inbox/`：有与本次主题相关的待整理结论就一并归位（互链+进 index+删 inbox 页）
7. **更新 `index.md`**：所有新创建的 wiki 页面必须加入 `~/kb/<local_dir>/index.md`（格式：`- [页面标题](wiki/path/file.md): 一句话说明`）
8. **确保交叉链接**：每个新页面必须至少被一个其他 wiki 页面链接到（来源页链接到实体页、实体页链接到综述页等），不能有 orphan 页面
9. 更新 `~/kb/<local_dir>/log.md`
10. 追加 `~/kb/PROGRESS.md`
11. **自检**：`kb lint --dir ~/kb/<local_dir>`，如果有 issue 先修复再 commit
12. Git 同步：
   ```bash
   cd ~/kb/<local_dir>
   git remote get-url origin &>/dev/null && kb git pull --rebase
   git add -A && git commit -m "ingest: <来源名>"
   git remote get-url origin &>/dev/null && kb git push
   ```

   > **冲突与红线**：`kb git pull --rebase` 冲突时——先 `git rebase --abort` 回到冲突前，改用
   > `kb git pull --no-rebase` 合并；在冲突文件里**保留双方内容**并加一行「⚠️ 冲突待人工裁决」，
   > commit 后告知用户哪几处需要裁决，绝不静默丢弃任何一方。
   > push 失败（4xx/网络）→ 把错误原样报给用户，按提示重试或拆分；**绝不用
   > `git filter-branch` / `push --force` 等重写历史的手段解决推送问题**——#45 实锤：
   > 那会永久抹掉用户 raw/ 里的原件。
   > `kb git` 报 `Unknown command: git`（容器里还是旧版 CLI）时改跑 `kb sync`（带认证先拉后推），并照实告诉用户推送结果。

## 来源页内容

来源页应至少包含：

- 来源标题
- 来源类型（文本 / 图片 / 音频 / 视频 / PDF）
- 原始文件路径（`raw/` 下的相对路径）
- 简短摘要
- 关键论点
- 关键证据或观察
- 相关实体、主题或概念
- 对既有理解产生的冲突、修正或压力
- 指向受影响页面的链接

对于多媒体来源，描述就是 source page 的核心内容。如果描述不够准确，直接编辑 source page 或重新 ingest 即可——source page 是可变的，raw/ 里的原始文件才是不可变的。

## 抽取规则

- 将来源明确表达的内容与综合推断区分开
- 不要把大段原文直接复制进 wiki
- 优先写成简洁、可链接、之后可更新的陈述
- 当来源含混或不完整时，显式记录不确定性
- 遇到冲突要记录，不要静默抹平

## 何时创建相关页面

出现下列情况时应建议新建页面：

- 某个人、组织、产品或概念很重要，但还没有稳定页面
- 来源引入了一个新的 recurring topic
- 来源实质性改变了某个既有 overview
- 形成的综合结果已经明显值得进入 `wiki/analyses/`

## 最小交付标准

一次成功的 ingest 至少应留下：

- 一页可用的 `wiki/sources/` 页面
- 一份清晰的受影响页面列表
- 足够明确的结构，使下一步 update 很自然
