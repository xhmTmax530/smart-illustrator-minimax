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

## Section 7: 已知限制

- minimax 配额有限，大量文章配图可能需分批
- `--regen`/`--force` 在 minimax API 不可用时只能重生 mermaid/excalidraw (走作者脚本，无 API 依赖)
- 当前未做端到端测试 (minimax 配额暂停); 逻辑已通过 fixture 模拟确认 (skip-existing + PNG 覆盖)
