---
description: smart-illustrator 的 minimax 替代版 — 文章配图(用 minimax API 替代 Gemini,严格复用作者原生 mermaid/excalidraw 脚本)
argument-hint: <file.md> [extra hints...]
allowed-tools: Read Write Edit Bash Glob
---

# /smart-illustrator-minimax — 文章配图(minimax 替代 Gemini)

> **非侵入式增强**:不修改作者任何文件(`SKILL.md` / `scripts/*` / `styles/*` / `references/*`),完全复用作者的 `mermaid-export.ts` 与 `excalidraw-export.ts`,仅把 Gemini API 替换为本地 `minimax_t2i.py`。

## 输入

`$ARGUMENTS` = `<file.md> [flags] [extra hints...]`

- 第 1 段(必填):文章绝对或相对路径(`~` 自动展开,**含空格的路径必须加引号**)
- 后续(可选,顺序无关):flags 或用户偏好(自然语言,如"重点配架构图,少隐喻"),Claude 据此调整选 engine / 数量 / 风格

## 参数

| 参数 | 默认 | 说明 |
|------|------|------|
| `--regen N` | - | 只重生第 N 张(N≥1,图片编号),其余已有图跳过(不管是否变更) |
| `--force` | `false` | 无视已有文件,全部重新生成 |
| `-content "..."` | - | 自然语言描述目标图（不用记编号）。按 topic/anchor/content 打匹配分,唯一最高分自动选中 |

> **互斥规则(Step 0 路由之前无条件检测)**:
> - `-content` 与 `--force` 同传 → **硬互斥,报错退出**,提示 `Use one or the other`
> - `--regen` 与 `--force` 同传 → `--force` 优先(全量重来),warning 中明确"已忽略 --regen"
> - `-content` 与 `--regen N` 同传 → `--regen N` 优先(显式 id 更精确),路径 3 跳过
>
> `--regen` 允许多次指定:`--regen 2 --regen 5` 只重生第 2 和第 5 张。`--regen` 必须带一个**正整数**参数(`--regen=3`、`--regen abc`、`--regen 2.5` 均为非法)。
>
> 重生机制:PNG 固定写入 `images/{stem}-image-NN.png`,副本引用一律 **base64 data URI 内嵌**(`![](data:image/png;base64,<...>)` 单行,自包含 —— 拷贝到任何地方打开都显示图片)。覆盖 PNG 后**必须**执行「副本引用刷新」(路径 1/2 内建):按图片行序号命中即整行替换为新 base64 行,缺失按 anchor 定位插入。

## 全局约束

1. **原文永不动(硬规则)**:复制为 `{stem}-image.md`,所有写入副本。**禁止改动原文任何文字,包括引号、全角标点等细微字符**;插图后必须跑一次 `diff` 校验。**副本唯一允许差异 = 图片行(base64)+ 空行**:base64 图片行一律以 `!` 开头,`grep -v '^!'` 过滤规则继续有效;过滤后 diff 中除空行外不得出现任何非空行差异;任何对原文行的改动视为 bug 立即重试。
2. **Engine 枚举**(严格作者 `--engine` 值,不自定义): `gemini` | `excalidraw` | `mermaid`
3. **PNG 命名(作者风格)**: `images/{stem}-image-{NN}.png`,**文章目录 images/ 子目录**(先 `mkdir -p images`),NN 两位零填充从 01(如 `images/test-image-03.png`)。不与副本 `{stem}-image.md` 冲突(.md vs .png)。
4. **mermaid 默认 PNG**(走作者 `mermaid-export.ts`),不是代码块;excalidraw 永远 PNG(走 `excalidraw-export.ts`)。源文件命名保持 `{chart}.mmd` / `{chart}.excalidraw` 现状。
5. **插入机制**:Claude 心跳记忆 — 同一个会话里读完文章 → 出图 → 写副本,"图 N 该放第 X 段"在 context window 里。**插图只插目标段落末尾空行之前;禁止插在标题与分隔线(`---`)之间**(图归属必须清晰)。**副本引用格式固定 base64 data URI 单行**:`![](data:image/png;base64,<base64>)` —— 单行、无尖括号包裹、无空格/换行,base64 以 `iVBOR` 开头(PNG 魔数)。生成命令:`python3 -c "import base64,sys;print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" <png>`。**base64 行可达 ~950KB,插图/刷新一律用 python3 脚本操作(禁用 Edit 工具)**:脚本定位 → 拼单行 → 写临时文件 → `os.replace` 原子替换。
6. **复用作者脚本**(完全不改):
   - `scripts/mermaid-export.ts`(mmdc 出 PNG)
   - `scripts/excalidraw-export.ts`(Playwright + Firefox + excalidraw.com)
7. **唯一新依赖**: `~/图片/minimax_t2i.py`(用户本地 minimax 出图脚本,仅替代 `generate-image.ts` 里的 Gemini API 调用)
8. **manifest = 控制平面(必做)**:路径 4 必写 `{stem}.si-plan.json`(文章目录,与 `{stem}-image.md` 平级),路径 1/2/3 只读。schema `si-minimax/v3`。
9. **早退分支**:manifest 存在 + flag 触发时,跳过 Read 全文 + cp 副本,只覆盖同名 PNG + 执行「副本引用刷新」(仅动副本图片行,不重新分析)。

## 执行步骤

### Step 0:cd + manifest 检测 + 早退分流

> **此步必须在做任何分析之前最先执行**。manifest 是早退分支的唯一控制平面。

#### 0.0 强制 cd(所有路径第一步)

```bash
ARTICLE="$(realpath -m "$FILE")"        # 规范化绝对路径
cd "$(dirname "$ARTICLE")"              # 此后所有相对路径一律以文章目录为基准解析
```

所有路径(1/2/3/4)的第一步都是这个 cd,后续 mkdir / 写 PNG / 读源文件 / 写副本全部在文章目录解析,与调用时的会话 cwd 无关。

#### 0.1 manifest 定位

```bash
STEM="$(basename "$ARTICLE" .md)"
MANIFEST="${STEM}.si-plan.json"                          # 新位置:文章目录,与副本平级
LEGACY_MANIFEST="/tmp/si-plan-${STEM}.json"              # 旧位置(仅兼容查找)
```

查找顺序:
1. `$MANIFEST`(文章目录 `{stem}.si-plan.json`)存在 → 用它
2. 不存在但 `$LEGACY_MANIFEST`(/tmp)存在 → **提示"manifest 已迁移到文章目录({MANIFEST}),请重跑完整流程刷新"**,然后按"manifest 不存在"处理(见 0.5)
3. 两者都不存在 → "manifest 不存在"

#### 0.2 读前 JSON 校验(manifest 存在时)

```bash
jq -e . "$MANIFEST" >/dev/null 2>&1 || {
  echo "[ERROR] manifest 损坏(${MANIFEST}),请删除后重跑完整流程"
  exit 1
}
```

#### 0.3 schema 校验

- `_meta.schema == "si-minimax/v3"` → 正常
- v1(缺 `source_file` 字段)或任何非 v3 旧版本 → **显式拒绝**:

```bash
echo "[ERROR] 旧版 manifest(${MANIFEST}),请重跑完整流程升级为 v3"
exit 1
```

> **不做任何从 `content` 重建的死代码**:旧 manifest 的 content 是语义描述而非源码,重建出的图与原图必然不同,一律拒绝并引导升级。

#### 0.4 陈旧检测

```bash
SRC_MTIME=$(stat -c %Y "$ARTICLE")
SRC_SIZE=$(stat -c %s "$ARTICLE")
META_MTIME=$(jq -r '._meta.source_mtime' "$MANIFEST")
META_SIZE=$(jq -r '._meta.source_size' "$MANIFEST")
if [[ "$SRC_MTIME" != "$META_MTIME" || "$SRC_SIZE" != "$META_SIZE" ]]; then
  STALE=1
fi
```

- 路径 1/2/3:`STALE=1` → 警告 **"原文已修改({来源 mtime 对应日期}),图片可能过时;确认继续则手动回复继续"**,用户回复"继续"才执行,否则退出。
- 路径 4(重新分析):`STALE=1` → 提示"原文已修改({date}),本次按当前内容重新分析",直接继续。

#### 0.5 flag 分流(路由表)

| 条件 | 目标路径 |
|------|---------|
| 互斥检测命中(-content + --force) | 报错 exit 1(见参数节) |
| manifest 不存在 + 任一 flag(`--force`/`--regen`/`-content`) | **报错 exit 1**(见下) |
| manifest 不存在 + 无 flag | 路径 4(完整流程) |
| manifest 存在 + `--force` | 路径 2 |
| manifest 存在 + `--regen N` | 路径 1 |
| manifest 存在 + `-content "..."` | 路径 3 |
| manifest 存在 + 无 flag + 原文未变 | **询问复用/重新分析**(见 0.6) |
| manifest 存在 + 无 flag + 原文已变 | 路径 4 重新分析(带"原文已修改"提示) |

**manifest 不存在 + flag → 统一报错,绝不静默回退路径 4**:

```bash
echo "[ERROR] manifest 不存在(${MANIFEST}),请先跑一次不带 flag 的完整流程生成"
exit 1
```

> **注意**:即使 manifest 存在,路径 1/2/3 执行中遇到边界错误(源文件缺失/API 不可用等)也只跳过该图、记录失败,**绝不退回路径 4 的全文分析流程**。

#### 0.6 无 flag 重跑分流(manifest 存在 + 原文未变)

展示 manifest 摘要表(编号两位/引擎/源文件/status),然后询问:

> "复用现有规划(推荐,幂等)还是重新分析?回复「复用」或「重新分析」"

- **「复用」** → 保持现有 manifest 规划,走路径 4 的 skip-existing 执行体(已有 PNG 跳过、缺失的补生成、写副本),**不做 LLM 重新分析**
- **「重新分析」** → 走路径 4 完整流程(重新 LLM 分析并重写 manifest)

---

### 路径 1:--regen N 早退

> manifest 存在 + `--regen N` → 绝对不读原文(不重新分析),只覆盖同名 PNG;成功后执行「副本引用刷新」(见 1.2 末尾)。

#### 1.1 输入校验(前置全量校验,任一非法 → 零执行)

```bash
TOTAL=$(jq '.pictures | length' "$MANIFEST")
META_TOTAL=$(jq '._meta.total' "$MANIFEST")
[[ "$TOTAL" == "$META_TOTAL" ]] || { echo "[ERROR] manifest 内部不一致(_meta.total ≠ pictures 长度)"; exit 1; }

REGEN_FAILED=0
declare -A SEEN=()
for N in $REGEN_IDS; do
  if ! [[ "$N" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] --regen $N: 必须为正整数"
    REGEN_FAILED=1; continue
  fi
  N=$((10#$N))                      # 去前导零
  if [[ -n "${SEEN[$N]}" ]]; then
    continue                        # 去重
  fi
  SEEN[$N]=1
  if (( N < 1 || N > TOTAL )); then
    echo "[ERROR] --regen $N: picture ID out of range (1-$TOTAL)"
    REGEN_FAILED=1
  fi
done
if [[ $REGEN_FAILED -eq 1 ]]; then
  exit 1                            # 任一 N 非法 → 整体失败,零执行
fi
```

**校验通过才逐个执行**——绝不在校验循环里先做任何重生(避免"合法的先做了、非法的后报错"的部分副作用)。

#### 1.2 早退执行体

对每个有效 `N`(已去重、已验证范围):

1. **按 id 查找**(禁止 `pictures[N-1]` 下标):

```bash
PIC_JSON=$(jq -e --argjson id "$N" '.pictures[] | select(.id == $id)' "$MANIFEST") || {
  echo "[ERROR] picture $N 不存在"; exit 1; }
```

2. 读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`
3. 未知 engine(不在 gemini/excalidraw/mermaid 枚举)→ 报错"picture $N engine 非法,已跳过",纳入失败列表,继续下一张
4. 拼凑 PNG 路径:`images/${STEM}-image-$(printf '%02d' $N).png`(文章目录 images/ 子目录;执行前 `mkdir -p images`)

**gemini 分支(minimax 调用,契约已实测)**:

```bash
# 实测契约(2026-08-01):python3 ~/图片/minimax_t2i.py -h
#   - prompt 是位置参数,最长 1500 字符
#   - --out <目录>:输出目录(不是文件),产物固定 minimax-{i}.jpeg
#   - --ratio 支持 16:9;不存在 --prompt-file / --output
# 调用任何 minimax 前,若对参数不确定,先跑 -h 实测,以实测为准。
[[ -n "$MINIMAX_IMAGE_API_KEY" || -n "$MINIMAX_API_KEY" ]] || {
  echo "[ERROR] MINIMAX_IMAGE_API_KEY / MINIMAX_API_KEY 均未设置"
  exit 1; }
[[ -f ~/图片/minimax_t2i.py ]] || { echo "[ERROR] ~/图片/minimax_t2i.py 不存在"; exit 1; }

python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-prompt-${NN}.txt)" \
  --out /tmp/si-out-${NN} --ratio 16:9 \
  && mv /tmp/si-out-${NN}/minimax-0.jpeg "images/${STEM}-image-${NN}.png"
# mv 后必须执行「格式统一规范」(Step 4a 末尾:file 检测 + ffmpeg 转码为真 PNG)
```

- prompt 文件用 HEREDOC 写入 `/tmp/si-prompt-${NN}.txt`(避免 shell 转义),写入后 `wc -c` 校验 ≤1500(压缩策略见 Step 4a)
- 产物 `minimax-0.jpeg` 实测是 **JPEG 编码(1280×720)**,`mv` 只换扩展名不换编码 —— 严格按扩展名解析的工具会解码失败。**mv 后必须执行「格式统一规范」**(Step 4a 末尾:file 检测,JPEG 则 ffmpeg 转码为真 PNG)
- **绝对不能用 `--prompt-file` / `--output` 这两个不存在的 flag**
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**mermaid 分支**:
- 读取 `source_file`(相对文章目录解析;缺失 → 报错"mermaid 源文件缺失,请用 --force 重建")
- `npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts -i {source_file} -o {PNG_PATH} -w 2400`
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**excalidraw 分支**:
- 读取 `source_file`(相对文章目录解析;缺失 → 报错"excalidraw 源文件缺失,请用 --force 重建")
- `npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts -i {source_file} -o {PNG_PATH} -s 2`
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**副本引用刷新(成功覆盖 PNG 后必做;只动副本图片行,不读原文分析;失败图不刷)**:

对每张成功重生的图(在更新 status 之前):

1. 副本 `{stem}-image.md` 不存在 → 跳过本步,报告"副本缺失,引用未刷新"
2. **定位图片行(注意:base64 行不含文件名,原 `grep image-NN.png` 已失效)**:副本图片行按顺序对应 picture id —— manifest pictures 按 id 升序,副本插图顺序与之一致,第 N 张图 = 第 N 个图片行。先取序号:`Bash grep -n '^!\[\](data:image/png;base64,' "{stem}-image.md"` → 取第 N 个匹配行(行号记入报告)
3. **命中** → 用 python3 脚本整行替换为新 PNG 的 base64 行(**禁用 Edit**,行可达 ~950KB;写临时文件再原子替换):

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

4. **未命中**(脚本退出码 2:引用被删/图片行不足/顺序错乱)→ 读 manifest 该 picture 的 `anchor`,`Read` 副本定位该段 → **段末空行前插入** base64 行(插入脚本同 Step 5.3;全流程唯一需要 LLM 心跳定位的步骤);段落定位失败 → 报告"引用未找到,未插入",不阻塞后续

每张图执行后更新 manifest 中该 picture 的 status:

```bash
jq --argjson id "$N" --arg s "generated" \
  '(.pictures[] | select(.id == $id) | .status) = $s' "$MANIFEST" > "${MANIFEST}.tmp" \
  && mv "${MANIFEST}.tmp" "$MANIFEST"
```

#### 1.3 完成报告(表格格式见 Step 6,status 列如实反映)

```
路径 1 完成 — 副本引用已刷新(2 行整行替换;1 张副本缺失未刷)
重生: 2, 5 (共 2 张);失败: 5 (minimax API 不可用);跳过: 1, 3, 4 (不在 regen 集合)
```

> 失败与跳过互斥:失败只列 regen 集合内执行失败的 ID,同一张图不会同时出现在失败与跳过里。

---

### 路径 2:--force 早退

> manifest 存在 + `--force` → 遍历所有 pictures,全量覆盖 PNG,每张成功后执行「副本引用刷新」(规范同路径 1.2)。**源文件缺失时直接报错跳过,不做从 content 重建**(旧版已显式拒绝,重建无意义)。

#### 2.1 早退执行体

```
Bash mkdir -p images   # 文章目录 images/ 子目录(PNG 收纳地)
FORCE_MODE=true
```

对每张 picture(按 id 遍历 `jq '.pictures[]'`):
1. 读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`
2. 拼凑 PNG 路径:`images/${STEM}-image-$(printf '%02d' $N).png`
3. engine 分支 —— **调用规范 + 格式统一与路径 1 完全相同**(gemini 走实测 minimax 契约;mermaid/excalidraw 走作者脚本):
   - gemini:HEREDOC 写 prompt 到 `/tmp/si-prompt-${NN}.txt`(≤1500 压缩策略同 Step 4a)→ `python3 ~/图片/minimax_t2i.py "$(cat ...)" --out /tmp/si-out-${NN} --ratio 16:9` → `mv /tmp/si-out-${NN}/minimax-0.jpeg {PNG}` → **格式统一规范(Step 4a 末尾):file 检测,JPEG 则 ffmpeg 转码为真 PNG**
   - mermaid:无 `source_file` → 跳过该图,报错;有 → `mermaid-export.ts -i {source_file} -o {PNG} -w 2400`
   - excalidraw:无 `source_file` → 跳过该图,报错;有 → `excalidraw-export.ts -i {source_file} -o {PNG} -s 2`
4. **成功覆盖 PNG 后 → 执行「副本引用刷新」(规范同路径 1.2,失败图不刷)**
5. 每张执行后更新 manifest 的 status(generated / failed)
6. **全部遍历完成后 → 孤儿文件检测(仅提示,不删除)**:遍历 `images/{stem}-image-*.png`,文件名序号不在 manifest pictures id 集合 → 提示"孤儿文件 {file}(manifest 未记录,未删除)"。脚本:

```bash
python3 - "$STEM" "$MANIFEST" << 'PYEOF'
import glob, json, re, sys
stem, manifest = sys.argv[1], sys.argv[2]
ids = {str(p["id"]) for p in json.load(open(manifest))["pictures"]}
for f in sorted(glob.glob(f"images/{stem}-image-*.png")):
    m = re.search(r"image-(\d+)\.png$", f)
    if m and m.group(1).lstrip("0") not in ids:
        print(f"孤儿文件 {f}(manifest 未记录,未删除)")
PYEOF
```

#### 2.2 完成报告

```
路径 2 完成 — 副本引用已刷新(3 张整行替换;1 张副本缺失未刷)
全量重生: 3 张;失败: 1 张 (excalidraw 源文件缺失)
```

---

### 路径 3:-content 智能匹配早退

> manifest 存在 + `-content "..."` → 评分找唯一最高分,命中的话走路径 1 单图重生。

#### 3.1 互斥检查

- `-content` 与 `--force` 同传 → 报错互斥(Step 0 已拦截)
- `-content` 与 `--regen N` 同传 → `--regen N` 优先(显式 id 更精确),路径 3 跳过

#### 3.2 评分算法

对 `manifest.pictures` 中每张 picture 打分:

| 命中维度 | 加分 | 说明 |
|---------|------|------|
| `topic` 子串(大小写不敏感) | +10 | 精确语义匹配 |
| `anchor` 子串(大小写不敏感) | +10 | 章节锚点命中 |
| `content` 子串(大小写不敏感) | +10 | 内容描述命中 |
| 章节编号命中(描述含「第 N 节/数字+.」) | +5 | 定位精度 |
| 类型关键词命中(「流程图/时序图/对比图/架构图/概念图/隐喻图」) | +3 | 类型提示 |

> 每个 picture 取所有命中维度的累加分,最高分者胜出。

#### 3.3 分流

- **最高分唯一** → 选中该 ID,转路径 1 单图重生逻辑(`--regen N` 执行体)
- **并列 ≥ 2** → 报错,列出前 3 候选(id + topic + 命中维度 + 分值),要求 `--regen <id>` 消歧
- **全 0 分** → 报错,列出所有 picture 的 id + topic + anchor

> **提示(并列/零命中报错末尾必带)**:编号 = 图片文件名后缀数字(如 `images/test-image-03.png` → 03)。

---

### 路径 4:默认全流程（原 Step 1-6,v3 修订）

> 进入条件:manifest 不存在 + 无 flag(完整流程);或 manifest 存在 + 无 flag + 原文已变(重新分析);或「复用」分支复用现有 manifest。

#### Step 1:读原文

- `Read <file.md>` 全文(若极长,按章节分批读)

#### Step 2:心跳分析(Claude LLM 决策)

按作者 SKILL.md `Step 1` 启发式:

1. 识别 **3-5 个**配图位置(短文 1-2,中篇 2-4,长文 4-6,教程每主步骤 1 张)
2. 为每张定 engine,优先级: `gemini`(隐喻/情感/封面) → `excalidraw`(手绘概念/对比/简单流程 ≤8 节点) → `mermaid`(复杂流程 >8 节点/多层架构/时序)
3. 心跳里记好:**每张图对应文章哪段**(用简短描述,例如"图 2 在讲 Spring 三层架构那段后")
4. 给每张定 PNG 序号(01, 02, ...)和 PNG 命名(`images/{stem}-image-{NN}.png`)

> ⚠ 这步**没有任何写盘动作**。JSON 还没生成。
>
> **「复用」分支跳过本步**:沿用 manifest 现有 pictures,直接走 Step 3(不重写)→ Step 4 → Step 5。
>
> **原文已变提示**:若 Step 0 陈旧检测命中,先提示"原文已修改({date}),本次按当前内容重新分析"再继续。

#### Step 3:(必做)写 manifest

> **此步必做** —— v3 manifest 是早退分支的控制平面。写完必须 `jq -e .` 校验,失败立即报错重写。

```
Write {stem}.si-plan.json   # 文章目录,与 {stem}-image.md 平级
```

**Schema v3** (`_meta.schema` = `si-minimax/v3`):

```json
{
  "_meta": {
    "schema": "si-minimax/v3",
    "source": "<文章规范化绝对路径,realpath 结果>",
    "source_mtime": "<stat -c %Y 文章,整数>",
    "source_size": "<stat -c %s 文章,整数>",
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
      "anchor": "<简短段落描述,用于定位>",
      "source_file": "<.mmd/.excalidraw 路径,相对文章目录、带 images/ 前缀(如 images/insight-5steps.mmd),仅 mermaid/excalidraw;若文件在 /tmp 则写绝对路径并注释说明>",
      "source_prompt": "<完整 prompt 文本,仅 gemini>",
      "status": "planned"
    }
  ]
}
```

**v3 变更(vs v2)**:
- `_meta` 新增 `source`(规范化绝对路径)/ `source_mtime` / `source_size`(陈旧检测用)
- 每张 picture 恢复 `"status": "planned|generated|failed"`,执行后即时更新
- 生成图片时 `source_file` 写**相对文章目录**路径、带 `images/` 前缀(Step 0 已 cd,解析无歧义);**文件在 /tmp(如 gemini 的 prompt 文件)时写绝对路径并注释说明**
- 写盘后强制校验(两级):先 `jq -e .` 基础 JSON 校验;若 `~/.claude/skills/si-regen/scripts/validate-manifest.sh` 存在(另一 agent 并行产出)则追加调用。校验失败 → 按校验输出修正后重写 manifest,重写后复验;仍失败 → 报错 exit 1。脚本不存在 → 仅 jq 兜底:

```bash
jq -e . "{stem}.si-plan.json" >/dev/null || {
  echo "[ERROR] manifest 写入后校验失败,请重新生成"; exit 1; }
VALIDATOR="$HOME/.claude/skills/si-regen/scripts/validate-manifest.sh"
if [[ -f "$VALIDATOR" ]] && ! bash "$VALIDATOR" "{stem}.si-plan.json"; then
  echo "[ERROR] validate-manifest.sh 校验失败,请按校验输出修正重写后复验"
  exit 1
fi
```

#### Step 4:生成图片

skip-existing 逻辑(「重新分析」与「复用」共用;路径 4 内 flag 恒为空):

```
Bash mkdir -p images   # 第一步:建图片收纳目录

默认(无 flag):
  若 images/{stem}-image-{NN}.png 已存在 → 跳过(⏭)
  若不存在 → 正常生成
```

> 路径 4 中 `--force`/`--regen` 分支不存在(flag 已在 Step 0 分流到路径 1/2),此处只有 skip-existing 一种语义。

对每张**不跳过**的图,按 engine 分支:

**4a. gemini(替换为 minimax,调用规范 + 格式统一三处统一)**:

```bash
# ---- prompt 压缩策略(≤1500 字符硬上限,脚本实测确认) ----
# 1. 先 Read ~/.claude/skills/smart-illustrator/styles/style-light.md(或用户指定 style)
# 2. 提取 style 核心要点(品牌色板 + 构图/氛围/禁忌,要点短语而非全文)
#    示例:"扁平几何、浅色模式、背景 #F8F9FA、主色 #38BDF8、强调 #F59E0B、
#    极细字重、留白 ≥40%、16:9、禁霓虹渐变、单隐喻"
# 3. 拼接 = style 核心要点 + topic + content
# 4. wc -c 检查:>1500 时按顺序截断——先截 content 尾部,仍超则截 style 尾部;
#    topic 与核心视觉要求(色板/比例/禁忌)必须完整保留
cat > /tmp/si-prompt-{NN}.txt << 'EOF'
<style 核心要点 + topic + content,≤1500 字符>
EOF
wc -c /tmp/si-prompt-{NN}.txt    # 校验 ≤1500,超限按上面规则截断

# ---- 调用(契约实测 2026-08-01,与路径 1/2 完全一致) ----
python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-prompt-{NN}.txt)" \
  --out /tmp/si-out-{NN} \
  --ratio 16:9
mv /tmp/si-out-{NN}/minimax-0.jpeg "images/{stem}-image-{NN}.png"
```

- **绝对不能用 `--prompt-file` / `--output` 这两个不存在的 flag**(真实契约:位置参数 prompt + `--out <目录>` + 产物 `minimax-{i}.jpeg`)
- key 检查:`MINIMAX_IMAGE_API_KEY` 或 `MINIMAX_API_KEY` **任一存在**即可(脚本首选前者,回落后者)
- 宽高比:脚本 `--ratio` 支持 16:9,固定传 `--ratio 16:9`(作者正文配图契约)

**格式统一规范(minimax 分支统一执行;路径 1/2/4a 三处共用本规范,勿各自另写)**:

> 实测(2026-08-01):minimax 产物 `minimax-0.jpeg` 是 **JPEG 编码(1280×720)**——`mv` 只换了扩展名,内容仍是 JPEG,严格按扩展名解析的工具会解码失败。mv 后必须执行:

```bash
# 1. file 检测产物编码:已是真 PNG("PNG image data")→ 跳过;JPEG(或其他非 PNG)→ 转码
PNG="images/{stem}-image-{NN}.png"
if ! file "$PNG" | grep -q "PNG image data"; then
  if command -v ffmpeg >/dev/null 2>&1; then
    # 2. ffmpeg 按输出扩展名编码真 PNG;先写临时文件再 mv 覆盖(同路径直写有截断风险)
    #    -update 1 抑制 image2 单帧输出的提示噪音
    ffmpeg -y -i "$PNG" -update 1 "$PNG.fix.png" && mv "$PNG.fix.png" "$PNG"
  else
    # 3. ffmpeg 不可用 → 警告不失败,产物保持 JPEG 编码(可正常显示)
    echo "⚠️ 产物为 JPEG 编码但扩展名 .png,请安装 ffmpeg 以获得真 PNG;当前文件可正常显示"
  fi
fi
file "$PNG"    # 4. 验证:必须输出 "PNG image data"(转码后或原本就是真 PNG)
```

- 幂等:重复生成/重生时已是真 PNG 则直接跳过,无副作用
- **仅 gemini/minimax 分支需要**;mermaid/excalidraw 导出本来就是真 PNG,**不执行**本规范

**4b. mermaid(复用作者脚本)**:
```
Write images/{chart}.mmd
<mmd 内容,Claude 按 content 生成>
Bash npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts \
  -i images/{chart}.mmd \
  -o images/{stem}-image-{NN}.png \
  -w 2400
```
- `.mmd` 源文件保留在文章目录 images/ 子目录(命名 `{chart}.mmd` 现状不变)

**4c. excalidraw(复用作者脚本)**:
```
Read ~/.claude/skills/smart-illustrator/references/excalidraw-guide.md
Write images/{chart}.excalidraw
<按 guide 规范写 Excalidraw JSON 数组>
Bash npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts \
  -i images/{chart}.excalidraw \
  -o images/{stem}-image-{NN}.png \
  -s 2
```
- `.excalidraw` 源文件保留在 images/ 子目录
- 必读 excalidraw-guide.md(`boundElements: null`、`updated: 1`、不加 `frameId`)
- 依赖 Playwright + Firefox(若未装,报错)

每张图执行后更新 manifest 的 status(generated / failed),写入命令与路径 1.2 相同。

#### Step 5:写副本(Claude 心跳引导)

1. **副本已存在 → 先显示 diff 摘要,再询问是否覆盖**(与失败处理表统一):

```bash
if [[ -f "{stem}-image.md" ]]; then
  diff <(grep -v '^!' "$ARTICLE") <(grep -v '^!' "{stem}-image.md") | head -20   # diff 摘要
  # 询问:"副本已存在,是否覆盖?回复「覆盖」或「跳过」"
fi
```

2. 确认覆盖(或副本不存在)→ `Bash cp <file.md> {stem}-image.md`(先复制原文为副本)

3. `Read {stem}-image.md`,在心跳记的"图 N 该放第 X 段"位置插图。**插图操作用 python3 脚本执行(禁用 Edit)** —— base64 行可达 ~950KB,Edit 工具无法承载。脚本按 anchor 定位段末空行前,读取 PNG 生成 base64,拼成单行插入,写临时文件再原子替换:

```bash
python3 - "{stem}-image.md" "images/{stem}-image-{NN}.png" "<段末定位标记:该段最后一行内容的唯一子串>" << 'PYEOF'
import base64, os, sys
copy_path, png_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]
b64 = base64.b64encode(open(png_path, "rb").read()).decode()
img = "![](data:image/png;base64," + b64 + ")"
lines = open(copy_path, encoding="utf-8").read().split("\n")
try:
    idx = next(i for i, l in enumerate(lines) if marker in l)          # 段末定位标记行
except StopIteration:
    print(f"[ERROR] 段末定位标记未找到: {marker}", file=sys.stderr); sys.exit(3)
j = next(i for i in range(idx + 1, len(lines)) if not lines[i].strip())  # 段末空行
lines[j:j+1] = ["", img, ""]                                           # 空行位置插入:空行+图片行+空行
open(copy_path + ".tmp", "w", encoding="utf-8").write("\n".join(lines))
os.replace(copy_path + ".tmp", copy_path)
print(f"插入图片行于行 {j + 1} 后(base64 {len(b64)} 字符)")
PYEOF
```

对每张图重复一次(第 N 张图 = 第 N 个 picture,PNG 序号 `{NN}` 对应;`段末定位标记` = anchor 对应段落最后一行内容的唯一子串;标记未找到 → 报错不插入,人工核对 anchor)。**不动原文 paragraph 结构,不改任何原文字符(含标点)**,只在段末空行前插图;禁止插在标题与 `---` 分隔线之间。引用格式固定 base64 data URI 单行(见全局约束 5)。

4. **插图后 diff 校验**(硬规则):`diff <(grep -v '^!') "$ARTICLE" <(grep -v '^!') "{stem}-image.md"`。**副本唯一允许差异 = 图片行(base64)+ 空行**:base64 图片行以 `!` 开头,`grep -v '^!'` 过滤规则继续有效;过滤后 diff 输出中除空行外不得出现任何非空行差异;发现原文行被改动(如引号被换)→ 视为 bug,重新从 Step 5.2 开始。

#### Step 6:报告

```text
[smart-illustrator-minimax 完成]
────────────────────────────────────────────────────────────────────────────
编号 │ 引擎       │ 源文件                              │ status     │ 动作 │ PNG 路径
─────┼────────────┼────────────────────────────────────┼────────────┼──────┼────────────────────
01   │ mermaid    │ images/test-chart-aop.mmd           │ generated  │ 🆕  │ images/test-image-01.png
02   │ excalidraw │ images/test-chart-comparison.excalidraw │ generated │ 🆕 │ images/test-image-02.png
03   │ gemini     │ /tmp/si-prompt-03.txt               │ failed     │ ✖   │ images/test-image-03.png
04   │ mermaid    │ images/test-chart-routing.mmd       │ generated  │ ⏭   │ images/test-image-04.png

动作图例: 🆕 生成(新图) │ 🔄 重生(--regen/--force 覆盖) │ ⏭ 跳过(已有文件) │ ⏭ 跳过(不在重生集合,仅 --regen) │ ✖ 失败

✅ 副本:{stem}-image.md(图片已 base64 内嵌,自包含 —— 拷贝到任何位置打开都显示图片;不引用外部 PNG)
✅ 图片:images/{stem}-image-01.png ...(重生资产,PNG 仍保留在文章目录 images/ 子目录,副本不再引用)
✅ 源文件:images/*.mmd / *.excalidraw(保留可编辑)
✅ manifest:{stem}.si-plan.json(文章目录,v3)
```

报告表格规范:编号**两位零填充**(01 不是 001);`source_file` 列 = 该图的 .mmd/.excalidraw 源文件路径(**相对文章目录、带 images/ 前缀**)或 gemini 的 prompt 文件路径(prompt 在 /tmp,**写绝对路径**并注释说明);PNG 路径列写 `images/{stem}-image-NN.png`(文章目录 images/ 子目录相对路径);status 列如实反映 planned/generated/failed。

## 失败处理

| 情况 | 应对 |
|---|---|
| 路径不存在 / 不可读 | 报错并提示正确路径格式 |
| 路径含空格未加引号 | 报错提示:传入参数已按空格切分,含空格路径必须整体加引号重试 |
| manifest 不存在 + 任一 flag | 报错"manifest 不存在({path}),请先跑一次不带 flag 的完整流程生成",exit 1 |
| manifest 损坏(JSON 解析失败) | 报错"manifest 损坏({path}),请删除后重跑完整流程" |
| manifest 为 v1/旧版 schema | 报错"旧版 manifest({path}),请重跑完整流程升级为 v3",不做 content 重建 |
| manifest 内部不一致(_meta.total ≠ pictures 长度) | 报错,exit 1 |
| 原文已修改(mtime/size 不符) | 路径 1/2/3:警告"原文已修改({date}),图片可能过时",用户回复"继续"才执行 |
| `--regen N` 非正整数 / 超出范围 | 报错"图片共 M 张,N 超出范围(1-M)",**校验前置,任一非法零执行** exit 1 |
| `--regen N` 的图源文件(.mmd/.excalidraw)已删除 | 报错"源文件缺失,请用 --force 重建" |
| `MINIMAX_IMAGE_API_KEY` / `MINIMAX_API_KEY` 均未设 | 立即报错,提示设置其一 |
| minimax 调用参数错误(如误用 --prompt-file/--output) | 立即 `python3 ~/图片/minimax_t2i.py -h` 实测契约修正后重试 |
| minimax prompt 超 1500 字符 | 按压缩策略截断重试 |
| minimax API 调用失败 | 该图跳过,status=failed,继续下一张,最后报告失败列表 |
| mermaid 脚本失败 / `mmdc` 未装 | 同上,提示安装 `npm i -g @mermaid-js/mermaid-cli` |
| excalidraw 脚本失败 / Playwright 未装 | 同上,提示安装 |
| excalidraw JSON 不符规范 | 重新 `Read references/excalidraw-guide.md`,重写一次再导出;仍失败则跳过记录 |
| 副本已存在 | 显示 diff 摘要,询问用户是否覆盖(回复「覆盖」或「跳过」) |
| 副本 {stem}-image.md 不存在(--regen/--force 刷新时) | 跳过引用刷新,报告"副本缺失,引用未刷新" |
| 副本中找不到图片引用/图片行不足(--regen/--force) | 读 manifest 该 picture 的 anchor 定位段落,段末空行前插入 base64 行(脚本,同 Step 5.3);段落也定位失败 → 报告"引用未找到,未插入",继续 |
| 副本图片引用格式不符(旧绝对路径/相对引用/URL 编码) | 整行替换为 base64 data URI 标准格式(脚本,非 Edit),行号记入报告 |
| `-content` 与 `--force` 同传 | 报错"-content and --force are mutually exclusive. Use one or the other." |
| `-content` 智能匹配并列 ≥ 2 | 报错列前 3 候选(id + topic + 命中维度 + 分值);不重生任何图;提示"编号 = 图片文件名后缀数字" |
| `-content` 智能匹配 0 分 | 报错列所有 picture 的 id + topic + anchor;提示"编号 = 图片文件名后缀数字" |
| 未知 engine 值(手改 manifest) | 报错"picture $N engine 非法",跳过该图,纳入失败列表 |

## 输出文件清单

```
{stem}-image.md                       # 副本(图片 base64 data URI 内嵌,单文件自包含;原文不动)
{stem}.si-plan.json                   # manifest(v3,文章目录,与副本平级)
images/
├── {stem}-image-01.png               # PNG(文章目录 images/ 子目录,作者风格命名)
├── {stem}-image-02.png
│   └── ...
├── {chart}.mmd                       # mermaid 源文件(便于后续编辑,命名现状不变)
└── {chart}.excalidraw                # excalidraw 源文件
```

## 非侵入(钉死)

- ❌ 不改 `~/.claude/skills/smart-illustrator/SKILL.md`
- ❌ 不改 `scripts/*.ts`
- ❌ 不改 `styles/*.md`
- ❌ 不改 `references/*.md`
- ❌ 不改 `{stem}.md`(原文)
- ✅ 只写:`{stem}-image.md`、`images/{stem}-image-NN.png`、`images/{chart}.mmd/.excalidraw`、`{stem}.si-plan.json`(均在文章目录内)

## 与原版的关系

- 100% 复用作者 `mermaid-export.ts` / `excalidraw-export.ts`(零改)
- 100% 复用作者的引擎优先级规则
- PNG 命名与作者一致:`{stem}-image-NN.png`(差异:收纳进文章目录 `images/` 子目录,原版在顶层;副本图片用 base64 data URI 内嵌实现自包含,拷到任何地方都显示;重生后按图片行序号整行刷新 base64)
- 唯一差异:Gemini API → minimax API(因为没订阅 Gemini;调用契约按实测记录)
- 路径 1/2/3 早退分支复用 `skip-existing` 逻辑,跳过 Read 全文/cp 副本,但每张覆盖成功后执行「副本引用刷新」(只动副本图片行,不重新分析)
- manifest v3:位置迁至文章目录、恢复 status、新增 source_mtime/source_size 陈旧检测
