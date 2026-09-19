---
name: create-requirement-branch
description: "当用户说「创建新需求分支」「开需求分支」「新建需求分支」「用 worktree 并行」时触发。从远程主分支拉最新代码，按 `{id后4位}-{标题截取}（{id}）` 命名分支与 worktree 目录，最后给出进入该目录的路径（`cd …`）；不自动启动本地服务（要起由用户点名）。上游必须是该分支自己。"
---

# 创建需求分支

从**远程主分支最新提交**拉出需求分支，上游设成**同名远程分支（自己）**。

**产出物 = 分支 + worktree 目录 + 一行进入路径**。本技能**不自动启动本地服务**（要起由用户点名，见文末「需要起服务时」）。

**建完之后的开发规范**：本需求的开发提交**都推回这条分支**——提交后直接 `git push` 到该分支的远程同名分支（上游就是它自己）；不推主分支、不 `--force`、不开 PR（除非用户要求）。

**本文档不绑定某个工具**：涉及"打开新目录""后台起服务"这类动作，按你实际用的工具照「跨工具怎么做」选一条。

## 命名规范

```
{短id后4位}-{标题截取}（{短id}）
```

例题（真实输入 → 结果）：

| 输入 | 结果 |
|---|---|
| id `1140677205001002792`（TAPD 链接 `…/story/detail/1140677205001002792`）+ 标题「效果图与转平台能力流程重构（F1~F9 共 9 个功能，均可独立开发上线）」 | `2792-效果图与转平台能力流程重构（1002792）` |
| id `1002816` + 标题「WB 颜色接口按色系分组展示」 | `2816-WB-颜色接口按色系分组展示（1002816）` |
| id `PROJ-88` + 标题「导出报表」 | `PROJ-88-导出报表`（非数字 id：前缀就是完整 id，括号省略） |

**三步推导：**

1. **取 id**
   - 给的是**短 id**（`1002792`）→ 直接用。
   - 给的是**长 id / TAPD 链接**（`1140677205001002792`）→ **去掉前 10 位前缀、再去掉前导 0**，得 `1002792`。
   - 非纯数字 id（`PROJ-88`）→ 原样使用，且**前缀用完整 id、括号省略**。
2. **前缀** = 短 id 的**后 4 位**（`1002792` → `2792`）。
3. **标题截取** = 取标题里**第一个 `（` 或 `(` 之前**的部分 → 去首尾空白 → **空白转 `-`** → 剔除 git 非法字符（`~ ^ : ? * [ ] \` 与控制字符）→ **保留中文**。
   - 建议 ≤ **24 个字符**；太长时保留语义最前的部分截断，并在汇报里写明"标题已截断"。
   - 用户直接给了短标题 → 以用户的为准，不再截取。

**分支名与 worktree 目录名同形**（都用上面这串，不加任何前缀）。

## worktree 建在哪

按序判断，命中即停：

1. **仓库文档优先**：当前 Git 仓根的 `AGENT.md` / `CLAUDE.md` / `AGENTS.md` 里写了并行目录约定 → 照它。
2. **跟仓库现有布局**：仓根下已有前端应用目录（如 `Apps/frontend/`）→ 建在 **`<仓根>/Apps/frontend/<分支名>`**。
   （前端项目在 `Apps/frontend/<某应用>` 的 monorepo 布局，worktree 就放在它旁边。）
3. **兜底**：`<原仓父目录>/<原仓文件夹名>-wt-<分支名>`。

⚠️ 建在仓库工作树内时，父仓 `git status` 会把它显示成未跟踪 → **提醒用户把该目录加进 `.gitignore`**（或确认仓库已有规则）。

## 触发时机

- 「创建新需求分支」「开需求分支」「新建需求分支」「切一条需求分支」
- 「从主分支拉个需求分支」
- 「用 worktree 并行」「当前分支在做别的，另开一条线」

**反例**：只说「切分支」且无 id/标题；只说「拉一下 main」。

---

## 模式选择（先判再做）

| 条件 | 模式 | 行为 |
|---|---|---|
| 用户说「worktree」「并行」「另开一线」「当前分支还在做 A」 | **Worktree（默认并行）** | 在**新目录**挂新分支；**不切换、不 stash、不碰**当前工作区 |
| 当前分支不是主分支，或工作区有未提交改动，又要开新需求 | **Worktree** | 同上 |
| 用户明确说「就在当前仓库切分支 / 不用 worktree」，且工作区允许检出 | **In-place** | 在本仓 `switch -c --no-track` |
| 信息不足 | **先问一句** | 默认倾向 Worktree |

**禁止**：在正开发 A 的脏分支上直接 `checkout -b` 开 B。

---

## 硬性规则（两种模式都要满足）

1. 新分支**只能**从 `origin/<主分支>`（fetch 后）创建。
2. 分支名与 worktree 目录名按上面的**命名规范**。
3. `@{upstream}` **必须是** `origin/<同名分支>`（自己）。
4. **绝对禁止**上游是主分支；禁止向主分支 push。
5. 建分支必须 `--no-track`。
6. **默认不启动本地服务**；只在用户明确说「起服务 / 跑起来」时才执行文末那节。
7. 不改业务代码、不 `commit`。

---

## 公共前置

缺 **需求 id** 或 **需求标题** → 先问，不编造，不跑 git。

### 判定远程主分支 `<主分支>`

1. 读**当前 Git 仓根**的 `AGENT.md` / `CLAUDE.md` / `AGENTS.md`
2. `git symbolic-ref refs/remotes/origin/HEAD`
3. 远程 `main`，否则 `master`
4. 仍不确定 → 问用户

### 确认 Git 仓根

命令必须在**真正的 git 仓库根**执行。多仓工作区根不是 git 根时，先进入对应子仓。

### 撞名处理

本地或远程已有同名分支 / 目录 → **停止**并汇报，不覆盖、不追加序号（改标题，或确认是否复用已有 worktree）。

---

## 模式 A：Worktree 并行（推荐）

```
fetch → worktree add -b --no-track → push -u → 校验上游 → 给出进入路径（不起服务）
```

在**原仓根** `git fetch origin`（可选 `git fetch origin <主分支>:<主分支>`，失败只警告）。**不要** switch/stash 当前分支。

```bash
git worktree add "<worktree路径>" -b "<分支名>" "origin/<主分支>" --no-track
cd "<worktree路径>"
git push -u origin HEAD
```

校验：`@{u}` = `origin/<分支名>`，绝不是主分支。

**复用优先**：同一需求已有 worktree（目录名含同一个 id）时，优先复用该目录，不要重复新建。

### 汇报（Worktree）

```
已用 worktree 并行创建需求分支：

  branch:    <分支名>
  from:      origin/<主分支> @ <short-sha>
  upstream:  origin/<分支名>   （自己，不是主分支）
  worktree:  <工作目录相对路径，如 ./Apps/frontend/2792-效果图与转平台能力流程重构（1002792）>
  进入:      cd ./Apps/frontend/2792-效果图与转平台能力流程重构（1002792）
  （绝对路径：<绝对路径>）
  启动命令:  <dev-cmd，如 pnpm dev>   ← 备查，**未执行**；要跑由你说
  原工作区:  未改动；原窗口可继续跑 A
```

**进入路径怎么给**：
- 优先给**相对当前工作目录**的路径（能算出相对就给相对，短、好粘）；同时附一行绝对路径兜底。
- **分支名里的空白已被转成 `-`，所以 `cd` 那行没有空格、可以直接粘**；全角括号不是 shell 元字符，也不需要转义。想更保险就加引号：`cd "./Apps/frontend/…（1002792）"`。

### 收尾（仅告知）

```bash
git worktree remove "<worktree路径>"
```

---

## 模式 B：In-place（仅本仓切换）

仅当用户明确不用 worktree，且工作区允许时。

```
fetch → switch -c --no-track → push -u → 校验 → 汇报（给路径，不起服务）
```

有未提交且检出会冲突 → **改走模式 A**，禁止 stash 强切。

```bash
git switch -c "<分支名>" --no-track "origin/<主分支>"
git push -u origin HEAD
```

汇报中注明：`工作目录: <仓根>`（没换目录）、`启动命令: <dev-cmd>（未执行）`。

---

## 跨工具怎么做（打开新目录 / 并行开发）

| 工具 | 打开 worktree 目录 |
|---|---|
| **Cursor** | File → New Window → Open Folder，选 worktree 路径（或 `cursor <路径>`） |
| **VS Code** | File → Open Folder…，或终端 `code <路径>` |
| **JetBrains 系** | File → Open…，选 worktree 目录 |
| **命令行型 Agent（Claude Code / WorkBuddy 等）** | 不用"打开"——直接在对话里把工作目录指到 worktree 路径，或 `cd <路径>` 后继续 |
| **纯终端** | `cd <路径>` 即可 |

> 关键不是用哪个工具，而是：**A 在原目录继续，B 在新 worktree 目录里做**。

---

## 需要起服务时（仅用户点名，默认不做）

用户明确说「起服务 / 把 dev 跑起来」才执行本节。判定命令按序：文档里的启动方式 → `package.json` 的 `scripts`（`dev` > `serve` > `start`）→ 锁文件选包管理器（`pnpm-lock.yaml`→pnpm、`yarn.lock`→yarn，否则 npm）→ 仍不确定就问，别瞎猜。

### 先试：共享主仓的 node_modules，跳过 install（秒级）

新 worktree 没有 `node_modules` 才需要 install。**可以不装**——把主 worktree（或上一个 worktree）的 `node_modules` 用符号链接/联接挂过来：

```bash
# mac / Linux：绝对路径最省事（换机器或挪目录会断，断了重连即可）
ln -sfn "<主仓路径>/node_modules" "<worktree路径>/node_modules"
# monorepo 里每个包都有自己的 node_modules，就按同样办法各挂一个

# Windows（PowerShell）：目录联接，普通用户可用
New-Item -ItemType Junction -Path "<worktree路径>\node_modules" -Target "<主仓路径>\node_modules"
```

什么时候**不能**用（回退正常 install）：

- 本分支**改过依赖**（动了 `package.json` / `pnpm-lock.yaml`）→ 共享的是主分支的依赖，会缺包/错版本。
- 出现诡异的模块解析问题、或 pnpm 报 `node_modules` 相关警告且服务起不来 → 撤掉链接，老老实实 `pnpm install --prefer-offline`（暖 store 一般 1 分钟内）。

注意点：

- **git 侧不会把它当成修改**：`node_modules` 本就在 `.gitignore`（pnpm/npm 项目默认），里面的符号链接 `git status` 根本看不到。自检：`git check-ignore -v node_modules`（会显示命中的规则）。
- 主仓必须 install 过；**主分支的依赖更新了，就在主仓重跑一次 install**，worktree 自动跟着用，不用每条分支各装一遍。
- 两个 dev **同时首次启动**会抢 Vite 预构建缓存 → 先起一边，ready 后再起另一边。
- pnpm 可能提示 `node_modules` 是符号链接 → 可忽略；pnpm 的 `.pnpm` 硬链接直连全局 store，跨目录照样可用。
- 不想共享了：删掉链接，正常 install 即可恢复独立依赖。

### 三个必须避的坑

1. **`node_modules` 存在 ≠ 可用**：抽查 `node_modules/.bin` 是否非空；空的话先 `pnpm install --prefer-offline`，还不行 `pnpm install --force`。
2. **别抢端口**：worktree 与原窗口常撞同一默认端口 → 换端口起（`pnpm dev -- --port <空闲端口>` / `PORT=<空闲端口>`），**不要杀原窗口 A 的进程**。
3. **后台起、别阻塞**：用你所在工具的后台终端能力（Cursor 的 `block_until_ms` 设小；WorkBuddy / Claude Code 用后台运行；纯 shell `nohup <dev-cmd> > /tmp/dev-<端口>.log 2>&1 &` + `tail` 确认 ready），读到本机 URL 再汇报。起不来就说清原因，**不要假装服务已起**（分支创建结果保留，不回滚）。

其他：`.env` / `.env.local` 从原仓根复制（只复制被 gitignore 的文件，不提交）；临时端口用命令行/环境变量传，**不要 commit**。

---

## 触发示例

- 「创建新需求分支，id=1140677205001002792，标题=效果图与转平台能力流程重构（F1~F9 共 9 个功能，均可独立开发上线）」→ `2792-效果图与转平台能力流程重构（1002792）`，最后给 `cd` 路径
- 「用 worktree 并行开需求：id=1002816，标题=WB 颜色接口按色系分组展示」→ `2816-WB-颜色接口按色系分组展示（1002816）`
- 「用 worktree 并行开…，顺便把 dev 跑起来」→ 例外：用户点名，才执行「需要起服务时」
- 「开一条需求分支，标题=导出报表，就在当前仓切，不用 worktree」→ 只建分支、给路径，不起服务
