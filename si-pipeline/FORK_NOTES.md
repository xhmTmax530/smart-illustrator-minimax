# Fork Notes: smart-illustrator-minimax

个人 fork 备注，与上游 `axtonliu/smart-illustrator` 做差异说明。

---

## Section 1: Fork vs Upstream 对比表

| 维度 | 上游 | 本 fork |
|---|---|---|
| 创意图生成 | Gemini API (需订阅) | minimax_t2i.py (本地) |
| mermaid 导出 | `scripts/mermaid-export.ts` | ✅ 完全复用，零改 |
| excalidraw 导出 | `scripts/excalidraw-export.ts` | ✅ 完全复用，零改 |
| 文章插图位置 | Claude 心跳记忆，无外部状态机 | ✅ 沿用同一机制 |
| PNG 命名 | `{stem}-image-NN.png` | `images/{stem}-image-{NN}.png`（文章目录 **images/ 子目录**，NN 两位零填充从 01；v3.2 起，见 Section 12） |
| 副本插图 | 相对路径 `![]({stem}-image-NN.png)` | **base64 data URI 内嵌单行** `![](data:image/png;base64,<...>)`——自包含，复制到任何地方打开都显示图片（v3.2 起） |
| 状态机 | 作者用心跳 = 状态机 | ✅ 沿用 (manifest 保留为早退分支控制平面，v3 起迁至文章目录，见 Section 10；schema 有独立样本与校验脚本，见 Section 12) |
| 单图重生 | `--regenerate <ids>` (slides 模式，作者 `batch-generate.ts` 行 341) | ✅ 文章模式新增 `--regen N` (等价 skip-existing 逻辑) |
| 强制重来 | `--force` (slides 模式) | ✅ 文章模式新增 `--force` |
| 配置文件 | `config.json` (项目/用户两级) | ✅ 完全沿用 |

---

## Section 2: `--regen N` / `--force` 设计决策

- 触发: `--regen N` (只重生第 N 张，N≥1，可多次指定) / `--force` (全部重来)
- 互斥: `--regen` 与 `--force` 同时传，`--force` 优先
- skip-existing 逻辑 (等价 `batch-generate.ts` 行 341):
  ```
  if file_exists and not force and id not in regen_ids:
      skip
  ```
- **关键洞察(v3.2 起)**: 副本插图是 **base64 data URI 内嵌单行**（自包含，拷贝到任何地方都显示图），文件路径不变不再自动生效 —— 重生覆盖 PNG 后**必须**执行「副本引用刷新」：按图片行序号定位（base64 行不含文件名，原 `grep image-NN.png` 失效；副本图片行按 manifest pictures id 升序对应），**整行替换**为新 base64 行（base64 行可达 ~950KB，一律用 python3 脚本定位→拼行→`os.replace` 原子替换，禁用 Edit 工具）；引用缺失按 anchor 定位插入；副本不存在则跳过并报告
- 默认行为: 已有 PNG → 跳过 (避免 API 重复扣费)
- 来源: 来自 commit `01b6809` 的 deepseek 偏差补丁设计参考 + 作者 `batch-generate.ts` 的 skip-existing 模式

---

## Section 3: minimax 替代 Gemini

- 原因: 用户没订阅 Gemini; minimax 是国内可用 API
- 唯一差异: `scripts/generate-image.ts` → `~/图片/minimax_t2i.py` (用户本地脚本)
- 调用方式(实测契约 2026-08-01,`python3 ~/图片/minimax_t2i.py -h`):
  ```
  python3 ~/图片/minimax_t2i.py "$(cat /tmp/si-prompt-NN.txt)" --out /tmp/si-out-NN --ratio 16:9
  mv /tmp/si-out-NN/minimax-0.jpeg {stem}-image-NN.png
  ```
  - prompt 是**位置参数**(≤1500 字符);`--out` 是**输出目录**;产物固定 `minimax-{i}.jpeg`
  - **不存在 `--prompt-file` / `--output` flag**
  - `--ratio` 支持 16:9,固定传 16:9
- 环境变量: `MINIMAX_IMAGE_API_KEY` 首选,回落 `MINIMAX_API_KEY`(检查时任一存在即可)
- 限制: minimax 配额有限，可能触发 `QuotaExceeded` → 该图跳过，继续下一张

---

## Section 4: 非侵入承诺

```
❌ 不改 ~/.claude/skills/smart-illustrator/SKILL.md
❌ 不改 scripts/*.ts
❌ 不改 styles/*.md
❌ 不改 references/*.md
❌ 不改 {stem}.md (原文)
✅ 只写: {stem}-image.md (副本)、{stem}-image-*.png、{chart}.mmd/.excalidraw、{stem}.si-plan.json (文章目录)
```

---

## Section 5: 安装说明

用户怎么用这个 fork:

1. clone fork 到 `~/.claude/skills/smart-illustrator` (替换原版)
   ```bash
   git clone https://github.com/xhmTmax530/smart-illustrator-minimax.git ~/.claude/skills/smart-illustrator
   ```
2. 安装 slash command (文件**在 repo 里**,仓库是事实源):
   ```bash
   cp si-pipeline/commands/smart-illustrator-minimax.md ~/.claude/commands/
   ```
3. 安装 si-regen skill (仓库内是事实源,含 schema 样本与校验脚本):
   ```bash
   cp -r si-pipeline/skills/si-regen ~/.claude/skills/   # 全局 skill:SKILL.md + schema/ + scripts/validate-manifest.sh
   ```
4. 装依赖:
   ```bash
   npm i -g @mermaid-js/mermaid-cli
   cd ~/.claude/skills/smart-illustrator/scripts && npm install && npx playwright install firefox
   export MINIMAX_API_KEY=<你的 key>
   ```
6. 使用:
   ```bash
   /smart-illustrator-minimax "<article.md>" [extra hints]
   /smart-illustrator-minimax "<article.md>" --regen 3
   /smart-illustrator-minimax "<article.md>" --force
   ```

---

## Section 6: 版本与同步策略

- 上游版本: 跟随 axtonliu/smart-illustrator 的 `main` 分支
- 本 fork: 改造主线在 **`main`**(默认分支,推送目标);`feat/placeholder-pipeline` 为开发期分支(历史,已并入 main)
- 不主动 push PR 回上游 (非侵入增强，要保留作者的 `--engine` 设计空间)

---

## Section 7: -content 智能匹配（v2 增强）

文章配图模式新增 `-content "..."` 自然语言定位 flag,与 `--regen N` / `--force` 互补。

**使用场景**：

| flag | 用户记忆成本 | 精确度 |
|---|---|---|
| `--regen N` | 需查 manifest 记 id | 最精确 |
| `-content "..."` | 自然语言 | 子串匹配,有歧义可能 |
| `--force` | 零 | 全量 |

**匹配规则**（按 picture 数组逐张打分）：

| 维度 | 加分 | 例子 |
|---|---|---|
| 关键词命中(topic/anchor/content 子串,大小写不敏感) | +10 | "MVC 路由" → topic="MVC 路由流程" |
| 章节锚点命中(描述含「第 N 节」) | +5 | "第 4.2 节" → anchor="4.2 参数注解..." |
| 类型命中(描述含「流程图/时序图/对比图/架构图/概念图/隐喻图」) | +3 | "时序图" → type="sequence" |

**三种结果**：

- 最高分唯一 → 自动选中并重生
- 并列 ≥ 2 → 报错列前 3 候选(id + topic + anchor + 命中维度),要求用 `--regen <id>` 消歧
- 全 0 分 → 报错列所有 picture 的 id + topic + anchor 供改写描述

**互斥规则**：

- `-content` 与 `--force` 互斥(同时传报错)
- `-content` 与 `--regen N` 同传时 `--regen N` 优先(显式 id 更精确)

**已知限制**：

- 子串匹配,大小写不敏感但不分词("IoC" 不会拆成 "I" "o" "C")
- 同义词不匹配("架构图" vs "architecture",靠 type 命中+3 分勉强覆盖)
- 复杂描述可能并列(如 "架构" 同时命中多张架构图)
- 端到端未测(依赖 minimax API,配额暂停);逻辑已通过 fixture 模拟确认

**设计参考来源**:deepseek commit `01b6809` 的 `-content` 智能匹配设计(spec 第 78-84 行)。

## Section 8: 已知限制（接上）

- minimax 配额有限，大量文章配图可能需分批
- `--regen`/`--force` 在 minimax API 不可用时只能重生 mermaid/excalidraw (走作者脚本，无 API 依赖)
- 当前未做端到端测试 (minimax 配额暂停); 逻辑已通过 fixture 模拟确认 (skip-existing + PNG 覆盖)

---

## Section 9: 早退分支设计

### 设计动机

用户第二次调用 `/smart-illustrator-minimax <file.md> --regen N` 时，如果每次都重新走全文分析（Read → 心跳分析 → 位置决策），对于只想重生第 N 张图的场景是极大浪费：读全文消耗 token，心跳分析消耗 token，cp 副本写入也是 IO。

早退分支的核心价值：**以 manifest 为唯一控制平面，让第二次调用的用户跳过所有不必要的步骤，直接覆盖目标 PNG。**

### manifest 作为控制平面

`{stem}.si-plan.json`(文章目录,与 `{stem}-image.md` 平级;v3 起)在路径 4(首次全流程)中必写,路径 1/2/3 纯读 manifest 不写。**manifest 缺失 + 任一 flag → 报错退出**("请先跑一次不带 flag 的完整流程生成"),绝不静默回退路径 4(v3 修复,原"缺失即退回路径 4"表述已废弃)。

Step 0 的 manifest 检测是**最先执行的**，在任何分析之前。这确保了早退路径不会被误触发。

### 版本兼容策略(v3 起)

| 场景 | 处理 |
|------|------|
| 新代码读 v1/v2 manifest | **显式拒绝**:报错"旧版 manifest({path}),请重跑完整流程升级为 v3",exit 1;不做从 `content` 重建的死代码 |
| 旧代码读 v3 manifest | JSON.parse 忽略未知字段,完全兼容(仅理论场景,本 fork 唯一读者即命令自身) |
| v2 → v3 迁移 | 无原地迁移:路径 4 总是全量重写 manifest(新位置 + v3 schema + status + source_mtime/source_size) |

### 与原 deepseek commit `01b6809` 的偏差

commit `01b6809` 引入 manifest 概念，但本 fork 的早退分支**只重 manifest 字段，不重 manifest 概念**：

| 维度 | `01b6809` 设计 | 本 fork 设计 |
|------|---------------|------------|
| manifest 角色 | 外部状态机，控制心跳流程 | 只读快照，路径 1/2/3 的控制平面 |
| 心跳与 manifest 关系 | manifest 驱动心跳状态机 | 心跳 = 状态机（沿用），manifest = 快照 |
| 路径 1 行为 | 依赖完整的状态转移 | 只读 manifest，零不动副本 |
| `--force` 行为 | 重写 manifest + 重新分析 | 只覆盖 PNG（manifest 内容不变） |

本 fork 不引入新的状态机，manifest 是**快照而非状态转移器**，这是与 `01b6809` 的根本差异。

### 互斥规则（2026-07-30 修正）

| 组合 | 处理方式 |
|------|---------|
| `--regen` + `--force` | `--force` 优先，全部重来 |
| `-content` + `--force` | **硬互斥，报错退出**（2026-07-30 修复场景 9） |
| `-content` + `--regen N` | `--regen N` 优先（显式 id 更精确） |

**范围校验**：路径 1 的 `--regen N` 在 jq 抽取之前做严格范围检查，N 超范围时报错跳过，**不调用任何 jq**，确保 manifest 和 PNG 不被副作用修改（2026-07-30 修复场景 4）。v3 强化：**前置全量校验**——先校验全部 id(正整数、去重、范围内、`_meta.total == pictures.length`),任一非法即报错 exit 1,**零执行**;校验通过才逐个执行。

---

## Section 10: v3 重设计（2026-08-01）

### 背景:4 份审查报告发现的三大致命伤

2026-07-31 由 4 个审查 agent 对命令体（`~/.claude/commands/smart-illustrator-minimax.md`）做了逻辑 / manifest 设计 / 集成 / 场景体验四维审查（`/tmp/review-{logic,manifest,integration,ux}.md`），三大致命伤：

| # | 致命伤 | 后果 |
|---|--------|------|
| 1 | **minimax 调用契约与真实脚本不符**:命令写死 `--prompt-file` / `--output`,脚本实际是**位置参数 prompt**(≤1500 字符)+ `--out <目录>` + 产物固定 `minimax-{i}.jpeg`,支持 `--ratio` | 所有 gemini 分支 100% 失败,argparse 直接报错退出 |
| 2 | **manifest 放 /tmp**:tmpfs + systemd-tmpfiles 10 天清理双重失联,manifest 生命周期远短于文章 | 重启/清理后 `--regen`/`--force`/`-content` 全部失效 |
| 3 | **cwd 敏感**:早退路径按会话 cwd 解析相对路径,不在文章目录调用时 PNG/源文件落到错误位置(幽灵图) | 跨目录二次调用静默写错位置,报告谎报成功 |

### 用户三项决策

1. **manifest 放原文旁** `{stem}.si-plan.json`(文章目录,与 `{stem}-image.md` 平级)
2. **无 flag 重跑时询问**"复用规划还是重新分析"(回复「复用」或「重新分析」)
3. **PNG 命名改成作者风格** `{stem}-image-NN.png`(顶层,NN 两位零填充从 01;v2 的 `images/{stem}-img-NN.png` 废弃,产物已迁移)

### v3 schema 变更（`_meta.schema` = `si-minimax/v3`）

| 变更 | 内容 |
|------|------|
| 位置 | `/tmp/si-plan-{stem}.json` → 文章目录 `{stem}.si-plan.json`(旧位置命中时提示"已迁移,请重跑完整流程刷新") |
| `_meta.source` | 规范化绝对路径(realpath) |
| `_meta.source_mtime` / `source_size` | stat 文章记录,Step 0 陈旧检测(原文已修改 → 警告/提示) |
| picture.status | 恢复 `"planned\|generated\|failed"`,每张图执行后更新(报告表格加 status 列) |
| `source_file` | 相对文章目录路径(Step 0 强制 cd 后解析无歧义);文件在 /tmp(如 prompt)→ 写绝对路径并注释说明 |
| 版本兼容 | v1/v2 → 显式拒绝("请重跑完整流程升级为 v3"),删除 content 重建死代码 |

### v3 修复清单（对应审查发现）

| 审查发现 | v3 修复 |
|----------|---------|
| minimax 契约不符(S1-1×4 报告) | 实测 `-h` 记录契约:位置 prompt + `--out` 目录 + `mv minimax-0.jpeg`;禁 `--prompt-file`/`--output`;固定 `--ratio 16:9` |
| prompt >1500 字符(S1-2 integration) | 压缩策略:Read style 文件 → 提取核心要点(色板/构图/禁忌)→ 拼 topic + content → `wc -c` 校验,超限先截 content 再截 style,topic 与视觉核心必须保留 |
| key 检查(S3-3 integration) | `MINIMAX_IMAGE_API_KEY` 或 `MINIMAX_API_KEY` 任一存在即可 |
| cwd 敏感(S1-2 manifest / S2-2 integration) | Step 0 **强制 cd** `cd "$(dirname "$ARTICLE")"`,所有路径第一步;ARTICLE 先 realpath 规范化 |
| /tmp 失联(S1-1 manifest / S1-1 ux) | manifest 迁至文章目录 |
| 陈旧检测缺失(S1-3 manifest / S3-11 logic) | `_meta.source_mtime/source_size` + Step 0 对比;路径 1/2/3 警告"确认继续则手动回复继续",路径 4 提示按当前内容重新分析 |
| 坏 JSON 无定义行为(S1-4 manifest / S4-13 logic) | Step 3 写后 `jq -e .` 校验失败报错;Step 0 读前 `jq -e .` 校验,损坏报"manifest 损坏({path}),请删除后重跑完整流程" |
| planned≠generated(S1-5 manifest) | 恢复 status 字段 + 每图执行后更新 + 报告列 |
| regen 校验交错(S2-1 logic) | 前置全量校验(正整数/去重/范围/total 一致),任一非法 exit 1 **零执行** |
| pictures[N-1] 下标(S2-2 logic) | 按 id 查找:`jq -e --argjson id N '.pictures[] \| select(.id == $id)'` |
| manifest 缺失行为三处矛盾(S2-7 logic / S2-3 manifest) | 统一:缺失 + flag → 报错 exit 1;缺失 + 无 flag → 路径 4。删除"静默回退"表述 |
| v1 content 重建死代码(S3-1 logic) | 显式拒绝旧版,不做重建 |
| 副本覆盖矛盾(S3-4 logic) | Step 5 与失败表统一:副本已存在 → diff 摘要 → 询问覆盖 |
| 命名三处漂移(S3-9 logic / S3-1 integration) | 统一 `{stem}-image-NN.png` 顶层;删除"100% 沿用"错误声明改为如实描述;现有产物已迁移 |
| 无 flag 重跑漂移(S4-2 manifest / S1-3 ux) | 无 flag + manifest 存在 + 原文未变 → 摘要表 + 询问「复用」/「重新分析」;原文已变 → 直接重新分析(带提示) |
| 编号/源文件对应不可知(S2-2 ux) | 报告表格加 `source_file` 列(.mmd/.excalidraw 相对文章目录;gemini prompt 文件在 /tmp 写绝对路径并注释),编号两位(01) |
| 副本内容被微改(S2-5 ux) | 硬规则:禁改原文任何文字(含标点);插图后 diff 校验只允许新增图片行+空行 |
| 插图落在标题与 --- 之间(S2-6 ux) | 硬规则:只插目标段落末尾空行前,禁插标题与分隔线之间 |
| -content 报错可操作性(S2-7 ux) | 报错末尾提示"编号 = 图片文件名后缀数字(如 test-image-03.png → 03)" |

### 产物迁移记录（2026-08-01,`/home/xhm/文档/配图测试/`,非 git repo）

- 备份:`/tmp/si-migrate-backup-images-1785573288`(迁移前 images/ 快照)
- `images/test-img-01..04.png` → 顶层 `test-image-01..04.png`
- 副本 `test-image.md` 4 处 `![](images/test-img-NN.png)` → `![]({stem}-image-NN.png)`(Edit 逐处改,已 grep 验证无残留)
- `images/` 保留(内含 4 个 .mmd/.excalidraw 源文件)
- 旧 `/tmp/si-plan-*.json` 与遗留 `test.json`(v1 规划)不再使用,由 v3 命令显式拒绝/忽略

### v3 端到端验证记录(2026-08-01)

- **minimax 首次真实调用成功**:产物 1280×720,退出码 0(实测文件 `/home/xhm/文档/配图测试/test-minimax-image-01.png`)
- **发现缺陷「PNG 扩展名 + JPEG 内容」**:minimax 产物 `minimax-0.jpeg` 实测是 **JPEG 编码(1280×720)**,`mv` 仅换扩展名不换编码 → 严格按扩展名解析的工具解码失败
- **修复(格式统一,2026-08-01)**:slash command 新增「格式统一规范」,收敛为**单一规范文本**(Step 4a 末尾,路径 1/2 引用,避免三处重复维护):`file` 检测 → 已是真 PNG("PNG image data")跳过;JPEG → `ffmpeg -y -i <png> -update 1 <png>.fix.png && mv` 转码为真 PNG(先写临时文件再 mv 覆盖,同路径直写有截断风险;`-update 1` 抑制单帧输出提示);ffmpeg 缺失 → 警告"⚠️ 产物为 JPEG 编码但扩展名 .png,请安装 ffmpeg 以获得真 PNG;当前文件可正常显示"(不失败);转码后 `file` 验证。**仅 gemini/minimax 分支执行**;mermaid/excalidraw 输出本为真 PNG,不执行
- **source_file 路径规则统一**:相对文章目录;文件在 /tmp(如 prompt 文件)→ 写绝对路径并注释说明(schema 注释 / v3 变更 / 报告表格规范三处同步)
- 依赖新增:**ffmpeg(可选)**,JPEG→PNG 转码;缺失时产物保持 JPEG 编码并警告

---

## Section 11: 作者输出结构查证 + v3 验证记录(2026-08-01)

### 作者输出结构查证(2026-08-01,派研究 agent 核实作者原版设计)

| 事实 | 出处 |
|------|------|
| 正文配图放**顶层** `{stem}-image-NN.png`(两位零填充从 01) | SKILL.md:304-311「输出文件」章节、README.md:133-142「Output Files」章节,双文档图示一致 |
| 作者脚本**从不创建 images/ 子目录**:只有 `mkdir(dirname(output), {recursive:true})` 确保父目录存在 | generate-image.ts:641-642 / mermaid-export.ts:218-219 / excalidraw-export.ts:338 |
| 唯一建目录的是 slides 批量模式(默认 `./illustrations`) | batch-generate.ts:307 |
| `images/` 只出现在 README 的 slides 调用示例 `--output-dir ./images`(且与脚本默认 `./illustrations` 矛盾,纯示例文本) | README slides 示例 |
| 封面图 `{文章名}-cover.png` 顶层;副本 `{文章名}-image.md` 同目录;.mmd/.excalidraw 源文件同目录保留 | SKILL.md:304-311「输出文件」章节 |

**结论**:v3 的顶层命名 `{stem}-image-NN.png` 与作者完全一致;v2 的 `images/{stem}-img-NN.png` 才是偏离(v3 已迁回)。

### T1 测试(2026-08-01):无 flag 重跑分流验证

- 测试对象:test-minimax.md,无 flag 重跑 → **精确命中** Step 0.6「复用/重新分析」询问(路径 4 分流正确)
- 复用分支验证通过:**零 token**(不读原文、不 LLM 重新分析,直接沿用 manifest 执行 skip-existing)
- 测试发现的文档空白:**skip-existing 只校验文件存在性,不校验编码** —— 格式统一修复前生成的历史 JPEG 编码产物(扩展名 .png)会被静默跳过,文档无处理路径
  - **处理建议**:历史 JPEG 产物用 `--regen N` 强制重生(走格式统一转码修复),或 `--force` 全量重生;可选优化方向是 skip 校验叠加 `file` 编码检测
- 另:slash command 实际行数 **574**(commands/README.md 原写 550,已随本次同步修正)

### 用户使用实录(2026-08-01 晚)

- 用户手动跑 `--regen 1` 真实体验:**成功** —— 图片覆盖、副本零改动、格式统一修复端到端生效(产物变真 PNG 1.4MB)
- 这是 `--regen` 路径的**首次真实用户端到端验证**(此前仅 fixture/逻辑确认 + minimax 单次真实调用)

---

## Section 12: v3.2 变更(2026-08-04)

| 变更 | 内容 |
|------|------|
| PNG 收纳 | `images/{stem}-image-{NN}.png`,文章目录 **images/ 子目录**(先 `mkdir -p images`) |
| 副本插图 | **base64 data URI 内嵌单行** `![](data:image/png;base64,<...>)`(无尖括号包裹、无空格/换行,base64 以 `iVBOR` 开头;单行可达 ~950KB) |
| 自包含性 | 副本拷贝到任何地方打开都显示图片,不再依赖文章目录的 PNG 文件 |
| 副本引用刷新 | 覆盖 PNG 后**必须**刷新:按图片行序号定位(base64 行不含文件名,`grep image-NN.png` 失效;图片行按 manifest pictures id 升序对应)→ 整行替换为新 base64 行(引用缺失按 anchor 定位插入);**base64 行一律 python3 脚本操作(定位→拼单行→临时文件→`os.replace` 原子替换),禁用 Edit 工具** |
| manifest schema 固化 | 独立样本 `si-pipeline/skills/si-regen/schema/si-plan-v3.sample.json` + 校验脚本 `scripts/validate-manifest.sh`(bash,jq;校验 schema 版本/字段/状态机/序号连续性) |
| 仓库资产 | 命令事实源 `si-pipeline/commands/smart-illustrator-minimax.md`(v3.2,639 行)、skill 事实源 `si-pipeline/skills/si-regen/`(SKILL.md + schema/ + scripts/),安装方式见 Section 5 |
