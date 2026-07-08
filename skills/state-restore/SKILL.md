---
name: state-restore
description: >-
  新会话启动时恢复 Working State。
  SOUL.md 指令要求加载本 skill。
  读取 ~/.hermes/state/ 下的 state 文件，恢复连续上下文。
version: 1.0
state_schema:
  global: 1.0
  project: 1.0
  task: 1.0
---

# State Restore — 恢复 Working State

## 触发方式

本 skill 由 SOUL.md 的"跨会话连续性"指令要求在每次新会话启动时加载。非框架自动，而是身份锚定中的显式指令。

## 执行步骤

### 1. 检查 state 文件是否存在

```
~/.hermes/state/global.yaml
~/.hermes/state/active/project.yaml
~/.hermes/state/active/task.yaml
```

缺少任意一个文件 → 跳过恢复（新用户或首次使用）。

### 2. 读取 state 文件

使用 read_file 依次读取三个文件。

### 3. 检查多项目列表

```
ls ~/.hermes/state/projects/*.yaml 2>/dev/null
```

如果 projects/ 下有多个项目快照，记录项目名供后续提示使用。

### 4. 构建双输出：结构化状态 + 人类摘要

**4a. 结构化状态（Agent 推理用）**

内部生成 YAML 状态块，注入推理上下文：

```yaml
## Working State
project: <project.name>
goal: <project.goal>
status: <project.status>
blockers: <project.blockers>
confirmed_decisions: <project.recent_decisions>
current_task: <task.current_task>
next_actions: <task.next_actions>
open_questions: <task.open_questions + project.pending_questions>
```

这段结构化数据用于 Agent 推理，不直接输出给用户看。

**4b. 人类摘要（用户看）**

向用户输出以下格式（无多余开场白）：

```
── 状态恢复 ──────────────────────────────────

上次在做：
  <task.current_task>

进度：
  <task.completed_this_session 最近5条>

下一步：
  <task.next_actions>

阻塞：
  <task.current_blocker 或 无>

决策记录：
  <project.recent_decisions 最近3条>

项目资源：
  <project.resources 中的关键资源状态>
─────────────────────────────────────────────
其他项目：
  <项目1>
  <项目2>
  输入 '切换 <项目名>' 可切换。
─────────────────────────────────────────────
接续上次的来做？还是先处理别的？
```

### 5. 主动加载相关 Hindsight 记忆

在输出恢复摘要前，用 hindsight_recall 搜索与 project 和 current_task 相关的记忆。

`hindsight_recall(query="<project.name> <task.current_task>")`

如果有高相关性结果，追加到摘要中。

### 5b. 状态完整性校验（检测 State Reality Drift）

恢复后检查状态是否与已知事实一致。关键信号：

- **时间戳异常** — task.updated_at 远早于当前会话时间，但状态显示"进行中"
- **已完成任务显示 ⏳** — 事实已完成的 milestone 在 state 中仍标记为 pending
- **用户纠正恢复摘要** — 用户说"这个已经做完了"或"那个不用做了"
- **事件日志与 state 不一致** — events/<project>.log 中有完成事件，但 project.yaml 未更新

检测到 drift 时：
1. 在人类摘要末尾追加章节：`⚠ State Reality Drift 检测到 — <描述不一致点>`
2. 不自动修复，等待用户确认后再执行 reconciliation

Drift reconciliation 流程见参考文档 `state-reality-drift.md`。

### 6. 等待用户确认

不要直接继续上次的任务。先问用户是否要接续，还是换方向。

## 多项目切换

用户要求切换到指定项目时：

1. 检查 `projects/<project>.yaml` 是否存在
2. 如果存在，使用 `bash ~/.hermes/state/state-switch <project-name>` 执行切换
   - state-switch 执行 snapshot-save → snapshot-load 语义
   - 当前 active/project.yaml 被保存为 projects/ 下最新快照
   - 目标项目快照被加载到 active/project.yaml
   - task.yaml 重置为新项目上下文
   - 切换事件写入 events/<project>.log
3. 用新项目状态重新输出恢复摘要

## 注意

- 不要输出完整文件内容，只输出压缩摘要
- 如果 project.yaml 的 status 是 "completed" 且当前 task 为空，提示 "上次项目已完成，有什么新任务？"
- events/ 目录下文件不直接加载，只在用户问"之前发生过什么"时读取
- 保留问题在 open_questions 里，用户选择接续时先问这些问题
- global.yaml 永远跨项目共享，不因项目切换而被覆盖

## 参考文档

- `state-lifecycle-model.md` — State 生命周期架构原则：Snapshot ≠ Backup、三文件模型、snapshot 元数据、state-switch 流程
- `state-reality-drift.md` — 状态现实漂移的模式、检测信号和三步骤协调流程
- `model-independent-continuity-verification.md` — 模型无关连续性验证协议