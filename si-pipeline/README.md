# si-pipeline — 占位符驱动半自动配图管线

本目录是 `smart-illustrator` 的**非侵入式增强层**:不改作者任何现有文件,只在 `commands/` 下新增 slash command,配合作者 `styles/`、`scripts/` 使用。

## 安装

```bash
cd ~/.claude/skills/smart-illustrator
# 命令体软链到用户级 ~/.claude/commands/(改动自动同步)
ln -sf "$(pwd)/si-pipeline/commands/si-plan.md" ~/.claude/commands/si-plan.md
```

## 命令清单

| 命令 | 阶段 | 状态 | 说明 |
|---|---|---|---|
| `/si-plan` | Stage 1 | ✅ 已交付 | 复制 + 占位符 + 清单 |
| `/si-image` | Stage 2 | 📋 计划中 | 创意图(minimax 后端) |
| `/si-chart` | Stage 3 | 📋 计划中 | 结构图(作者引擎 mermaid/excalidraw) |
| `/si-all` | Stage 2+3 | 📋 计划中 | 全部跑完回填 |

## 设计文档

- Spec: `../docs/superpowers/specs/2026-07-17-placeholder-pipeline-design.md`
- Stage 1 实现计划: `../docs/superpowers/plans/2026-07-17-stage1-si-plan.md`

## PR 策略

每阶段独立目录、可独立合入上游;minimax 后端本地保留(用 `--backend` 切换)。
