# Stage 1 (/si-plan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从 `file.md` 产出 `{stem}-image.md` 副本(含 `<!-- IMAGE:NNN -->` 占位符) + `{stem}.illus.json` 清单(状态 `planned`);人工检查点确认位置/引擎/类型后,再进入 Stage 2/3。

**Architecture:** 纯 Claude-driven skill,**无 TS 脚本**。Claude 用内置 Read/Write/Edit 工具完成:复制 → 选位 → 插入占位符 → 读作者 style 文件 → 写 JSON → 检查点。slash command `/si-plan` 触发。

**Tech Stack:** Claude Code slash command + 工具调用(Read/Write/Edit/Bash);作者 `styles/style-light.md` 作为 style 字段唯一来源。

## Global Constraints(从 spec 逐字钉死,任何任务违反即错)

- **原文永不动**:所有写入发生于副本 `{stem}-image.md`(与原文同目录)
- **占位符**:`<!-- IMAGE:NNN -->`(3 位零填充,纯编号,如 `<!-- IMAGE:001 -->`;**不含**引擎/类型信息)
- **引擎枚举**(严格作者 `--engine` 合法值,不自定义):`gemini` | `excalidraw` | `mermaid`
- **类型(可选,沿用作者 README 表)**:`process` | `architecture` | `sequence` | `mindmap` | `state` | `concept` | `comparison` | `data` | `scene` | `metaphor` | `cover`
- **引擎优先级**(作者硬规则):`Gemini > Excalidraw > Mermaid`
- **数量**(作者 README 建议,Claude 据文章长度自决):短文<1000 字 1-2 / 中篇 1000-3000 字 2-4 / 长文>3000 字 4-6 / 教程每主步骤 1 张
- **清单路径**:`{stem}.illus.json`(紧挨原文)
- **Style 字段**:从 `{skill_root}/styles/style-{name}.md` 的 ``` 代码块内**抽取操作型 Gemini System Prompt**(默认 `style-light.md`)。丢弃前后 markdown 元数据(标题、`## Gemini System Prompt` 标题、闭合 ```、末尾的 `## Prompt 模板`/`## 配图类型` 文档段)——这些是给人读的,不该塞给 Gemini。
- **JSON = 唯一事实源**:`code` 字段 Stage 1 一律 `""`(Stage 3 才填);`content` 字段为人类校验用,不作第二定位
- **状态机**:`planned` → `generated` → `inserted`(Stage 1 全部 `planned`)
- **filename 规则**:
  - `gemini` / `excalidraw` → `images/{stem}-img-NNN.png`(Stage 2/3 生成 PNG 时落盘)
  - `mermaid` 嵌代码块模式 → `""`(不生成 PNG 文件)
- **非侵入**:本计划**只新增**文件,不改作者 `SKILL.md` / `scripts/*` / `styles/*` / `references/*`
- **PR 友好**:Stage 1 完成后,目录结构独立可合入上游

## Landing Decision(解决 spec §待后续 plan 阶段细化 第 1 项)

| 文件类别 | 路径 | 说明 |
|---|---|---|
| Slash command 源 | `{skill_root}/si-pipeline/commands/si-plan.md` | 在作者仓库内,新增子目录 |
| 用户级安装 | `~/.claude/commands/si-plan.md` | **symlink** 到上面的源(改动自动同步;可改回 `cp`) |
| 测试夹具 | `{skill_root}/si-pipeline/tests/fixtures/` | 提交入库 |
| Stage 2/3/4 同理 | `si-pipeline/commands/si-{image,chart,all}.md` | 同目录后续填 |

**不**修改作者 `package.json` / `SKILL.md` / 任何已存在文件。

---

## File Structure(Stage 1 完成后)

```
smart-illustrator/si-pipeline/
├── README.md                              # 简介 + 安装/卸载
├── commands/
│   └── si-plan.md                         # /si-plan 主体(本计划核心交付物)
└── tests/
    └── fixtures/
        └── minimal-article.md             # 50 行最小测试文档

# 用户级 symlink(不提交)
~/.claude/commands/si-plan.md → .../smart-illustrator/si-pipeline/commands/si-plan.md
```

---

### Task 1: Bootstrap si-pipeline directory structure

**Files:**
- Create: `si-pipeline/README.md`
- Create: `si-pipeline/commands/.gitkeep`
- Create: `si-pipeline/tests/fixtures/.gitkeep`

- [ ] **Step 1: 创建目录骨架**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
mkdir -p si-pipeline/commands si-pipeline/tests/fixtures
```

- [ ] **Step 2: 写 README.md**

```markdown
# si-pipeline — 占位符驱动半自动配图管线

本目录是 `smart-illustrator` 的**非侵入式增强层**:不改作者任何现有文件,只在 `commands/` 下新增 slash command,配合作者 `styles/`、`scripts/` 使用。

## 安装

```bash
cd ~/.claude/skills/smart-illustrator
# 命令体软链到用户级 ~/.claude/commands/(改动自动同步)
ln -sf "$(pwd)/si-pipeline/commands/si-plan.md" ~/.claude/commands/si-plan.md
```

## 命令清单

| 命令 | 阶段 | 说明 |
|---|---|---|
| `/si-plan` | Stage 1 | 复制 + 占位符 + 清单(本计划交付) |
| `/si-image` | Stage 2 | 创意图(minimax 后端) |
| `/si-chart` | Stage 3 | 结构图(作者引擎 mermaid/excalidraw) |
| `/si-all` | Stage 2+3 一键 | 全部跑完回填 |

## 设计文档

- Spec: `../docs/superpowers/specs/2026-07-17-placeholder-pipeline-design.md`
- Stage 1 实现计划: `../docs/superpowers/plans/2026-07-17-stage1-si-plan.md`

## PR 策略

每阶段独立目录、可独立合入上游;minimax 后端本地保留(用 `--backend` 切换)。
```

- [ ] **Step 3: 提交**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/README.md si-pipeline/commands/.gitkeep si-pipeline/tests/fixtures/.gitkeep
git commit -m "feat(si-pipeline): bootstrap directory + README"
```

Expected: 1 commit on branch `feat/placeholder-pipeline`,3 个新文件。

---

### Task 2: Author /si-plan slash command body(核心交付物)

**Files:**
- Create: `si-pipeline/commands/si-plan.md`
- Create symlink: `~/.claude/commands/si-plan.md` → 上面

**Interfaces:**
- Consumes: `$ARGUMENTS` = `<file.md> ["额外提示词"]`
- Produces: `{stem}-image.md`(副本,含占位符)、`{stem}.illus.json`(清单)、stdout 检查点表

- [ ] **Step 1: 写 `si-pipeline/commands/si-plan.md`(完整内容)**

```markdown
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

### 5. 读 style(提取操作型 Gemini System Prompt)

- 默认路径:`{skill_root}/styles/style-light.md`(`skill_root` = 本 slash command 解析到的仓库根,即 `~/.claude/skills/smart-illustrator`)
- 若用户传 `--style <name>`,改读 `style-{name}.md`
- `Read` 该文件全文
- **抽取** ``` … ``` 代码块**内部**的 Gemini System Prompt,丢弃:
  - 头部 markdown 元数据(标题、描述、`## 适用场景` 列表、`## Gemini System Prompt` 标题、起始 ```)
  - 尾部 markdown 文档段(闭合 ```、`## 水印`、`## Prompt 模板`、`## 配图类型 × 构图建议`)
- 将操作型 prompt 纯文本塞到 JSON 的 `style` 字段
- 例:`style-light.md` → 提取从 "你是一位信息图绘图大师..." 开始,到第一个闭合 ``` 之前结束的整段

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
```

- [ ] **Step 2: 创建 symlink**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
ln -sf "$(pwd)/si-pipeline/commands/si-plan.md" ~/.claude/commands/si-plan.md
ls -la ~/.claude/commands/si-plan.md
```

Expected: 显示 `→ /home/xhm/.claude/skills/smart-illustrator/si-pipeline/commands/si-plan.md`

- [ ] **验证 symlink 目标可解析**

```bash
target=$(readlink -f ~/.claude/commands/si-plan.md)
test -f "$target" || { echo "ERROR: symlink broken: $target"; exit 1; }
echo "symlink OK: $target"
```

- [ ] **Step 3: 提交**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/commands/si-plan.md
git status   # 确认只有这一个新文件 + 前面 Task 1 的文件;**没有任何作者现有文件被修改**
git commit -m "feat(si-pipeline): /si-plan Stage 1 slash command"
```

Expected: 1 commit;`git status` 显示 working tree clean。

---

### Task 3: Test fixture — minimal synthetic article

**Files:**
- Create: `si-pipeline/tests/fixtures/minimal-article.md`

**目的:** 单元测试式的小夹具,文章结构简单可控,手算期望 manifest,验证 Stage 1 行为可预测。

- [ ] **Step 1: 写最小测试文档**

文件: `si-pipeline/tests/fixtures/minimal-article.md`

```markdown
# 测试文档:三阶段流程

本文用于验证 /si-plan 行为。

## 阶段 A:初始化

第一步是创建项目。

## 阶段 B:数据准备

需要先采集数据,再清洗。

## 阶段 C:执行

数据就绪后,执行核心流程。

## 总结

A→B→C 三个阶段缺一不可。
```

- [ ] **Step 2: 期望 manifest(手算,不入库,仅供 Step 4 核对)**

| id | engine | type | 位置(原文) |
|---|---|---|---|
| 1 | mermaid | process | L7 段末(阶段 A) |
| 2 | mermaid | process | L11 段末(阶段 B) |
| 3 | mermaid | process | L15 段末(阶段 C) |

原因:三个章节都是线性步骤,简单流程 → mermaid `process`。

- [ ] **Step 3: 提交**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/tests/fixtures/minimal-article.md
git commit -m "test(si-pipeline): minimal article fixture"
```

---

### Task 4: Validate on synthetic article

**Files:** 无新文件(只读验证)

- [ ] **Step 1: 跑 /si-plan**

在 Claude Code 中输入:

```text
/si-plan /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures/minimal-article.md
```

Expected stdout: 检查点表 + 两文件路径(`.../minimal-article-image.md`、`.../minimal-article.illus.json`)。

- [ ] **Step 2: 验证副本**

```bash
cd /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures
grep -n "<!-- IMAGE:" minimal-article-image.md
```

Expected: 输出 3 行,内容形如 `7:<!-- IMAGE:001 -->`、`11:<!-- IMAGE:002 -->`、`15:<!-- IMAGE:003 -->`(行号可能 ±1,因 LLM 选位略有差异,**数量=3 + 占位符格式正确** 是硬指标)。

- [ ] **Step 3: 验证 JSON schema**

```bash
cat minimal-article.illus.json
```

逐项核对:

- [ ] `pictures.length === 3`
- [ ] `pictures[].engine` 全部 `mermaid`
- [ ] `pictures[].type` 全部 `process`
- [ ] `pictures[].placeholder` 是 `<!-- IMAGE:001 -->` … `<!-- IMAGE:003 -->`(顺序对)
- [ ] `pictures[].code` 全部 `""`
- [ ] `pictures[].status` 全部 `planned`
- [ ] `pictures[].filename` 全部 `""`(mermaid 嵌码模式)
- [ ] `style` 字段是 `style-light.md` ``` 代码块内的操作型 prompt(长度 > 1000 字符;且与 style-light.md 首段 ```...``` 块内容字符串相等)
- [ ] `style` 字段不含 '# Style:' 标题或 '## 配图类型' 表格(确认丢弃了 markdown 包装)
- [ ] `batch_rules.total === 3`
- [ ] `instruction` 含"请为我绘制 3 张图片"

- [ ] **Step 4: 幂等验证**

再跑一次:

```text
/si-plan /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures/minimal-article.md
```

确认:

- [ ] 副本占位符数量仍为 3(没有 `<!-- IMAGE:004 -->` 出现)
- [ ] JSON 内容除格式外语义不变(`git diff` 仅空白差异或全等)

```bash
cd /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures
grep -c "<!-- IMAGE:" minimal-article-image.md   # 应输出 3
```

- [ ] **Step 5: 修正(如需)**

若 Step 2-4 任何一项失败,改 `si-pipeline/commands/si-plan.md` 后重跑。常见偏差:

| 偏差 | 修正方向 |
|---|---|
| 占位符数 ≠ 3 | 改 step 3 的数量指引 / 加固"段末插入"语义 |
| `code` 非空 | 检查 step 6 schema 模板 |
| `filename` 非空(mermaid 项) | 改 step 6 filename 规则段 |
| `style` 太短 | 检查 step 5 的完整 Read |
| 幂等失败(占位符累加) | 加固 step 4 的幂等检查 |

修正后 commit:

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/commands/si-plan.md
git commit -m "fix(si-pipeline): /si-plan validation fixes from synthetic test"
```

---

### Task 5: Validate on Spring test doc(真机验收)

**Files:** 无新文件(只读验证;产物在用户指定的工作目录)

- [ ] **Step 1: 定位 Spring 测试文档**

```bash
find ~/.claude -name "Enterprise Spring*.md" 2>/dev/null | head -3
ls ~/Documents/*.md ~/Documents/**/*.md 2>/dev/null | grep -i spring | head -3
```

若用户在前序对话中已指定路径,用之。否则询问用户。

- [ ] **Step 2: 跑 /si-plan + 传额外提示词**

```text
/si-plan <Spring-doc-path> "重点配架构图与流程图,少用隐喻"
```

Expected: 检查点表 + 副本路径 + 清单路径;**数量在 4-6 张**。

- [ ] **Step 3: 验证产物**

```bash
STEM=<Spring-doc-stem>   # 不含 .md,如 "Enterprise Spring Core..."
DIR=<Spring-doc-dir>
grep -c "<!-- IMAGE:" "$DIR/$STEM-image.md"      # 应在 4-6
python3 -c "
import json
m = json.load(open('$DIR/$STEM.illus.json'))
assert all(p['code']=='' for p in m['pictures'])
assert all(p['status']=='planned' for p in m['pictures'])
assert set(p['engine'] for p in m['pictures']).issubset({'gemini','excalidraw','mermaid'})
print('engines:', {p['engine'] for p in m['pictures']})
print('count:', len(m['pictures']))
"
```

Expected: count 在 4-6,engines 包含至少 mermaid(架构/流程),可能含 excalidraw(对比),可能含 1 张 gemini(隐喻封面)。

- [ ] **Step 4: 人工检查点 + 用户确认**

打印检查点表给用户,问:

```text
Spring 文档 Stage 1 完成:
- 副本:<copy_path>
- 清单:<manifest_path>
- 张数:<N>
- 引擎分布:<engines>

请确认:
- 位置/数量/引擎 OK?→ 跑 /si-image 与 /si-chart(进入 Stage 2/3 实现计划)
- 不 OK?→ 告诉我「改 XXX:YYY→ZZZ」
```

收到确认 → Stage 1 收官。

- [ ] **Step 5: 提交验证产物(可选)**

如产物在工作目录且用户同意:

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/tests/fixtures/   # 若用户复制了最小夹具的产物作为 reference
git commit -m "test(si-pipeline): validation outputs (Spring doc)" --allow-empty
```

---

## Self-Review

### Spec coverage(spec §Stage 1 7-step 流程逐条对应)

| Spec 项 | 对应 Task |
|---|---|
| 1. 读原文 → 复制 `{stem}-image.md` | Task 2 step 1 |
| 2. LLM 选位 + 引擎 + 类型 | Task 2 step 3 |
| 3. 在副本插入 `<!-- IMAGE:NNN -->` | Task 2 step 4 |
| 4. 起草 `content`,`code` 留空 | Task 2 step 6(schema) |
| 5. 读作者 style 文件,填 `style` 字段 | Task 2 step 5 |
| 6. 生成 `{stem}.illus.json` | Task 2 step 6-7 |
| 7. 检查点输出 `编号→引擎→类型→位置` | Task 2 step 8 |
| 占位符格式 `<!-- IMAGE:NNN -->` | Task 2 全局约束 2 |
| 引擎枚举严格作者值 | Task 2 全局约束 3 |
| 类型沿用作者表 | Task 2 全局约束 4 |
| 优先级 Gemini>Excalidraw>Mermaid | Task 2 全局约束 5 |
| Style 读作者原文 | Task 2 step 5 |
| Code 字段空 | Task 2 全局约束 9 |
| Status=planned | Task 2 全局约束 10 |
| 原文不动 | Task 2 全局约束 1 |
| 非侵入(不改作者现有文件) | Task 1/2/3 全程无 `Modify: SKILL.md` 等 |
| Landing 决策(plan 阶段细化项 1) | Landing Decision 段 |
| 幂等 | Task 4 step 4 |
| 失败处理 | Task 2 失败处理表 |
| PR 友好 | Landing Decision + README PR 策略段 |

### Placeholder scan

- [x] 无 "TBD"/"TODO"/"implement later"
- [x] 所有代码块、命令、JSON schema 完整
- [x] 无 "Similar to Task N"(每步骤独立完整)
- [x] 无"add appropriate error handling"(失败处理表已具体)
- [x] 类型/函数/字段名全程一致

### Type consistency

- JSON 字段:`id` / `topic` / `content` / `engine` / `type` / `placeholder` / `filename` / `code` / `status`(与 spec 完全一致)
- 占位符格式:`<!-- IMAGE:NNN -->`(全程 3 位零填充)
- 文件命名:`{stem}-image.md` / `{stem}.illus.json` / `images/{stem}-img-NNN.png`(全程一致)
- 引擎枚举字面量:`gemini` / `excalidraw` / `mermaid`(无任何变体如 `Gemini` 或 `geminii`)
- symlink 目标:`~/.claude/commands/si-plan.md`(与命令名一致)

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-17-stage1-si-plan.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — execute tasks in this session using executing-plans, batch with checkpoints