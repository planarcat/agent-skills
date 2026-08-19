---
name: create-requirement-branch
description: "当用户说「创建新需求分支」「开需求分支」「新建需求分支」时触发。从远程主分支拉取最新代码，在本地创建分支 dev/hcb/{需求id}_{需求标题}；创建后必须把上游设为该分支自己，绝对不能跟踪主分支。"
---

# 创建需求分支

从**远程主分支最新提交**拉出一条本地需求分支，并立刻把上游设成**同名远程分支（自己）**。本 skill **只做分支操作**，不改业务代码、不 commit。

## 触发时机

说出以下或相近表达时使用本 skill：

- 「创建新需求分支」
- 「开需求分支」「新建需求分支」「切一条需求分支」
- 「从主分支拉个需求分支」

**反例**（不触发）：只说「切分支」「checkout」且未给需求 id/标题；只说「拉一下 main」。

---

## 硬性规则（必须同时满足）

1. 新分支**只能**从远程主分支的最新提交创建，不能从当前脏分支或过期本地主分支当起点（本地主分支可顺带快进，但不能当唯一真相）。
2. 分支名固定为：`dev/hcb/{需求id}_{需求标题}`。
3. 创建完成后，`@{upstream}` **必须是** `origin/dev/hcb/{需求id}_{需求标题}`（自己）。
4. **绝对禁止**把上游设成主分支（`origin/main`、`origin/master`、文档里标明的主干等）。
5. 禁止向主分支 push、禁止 `git push origin HEAD:主分支`、禁止 `git branch -u origin/主分支`。

`git checkout -b <新分支> origin/<主分支>` 在默认配置下常会把上游悄悄设成主分支——**禁止这样建分支**。

---

## 工作流程

```
1. 解析需求 id / 标题 → 2. 判定主分支名 → 3. 检查工作区 → 4. fetch 并更新本地主分支
→ 5. --no-track 创建并检出新分支 → 6. push -u 到同名远程 → 7. 校验上游是自己
```

缺 id 或标题时**先问用户**，不要编造，不要进入 git 步骤。

---

## 第一步：解析分支名

从用户这句话里取出 **需求 id** 和 **需求标题**。

| 输入示例 | 结果 |
|---|---|
| 创建新需求分支 1024 登录页增加验证码 | `dev/hcb/1024_登录页增加验证码` |
| 开需求分支，id=PROJ-88，标题=导出报表 | `dev/hcb/PROJ-88_导出报表` |
| 新建需求分支 ISSUE-12 修复支付回调 | `dev/hcb/ISSUE-12_修复支付回调` |

**标题清洗（只做安全化，不改语义）：**

- 去首尾空白；空白改成 `-`
- 去掉 git 非法字符：`~ ^ : ? * [ \ .. @{`
- 连续 `-` 压成一个；去掉首尾 `-` 和 `.`
- **不要**把标题里的中文改成拼音或英文

id、标题都有才能继续。只有一个片段时，问清哪个是 id、哪个是标题。

本地或远程已存在同名分支 → **停止**，告知用户，不要覆盖、不要改名硬切。

---

## 第二步：判定远程主分支名

按顺序，命中即停：

1. 读工作区根目录 **`AGENT.md`、`CLAUDE.md`**（若存在也读 `AGENTS.md`）。只采**明确写明的主干**，例如：
   - `主分支` / `主干` / `default branch` / `base branch`
   - `origin/main`、`origin/master`、`origin/develop` 等作为主干的说明
2. 仍不确定：`git symbolic-ref refs/remotes/origin/HEAD`（如 `origin/main` → `main`）
3. 再不行：远程是否有 `main`，否则 `master`
4. 仍不确定 → **问用户**，不要猜 `develop`

下文把该名字记为 `<main>`。

---

## 第三步：检查工作区

```bash
git status --short
git branch --show-current
```

| 状态 | 处理 |
|---|---|
| 合并 / rebase / cherry-pick 进行中 | 停止，让用户先结束 |
| 有未提交改动，且检出新分支会冲突 | 停止，不要 stash、不要丢改动 |
| 工作区干净，或不影响检出 | 继续 |

---

## 第四步：拉取远程主分支最新代码

```bash
git fetch origin
```

尽量把**本地** `<main>` 快进到远程（本地 `<main>` 不是当前分支时可用右边这条）：

```bash
git switch <main>
git pull --ff-only origin <main>
```

当前不在 `<main>` 时，优先快进引用、避免无关切换：

```bash
git fetch origin <main>:<main>
```

- `--ff-only` / 快进失败（本地主分支分叉）→ **不要 merge、不要 rebase 主分支**。警告用户，新分支仍从 `origin/<main>` 创建。
- 新分支的起点永远是 `origin/<main>`（fetch 之后），不是「可能过期的本地主分支」。

---

## 第五步：创建并检出新分支（禁止跟踪主分支）

**必须用 `--no-track`**，起点用远程主分支：

```bash
git switch -c dev/hcb/{需求id}_{需求标题} --no-track origin/<main>
```

旧 git 等价：

```bash
git checkout -b dev/hcb/{需求id}_{需求标题} --no-track origin/<main>
```

**禁止：**

```bash
git switch -c <新分支> origin/<main>          # 缺 --no-track，上游常变成主分支
git checkout -b <新分支> origin/<main>        # 同上
git checkout -b <新分支>                      # 若当前不在最新主分支，起点错误
git branch -u origin/<main>                   # 任何时候都不允许
```

若发现已经跟踪了主分支，立刻断开（第六步成功前也要做）：

```bash
git branch --unset-upstream
```

---

## 第六步：把上游设成自己（必须 push）

本地没有同名远程分支时，上游无法变成「自己」。因此本 skill **要 push**，且只推这条新分支：

```bash
git push -u origin HEAD
```

等价且允许：`git push -u origin dev/hcb/{需求id}_{需求标题}`。

**禁止：**

```bash
git push origin HEAD:<main>
git push -u origin <main>
git push origin <新分支>:<main>
```

push 失败（无权限、无远程、网络）：保持 `--unset-upstream`（上游为空可以，跟踪主分支不行），告诉用户稍后必须执行 `git push -u origin HEAD`，**不要**改成跟踪主分支。

---

## 第七步：校验（不通过就修，不能交差）

```bash
git branch --show-current
git rev-parse --abbrev-ref @{u}
git status -sb
```

| 检查 | 必须 |
|---|---|
| 当前分支 | `dev/hcb/{需求id}_{需求标题}` |
| `@{u}` | `origin/dev/hcb/{需求id}_{需求标题}` |
| `@{u}` | **不是** `origin/<main>`，也不是任何被认定为主干的名字 |

若 `@{u}` 是主分支：`--unset-upstream`，再 `git push -u origin HEAD`，重新校验。

环境里有设置当前会话 Git 分支的工具时，把活动分支设成这条新分支。

---

## 汇报

```
已创建需求分支：

  branch:   dev/hcb/{需求id}_{需求标题}
  from:     origin/<main> @ <short-sha>
  upstream: origin/dev/hcb/{需求id}_{需求标题}   （自己，不是主分支）
```

---

## 触发示例

- 「创建新需求分支 1024 登录页增加验证码」
- 「开一条需求分支，PROJ-88，导出报表」
- 「从主分支拉最新代码，新建需求分支 ISSUE-12 修复支付回调」
