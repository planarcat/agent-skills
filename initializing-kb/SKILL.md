---
name: initializing-kb
description: "创建新知识库或初始化 ~/kb 工作空间（个人库与企业库同一入口，企业共享靠后续 publish）。当用户说「建个知识库」「我想整理XX的知识」「新开一个 KB/wiki」「把这类资料长期管起来」「建企业知识库/团队知识库」时使用。"
version: 0.6.0
owner_repo: Optima-Chat/kb-skills
---

# Initializing KB

创建一个基于 Markdown 的知识库。主要产物是 `~/kb/<local_dir>/` 目录和其中的 `AGENTS.md`（新建自己的库时，local_dir = slug）。

## 核心：工作目录

所有知识库都在 `~/kb` 下，每个知识库一个子目录。

```text
~/kb/
├── REGISTRY.md
├── PROGRESS.md
├── <slug>/
│   ├── .git/
│   ├── AGENTS.md
│   ├── index.md
│   ├── log.md
│   ├── raw/
│   └── wiki/
│       ├── overview/
│       ├── entities/
│       ├── sources/
│       └── analyses/
└── <slug-2>/
    └── ...
```

## 启动 SOP

0. 自动迁移与同步（后台执行，成功不必汇报；**失败必须告知用户一句**——sync 失败
   意味着本地与远端/企业库脱同步，静默吞掉只会让两边越漂越远）：
   ```bash
   [ -d ~/kb/.git ] && kb migrate
   [ -n "$KB_BACKEND_URL" ] && kb sync
   ```
1. `ls ~/kb/REGISTRY.md`
   - 不存在 → 初始化根目录（见下方"首次初始化"）
   - 存在 → 读 `~/kb/REGISTRY.md`，了解已有的知识库
   `local_dir` 列是该库在 `~/kb/` 下的目录名（自己的库 = slug；同事的库 = `<作者>--<slug>`），下文的 `<local_dir>` 都指它。
2. 询问用户要创建什么主题的知识库

## 首次初始化

如果 `~/kb` 不存在：

1. `mkdir -p ~/kb`
2. 创建 `~/kb/PROGRESS.md`：

   ```markdown
   # 知识库工作日志
   ```

3. 如果 `KB_BACKEND_URL` 已设置，运行 `kb sync`（会自动生成 REGISTRY.md）。否则手动创建空 REGISTRY.md：

   ```markdown
   # Knowledge Base Registry

   | local_dir | slug | name | scope | owner | status | created_at | notes |
   |-----------|------|------|-------|-------|--------|------------|-------|
   ```

   > `scope` 列的 `enterprise:<uuid>` 表示已发布为企业知识库；旧的 `team:<uuid>` 是历史值，下次 `kb sync` 会自动刷新。

## 创建知识库

1. 询问用户知识库主题
2. 从主题生成 kebab-case slug 建议（不带 `-kb` 后缀）
3. 校验 slug：
   - 匹配 `^[a-z0-9][a-z0-9-]{0,29}$`
   - 不与 `REGISTRY.md` 已有 slug 重复
   - 让用户确认或修改
4. `kb create --slug <slug> --name "<主题>"`
   - 自动创建目录结构（AGENTS.md、index.md、log.md、raw/、wiki/）
   - 自动 git init + commit
   - 如果 KB_BACKEND_URL 已设置，自动注册到 kb-backend
5. 根据用户的素材和需求，编辑 `AGENTS.md`（见下方"AGENTS.md 内容"）

## 企业知识库（共享给同事）

触发词：「企业知识库」「加到公司/团队的库」「让同事也能看到」「团队共享」。

关键事实：**`kb create` 建出的库永远是 personal（仅自己可见）——库名叫"企业知识库"≠ 已发布**。共享靠显式发布：

1. 照上面流程建库、收录内容（没有单独的"企业版 create"）；
2. 发布是共享操作，先向用户确认：「发布后企业内全员可见、可共同编辑，确认发布吗？」
3. 确认后执行 `kb publish --slug <slug>`，将自己的个人库首次发布为企业库——发布目标由服务端从当前席位身份自动推导（不需要也不能传企业 id）；个人账号无企业席位会被拒（ENTERPRISE_REQUIRED）；
4. 之后内容有更新，由各技能的「Git 同步」在 `~/kb/<local_dir>/` 内执行 `kb git push` 推送（含同事的已发布企业库）；撤回共享用 `kb unpublish --slug <slug>`。

交付话术必须区分两种状态，不可混用：

- 未发布：「已收录到**个人**知识库 <name>（仅你可见）。要共享给企业同事，我可以发布为企业知识库，确认吗？」
- 已发布：「已发布为**企业**知识库（企业内全员可见、可共同编辑）」

⚠️ 没有 `kb push` 这个命令；自己的库首次发布为企业库用 `kb publish --slug <slug>`，之后内容更新由各技能的「Git 同步」在 `~/kb/<local_dir>/` 内执行 `kb git push`。

## AGENTS.md 内容

至少应包含：

- 仓库目标
- `raw/` 的 source-of-truth 规则
- 页面类型及其职责
- ingest 工作流
- query 工作流
- lint 工作流
- 编辑规则
- 命名约定
- 何时应新建页面，而不是继续扩写旧页
- agent 修改后的输出要求

## 页面模型

默认页面职责：

- `wiki/sources/`：每个来源一页
- `wiki/entities/`：每个跨多个来源反复出现的稳定实体或概念一页
- `wiki/overview/`：每个主题或认知领域一页
- `wiki/analyses/`：长期有效的答案、比较、综合或决策记录

避免混淆这些角色。

## 命名规则

- 来源页：`YYYY-MM-DD-short-source-name.md`
- 分析页：`YYYY-MM-DD-short-analysis-name.md`
- 实体页：`kebab-case-entity-name.md`
- 综述页：`kebab-case-topic-name.md`

## 好的结果

一个好的 schema 应该让这些决策变得容易：

- 新来源应该落到哪里
- 一个概念什么时候值得拥有独立实体页
- 一个高价值答案应该写回哪里
- 冲突信息应如何呈现
- 之后如何再次找到这些页面
