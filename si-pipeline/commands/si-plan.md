---
description: smart-illustrator Stage 1 — 生成文章副本 + 插入占位符 + 输出 JSON 清单(等待人工确认后,再跑 /si-image 与 /si-chart)
argument-hint: <file.md> ["额外提示词"]
allowed-tools: Read Write Edit Bash Glob
---

# /si-plan — Stage 1:占位符驱动半自动配图(规划)

> 非侵入式增强:不改作者任何现有文件,只在 `{stem}-image.md` 副本上工作,产物为 JSON 清单(事实源)。

## 输入

`$ARGUMENTS` = `<file.md> [额外提示词]`

- 第 1 段(必填):文章绝对或相对路径(`~` 自动展开)
- 第 2 段起(可选):用户偏好(如"重点配架构图,少隐喻"),作为 LLM 选位偏好

## 全局约束(钉死,违反即错)

1. **原文永不动**:复制为 `{stem}-image.md`,所有写入副本。
2. **占位符**:`<!-- IMAGE:NNN -->`(3 位零填充;NNN 从 001 起;**只含编号**,不写引擎/类型)
3. **引擎枚举**:`gemini` | `excalidraw` | `mermaid`(严格作者 `--engine` 值,不自定义)
4. **类型(可选)**:作者类型表 — `process|architecture|sequence|mindmap|state|concept|comparison|data|scene|metaphor|cover`
5. **优先级**:`Gemini > Excalidraw > Mermaid`(作者硬规则)
6. **数量**:短文(< 1000 字)1-2,中篇(1000-3000)2-4,长文(> 3000)4-6,教程每主步骤 1 张
7. **清单**:`{stem}.illus.json` 紧挨原文
8. **Style 字段**:从 `{skill_root}/styles/style-{name}.md` **完整拷贝**(`style-light.md` 默认),不简化
9. **Code 字段**:Stage 1 一律 `""`(Stage 3 才填)
10. **Status**:Stage 1 全部为 `planned`
11. **filename 字段**:`gemini`/`excalidraw` → `images/{stem}-img-NNN.png`;`mermaid` 嵌码 → `""`

## 执行步骤

### 1. 参数解析与文件准备

- 切 `$ARGUMENTS`,得 `file_path` 与 `extra_prompt`(可能空)
- 若 `file_path` 以 `~/` 起,用 `Bash` 执行 `echo ~` 展开 home 后重拼路径
- `Glob` 校验路径存在;否则报错并提示正确路径
- 用 `Bash` 执行 `cp "$file_path" "${file_path%.md}-image.md"`,得副本路径 `copy_path`
- 若副本已存在(重跑场景):`Bash` `git diff --quiet "$copy_path"`;若 exit 非 0(副本被改过),**询问用户**是否覆盖

### 2. 读原文 + 副本

- `Read` 原文(分析用)
- `Read` 副本(后续插入用;若用户改过副本,以副本为基准插入)

### 3. 选位 + 选引擎 + 选类型(LLM 决策)

基于原文结构 + 额外提示词,按作者优先级判定:

| 内容特征 | engine | type |
|---|---|---|
| 隐喻/情感/封面/无法图表化 | `gemini` | `metaphor` / `scene` / `cover` |
| 手绘概念/对比/简单流程(≤8 节点)/关系图 | `excalidraw` | `concept` / `comparison` |
| 复杂流程(>8 节点)/多层架构/时序/决策树 | `mermaid` | `process` / `architecture` / `sequence` / `mindmap` / `state` |

每处给出:
- `id`(从 1 起,递增)
- `engine`、`type`
- 拟插入位置:用原文前 30 字符 + 行号(供检查点人类复核)
- `topic`(主题方向,沿用作者 slide 示例措辞,如"流程概览"/"核心概念")
- `content`(自然语言描述,Stage 1 起草;Stage 2/3 据此渲染)

### 4. 插入占位符(`Edit` 副本)

对每处,在副本目标段落的**段末空行前**插入:

```text
<!-- IMAGE:NNN -->
```

**就近原则**:不破坏段落结构;插在目标段末空行之前,或紧随小标题之后(短章节首)。

**幂等**:对每处 `Edit` 前先 `Read` 副本对应行;若 `<!-- IMAGE:NNN -->` 已存在,跳过并复用其编号。

### 5. 读 style(必须用作者原文,不简化)

- 默认路径:`{skill_root}/styles/style-light.md`(`skill_root` = 本 slash command 解析到的仓库根,即 `~/.claude/skills/smart-illustrator`)
- 若用户传 `--style <name>`,改读 `style-{name}.md`
- `Read` 该文件全文,**完整内容**塞到 JSON 的 `style` 字段

### 6. 生成 `{stem}.illus.json`

按以下 schema 构造(每个 picture 字段都填;`code` 一律 `""`):

```jsonc
{
  "instruction": "请为我绘制 N 张图片(generate N images)。你是一位「信息图绘制者」。请逐条执行 pictures 数组:每个 id 对应 1 张独立的配图,严禁合并,严禁只输出文字描述。",
  "batch_rules": {
    "total": N,
    "one_item_one_image": true,
    "aspect_ratio": "16:9",
    "do_not_merge": true
  },
  "fallback": "如果无法一次生成全部图片:请输出 N 条独立的单图绘图指令(编号 1-N),每条可单独执行,必须包含完整 style 和水印要求。",
  "style": "<完整 style 文件内容,从 styles/style-light.md 拷贝>",
  "pictures": [
    {
      "id": 1,
      "topic": "<主题方向>",
      "content": "<自然语言描述,Stage 1 起草>",
      "engine": "gemini|excalidraw|mermaid",
      "type": "<作者类型表枚举>",
      "placeholder": "<!-- IMAGE:001 -->",
      "filename": "images/{stem}-img-001.png",  // mermaid 嵌码模式时为 ""
      "code": "",
      "status": "planned"
    }
    // ... 共 N 项
  ]
}
```

`{stem}` = 原文路径去掉目录与 `.md` 后缀(如 `/path/to/foo.md` → `foo`)。

`filename` 字段规则:
- `gemini` / `excalidraw`:`images/{stem}-img-NNN.png`
- `mermaid` 嵌代码块模式:留 `""`(不生成 PNG 文件)

### 7. 写入 JSON

- `Write` 工具写 `{stem}.illus.json`(UTF-8,2 空格缩进,便于 diff)

### 8. 检查点(必须人工确认)

向用户打印以下表格 + 路径,**不直接进入 Stage 2/3**:

```text
[Stage 1 检查点]
─────────────────────────────
编号 │ 引擎      │ 类型        │ 拟插入位置(原文行号 + 前 30 字)
─────┼───────────┼─────────────┼────────────────────────────────
001  │ gemini    │ metaphor    │ L12 「本文将探讨 AI 协作的隐喻...」
002  │ mermaid   │ architecture│ L28 「Spring 容器包含三大核心...」
...

✅ 副本:{copy_path}
✅ 清单:{manifest_path}

请确认:
- 位置/数量 OK?→ 跑 /si-image 与 /si-chart
- 不 OK?→ 告诉我「改 XXX:YYY→ZZZ」(我会重选并重生成)
```

## 失败处理

| 情况 | 应对 |
|---|---|
| 路径不存在 | 报错并提示正确路径格式 |
| 副本已存在且被改过 | 询问是否覆盖(显示 diff 摘要) |
| 找不到 style 文件 | 列出 `styles/` 下所有 `style-*.md`,请用户选 |
| 文章极短(< 300 字纯列表) | 仍生成 1 张隐喻封面,提示用户 |
| LLM 选不出引擎 | 默认走 `mermaid` + `concept`,提示人工调整 |

## 输出文件清单

```
{stem}-image.md          # 副本(含占位符,原文不动)
{stem}.illus.json        # 清单(事实源)
```

## 后续衔接

- `/si-image {manifest}` — Stage 2 跑 gemini 项(minimax 后端)
- `/si-chart {manifest}` — Stage 3 跑 mermaid/excalidraw 项(作者引擎)
- `/si-all {manifest}` — 一步跑完 Stage 2+3
