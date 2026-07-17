---
description: smart-illustrator Stage 3 — 从 {stem}.illus.json 出发,为 mermaid/excalidraw 项生成 code 并渲染 PNG,回填副本占位符;支持 --regen + -content
argument-hint: <manifest.illus.json> [-full] [--regen <picture_id> | -content "..." | --regen <picture_id> -content "..."] [-mermaid | -excalidraw] [--theme light|dark]
allowed-tools: Read Write Edit Bash Glob
---

# /si-chart — Stage 3:结构图生成(mermaid + excalidraw)

> 非侵入式增强:不修改作者任何现有文件;调用作者的 `mermaid-export.ts` / `excalidraw-export.ts` 出 PNG;按 spec 占位符回填。

## 输入

`$ARGUMENTS` = `<manifest.illus.json> [-full] [--regen <picture_id> | -content "..." | --regen <picture_id> -content "..."] [-mermaid | -excalidraw] [--theme light|dark]`

- 第 1 段(必填):manifest 绝对或相对路径
- `-full`:渲染后回填副本(必须在所有目标 picture 都生完图后用)
- **目标 picture 指定方式(三选一)**:
  - `--regen <picture_id>`:**显式指定**;用 picture 的 `id`(数字,1 起)定位。必须配 `-content`(否则报错"需要 -content")
  - `-content "..."`(无 `--regen`):**LLM 自动匹配**;Claude 读 manifest 所有 picture 的 `topic`/`content`/`anchor`,自己挑出 1 个最匹配的;若 0 匹配报错,> 1 匹配歧义则取分数最高的 + 列出候选让用户确认
  - `--regen <picture_id> -content "..."`:**显式 + 补充上下文**;id 锁定,`-content` 作为重生时补充上下文(直接覆写 `content` 字段)
- `-mermaid`:只处理 mermaid 项(默认:全 mermaid + excalidraw)
- `-excalidraw`:只处理 excalidraw 项
- `--theme light|dark`:mermaid 主题,默认 `light`(对齐浅色文章配图)

## 全局约束(钉死,违反即错)

1. **输入校验**:manifest 路径必须存在;manifest 中所有目标 picture 的 `status` ∈ `{"planned", "generated"}`(已 `inserted` / `error` 跳过)。**单图模式(`--regen <id>` / `-content` 智能匹配)**只校验命中的那 1 张 picture,不校验全量状态。
2. **目标 picture**:`engine == "mermaid" || engine == "excalidraw"`(gemini 项跳过,留给 Stage 2 /si-image)
3. **Code 生成(规则)**:
   - mermaid 项:`code` 写进 `manifest.pictures[i].code`(mermaid 语法文本)
   - excalidraw 项:`code` 写进独立文件 `images/{stem}-img-NNN.excalidraw`(Excalidraw JSON 数组),`manifest.pictures[i].code` 留 `""`(excalidraw JSON 太长,不进 manifest)
4. **渲染规则**:
   - mermaid:`npx -y bun <repo>/scripts/mermaid-export.ts --content "<code>" --output "<images_dir>/{stem}-img-NNN.png" --theme <theme>`(`--content` 内联,免写临时 .mmd)
   - excalidraw:`npx -y bun <repo>/scripts/excalidraw-export.ts -i "<excalidraw_path>" -o "<images_dir>/{stem}-img-NNN.png" -s 2`
5. **filename 规则**(spec §JSON schema):
   - mermaid 项:`""`(嵌码,无 PNG)
   - excalidraw 项:`images/{stem}-img-NNN.png`(必须落盘)
6. **PNG 落盘**:相对 manifest 所在目录的 `./images/`,文件名严格 `{stem}-img-NNN.png`(excalidraw 才有 PNG;mermaid 默认嵌码)
7. **Excalidraw 源文件落盘**:`images/{stem}-img-NNN.excalidraw`(必读 `references/excalidraw-guide.md`;`boundElements: null`、`updated: 1`、不加 `frameId`/`versionNonce`)
8. **回填幂等**:二次跑不重复插入;`Read` 副本后定位 `<!-- IMAGE:NNN -->` 整行,`Edit` 替换;幂等检查同 Stage 2
9. **状态机**:
   - 默认检查点:`planned` / `generated`(不动,只 plan)
   - `--regen <id>`(不带 `-full`):只重生 code + 渲染 → status="generated",**不动副本**
   - `-full`:回填副本;meermaid 用 ```mermaid code block,excalidraw 用 `![](images/...)` → status="inserted"
   - 失败:status="error"
10. **行号一致性**:`-full` 回填后 `line` / `anchor` 不重新计算(占位符行还在,只是变成图引用;若用户后续删除/移动 placeholder,需重跑 Stage 1)
11. **非侵入**:不修改 manifest 原文以外的任何文件(spec 钉死的非侵入);不改 `{stem}.md`,只在 `{stem}-image.md` 副本上工作
12. **PR 友好**:完全复用作者的 `mermaid-export.ts` / `excalidraw-export.ts`,零改作者代码

## 执行步骤

### 1. 参数解析

- 切 `$ARGUMENTS`,得 `manifest_path` / flag 集合(`full` / `regen` / `content` / `engine_filter` / `theme` / `target_id` 或 `auto_target`)
- `~` 展开
- 校验 `manifest_path` 必须以 `.illus.json` 结尾
- **目标选择**:
  - `--regen <id>` 已设 → `target_id = <id>`(要求 `--regen` 必须配 `-content`;`-content` 作为补充上下文覆写到 `content` 字段后重生)
  - 只有 `-content "..."` → `auto_target = true`;`target_id = None`(Step 3 由 LLM 匹配)
  - 既无 `--regen` 也无 `-content` → 走默认(全量 planned/generated)
- `-mermaid` / `-excalidraw` 互斥(同时传 → 报错)
- `theme` 默认 `light`

### 2. 读 manifest + 校验

- `Read` manifest;`Bash python3 -c "import json; m=json.load(open('PATH')); ..."` 校验 schema:
  - `m.pictures` 是 list
  - 每 picture 含 `id/topic/content/engine/type/line/anchor/placeholder/filename/code/status`
- 得出 `{stem}` 与 `./images/` 路径

### 3. 选目标 picture

过滤规则:
- 默认:`engine in {"mermaid", "excalidraw"}` AND `status in {"planned", "generated"}`
- `-mermaid`:再 filter `engine == "mermaid"`
- `-excalidraw`:再 filter `engine == "excalidraw"`
- `--regen <id>`:只看该 id,且其 engine ∈ {mermaid, excalidraw}
- **`auto_target == true`(只有 `-content` 无 `--regen`)**:Claude 读 manifest,对照 `-content` 自然语言描述,对每个 candidate picture 打匹配分:
  - 关键词命中:`topic`/`anchor`/`content` 任一字段含 `-content` 里的关键词 → +分
  - 章节锚点命中:`-content` 提到「第 N 节 / 第 X 章 / 某标题」 → `anchor` 含该标题的 → +分
  - 类型命中:`-content` 提到「流程图 / 时序图 / 对比图」 → `type` 对应的 → +分
  - **阈值**:最高分 picture 唯一 → 直接用;最高分有并列 ≥ 2 → 列出前 3 候选 + 各自的命中证据,要求用户**手动 `--regen <id>` 消歧**;全 0 分 → 报错"-content 描述与 manifest 不匹配"
  - 锁定后 `target_id = <match_id>`,正常走 `--regen <id>` 流程

记 `targets = [...]`,N = len。

### 4. 选择路径

依据 flag:
- **路径 D(无 flag,只 plan)**:跳到 Step D
- **路径 R(`--regen <id>` without `-full`,或 `-content` 独立 / `-content` 配 `--regen`)**:跳到 Step R
- **路径 F(`-full`)**:跳到 Step F
- **路径 RF(`--regen <id> -full`)**:跳到 Step R 后接 Step F(只对指定 id 回填)
- **路径 AF(`-content "..." -full`,auto target + 回填)**:跳到 Step R(LLM 选 id)后接 Step F(只对选中 id 回填)

### Step R: --regen(重生 code + 渲染,不动副本)

R.1 对每 target picture:

- mermaid 项:
  - **生成 code**(Claude 按 `topic` + `content` + `-content` 覆写 + `anchor` 写 mermaid 语法):写入 `manifest.pictures[i].code`
  - 校验:`code` 非空 + 含 `flowchart`/`graph`/`sequenceDiagram`/`classDiagram`/`stateDiagram`/`erDiagram`/`gantt`/`pie`/`gitGraph` 之一(简单校验)
- excalidraw 项:
  - **生成 JSON**(Claude 按 `topic` + `content` + `-content` + `anchor` 写 Excalidraw JSON 数组):写入 `images/{stem}-img-NNN.excalidraw`
  - **必读** `references/excalidraw-guide.md`(用户级)再写;校验 `boundElements: null`/`updated: 1`/无 `frameId`
  - `manifest.pictures[i].code` 留 `""`

R.2 校验 `images_dir` 存在:`Bash mkdir -p "<images_dir>"`(若不存在)

R.3 mermaid 项渲染:

```
Bash npx -y bun <repo>/scripts/mermaid-export.ts \
  --content "<code>" \
  --output "<images_dir>/{stem}-img-NNN.png" \
  --theme <theme>
```

> 注意:excalidraw 项本身**不生 PNG**——但 Stage 3 的 excalidraw 项**仍然要生 PNG**(spec §Stage 2 excalidraw 必须导出 PNG)。所以 excalidraw 走 R.4。

R.4 excalidraw 项渲染:

```
Bash npx -y bun <repo>/scripts/excalidraw-export.ts \
  -i "<images_dir>/{stem}-img-NNN.excalidraw" \
  -o "<images_dir>/{stem}-img-NNN.png" \
  -s 2
```

> ⚠ Playwright + Firefox 必须安装(per CLAUDE.md)。若失败 → status="error",继续下一张。

R.5 失败:该 picture status="error";继续下一张;最后打印 error 列表

R.6 **就地 update** manifest:`code`(mermaid)/`filename`(excalidraw)+ `status`(`generated` for success, `error` for fail)

R.6.1 **写后回读校验** `Read manifest`,确认目标 picture 的 `code` + `filename` + `status` 已落地;漏则重写

R.7 检查点表:打印"已处理 N/M + 失败列表";**不直接回填**,等用户手动加 `-full`

### Step F: -full(回填副本)

F.1 校验所有目标 picture 的 `status` ∈ `{"generated", "error"}`(若全是 `planned` → 报错"请先跑默认或 --regen 生 code")

F.2 `Read` 副本 `{stem}-image.md`

F.3 对每 `status=="generated"` 的目标 picture:

- mermaid 项:定位 `<!-- IMAGE:NNN -->` 行,**替换为** ```mermaid\n<code>\n``` 围栏代码块
- excalidraw 项:定位 `<!-- IMAGE:NNN -->` 行,**替换为** `![](images/{stem}-img-NNN.png)`(同 Stage 2)
- **幂等**:若已是目标形式(```mermaid block 或 ![](...))→ 跳过
- 用 `Edit`(`old_string` 含 placeholder 整行)

F.4 **就地 update** manifest:所有目标 picture 的 `status` 改 `"inserted"`(`Write` 整 manifest,因 Edit 在 JSON 行级不稳定)

F.4.1 **写后回读校验** `Read manifest`,确认所有目标 picture 的 `status="inserted"`;漏则重写

F.5 打印完成报告 + 检查点表

### Step D: 无 flag(只 plan)

D.1 打印检查点表(N,引擎分布,目标 PNG 路径,code 已就绪数)

D.2 提示:

```text
[Stage 3 路径建议]
────────────────────
N=<N>  mermaid=<m>  excalidraw=<e>  code 就绪=<c>/<N>

下一步:
- /si-chart <manifest> -content "..."                       智能匹配 id 重生(自然语言定位,无需记 id)
- /si-chart <manifest> --regen <id> -content "..."         显式 id 重生(更精确)
- /si-chart <manifest> -full                                全部回填副本
- /si-chart <manifest> --regen <id> -content "..." -full    重生 + 回填
- /si-chart <manifest> -content "..." -full                 智能匹配 + 回填
- /si-all <manifest>                                        Stage 2 + 3 一键
```

D.3 **不**自动推进;等用户决策

### 8. 检查点表(所有路径通用,字段值不同)

```text
[Stage 3 检查点]
────────────────────────────────────────────────────────────────
编号 │ 引擎       │ 行号 │ 章节锚点                         │ 状态
─────┼────────────┼──────┼──────────────────────────────────┼────────────
001  │ mermaid    │ L37  │ #### 1.2 IoC 容器与依赖注入 (DI) │ inserted
002  │ excalidraw │ L500 │ #### 8.2 构造器注入的运作原理     │ generated
...

✅ manifest:<manifest_path>
✅ 副本:<copy_path>(仅 -full 时改动)
✅ 图片目录:<images_dir>(仅渲染/回填时落盘)
✅ excalidraw 源:<images_dir>/{stem}-img-NNN.excalidraw

请确认:
- 输出 OK?→ 进入 /si-all 收尾或提 PR
- 不 OK?→ 告诉我「改 XXX:YYY→ZZZ」
```

## 失败处理

| 情况 | 应对 |
|---|---|
| manifest 路径不存在 / 非 `.illus.json` | 报错并提示正确路径 |
| `--regen` 不配 `-content`(显式 id 模式) | 报错"--regen 必须配 -content"(若只想用 `-content` 智能匹配,去掉 `--regen` 即可) |
| `-content` 智能匹配:**全 0 分** | 报错"-content 描述与 manifest 不匹配";列出 manifest 所有 picture 的 `topic`+`anchor` 供对照 |
| `-content` 智能匹配:**并列最高分 ≥ 2** | 报错并列出前 3 候选 + 各自命中证据;提示用户改用 `--regen <id>` 消歧 |
| `-content` 智能匹配:**唯一匹配但 engine=gemini** | 报错"-content 命中的 picture 是 gemini 引擎,该走 /si-image -g";列出命中的 id |
| `-mermaid` 与 `-excalidraw` 同时传 | 报错"二者选一" |
| 目标 picture 全是 `inserted` | 提示"已完成,无需再处理" |
| mermaid code 校验失败(不含合法关键字) | 该 picture status="error";打印"code 写得不合法" |
| excalidraw JSON 校验失败(违反 references/excalidraw-guide.md) | 该 picture status="error";打印具体违反规则 |
| mmdc 未安装 / excalidraw-export 依赖缺失 | 报错并提示安装命令(per CLAUDE.md) |
| PNG 渲染失败 | 该 picture status="error";继续下一张 |
| `<!-- IMAGE:NNN -->` 在副本中找不到(回填时) | 报错"占位符丢失,可能 Stage 1 重跑或用户手改了";**不**强插(避免错位) |
| JSON 写回后字段丢了 | Step R.6 / F.4 写后立即 `Read` 回头校验;漏则重写 |

## 输出文件清单

```
{stem}-image.md                       # 副本(仅 -full 时改 placeholder → mermaid block 或 ![](path)行;原文不动)
{stem}.illus.json                     # manifest(渲染/回填时改 code/filename/status;原文不动)
./images/                             # 渲染时建目录
├── {stem}-img-NNN.png                # excalidraw 渲染出的 PNG
└── {stem}-img-NNN.excalidraw         # excalidraw 源 JSON(便于后续编辑)
```

> mermaid 项**不**生成独立 PNG;code 嵌入 `{stem}-image.md` 的 ```mermaid 围栏块;GitHub/大多数 MD 渲染器自动渲染。

## 后续衔接

- `/si-all {manifest}` — Stage 2 + 3 一键;若已跑 Stage 2 插入部分 gemini,Stage 3 只补 mermaid/excalidraw
- 提交 PR:`feat/si-pipeline` 分支 13 → 15 commits,纯增量,作者文件未动