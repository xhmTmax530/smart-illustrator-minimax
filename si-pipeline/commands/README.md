# si-pipeline/commands — slash command 事实源

本目录存放 fork 的自定义 slash command **唯一事实源**。

## 安装(首次)

```bash
cp smart-illustrator-minimax.md ~/.claude/commands/
```

Claude Code 从 `~/.claude/commands/` 加载用户级命令;仓库内版本用于版本管理与回溯。

## 同步规则(双向)

- 仓库内文件与 `~/.claude/commands/smart-illustrator-minimax.md` **互为备份**
- 任意一边修改后**必须**回写另一边:
  - 改了 `si-pipeline/commands/` → `cp smart-illustrator-minimax.md ~/.claude/commands/` → commit/push
  - 改了 `~/.claude/commands/` → 同步回仓库 → commit/push
- 两个位置内容不一致时,**以仓库为准**(仓库是版本管理与回溯的事实源)

## 设计原则(钉死)

1. **零侵入**:不改作者任何文件(SKILL.md / scripts/*.ts / styles/*.md / references/*.md)
2. **只复用 + 添加**:复用作者 mermaid-export.ts / excalidraw-export.ts / style-*.md / excalidraw-guide.md(只读调用);唯一替换点 = gemini 接口 → 本地 minimax 脚本(`~/图片/minimax_t2i.py`,用户未订阅 gemini 生图)
3. **产物只写文章目录**:`{stem}-image.md`(副本,base64 内嵌自包含)/ `images/{stem}-image-NN.png` / `{stem}.si-plan.json` / `*.mmd` / `*.excalidraw`

## 文件

| 文件 | 说明 |
|---|---|
| `smart-illustrator-minimax.md` | slash command 本体(v3.2,639 行,4 路径早退分支;base64 内嵌插图) |
| `.gitkeep` | 目录占位(作者原) |

## 关联目录

| 目录 | 说明 |
|---|---|
| `../skills/si-regen/` | si-regen 全局 skill 事实源:SKILL.md(重生早退)+ `schema/si-plan-v3.sample.json`(manifest 样本)+ `schema/README.md` + `scripts/validate-manifest.sh`(schema 校验脚本)。安装:`cp -r ../skills/si-regen ~/.claude/skills/` |
| `../FORK_NOTES.md` | fork 差异说明与设计决策记录(v3.2 见 Section 12) |
