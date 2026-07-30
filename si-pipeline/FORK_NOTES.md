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
| PNG 命名 | `{stem}-image-NN.png` | ✅ 沿用 |
| 状态机 | 作者用心跳 = 状态机 | ✅ 沿用 (原 deepseek 引入 manifest 已被 2fd737c refactor 撤掉) |
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
- **关键洞察**: 文件名不变 → 副本 `![](images/{stem}-img-NN.png)` 自动指向新图，**零额外操作**
- 默认行为: 已有 PNG → 跳过 (避免 API 重复扣费)
- 来源: 来自 commit `01b6809` 的 deepseek 偏差补丁设计参考 + 作者 `batch-generate.ts` 的 skip-existing 模式

---

## Section 3: minimax 替代 Gemini

- 原因: 用户没订阅 Gemini; minimax 是国内可用 API
- 唯一差异: `scripts/generate-image.ts` → `~/图片/minimax_t2i.py` (用户本地脚本)
- 调用方式: `python3 ~/图片/minimax_t2i.py --prompt-file <tmp.txt> --output <png>`
- 环境变量: `MINIMAX_API_KEY` (无 fallback)
- 限制: minimax 配额有限，可能触发 `QuotaExceeded` → 该图跳过，继续下一张

---

## Section 4: 非侵入承诺

```
❌ 不改 ~/.claude/skills/smart-illustrator/SKILL.md
❌ 不改 scripts/*.ts
❌ 不改 styles/*.md
❌ 不改 references/*.md
❌ 不改 {stem}.md (原文)
✅ 只写: {stem}-image.md (副本)、images/*.{png}、{chart}.mmd/.excalidraw、/tmp/si-plan-*.json
```

---

## Section 5: 安装说明

用户怎么用这个 fork:

1. clone fork 到 `~/.claude/skills/smart-illustrator` (替换原版)
   ```bash
   git clone https://github.com/xhmTmax530/smart-illustrator-minimax.git ~/.claude/skills/smart-illustrator
   ```
2. 安装 slash command (文件不在 repo 里):
   ```bash
   # 从本会话或手动复制 ~/.claude/commands/smart-illustrator-minimax.md
   ```
3. 装依赖:
   ```bash
   npm i -g @mermaid-js/mermaid-cli
   cd ~/.claude/skills/smart-illustrator/scripts && npm install && npx playwright install firefox
   export MINIMAX_API_KEY=<你的 key>
   ```
4. 使用:
   ```bash
   /smart-illustrator-minimax "<article.md>" [extra hints]
   /smart-illustrator-minimax "<article.md>" --regen 3
   /smart-illustrator-minimax "<article.md>" --force
   ```

---

## Section 6: 版本与同步策略

- 上游版本: 跟随 axtonliu/smart-illustrator 的 `main` 分支
- 本 fork: 独立 `feat/placeholder-pipeline` 分支
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

`/tmp/si-plan-{stem}.json` 在路径 4（首次全流程）中必写，路径 1/2/3 纯读 manifest 不写。manifest 缺失时，所有 flag 均退回路径 4，不报错（退化为"首次运行"行为）。

Step 0 的 manifest 检测是**最先执行的**，在任何分析之前。这确保了早退路径不会被误触发。

### v1/v2 兼容性策略

| 场景 | 处理 |
|------|------|
| 新代码读 v1 manifest | `source_file`/`source_prompt` → `null`，路径 1 降级报错；路径 2 尝试从 `content` 重建 |
| v1 + `--regen` mermaid/excalidraw 缺源文件 | 报错"请用 --force 重建" |
| 旧代码读 v2 manifest | JSON.parse 忽略未知字段，完全兼容 |
| v2 写回 v1 文件 | 只追加字段（`anchor`/`source_file`/`source_prompt`），不删除原有字段 |

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

**范围校验**：路径 1 的 `--regen N` 在 jq 抽取之前做严格范围检查，N 超范围时报错跳过，**不调用任何 jq**，确保 manifest 和 PNG 不被副作用修改（2026-07-30 修复场景 4）。
