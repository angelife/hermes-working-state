#!/bin/bash
# setup.sh — One-command deploy of Hermes Working State for any Hermes bot
# Usage: bash <(curl -sL https://raw.githubusercontent.com/angelife/hermes-working-state/main/setup.sh)
#   or: bash setup.sh
#
# This script:
#   1. Creates ~/.hermes/state/ directory structure
#   2. Installs state-save and state-restore skills
#   3. Installs state-switch script
#   4. Writes SOUL.md integration instructions
#   5. Creates VERSION marker

set -e

HERMES_HOME="${HOME}/.hermes"
STATE_DIR="${HERMES_HOME}/state"
SKILLS_DIR="${HERMES_HOME}/skills/workflow"
REPO_URL="https://raw.githubusercontent.com/angelife/hermes-working-state/main"

echo "=== Hermes Working State — Setup ==="
echo ""

# Step 1: Create state directory structure
echo "[1/5] Creating state directory structure..."
mkdir -p "${STATE_DIR}/active"
mkdir -p "${STATE_DIR}/projects"
mkdir -p "${STATE_DIR}/events"

# Step 2: Write state templates if not exist
echo "[2/5] Writing state templates..."

if [ ! -f "${STATE_DIR}/global.yaml" ]; then
  curl -sL "${REPO_URL}/templates/global.yaml" -o "${STATE_DIR}/global.yaml"
  echo "  → global.yaml created"
else
  echo "  → global.yaml exists, skipping"
fi

if [ ! -f "${STATE_DIR}/active/project.yaml" ]; then
  curl -sL "${REPO_URL}/templates/active/project.yaml" -o "${STATE_DIR}/active/project.yaml"
  echo "  → active/project.yaml created"
else
  echo "  → active/project.yaml exists, skipping"
fi

if [ ! -f "${STATE_DIR}/active/task.yaml" ]; then
  curl -sL "${REPO_URL}/templates/active/task.yaml" -o "${STATE_DIR}/active/task.yaml"
  echo "  → active/task.yaml created"
else
  echo "  → active/task.yaml exists, skipping"
fi

# events/global.log — start empty, only if not exists
if [ ! -f "${STATE_DIR}/events/global.log" ]; then
  touch "${STATE_DIR}/events/global.log"
  echo "  → events/global.log created"
fi

# VERSION marker
if [ ! -f "${STATE_DIR}/VERSION" ]; then
  curl -sL "${REPO_URL}/VERSION" -o "${STATE_DIR}/VERSION"
  echo "  → VERSION created"
else
  echo "  → VERSION exists, skipping"
fi

# Step 3: Install skills
echo "[3/5] Installing skills..."

SKILL_SAVE_DIR="${SKILLS_DIR}/state-save"
SKILL_RESTORE_DIR="${SKILLS_DIR}/state-restore"
mkdir -p "${SKILL_SAVE_DIR}"
mkdir -p "${SKILL_RESTORE_DIR}"

# state-save skill
if [ ! -f "${SKILL_SAVE_DIR}/SKILL.md" ]; then
  curl -sL "${REPO_URL}/skills/state-save/SKILL.md" -o "${SKILL_SAVE_DIR}/SKILL.md"
  echo "  → state-save skill installed"
else
  echo "  → state-save skill exists, skipping"
fi

# state-restore skill
if [ ! -f "${SKILL_RESTORE_DIR}/SKILL.md" ]; then
  curl -sL "${REPO_URL}/skills/state-restore/SKILL.md" -o "${SKILL_RESTORE_DIR}/SKILL.md"
  echo "  → state-restore skill installed"
else
  echo "  → state-restore skill exists, skipping"
fi

# state-restore reference docs
RESTORE_DOC_DIR="${SKILL_RESTORE_DIR}/references"
mkdir -p "${RESTORE_DOC_DIR}"

for doc in state-lifecycle-model.md state-reality-drift.md model-independent-continuity-verification.md; do
  if [ ! -f "${RESTORE_DOC_DIR}/${doc}" ]; then
    curl -sL "${REPO_URL}/docs/${doc}" -o "${RESTORE_DOC_DIR}/${doc}"
    echo "  → ${doc} installed"
  else
    echo "  → ${doc} exists, skipping"
  fi
done

# Step 4: Install state-switch script
echo "[4/5] Installing state-switch script..."

SWITCH_SCRIPT="${STATE_DIR}/state-switch"
mkdir -p "${HERMES_HOME}/state"
if [ ! -f "${SWITCH_SCRIPT}" ]; then
  curl -sL "${REPO_URL}/skills/state-restore/scripts/state-switch.sh" -o "${SWITCH_SCRIPT}"
  chmod +x "${SWITCH_SCRIPT}"
  echo "  → state-switch installed at ${SWITCH_SCRIPT}"
else
  echo "  → state-switch exists, skipping"
fi

# Write integration guide to reference/
WRITE_DIR="${HERMES_HOME}/state"
cat > "${WRITE_DIR}/SOUL_INTEGRATION.md" << 'GUIDE'
# SOUL.md Integration Guide — Hermes Working State

## Add to SOUL.md

在身份锚定之后，添加以下内容：

```markdown
## Working State — 跨会话连续性

按下述顺序加载 state 状态：

1. 加载 state-restore skill（`skill_view(name="state-restore")`）
2. 按 state-restore 流程恢复当前项目状态
3. 恢复后告知用户并等待指令
```

## Required: Update identity anchor

确保身份锚定中有调用 `state-restore` 的指令，例如：

```
新会话启动时，立即加载 state-restore skill 检查 ~/.hermes/state/ 下的 Working State，
恢复上次的目标、进度和决策。会话结束前，确保调用 state-save skill 保存当前状态到 state 文件。
这是保持跨会话连续性的唯一机制。
```

## Verify

在新会话中输入 `继续`，应自动恢复 Working State。

如果未触发：检查 SOUL.md 中是否引用了 `state-restore` skill 名称，以及 skill 是否在 `~/.hermes/skills/workflow/state-restore/` 下。
GUIDE
echo "  → SOUL_INTEGRATION.md written"

# Step 5: Final report
echo ""
echo "[5/5] Done!"
echo ""
echo "=== Install Summary ==="
echo "State dir:     ${STATE_DIR}/"
echo "Skills:        ${SKILL_SAVE_DIR}/  ${SKILL_RESTORE_DIR}/"
echo "Switch script: ${SWITCH_SCRIPT}"
echo ""
echo "Next steps:"
echo "  1. Add Working State integration to ~/.hermes/SOUL.md"
echo "  2. Start a new session and type '继续' to verify"
echo "  3. Run 'state-save' at end of session to persist state"
echo ""
echo "See ${STATE_DIR}/SOUL_INTEGRATION.md for SOUL.md instructions."
echo "Fire away."