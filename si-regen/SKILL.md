---
name: si-regen
description: 对 smart-illustrator / smart-illustrator-minimax 已规划的文章({stem}_images/{stem}.si-plan.json manifest 存在)按编号重生指定图片、重生封面或全量重生。输入格式:si-regen <file.md> --regen N [--regen M ...] 只重画第 N/M 张;si-regen <file.md> --regen cover 只重画封面;si-regen <file.md> --force 无视已有文件全量重画(含封面)。当用户说"重画第 N 张图""图 03 重新生成""这张图重出一次""--regen 2 --regen 5""封面重新生成""全部图 --force 重来""图片重生"等,只要是针对已规划文章的图片/封面重生请求,务必用本 skill。本 skill 只做重生早退:不读原文(不重新分析;唯一例外:--regen cover 且 manifest 无 _meta.cover 时读原文做封面主题轻量提取),mermaid/excalidraw 从 manifest 的 content 重新生成源文件(风格轮换)后渲染,覆盖同名 PNG、更新 manifest status,并按命令规范刷新副本图片引用(按图片行序号整行替换为 base64 data URI 行,定位时排除封面内嵌行;引用缺失按 anchor 定位插入);封面重生后副本封面内嵌行整行刷新为缩略图 `{stem}-cover-thumb.png` 的 base64(640px 宽 ≤200KB,失败回退原图),插入位置读 manifest `_meta.cover.anchor`(缺失/默认"第一个一级标题之后" → 第一个 `# ` 标题后;其他描述 → 正文图 anchor 定位逻辑)。文章尚未规划(manifest 不存在)时不属于本 skill 职责,引导用户先跑完整流程生成 manifest。
compatibility: bash、jq、ffmpeg、python3、bun(npx);~/图片/minimax_t2i.py;~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts 与 excalidraw-export.ts;环境变量 MINIMAX_IMAGE_API_KEY 或 MINIMAX_API_KEY(任一)
---

# si-regen — 文章配图重生(早退路径)

> 把 smart-illustrator-minimax 的"图片重生成"固定动作固化为独立 skill。manifest 是控制平面,一切以它为准。
> 版本同步:smart-illustrator-minimax v3.8 —— 封面内嵌行用缩略图 `{stem}-cover-thumb.png` 的 base64(640px 宽 ≤200KB);封面内嵌行插入位置读 manifest `_meta.cover.anchor`(缺失/默认 → 第一个 `# ` 标题后)。

## 输入与范围

`$ARGUMENTS` = `<file.md> --regen N [--regen M ...]` 或 `<file.md> --regen cover` 或 `<file.md> --force`

- 第 1 段(必填):文章绝对或相对路径(`~` 自动展开,含空格路径必须整体加引号)
- `--regen N`:只重生第 N 张,允许多次指定(`--regen 2 --regen 5` 只重画第 2 和第 5 张)
- `--regen cover`:只重生封面(`{stem}_images/{stem}-cover.png`,v3.4);frontmatter 声明值从 manifest `_meta.cover.filename` 读取(缺失回退约定式 `{stem}-cover.png`);可与 N 混用(`--regen 2 --regen cover`);成功后副本封面内嵌行整行刷新为缩略图 `{stem}-cover-thumb.png` 的 base64,插入位置读 `_meta.cover.anchor`(v3.8)
- `--force`:无视已有 PNG,全量重生所有 pictures **+ 封面**(除非 `--no-cover`)
- `--no-cover`:`--force` 时跳过封面;与 `--regen cover` 同传 → `--no-cover` 优先,忽略 `--regen cover`
- `--cover-ratio <X:Y>`:封面比例,默认 16:9;其他比例先 `python3 ~/图片/minimax_t2i.py -h` 实测,不支持 → 警告回退 16:9
- **本 skill 不含 `-content` 智能匹配**(那是 smart-illustrator-minimax 完整流程的职责);用户提到 `-content` 时,提示改用 `--regen N` 或完整流程

**互斥/优先级(Step 0 无条件检测)**:`--regen` 与 `--force` 同传 → `--force` 优先(警告"已忽略 --regen")。

## 全局铁律

1. **早退铁律(硬规则)**:manifest 存在 + 重生 flag → **绝对不读原文(不重新分析)**。PNG 覆盖成功后执行「副本引用刷新」(规范同命令文件路径 1):**base64 行不含文件名,不能 grep PNG 文件名** —— 副本图片行按顺序对应 picture id(manifest pictures 按 id 升序),第 N 张图 = 第 N 个 `grep -n '^!\[\](data:image/png;base64,'` 匹配行 → python3 脚本整行替换为新 PNG 的 base64 行(**禁用 Edit**,行可达 ~950KB);未命中 → 按 manifest anchor 定位段落、段末空行前插入;副本不存在 → 跳过并报告。**定位正文图行时排除封面行**(以 `![cover](` 开头),封面行不参与正文图计数,仅在封面流程(2.8/Step 3)更新。只动副本图片行,不改其他任何文字。
2. **manifest 是唯一控制平面**:只从 manifest 读 engine/topic/content/source_file/source_prompt,不读原文。mermaid/excalidraw 重生 = **从 content 重新生成源文件(风格轮换规范)→ 渲染 → 覆盖 PNG**;gemini 用 source_prompt。
3. **PNG 命名(作者风格)**:`{stem}_images/{stem}-image-{NN}.png`,**文章目录 {stem}_images/ 子目录**(先 `mkdir -p {stem}_images`),NN 两位零填充从 01;覆盖同名文件。
4. **非侵入(钉死)**:不改 `{stem}.md` 原文;不改 `~/.claude/skills/smart-illustrator-minimax` 本体;不改 smart-illustrator 的 SKILL.md/scripts/styles/references;不复制、不新建脚本 —— 只读复用 `~/图片/minimax_t2i.py` 与 `~/.claude/skills/smart-illustrator/scripts/{mermaid-export,excalidraw-export}.ts`。
5. 边界错误(源文件缺失/API 不可用等)只跳过该图、记录失败,**绝不回退到完整流程的全文分析**。
6. **manifest 铁律(分层约束,措辞绝对化)**:
   - **绝对禁止改动**:manifest 一旦写盘,`pictures` 数组的结构(每张的 `id`/`engine`/`topic`/`content`/`anchor`/`source_file`/`source_prompt` 及数组顺序)与 `_meta` 全部字段(`source`/`source_mtime`/`source_size`/`produced_at`/`total`/`by_engine`),**任何理由、任何步骤(含 `--regen`/`--force`/完整流程)一律禁止修改** —— 它是锚定参考文件,动了会导致副本刷新错位、引擎分发错误、anchor 自愈失效。
   - **唯一允许写入 = `status` 字段**(`planned`→`generated`/`failed`),且**只能由命令脚本的 jq 命令更新,不经大模型判断**。
   - **封面字段例外(v3.4)**:`_meta.cover`(**新增可选字段**,正文 pictures 与 `_meta` 原有字段的铁律不因它松动)由封面流程专用 —— 完整流程写全字段(含 v3.5 新增可选 `filename` 与 v3.8 新增可选 `anchor`,封面文件名 / 内嵌行插入位置描述,anchor 默认"第一个一级标题之后");`--regen cover` 可更新 `prompt` 与 `status`(缺失补写 topic/metaphor 时一并写 `filename`/`anchor`);`--force` 仅更新 `status`(anchor 缺失读取时回退默认)。封面不进入 `pictures`(不插入正文、不参与副本正文图刷新计数;封面行仅在封面流程更新);副本中封面为**双重表示**(v3.7;v3.8 起内嵌行为缩略图 base64):frontmatter `cover:` 声明(程序消费)+ 正文首个标题后 `![cover](data:image/png;base64,...)` 内嵌行(编辑器消费,base64 为缩略图 `{stem}-cover-thumb.png`,与正文图同方式,不参与正文图计数)。
   - **重新规划 ≠ 修改**:原文大改或用户要求「重新分析」时,走完整流程**整体重写** manifest(产生新锚定),禁止复用旧 manifest 逐字段编辑。
   - **触发场景**:发现 manifest 内容与预期不符(如 status 异常)→ **只报错/跳过,不修复、不改写**;提示用户删除 manifest 后重跑完整流程。

## Step 0:定位 + manifest 校验 + 路由

### 0.1 强制 cd

```bash
ARTICLE="$(realpath -m "$FILE")"      # 规范化绝对路径
cd "$(dirname "$ARTICLE")"            # 此后所有相对路径以文章目录为基准解析
```

### 0.2 manifest 定位

```bash
STEM="$(basename "$ARTICLE" .md)"
IMG_DIR="${STEM}_images"              # 该文章全部机器产物目录(manifest/副本/PNG/源文件)
MANIFEST="${IMG_DIR}/${STEM}.si-plan.json"    # 文章目录 {stem}_images/ 子目录
```

不存在 → **报错退出,绝不静默回退完整流程**(旧位置(v3.2 文章目录顶层 / v1 的 /tmp)存在时提示迁移):

```bash
[ -f "$MANIFEST" ] || {
  if [[ -f "${STEM}.si-plan.json" || -f "/tmp/si-plan-${STEM}.json" ]]; then
    echo "[ERROR] manifest 在旧位置,已迁移到 ${MANIFEST},请重跑完整流程刷新"
  else
    echo "[ERROR] manifest 不存在(${MANIFEST}),请先跑一次不带 flag 的完整流程生成"
  fi
  exit 1; }
```

### 0.3 读前 JSON 校验

```bash
jq -e . "$MANIFEST" >/dev/null 2>&1 || { echo "[ERROR] manifest 损坏(${MANIFEST}),请删除后重跑完整流程"; exit 1; }
```

### 0.4 schema 校验

`_meta.schema` 必须为 `si-minimax/v3`。v1/v2 或任何旧版 → **显式拒绝,不做 content 重建**(旧 content 是语义描述,重建必与原图不同):

```bash
[ "$(jq -r '._meta.schema' "$MANIFEST")" = "si-minimax/v3" ] || { echo "[ERROR] 旧版 manifest(${MANIFEST}),请重跑完整流程升级为 v3"; exit 1; }
```

### 0.5 内部一致性

```bash
TOTAL=$(jq '.pictures | length' "$MANIFEST")
META_TOTAL=$(jq '._meta.total' "$MANIFEST")
[[ "$TOTAL" == "$META_TOTAL" ]] || { echo "[ERROR] manifest 内部不一致(_meta.total ≠ pictures 长度)"; exit 1; }
```

### 0.6 互斥/优先级

- `--regen` 与 `--force` 同传 → **`--force` 优先**,警告"已忽略 --regen",按全量执行

### 0.7 陈旧检测(可选,原 v3 有)

```bash
SRC_MTIME=$(stat -c %Y "$ARTICLE"); SRC_SIZE=$(stat -c %s "$ARTICLE")
META_MTIME=$(jq -r '._meta.source_mtime' "$MANIFEST"); META_SIZE=$(jq -r '._meta.source_size' "$MANIFEST")
if [[ "$SRC_MTIME" != "$META_MTIME" || "$SRC_SIZE" != "$META_SIZE" ]]; then STALE=1; fi
```

`STALE=1` → 警告"原文已修改({mtime 对应日期}),图片可能过时",**用户回复「继续」才执行,否则退出**。

### 0.8 路由

| 条件 | 走向 |
|------|------|
| `--force` | Step 2(全量) |
| `--regen N...` | Step 1(单张/多张) |

## Step 1:--regen N 校验(前置全量,任一非法 → 零执行)

收集所有 `--regen` 参数为 `REGEN_IDS`,**先整体校验,通过后才执行** —— 绝不在校验循环里先做任何重生(避免"合法的先做了、非法的后报错"的部分副作用):

```bash
REGEN_FAILED=0
REGEN_COVER=0                        # 1 = 重生集合含 cover(v3.4)
declare -A SEEN=()
for N in $REGEN_IDS; do
  if [[ "$N" == "cover" ]]; then
    REGEN_COVER=1; continue          # 保留字,不参与数字范围校验,执行体见 2.8
  fi
  if ! [[ "$N" =~ ^[0-9]+$ ]]; then            # --regen=3 / --regen abc / --regen 2.5 均非法
    echo "[ERROR] --regen $N: 必须为正整数或 cover"; REGEN_FAILED=1; continue
  fi
  N=$((10#$N))                                 # 去前导零
  [[ -n "${SEEN[$N]}" ]] && continue           # 去重
  SEEN[$N]=1
  if (( N < 1 || N > TOTAL )); then
    echo "[ERROR] --regen $N: picture ID out of range (1-$TOTAL)"; REGEN_FAILED=1
  fi
done
[[ $REGEN_FAILED -eq 1 ]] && exit 1            # 任一非法 → 整体失败,零执行
```

对每个有效 `N`(已去重、已验证范围)执行 Step 2 的分发逻辑;`cover`(REGEN_COVER=1)在正文 id 之后执行 2.8 封面执行体。

## Step 2:engine 分发(执行体,--regen 与 --force 共用)

### 2.1 按 id 查找(禁止 `pictures[N-1]` 下标)

```bash
PIC_JSON=$(jq -e --argjson id "$N" '.pictures[] | select(.id == $id)' "$MANIFEST") || {
  echo "[ERROR] picture $N 不存在"; exit 1; }
```

读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`;PNG 路径:

```bash
PNG="${IMG_DIR}/${STEM}-image-$(printf '%02d' $N).png"   # 文章目录 {stem}_images/ 子目录(先 mkdir -p "${IMG_DIR}"),覆盖同名文件
```

### 2.2 gemini 分支(minimax 调用,契约已实测写死)

> 实测契约(2026-08-01,`python3 ~/图片/minimax_t2i.py -h` 验证):prompt 是**位置参数**,最长 1500 字符;`--out` 是**输出目录**;产物固定 `minimax-0.jpeg`(JPEG 编码 1280×720);**不存在 `--prompt-file` / `--output` 这两个 flag**。调用前若对参数有疑虑,先 `-h` 实测,以实测为准。

```bash
[[ -n "$MINIMAX_IMAGE_API_KEY" || -n "$MINIMAX_API_KEY" ]] || {
  echo "[ERROR] MINIMAX_IMAGE_API_KEY / MINIMAX_API_KEY 均未设置"; exit 1; }
[[ -f ~/图片/minimax_t2i.py ]] || { echo "[ERROR] ~/图片/minimax_t2i.py 不存在"; exit 1; }
```

**prompt 来源**:读 `source_prompt`。两种形态:
- 本身就是完整 prompt 文本 → 直接使用
- 是路径引用(如 `"见 /tmp/si-prompt-01.txt(生成时写入)"`)→ `cat` 该文件取文本

取到的文本写入 `/tmp/si-prompt-{NN}.txt`(HEREDOC,避免 shell 转义),然后 `wc -c` 校验 ≤1500。

**压缩策略(>1500 时,按顺序截断)**:先截 content 尾部,仍超再截 style 尾部;topic 与核心视觉要求(色板/比例/禁忌)必须完整保留。

```bash
cat > /tmp/si-prompt-${NN}.txt << 'EOF'
<prompt 文本,≤1500 字符>
EOF
wc -c /tmp/si-prompt-${NN}.txt              # 超限按压缩策略截断

python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-prompt-${NN}.txt)" \
  --out /tmp/si-out-${NN} --ratio 16:9 \
  && mv /tmp/si-out-${NN}/minimax-0.jpeg "$PNG"
```

**格式统一规范(mv 后必做)** —— 产物 `minimax-0.jpeg` 是 JPEG 编码,`mv` 只换扩展名不改编码,严格按扩展名解析的工具会解码失败:

```bash
if ! file "$PNG" | grep -q "PNG image data"; then
  ffmpeg -y -i "$PNG" -update 1 "$PNG.fix.png" && mv "$PNG.fix.png" "$PNG"
  # 先写临时文件再 mv 覆盖,同路径直写有截断风险;-update 1 抑制 image2 单帧提示噪音
fi
file "$PNG"    # 验证:必须输出 "PNG image data"
```

幂等:已是真 PNG 则直接跳过,无副作用。**仅 gemini 分支需要;mermaid/excalidraw 导出本就是真 PNG,不执行本规范。**

### 2.3 mermaid 分支(重生 = 从 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG)

- 读 manifest 该 picture 的 `content`(+`topic`/`anchor`),按「风格轮换规范」重新生成源文件写入 `"$IMG_DIR/$SOURCE_FILE"`(**禁止 Read 磁盘旧 .mmd 照抄**,只读 manifest content)
- 旧源文件缺失不是错误 —— 重生一律按 content 重建源文件;`source_file` 以 `$IMG_DIR/` 为基准解析(无前缀裸文件名)

```bash
npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts \
  -i "$IMG_DIR/$SOURCE_FILE" -o "$PNG" -w 2400
```

### 2.4 excalidraw 分支(重生 = 从 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG)

- 读 manifest 该 picture 的 `content`(+`topic`/`anchor`),按「风格轮换规范」重新生成源文件写入 `"$IMG_DIR/$SOURCE_FILE"`(**禁止 Read 磁盘旧 .excalidraw 照抄**,只读 manifest content)
- 旧源文件缺失不是错误 —— 重生一律按 content 重建源文件;`source_file` 以 `$IMG_DIR/` 为基准解析(无前缀裸文件名)

```bash
npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts \
  -i "$IMG_DIR/$SOURCE_FILE" -o "$PNG" -s 2
```

### 2.5 未知 engine

不在 gemini/mermaid/excalidraw 枚举(如手改 manifest)→ 报错"picture $N engine 非法,已跳过",纳入失败列表,继续下一张。

### 2.6 status 更新(每张执行后,成功/失败都写)

```bash
jq --argjson id "$N" --arg s "generated|failed" \
  '(.pictures[] | select(.id == $id) | .status) = $s' "$MANIFEST" > "${MANIFEST}.tmp" \
  && mv "${MANIFEST}.tmp" "$MANIFEST"
```

### 2.7 副本引用刷新(成功覆盖 PNG 后、status 更新前执行;只动副本图片行)

对每张成功重生的图:
1. 副本 `{stem}_images/{stem}-image.md` 不存在 → 跳过,报告"副本缺失,引用未刷新"
2. 定位图片行:副本图片行按顺序对应 picture id(manifest pictures 按 id 升序),第 N 张图 = 第 N 个匹配:`Bash grep -n '^!\[\](data:image/png;base64,' "{stem}_images/{stem}-image.md"` 取第 N 个匹配行(行号记入报告);**定位正文图行时排除封面行**(以 `![cover](` 开头的封面内嵌行不参与正文图计数,封面行仅在封面流程(2.8/Step 3)更新)
3. 命中 → python3 脚本整行替换为新 PNG 的 base64 行(禁用 Edit;写临时文件再原子替换):

```bash
python3 - "{stem}_images/{stem}-image.md" "{stem}_images/{stem}-image-{NN}.png" $N << 'PYEOF'
import base64, os, sys
copy_path, png_path, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
b64 = base64.b64encode(open(png_path, "rb").read()).decode()
img = "![](data:image/png;base64," + b64 + ")"
lines = open(copy_path, encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines) if l.startswith("![](data:image/png;base64,")]
if len(hits) < n:
    print(f"[ERROR] 副本图片行不足:需第 {n} 个,实有 {len(hits)} 个", file=sys.stderr)
    sys.exit(2)          # 退出码 2 → 走第 4 步 anchor 兜底
lines[hits[n - 1]] = img
open(copy_path + ".tmp", "w", encoding="utf-8").write("\n".join(lines))
os.replace(copy_path + ".tmp", copy_path)
print(f"刷新第 {n} 张图,行 {hits[n - 1] + 1}(base64 {len(b64)} 字符)")
PYEOF
```

4. 未命中(脚本退出码 2:引用被删/行数不足)→ 读 manifest 该 picture 的 `anchor`,Read 副本定位段落,段末空行前插入 base64 行(插入脚本同命令文件 Step 5.3;唯一 LLM 心跳定位步骤);段落定位失败 → 报告"引用未找到,未插入",不阻塞后续

### 2.8 封面执行体(--regen cover,REGEN_COVER=1 时执行;v3.4)

**只碰封面,不碰正文图片、不重规划正文图**。封面走 minimax(gemini 分支契约),API 天然随机,无需风格轮换。早退原则放宽的唯一例外:仅当 `_meta.cover` 缺失时读原文做轻量主题提取。

1. 封面路径:`COVER_PNG="${IMG_DIR}/${STEM}-cover.png"`(先 `mkdir -p "${IMG_DIR}"`)。**解析封面文件名**(frontmatter 声明与补写统一用):
   ```bash
   COVER_FILE=$(jq -r '._meta.cover.filename // ""' "$MANIFEST")
   [[ -n "$COVER_FILE" ]] || COVER_FILE="${STEM}-cover.png"   # 旧 manifest 缺失 filename → 约定式回退(变量可能含空格,引用一律加引号)
   ```
2. **主题与 prompt 来源**(`jq -r '._meta.cover' "$MANIFEST"`):
   - `prompt` 非空 → 直接用
   - `prompt` 空但 `topic`/`metaphor` 存在 → 按「封面规范」(命令文件)重拼 prompt
   - `_meta.cover` 整个缺失(v3.3 及更早 manifest)→ **唯一例外 Read 原文**:轻量提炼核心概念 + 视觉隐喻,按「封面规范」拼 prompt,补写 `_meta.cover`(topic/metaphor/prompt/ratio/status/**filename**/**anchor**(默认"第一个一级标题之后");只补封面字段,不动 `pictures` 与 `_meta` 原有字段)
3. prompt 写入 `/tmp/si-cover-prompt.txt`(HEREDOC),`wc -c` ≤1500(超限按「封面规范」压缩策略截断:先截场景描述尾部,再截尾缀尾部)
4. 比例 `COVER_RATIO`:默认 16:9;`--cover-ratio` 其他值先 `python3 ~/图片/minimax_t2i.py -h` 实测,不支持 → 警告回退 16:9
5. key/脚本检查(同 2.2)→ 调用:

```bash
python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-cover-prompt.txt)" \
  --out /tmp/si-out-cover --ratio "${COVER_RATIO}" \
  && mv /tmp/si-out-cover/minimax-0.jpeg "$COVER_PNG"
```

6. **格式统一规范**(2.2 末尾:file 检测,JPEG 则 ffmpeg 转码为真 PNG);**缩略图生成(v3.8,格式统一成功后执行)**:封面 PNG 生成/转码成功后额外生成内嵌用缩略图 `{stem}-cover-thumb.png`(命名固定约定式,不进 manifest):`ffmpeg -y -loglevel error -i "$COVER_PNG" -vf "scale=640:-1" -compression_level 9 "${IMG_DIR}/${STEM}-cover-thumb.png"`(640px 宽,实测 ~158KB ≤200KB;生成失败或 ffmpeg 不可用 → **回退用原图 base64 内嵌,不阻塞**,报告中注明"缩略图生成失败,内嵌用原图")
7. 更新 `_meta.cover.status`(成功 generated / 失败 failed,失败不阻塞正文):

```bash
jq --arg s "generated" '._meta.cover.status = $s' "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"
```

8. 成功后 **副本 frontmatter 声明同步**:确保副本 `{stem}_images/{stem}-image.md` frontmatter 含 `cover: $COVER_FILE`(值取自 manifest `_meta.cover.filename`,缺失按约定式回退;python3 脚本,三情形:已有 cover 字段 → 替换;有 frontmatter 无 cover → 块内追加;无 frontmatter → 头部新建 `---` 块;**三情形统一保证闭合 `---` 后为一行空行**(v3.8 根因修复:闭合后无空行会被 MarkText/VSCode 等 frontmatter 正则惰性吞并后续行直至文中下一个 `---`,封面内嵌行不可见);脚本见命令文件路径 4 Step 5 的 3.5);随后执行**封面内嵌行插入/刷新(v3.8)**:插入/刷新 base64 内嵌行 `![cover](data:image/png;base64,{base64})`(base64 由 `base64 -w0 "${IMG_DIR}/${STEM}-cover-thumb.png"` 生成,封面**缩略图**;缺失/生成失败 → 回退原图 `base64 -w0 "${IMG_DIR}/${COVER_FILE}"`,报告中注明);**有 `![cover](data:image/png;base64,` 前缀行 → 整行替换**(封面重生后内容变了,必须刷新,非仅保持;行位置不变,无需 anchor 定位);无 → **读 manifest `_meta.cover.anchor` 定位插入**:缺失/默认"第一个一级标题之后" → 副本第一个 `# ` 一级标题行之后(独占一行,前后各留一个空行);其他描述 → 按正文图 anchor 定位逻辑(Read 副本定位该段落,段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;封面行以 `!` 开头 → 被 `^!` 过滤;刷新定位排除封面行(以 `![cover](` 开头,不参与正文图计数);规范见命令文件 Step 5「封面内嵌行」);副本不存在 → 声明与内嵌行一并跳过,报告"副本缺失,封面声明未写入"

## Step 3:--force 全量

遍历 `jq -r '.pictures[] | .id' "$MANIFEST"` 得到全部 id,对每张按 Step 2 分发执行:
- 逐张从 content 重新生成源文件(风格轮换规范)后渲染覆盖同名 PNG(不管是否已有文件)
- 旧源文件缺失无碍 —— 一律按 content 重建;边界错误(API 不可用/渲染失败)只跳过该图、记录失败
- 每张执行后按 2.6 更新 status

**封面处理(v3.4;`--no-cover` 时整步跳过)**:正文遍历完成后执行封面重生(执行体同 2.8 第 2-8 步,但**不读原文**):
- `_meta.cover.prompt` 非空 → 用存的 prompt 按 `--cover-ratio`(默认 16:9)重生
- `_meta.cover` 缺失 → **跳过封面**,报告"封面未规划(manifest 无 _meta.cover),跳过;请跑完整流程或 --regen cover"(--force 为早退,不读原文提取主题)
- 成功 → 更新 `_meta.cover.status` + 副本 frontmatter 声明同步(声明值 = 从 manifest 解析的 COVER_FILE:jq 读 `_meta.cover.filename`,缺失回退约定式 `{stem}-cover.png`)+ **封面内嵌行插入/刷新**(v3.8,同 2.8 第 6/8 步:缩略图 base64 + anchor 定位);失败 → status=failed,不阻塞

全部遍历完成后执行**孤儿文件检测(仅提示,不删除)**:遍历 `{stem}_images/{stem}-image-*.png`,文件名序号不在 manifest pictures id 集合 → 提示"孤儿文件 {file}(manifest 未记录,未删除)"。

## Step 4:报告

统计行:**`重生: N, M(共 K 张);失败: ...;跳过: ...`**

- 失败与跳过互斥:失败只列重生集合内执行失败的 ID,同一张图不会同时出现在失败与跳过里
- 跳过 = 不在重生集合的图(--regen 时)
- **封面(v3.4)**:命中(重生集合含 cover 或 --force 含封面)时单独一行 `封面: 重生(生成) / 失败 / 跳过(--no-cover 或未规划)`,封面行格式见命令文件 Step 6

表格(编号两位零填充,status 如实反映):

```text
[si-regen 完成]
────────────────────────────────────────────────────────────
编号 │ 引擎       │ 源文件                         │ status    │ 动作 │ PNG 路径
─────┼────────────┼───────────────────────────────┼───────────┼──────┼──────────────
01   │ gemini     │ /tmp/si-prompt-01.txt         │ generated │ 🔄   │ xxx_images/xxx-image-01.png
03   │ mermaid    │ chart-aop.mmd                 │ failed    │ ✖    │ xxx_images/xxx-image-03.png
04   │ excalidraw │ chart-cmp.excalidraw          │ generated │ 🔄   │ xxx_images/xxx-image-04.png
05   │ gemini     │ /tmp/si-prompt-05.txt         │ generated │ ⏭    │ xxx_images/xxx-image-05.png

动作图例: 🔄 重生(--regen/--force 覆盖) │ ⏭ 跳过(不在重生集合) │ ✖ 失败
重生: 1, 3 (共 2 张);失败: 3 (minimax API 不可用);跳过: 2, 4, 5
```

源文件列:gemini 写 prompt 文件绝对路径(`/tmp/si-prompt-NN.txt`);mermaid/excalidraw 写相对 `{stem}_images/` 目录的裸文件名(无前缀)。**副本仅图片行刷新(见 2.7,整行替换为 base64 data URI 行),其余文字不动**。PNG 仍保留在 `{stem}_images/`(重生资产),副本已内嵌,不引用外部 PNG。副本封面为**双重表示**(v3.7;v3.8 起内嵌行为缩略图 base64):frontmatter `cover:` 声明 + 正文首个标题后封面缩略图 base64 内嵌行(`![cover](data:image/png;base64,...)`,base64 来自 `{stem}-cover-thumb.png`);封面内嵌行仅在封面流程更新(整行替换),不参与正文图计数;以 `!` 开头,被 `^!` 过滤。

## 风格轮换规范(mermaid/excalidraw 重生,Step 1/2/3 通用)

> 每次重生 mermaid/excalidraw 图 = **从 manifest 该 picture 的 `content`(+`topic`/`anchor`)重新生成源文件(.mmd/.excalidraw)→ 渲染 → 覆盖 PNG**。gemini/minimax 分支不适用本规范(API 生成天然随机)。

### 语义锚定(硬规则)

- 图的主题、节点、结构、层次**必须严格来自 `content`**(可参考 `topic`/`anchor` 补足上下文):不许简化节点、不许跑偏主题、不许丢节点、不许凭空加内容。
- `content` 是锚定参考:生成源文件时**只读 manifest 的 content** —— **禁止 `Read` 磁盘上旧的 .mmd/.excalidraw 照抄**(样式部分也不例外)。
- 旧源文件缺失不再是错误:无论旧文件在不在,一律按 content 重新生成源文件。

### 轮换参数(每次至少变化一项,推荐多项)

- **mermaid**:`theme: base|forest|neutral` 随机三选一 + `themeVariables` 主色系成套随机轮换(`primaryColor` / `primaryBorderColor` / `primaryTextColor` / `lineColor`)+ 线性流程合理时 direction `TB|LR|RL` 随机
- **excalidraw**:背景色 / 元素描边与填充色 / 布局微调(间距、对齐偏移 ±10%)

### 随机源

- 用 Bash `$RANDOM` 或 `date +%N` 尾数取模选组,例如:
  `THEME=("base" "forest" "neutral"); THEME=${THEME[$((10#$(date +%N) % 3))]}` 或 `[[ $((RANDOM % 3)) -eq 0 ]] && THEME=base`
- 同一次重生中多张图各自独立随机,不要求一致

### 节点内容

- 节点文案、结构、逻辑与 content 严格一致(语义锚定优先于轮换),只轮换**表现层**参数(主题/配色/方向/布局)。

## 失败处理

| 情况 | 应对 |
|---|---|
| manifest 不存在 + flag | 报错"manifest 不存在({path}),请先跑一次不带 flag 的完整流程生成",exit 1 |
| manifest 损坏(JSON 解析失败) | 报错"manifest 损坏({path}),请删除后重跑完整流程" |
| manifest 旧版 schema(非 si-minimax/v3) | 报错"旧版 manifest({path}),请重跑完整流程升级为 v3",不做 content 重建 |
| manifest 内部不一致(_meta.total ≠ pictures 长度) | 报错,exit 1 |
| 原文已修改(mtime/size 不符) | 警告"原文已修改({date}),图片可能过时",用户回复「继续」才执行 |
| `--regen N` 非正整数 / 越界 | 报错"必须为正整数或 cover"(非数字)/ "picture ID out of range (1-$TOTAL)"(越界),**校验前置,任一非法零执行** exit 1 |
| 按 id 找不到 picture | 报错"picture N 不存在",exit 1 |
| 旧 `.mmd` / `.excalidraw` 源文件已删除/不存在 | 无碍 —— 重生按「风格轮换规范」从 content 重新生成源文件,不再报"源文件缺失" |
| `MINIMAX_IMAGE_API_KEY` / `MINIMAX_API_KEY` 均未设 | 立即报错,提示设置其一 |
| minimax 参数错误(如误用 --prompt-file/--output) | 立即 `python3 ~/图片/minimax_t2i.py -h` 实测契约修正后重试 |
| prompt 超 1500 字符 | 按压缩策略截断(先 content 尾部再 style 尾部)重试 |
| minimax API 调用失败 | 该图跳过,status=failed,继续下一张,最后报告失败列表 |
| mermaid 脚本失败 / mmdc 未装 | 跳过该图,status=failed,提示 `npm i -g @mermaid-js/mermaid-cli` |
| excalidraw 脚本失败 / Playwright 未装 | 跳过该图,status=failed,提示安装依赖 |
| 未知 engine 值(手改 manifest) | 报错"picture $N engine 非法",跳过该图,纳入失败列表 |
| `--regen cover` 但 `_meta.cover` 缺失 | 唯一例外读原文:轻量提炼核心概念+视觉隐喻,补写 `_meta.cover`(含 `filename`/`anchor`)后生成;`--force` 时反之:跳过并提示"封面未规划" |
| 封面 minimax 调用失败 | 封面 status=failed,报告失败,不阻塞正文图片与副本 |
| 缩略图生成失败(ffmpeg 不可用/命令失败) | 回退用原图 base64 内嵌,不阻塞,报告中注明"缩略图生成失败,内嵌用原图" |
| `--cover-ratio` 比例不被 minimax 支持 | 警告"脚本不支持比例 X,已回退 16:9",按 16:9 继续 |
| `--no-cover` 与 `--regen cover` 同传 | `--no-cover` 优先,忽略 `--regen cover`,warning 说明 |
| 副本不存在时封面声明 | 跳过声明与封面内嵌行,报告"副本缺失,封面声明未写入"(声明值 = 读 manifest `_meta.cover.filename`,缺失回退约定式 `{stem}-cover.png`) |
| 副本缺封面内嵌行(2.8/Step 3) | 插入/刷新:已有 `![cover](data:image/png;base64,` 前缀行 → 整行替换为新 base64(`base64 -w0 "${IMG_DIR}/${STEM}-cover-thumb.png"`,缺失/生成失败 → 回退原图 `"${IMG_DIR}/${COVER_FILE}"`);无 → 读 manifest `_meta.cover.anchor` 定位:缺失/默认"第一个一级标题之后" → 第一个 `# ` 标题行后插入;其他描述 → 正文图 anchor 定位逻辑(段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;格式 `![cover](data:image/png;base64,{base64})`(独占一行,前后各留空行) |

## 参考

- manifest 实例:`/home/xhm/文档/测试生图2/Prompt高级专业术语全解_images/Prompt高级专业术语全解.si-plan.json`(si-minimax/v3)
- 本体(skill 不修改,只读复用):`~/.claude/commands/smart-illustrator-minimax.md`(v3.8,含「封面规范」专节与缩略图/anchor 规范)
- 脚本契约:`python3 ~/图片/minimax_t2i.py -h`、`mermaid-export.ts --help`、`excalidraw-export.ts --help`
