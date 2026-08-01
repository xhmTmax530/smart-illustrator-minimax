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

> `--regen N`:文件名不变 → `![]({stem}-image-03.png)` 自动指向新图,无需改副本。

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

### 早退分支模式（manifest 驱动）

manifest（`{stem}.si-plan.json`，**文章目录**，与 `{stem}-image.md` 平级）是早退分支的**唯一控制平面**。通过 Step 0 先检测 manifest 是否存在，再按 flag 分流到 4 条路径。Step 0 第一步强制 `cd "$(dirname "$ARTICLE")"`，后续所有路径在文章目录解析。

#### 四条路径

| 路径 | 触发条件 | 行为 |
|------|---------|------|
| **路径 1** | manifest 存在 + `--regen N` | 只覆盖第 N 张 PNG，**零不动**（不读原文、不 cp 副本、不 Edit 副本） |
| **路径 2** | manifest 存在 + `--force` | 全量遍历 manifest，重生所有 PNG（源文件缺失报错跳过，不做 content 重建） |
| **路径 3** | manifest 存在 + `-content "..."` | 自然语言打分匹配，唯一最高分 → 转路径 1；并列/零分 → 报错 |
| **路径 4** | manifest 不存在 + 无 flag / 无 flag + 原文已变 / 「复用」 | 默认全流程（Read → 心跳分析 → 写 manifest → 生成 → cp 副本插图）；「复用」分支跳过 LLM 重新分析，沿用现有 manifest 执行 skip-existing |

**关键规则（v3）**：
- **manifest 不存在 + 任一 flag（`--force`/`--regen`/`-content`）→ 报错退出**："manifest 不存在({path}),请先跑一次不带 flag 的完整流程生成"。绝不静默回退路径 4。
- 旧版 manifest（v1/v2，含 /tmp 旧位置）→ 显式拒绝："旧版 manifest({path}),请重跑完整流程升级为 v3"。
- manifest 损坏（JSON 解析失败）→ "manifest 损坏({path}),请删除后重跑完整流程"。
- 原文已修改（mtime/size 不符）→ 路径 1/2/3 警告"原文已修改({date}),图片可能过时;确认继续则手动回复继续"。
- **无 flag + manifest 存在 + 原文未变** → 展示 manifest 摘要表（编号/引擎/源文件/status），询问**「复用」（推荐,幂等）还是「重新分析」**。原文已变 → 直接重新分析（带提示）。
- **格式统一（仅 gemini/minimax）**：minimax 产物实测是 JPEG 编码(1280×720)，mv 后必须 `file` 检测 + ffmpeg 转码为真 PNG；ffmpeg 缺失 → 警告，产物保持 JPEG 编码。mermaid/excalidraw 输出本为真 PNG，无需处理。

#### manifest v3 schema

```json
{
  "_meta": {
    "schema": "si-minimax/v3",
    "source": "<文章规范化绝对路径>",
    "source_mtime": "<stat -c %Y>",
    "source_size": "<stat -c %s>",
    "produced_at": "<ISO8601>",
    "total": <N>,
    "by_engine": { "gemini": <M>, "excalidraw": <E>, "mermaid": <R> }
  },
  "pictures": [
    {
      "id": 1,
      "engine": "mermaid",
      "topic": "...",
      "content": "...",
      "anchor": "<段落描述>",
      "source_file": "<.mmd/.excalidraw 路径,相对文章目录>",
      "source_prompt": "<gemini 完整 prompt>",
      "status": "planned|generated|failed"
    }
  ]
}
```

| 字段 | 用途 | 适用引擎 |
|------|------|---------|
| `anchor` | 段落锚点描述（-content 评分） | 全部 |
| `source_file` | mermaid/excalidraw 源文件路径（相对文章目录），重生时直接导出 PNG | mermaid / excalidraw |
| `source_prompt` | gemini/minimax 原始 prompt，重生时还原 | gemini |
| `status` | 执行状态，每张图执行后更新，报告表格展示 | 全部 |
| `_meta.source_mtime/source_size` | 陈旧检测：原文修改后警告 | 全部 |

#### 零不动原则

路径 1/2/3 绝对不做：
- ❌ Read 原文
- ❌ cp 副本
- ❌ Edit 副本
- ❌ LLM 重新分析位置

副本里的 `![]({stem}-image-NN.png)` 引用**始终指向同名 PNG**，覆盖后自动生效，无需修改副本。

## 工作流(与作者 spec 对齐)

```
用户: /smart-illustrator-minimax file.md
  ↓
Claude Code 读 SKILL.md 的启发式规则
  ↓
Step 1 读原文
Step 2 心跳分析(识别 3-5 个配图位置 + 选 engine)
Step 3 (必做) 写 manifest 到文章目录 {stem}.si-plan.json (v3 schema,写后 jq -e 校验)
Step 4 循环每张图:
        gemini     → minimax_t2i.py + ffmpeg 转码 → {stem}-image-NN.png
        mermaid    → 作者 mermaid-export   → {stem}-image-NN.png
        excalidraw → 作者 excalidraw-export → {stem}-image-NN.png
Step 5 复制原文为 {stem}-image.md,在心跳记的位置插 ![](...)(副本已存在 → diff 摘要 → 询问覆盖)
Step 6 报告产物
```

**没有中间状态机**,没有占位符回填,没有 `--prompt-only` 复制粘贴。Claude 心跳记忆 = 状态机。

## 与原版对比

| 维度 | 原版 `/smart-illustrator` | 本命令 |
|---|---|---|
| 创意图 | Gemini API | minimax_t2i.py(本地,调用契约实测:位置 prompt + `--out` 目录 + `--ratio 16:9`);产物为 JPEG 编码,统一转码为真 PNG(ffmpeg,可选依赖) |
| mermaid | `mermaid-export.ts` | ✅ 完全复用,不改 |
| excalidraw | `excalidraw-export.ts` | ✅ 完全复用,不改 |
| PNG 命名 | `{stem}-image-NN.png` | ✅ 沿用(文章目录顶层,v3 起) |
| 插入机制 | Claude 心跳 | ✅ 沿用(同一机制) |
| 作者代码改动 | — | **0 行** |

## manifest(必做,双角色)

`{stem}.si-plan.json`(文章目录,与 `{stem}-image.md` 平级,v3 schema)——**快照 + 控制平面双角色**:路径 4 必写(写后 `jq -e .` 校验),路径 1/2/3 只读。生命周期与文章一致(随目录备份/移动),重启不丢。

## 必备依赖

- Bun(运行作者 ts 脚本)
- Mermaid CLI(`npm i -g @mermaid-js/mermaid-cli`)
- Playwright + Firefox(Excalidraw 导出依赖)
- minimax 脚本 + `MINIMAX_IMAGE_API_KEY`(或回落 `MINIMAX_API_KEY`)环境变量
- jq(路径 1/2/3 的 manifest 读取依赖)
- ffmpeg(可选,JPEG→PNG 转码:minimax 产物实测是 JPEG 编码,须转码为真 PNG;缺失时产物保持 JPEG 编码并警告)

## 非侵入承诺

- ❌ 不改 `~/.claude/skills/smart-illustrator/SKILL.md`
- ❌ 不改 `scripts/*.ts`
- ❌ 不改 `styles/*.md`
- ❌ 不改 `references/*.md`
- ❌ 不改 `{stem}.md`(原文)
- ✅ 只写:`{stem}-image.md`、`{stem}-image-*.png`(顶层)、`{chart}.mmd/.excalidraw`、`{stem}.si-plan.json`(文章目录)

## PR 策略

极简 diff,易合入上游。命令体在 `~/.claude/commands/smart-illustrator-minimax.md`,可独立 PR。