# Hermes Working State — Persistent Runtime State for Hermes Agent

> 每个 `/new` 后丢失的不是 Memory，而是 Working State。

## What

Hermes Working State 是一个轻量级 Agent Runtime State 层。它解决了 Hermes Agent （以及任何类 CLI Agent 框架）的核心架构缺失：**跨会话工作连续性**。

每次 `/new` 清除的是 LLM 上下文窗口，但**不需要**清除执行状态。Working State 通过三个持久化文件 + 两个 skill，让 Agent 在新会话中自动恢复完整的项目上下文、任务进度、决策记录和阻塞点。

## Architecture

```
~/.hermes/state/
├── global.yaml                     ← 跨项目偏好（永不被切换覆盖）
├── active/
│   ├── project.yaml                 ← 当前激活的项目状态
│   └── task.yaml                    ← 当前任务执行上下文
├── projects/
│   └── <sanitized-name>.yaml       ← 每项目一个快照文件（含元数据）
├── events/
│   ├── global.log                  ← 跨项目事件
│   └── <sanitized-name>.log        ← 每项目事件隔离
├── state-switch                    ← snapshot-save → snapshot-load 脚本
├── VERSION                         ← schema 版本标记
└── observations.log                ← 架构观察（v2.x 设计输入）
```

## Design Principles

### Snapshot ≠ Backup

| | Backup | Snapshot |
|---|---|---|
| 思维 | 运维 | Runtime |
| 生成 | 被动创建 | 主动生成 |
| 历史 | 保留多版本 | 覆盖更新 |
| 用途 | 防误操作 | Runtime 恢复依据 |
| 角色 | 存档 | state-switch 加载源 |

### Three-Layer Isolation

1. **Global** (`global.yaml`) — 跨项目偏好、用户纠正历史、重要路径。永不因项目切换而修改。
2. **Project** (`project.yaml` + `projects/` 快照) — 每个项目的独立状态。切换时 snapshot-save → snapshot-load，互不污染。
3. **Task** (`task.yaml`) — 当前执行上下文。项目切换时重置。

### Event Log as Source of Truth

`events/*.log` 是 append-only 的不可变事件流。它记录"事实发生了什么"，不被后续的 state 覆盖影响。当发生 State Reality Drift 时，先写事件日志，再更新 state，最后更新快照。

## Validation Status

| Test | What It Validates | Status |
|------|-------------------|--------|
| Test 1 | Session Recovery — `/new` 后恢复完整上下文 | ✅ |
| Test 2 | Project Isolation — 多项目互不污染 | ✅ |
| Test 2.5 / Cold Start | Snapshot Lifecycle — 最新快照正确恢复 | ✅ |
| Test 3 | Model-Independent Recovery — 不同 LLM 恢复同一状态 | ✅ |

**核心结论已闭环：** 连续性来自 Runtime State，不是来自 LLM 上下文窗口。

验证协议详见 [docs/model-independent-continuity-verification.md](docs/model-independent-continuity-verification.md)。

## Quick Start

### For any Hermes bot (金 / 水 / 火 / 土)

```bash
bash <(curl -sL https://raw.githubusercontent.com/angelife/hermes-working-state/main/setup.sh)
```

或者 clone 后手动执行：

```bash
git clone https://github.com/angelife/hermes-working-state.git ~/hermes-working-state
cd ~/hermes-working-state
bash setup.sh
```

### What the setup does

1. 创建 `~/.hermes/state/` 目录结构（global / active / projects / events）
2. 安装 `state-save` 和 `state-restore` skills 到 `~/.hermes/skills/`
3. 安装 `state-switch` 脚本
4. 将 SOUL.md 集成指令写入说明书（默认不修改现有 SOUL.md）
5. 创建 VERSION marker

### After setup

在 SOUL.md 的末尾（紧接身份锚定之后）添加：

```markdown
# Working State — 跨会话连续性
按下述顺序加载 state 状态：
1. 加载 state-restore skill
2. 按 state-restore 流程恢复项目状态
3. 恢复后告知用户并等待指令
```

然后在新会话中输入"继续"即可验证。

## Files

```
hermes-working-state/
├── README.md                    ← 本文档
├── setup.sh                     ← 一键部署脚本
├── VERSION                      ← schema 版本标记（项目级）
├── templates/
│   ├── global.yaml              ← 跨项目偏好模板
│   ├── active/
│   │   ├── project.yaml         ← 项目状态模板
│   │   └── task.yaml            ← 任务状态模板
│   └── events/
│       └── global.log           ← 空事件日志
├── skills/
│   ├── state-save/
│   │   └── SKILL.md             ← 保存 skill
│   └── state-restore/
│       ├── SKILL.md             ← 恢复 skill
│       └── scripts/
│           └── state-switch.sh  ← 项目切换脚本
├── docs/
│   ├── state-lifecycle-model.md               ← Snapshot ≠ Backup 架构说明
│   ├── state-reality-drift.md                 ← 状态漂移检测与修复
│   └── model-independent-continuity-verification.md  ← 验证协议
├── reference/
│   └── SOUL_INTEGRATION_GUIDE.md   ← SOUL.md 集成指南
└── CHANGELOG.md                   ← 变更日志
```

## For Bot Fleet Coordination

This system handles **per-bot continuity** (individual bot remembering its state across sessions).

For **fleet coordination** (multiple bots sharing a task board), see:
[hermes-multi-bot-todo](https://github.com/angelife/hermes-multi-bot-todo)

The two systems are complementary:

```
fleet coordination  ← hermes-multi-bot-todo (谁做什么)
per-bot continuity  ← hermes-working-state (我记得什么)
```