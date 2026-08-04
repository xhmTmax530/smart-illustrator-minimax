---
name: si-regen
description: 对 smart-illustrator / smart-illustrator-minimax 已规划的文章({stem}.si-plan.json manifest 存在)按编号重生指定图片或全量重生。输入格式:si-regen <file.md> --regen N [--regen M ...] 只重画第 N/M 张;si-regen <file.md> --force 无视已有文件全量重画。当用户说"重画第 N 张图""图 03 重新生成""这张图重出一次""--regen 2 --regen 5""全部图 --force 重来""图片重生"等,只要是针对已规划文章的图片重生请求,务必用本 skill。本 skill 只做重生早退:不读原文(不重新分析),只覆盖同名 PNG、更新 manifest status,并按命令规范刷新副本图片引用(按图片行序号整行替换为 base64 data URI 行;引用缺失按 anchor 定位插入)。文章尚未规划(manifest 不存在)时不属于本 skill 职责,引导用户先跑完整流程生成 manifest。
compatibility: bash、jq、ffmpeg、python3、bun(npx);~/图片/minimax_t2i.py;~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts 与 excalidraw-export.ts;环境变量 MINIMAX_IMAGE_API_KEY 或 MINIMAX_API_KEY(任一)
---

# si-regen — 文章配图重生(早退路径)

> 把 smart-illustrator-minimax 的"图片重生成"固定动作固化为独立 skill。manifest 是控制平面,一切以它为准。

## 输入与范围

`$ARGUMENTS` = `<file.md> --regen N [--regen M ...]` 或 `<file.md> --force`

- 第 1 段(必填):文章绝对或相对路径(`~` 自动展开,含空格路径必须整体加引号)
- `--regen N`:只重生第 N 张,允许多次指定(`--regen 2 --regen 5` 只重画第 2 和第 5 张)
- `--force`:无视已有 PNG,全量重生所有 pictures
- **本 skill 不含 `-content` 智能匹配**(那是 smart-illustrator-minimax 完整流程的职责);用户提到 `-content` 时,提示改用 `--regen N` 或完整流程

**互斥/优先级(Step 0 无条件检测)**:`--regen` 与 `--force` 同传 → `--force` 优先(警告"已忽略 --regen")。

## 全局铁律

1. **早退铁律(硬规则)**:manifest 存在 + 重生 flag → **绝对不读原文(不重新分析)**。PNG 覆盖成功后执行「副本引用刷新」(规范同命令文件路径 1):**base64 行不含文件名,不能 grep PNG 文件名** —— 副本图片行按顺序对应 picture id(manifest pictures 按 id 升序),第 N 张图 = 第 N 个 `grep -n '^!\[\](data:image/png;base64,'` 匹配行 → python3 脚本整行替换为新 PNG 的 base64 行(**禁用 Edit**,行可达 ~950KB);未命中 → 按 manifest anchor 定位段落、段末空行前插入;副本不存在 → 跳过并报告。只动副本图片行,不改其他任何文字。
2. **manifest 是唯一控制平面**:只从 manifest 读 engine/source_file/source_prompt,不读原文、不从 content 重建源码。
3. **PNG 命名(作者风格)**:`images/{stem}-image-{NN}.png`,**文章目录 images/ 子目录**(先 `mkdir -p images`),NN 两位零填充从 01;覆盖同名文件。
4. **非侵入(钉死)**:不改 `{stem}.md` 原文;不改 `~/.claude/skills/smart-illustrator-minimax` 本体;不改 smart-illustrator 的 SKILL.md/scripts/styles/references;不复制、不新建脚本 —— 只读复用 `~/图片/minimax_t2i.py` 与 `~/.claude/skills/smart-illustrator/scripts/{mermaid-export,excalidraw-export}.ts`。
5. 边界错误(源文件缺失/API 不可用等)只跳过该图、记录失败,**绝不回退到完整流程的全文分析**。

## Step 0:定位 + manifest 校验 + 路由

### 0.1 强制 cd

```bash
ARTICLE="$(realpath -m "$FILE")"      # 规范化绝对路径
cd "$(dirname "$ARTICLE")"            # 此后所有相对路径以文章目录为基准解析
```

### 0.2 manifest 定位

```bash
STEM="$(basename "$ARTICLE" .md)"
MANIFEST="${STEM}.si-plan.json"       # 文章目录,与副本平级
```

不存在 → **报错退出,绝不静默回退完整流程**:

```bash
[ -f "$MANIFEST" ] || { echo "[ERROR] manifest 不存在(${MANIFEST}),请先跑一次不带 flag 的完整流程生成"; exit 1; }
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
declare -A SEEN=()
for N in $REGEN_IDS; do
  if ! [[ "$N" =~ ^[0-9]+$ ]]; then            # --regen=3 / --regen abc / --regen 2.5 均非法
    echo "[ERROR] --regen $N: 必须为正整数"; REGEN_FAILED=1; continue
  fi
  N=$((10#$N))                                 # 去前导零
  [[ -n "${SEEN[$N]}" ]] && continue           # 去重
  SEEN[$N]=1
  if (( N < 1 || N > TOTAL )); then
    echo "[ERROR] --regen $N: picture ID out of range (1-$TOTAL)"; REGEN_FAILED=1
  fi
done
[[ $REGEN_FAILED -eq 1 ]] && exit 1            # 任一 N 非法 → 整体失败,零执行
```

对每个有效 `N`(已去重、已验证范围)执行 Step 2 的分发逻辑。

## Step 2:engine 分发(执行体,--regen 与 --force 共用)

### 2.1 按 id 查找(禁止 `pictures[N-1]` 下标)

```bash
PIC_JSON=$(jq -e --argjson id "$N" '.pictures[] | select(.id == $id)' "$MANIFEST") || {
  echo "[ERROR] picture $N 不存在"; exit 1; }
```

读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`;PNG 路径:

```bash
PNG="images/${STEM}-image-$(printf '%02d' $N).png"   # 文章目录 images/ 子目录(先 mkdir -p images),覆盖同名文件
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

### 2.3 mermaid 分支

- 读 `source_file`(相对文章目录解析);缺失 → 报错"mermaid 源文件缺失,请用 --force 重建",跳过该图

```bash
npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts \
  -i "$SOURCE_FILE" -o "$PNG" -w 2400
```

### 2.4 excalidraw 分支

- 读 `source_file`(相对文章目录解析);缺失 → 报错"excalidraw 源文件缺失,请用 --force 重建",跳过该图

```bash
npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts \
  -i "$SOURCE_FILE" -o "$PNG" -s 2
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
1. 副本 `{stem}-image.md` 不存在 → 跳过,报告"副本缺失,引用未刷新"
2. 定位图片行:副本图片行按顺序对应 picture id(manifest pictures 按 id 升序),第 N 张图 = 第 N 个匹配:`Bash grep -n '^!\[\](data:image/png;base64,' "{stem}-image.md"` 取第 N 个匹配行(行号记入报告)
3. 命中 → python3 脚本整行替换为新 PNG 的 base64 行(禁用 Edit;写临时文件再原子替换):

```bash
python3 - "{stem}-image.md" "images/{stem}-image-{NN}.png" $N << 'PYEOF'
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

## Step 3:--force 全量

遍历 `jq -r '.pictures[] | .id' "$MANIFEST"` 得到全部 id,对每张按 Step 2 分发执行:
- 逐张覆盖同名 PNG(不管是否已有文件)
- 源文件缺失 → 直接报错跳过,**不做从 content 重建**(旧版已显式拒绝,重建无意义)
- 每张执行后按 2.6 更新 status

全部遍历完成后执行**孤儿文件检测(仅提示,不删除)**:遍历 `images/{stem}-image-*.png`,文件名序号不在 manifest pictures id 集合 → 提示"孤儿文件 {file}(manifest 未记录,未删除)"。

## Step 4:报告

统计行:**`重生: N, M(共 K 张);失败: ...;跳过: ...`**

- 失败与跳过互斥:失败只列重生集合内执行失败的 ID,同一张图不会同时出现在失败与跳过里
- 跳过 = 不在重生集合的图(--regen 时)或源文件缺失未执行的图(--force 时)

表格(编号两位零填充,status 如实反映):

```text
[si-regen 完成]
────────────────────────────────────────────────────────────
编号 │ 引擎       │ 源文件                         │ status    │ 动作 │ PNG 路径
─────┼────────────┼───────────────────────────────┼───────────┼──────┼──────────────
01   │ gemini     │ /tmp/si-prompt-01.txt         │ generated │ 🔄   │ images/xxx-image-01.png
03   │ mermaid    │ images/chart-aop.mmd          │ failed    │ ✖    │ images/xxx-image-03.png
04   │ excalidraw │ images/chart-cmp.excalidraw   │ generated │ 🔄   │ images/xxx-image-04.png
05   │ gemini     │ /tmp/si-prompt-05.txt         │ generated │ ⏭    │ images/xxx-image-05.png

动作图例: 🔄 重生(--regen/--force 覆盖) │ ⏭ 跳过(不在重生集合) │ ✖ 失败
重生: 1, 3 (共 2 张);失败: 3 (mermaid 源文件缺失);跳过: 2, 4, 5
```

源文件列:gemini 写 prompt 文件绝对路径(`/tmp/si-prompt-NN.txt`);mermaid/excalidraw 写相对文章目录、带 `images/` 前缀的源文件路径。**副本仅图片行刷新(见 2.7,整行替换为 base64 data URI 行),其余文字不动**。PNG 仍保留在 images/(重生资产),副本已内嵌,不引用外部 PNG。

## 失败处理

| 情况 | 应对 |
|---|---|
| manifest 不存在 + flag | 报错"manifest 不存在({path}),请先跑一次不带 flag 的完整流程生成",exit 1 |
| manifest 损坏(JSON 解析失败) | 报错"manifest 损坏({path}),请删除后重跑完整流程" |
| manifest 旧版 schema(非 si-minimax/v3) | 报错"旧版 manifest({path}),请重跑完整流程升级为 v3",不做 content 重建 |
| manifest 内部不一致(_meta.total ≠ pictures 长度) | 报错,exit 1 |
| 原文已修改(mtime/size 不符) | 警告"原文已修改({date}),图片可能过时",用户回复「继续」才执行 |
| `--regen N` 非正整数 / 越界 | 报错"图片共 M 张,N 超出范围(1-M)",**校验前置,任一非法零执行** exit 1 |
| 按 id 找不到 picture | 报错"picture N 不存在",exit 1 |
| `.mmd` / `.excalidraw` 源文件已删除 | 报错"源文件缺失,请用 --force 重建",跳过该图 |
| `MINIMAX_IMAGE_API_KEY` / `MINIMAX_API_KEY` 均未设 | 立即报错,提示设置其一 |
| minimax 参数错误(如误用 --prompt-file/--output) | 立即 `python3 ~/图片/minimax_t2i.py -h` 实测契约修正后重试 |
| prompt 超 1500 字符 | 按压缩策略截断(先 content 尾部再 style 尾部)重试 |
| minimax API 调用失败 | 该图跳过,status=failed,继续下一张,最后报告失败列表 |
| mermaid 脚本失败 / mmdc 未装 | 跳过该图,status=failed,提示 `npm i -g @mermaid-js/mermaid-cli` |
| excalidraw 脚本失败 / Playwright 未装 | 跳过该图,status=failed,提示安装依赖 |
| 未知 engine 值(手改 manifest) | 报错"picture $N engine 非法",跳过该图,纳入失败列表 |

## 参考

- manifest 实例:`/home/xhm/文档/测试生图2/Prompt高级专业术语全解.si-plan.json`(si-minimax/v3)
- 本体(skill 不修改,只读复用):`~/.claude/commands/smart-illustrator-minimax.md`(`~/.claude/skills/smart-illustrator/si-pipeline/commands/` 下旧副本已过期,勿引用)
- 脚本契约:`python3 ~/图片/minimax_t2i.py -h`、`mermaid-export.ts --help`、`excalidraw-export.ts --help`
