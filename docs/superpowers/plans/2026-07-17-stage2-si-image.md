# Stage 2 (/si-image) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从 `{stem}.illus.json`(Stage 1 产出,所有 picture `status="planned"`)出发,基于 minimax 后端调创意图生成 API,产出 PNG 至 `./images/{stem}-img-NNN.png` 并把图按 `placeholder` 回填进 `{stem}-image.md` 副本;支持 `--prompt-only` 模式不调 API 预览 prompt 质量。

**Architecture:** Claude-driven slash command(`/si-image`)调用用户已有 Python 脚本 `/home/xhm/图片/minimax_t2i.py` 出图,纯工具调用(Read/Edit/Write/Bash),**不写 TS 脚本**;成功后用 Edit 替换副本中的占位符行为 `![](images/...)`,JSON `status` 从 `planned` → `generated` → `inserted`。`--backend gemini` 分支不实现调用,只把 prompt 字段导出供上游作者 `generate-image.ts` 取用(留接口)。

**Tech Stack:** Claude Code slash command + 内置工具(Read/Write/Edit/Bash/Glob);Python 3 + `minimax_t2i.py`(用户资源,仓库外,不提交);可选作者 `generate-image.ts`(Stage 2 仅搭接口,不调用)。

## Global Constraints(从 spec 逐字钉死,任何任务违反即错)

- **输入**:`{stem}.illus.json`(Stage 1 输出,**所有 picture `status="planned"`,否则提示先跑 Stage 1**)
- **非侵入**:本计划**只新增**文件 `si-pipeline/commands/si-image.md` + 用户级 symlink;不改作者 `SKILL.md` / `scripts/*` / `styles/*` / `references/*`
- **不调 API 模式**:`--prompt-only`,只产出 `{stem}.image-prompts.json`(**覆盖全量** picture,不止 gemini;mermaid/excalidraw 的 `prompt` 字段为 Stage 3 将起草的 `code` 草案占位文本)
- **创意图只跑 `engine=="gemini"` 项**(spec §Stage 2 第 105 行);mermaid/excalidraw 项 Stage 2 **跳过**,留给 Stage 3
- **prompt 长度上限 1500 字符**(用户 minimax_t2i.py argparse `prompt` help 明确写明;spec §待后续 plan 阶段细化 第 2 项)→ 拼接时按策略裁剪,见 Task 2 Step 3
- **prompt 拼接规则**(spec §Stage 2 第 114 行):`gemini` 项 → `style + "\n\n" + topic + "\n\n" + content`;`mermaid`/`excalidraw` 项 → `prompt = content`(Stage 3 据此生 code)
- **每 picture 11 字段**(spec §Stage 2 第 113 行钉死,与 Stage 1.5 schema 完全一致):`id / topic / content / engine / type / line / anchor / placeholder / filename / code / prompt` + `status`=**`"prompted"`**(仅 `--prompt-only`)或 **`"generated"`**(API 出图成功)或 **`"inserted"`**(已回填副本)
- **后端可插拔**:`--backend minimax | gemini`,默认 `minimax`;`gemini` 仅搭占位实现(不调,不写图,只把 prompt 标 `status="prompted"`),留给上游 `generate-image.ts` 取用
- **状态机**(spec §JSON schema 第 65 行):`planned` → `generated` → `inserted`(--prompt-only 路径产生一个独立分支:`planned` → `prompted`)
- **filename 写入规则**(spec §JSON schema filename 段):`gemini` / `excalidraw` → `images/{stem}-img-NNN.png`(Stage 2 为 gemini 项落盘);`mermaid` 嵌码 → `""`(**不**为 mermaid 项生成 PNG)
- **PNG 落盘路径**:`./images/`,相对 manifest 所在目录;`minimax_t2i.py` 默认输出 `minimax-{i}.jpeg`,slash command 必须按 `filename` 重命名为 `.png`(.jpeg → .png = 仅重命名,内容不动)
- **回填幂等**(spec §待后续 plan 阶段细化 第 3 项):二次跑不重复插入;以 `placeholder` 精确匹配定位替换
- **回填副本**(spec §Stage 2 第 107 行):`-g -full` 把 `![](images/{stem}-img-NNN.png)` 行替换占位符 `<!-- IMAGE:NNN -->` 行;默认 `-g` 仅生成 PNG 不动副本,先让人审图
- **不修改原文**:`/si-image` 永远不写 `{stem}.md`,只写 `{stem}-image.md` 与 `./images/*`
- **PR 友好**:minimax 后端本地保留(`--backend minimax` 默认),PR 上游时切换 `--backend gemini`

## Landing Decision(si-image 落点)

| 文件 | 路径 | 说明 |
|---|---|---|
| Slash command 源 | `{skill_root}/si-pipeline/commands/si-image.md` | 在作者仓库内,新增,与 `si-plan.md` 同目录 |
| 用户级安装 | `~/.claude/commands/si-image.md` | **symlink** 到上面的源(同 `si-plan.md` 模式) |
| 测试夹具 | `si-pipeline/tests/fixtures/`(已存在,Stage 1 已用) | 同上 |
| 不动 `si-plan.md` / `si-chart.md` / `si-all.md`(后两者属 Stage 3/4 实现) |

**不**修改作者 `package.json` / `SKILL.md` / 任何已存在文件;不修改 Stage 1 已交付的 `si-pipeline/README.md`(后续 Stage 4 一并加 si-image 行)。

---

## File Structure(Stage 2 完成后)

```
smart-illustrator/si-pipeline/
├── README.md                              # 已有(Stage 1)
├── commands/
│   ├── si-plan.md                         # 已有(Stage 1)
│   └── si-image.md                        # ★ 本计划核心交付物
└── tests/
    └── fixtures/
        └── minimal-article.md             # 已有(Stage 1)

# 用户级 symlink(不提交)
~/.claude/commands/si-image.md → .../smart-illustrator/si-pipeline/commands/si-image.md
```

---

### Task 1: Author /si-image slash command body(核心交付物)

**Files:**
- Create: `si-pipeline/commands/si-image.md`
- Create symlink: `~/.claude/commands/si-image.md` → 上面

**Interfaces:**
- Consumes: `$ARGUMENTS` = `<manifest.illus.json> [--prompt-only|-p] [-g] [-full] [--backend minimax|gemini]`(`$1` 必填 = manifest 绝对/相对路径;`~` 自动展开;可选 flag 见下表)
- Produces:
  - `--prompt-only` → `{stem}.image-prompts.json`(覆盖全量 picture,11 字段 + `prompt` + `status="prompted"`)
  - `-g` → `./images/{stem}-img-NNN.png`(N = gemini 项数);改写 manifest 的 `filename` 与 `status="generated"`
  - `-g -full` → 同上 + 副本 `{stem}-image.md` 中的占位符行替换为 `![](images/{stem}-img-NNN.png)`,manifest 进一步 `status="inserted"`
  - 默认(无 flag)→ 仅打印检查点表 + 提示:"先用 --prompt-only 预览,再 -g,再 -g -full"

**Flag 表(slash command 解析阶段用):**

| 用户传 | 路径 |
|---|---|
| `<manifest>` 必填,第 1 段(其它段全是 flag) | 固定入参 |
| `--prompt-only` 或 `-p` | 走 prompt-only 路径 |
| `-g` | 走生成路径(必须配 `--backend`) |
| `-full` | 与 `-g` 配合,生图后回填副本(必须显式声明,默认不填) |
| `--backend minimax` 或 `--backend gemini` | 默认 `minimax`;`gemini` 不调用,只标 `status="prompted"` |

**Step 1: 写 `si-pipeline/commands/si-image.md`(完整内容)**

```markdown
---
description: smart-illustrator Stage 2 — 从 {stem}.illus.json 出发,生成创意图(minimax 后端)并回填副本占位符;支持 --prompt-only 预览 prompt
argument-hint: <manifest.illus.json> [--prompt-only | -p] [-g] [-full] [--backend minimax|gemini]
allowed-tools: Read Write Edit Bash Glob
---

# /si-image — Stage 2:创意图生成(minimax 后端)

> 非侵入式增强:不修改作者任何现有文件;调用用户已有 `/home/xhm/图片/minimax_t2i.py` 出 PNG;按 spec 占位符回填。

## 输入

`$ARGUMENTS` = `<manifest.illus.json> [--prompt-only|-p] [-g] [-full] [--backend minimax|gemini]`

- 第 1 段(必填):manifest 绝对或相对路径(`~` 自动展开);前置条件:`status` 全是 `planned`(否则报错让人跑 Stage 1 修)
- 后续段:flag 组合,无序;互斥:
  - `--prompt-only` / `-p`:不调 API,只导出 `prompt` 文本(JSON)
  - `-g`:走生成;不指定则**仅打印检查点表 + 建议跑 `--prompt-only` 预览**(防误触 API 花钱)
  - `-full`:生成后回填副本(必须配 `-g`)
  - `--backend minimax|gemini`:默认 `minimax`;`gemini` 模式只产出 `status="prompted"` JSON(不调 API,给上游 generate-image.ts 取用)

## 全局约束(钉死,违反即错)

1. **输入校验**:manifest 路径必须存在;manifest 中所有 picture.status 必须为 `"planned"`(否则报错并提示先跑 Stage 1 修)
2. **目标 picture**:只处理 `engine == "gemini"` 的 picture;mermaid/excalidraw 项跳过(spec §Stage 2 第 105 行),已提示"留给 Stage 3 的 /si-chart"
3. **prompt 拼接(规则)**(spec §Stage 2 第 114 行):
   - gemini 项:`prompt = style + "\n\n" + topic + "\n\n" + content`
   - mermaid/excalidraw 项:`prompt = content`(prompt-only 模式下覆盖全量时填)
4. **prompt 长度硬上限 1500 字符**(minimax_t2i.py argparse help:"图片描述,最长 1500 字符");超过则按 **策略 P1**(详见"失败处理")裁剪
5. **每 picture 字段(11 个 + prompt + status="prompted")**(spec §Stage 2 第 113 行):`id / topic / content / engine / type / line / anchor / placeholder / filename / code` 全继承;新增 `prompt`(本 Stage 写);`status` 取值见状态机
6. **状态机**:
   - 默认检查点:`planned`(不动)
   - `--prompt-only` 改:`prompted`(只写 JSON,不动副本)
   - `-g` 改:`generated`(只生 PNG,不动副本)
   - `-g -full` 改:`inserted`(生 PNG + 回填副本)
7. **filename 规则(spec §JSON schema)**:
   - gemini / excalidraw 项:`images/{stem}-img-NNN.png`(Stage 2 真落盘)
   - mermaid 嵌码项:`""`(不生成)
8. **PNG 落盘**:相对 manifest 所在目录的 `./images/`,文件名严格 `{stem}-img-NNN.png`;调 `minimax_t2i.py` 默认产生 `minimax-{i}.jpeg`,slash command 按 id 重命名为 `.png`(.jpeg 改后缀为 .png = 仅文件重命名,字节内容不动)
9. **回填幂等**:二次跑不重复插入;`Read` 副本后定位 `<!-- IMAGE:NNN -->` 整行,`Edit` 替换为 `![](images/{stem}-img-NNN.png)`(同占位符行号)
10. **非侵入**:不修改 manifest 原文以外的任何文件(spec 钉死的非侵入);不改 `{stem}.md`,只在 `{stem}-image.md` 副本上工作
11. **PR 友好**:`--backend gemini` 留给上游;默认 minimax 本地保留,PR 上游时改默认

## 执行步骤

### 1. 参数解析

- 切 `$ARGUMENTS`,得 `manifest_path` 与 flag 集合(`prompt_only` / `generate` / `full` / `backend`)
- `~` 展开:`file_path` 以 `~/` 起时 `Bash echo ~` 后重拼
- 校验 `manifest_path` 必须以 `.illus.json` 结尾(防用户传错)
- 校验 flag 互斥:`-p` 与 `-g` 互斥(同时传 → 报错并提示"二者选一")
- 校验 `-full` 必须配 `-g`(否则报错并提示)
- 若无 `-p` 也无 `-g`(仅传了 manifest)→ 走检查点路径(只打印建议)
- `backend` 默认 `minimax`

### 2. 读 manifest(分析用 + 后写回)

- `Read` manifest;`Bash python3 -c "import json; m=json.load(open('PATH')); ..."` 校验 schema:
  - `m.pictures` 是 list
  - 每 picture 含 `id/topic/content/engine/type/line/anchor/placeholder/filename/code/status`
  - 所有 picture.status == `"planned"`(否则**报错并列出 非 planned 的 id 让人修**)
- 得出 `{stem}`(`manifest_path` 去目录与 `.illus.json` 后缀)
- 计算 `./images/` 路径(相对 manifest 所在目录)

### 3. 选目标 picture

过滤 `engine == "gemini"` 的 picture(本 Stage 唯一目标;mermaid/excalidraw 跳过并在检查点表标注"留给 Stage 3 /si-chart")。

记 `gemini_items = [{picture}, ...]`,N = len。

### 4. 选择路径

依据 flag:

- **路径 A(`/p` 或 `--prompt-only`)**:跳到 Step A
- **路径 B(`-g` without `-full`)**:跳到 Step B
- **路径 C(`-g -full`)**:跳到 Step B 后接 Step C
- **路径 D(无 flag)**:跳到 Step D

### Step A: --prompt-only 路径(只导出 prompt 文本,不动 manifest 原文)

A.1 构建 prompt:

- 对每 picture(gemini / mermaid / excalidraw 全覆盖,spec §Stage 2 第 110-114 行钉死"覆盖全量"):
  - gemini:`prompt = style + "\n\n" + topic + "\n\n" + content`
  - mermaid / excalidraw:`prompt = content`(Stage 3 据此生 code;此处为草案占位文本)
- 长度校验:若 `len(prompt) > 1500`,应用**策略 P1**(见"失败处理")裁剪,记录裁剪次数到检查点表

A.2 构造 `{stem}.image-prompts.json`:

```jsonc
{
  "_meta": {
    "schema_version": "stage-2/v1",
    "produced_by": "/si-image --prompt-only",
    "produced_at": "<ISO8601 now>",
    "backend": "<minimax|gemini>",
    "source_manifest": "<manifest path>",
    "total": <pictures.length>,
    "gemini": <gemini count>,
    "truncated_prompts": [<被裁剪的 id 列表>]
  },
  "pictures": [
    {
      "id": 1,
      "topic": "...",
      "content": "...",
      "engine": "gemini|excalidraw|mermaid",
      "type": "...",
      "line": 42,
      "anchor": "...",
      "placeholder": "<!-- IMAGE:001 -->",
      "filename": "images/{stem}-img-001.png",  // mermaid 嵌码则 ""
      "code": "",
      "prompt": "<拼接结果,可能被裁剪>",
      "status": "prompted"
    }
    // ... 共 N 项(覆盖全量,不止 gemini)
  ]
}
```

A.3 `Write` 输出 JSON(UTF-8,2 空格缩进)。

A.4 打印检查点表 + 路径 → 等用户确认。

### Step B: -g 路径(出 PNG,不动副本)

B.1 校验 `backend == "minimax"` 时 `MINIMAX_IMAGE_API_KEY` 或 `MINIMAX_API_KEY` env 必须设置(`Bash test -n "$MINIMAX_IMAGE_API_KEY$MINIMAX_API_KEY" || { echo "❌ 请先设置 MINIMAX_IMAGE_API_KEY 环境变量"; exit 1; }`)。

B.2 `Bash mkdir -p "<manifest_dir>/images"` 建输出目录。

B.3 逐 picture 串行调 API(避免并发 API 限流;若用户后续指定 `-parallel` 再启用 subagent 并行):

- 构造本图 prompt(同 Step A.1,但**仅** gemini 项;style + topic + content)
- 长度校验(< 1500);超则 P1 裁剪
- `Bash`:`/home/xhm/图片/minimax_t2i.py "<prompt>" --out "<images_dir>/_tmp/" --ratio "16:9" --format base64 --n 1 2>&1 | tail -20` 调起出图(用 `_tmp` 子目录避免与历史产出混淆)
- `Bash ls "<images_dir>/_tmp/"` 取最新生成的 `minimax-{i}.jpeg`
- `Bash mv "<images_dir>/_tmp/minimax-{i}.jpeg" "<images_dir>/{stem}-img-NNN.png"` 重命名(.jpeg → .png 仅文件重命名;内容字节不动)
- `Bash rm -rf "<images_dir>/_tmp"` 清理

B.4 改写原 manifest 对应 picture(不是另存,是**就地修改** `manifest_path`):

- `filename`:显式写盘后的相对路径
- `status`:`"generated"`

B.5 失败时此 picture 的 status 改 `"error"`(而不是留 `"planned"`);继续下一张;检查点表打印 error 项。

B.6 检查点表:打印"已生成 N/M 张 + 失败列表";**不直接回填**等用户手动再加 `-full`。

### Step C: -g -full 追加路径(回填副本)

C.1 校验路径 B 已完成所有目标 picture(`status` 全 `generated` 或 `error`;若全是 `planned` → 报错"请先跑 `-g`")

C.2 找出副本:`{stem}-image.md`(`{stem}` 已算);`Read` 副本

C.3 对每 `status=="generated"` 的 gemini picture:

- `Bash grep -n "<!-- IMAGE:NNN -->" "<copy_path>"` 定位行号(L)
- `Edit` 副本,`old_string` = `<!-- IMAGE:NNN -->\n`(整行),`new_string` = `![](images/{stem}-img-NNN.png)\n`
- **幂等**:若 `grep` 命中行已是 `![](...)`,跳过;若命中多行(不该发生,manifest 一对一)→ 报错
- **行号一致性**:`-full` 回填后,`status` 改 `"inserted"`;但 `line` / `anchor` 字段(line + anchor 是占位符行号)此 Stage **不重新计算**(占位符行还在,只是变成了图片引用;回填后的 markdown 行号与原 placeholder 行号 = 同一行;若用户后续删除/移动 placeholder,Stage 1.5 的 line 字段失效,需重跑 Stage 1)

C.4 改写 manifest 后**就地 update** picture.status 为 `"inserted"`(`Write` 整 manifest,因 Edit 在 JSON 行级不稳定)

C.5 打印完成报告 + 检查点表

### Step D: 无 flag(只检查点)

D.1 打印检查点表(N,引擎分布,prompt 总字符,目标 picture 数)

D.2 提示:

```text
[Stage 2 路径建议]
────────────────────
N=<N>  gemini=<g>  mermaid=<m>  excalidraw=<e>

下一步:
- 跑 /si-image <manifest> --prompt-only     先看 prompt 文本(不调 API)
- 跑 /si-image <manifest> -g                 出图(<backend> 后端)
- 跑 /si-image <manifest> -g -full           出图 + 回填副本
- 跑 /si-image <manifest> -g -full --backend gemini   跳过调用,只更新 manifest 状态
```

D.3 **不**自动推进;等用户决策

### 8. 检查点表(所有路径通用,只是字段值不同)

向用户打印(任何路径都要打):

```text
[Stage 2 检查点]
────────────────────────────────────────────────────────────
编号 │ 引擎      │ 行号 │ 章节锚点              │ 状态
─────┼───────────┼──────┼───────────────────────┼────────────
001  │ gemini    │ L37  │ ## 1.2 IoC 容器与...  │ generated
002  │ mermaid   │ L191 │ ## 三层架构协同代码展示│ skipped(Stage 3)
...

✅ manifest:<manifest_path>
✅ 副本:<copy_path>(仅 -full 时改动)
✅ 图片目录:<images_dir>(仅 -g / -full 时落盘)

请确认:
- 输出 OK?→ 进入 Stage 3(/si-chart)或收尾
- 不 OK?→ 告诉我「改 XXX:YYY→ZZZ」
```

## 失败处理

| 情况 | 应对 |
|---|---|
| manifest 路径不存在 / 非 `.illus.json` | 报错并提示正确路径 |
| manifest 中存在 status != `"planned"` 的 picture | 报错列出非 planned 的 id;提示先跑 Stage 1 重置 |
| `--prompt-only` 与 `-g` 同时传 | 报错"二者选一" |
| `-full` 不配 `-g` | 报错"必须有 -g 才有 -full" |
| 无 manifest_arg | 报错"第 1 段必填 manifest 路径" |
| MINIMAX_IMAGE_API_KEY / MINIMAX_API_KEY 未设置(`-g` 时) | 报错并提示:`export MINIMAX_IMAGE_API_KEY=...` |
| `minimax_t2i.py` 调用失败(API 报错 / 超时) | 该 picture `status="error"`,继续下一张,最后打印 error 列表 |
| prompt 拼接超 1500 字符 | 应用策略 P1:`content` 截到 1500 - len(style) - len(topic) - 4(分隔符 `\n\n` × 2);若仍超,继续截 `topic`;最后截 `style`;若 style 也撑爆,报错让人手改。**裁剪后必须在 `_meta.truncated_prompts` 记录 id 列表**(--prompt-only 路径) |
| `<!-- IMAGE:NNN -->` 在副本中找不到(回填时) | 报错"占位符丢失,可能 Stage 1 重跑或用户手改了";**不**强插(避免错位) |
| JSON 写回后字段丢了 | Step A.2 / Step B.4 写后立即 `Read` 回头校验 11 字段全 + 新增 prompt 与 status;漏则重写 |
| minimax 返回的不是 jpeg | 不假设扩展名,read first bytes 判 mime;非 jpeg 则改为 `.bin` 不改 `.png`(`filename` 改后缀;记 warning) |

## 输出文件清单

```
{stem}-image.md                       # 副本(仅 -full 时改 placeholder → ![](path)行;原文不动)
{stem}.illus.json                     # manifest(仅 -g / -full 时改 filename+status;原文不动)
{stem}.image-prompts.json             # --prompt-only 路径才产出(覆盖全量 picture,prompted)
./images/                             # -g / -full 时建目录
└── {stem}-img-NNN.png                # 重命名后的 PNG(每个 gemini picture 一张)
```

## 后续衔接

- `/si-chart {manifest}` — Stage 3 跑 mermaid/excalidraw 项,回填时复用此 Stage 的同一副本(状态机不会冲突,只处理 `status != "inserted"` 项)
- `/si-all {manifest}` — Stage 2+3 一键;若已跑 Stage 2 部分插入,Stage 3 只补未完成项
```

**Step 2: 创建 symlink**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
ln -sf "$(pwd)/si-pipeline/commands/si-image.md" ~/.claude/commands/si-image.md
ls -la ~/.claude/commands/si-image.md
```

Expected: 显示 `→ /home/xhm/.claude/skills/smart-illustrator/si-pipeline/commands/si-image.md`

**Step 3: 校验 symlink 目标可解析**

```bash
target=$(readlink -f ~/.claude/commands/si-image.md)
test -f "$target" || { echo "ERROR: symlink broken: $target"; exit 1; }
echo "symlink OK: $target"
```

**Step 4: 提交**

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/commands/si-image.md
git status   # 确认只有这一个新文件;**没有任何作者现有文件被修改,也没有 si-plan.md 被改**
git commit -m "feat(si-pipeline): /si-image Stage 2 slash command (prompt-only / -g / -full)"
```

Expected: 1 commit;`git status` 显示 working tree clean。

---

### Task 2: Validate on synthetic article --prompt-only 不调 API

**Files:** 无新文件(只读验证)

**目的:** 验证 `--prompt-only` 路径无需 API 也能跑通,产物 JSON 字段齐全。

**Step 1: 用 Stage 1 已有 minimal fixture 跑 /si-image --prompt-only**

在 Claude Code 中输入:

```text
/si-image /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures/minimal-article.illus.json --prompt-only
```

Expected stdout: 检查点表 + 一个新文件 `minimal-article.image-prompts.json` 路径。

**Step 2: 验证产物 JSON 字段**

```bash
cd /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures
test -f minimal-article.image-prompts.json && echo "exists" || { echo "ERROR: file not produced"; exit 1; }
python3 -c "
import json
m = json.load(open('minimal-article.image-prompts.json'))
assert '_meta' in m
assert 'pictures' in m
assert len(m['pictures']) == 3, f\"expected 3 pictures, got {len(m['pictures'])}\"
required = {'id','topic','content','engine','type','line','anchor','placeholder','filename','code','prompt','status'}
for p in m['pictures']:
    missing = required - set(p.keys())
    assert not missing, f\"picture {p.get('id')} missing {missing}\"
    assert p['status'] == 'prompted', f\"picture {p['id']} status={p['status']!r}, expected 'prompted'\"
    assert isinstance(p['line'], int), f\"picture {p['id']} line not int: {p['line']!r}\"
    assert isinstance(p['anchor'], str), f\"picture {p['id']} anchor not str: {p['anchor']!r}\"
    assert p['prompt'], f\"picture {p['id']} prompt empty\"
    # 每图 prompt 非空 + gemini 项 prompt 含 style+content 的拼接
    if p['engine'] == 'gemini':
        assert p['content'] in p['prompt'], f\"picture {p['id']} gemini prompt missing content\"
print('OK: --prompt-only JSON valid, all 3 pictures have 11 legacy fields + prompt + status=prompted')
"
```

Expected: 末行 `OK: --prompt-only JSON valid...`。

**Step 3: 验证不调 API(无 images/ 出现)**

```bash
cd /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures
test -d images && { echo "ERROR: --prompt-only 不该生成 images/"; exit 1; } || echo "OK: 无 images/ 目录"
```

Expected: `OK: 无 images/ 目录`

**Step 4: 验证 manifest 原文不被改**

```bash
cd /home/xhm/.claude/skills/smart-illustrator/si-pipeline/tests/fixtures
git diff --stat minimal-article.illus.json
# 应输出空或仅有元数据;status 应全 planned
python3 -c "
import json
m = json.load(open('minimal-article.illus.json'))
assert all(p['status']=='planned' for p in m['pictures']), 'manifest status changed'
print('OK: manifest 原文未改')
"
```

**Step 5: 修正(如需)**

若 Step 2-4 失败,看错误信息改 `si-pipeline/commands/si-image.md` 对应 Step A.X;常见偏差:

| 偏差 | 修正方向 |
|---|---|
| JSON 缺失某字段 | 检查 Step A.2 schema;特别 `line` / `anchor` 必须从 manifest 继承 |
| `status` 不是 `prompted` | 检查 Step A.2 status 字段 |
| `prompt` 为空 | 检查 Step A.1 拼接;style / topic / content 来源 |
| mermaid 项无 prompt | 检查 Step A.1 mermaid 项分支 `prompt = content` |
| API 被调用了(`images/` 出现) | 检查路径选择 Step 4,确认 `--prompt-only` 跳到 Step A 而非 Step B |

修正后 commit:

```bash
cd /home/xhm/.claude/skills/smart-illustrator
git add si-pipeline/commands/si-image.md
git commit -m "fix(si-pipeline): /si-image validation fixes from --prompt-only test"
```

---

### Task 3: Validate on Spring test doc --prompt-only(真机验收,不调 API)

**Files:** 无新文件(只读验证;产物在用户指定目录)

**Step 1: 定位 Spring manifest**

```bash
ls /home/xhm/文档/配图测试/Enterprise*.illus.json
```

Expected: 看到 `Enterprise Spring...illus.json`(Stage 1 Spring 真机回归产物,5 张配图,4 mermaid + 1 excalidraw)。

**Step 2: 跑 /si-image --prompt-only**

```text
/si-image /home/xhm/文档/配图测试/Enterprise Spring Core Principles & Architecture Design Guide.illus.json --prompt-only
```

Expected: 检查点表 + 新文件 `Enterprise Spring Core Principles & Architecture Design Guide.image-prompts.json`(覆盖 5 张图,含 mermaid/excalidraw 项)。

**Step 3: 验证产物覆盖全量(prompt-only 路径覆盖全量图,不止 gemini)**

```bash
SPRING=/home/xhm/文档/配图测试/Enterprise Spring Core Principles & Architecture Design Guide
test -f "$SPRING.image-prompts.json" || { echo "ERROR: file not produced"; exit 1; }
python3 -c "
import json
src = json.load(open('$SPRING.illus.json'))
out = json.load(open('$SPRING.image-prompts.json'))
src_ids = sorted(p['id'] for p in src['pictures'])
out_ids = sorted(p['id'] for p in out['pictures'])
assert src_ids == out_ids, f\"id 不匹配: src={src_ids}, out={out_ids}\"
for p in out['pictures']:
    assert 'prompt' in p and p['prompt'], f\"picture {p['id']} prompt 空\"
    assert p['status'] == 'prompted'
    # 行号锚点必须从 manifest 继承(Stage 1.5 硬化字段不能丢)
    src_p = next(s for s in src['pictures'] if s['id'] == p['id'])
    assert p['line'] == src_p['line'], f\"picture {p['id']} line 漂移\"
    assert p['anchor'] == src_p['anchor'], f\"picture {p['id']} anchor 漂移\"
print('OK: 5/5 pictures, 行号/锚点零漂移, prompt 全填充')
"
```

Expected: 末行 `OK: 5/5 pictures, 行号/锚点零漂移, prompt 全填充`。

**Step 4: 验证 manifest 原文不动**

```bash
cd /home/xhm/文档/配图测试
git -C /home/xhm/.claude/skills/smart-illustrator status  # 仓库状态,Spring doc 不在仓库内
python3 -c "
import json
m = json.load(open('$SPRING.illus.json'))
assert all(p['status']=='planned' for p in m['pictures']), 'manifest status changed'
print('OK: Spring manifest 原文 status 全 planned,未改')
"
```

**Step 5: 报告 + 提交产物(JSON,不进仓库)**

```bash
echo "Stage 2 真机验收(--prompt-only):"
echo "  manifest: $SPRING.illus.json"
echo "  prompts:  $SPRING.image-prompts.json"
echo "  count:    5/5, 行号/锚点零漂移"
echo ""
echo "下一步 --g 路径需要 API key + minimax_t2i.py (用户资源),"
echo "用户后续手动跑或单独 spec 验证。"
```

Spring 产物的 manifest + prompts 留在用户测试目录,**不入库**(Stage 1 同处理)。

---

## Self-Review

### Spec coverage(spec §Stage 2 5 项 + §Stage 2 --prompt-only 段 + §待后续 plan 阶段细化第 2/3 项 逐条对应)

| Spec 项 | 对应 Task |
|---|---|
| `-g`:建 images/,取 gemini,style+topic+content 拼 prompt,调 minimax_t2i,重命名 → generated | Task 1 Step B.1-B.5 |
| `-g -full`:按 placeholder 回填 → inserted | Task 1 Step C.1-C.5 |
| `<name.png>` 单图重生 | **本计划不实现**(spec 提及但用户在前序决策中**未要求**单图重生;后续 task 视需要追加;YAGNI 当前不做;在 slash command 失败处理表注明) |
| `<name.png> -y` 单图回填 | 同上(YAGNI) |
| `--prompt-only`:覆盖全量 picture + status="prompted" + prompt 字段 | Task 1 Step A.1-A.4 + Task 2 + Task 3 全量覆盖验证 |
| 后端可插拔 `--backend minimax|gemini`,默认 minimax | Task 1 Step 1 + 全局约束 11;Task 1 Step B.1 + Step D gemini 路径走 prompt-only 分支 |
| gemini 项 prompt = style+"\n\n"+topic+"\n\n"+content | Task 1 Step A.1 / Step B.3 |
| mermaid/excalidraw 项 prompt = content | Task 1 Step A.1 第二条 |
| 每 picture 11 字段继承 + prompt + status | Task 1 全局约束 5 + Step A.2 schema 块 + Task 2 Step 2 Python 校验 |
| prompt 上限 1500 字符 + 裁剪策略 | Task 1 全局约束 4 + 策略 P1 + 失败处理表 |
| 状态机 planned→generated→inserted + prompt-only 分支 prompted | Task 1 全局约束 6 |
| filename 落盘规则(spec §JSON schema) | Task 1 全局约束 7 + Step B.3 重命名 |
| PNG 落盘路径相对 manifest 的 ./images/ | Task 1 Step B.2 + Step C.2 |
| 原 manifest 路径(spec §待后续 plan 阶段细化第 3 项"回填按行精准匹配") | Task 1 Step C.3 placeholder 整行 Edit + 幂等分支 |
| 回填幂等(二次跑不重复插入) | Task 1 Step C.3 幂等分支 |
| 不修改原文 | Task 1 全局约束 10 |
| 非侵入 | Task 1 全局约束 11 + 文件清单验证(Task 1 Step 4 git status 检无作者现有文件被改) |
| PR 友好(minimax 本地保留,gemini 上游) | Task 1 全局约束 11 |

### Placeholder scan

- [x] 无 "TBD"/"TODO"/"implement later"/"fill in details"
- [x] 所有 `--prompt-only` / `-g` / `-full` / `--backend` flag 在 Step 1 参数解析段完整列
- [x] 所有策略 P1 裁剪在失败处理表具体给出(按 content → topic → style 顺序截)
- [x] 所有 1500 字符超限应对具体
- [x] 无 "Similar to Task N"(每 Task 独立完整;Task 3 复用 Spring 路径独立写出)
- [x] spec 第 113 行 11 字段完整列出(id / topic / content / engine / type / line / anchor / placeholder / filename / code + prompt + status 全部明确)

### Type consistency

- JSON 字段:`id / topic / content / engine / type / line / anchor / placeholder / filename / code / prompt / status`(与 spec 第 113 行 + 与 Stage 1 全程一致)
- 占位符格式:`<!-- IMAGE:NNN -->`(3 位零填充,与 Stage 1 一致)
- 文件命名:`{stem}-image.md` / `{stem}.illus.json` / `{stem}.image-prompts.json` / `images/{stem}-img-NNN.png`(全程一致)
- 引擎枚举字面量:`gemini` / `excalidraw` / `mermaid`(无任何变体)
- 状态值字面量:`planned` / `prompted` / `generated` / `inserted` / `error`(`error` 失败时追加,与 spec 状态机互补)
- backend 字面量:`minimax` / `gemini`(`minimax` 为本用户 minimax 后端保留名,未污染作者 gemini 字面量)
- symlink 目标:`~/.claude/commands/si-image.md`(与命令名一致)
- flag 字面量:`--prompt-only` / `-p` / `-g` / `-full` / `--backend`(全小写连字符,符合 CLI 习惯)

### YAGNI check(明确不做)

- `<name.png>` 单图重生 / `-y` 单图回填:spec 提及但前序决策未要求,后续 Task 视需要追加
- `-parallel` 并行调 API:本计划用串行(避免限流,simpler);如用户后续要并行,Stage 2 末尾可加 Task 加 `--parallel` flag + subagent fan-out
- mermaid / excalidraw 生图:本 Stage 完全跳过,留给 Stage 3(/si-chart)

---
