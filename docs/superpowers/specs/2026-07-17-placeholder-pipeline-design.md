# 设计文档:smart-illustrator 半自动配图管线(占位符驱动)

- 日期:2026-07-17
- 状态:已批准(等待 spec 复核)
- 分支:`feat/placeholder-pipeline`
- 基线:axtonliu/smart-illustrator @ main

## 背景与目标

作者的 `smart-illustrator` 在文章模式下没有"占位符 / 持久化清单 / 可续跑"概念:
Claude 读文章 → 自己选 3-5 处 → 直接写新文件 `article-image.md` 把图插进去。
这带来两个痛点:配图位置不可复核、生成后无法分阶段/断点续跑、无法人工逐图审。

本项目在**不修改作者任何脚本**的前提下,新增一层**占位符驱动、JSON 清单为事实源、
人工逐阶段确认**的半自动管线,补上这个空缺,并保持可 PR 上游。

## 已锁定的地基决策

1. **占位符职责**:大模型决定插图位置 + 大模型写入占位符(贴合作者"模型选位"意图)。
2. **写入目标**:一律写副本 `{stem}-image.md`,原文 `{stem}.md` 永不修改(遵作者硬规则)。
3. **清单 schema**:扩展作者 unified 格式(与 `batch-generate.ts` 兼容,可 PR)。
4. **交付节奏**:分阶段交付,Stage 1 先真机验证(Spring 测试文档),再 2、再 3;
   每阶段独立 spec→plan→实现;**阶段间设检查点,会话将满则压缩后再续**。

## 总原则

- **非侵入**:不改作者 `scripts/*`、`SKILL.md`、`styles/*`;只**调用**作者
  `mermaid-export.ts` / `excalidraw-export.ts` 与用户已有 `minimax_t2i.py`。
- **原文永不动**:所有写入发生在副本 `{stem}-image.md`。
- **JSON 清单 = 唯一事实源**:占位符只带编号;类型/文件名/状态只存 JSON,避免两处漂移。
- **style 不自编**:`style` 字段从作者 `styles/style-*.md` 读取(遵作者强制规则)。
- **编排=人工回合制**(skill+command);仅 Stage 2 批量生图用 subagent 并行;
  不用 Workflow / agentteam(与人工审图流程冲突)。

## 命名(硬编码)

| 项 | 命名 |
|---|---|
| 命令族前缀 | `si-` |
| Stage 1 | `/si-plan <file.md> ["额外提示词"]` — 生成副本+占位符+清单 |
| Stage 2 | `/si-image <manifest.json> [flags]` — 创意图(minimax 后端,当 gemini) |
| Stage 3 | `/si-chart <manifest.json> [flags]` — mermaid/excalidraw(作者引擎) |
| 一键 | `/si-all <manifest.json>` — 梭哈填充全部 |
| 清单文件 | `{stem}.illus.json`(紧挨原文) |
| 占位符 | `<!-- IMAGE:001 -->`(3 位零填充,纯编号) |
| 图片文件 | `./images/{stem}-img-001.png` |

## JSON 清单 schema(扩展作者 unified)

顶层沿用作者:`instruction` / `batch_rules` / `style` / `pictures[]`。
每个 picture 在作者 `{id, topic, content}` 基础上新增 5 字段:

```jsonc
{
  "id": 1,
  "topic": "...",                          // 作者原有
  "content": "...",                        // 作者原有:生图内容/上下文描述
  "engine": "gemini",                      // 新增:gemini|excalidraw|mermaid(作者枚举)
  "placeholder": "<!-- IMAGE:001 -->",     // 新增:回填精确匹配行
  "filename": "images/{stem}-img-001.png", // 新增:固定命名
  "status": "planned"                      // 新增:planned→generated→inserted(可续跑)
}
```

**锚点字段去除**:占位符注释即唯一精确行级锚点;`content` 仅供人工校验,不作第二定位。
**插图类型枚举**:严格取作者 `--engine` 值 `gemini` / `excalidraw` / `mermaid`,不自定义。

## Stage 1 `/si-plan` 详细流程

1. 读原文 → 复制为 `{stem}-image.md`(原文不动)。
2. Claude 语义分析:选 3-5 处配图位,按作者优先级(Gemini>Excalidraw>Mermaid)判引擎。
3. 在**副本**对应行插入 `<!-- IMAGE:001 -->` … `<!-- IMAGE:00N -->`。
4. 读作者 `styles/style-light.md`(或 `--style` 对应文件)填 `style` 字段。
5. 生成 `{stem}.illus.json`。
6. **检查点**:输出占位符位置清单,人工确认;不对则对话调整。

## Stage 2 `/si-image` 骨架(创意图,minimax 后端)

- `-g`:建 `./images/`;取 `engine=="gemini"` 项;`style+topic+content` 拼 prompt →
  调 `minimax_t2i.py` → 重命名 `filename` → 落 images/ → `status=generated`。人工审图。
- `-g -full`:已生成的 gemini 图按 `placeholder` 回填副本 → `inserted`(覆盖需确认)。
- `<name.png>`:单图重生(读该项 content 重发 API,覆盖同名图,需确认)。
- `<name.png> -y`:单图回填副本原位。
- **后端可插拔**:`--backend gemini|minimax`,默认 minimax;PR 上游时切 gemini。

## Stage 3 `/si-chart` 骨架(结构图,作者引擎)

- `-mermaid -full` / `-excalidraw -full`:取对应 engine 项;Claude 生成
  `.mmd`/`.excalidraw` → 调作者 `mermaid-export.ts`/`excalidraw-export.ts` 导 PNG → 回填。
- `-content "自然语言"`:定位并重生某一处。
- 生成 Excalidraw 前**必读** `references/excalidraw-guide.md`。

## `/si-all`

按 `engine` 分派,一次跑完 Stage 2+3,全部回填,最后输出总报告。

## Agent 框架结论

- 编排:skill + 4 条 command,人工回合制。
- Stage 2 批量生图:N 张图用 subagent 并行(每 agent 一张,独立调 API)。
- 不用 Workflow / agentteam。

## PR 可行性

- 可上游:Stage 1(占位符+清单)、Stage 3(作者引擎)、回填层——纯增量。
- 不可上游:minimax 后端——设计成 `--backend` 可插拔,PR 默认 gemini。
- 每阶段独立 skill,便于分块合并。

## 待后续 plan 阶段细化

- 新管线代码/命令的落盘位置(独立 skill 目录 vs 作者仓库内)——plan 阶段定。
- `minimax_t2i.py` 的 prompt 长度上限(1500 字符)对 `style+content` 拼接的裁剪策略。
- 回填时占位符行的精确匹配/幂等(重复运行不重复插入)。
- 检查点与会话压缩的恢复协议(git spec + memory 作恢复锚点)。
