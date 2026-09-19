---
name: tapd-todo-query
description: 查询何成标在 TAPD 各项目（灵创_用户端 / 来图 / 灵创_工厂端）名下待开发的需求清单（未完成状态）。当用户问「TAPD 上我还有哪些需求/任务待开发」「查一下待办需求」「核对 TAPD 需求状态」时使用。需要 TAPD connector 已连接。
---

# TAPD 待开发需求查询

## 何时使用
- 用户问「TAPD 上我还有哪些需求待开发 / 待办 / 没做完的需求」
- 用户要求核对 TAPD 需求状态（周报/周评交叉验证、安排排期用）
- 用户提到具体需求编号要查详情/状态

## 前置
- TAPD connector 已连接（disconnected 时先提示用户连接）
- 工具均为 deferred：先 ToolSearch 加载 mcp__tapd__get_user_participant_projects / get_stories_fields_info / get_stories_or_tasks / get_story_or_task_count，再用 DeferExecuteTool 调用

## 流程（三步）

### Step 1：获取用户参与的项目
- 调 get_user_participant_projects（不传参，自动取当前用户）
- **过滤 category == "organization"（公司）**，只留 project
- 何成标参与的项目：来图 39230945 ｜ 灵创_用户端 40677205 ｜ 灵创_工厂端 44355585

### Step 2：获取各项目 status 候选值（中文映射，必须逐个查）
- 每个项目调 get_stories_fields_info(workspace_id)，status 枚举**各项目不同**：
  - 灵创_用户端：planning=初稿 / developing=实现中 / status_3=评审中 / status_4=测试中 / resolved=已实现 / rejected=已拒绝
  - 来图：planning=初稿 / developing=评审中 / status_2=实现中 / status_3=测试中 / status_4=待验收
  - 灵创_工厂端：planning=初稿 / developing=实现中 / status_3=评审中 / status_4=测试中 / status_5=产品体验
- 查未完成需求 = 排除 resolved / rejected

> ⚠️ **两套状态中文名打架（09-18 实测）**：上面是 TAPD 里**当前的**枚举中文名；但 v3 规范 §7.1 要求日报对外写**新语义**——
> `planning`→**评审中**、`developing`→**开发中**、`status_3`→**待测试**、`status_4`→**测试中/待验收**、`resolved`/`closed`→**已闭环**。
> 另：**`planning` 不是"还没开始"**，它是"正在等人评审方案"，卡住时追责对象是评审人/排期。
>
> 🔴 **两套顺序根本不一样，别混（09-18 二轮实测）**：
> - **TAPD 用户端旧枚举**的流转顺序（`get_workflows_all_transitions` 实测）：`planning`(初稿) → `status_3`(**评审中**) → `developing`(实现中) → `status_4`(测试中) → `resolved`(已实现)
> - **v3 §7.1 表假设的顺序**：`planning`(评审中) → `developing`(开发中) → `status_3`(待测试) → `status_4`(测试中/待验收)
> - 也就是说：**"评审中"这个词，TAPD 界面挂在 `status_3`、v3 规范挂在 `planning`**。用户在界面上看到并点名的「评审中」= `status_3`；机器比对审核时用的却是规范表。
>
> 🔴 **判断规则（改状态前必走）**：用户说"改成 X"时先分清他要哪个：
> 1. **要让日报合规**（＝报表与 TAPD 按 §7.1 表对得上）→ **按规范表反推 raw key**。要「评审中」就设 **`planning`**；要「待测试」才设 `status_3`。
> 2. **只是想让 TAPD 界面显示 X** → 按界面同名选项设（「评审中」= `status_3`），但要**当场说明**：这会让日报写「评审中」时按规范表被判成 planning，与 `status_3` 不一致（虚报口径，宽限期只标黄）。
> **默认走 1**（考核比对用规范表），把差别讲清楚让用户拍板。**别默认走 2 也不吭声**——09-18 就是这么埋了一个不一致。
> 拿不准就先 `get_stories_fields_info` 看 `status.options` 里哪个 key 挂着用户说的那个中文名。

### Step 3：查询未完成需求
- get_stories_or_tasks(workspace_id, options)：
  - entity_type: "stories"（需求；任务用 "tasks"，状态只有 open/progressing/done）
  - owner: "何成标"（支持中文姓名）
  - v_status: 中文枚举（按项目 Step 2 的结果组装，如 "初稿|实现中|评审中|测试中"）
  - fields: "id,name,status,owner,priority,due,module"
  - limit: 100；或先 get_story_or_task_count 看总数

## 汇总输出
按项目分组表格：ID | 标题 | 状态 | 优先级 | 截止 | 备注
- 截止已过标 🔴，月底前到期标 🟡
- **重点提示：TAPD 状态常滞后于实际开发**（本周已上线的需求仍显示「实现中」），提醒用户统一更新状态，避免周报/考核口径对不上
- 需求链接：https://www.tapd.cn/{workspace_id}/prong/stories/view/{id}

## 注意事项
- 优先级：灵创_用户端/工厂端用 priority_label（High/Middle/Low），来图用 priority（紧急/高优先/中优先/低优先）
- owner 支持中文姓名；v_status 支持中文状态名
- 父需求 vs 子需求：可用 parent_id / ancestor_id 追溯（如 1002652 手工单业务逻辑重构是父需求，子需求 1002681/1002682/1002683）

## 字段名坑（09-18 实测）
- **`workitem_type_name` 不是有效的 fields 参数**——传了会被静默丢弃，返回里根本不出现。想拿需求类别：先取 `workitem_type_id`（有效字段），再用 **get_workitem_types(workspace_id)** 换名字。
- **用户端只有三种工作项类型**：`需求`(story) / `特性`(Featrue) / `史诗故事`(Epic)——**没有 v3 规范要求的「技术开发 / 文案内容 / 混合 / 技术任务」需求类型字段**。日报里那栏只能按工作性质人工判断填写，并注明该字段 TAPD 尚未上线（v3 系统在铺开期，规范给了 2~4 周宽限）。
- 用户端的自定义字段只有 4 个：`custom_field_one`=需求来源、`two`=备注、`three`=研发自测&签字、`four`=组长签字。**没有** v3 提到的「开工校验记录 / 异常穷举报告 / 方案链接 / 方案版本 / 方案评审分」——这些字段同样还没上线，别去查、也别在日报里编。
- `get_stories_or_tasks` 返回的 **`modified` 字段很好用**：判断"这条需求今天有没有被动过"（如 1002792 modified=09-18 19:33 → 需求改写确实当天落进 TAPD）。
- **改 `iteration_id`（挂迭代）**：子需求可以正常改（`options={"iteration_id":"<迭代id>"}`），**但「有子需求的父需求」传 `iteration_id` 会 422 ParamError**（09-18 实测：#1002792 试两次都失败，同批 10 个子需求全部成功）→ 父需求的迭代在 TAPD 界面上设，或忽略（目标对齐率看叶子任务）。
- 挂迭代前先 `get_stories_fields_info` 看 `iteration_id.options`，里面带**「（当前迭代）」**字样的才是当前迭代；**可能有多个**（用户端同时挂着「【灵创】v2.0.9（当前迭代）」和「Wildberries平台接入（当前迭代）」）→ **按同主题的兄弟需求取齐**（实测：工厂端所有 WB 开头的单都挂「Wildberries平台接入」，所以 #1002816 也挂它，而不是挂「【灵创工厂】2026年9月」）。

## 改 TAPD 同步字段时（owner / 状态，09-18 实测）
日报 v3 里 `owner` 和 `状态` 都是〔同步〕字段 —— **用户说"日报里的 owner / 状态要改"，正确动作是改 TAPD、让报表跟着同步**，只改日报 = 反向不一致 = 虚报。

改父子结构的 owner 时**必须级联**（父改了子不会跟着变）：
1. 先实查完整子列表：`get_stories_or_tasks(ws, {"entity_type":"stories","ancestor_id":"<父id>","fields":"id,name,owner,status","limit":50})` —— 返回里含父需求本身，**别用记忆里的"父 + N 子"数字**（会过时）。
2. 逐条 update：`update_story_or_task(ws, {"entity_type":"stories","id":"<id>","owner":"何成标;张栋栋"})`（多 owner 用**英文分号**分隔，结尾带不带分号都能写成功）。
3. 改完再查一遍复核；子需求里 owner 只有后端单人（本人不参与）的**不动**。

实例：#1002792 父 + 10 子，把袁广杰换成张栋栋 = **9 次 update**（父 + F1~F9）；#2875 需求评审 owner 只有张栋栋，跳过后**看起来"少改一条"，这是对的**。

### 改状态：先查工作流，别硬跳（09-18 实测）
用户端 `需求` 类型的流转（`get_workflows_all_transitions`，system=story, workitem_type_id=1140677205001000015）实际是：
```
初稿 planning → 评审中 status_3 → 实现中 developing → 测试中 status_4 → 已实现 resolved
```
- `planning` 可去：planning / **status_3** / developing / resolved / rejected
- `developing` 只能去：developing / **status_4** / rejected（**不能直达 status_3**）
- `status_4` 只能去：status_4 / resolved
- 所以用户说"某条改成评审中"时，若那条现在是「实现中」，**工作流不允许**——要么先退回初稿再走，要么只能落到「测试中」。先查表再回话，别硬写。
- 怎么落库：`options={"v_status":"<中文名>"}`（中文别名可用）。**但用户说的中文名要先过一遍上面的「判断规则」**：v3 要「评审中」→ 写 `"初稿"`/`planning`；要让界面显示「评审中」→ 写 `"评审中"`/status_3。**默认按规范表（合规优先），并说明差别。**

**批量改状态同理逐条做**，别只改父（改父不会带着子变）；#1002792 实测 11 条（父 + 10 子）全部 planning→status_3，11 次调用。

### 09-18 那一轮的真实教训（别重犯）
用户说「改成评审中」，我按界面同名选项设成了 `status_3` 并回"日报不用改"。复查时发现 **v3 §7.1 把 `status_3` 定义成「待测试」**，于是日报写「评审中」= 声称 planning ≠ TAPD 的 status_3 → 按双向虚报口径**报表与 TAPD 不一致**。
**正确做法**：听到中文状态名先问自己"他要的是报表那个词，还是界面那个词"，**默认让 TAPD 落到规范表对应的 raw key（评审中→planning）**，这样报表写「评审中」两边都对得上；而且 planning 的规范含义（"等方案评审"）通常正好就是真实现状。若用户确实要让界面显示「评审中」，也要同时告诉他这会牺牲报表一致性。

另：日报正文写"总条数/总个数"要留余地 —— 写死「重写为父 + 9 子」后，同事当晚 19:33 又加了一条子需求，数字当场就对不上了。改成与 TAPD 标题一致的口径（如「F1~F9 共 9 个功能子需求」）更稳。

## 查具体某条需求时（截图没带 id / 要核对挂靠）
- **id 只是需求号尾段，跨项目会撞**：`1002816` 在用户端是「场景化刊登-刊登导出-价格模版」（已实现），在工厂端是「WB 颜色接口按色系分组展示」——**查 id 必须带 workspace_id**，拿到号先确认是哪个项目。
- 用户只给标题时，用 `options={"name": "%关键词%"}` **逐项目模糊匹配**（如 `name=%WB%` 在工厂端一次就命中）。
- **虾皮 POD 的需求挂在来图项目 39230945 的父需求 1002708「虾皮POD上架系统开发」下**（21 条子需求，多为 planning）。子需求对不上当日具体事项时，日报里括注父需求 1002708。
