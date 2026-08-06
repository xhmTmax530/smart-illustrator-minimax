---
description: smart-illustrator 的 minimax 替代版 — 文章配图(用 minimax API 替代 Gemini,严格复用作者原生 mermaid/excalidraw 脚本)
argument-hint: <file.md> [extra hints...]
allowed-tools: Read Write Edit Bash Glob
---

# /smart-illustrator-minimax — 文章配图(minimax 替代 Gemini) v3.8

> **非侵入式增强**:不修改作者任何文件(`SKILL.md` / `scripts/*` / `styles/*` / `references/*`),完全复用作者的 `mermaid-export.ts` 与 `excalidraw-export.ts`,仅把 Gemini API 替换为本地 `minimax_t2i.py`。
>
> **v3.3 变更**:① 全部机器产物收敛到文章目录 `{stem}_images/` 子目录(manifest / 副本 / PNG / .mmd/.excalidraw 源文件),原文 `{stem}.md` 留在文章目录顶层;② mermaid/excalidraw 重生改为"从 manifest 的 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG",不再只重渲染旧源文件,旧源文件缺失也不再是错误(见「风格轮换规范」)。
>
> **v3.4 变更(封面功能,对齐作者)**:① 完整流程**默认每篇生成 1 张封面** `{stem}_images/{stem}-cover.png`(作者 article 模式默认行为,`--no-cover` 关闭);封面主题(核心概念+视觉隐喻)在心跳分析时与正文图同源提炼,manifest 新增**可选** `_meta.cover`(旧 manifest 无此字段 = 封面未生成,兼容);② `--regen cover` 只重生封面;`--cover-ratio <X:Y>` 指定封面比例(默认 16:9);③ 封面**不插入正文**,以副本 YAML frontmatter 声明(字段 `cover: {stem}-cover.png`,作者字段名未定、由本命令自定义;原文永不动,声明只写副本);④ 封面 prompt 采用 **Axton Cover Identity**(纯黑 #0A0A0A 虚空 + 琥珀金 #F59E0B 主光 ~70% + 天空蓝 #38BDF8 辅光 ~30%,零文字,主体 30-50%,中央 71% 高度安全区),走 minimax(gemini 分支契约),API 天然随机无需风格轮换(见「封面规范」)。
>
> **v3.5 变更(封面声明从 manifest 读取)**:⑤ `_meta.cover` 新增可选字段 `filename`(封面文件名,完整流程写入;frontmatter 声明改为从 manifest 读取,缺失回退约定式 `{stem}-cover.png`,旧 manifest 零迁移)。
>
> **v3.6 变更(封面在副本中双重表示)**:⑥ 封面在副本中**双重表示**:frontmatter `cover:` 声明(程序消费)+ 副本第一个标题后插入 `![](<cover文件名>)` 相对路径引用行(markdown 编辑器直接显示;引用行以 `!` 开头,天然被 `grep -v '^!'` 过滤,不产生 diff 差异;非 base64,不参与副本 data URI 刷新序号)。
>
> **v3.7 变更(封面在副本中 base64 内嵌)**:⑦ 封面在副本中的表示改为 **base64 data URI 内嵌**(格式 `![cover](data:image/png;base64,...)`,alt 固定 `cover`;与正文图同方式,任何 markdown 编辑器 100% 可见,消除文件名空格/中文的路径解析问题)。封面行以 `!` 开头被 `^!` 过滤(diff 规则零新增);刷新机制以 `^!\[cover\]\(` 前缀识别并跳过封面行,正文图按序计数不受影响;封面重生后封面行**整行刷新**(替换新 base64),非仅保持
>
> **v3.8 变更(封面缩略图内嵌 + manifest anchor 字段)**:⑧ **封面内嵌行改用缩略图**:封面 PNG 生成/转码成功后额外生成 `{stem}-cover-thumb.png`(ffmpeg 缩放 640px 宽,`-compression_level 9`,实测 ~158KB ≤200KB),封面内嵌行 base64 改用缩略图(≤~211K 字符,消除超长行导致 MarkText/VSCode 等编辑器不显示的问题);原图 `{stem}-cover.png` 保留在 {stem}_images/(发布平台用),不删除、不进副本;缩略图命名固定约定式、**不进 manifest**(manifest 只记原图文件名 `filename`);缩略图生成失败回退原图 base64 内嵌(不阻塞,报告注明)。⑨ **`_meta.cover` 新增可选 `anchor` 字段**(封面内嵌行插入位置描述,默认约定值"第一个一级标题之后"):完整流程写全字段(含 anchor,值 = 默认值或按实际插入逻辑描述),`--regen cover` 补写/保持,`--force` 仅 status(缺失回退默认);封面内嵌行插入/刷新时读 anchor —— 缺失/默认 → 现状逻辑(第一个 `# ` 一级标题后),其他描述 → 按正文图 anchor 定位逻辑插入(段末空行前;定位失败 → 回退第一个 `# ` 标题后,报告注明)。⑩ **兼容性**:旧 manifest 无 anchor / 无缩略图 → 缺失回退默认值 / 回退原图 base64,零迁移,validate-manifest.sh 只校验必需字段,无需改动。⑪ **frontmatter 闭合空行根因修复**:封面不可见的真正根因 —— frontmatter 闭合 `---` 后无空行时,MarkText/VSCode 的 frontmatter 正则要求闭合后空行或文件末尾,否则惰性扫描到文中下一个 `---`(原文分隔线)才闭合,标题+封面行全被吞进 YAML 代码块显示为原始文本;修复:frontmatter 声明/新建**三情形统一保证闭合 `---` 后为一行空行**(情形 1/2 检测闭合后一行非空 → 补空行;情形 3 新建时 `---` 后直接带空行),封面内嵌行插入/刷新前加**结构修复前置**(副本闭合后无空行 → 先补空行,刷新存量副本顺带修复)。

## 输入

`$ARGUMENTS` = `<file.md> [flags] [extra hints...]`

- 第 1 段(必填):文章绝对或相对路径(`~` 自动展开,**含空格的路径必须加引号**)
- 后续(可选,顺序无关):flags 或用户偏好(自然语言,如"重点配架构图,少隐喻"),Claude 据此调整选 engine / 数量 / 风格

## 参数

| 参数 | 默认 | 说明 |
|------|------|------|
| `--regen N` | - | 只重生第 N 张(N≥1,图片编号),其余已有图跳过(不管是否变更) |
| `--regen cover` | - | 只重生封面(`{stem}_images/{stem}-cover.png`)。封面主题取自 manifest `_meta.cover`;该字段缺失时读原文做轻量主题提取(仅补写 `_meta.cover`,不重规划正文图);副本封面内嵌行用缩略图 `{stem}-cover-thumb.png`、插入位置读 `_meta.cover.anchor`(v3.8) |
| `--force` | `false` | 无视已有文件,全部重新生成(含封面,除非 `--no-cover`) |
| `-content "..."` | - | 自然语言描述目标图（不用记编号）。按 topic/anchor/content 打匹配分,唯一最高分自动选中(只匹配正文图,封面不参与) |
| `--no-cover` | `false` | 本次**不生成/不重生封面**:完整流程跳过封面生成与 frontmatter 声明,`--force` 跳过封面重生;副本中已有的 cover 声明保留不动 |
| `--cover-ratio <X:Y>` | `16:9` | 封面宽高比,如 `--cover-ratio 3:4`。minimax 实测仅确认支持 16:9;传其他比例时先 `python3 ~/图片/minimax_t2i.py -h` 实测支持列表,不支持 → 警告并回退 16:9 |

> **互斥规则(Step 0 路由之前无条件检测)**:
> - `-content` 与 `--force` 同传 → **硬互斥,报错退出**,提示 `Use one or the other`
> - `--regen` 与 `--force` 同传 → `--force` 优先(全量重来),warning 中明确"已忽略 --regen"
> - `-content` 与 `--regen`(含 `--regen cover`)同传 → `--regen` 优先(显式更精确),路径 3 跳过
> - `--no-cover` 与 `--regen cover` 同传 → `--no-cover` 优先,忽略 `--regen cover`,warning 中明确"已忽略 --regen cover"
>
> `--regen` 允许多次指定,参数为**正整数**或 **`cover`**,可混用:`--regen 2 --regen cover` 只重生第 2 张与封面。正整数参数非法值(`--regen=3`、`--regen abc`、`--regen 2.5`)报错;`cover` 为保留字不参与范围校验。
>
> 重生机制:PNG 固定写入 `{stem}_images/{stem}-image-NN.png`,副本引用一律 **base64 data URI 内嵌**(`![](data:image/png;base64,<...>)` 单行,自包含 —— 拷贝到任何地方打开都显示图片)。覆盖 PNG 后**必须**执行「副本引用刷新」(路径 1/2 内建):按图片行序号命中即整行替换为新 base64 行,缺失按 anchor 定位插入。**定位正文图行时排除封面行**(以 `![cover](` 开头),封面行不参与正文图计数;封面行仅在封面流程(1c/路径 2/完整流程 4d)时更新。

## 全局约束

1. **原文永不动(硬规则)**:复制为 `{stem}_images/{stem}-image.md`(副本收敛在该文章专属目录内),所有写入副本。**禁止改动原文任何文字,包括引号、全角标点等细微字符**;插图后必须跑一次 `diff` 校验。**副本唯一允许差异 = 图片行(base64)+ 空行 + frontmatter 的 cover 声明行(v3.4)**:`grep -v -e '^!' -e '^cover: '` 过滤规则;过滤后 diff 中除空行外不得出现任何非空行差异;任何对原文行的改动视为 bug 立即重试。**封面内嵌行(v3.7;v3.8 起内嵌 base64 为缩略图 `{stem}-cover-thumb.png` 的 base64)以 `!` 开头(格式 `![cover](data:image/png;base64,...)`),被现有 `^!` 过滤规则覆盖,无需新增过滤项**。
2. **Engine 枚举**(严格作者 `--engine` 值,不自定义): `gemini` | `excalidraw` | `mermaid`
3. **PNG 命名(作者风格)**: `{stem}_images/{stem}-image-{NN}.png`,**文章目录 {stem}_images/ 子目录**(先 `mkdir -p {stem}_images`),NN 两位零填充从 01(如 `{stem}_images/{stem}-image-03.png`)。不与副本 `{stem}_images/{stem}-image.md` 冲突(.md vs .png)。
4. **mermaid 默认 PNG**(走作者 `mermaid-export.ts`),不是代码块;excalidraw 永远 PNG(走 `excalidraw-export.ts`)。源文件命名保持 `{chart}.mmd` / `{chart}.excalidraw` 现状。
5. **插入机制**:Claude 心跳记忆 — 同一个会话里读完文章 → 出图 → 写副本,"图 N 该放第 X 段"在 context window 里。**插图只插目标段落末尾空行之前;禁止插在标题与分隔线(`---`)之间**(图归属必须清晰)。**副本引用格式固定 base64 data URI 单行**:`![](data:image/png;base64,<base64>)` —— 单行、无尖括号包裹、无空格/换行,base64 以 `iVBOR` 开头(PNG 魔数)。生成命令:`python3 -c "import base64,sys;print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" <png>`。**base64 行可达 ~950KB,插图/刷新一律用 python3 脚本操作(禁用 Edit 工具)**:脚本定位 → 拼单行 → 写临时文件 → `os.replace` 原子替换。
6. **复用作者脚本**(完全不改):
   - `scripts/mermaid-export.ts`(mmdc 出 PNG)
   - `scripts/excalidraw-export.ts`(Playwright + Firefox + excalidraw.com)
7. **唯一新依赖**: `~/图片/minimax_t2i.py`(用户本地 minimax 出图脚本,仅替代 `generate-image.ts` 里的 Gemini API 调用)
8. **manifest = 控制平面(必做)**:路径 4 必写 `{stem}_images/{stem}.si-plan.json`(文章目录 `{stem}_images/` 子目录,与副本/PNG 同处),路径 1/2/3 只读。schema `si-minimax/v3`(v3.4 新增**可选** `_meta.cover` 对象,旧 manifest 无此字段 = 封面未生成,兼容,不必升级);`_meta.cover` 字段表:v3.5 起含**可选** `filename` —— 封面文件名(`{stem}-cover.png`,相对 `{stem}_images/` 裸文件名;可选字段,缺失回退约定式,旧 manifest 零迁移);v3.8 起含**可选** `anchor` —— 封面内嵌行插入位置描述(默认约定值"第一个一级标题之后",即副本第一个 `# ` 一级标题行后;可选字段,缺失回退默认,旧 manifest 零迁移)。
9. **早退分支**:manifest 存在 + flag 触发时,跳过 Read 全文 + cp 副本,只覆盖同名 PNG + 执行「副本引用刷新」(仅动副本图片行,不重新分析)。
10. **manifest 铁律(分层约束,措辞绝对化)**:
    - **绝对禁止改动(硬规则)**:manifest 一旦写盘,`pictures` 数组的**结构** —— 每张的 `id`/`engine`/`topic`/`content`/`anchor`/`source_file`/`source_prompt`、数组顺序 —— 以及 `_meta` 全部**原有**字段(`source`/`source_mtime`/`source_size`/`produced_at`/`total`/`by_engine`),**任何理由、任何步骤(含 `--regen`/`--force`/`-content`/完整流程)一律禁止修改**。它是锚定参考文件,动了会导致:副本刷新错位、引擎分发错误、anchor 自愈失效。
    - **唯一允许写入 = `status` 字段**(`planned` → `generated`/`failed`),且**只能由命令脚本的 jq 命令更新,不经大模型判断**。
    - **封面字段例外(v3.4)**:`_meta.cover`(**新增可选字段**,正文 pictures 与 `_meta` 原有字段的铁律不因它松动)由封面流程专用 —— **完整流程写全字段**(`topic`/`metaphor`/`prompt`/`ratio`/`status`,含 v3.5 新增可选 `filename` 与 v3.8 新增可选 `anchor`,anchor 值 = "第一个一级标题之后" 或按实际插入逻辑描述);`--regen cover` 可更新 `prompt` 与 `status`(缺失补写 topic/metaphor 时一并写 `filename`/`anchor`);`--force` 仅更新 `status`(anchor 缺失时读取回退默认值)。封面不进入 `pictures`(不插入正文插图、不参与 -content 匹配、不参与副本正文图刷新计数;封面行仅在封面流程更新);副本中封面为**双重表示**(v3.7;v3.8 起内嵌行为缩略图 base64):frontmatter `cover:` 声明(程序消费)+ 正文首个标题后 `![cover](data:image/png;base64,...)` 内嵌行(编辑器消费,base64 为缩略图 `{stem}-cover-thumb.png`(640px 宽 ≤200KB,~211K 字符),与正文图同方式,任何 markdown 编辑器 100% 可见)。
    - **重新规划 ≠ 修改**:原文大改或用户要求「重新分析」时,走路径 4 **整体重写** manifest(产生新锚定),禁止复用旧 manifest 逐字段编辑。
    - **触发场景**:路径 1/2/3 发现 manifest 内容与预期不符(如 status 异常)→ **只报错/跳过,不修复、不改写**;提示用户删除 manifest 后重跑完整流程。

## 执行步骤

### Step 0:cd + manifest 检测 + 早退分流

> **此步必须在做任何分析之前最先执行**。manifest 是早退分支的唯一控制平面。

#### 0.0 强制 cd(所有路径第一步)

```bash
ARTICLE="$(realpath -m "$FILE")"        # 规范化绝对路径
cd "$(dirname "$ARTICLE")"              # 此后所有相对路径一律以文章目录为基准解析
```

所有路径(1/2/3/4)的第一步都是这个 cd,后续 mkdir / 写 PNG / 读源文件 / 写副本全部在文章目录解析,与调用时的会话 cwd 无关。`{stem}_images/` 是文章目录下的子目录;解析 manifest 中 `source_file` 时以 `{stem}_images/` 为基准(无前缀裸文件名)。

#### 0.1 manifest 定位

```bash
STEM="$(basename "$ARTICLE" .md)"
IMG_DIR="${STEM}_images"                                 # 该文章全部机器产物目录(manifest/副本/PNG/源文件)
MANIFEST="${IMG_DIR}/${STEM}.si-plan.json"               # 新位置:文章目录 {stem}_images/ 子目录
LEGACY_MANIFEST="/tmp/si-plan-${STEM}.json"              # 旧位置 v1(仅兼容查找)
LEGACY_MANIFEST2="${STEM}.si-plan.json"                  # 旧位置 v3.2(文章目录顶层,仅兼容查找)
```

查找顺序:
1. `$MANIFEST`(`{stem}_images/{stem}.si-plan.json`)存在 → 用它
2. 不存在但 `$LEGACY_MANIFEST`(/tmp)或 `$LEGACY_MANIFEST2`(文章目录顶层,即 v3.2 旧布局)存在 → **提示"manifest 已迁移到 {stem}_images/({MANIFEST}),请重跑完整流程刷新"**,然后按"manifest 不存在"处理(见 0.5)
3. 都不存在 → "manifest 不存在"

#### 0.2 读前 JSON 校验(manifest 存在时)

```bash
jq -e . "$MANIFEST" >/dev/null 2>&1 || {
  echo "[ERROR] manifest 损坏(${MANIFEST}),请删除后重跑完整流程"
  exit 1
}
```

#### 0.3 schema 校验

- `_meta.schema == "si-minimax/v3"` → 正常(旧 v3 无 `_meta.cover` = 封面未生成,兼容,视为封面缺失,不拒绝)
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
| manifest 不存在 + 无 flag | 路径 4(完整流程;`--no-cover`/`--cover-ratio` 为修饰 flag,不触发报错) |
| manifest 存在 + `--force` | 路径 2(含封面,除非 `--no-cover`) |
| manifest 存在 + `--regen`(N 和/或 `cover`) | 路径 1(数字走正文执行体,`cover` 走 1c 封面执行体) |
| manifest 存在 + `-content "..."` | 路径 3 |
| manifest 存在 + 无 flag + 原文未变 | **询问复用/重新分析**(见 0.6) |
| manifest 存在 + 无 flag + 原文已变 | 路径 4 重新分析(带"原文已修改"提示) |

**manifest 不存在 + flag → 统一报错,绝不静默回退路径 4**:

```bash
echo "[ERROR] manifest 不存在(${MANIFEST}),请先跑一次不带 flag 的完整流程生成"
exit 1
```

> **注意**:即使 manifest 存在,路径 1/2/3 执行中遇到边界错误(API 不可用/渲染失败等)也只跳过该图、记录失败,**绝不退回路径 4 的全文分析流程**。重生时旧源文件缺失不构成错误 —— mermaid/excalidraw 一律从 content 重新生成源文件(见「风格轮换规范」)。

#### 0.6 无 flag 重跑分流(manifest 存在 + 原文未变)

展示 manifest 摘要表(编号两位/引擎/源文件/status),然后询问:

> "复用现有规划(推荐,幂等)还是重新分析?回复「复用」或「重新分析」"

- **「复用」** → 保持现有 manifest 规划,走路径 4 的 skip-existing 执行体(已有 PNG 跳过、缺失的补生成、写副本),**不做 LLM 重新分析**;封面:v3.4 起 `_meta.cover` 存在 → 按存的 prompt skip-existing 处理;旧 manifest 无 `_meta.cover` → 不读原文,跳过封面并提示"封面未规划(manifest 无 _meta.cover),请重新分析或 --regen cover"
- **「重新分析」** → 走路径 4 完整流程(重新 LLM 分析并重写 manifest,含封面主题)

---

### 路径 1:--regen N 早退

> manifest 存在 + `--regen N` → 绝对不读原文(不重新分析),只覆盖同名 PNG;成功后执行「副本引用刷新」(见 1.2 末尾)。

#### 1.1 输入校验(前置全量校验,任一非法 → 零执行)

```bash
TOTAL=$(jq '.pictures | length' "$MANIFEST")
META_TOTAL=$(jq '._meta.total' "$MANIFEST")
[[ "$TOTAL" == "$META_TOTAL" ]] || { echo "[ERROR] manifest 内部不一致(_meta.total ≠ pictures 长度)"; exit 1; }

REGEN_FAILED=0
REGEN_COVER=0                        # 1 = 重生集合含 cover(v3.4)
declare -A SEEN=()
for N in $REGEN_IDS; do
  if [[ "$N" == "cover" ]]; then
    REGEN_COVER=1; continue          # 保留字,不参与数字范围校验,执行体见 1c
  fi
  if ! [[ "$N" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] --regen $N: 必须为正整数或 cover"
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

**校验通过才逐个执行**——绝不在校验循环里先做任何重生(避免"合法的先做了、非法的后报错"的部分副作用)。正文 id 按 1.2 执行体,`cover` 按 1c 封面执行体;执行顺序:先正文 id 后封面。

#### 1.2 早退执行体

对每个有效 `N`(已去重、已验证范围):

1. **按 id 查找**(禁止 `pictures[N-1]` 下标):

```bash
PIC_JSON=$(jq -e --argjson id "$N" '.pictures[] | select(.id == $id)' "$MANIFEST") || {
  echo "[ERROR] picture $N 不存在"; exit 1; }
```

2. 读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`
3. 未知 engine(不在 gemini/excalidraw/mermaid 枚举)→ 报错"picture $N engine 非法,已跳过",纳入失败列表,继续下一张
4. 拼凑 PNG 路径:`${IMG_DIR}/${STEM}-image-$(printf '%02d' $N).png`(文章目录 {stem}_images/ 子目录;执行前 `mkdir -p "${IMG_DIR}"`)

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
  && mv /tmp/si-out-${NN}/minimax-0.jpeg "${IMG_DIR}/${STEM}-image-${NN}.png"
# mv 后必须执行「格式统一规范」(Step 4a 末尾:file 检测 + ffmpeg 转码为真 PNG)
```

- prompt 文件用 HEREDOC 写入 `/tmp/si-prompt-${NN}.txt`(避免 shell 转义),写入后 `wc -c` 校验 ≤1500(压缩策略见 Step 4a)
- 产物 `minimax-0.jpeg` 实测是 **JPEG 编码(1280×720)**,`mv` 只换扩展名不换编码 —— 严格按扩展名解析的工具会解码失败。**mv 后必须执行「格式统一规范」**(Step 4a 末尾:file 检测,JPEG 则 ffmpeg 转码为真 PNG)
- **绝对不能用 `--prompt-file` / `--output` 这两个不存在的 flag**
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**mermaid 分支(重生 = 从 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG)**:
- 读 manifest 该 picture 的 `content`(+`topic`/`anchor`),按「风格轮换规范」重新生成源文件写入 `{stem}_images/{source_file}`(**禁止 Read 磁盘旧 .mmd 照抄**,只读 manifest content)
- 旧源文件缺失不是错误 —— 重生一律按 content 重建源文件;`source_file` 以 `{stem}_images/` 为基准解析(无前缀裸文件名)
- `npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts -i {stem}_images/{source_file} -o {PNG_PATH} -w 2400`
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**excalidraw 分支(重生 = 从 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG)**:
- 读 manifest 该 picture 的 `content`(+`topic`/`anchor`),按「风格轮换规范」重新生成源文件写入 `{stem}_images/{source_file}`(**禁止 Read 磁盘旧 .excalidraw 照抄**,只读 manifest content)
- 旧源文件缺失不是错误 —— 重生一律按 content 重建源文件;`source_file` 以 `{stem}_images/` 为基准解析(无前缀裸文件名)
- `npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts -i {stem}_images/{source_file} -o {PNG_PATH} -s 2`
- 成功:覆盖 PNG 并更新 status;失败:跳过,记录 failed

**副本引用刷新(成功覆盖 PNG 后必做;只动副本图片行,不读原文分析;失败图不刷)**:

对每张成功重生的图(在更新 status 之前):

1. 副本 `{stem}_images/{stem}-image.md` 不存在 → 跳过本步,报告"副本缺失,引用未刷新"
2. **定位图片行(注意:base64 行不含文件名,原 `grep image-NN.png` 已失效)**:副本图片行按顺序对应 picture id —— manifest pictures 按 id 升序,副本插图顺序与之一致,第 N 张图 = 第 N 个图片行。先取序号:`Bash grep -n '^!\[\](data:image/png;base64,' "{stem}_images/{stem}-image.md"` → 取第 N 个匹配行(行号记入报告);**定位正文图行时排除封面行**(以 `![cover](` 开头),封面行不参与正文图计数;封面行仅在封面流程(1c/路径 2/完整流程 4d)时更新
3. **命中** → 用 python3 脚本整行替换为新 PNG 的 base64 行(**禁用 Edit**,行可达 ~950KB;写临时文件再原子替换):

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

4. **未命中**(脚本退出码 2:引用被删/图片行不足/顺序错乱)→ 读 manifest 该 picture 的 `anchor`,`Read` 副本定位该段 → **段末空行前插入** base64 行(插入脚本同 Step 5.3;全流程唯一需要 LLM 心跳定位的步骤);段落定位失败 → 报告"引用未找到,未插入",不阻塞后续

每张图执行后更新 manifest 中该 picture 的 status:

```bash
jq --argjson id "$N" --arg s "generated" \
  '(.pictures[] | select(.id == $id) | .status) = $s' "$MANIFEST" > "${MANIFEST}.tmp" \
  && mv "${MANIFEST}.tmp" "$MANIFEST"
```

#### 1c.--regen cover 封面早退执行体(v3.4)

> `REGEN_COVER=1` 时执行(可与正文 id 混用,封面在正文 id 之后执行)。**只碰封面,不碰正文图片、不重规划正文图**。封面走 minimax(gemini 分支契约,见「封面规范」),API 天然随机,无需风格轮换。早退原则放宽的唯一例外:仅当 `_meta.cover` 缺失时读原文做轻量主题提取(用户明确点名封面,值得一次读取)。

1. 封面路径:`COVER_PNG="${IMG_DIR}/${STEM}-cover.png"`;执行前 `mkdir -p "${IMG_DIR}"`。**解析封面文件名**(frontmatter 声明与补写统一用):
   ```bash
   COVER_FILE=$(jq -r '._meta.cover.filename // ""' "$MANIFEST")
   [[ -n "$COVER_FILE" ]] || COVER_FILE="${STEM}-cover.png"   # 旧 manifest 缺失 filename → 约定式回退(变量可能含空格,引用一律加引号)
   ```
2. **封面主题与 prompt 来源**(jq 读取 `._meta.cover`):
   - `_meta.cover.prompt` 非空 → 直接用
   - `prompt` 为空但 `topic`/`metaphor` 存在 → 按「封面规范」重拼 prompt(更新 `_meta.cover.prompt`)
   - `_meta.cover` 整个缺失(v3.3 及更早 manifest)→ **唯一例外 Read 原文**:`Read {stem}.md` 轻量提炼核心概念 + 视觉隐喻,按「封面规范」拼 prompt,补写 `_meta.cover`(topic/metaphor/prompt/ratio/status/**filename**/**anchor**(默认"第一个一级标题之后");只补封面字段,不动 `pictures` 与 `_meta` 原有字段)
3. prompt 写入 `/tmp/si-cover-prompt.txt`(HEREDOC,避免 shell 转义),`wc -c` 校验 ≤1500(超限按「封面规范」压缩策略截断)
4. 比例:**显式初始化** `COVER_RATIO="16:9"; [[ -n "$COVER_RATIO_ARG" ]] && COVER_RATIO="$COVER_RATIO_ARG"`(flag 解析:`--cover-ratio` 的值存入 `COVER_RATIO_ARG`);`--cover-ratio` 指定其他值时先 `python3 ~/图片/minimax_t2i.py -h` 实测支持列表,不支持 → 警告"脚本不支持比例 ${X},已回退 16:9"
5. key/脚本检查(同 1.2 gemini 分支)→ 调用:

```bash
python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-cover-prompt.txt)" \
  --out /tmp/si-out-cover --ratio "${COVER_RATIO}" \
  && mv /tmp/si-out-cover/minimax-0.jpeg "${COVER_PNG}"
```

6. **格式统一规范**(Step 4a 末尾:file 检测,JPEG 则 ffmpeg 转码为真 PNG);**缩略图生成(v3.8,格式统一成功后执行)**:封面 PNG 生成/转码成功后额外生成内嵌用缩略图 `{stem}-cover-thumb.png`(命名固定约定式,不进 manifest):`ffmpeg -y -loglevel error -i "${COVER_PNG}" -vf "scale=640:-1" -compression_level 9 "${IMG_DIR}/${STEM}-cover-thumb.png"`(640px 宽,实测 ~158KB ≤200KB;生成失败或 ffmpeg 不可用 → **回退用原图 base64 内嵌,不阻塞**,报告中注明"缩略图生成失败,内嵌用原图")
7. 成功 → 更新 status;失败 → status=failed,报告失败,不阻塞正文 id 的执行:

```bash
jq --arg s "generated" '._meta.cover.status = $s' "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"
```

8. 成功后 → **副本 frontmatter 声明同步**:确保副本 `{stem}_images/{stem}-image.md` frontmatter 含 `cover: ${COVER_FILE}`(值取自 manifest `_meta.cover.filename`,缺失按约定式回退;缺失则补,脚本见路径 4 Step 5 的 3.5);**随后执行封面内嵌行插入/刷新(v3.8)**:插入/刷新 base64 内嵌行 `![cover](data:image/png;base64,{base64})`(base64 由 `base64 -w0 "${IMG_DIR}/${STEM}-cover-thumb.png"` 生成,封面**缩略图**路径;缩略图缺失/生成失败 → 回退原图 `base64 -w0 "${IMG_DIR}/${COVER_FILE}"`,报告中注明;独占一行,前后各留一个空行);**有 `![cover](data:image/png;base64,` 前缀行 → 整行替换**(封面重生后内容变了,必须刷新,非仅保持;行位置不变,无需 anchor 定位);无 → **读 manifest `_meta.cover.anchor` 定位插入**:缺失或等于默认值"第一个一级标题之后" → 在副本第一个 `# ` 一级标题行之后插入;其他描述 → 按正文图 anchor 定位逻辑(Read 副本定位该段落,段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;规范见「Step 5 封面内嵌行」);副本不存在 → 声明与内嵌行一并跳过,报告"副本缺失,封面声明未写入"

#### 1.3 完成报告(表格格式见 Step 6,status 列如实反映)

```
路径 1 完成 — 副本引用已刷新(2 行整行替换;1 张副本缺失未刷)
重生: 2, 5 (共 2 张);失败: 5 (minimax API 不可用);跳过: 1, 3, 4 (不在 regen 集合)
封面: 重生(生成) / 失败 / 跳过(--no-cover 或未规划) —— 命中时单独一行,见 Step 6 封面行格式
```

> 失败与跳过互斥:失败只列 regen 集合内执行失败的 ID,同一张图不会同时出现在失败与跳过里。

---

### 路径 2:--force 早退

> manifest 存在 + `--force` → 遍历所有 pictures,全量重生(每张从 content 重新生成源文件 + 风格轮换 → 渲染 → 覆盖 PNG),每张成功后执行「副本引用刷新」(规范同路径 1.2)。旧源文件缺失无碍 —— 一律按 content 重建(见「风格轮换规范」)。

#### 2.1 早退执行体

```
Bash mkdir -p {stem}_images   # 文章目录 {stem}_images/ 子目录(全部机器产物收纳地)
FORCE_MODE=true
```

对每张 picture(按 id 遍历 `jq '.pictures[]'`):
1. 读取 `engine` / `topic` / `content` / `source_file` / `source_prompt`
2. 拼凑 PNG 路径:`${IMG_DIR}/${STEM}-image-$(printf '%02d' $N).png`
3. engine 分支 —— **调用规范 + 格式统一与路径 1 完全相同**(gemini 走实测 minimax 契约;mermaid/excalidraw 走作者脚本):
   - gemini:HEREDOC 写 prompt 到 `/tmp/si-prompt-${NN}.txt`(≤1500 压缩策略同 Step 4a)→ `python3 ~/图片/minimax_t2i.py "$(cat ...)" --out /tmp/si-out-${NN} --ratio 16:9` → `mv /tmp/si-out-${NN}/minimax-0.jpeg {PNG}` → **格式统一规范(Step 4a 末尾):file 检测,JPEG 则 ffmpeg 转码为真 PNG**
   - mermaid:按「风格轮换规范」从 content 重新生成源文件写入 `{stem}_images/{source_file}` → `mermaid-export.ts -i {stem}_images/{source_file} -o {PNG} -w 2400`(旧源文件缺失无碍,一律重建)
   - excalidraw:同上从 content 重新生成源文件 → `excalidraw-export.ts -i {stem}_images/{source_file} -o {PNG} -s 2`
4. **成功覆盖 PNG 后 → 执行「副本引用刷新」(规范同路径 1.2,失败图不刷;定位正文图行时排除封面行,封面行仅在封面处理步骤更新)**
5. 每张执行后更新 manifest 的 status(generated / failed)
6. **封面处理(v3.4;`--no-cover` 时整步跳过)**:正文遍历完成后执行封面重生(执行体同 1c 第 2-8 步,但**不读原文**):
   - `_meta.cover.prompt` 非空 → 用存的 prompt 按 `--cover-ratio`(默认 16:9)重生
   - `_meta.cover` 缺失 → **跳过封面**,报告"封面未规划(manifest 无 _meta.cover),跳过;请跑完整流程或 --regen cover"(--force 为早退,不读原文提取主题)
   - 成功 → 更新 `_meta.cover.status` + 副本 frontmatter 声明同步(声明值 = 从 manifest 解析的 COVER_FILE:`jq -r '._meta.cover.filename // ""' "$MANIFEST"`,缺失回退约定式 `{stem}-cover.png`)+ **封面内嵌行插入/刷新**(v3.8:有 `![cover](data:image/png;base64,` 前缀行 → **整行替换**为新 base64(`base64 -w0` 读取缩略图 `{stem}-cover-thumb.png`,缺失/生成失败 → 回退原图);无 → 读 manifest `_meta.cover.anchor` 定位插入:缺失/默认"第一个一级标题之后" → 副本第一个 `# ` 标题行后;其他描述 → 正文图 anchor 定位逻辑(段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;独占一行,前后各留空行,规范见「Step 5 封面内嵌行」);失败 → status=failed,不阻塞
7. **全部遍历完成后 → 孤儿文件检测(仅提示,不删除)**:遍历 `{stem}_images/{stem}-image-*.png`,文件名序号不在 manifest pictures id 集合 → 提示"孤儿文件 {file}(manifest 未记录,未删除)"。脚本:

```bash
python3 - "$STEM" "$MANIFEST" << 'PYEOF'
import glob, json, re, sys
stem, manifest = sys.argv[1], sys.argv[2]
ids = {str(p["id"]) for p in json.load(open(manifest))["pictures"]}
for f in sorted(glob.glob(f"{stem}_images/{stem}-image-*.png")):
    m = re.search(r"image-(\d+)\.png$", f)
    if m and m.group(1).lstrip("0") not in ids:
        print(f"孤儿文件 {f}(manifest 未记录,未删除)")
PYEOF
```

#### 2.2 完成报告

```
路径 2 完成 — 副本引用已刷新(3 张整行替换;1 张副本缺失未刷)
全量重生: 3 张;失败: 1 张 (minimax API 不可用)
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

> **提示(并列/零命中报错末尾必带)**:编号 = 图片文件名后缀数字(如 `{stem}_images/{stem}-image-03.png` → 03)。

---

### 路径 4:默认全流程（原 Step 1-6,v3 修订）

> 进入条件:manifest 不存在 + 无 flag(完整流程);或 manifest 存在 + 无 flag + 原文已变(重新分析);或「复用」分支复用现有 manifest。

#### Step 1:读原文

- `Read <file.md>` 全文(若极长,按章节分批读)

#### Step 2:心跳分析(Claude LLM 决策)

按作者 SKILL.md `Step 1` 启发式:

1. 识别 **3-5 个**配图位置(短文 1-2,中篇 2-4,长文 4-6,教程每主步骤 1 张)
2. 为每张定 engine,优先级: `gemini`(隐喻/情感/封面) → `excalidraw`(手绘概念/对比/简单流程 ≤8 节点) → `mermaid`(复杂流程 >8 节点/多层架构/时序)。> 澄清:封面**不在 pictures 之列**,此处"封面"仅指封面生成引擎(固定 gemini/minimax,见「封面规范」);pictures 只承载正文插图
3. 心跳里记好:**每张图对应文章哪段**(用简短描述,例如"图 2 在讲 Spring 三层架构那段后")
4. 给每张定 PNG 序号(01, 02, ...)和 PNG 命名(`{stem}_images/{stem}-image-{NN}.png`)
5. **封面主题(v3.4,`--no-cover` 时跳过本步)**:与正文图同源提炼 —— 封面**核心概念**(文章一句话主题)+ **视觉隐喻**(承载该主题的具象物体/场景,如"破碎的玻璃立方体"隐喻"系统安全缺失")。中文推导、英文生成(见「封面规范」)。记入心跳,Step 3 写入 `_meta.cover`

> ⚠ 这步**没有任何写盘动作**。JSON 还没生成。
>
> **「复用」分支跳过本步**:沿用 manifest 现有 pictures,直接走 Step 3(不重写)→ Step 4 → Step 5。
>
> **原文已变提示**:若 Step 0 陈旧检测命中,先提示"原文已修改({date}),本次按当前内容重新分析"再继续。

#### Step 3:(必做)写 manifest

> **此步必做** —— v3 manifest 是早退分支的控制平面。写完必须 `jq -e .` 校验,失败立即报错重写。

```
Write {stem}_images/{stem}.si-plan.json   # 文章目录 {stem}_images/ 子目录,与副本/PNG 同处
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
    "by_engine": { "gemini": <M>, "excalidraw": <E>, "mermaid": <R> },
    "cover": {
      "topic": "<核心概念,中文,如 系统安全缺失>",
      "metaphor": "<视觉隐喻,中文,如 破碎的玻璃立方体>",
      "prompt": "<完整英文 prompt,≤1500 字符,按「封面规范」构造;可选,重生时为空则按 topic/metaphor 重拼>",
      "ratio": "16:9",
      "filename": "{stem}-cover.png",
      "anchor": "<封面内嵌行插入位置描述;可选(v3.8),默认约定值"第一个一级标题之后",缺失/默认 → 第一个 `# ` 一级标题后;其他描述 → 按该 anchor 定位插入>",
      "status": "planned|generated|failed"
    }
  },
  "pictures": [
    {
      "id": 1,
      "engine": "mermaid",
      "topic": "...",
      "content": "...",
      "anchor": "<简短段落描述,用于定位>",
      "source_file": "<.mmd/.excalidraw 裸文件名,相对 {stem}_images/ 目录、无前缀(如 insight-5steps.mmd),仅 mermaid/excalidraw;若文件在 /tmp 则写绝对路径并注释说明>",
      "source_prompt": "<完整 prompt 文本,仅 gemini>",
      "status": "planned"
    }
  ]
}
```

**v3 变更(vs v2)**:
- `_meta` 新增 `source`(规范化绝对路径)/ `source_mtime` / `source_size`(陈旧检测用)
- 每张 picture 恢复 `"status": "planned|generated|failed"`,执行后即时更新
- 生成图片时 `source_file` 写**相对 `{stem}_images/` 目录的裸文件名、无前缀**(如 `insight-5steps.mmd`),解析时以 `{stem}_images/` 为基准(Step 0 已 cd 到文章目录);**文件在 /tmp(如 gemini 的 prompt 文件)时写绝对路径并注释说明**
- 写盘后强制校验(两级):先 `jq -e .` 基础 JSON 校验;若 `~/.claude/skills/si-regen/scripts/validate-manifest.sh` 存在(另一 agent 并行产出)则追加调用。校验失败 → 按校验输出修正后重写 manifest,重写后复验;仍失败 → 报错 exit 1。脚本不存在 → 仅 jq 兜底:

**v3.3 变更(vs v3.2)**:
- **目录结构**:全部机器产物(manifest / 副本 / PNG / .mmd/.excalidraw 源文件)收敛到文章目录 `{stem}_images/` 子目录;原文 `{stem}.md` 留在文章目录顶层,是唯一留在外面的文件
- **source_file 语义**:由"相对文章目录、带 images/ 前缀"改为"相对 `{stem}_images/`、无前缀裸文件名"
- **重生语义**:mermaid/excalidraw 重生 = 从 manifest 的 `content`(+`topic`/`anchor`)重新生成源文件(风格轮换)→ 渲染 → 覆盖 PNG;不再只重渲染旧源文件,也不再报"源文件缺失"(见「风格轮换规范」)

**v3.4 变更(vs v3.3)**:
- `_meta` 新增**可选** `cover` 对象(topic/metaphor/prompt/ratio/status;缺失 = 封面未生成,旧 manifest 兼容,不强制升级)
- **封面默认生成**:完整流程每篇 1 张 `{stem}_images/{stem}-cover.png`(`--no-cover` 关闭);封面**不进入 `pictures`**(不插入正文、不参与 -content 匹配、不参与副本 base64 刷新)
- **封面声明**:副本 YAML frontmatter 加 `cover: {stem}-cover.png`(写副本,原文永不动);作者字段名未定,本命令自定义为 `cover`
- 封面走 minimax(gemini 分支契约);比例 `--cover-ratio` 默认 16:9

**v3.5 变更(vs v3.4)**:
- `_meta.cover` 新增**可选** `filename`(`{stem}-cover.png`,封面文件名,相对 `{stem}_images/` 裸文件名;可选字段,缺失回退约定式,旧 manifest 零迁移)
- **封面声明改从 manifest 读取**:副本 frontmatter `cover` 值取 manifest `_meta.cover.filename`(缺失回退约定式 `{stem}-cover.png`),不再硬编码

**v3.8 变更(vs v3.7)**:
- `_meta.cover` 新增**可选** `anchor`(封面内嵌行插入位置描述;可选字段,缺失/默认"第一个一级标题之后" → 第一个 `# ` 标题后插入;其他描述 → 按正文图 anchor 定位逻辑插入;旧 manifest 零迁移)
- **封面内嵌行改用缩略图**:封面生成/转码成功后额外生成 `{stem}-cover-thumb.png`(ffmpeg 640px 宽,`-compression_level 9`,实测 ~158KB ≤200KB),内嵌行 base64 用缩略图(~211K 字符,消除超长行显示问题);原图 `{stem}-cover.png` 保留(发布平台用);缩略图命名固定约定式、不进 manifest;生成失败回退原图

```bash
jq -e . "{stem}_images/{stem}.si-plan.json" >/dev/null || {
  echo "[ERROR] manifest 写入后校验失败,请重新生成"; exit 1; }
VALIDATOR="$HOME/.claude/skills/si-regen/scripts/validate-manifest.sh"
if [[ -f "$VALIDATOR" ]] && ! bash "$VALIDATOR" "{stem}_images/{stem}.si-plan.json"; then
  echo "[ERROR] validate-manifest.sh 校验失败,请按校验输出修正重写后复验"
  exit 1
fi
```

> **写盘后即视为锚定**:此后任何步骤(含 `--regen`/`--force`/`-content` 早退与「复用」分支)禁止修改 `pictures` 结构与 `_meta` 字段;唯一允许写入 = `status`(仅经命令脚本的 jq 命令更新,不经大模型判断);**封面字段例外**:`_meta.cover` 由封面流程专用(完整流程写 topic/metaphor/prompt/ratio/status 及可选 filename/anchor;`--regen cover` 可更新 prompt 与 status(补写时一并写 filename/anchor);`--force` 仅更新 status,见全局约束 10)。

#### Step 4:生成图片

skip-existing 逻辑(「重新分析」与「复用」共用;路径 4 内 flag 恒为空):

```
Bash mkdir -p {stem}_images   # 第一步:建机器产物收纳目录

默认(无 flag):
  若 {stem}_images/{stem}-image-{NN}.png 已存在 → 跳过(⏭)
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
mv /tmp/si-out-{NN}/minimax-0.jpeg "{stem}_images/{stem}-image-{NN}.png"
```

- **绝对不能用 `--prompt-file` / `--output` 这两个不存在的 flag**(真实契约:位置参数 prompt + `--out <目录>` + 产物 `minimax-{i}.jpeg`)
- key 检查:`MINIMAX_IMAGE_API_KEY` 或 `MINIMAX_API_KEY` **任一存在**即可(脚本首选前者,回落后者)
- 宽高比:脚本 `--ratio` 支持 16:9,固定传 `--ratio 16:9`(作者正文配图契约)

**格式统一规范(minimax 分支统一执行;路径 1/2/4a 三处共用本规范,勿各自另写)**:

> 实测(2026-08-01):minimax 产物 `minimax-0.jpeg` 是 **JPEG 编码(1280×720)**——`mv` 只换了扩展名,内容仍是 JPEG,严格按扩展名解析的工具会解码失败。mv 后必须执行:

```bash
# 1. file 检测产物编码:已是真 PNG("PNG image data")→ 跳过;JPEG(或其他非 PNG)→ 转码
PNG="{stem}_images/{stem}-image-{NN}.png"
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
Write {stem}_images/{chart}.mmd
<mmd 内容,按「风格轮换规范」从 content 生成:语义锚定 content,风格参数随机轮换(theme / 主色系 / direction)>
Bash npx -y bun ~/.claude/skills/smart-illustrator/scripts/mermaid-export.ts \
  -i {stem}_images/{chart}.mmd \
  -o {stem}_images/{stem}-image-{NN}.png \
  -w 2400
```
- `.mmd` 源文件保留在文章目录 {stem}_images/ 子目录(命名 `{chart}.mmd` 现状不变)

**4c. excalidraw(复用作者脚本)**:
```
Read ~/.claude/skills/smart-illustrator/references/excalidraw-guide.md
Write {stem}_images/{chart}.excalidraw
<按 guide 规范写 Excalidraw JSON 数组;按「风格轮换规范」随机轮换背景色/描边填充色/布局微调>
Bash npx -y bun ~/.claude/skills/smart-illustrator/scripts/excalidraw-export.ts \
  -i {stem}_images/{chart}.excalidraw \
  -o {stem}_images/{stem}-image-{NN}.png \
  -s 2
```
- `.excalidraw` 源文件保留在 {stem}_images/ 子目录
- 必读 excalidraw-guide.md(`boundElements: null`、`updated: 1`、不加 `frameId`)
- 依赖 Playwright + Firefox(若未装,报错)

**4d. 封面(v3.4,正文图之后执行;`--no-cover` 时整块跳过)**:

skip-existing:封面 `{stem}_images/{stem}-cover.png` 已存在 → 跳过(⏭;但缩略图 `{stem}-cover-thumb.png` 缺失时从已有封面补生成缩略图,见执行体 4.5,v3.8);不存在 → 生成。主题来源:

- **重新分析分支**:manifest 由本流程新写,`_meta.cover` 含 Step 2 提炼的 topic/metaphor + 按「封面规范」构造的 prompt + `filename`(`{stem}-cover.png`) + `anchor`("第一个一级标题之后",Step 3 写入)→ 直接用
- **「复用」分支**(manifest 存在但无 `_meta.cover`,即 v3.3 及更早的旧规划):**不读原文、不重规划** → 跳过封面,报告"封面未规划(manifest 无 _meta.cover),跳过;请跑完整流程重新分析或 --regen cover"
- **「复用」分支**(manifest 有 `_meta.cover`):用存的 prompt/ratio,skip-existing 同前;**旧 manifest 缺失 `filename`/`anchor` 时按约定式回退**(filename 回退 `{stem}-cover.png`,anchor 回退"第一个一级标题之后";写回/声明/插入均用回退值)

执行体(与 1c 第 3-8 步相同):

```bash
# 1. prompt 三态(与 1c 第 2 步同逻辑):_meta.cover.prompt 非空 → 读出写入文件;
#    空但 topic/metaphor 存在 → 按「封面规范」重拼并回写 _meta.cover.prompt;
#    整体缺失 → 不读原文,跳过封面(复用分支旧规划,见上文主题来源)
jq -r '._meta.cover.prompt' "$MANIFEST" > /tmp/si-cover-prompt.txt
if [[ ! -s /tmp/si-cover-prompt.txt ]]; then
  echo "[ERROR] 封面 prompt 为空(manifest _meta.cover.prompt 缺失),跳过封面;请跑完整流程重新分析或 --regen cover"
  jq --arg s "failed" '._meta.cover.status = $s' "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"
  SKIP_COVER=1
fi
wc -c /tmp/si-cover-prompt.txt   # 校验 ≤1500,超限按「封面规范」压缩策略截断重拼

# 2. 比例显式初始化:COVER_RATIO="16:9";[[ -n "$COVER_RATIO_ARG" ]] && COVER_RATIO="$COVER_RATIO_ARG";
#    --cover-ratio 指定其他值时先 -h 实测,不支持 → 警告回退 16:9
# 3. key/脚本检查(同 4a)→ 调用(SKIP_COVER=1 时跳过)
python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-cover-prompt.txt)" \
  --out /tmp/si-out-cover --ratio "${COVER_RATIO}" \
  && mv /tmp/si-out-cover/minimax-0.jpeg "{stem}_images/{stem}-cover.png"
# 4. 格式统一规范(4a 末尾:file 检测,JPEG 则 ffmpeg 转码为真 PNG)
# 4.5 缩略图生成(v3.8,4 成功后才执行;封面跳过生成但缩略图缺失时同样补生成):本地 ffmpeg,无 API 成本
#     ffmpeg -y -loglevel error -i "{stem}_images/{stem}-cover.png" -vf "scale=640:-1" -compression_level 9 "{stem}_images/{stem}-cover-thumb.png"
#     (640px 宽,实测 ~158KB ≤200KB;生成失败/ffmpeg 不可用 → 回退原图 base64 内嵌,不阻塞,报告中注明"缩略图生成失败,内嵌用原图")
# 5. 更新 status(写回时一并补齐 filename/anchor;旧 manifest 缺失 → 按约定式回退值/默认值写入)
jq --arg s "generated" --arg f "${STEM}-cover.png" --arg a "第一个一级标题之后" \
  '._meta.cover.status = $s | ._meta.cover.filename = (._meta.cover.filename // $f) | ._meta.cover.anchor = (._meta.cover.anchor // $a)' "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"
# 6. 成功后 Step 5 写副本时一并做 frontmatter 声明(见 3.5)
```

失败 → status=failed,报告失败,不阻塞正文图片与副本。

#### Step 5:写副本(Claude 心跳引导)

1. **副本已存在 → 先显示 diff 摘要,再询问是否覆盖**(与失败处理表统一):

```bash
if [[ -f "{stem}_images/{stem}-image.md" ]]; then
  diff <(grep -v '^!' "$ARTICLE") <(grep -v '^!' "{stem}_images/{stem}-image.md") | head -20   # diff 摘要
  # 询问:"副本已存在,是否覆盖?回复「覆盖」或「跳过」"
fi
```

2. 确认覆盖(或副本不存在)→ `Bash mkdir -p {stem}_images && cp <file.md> {stem}_images/{stem}-image.md`(先建目录、复制原文为副本)

3. `Read {stem}_images/{stem}-image.md`,在心跳记的"图 N 该放第 X 段"位置插图。**插图操作用 python3 脚本执行(禁用 Edit)** —— base64 行可达 ~950KB,Edit 工具无法承载。脚本按 anchor 定位段末空行前,读取 PNG 生成 base64,拼成单行插入,写临时文件再原子替换:

```bash
python3 - "{stem}_images/{stem}-image.md" "{stem}_images/{stem}-image-{NN}.png" "<段末定位标记:该段最后一行内容的唯一子串>" << 'PYEOF'
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

3.5 **封面 frontmatter 声明(v3.4;`--no-cover` 或封面未生成(含跳过/失败)时跳过本步)**:封面**不插入正文**,以副本 YAML frontmatter 声明,字段 `cover: {COVER_FILE}` —— **值取自 manifest `_meta.cover.filename`(缺失回退约定式 `{stem}-cover.png`;相对 `{stem}_images/` 目录裸文件名,副本同目录;作者字段名未定,本命令自定义为 `cover`)**,不再硬编码拼名。声明前先解析:

```bash
COVER_FILE=$(jq -r '._meta.cover.filename // ""' "$MANIFEST")
[[ -n "$COVER_FILE" ]] || COVER_FILE="${STEM}-cover.png"   # 旧 manifest 缺失 filename → 约定式回退
```

python3 脚本处理三种情形(已有 cover 字段 → 替换值;有 frontmatter 无 cover → frontmatter 块内追加;副本无 frontmatter → 头部插入 `---` 块);**三情形统一保证 frontmatter 闭合 `---` 后为一行空行(v3.8 根因修复:闭合后无空行会被 MarkText/VSCode 等 frontmatter 正则惰性吞并后续行直至文中下一个 `---`,封面内嵌行不可见)**:

```bash
python3 - "{stem}_images/{stem}-image.md" "$COVER_FILE" << 'PYEOF'
import os, re, sys
copy_path, cover_val = sys.argv[1], sys.argv[2]
lines = open(copy_path, encoding="utf-8").read().split("\n")
if lines and lines[0] == "---":
    end = next((i for i in range(1, len(lines)) if lines[i] == "---"), None)
    if end is not None:
        fm = lines[1:end]
        idx = next((i for i, l in enumerate(fm) if re.match(r"^cover\s*:", l)), None)
        if idx is not None:
            fm[idx] = f"cover: {cover_val}"
        else:
            fm.append(f"cover: {cover_val}")
        lines[1:end] = fm
        end = 1 + len(fm)   # v3.8:情形 2(追加)后 frontmatter 行数 +1,闭合行索引偏移,重定位后再检查
        if end + 1 < len(lines) and lines[end + 1].strip():
            lines.insert(end + 1, "")   # v3.8:闭合 `---` 后必须空行,否则 frontmatter 吞并后续行(封面不可见根因)
    else:
        lines[1:1] = [f"cover: {cover_val}"]          # frontmatter 未闭合(异常)→ 紧跟首行插入
else:
    lines = ["---", f"cover: {cover_val}", "---", ""] + lines   # 无 frontmatter → 头部新建(闭合后补空行,v3.8)
open(copy_path + ".tmp", "w", encoding="utf-8").write("\n".join(lines))
os.replace(copy_path + ".tmp", copy_path)
print(f"frontmatter cover 声明: {cover_val}")
PYEOF
```

**封面内嵌行插入/刷新(v3.8;与 frontmatter 声明同条件,`--no-cover` 或封面未生成(含跳过/失败)时跳过)**:声明后执行;执行前**结构修复前置(v3.8)**:Read 副本检查 frontmatter 结构 —— 副本有 frontmatter(首行 `---`)且闭合 `---` 后一行**非空行** → 先补插一个空行(仅此一处结构修复,不动其他内容;覆盖存量 v3.7 副本刷新型场景,闭合后无空行会被 MarkText/VSCode frontmatter 正则惰性吞并后续行,封面不可见);副本无 frontmatter → 无需处理(3.5 新建的 `---` 块已带空行)。随后 —— 插入/刷新 base64 内嵌行 `![cover](data:image/png;base64,{base64})`(base64 由 `base64 -w0 "{stem}_images/{stem}-cover-thumb.png"` 生成,封面**缩略图**;缩略图缺失/生成失败 → 回退原图 `base64 -w0 "{stem}_images/{COVER_FILE}"`,报告中注明;独占一行,前后各留一个空行);**有 `![cover](data:image/png;base64,` 前缀行 → 整行替换**(封面重生后内容变了,必须刷新,非仅保持;行位置不变,无需 anchor 定位);无 → **按 manifest `_meta.cover.anchor` 定位插入**:缺失或等于默认值"第一个一级标题之后" → 在副本**第一个 `# ` 一级标题行之后**插入;其他描述 → 按正文图 anchor 定位逻辑(Read 副本定位该段落,段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;规范见 3.6。

3.6 **封面内嵌行(正文可见,v3.7;缩略图内嵌 + anchor 定位,v3.8)**:封面在副本中**双重表示** —— frontmatter `cover:` 声明(程序消费)+ 正文内嵌行(编辑器消费),本小节为内嵌行规范:
- **插入位置(默认)**:副本第一个 `# ` 一级标题行之后、正文之前;独占一行,前后各留一个空行(与插图规范一致)
- **插入位置(anchor 定制,v3.8)**:插入时读 manifest `_meta.cover.anchor` —— 缺失或等于默认值"第一个一级标题之后" → 按默认位置;其他描述 → 按正文图 anchor 定位逻辑(Read 副本定位 anchor 对应段落,段末空行前插入);定位失败 → 回退第一个 `# ` 标题后,报告注明"封面 anchor 定位失败,已回退第一个一级标题后"
- **格式**:`![cover](data:image/png;base64,{base64})` —— alt 文本固定 **`cover`**(区别于正文图的空 alt);base64 由 `base64 -w0 "{stem}_images/{stem}-cover-thumb.png"` 生成(**封面缩略图**,v3.8,640px 宽 ≤200KB,base64 ≤~211K 字符;缩略图缺失/生成失败 → 回退原图 `base64 -w0 "{stem}_images/{COVER_FILE}"`,报告中注明);与正文图同方式,任何 markdown 编辑器 **100% 可见**,消除文件名空格/中文的路径解析问题与超长行显示问题
- **插入/刷新语义**:已有 `![cover](data:image/png;base64,` 前缀行 → **整行替换**为新 base64(封面重生后内容变了,必须刷新,不能只保持;行位置不变,无需 anchor 定位);无 → 按 anchor 逻辑插入
- **diff 兼容**:封面行以 `!` 开头 → 被现有 `grep -v -e '^!' -e '^cover: '` 过滤规则覆盖,零新增
- **刷新跳过**:「副本引用刷新」以 `^!\[cover\]\(` 前缀识别并跳过封面行,正文图按序计数不受影响;封面行仅在封面流程(1c/路径 2/完整流程 4d)时更新

4. **插图后 diff 校验**(硬规则):`diff <(grep -v -e '^!' -e '^cover: ' "$ARTICLE") <(grep -v -e '^!' -e '^cover: ' "{stem}_images/{stem}-image.md")`。**副本唯一允许差异 = 图片行(base64)+ 空行 + frontmatter 的 cover 声明行**:base64 图片行以 `!` 开头、cover 声明行以 `cover:` 开头,`grep -v` 过滤规则继续有效;过滤后 diff 输出中除空行外不得出现任何非空行差异;原文无 frontmatter 而副本首次加声明时,头部新增的 `---` 头尾两行会出现于 diff —— 属允许差异,人工核对;发现原文行被改动(如引号被换)→ 视为 bug,重新从 Step 5.2 开始。

#### Step 6:报告

```text
[smart-illustrator-minimax 完成]
────────────────────────────────────────────────────────────────────────────
编号 │ 引擎       │ 源文件                              │ status     │ 动作 │ PNG 路径
─────┼────────────┼────────────────────────────────────┼────────────┼──────┼────────────────────
01   │ mermaid    │ test-chart-aop.mmd                  │ generated  │ 🆕  │ test_images/test-image-01.png
02   │ excalidraw │ test-chart-comparison.excalidraw    │ generated  │ 🆕  │ test_images/test-image-02.png
03   │ gemini     │ /tmp/si-prompt-03.txt               │ failed     │ ✖   │ test_images/test-image-03.png
04   │ mermaid    │ test-chart-routing.mmd              │ generated  │ ⏭   │ test_images/test-image-04.png

动作图例: 🆕 生成(新图) │ 🔄 重生(--regen/--force 覆盖) │ ⏭ 跳过(已有文件) │ ⏭ 跳过(不在重生集合,仅 --regen) │ ✖ 失败

封面行示例(表下方,不在编号表内):

```text
封面  │ gemini     │ /tmp/si-cover-prompt.txt            │ generated  │ 🆕  │ {stem}_images/{stem}-cover.png
```

✅ 副本:{stem}_images/{stem}-image.md(图片已 base64 内嵌,自包含 —— 拷贝到任何位置打开都显示图片;不引用外部 PNG;frontmatter 含 cover 声明 + 正文首个标题后封面缩略图 base64 内嵌行 —— 双重表示,打开即见封面图)
✅ 图片:{stem}_images/{stem}-image-01.png ...(重生资产,PNG 保留在文章目录 {stem}_images/ 子目录,副本不再引用)
✅ 封面:{stem}_images/{stem}-cover.png(v3.4;--no-cover 时无此产物;封面不插入正文插图,经副本 frontmatter `cover:` 声明 + 正文首个标题后 `![cover](data:image/png;base64,...)` 内嵌行双重表示;v3.8 起内嵌行为缩略图 {stem}_images/{stem}-cover-thumb.png 的 base64(640px 宽 ≤200KB),原图保留供发布平台)
✅ 源文件:{stem}_images/*.mmd / *.excalidraw(保留可编辑)
✅ manifest:{stem}_images/{stem}.si-plan.json(文章目录 {stem}_images/,v3;含可选 _meta.cover)
```

报告表格规范:编号**两位零填充**(01 不是 001);`source_file` 列 = 该图的 .mmd/.excalidraw 源文件裸文件名(**相对 `{stem}_images/` 目录、无前缀**)或 gemini 的 prompt 文件路径(prompt 在 /tmp,**写绝对路径**并注释说明);PNG 路径列写 `{stem}_images/{stem}-image-NN.png`(文章目录 {stem}_images/ 子目录相对路径);status 列如实反映 planned/generated/failed。

## 封面规范(Axton Cover Identity → minimax prompt,路径 1c/2/4 通用,v3.4)

> 封面 = 文章的门面,对齐作者 `styles/style-cover.md` 的 **Axton Cover Identity**。封面走 minimax(gemini 分支契约),API 天然随机,**不适用风格轮换规范**。

### 视觉规范(直接进 prompt,要点化)

- **色彩签名(双色光线系统)**:背景 studio black **#0A0A0A**(永远纯黑虚空);主光琥珀金 **#F59E0B** 侧面打亮主体 **~70%**;辅光天空蓝 **#38BDF8** rim light/阴影填充/边缘反射 **~30%**;颜色通过"光与折射"体现,不得当表面涂色;除金蓝外不引入其他强色相;禁霓虹、渐变、复杂纹理;主体与背景明度差 ≥50%
- **构图**:单一焦点;主体占画面 **30-50%**,其余纯黑留白;核心内容保持在**中央 71% 高度安全区**(16:9 裁 5:2 时上下各约裁 14.4%)
- **材质**(首选):半透明玻璃、磨砂亚克力、发光线框、冰晶、抛光暗金属;允许棋子/钥匙等日常物作隐喻载体但须去环境;禁止木纹/皮革/机械件等现实材质
- **文字**:绝对 **ZERO TEXT** —— 无任何可读字符含伪文字;无水印/logo/品牌文字(隐喻本身即标题,"The image IS the headline")
- **主体大小控制技巧**(通用):先环境后主体("A vast void. In the center, a tiny...")、"Extreme wide shot"、感性比例("a lone speck" 优于 "30%")、球体类加 "not a planet" 排除词
- **异常状态用肯定语言**描述正在发生的事件("cracked and partially shattered" 而非 "one side is missing");中文推导、英文生成

### prompt 模板与压缩(≤1500 字符硬上限)

拼接顺序(超限时按此顺序截断,**色板/光比/零文字/比例/材质必须完整保留**):

1. **主体场景**:单段落英文描述(<100 词):物体 + 材质 + 异常状态 + 虚空空间 + 光照 —— 直接来自 manifest 的 `topic`/`metaphor`
2. **渲染尾缀**(固定):`Minimalist abstract composition, infinite dark void. Aspect ratio {ratio}, landscape. Lighting: amber gold key light from left, sky blue rim light on edges, studio black background. Zero text, single focal point, dramatic cinematic lighting, 8k resolution, photorealistic rendering.`
3. 写入 `/tmp/si-cover-prompt.txt` 后 `wc -c` 校验 ≤1500;超限先截场景描述尾部,再截尾缀尾部(保留前段)

### 比例

- 默认 `16:9`(minimax 实测支持);`--cover-ratio <X:Y>` 指定其他比例(如 3:4 小红书)时,先 `python3 ~/图片/minimax_t2i.py -h` 实测支持列表,不支持 → 警告"脚本不支持比例 ${X},已回退 16:9"
- 作者平台预设(供参考,非 16:9 需确认 minimax 支持后使用):youtube 16:9 / wechat 2.35:1 / twitter 1.91:1 / xhs 3:4(作者脚本比例白名单本身不含 2.35:1 与 1.91:1,取近似)

### 缩略图(内嵌用,v3.8)

- **封面内嵌行 base64 一律用缩略图**,原图 `{stem}-cover.png` 保留在 {stem}_images/(发布平台用),**不删除、不进副本**;缩略图命名固定约定式 `{stem}_images/{stem}-cover-thumb.png`,**不进 manifest 字段**(manifest 只记原图文件名 `filename`)
- **生成时机**:封面 PNG 生成/转码成功后(路径 1c/2/4d 封面执行体统一执行;封面已存在但缩略图缺失时同样补生成,本地 ffmpeg 无 API 成本);命令:`ffmpeg -y -loglevel error -i "{stem}_images/{stem}-cover.png" -vf "scale=640:-1" -compression_level 9 "{stem}_images/{stem}-cover-thumb.png"`(640px 宽,实测 ~158KB,≤200KB 目标;内嵌行 base64 ≤~211K 字符,消除超长行导致编辑器不显示的问题)
- **失败回退**:缩略图生成失败或 ffmpeg 不可用 → 用原图 base64 内嵌(不阻塞),报告中注明"缩略图生成失败,内嵌用原图"

### 封面与正文图的边界

- 封面**不进入** `pictures`、不参与 -content 匹配、不参与副本正文图刷新计数(封面行仅在封面流程更新);副本中**双重表示**(v3.7;v3.8 起内嵌行为缩略图 base64):frontmatter `cover:` 声明(程序消费)+ 正文首个标题后 `![cover](data:image/png;base64,...)` 内嵌行(编辑器消费,base64 为缩略图 `{stem}-cover-thumb.png`,规范见「Step 5 封面内嵌行」与下方「缩略图」)
- 封面内嵌行以 `!` 开头,被现有 `^!` 过滤规则覆盖,无需新增过滤项
- 封面主题与 `anchor`(默认"第一个一级标题之后")随完整流程(Step 2/3)写入 `_meta.cover`;`--regen cover` 缺失时读原文轻量提取(补写含 anchor);`--force` 缺失时跳过并提示
- 失败不阻塞正文:封面 status=failed,报告列出

## 风格轮换规范(mermaid/excalidraw 重生,路径 1/2/4 通用)

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
| 路径不存在 / 不可读 | 报错并提示正确路径格式 |
| 路径含空格未加引号 | 报错提示:传入参数已按空格切分,含空格路径必须整体加引号重试 |
| manifest 不存在 + 任一 flag | 报错"manifest 不存在({path}),请先跑一次不带 flag 的完整流程生成",exit 1 |
| manifest 损坏(JSON 解析失败) | 报错"manifest 损坏({path}),请删除后重跑完整流程" |
| manifest 为 v1/旧版 schema | 报错"旧版 manifest({path}),请重跑完整流程升级为 v3",不做 content 重建 |
| manifest 内部不一致(_meta.total ≠ pictures 长度) | 报错,exit 1 |
| 原文已修改(mtime/size 不符) | 路径 1/2/3:警告"原文已修改({date}),图片可能过时",用户回复"继续"才执行 |
| `--regen N` 非正整数 / 超出范围 | 报错"必须为正整数或 cover"(非数字)/ "picture ID out of range (1-$TOTAL)"(越界),**校验前置,任一非法零执行** exit 1 |
| `--regen N` 的图旧源文件(.mmd/.excalidraw)已删除/不存在 | 无碍 —— 重生按「风格轮换规范」从 content 重新生成源文件,不再报"源文件缺失" |
| `MINIMAX_IMAGE_API_KEY` / `MINIMAX_API_KEY` 均未设 | 立即报错,提示设置其一 |
| minimax 调用参数错误(如误用 --prompt-file/--output) | 立即 `python3 ~/图片/minimax_t2i.py -h` 实测契约修正后重试 |
| minimax prompt 超 1500 字符 | 按压缩策略截断重试 |
| minimax API 调用失败 | 该图跳过,status=failed,继续下一张,最后报告失败列表 |
| mermaid 脚本失败 / `mmdc` 未装 | 同上,提示安装 `npm i -g @mermaid-js/mermaid-cli` |
| excalidraw 脚本失败 / Playwright 未装 | 同上,提示安装 |
| excalidraw JSON 不符规范 | 重新 `Read references/excalidraw-guide.md`,重写一次再导出;仍失败则跳过记录 |
| 副本已存在 | 显示 diff 摘要,询问用户是否覆盖(回复「覆盖」或「跳过」) |
| 副本 {stem}_images/{stem}-image.md 不存在(--regen/--force 刷新时) | 跳过引用刷新,报告"副本缺失,引用未刷新" |
| 副本中找不到图片引用/图片行不足(--regen/--force) | 读 manifest 该 picture 的 anchor 定位段落,段末空行前插入 base64 行(脚本,同 Step 5.3);段落也定位失败 → 报告"引用未找到,未插入",继续 |
| 副本图片引用格式不符(旧绝对路径/相对引用/URL 编码) | 整行替换为 base64 data URI 标准格式(脚本,非 Edit),行号记入报告 |
| `-content` 与 `--force` 同传 | 报错"-content and --force are mutually exclusive. Use one or the other." |
| `-content` 智能匹配并列 ≥ 2 | 报错列前 3 候选(id + topic + 命中维度 + 分值);不重生任何图;提示"编号 = 图片文件名后缀数字" |
| `-content` 智能匹配 0 分 | 报错列所有 picture 的 id + topic + anchor;提示"编号 = 图片文件名后缀数字" |
| 未知 engine 值(手改 manifest) | 报错"picture $N engine 非法",跳过该图,纳入失败列表 |
| `--regen cover` 但 `_meta.cover` 缺失 | 唯一例外读原文:轻量提炼核心概念+视觉隐喻,补写 `_meta.cover`(含 `filename`/`anchor`)后生成;`--force` 时反之:跳过并提示"封面未规划(manifest 无 _meta.cover),请跑完整流程或 --regen cover" |
| 封面 minimax 调用失败 | 封面 status=failed,报告失败,不阻塞正文图片与副本 |
| 缩略图生成失败(ffmpeg 不可用/命令失败) | 回退用原图 base64 内嵌,不阻塞,报告中注明"缩略图生成失败,内嵌用原图" |
| `--cover-ratio` 比例不被 minimax 支持 | 警告"脚本不支持比例 X,已回退 16:9",按 16:9 继续 |
| `--no-cover` 与 `--regen cover` 同传 | `--no-cover` 优先,忽略 `--regen cover`,warning 说明 |
| 副本不存在时封面声明(1c/路径 2) | 跳过声明与封面内嵌行,报告"副本缺失,封面声明未写入"(声明值 = 读 manifest `_meta.cover.filename`,缺失回退约定式 `{stem}-cover.png`) |
| 副本无 frontmatter(首次加封面声明) | 头部新建 `---` 块插入 cover 行;封面内嵌行插在第一个 `# ` 标题行后;diff 校验时头部 `---` 差异属允许范围,人工核对 |
| 副本缺封面内嵌行(1c/路径 2/路径 4) | 插入/刷新:已有 `![cover](data:image/png;base64,` 前缀行 → 整行替换为新 base64(`base64 -w0` 读取缩略图 `{stem}-cover-thumb.png`,缺失/生成失败 → 回退原图 `{COVER_FILE}`);无 → 读 manifest `_meta.cover.anchor`:缺失/默认"第一个一级标题之后" → 第一个 `# ` 一级标题行后插入;其他描述 → 正文图 anchor 定位逻辑(段末空行前插入),定位失败 → 回退第一个 `# ` 标题后并报告注明;格式 `![cover](data:image/png;base64,{base64})`(独占一行,前后各留空行) |

## 输出文件清单

```
{stem}.md                             # 原文(文章目录顶层,唯一留在外面的文件)
{stem}_images/                        # 该文章全部机器产物
├── {stem}-image.md                   # 副本(图片 base64 data URI 内嵌,单文件自包含;原文不动;frontmatter 含 cover 声明 + 正文首个标题后封面缩略图 base64 内嵌行,双重表示)
├── {stem}-cover.png                  # 封面原图(v3.4,默认每篇 1 张;--no-cover 关闭;发布平台用,不进副本;frontmatter 声明指向此文件)
├── {stem}-cover-thumb.png            # 封面缩略图(v3.8,640px 宽 ≤200KB;副本封面内嵌行 base64 用;命名固定约定式,不进 manifest)
├── {stem}.si-plan.json               # manifest(v3,控制平面,从此处定位;含可选 _meta.cover)
├── {stem}-image-01.png               # PNG(作者风格命名)
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
- ✅ 只写:`{stem}_images/{stem}-image.md`、`{stem}_images/{stem}-image-NN.png`、`{stem}_images/{stem}-cover.png`、`{stem}_images/{stem}-cover-thumb.png`(v3.8 封面缩略图)、`{stem}_images/{chart}.mmd/.excalidraw`、`{stem}_images/{stem}.si-plan.json`(全部机器产物收敛在文章目录 `{stem}_images/` 内;原文 `{stem}.md` 留在文章目录顶层)

## 与原版的关系

- 100% 复用作者 `mermaid-export.ts` / `excalidraw-export.ts`(零改)
- 100% 复用作者的引擎优先级规则
- PNG 命名与作者一致:`{stem}-image-NN.png`(差异:收纳进文章目录 `{stem}_images/` 子目录 —— v3.3 起全部机器产物都进 `{stem}_images/`,v3.2 及以前在 `images/`;原版在文章顶层;副本图片用 base64 data URI 内嵌实现自包含,拷到任何地方都显示;重生后按图片行序号整行刷新 base64)
- **封面功能(v3.4)**:对齐作者默认行为(article 模式默认每篇 1 张封面,`--no-cover` 关闭;命名 `{文章名}-cover.png`;封面不插入正文,经副本 frontmatter 声明;Axton Cover Identity 视觉规范)。差异:① 封面收纳进 `{stem}_images/` 子目录;② frontmatter 字段名作者未定,本命令自定义 `cover`;③ 引擎为 minimax(gemini 分支契约,1280×720,作者 Gemini 2K 低一档);④ cover-learner 学习闭环(Gemini 专属)不迁移;⑤(v3.8)副本封面内嵌行用缩略图 `{stem}-cover-thumb.png`(640px,~211K 字符),原图保留供发布平台
- 唯一差异:Gemini API → minimax API(因为没订阅 Gemini;调用契约按实测记录)
- 路径 1/2/3 早退分支复用 `skip-existing` 逻辑,跳过 Read 全文/cp 副本,但每张覆盖成功后执行「副本引用刷新」(只动副本图片行,不重新分析)
- manifest v3:位置迁至文章目录 `{stem}_images/`、恢复 status、新增 source_mtime/source_size 陈旧检测;v3.3:source_file 相对 `{stem}_images/` 无前缀,mermaid/excalidraw 重生 = 从 content 重新生成源文件 + 风格轮换
