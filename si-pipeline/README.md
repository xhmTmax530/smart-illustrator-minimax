# si-pipeline — smart-illustrator 的 minimax 替代层

本目录是 `smart-illustrator` 的**非侵入式极简增强**:不改作者任何现有文件,只新增一条 slash command,把 Gemini API 替换为本地 minimax,完全复用作者的 mermaid/excalidraw 脚本。

## 一条命令搞定一切

```bash
/smart-illustrator-minimax "<article.md>" [extra hints...]
```

示例:
```bash
/smart-illustrator-minimax "~/文档/技术文章.md"
/smart-illustrator-minimax "~/文档/技术文章.md" "重点配架构图,少隐喻"
```

### 单图重生 / 强制重来

```bash
# 只重生第 3 张图(其余跳过)
/smart-illustrator-minimax "~/文档/技术文章.md" --regen 3

# 重生第 2 和第 5 张
/smart-illustrator-minimax "~/文档/技术文章.md" --regen 2 --regen 5

# 全部重来
/smart-illustrator-minimax "~/文档/技术文章.md" --force

# --force 与 extra hints 可同时用
/smart-illustrator-minimax "~/文档/技术文章.md" --force "少隐喻,全用 mermaid"
```

> `--regen N`:文件名不变 → `![](images/{stem}-img-03.png)` 自动指向新图,无需改副本。

> ⚠ 路径含空格必须加引号(传给 Claude 的 `$ARGUMENTS` 按空格切分)

### 自然语言定位（-content）

```bash
# 用自然语言描述想重生的图（按 topic/anchor/content 自动匹配）
/smart-illustrator-minimax "~/文档/技术文章.md" -content "MVC 路由时序图"

/smart-illustrator-minimax "~/文档/技术文章.md" -content "AOP 那张"

/smart-illustrator-minimax "~/文档/技术文章.md" -content "第 4.2 节那张"
```

**匹配规则**：
- 关键词命中（topic/anchor/content 含描述词）→ +10
- 章节锚点命中（描述含「第 N 节」）→ +5
- 类型命中（描述含「流程图/时序图/对比图/架构图/概念图/隐喻图」）→ +3

**三种结果**：
- 最高分唯一 → 自动选中并重生
- 并列 ≥ 2 → 报错列前 3 候选，要求用 `--regen <id>` 消歧
- 全 0 分 → 报错列所有 picture 的 id + topic + anchor

> `-content` 与 `--force` 互斥。`-content` 与 `--regen N` 同传时 `--regen N` 优先（显式 id 更精确）。

## 工作流(与作者 spec 对齐)

```
用户: /smart-illustrator-minimax file.md
  ↓
Claude Code 读 SKILL.md 的启发式规则
  ↓
Step 1 读原文
Step 2 心跳分析(识别 3-5 个配图位置 + 选 engine)
Step 3 (可选) 写规划快照到 /tmp/si-plan-{stem}.json
Step 4 循环每张图:
        gemini     → minimax_t2i.py        → PNG
        mermaid    → 作者 mermaid-export   → PNG
        excalidraw → 作者 excalidraw-export → PNG
Step 5 复制原文为 {stem}-image.md,在心跳记的位置插 ![](...)
Step 6 报告产物
```

**没有中间状态机**,没有占位符回填,没有 `--prompt-only` 复制粘贴。Claude 心跳记忆 = 状态机。

## 与原版对比

| 维度 | 原版 `/smart-illustrator` | 本命令 |
|---|---|---|
| 创意图 | Gemini API | minimax_t2i.py(本地) |
| mermaid | `mermaid-export.ts` | ✅ 完全复用,不改 |
| excalidraw | `excalidraw-export.ts` | ✅ 完全复用,不改 |
| PNG 命名 | `{stem}-image-NN.png` | ✅ 沿用 |
| 插入机制 | Claude 心跳 | ✅ 沿用(同一机制) |
| 作者代码改动 | — | **0 行** |

## 唯一新增的产物(可选)

`/tmp/si-plan-{stem}.json` — 规划快照,用户可 `cat` 检查。
**不参与控制流**,纯快照。心跳里的信息才是状态。

## 必备依赖

- Bun(运行作者 ts 脚本)
- Mermaid CLI(`npm i -g @mermaid-js/mermaid-cli`)
- Playwright + Firefox(Excalidraw 导出依赖)
- minimax 脚本 + `MINIMAX_API_KEY` 环境变量

## 非侵入承诺

- ❌ 不改 `~/.claude/skills/smart-illustrator/SKILL.md`
- ❌ 不改 `scripts/*.ts`
- ❌ 不改 `styles/*.md`
- ❌ 不改 `references/*.md`
- ❌ 不改 `{stem}.md`(原文)
- ✅ 只写:`{stem}-image.md`、`images/*.{png}`、`{chart}.mmd/.excalidraw`、`/tmp/si-plan-*.json`

## PR 策略

极简 diff,易合入上游。命令体在 `~/.claude/commands/smart-illustrator-minimax.md`,可独立 PR。