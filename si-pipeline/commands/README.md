# si-pipeline/commands — slash command 事实源

本目录存放 fork 的自定义 slash command **唯一事实源**。

## 安装(首次)

```bash
cp smart-illustrator-minimax.md ~/.claude/commands/
```

Claude Code 从 `~/.claude/commands/` 加载用户级命令;仓库内版本用于版本管理与回溯。

## 同步规则

- **改命令 = 改本文件** → commit/push
- 改完**必须**同步副本:`cp smart-illustrator-minimax.md ~/.claude/commands/smart-illustrator-minimax.md`
- 两个位置内容不一致时,以仓库为准(仓库是源)

## 设计原则(钉死)

1. **零侵入**:不改作者任何文件(SKILL.md / scripts/*.ts / styles/*.md / references/*.md)
2. **只复用 + 添加**:复用作者 mermaid-export.ts / excalidraw-export.ts / style-*.md / excalidraw-guide.md(只读调用);唯一替换点 = gemini 接口 → 本地 minimax 脚本(`~/图片/minimax_t2i.py`,用户未订阅 gemini 生图)
3. **产物只写文章目录**:`{stem}-image.md` / `{stem}-image-NN.png` / `{stem}.si-plan.json` / `*.mmd` / `*.excalidraw`

## 文件

| 文件 | 说明 |
|---|---|
| `smart-illustrator-minimax.md` | slash command 本体(v3,550 行,4 路径早退分支) |
| `.gitkeep` | 目录占位(作者原) |
