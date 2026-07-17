---
description: smart-illustrator 一键 — Stage 2(/si-image)+ Stage 3(/si-chart)串行;从 {stem}.illus.json 到回填副本占位符一键完成
argument-hint: <manifest.illus.json> [--backend minimax|gemini] [--theme light|dark] [--dry-run]
allowed-tools: Read Write Edit Bash Glob
---

# /si-all — Stage 2 + Stage 3 一键

> 非侵入式增强:不修改作者任何现有文件;等价于 `/si-image -full && /si-chart -full`。
> **强约定**:此命令**直接出图 + 回填副本**,不带预览。**先跑 `--dry-run` 看检查点表再确认**(防误触 API 花钱)。

## 输入

`$ARGUMENTS` = `<manifest.illus.json> [--backend minimax|gemini] [--theme light|dark] [--dry-run]`

- 第 1 段(必填):manifest 路径
- `--backend minimax|gemini`:传给 `/si-image`(默认 `minimax` 本地)
- `--theme light|dark`:传给 `/si-chart`(默认 `light`)
- `--dry-run`:只读不写,打印检查点表 + 提示路径建议,不调 API、不渲染、不回填

## 全局约束(钉死,违反即错)

1. **状态机门禁**:manifest 中所有 picture.status 必须为 `"planned"` 才能直接跑(否则报错并列出 非 planned 的 id 让人修)
2. **顺序保证**:Stage 2 先跑(出 gemini 图),Stage 3 后跑(出 mermaid/excalidraw);**严禁并发改同一 manifest**(防止状态机冲突)
3. **图片落盘统一**:`./images/{stem}-img-NNN.png`;excalidraw 源 `./images/{stem}-img-NNN.excalidraw`;mermaid 不生 PNG(对齐 Stage 3 Constraint #6)
4. **回填统一**:`-image.md` 副本被 Stage 2/3 共同修改;**幂等**:重复跑不会重复插入
5. **状态机终态**:所有 picture.status = `"inserted"` 才算成功;中间任何一张失败 → 整体 status=`"error"`,**不**回滚(已成功的保留 inserted)
6. **非侵入**:不修改 manifest 原文以外的任何文件(spec 钉死的非侵入);不改 `{stem}.md`,只在 `{stem}-image.md` 副本上工作
7. **PR 友好**:同 Stage 2 / Stage 3,零改作者代码

## 执行步骤

### 1. 参数解析

- 切 `$ARGUMENTS`,得 `manifest_path` / `backend` / `theme` / `dry_run`
- `~` 展开
- 校验 `manifest_path` 必须以 `.illus.json` 结尾
- `backend` 默认 `minimax`;`theme` 默认 `light`

### 2. 读 manifest + 校验(强约束)

- `Read` manifest;`Bash python3 -c "import json; ..."` 校验 schema:
  - `m.pictures` 是 list,11 字段齐全
  - **所有 picture.status == `"planned"`**(否则**报错并列出 非 planned 的 id**,**不**继续)
- 得出 `{stem}` 与 `./images/` 路径

### 3. 检查点表 + dry-run 分支

#### 路径 DR(`--dry-run`)

DR.1 打印检查点表:

```text
[si-all 检查点表]
────────────────────────────────────────────────────────────────
编号 │ 引擎       │ line │ anchor                          │ 现状
─────┼────────────┼──────┼─────────────────────────────────┼──────
001  │ gemini     │ L37  │ #### 1.2 ...                    │ planned
002  │ mermaid    │ L191 │ #### 三层架构协同代码展示        │ planned
003  │ excalidraw │ L500 │ #### 8.2 构造器注入的运作原理    │ planned
────────────────────────────────────────────────────────────────
N=<N>  gemini=<g>  mermaid=<m>  excalidraw=<e>
backend: <backend>  theme: <theme>

下一步:
- 跑 /si-all <manifest>                     一键出图 + 回填
- 跑 /si-image <manifest> --prompt-only     只看 gemini prompt
- 跑 /si-chart <manifest> --regen <id> ...  重生某图 code
```

DR.2 **不**调用任何 API / 渲染 / 回填。**结束**(不进入 Step 4)。

### 4. Stage 2(gemini 出图)

> 此步**等价于** `/si-image <manifest> -g -full --backend <backend>`。

4.1 **前置校验**:`-g` 需要 `MINIMAX_IMAGE_API_KEY` / `MINIMAX_API_KEY`(若 `backend=minimax`)。没有就**报错**。

4.2 对每个 `engine == "gemini"` 的 picture:
- 构造 prompt(同 Stage 2 全局约束 #3)
- 长度校验(< 1500)
- `Bash`:`/home/xhm/图片/minimax_t2i.py "<prompt>" --out "<images_dir>/_tmp/" --ratio "16:9" --format base64 --n 1 2>&1 | tail -20`
- `Bash mv "<images_dir>/_tmp/minimax-{i}.jpeg" "<images_dir>/{stem}-img-NNN.png"`
- 清理 `_tmp/`
- 失败:该 picture status="error",继续

4.3 改写 manifest:gemini picture 的 `filename` + `status="generated"`

4.4 回填 `-image.md`:对每个 `status=="generated"` 的 gemini picture,`Edit` 替换 `<!-- IMAGE:NNN -->` 为 `![](images/...)`

4.5 改写 manifest:所有成功插入的 gemini picture 的 `status="inserted"`

### 5. Stage 3(mermaid/excalidraw 出图 + 回填)

> 此步**等价于** `/si-chart <manifest> -full --theme <theme>`。

5.1 对每个 `engine == "mermaid"` 且 `status == "planned"` 的 picture:
- **生成 mermaid code**(Claude 按 topic+content+anchor 写)
- 写进 `manifest.pictures[i].code`
- 校验 code 含合法 mermaid 关键字
- 不生 PNG(对齐 Constraint #6)
- 状态:`planned → generated`(code 写好后即 generated,无需渲染)

5.2 对每个 `engine == "excalidraw"` 且 `status == "planned"` 的 picture:
- **生成 Excalidraw JSON**(Claude 按 topic+content+anchor 写)
- 写到 `<images_dir>/{stem}-img-NNN.excalidraw`
- 校验符合 `references/excalidraw-guide.md`
- `Bash npx -y bun <repo>/scripts/excalidraw-export.ts -i "<excalidraw>" -o "<png>" -s 2`(playwright + excalidraw.com,需联网)
- 状态:`planned → generated`

5.3 回填 `-image.md`:
- mermaid:`<!-- IMAGE:NNN -->` → ```mermaid\n<code>\n```
- excalidraw:`<!-- IMAGE:NNN -->` → `![](images/...)`

5.4 改写 manifest:所有成功插入的 mermaid/excalidraw picture 的 `status="inserted"`

### 6. 错误恢复

6.1 若 Step 4 失败:跳过 Step 5,**不**回填,**报错**:"Stage 2 部分失败,后续 Stage 3 未跑。请修 API key 或图片,再单独跑 /si-chart"

6.2 若 Step 5 失败:mermaid/excalidraw 部分失败的 picture status="error",**不影响已 inserted 的**(不回滚)

6.3 重跑 /si-all 是幂等的:已 inserted 的跳过,只处理 planned / error / generated

### 7. 写后回读校验

7.1 `Read manifest` 校验:所有 picture 的 status ∈ {"inserted", "error"};漏则重写

7.2 `Read <stem>-image.md` 校验:无残余 `<!-- IMAGE:NNN -->`(除非该 id 状态为 error)

### 8. 检查点表(完成报告)

```text
[si-all 完成报告]
────────────────────────────────────────────────────────────────
编号 │ 引擎       │ line │ anchor                       │ status
─────┼────────────┼──────┼──────────────────────────────┼──────────
001  │ gemini     │ L37  │ #### 1.2 ...                 │ inserted
002  │ mermaid    │ L191 │ #### 三层架构协同代码展示    │ inserted
003  │ mermaid    │ L214 │ #### 4.2 参数注解的设计意义  │ inserted
004  │ mermaid    │ L372 │ #### 6.3 基于 JDK 动态代理...│ inserted
005  │ excalidraw │ L500 │ #### 8.2 构造器注入的运作原理│ inserted
────────────────────────────────────────────────────────────────
N=5  inserted=<n>  error=<e>
总耗时:<X>s

✅ manifest:<manifest_path>(已更新)
✅ 副本:<copy_path>(已回填)
✅ images/:
   - {stem}-img-001.png  (gemini)
   - {stem}-img-005.png  (excalidraw)
   - {stem}-img-005.excalidraw  (excalidraw 源)
```

## 失败处理

| 情况 | 应对 |
|---|---|
| manifest 路径不存在 / 非 `.illus.json` | 报错并提示 |
| 任一 picture.status != `"planned"` | 报错并列出非 planned 的 id;**不**继续 |
| `--backend minimax` 时缺 API key | 报错并提示 `export MINIMAX_IMAGE_API_KEY=...` |
| minimax_t2i.py 调用失败 | 该 picture status="error",继续下一张,Stage 5 跳过 |
| mermaid code 校验失败 | 该 picture status="error",跳过回填,继续下一张 |
| excalidraw-export.ts 失败(playwright / 联网问题) | 该 picture status="error",跳过回填,继续下一张 |
| mmdc 未安装 / playwright 未装 | 报错并提示安装命令 |
| 副本里找不到 `<!-- IMAGE:NNN -->` | 报错"占位符丢失,可能 Stage 1 重跑或用户手改了";**不**强插 |
| JSON 写回字段丢失 | 写后立即 Read 校验;漏则重写 |
| `--dry-run` 时调了 API | **不会**(dry-run 只读不写) |

## 输出文件清单

```
{stem}-image.md                       # 副本(Stage 2/3 共同修改;原文不动)
{stem}.illus.json                     # manifest(状态机推进;原文不动)
./images/                             # Stage 2/3 共同落盘
├── {stem}-img-001.png                 # gemini 出图(每张 gemini 一张)
├── {stem}-img-005.png                 # excalidraw 出图
└── {stem}-img-005.excalidraw          # excalidraw 源
```

> mermaid 项**不**生成独立 PNG;code 嵌 `{stem}-image.md` 的 fence 块。

## 后续衔接

- 提 PR:`feat/si-pipeline` 分支,纯增量,作者文件未动
- 复用:Stage 1 + Stage 2 + Stage 3 流水线跑完,可直接发文章