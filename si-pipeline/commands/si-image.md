---
description: smart-illustrator Stage 2 — 从 {stem}.illus.json 出发,生成创意图(minimax 后端)并回填副本占位符;支持 --prompt-only 预览 prompt
argument-hint: <manifest.illus.json> [--prompt-only | -p] [-g] [-full] [--backend minimax|gemini] [<file.png> [-y]]
allowed-tools: Read Write Edit Bash Glob
---

# /si-image — Stage 2:创意图生成(minimax 后端)

> 非侵入式增强:不修改作者任何现有文件;调用用户已有 `/home/xhm/图片/minimax_t2i.py` 出 PNG;按 spec 占位符回填。

## 输入

`$ARGUMENTS` = `<manifest.illus.json> [--prompt-only|-p] [-g] [-full] [--backend minimax|gemini] [<file.png> [-y]]`

- 第 1 段(必填):manifest 绝对或相对路径(`~` 自动展开);前置条件:`status` 全是 `planned`(否则报错让人跑 Stage 1 修)
- 后续段:flag 组合,无序;互斥:
  - `--prompt-only` / `-p`:不调 API,只导出 `prompt` 文本(JSON)
  - `-g`:走生成;不指定则**仅打印检查点表 + 建议跑 `--prompt-only` 预览**(防误触 API 花钱)
  - `-full`:生成后回填副本(必须配 `-g`)
  - `--backend minimax|gemini`:默认 `minimax`;`gemini` 模式只产出 `status="prompted"` JSON(不调 API,给上游 generate-image.ts 取用)
- **单图模式**(第 2 段为 `<file.png>` 形式):按图片名定位单张重生 / 插入
  - 触发条件:第 2 段以 `.png` 结尾(必须是 manifest 中某 picture 的 `filename` 字段 basename,允许带或不带 `images/` 前缀)
  - `<file.png>` 后无 `-y`:仅重生(覆盖原 PNG),`status="generated"`
  - `<file.png> -y`:重生 + 回填到副本占位符位置,`status="inserted"`
  - 与全量 `-g / -g -full` **互斥**(全量模式不接 `.png` 第 2 段)
  - 单图模式允许 `status` ∈ `{"planned", "generated", "inserted", "error"}`(允许「重新生成已插入的图」)
  - 仅处理 `engine == "gemini"` 的 picture;mermaid/excalidraw 项交给 `/si-chart`

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
   - `--prompt-only`:**不写原 manifest**,只产新文件 `{stem}.image-prompts.json`,其内每 picture `status="prompted"`(不动副本)
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
- **单图模式识别**:扫描非第 1 段的 token,若任一 token 以 `.png` 结尾 → 触发单图模式:
  - 把该 `.png` token 取出,得 `target_filename`;剩余 token 中若有 `-y` → `insert_after=true`,否则 `false`
  - 此时**忽略**全量模式的所有 flag(`--prompt-only` / `-g` / `-full` / `--backend` 都报错"单图模式与全量模式互斥")
- 校验 flag 互斥:`-p` 与 `-g` 互斥(同时传 → 报错并提示"二者选一")
- 校验 `-full` 必须配 `-g`(否则报错并提示)
- 若无 `-p` 也无 `-g`(仅传了 manifest)→ 走检查点路径(只打印建议)
- `backend` 默认 `minimax`(单图模式沿用)

### 2. 读 manifest(分析用 + 后写回)

- `Read` manifest;`Bash python3 -c "import json; m=json.load(open('PATH')); ..."` 校验 schema:
  - `m.pictures` 是 list
  - 每 picture 含 `id/topic/content/engine/type/line/anchor/placeholder/filename/code/status`
  - **全量模式(无单图文件名)**:所有 picture.status == `"planned"`(否则**报错并列出 非 planned 的 id 让人修**)
  - **单图模式(有 `target_filename`)**:不校验全量状态;但要求 `target_filename` basename 能匹配某 picture 的 `filename` 字段 basename(否则报错"图名不在 manifest 中")
- 得出 `{stem}`(`manifest_path` 去目录与 `.illus.json` 后缀)
- 计算 `./images/` 路径(相对 manifest 所在目录)
- **单图模式**额外:`target_filename` 归一化(去前缀 `images/`,只留 basename)→ 在 manifest.pictures 里 grep `os.path.basename(p['filename']) == target_basename`,得到 `target_picture`(单元素);若 0 个匹配报错,> 1 个匹配报错(规范钉死 filename 唯一)

### 3. 选目标 picture

过滤 `engine == "gemini"` 的 picture(本 Stage 唯一目标;mermaid/excalidraw 跳过并在检查点表标注"留给 Stage 3 /si-chart")。

记 `gemini_items = [{picture}, ...]`,N = len。

### 4. 选择路径

依据 flag:

- **路径 A(`/p` 或 `--prompt-only`)**:跳到 Step A
- **路径 B(`-g` without `-full`)**:跳到 Step B
- **路径 C(`-g -full`)**:跳到 Step B 后接 Step C
- **路径 D(无 flag)**:跳到 Step D
- **路径 E(单图模式:`target_filename` 已设)**:跳到 Step E;若 `insert_after=true` 再追加 Step F

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
      "filename": "images/{stem}-img-001.png"  // gemini/excalidraw 用;mermaid 嵌码项为 ""
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
- `Bash ls -t "<images_dir>/_tmp/" | head -1` 取最新生成的 `minimax-{i}.jpeg`(加 `-t` 按修改时间排序取最新)
- `Bash mv "<images_dir>/_tmp/minimax-{i}.jpeg" "<images_dir>/{stem}-img-NNN.png"` 重命名(.jpeg → .png 仅文件重命名;内容字节不动)
- `Bash rm -rf "<images_dir>/_tmp"` 清理

B.4 改写原 manifest 对应 picture(不是另存,是**就地修改** `manifest_path`):

- `filename`:显式写盘后的相对路径
- `status`:`"generated"`
- **用 `Write` 整 manifest 文件**(因 `Edit` 在 JSON 行级不稳定;不要用 `Edit` 部分覆盖)

B.4.1 **写后回读校验** `Read manifest`,确认目标 picture 的 `filename` + `status` 已落地;漏则重写

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

C.4.1 **写后回读校验** `Read manifest`,确认所有目标 picture 的 `status="inserted"` 已落地;漏则重写

C.5 打印完成报告 + 检查点表

### Step E: 单图重生(按文件名,覆盖 PNG)

> 触发条件:`target_filename` 已设;与 Step A/B/C **互斥**(全量模式不接 `.png` 第 2 段)。

E.1 校验 `target_picture.engine == "gemini"`(只有 gemini 由 /si-image 出 PNG;mermaid/excalidraw 走 /si-chart)。

E.2 校验 `target_picture.status` ∈ `{"planned", "generated", "inserted", "error"}`(允许「重新生成已插入的图」)。

E.3 校验 `backend == "minimax"` 时 `MINIMAX_IMAGE_API_KEY` 或 `MINIMAX_API_KEY` env 必须设置(`Bash test -n "$MINIMAX_IMAGE_API_KEY$MINIMAX_API_KEY" || { echo "❌ 请先设置 MINIMAX_IMAGE_API_KEY 环境变量"; exit 1; }`)。

E.4 构造本图 prompt(同 Step A.1 的 gemini 项拼接规则):`prompt = style + "\n\n" + topic + "\n\n" + content`;长度校验 < 1500;超则 P1 裁剪。

E.5 `Bash mkdir -p "<images_dir>"` 建输出目录。

E.6 调 API + 覆盖 PNG(**直接写到 `target_picture.filename` 的绝对路径**):

- `Bash`:`/home/xhm/图片/minimax_t2i.py "<prompt>" --out "<images_dir>/_tmp/" --ratio "16:9" --format base64 --n 1 2>&1 | tail -20`
- `Bash ls -t "<images_dir>/_tmp/" | head -1` 取最新生成的 `minimax-{i}.jpeg`
- `Bash mv -f "<images_dir>/_tmp/minimax-{i}.jpeg" "<absolute_target_png_path>"` 覆盖
- `Bash rm -rf "<images_dir>/_tmp"`

E.7 改写 manifest(就地):

- `filename`:已是 `target_picture.filename`(沿用,无需改)
- `status`:`"generated"`(成功)/`"error"`(失败)
- **用 `Write` 整 manifest 文件**(同 Step B.4)
- **写后回读校验** `Read manifest`,确认目标 picture 的 `status="generated"` 已落地

E.8 检查点表:打印「单图重生 → 覆盖 `<path>` + status=generated」

E.9 若 `insert_after == true` → **继续 Step F**(否则结束)

### Step F: 单图插入(回填副本,要求 `-y`)

> 触发条件:Step E 成功后 `insert_after=true`。等价于全量路径 C 的「单 picture 版本」。

F.1 校验 `target_picture.status == "generated"`(必须 Step E 成功重生,或本来就 generated)。

F.2 `Read` 副本 `{stem}-image.md`。

F.3 `Bash grep -n "<!-- IMAGE:NNN -->" "<copy_path>"` 定位 `target_picture.placeholder`(NNN = target_picture.id 的 3 位零填充)在副本中的行号。

- 若 0 命中:报错"占位符丢失,可能 Stage 1 重跑或用户手改了";**不**强插
- 若 > 1 命中:报错"占位符重复,manifest 与副本不一致,人工修"

F.4 `Edit` 副本,`old_string` = `<!-- IMAGE:NNN -->\n`(整行),`new_string` = `![](<target_picture.filename>)\n`

- **幂等**:若命中行已是 `![](<target_picture.filename>)`,跳过 Edit
- 若命中行已是 `![](其他 filename>)`:这是「替换」语义,直接替换(用户用 -y 就是想替换)

F.5 改写 manifest:target_picture.status = `"inserted"`(`Write` 整 manifest)

F.5.1 **写后回读校验** `Read manifest`,确认 `status="inserted"` 已落地

F.6 打印完成报告:「单图重生 + 插入 → `<copy_path>` 第 L 行的 placeholder 已替为 `![](<filename>)`」

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
| manifest 中存在 status != `"planned"` 的 picture(**全量模式**才校验) | 报错列出非 planned 的 id;提示先跑 Stage 1 重置 |
| **单图模式 `<file.png>` 但 manifest 找不到匹配** | 报错"图名不在 manifest 中";列出当前 manifest 中所有 `filename` 供对照 |
| **单图模式 `<file.png>` 匹配 > 1 个 picture**(filename 冲突) | 报错"filename 不唯一,规范违反";列出匹配列表 |
| **单图模式 `<file.png>` 但 engine != gemini** | 报错"单图重生只支持 gemini;excalidraw/mermaid 走 /si-chart" |
| **单图模式与全量 flag 同时传**(`--prompt-only` / `-g` / `-full` / `--backend`) | 报错"单图模式与全量模式互斥" |
| `--prompt-only` 与 `-g` 同时传 | 报错"二者选一" |
| `-full` 不配 `-g` | 报错"必须有 -g 才有 -full" |
| 无 manifest_arg | 报错"第 1 段必填 manifest 路径" |
| MINIMAX_IMAGE_API_KEY / MINIMAX_API_KEY 未设置(`-g` / 单图模式 时) | 报错并提示:`export MINIMAX_IMAGE_API_KEY=...` |
| `minimax_t2i.py` 调用失败(API 报错 / 超时) | 全量:该 picture `status="error"`,继续下一张。单图:target_picture.status="error",**不**进入 Step F(即使传了 `-y`) |
| prompt 拼接超 1500 字符 | 应用策略 P1:`content` 截到 1500 - len(style) - len(topic) - 4(分隔符 `\n\n` × 2);若仍超,继续截 `topic`;最后截 `style`;若 style 也撑爆,报错让人手改。**裁剪后必须在 `_meta.truncated_prompts` 记录 id 列表**(--prompt-only 路径) |
| `<!-- IMAGE:NNN -->` 在副本中找不到(回填时,全量 C 或单图 F) | 报错"占位符丢失,可能 Stage 1 重跑或用户手改了";**不**强插(避免错位) |
| JSON 写回后字段丢了 | Step A.2 / Step B.4 / Step E.7 / Step F.5 写后立即 `Read` 回头校验 11 字段全 + 新增 prompt 与 status;漏则重写 |
| minimax 返回的不是 jpeg | 不假设扩展名,read first bytes 判 mime;非 jpeg 则改为 `.bin` 不改 `.png`(`filename` 改后缀;记 warning) |
| 单图模式 Step E 失败时还传了 `-y` | 报错提示"Step E 失败,跳过 Step F";不部分回填 |

## 输出文件清单

```
{stem}-image.md                       # 副本(全量 -full 或单图 -y 时改 placeholder → ![](path)行;原文不动)
{stem}.illus.json                     # manifest(全量 -g / -full 或单图模式 时改 status;原文不动)
{stem}.image-prompts.json             # --prompt-only 路径才产出(覆盖全量 picture,prompted)
./images/                             # 全量 -g / -full 或单图模式 时建目录
└── {stem}-img-NNN.png                # 重命名后的 PNG(每个 gemini picture 一张;单图模式只改命中的那张)
```

## 后续衔接

- `/si-chart {manifest}` — Stage 3 跑 mermaid/excalidraw 项,回填时复用此 Stage 的同一副本(状态机不会冲突,只处理 `status != "inserted"` 项)
- `/si-all {manifest}` — Stage 2+3 一键;若已跑 Stage 2 部分插入,Stage 3 只补未完成项
