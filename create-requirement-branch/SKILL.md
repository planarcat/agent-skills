---
name: create-requirement-branch
description: "当用户说「创建新需求分支」「开需求分支」「新建需求分支」「用 worktree 并行」时触发。从远程主分支拉最新代码，创建 dev/hcb/{需求id}_{需求标题}；并行时用 Git Worktree 并默认在新目录自动起本地服务；本仓普通新建分支一般不起服务；上游必须是该分支自己。"
---

# 创建需求分支

从**远程主分支最新提交**拉出需求分支 `dev/hcb/{需求id}_{需求标题}`，把上游设成**同名远程分支（自己）**。

**本地服务：**

| 模式 | 是否自动起本地服务器 |
|---|---|
| **Worktree（并行）** | **默认启动**（新目录没有正在跑的服务；除非用户说「不起服务」） |
| **In-place（本仓普通建分支）** | **默认不启动**（同一工作区，原服务通常仍可用；除非用户明确说「顺便起服务 / 重启 dev」） |

Cursor **不会**在「当前分支被占用」时自动建 worktree；要并行时由本 skill **显式**走 Worktree。本 skill **不改业务代码、不 commit**。

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

1. 新分支**只能**从 `origin/<main>`（fetch 后）创建。
2. 分支名：`dev/hcb/{需求id}_{需求标题}`。
3. `@{upstream}` **必须是** `origin/dev/hcb/{需求id}_{需求标题}`。
4. **绝对禁止**上游是主分支；禁止向主分支 push。
5. 建分支必须 `--no-track`。
6. **仅 Worktree 模式**在分支就绪后默认启动本地服务器（见「自动启动本地服务器」）；In-place **默认跳过**起服务。

---

## 公共前置

缺 **需求 id** 或 **需求标题** → 先问，不编造，不跑 git。

### 解析分支名

| 输入示例 | 结果 |
|---|---|
| 创建新需求分支 1024 登录页增加验证码 | `dev/hcb/1024_登录页增加验证码` |
| 开需求分支，id=PROJ-88，标题=导出报表 | `dev/hcb/PROJ-88_导出报表` |

标题清洗：空白→`-`；去掉 git 非法字符；保留中文。本地或远程已有同名分支 → **停止**。

### 判定远程主分支 `<main>`

1. 读**当前 Git 仓根**的 `AGENT.md` / `CLAUDE.md`（有则也读 `AGENTS.md`）
2. `git symbolic-ref refs/remotes/origin/HEAD`
3. 远程 `main`，否则 `master`
4. 仍不确定 → 问用户

### 确认 Git 仓根

命令必须在**真正的 git 仓库根**执行。多仓工作区根不是 git 根时，先进入对应子仓。

---

## 模式 A：Worktree 并行（推荐）

```
fetch → worktree add -b --no-track → push -u → 校验上游
→ 依赖就绪 → 自动启动本地服务器（本模式默认）→ 汇报路径与访问地址
```

### A1–A4：建分支（摘要）

在**原仓根** `git fetch origin`（可选 `git fetch origin <main>:<main>`，失败只警告）。**不要** switch/stash 当前分支。

```bash
git worktree add <worktree路径> -b dev/hcb/{需求id}_{需求标题} origin/<main> --no-track
cd <worktree路径>
git push -u origin HEAD
```

路径默认：`<原仓父目录>/<原仓文件夹名>-wt-{需求id}_{短标题}`。

校验：`@{u}` = `origin/dev/hcb/...`，绝不是主分支。

### A5：依赖与本地服务器

在 **`<worktree路径>`** 内执行「自动启动本地服务器」全节。原窗口已在跑的 A 服务**不要停**。

### A6：汇报（Worktree）

```
已用 worktree 并行创建需求分支：

  branch:    dev/hcb/{需求id}_{需求标题}
  from:      origin/<main> @ <short-sha>
  upstream:  origin/dev/hcb/{需求id}_{需求标题}   （自己，不是主分支）
  worktree:  <绝对路径>
  本地服务:  <启动命令> → <本地 URL，含端口>
  原工作区:  未改动；原窗口服务可继续跑 A

请用 Cursor：File → New Window → Open Folder，打开上述 worktree。
原窗口做 A；新窗口做 B（B 的预览用上面的 URL）。
```

### A7：收尾（仅告知）

```bash
git worktree remove <worktree路径>
```

---

## 模式 B：In-place（仅本仓切换）

仅当用户明确不用 worktree，且工作区允许时。

```
fetch → switch -c --no-track → push -u → 校验 → 汇报（默认不起服务）
```

有未提交且检出会冲突 → **改走模式 A**，禁止 stash 强切。

```bash
git switch -c dev/hcb/{需求id}_{需求标题} --no-track origin/<main>
git push -u origin HEAD
```

**不要**自动起本地服务器。同一工作区里原 `dev` 进程一般仍对着当前目录，换分支后热更新/刷新即可。仅当用户明确说「起服务」「重启 dev」时，才在当前仓根执行「自动启动本地服务器」，并注意勿误杀其他 worktree 的进程。

汇报中注明：`本地服务: 未启动（本仓普通建分支，沿用原服务即可）`。

---

## 自动启动本地服务器（仅 Worktree 默认；In-place 需用户点名）

| 谁执行 | 条件 |
|---|---|
| **Worktree** | 默认执行；用户说「不起服务」「不用启动」「先别跑 dev」则跳过 |
| **In-place** | 默认**不**执行；仅用户明确要求起/重启服务时执行 |

工作目录 = Worktree 的新路径（或 In-place 经用户要求时的当前仓根）。跳过时汇报写明原因（「已按要求未启动」或「本仓普通建分支，默认不起服务」）。

### 1. 判定启动命令（按序，命中即停）

1. **当前 Git 仓根** `AGENT.md` / `CLAUDE.md` / `AGENTS.md` 里写明的本地启动方式（如 `pnpm dev`、`npm run serve`、端口说明）
2. `package.json` → `scripts`：优先 `dev`，其次 `serve`，再 `start`
3. 锁文件选包管理器：`pnpm-lock.yaml` → `pnpm`；`yarn.lock` → `yarn`；否则 `npm`
4. 仍不确定 → 问用户一句，**不要瞎猜**长命令

记录为 `<dev-cmd>`，例如 `pnpm dev`。

### 2. 依赖安装（Worktree 尤其要做）

新 worktree **通常没有**可用的 `node_modules`（或与工具链不完整）。在启动前：

```bash
# 在新需求工作目录内
# 有 pnpm-lock → pnpm install；yarn.lock → yarn；否则 npm install
```

已有完整 `node_modules` 且安装不明显过期 → 可跳过 install，直接起服务。install 失败 → 汇报错误，**不要假装服务已起**。

若项目文档要求复制 `.env` / `.env.local`：从原仓根复制到 worktree（只复制被 gitignore 的本地环境文件，不提交）。没有则按文档提示用户，不编造密钥。

### 3. 端口策略（并行时必查）

Worktree 与原窗口常会**抢同一默认端口**。

1. 从文档 / Vite·Webpack 配置 / `package.json` 读默认端口；常见前端 `5173`、`3000`、`8080` 等
2. 若默认端口已被占用（原窗口 A 很可能在用）：
   - **换端口启动**，不要杀 A 的进程
   - 优先用项目支持的方式，例如：
     - `pnpm dev -- --port <空闲端口>`
     - `npm run dev -- --port <空闲端口>`
     - 环境变量 `PORT=<空闲端口>`（以该项目实际支持为准）
   - 选一个空闲端口（如默认+1，再探测；`5173` 忙则试 `5174`…）
3. In-place 且用户就是要重启当前目录服务：可先停本目录旧 dev 再起；仍不要误杀**其他目录/其他 worktree** 的进程

### 4. 后台启动并确认

在新需求工作目录：

- 用终端**后台**跑 `<dev-cmd>`（必要时带换端口参数）
- `block_until_ms` 设小或 `0`，避免一直卡在启动日志上；再读终端输出，确认出现 Local / Network URL 或 “ready”
- 把 **URL（含端口）** 写进最终汇报
- 启动失败（依赖、编译、端口）→ 说明原因与已尝试命令；分支创建结果仍然保留，不回滚分支

### 5. 禁止

- 不要在**原 worktree / 原窗口目录**里再起一份 B 的服务（B 必须在新目录起）
- 不要为了起 B 而关掉 A 的服务（除非用户明确说停 A）
- 不要 `git commit` 把端口改动或 `.env` 提交上去（临时换端口用 CLI/环境变量即可）

---

## 触发示例

- 「创建新需求分支 1024 登录页增加验证码」（若走 in-place：只建分支，不起服务）
- 「用 worktree 并行开需求：id=1024，标题=登录页验证码」（worktree + 新目录默认起服务，换端口避开 A）
- 「用 worktree 并行…，先不起服务」
- 「开一条需求分支 PROJ-88 导出报表，就在当前仓切，不用 worktree」（不起服务）
- 「本仓切到新需求分支并重启一下本地服务」（In-place + 用户点名才起服务）
