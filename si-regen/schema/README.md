# si-minimax/v3 manifest 字段文档

> 本文件是 `smart-illustrator-minimax`(命令文件 `~/.claude/commands/smart-illustrator-minimax.md` Step 3)Schema v3 的字段固化文档。任何 agent 生成/修改 manifest 前必须先读本文件。

## 文件与校验

| 项 | 路径 |
|---|---|
| 样本(完整合法) | `~/.claude/skills/si-regen/schema/si-plan-v3.sample.json` |
| 本字段文档 | `~/.claude/skills/si-regen/schema/README.md` |
| 校验脚本 | `~/.claude/skills/si-regen/scripts/validate-manifest.sh` |
| 校验用法 | `bash validate-manifest.sh <manifest.json>`;通过 exit 0,失败 exit 1(输出具体到字段的中文错误) |

manifest 位置:文章目录 `{stem}.si-plan.json`,与副本 `{stem}-image.md` 平级。写盘后必须 `jq -e .` 校验。

## 顶层结构

```json
{
  "_meta": { "...": "元信息,见下" },
  "pictures": [ "...": "配图规划数组,见下" ]
}
```

## `_meta` 字段

| 字段 | 必填 | 类型 | 取值/示例 | 说明 |
|---|---|---|---|---|
| `schema` | 必填 | 字符串 | 固定 `"si-minimax/v3"` | 版本标识,校验器强校验;旧版(v1/v2)一律拒绝升级 |
| `source` | 必填 | 字符串 | `"/home/xhm/文档/测试生图2/xx.md"` | 文章规范化绝对路径(Step 0 realpath 结果),非空 |
| `source_mtime` | 必填 | 整数或数字字符串 | `1783740240` | `stat -c %Y` 文章;陈旧检测用。命令文件规范为整数;真实 manifest 是字符串,校验器两者都接受 |
| `source_size` | 必填 | 整数或数字字符串 | `13756` | `stat -c %s` 文章,同上 |
| `produced_at` | 必填 | 字符串 | `"2026-08-03T16:37:01+08:00"` | ISO8601 时间,非空 |
| `total` | 必填 | 整数 | `3` | **必须 == `pictures` 数组长度**(一致性硬要求) |
| `by_engine` | 必填 | 对象 | `{"gemini":1,"excalidraw":1,"mermaid":1}` | 键必须 ∈ {gemini, excalidraw, mermaid}(禁止枚举外键);各值为非负整数;**各值之和必须 == `total`**。无某引擎图片时该键可省略或写 0 |

## `pictures[]` 字段

| 字段 | 必填 | 类型 | 取值 | 说明 |
|---|---|---|---|---|
| `id` | 必填 | 整数 | `1`, `2`, `3`... | 正整数,全表唯一,建议从 1 连续递增。id N ↔ PNG 编号 `images/{stem}-image-NN.png`(NN 两位零填充) |
| `engine` | 必填 | 字符串 | `gemini` \| `excalidraw` \| `mermaid` | 严格枚举,禁止自定义值 |
| `topic` | 必填 | 字符串 | 非空,如 `"AI 处理「洞察」的 5 步标准执行逻辑"` | 图片主题(短),`-content` 智能匹配打分维度之一 |
| `content` | 必填 | 字符串 | 非空,如 `"顺序流程图,5 个步骤节点:..."` | 图片内容描述;mermaid/excalidraw 按它写源文件,geminiprompt 按它+style 拼 |
| `anchor` | 必填 | 字符串 | 非空,如 `"第 1 节 1.2 五步执行逻辑列表之后(第 5 步之后空行前)"` | 段落定位描述;副本引用缺失时用它定位插入 |
| `source_file` | 条件必填 | 字符串 | `images/insight-5steps.mmd` / `images/xx.excalidraw` / `/tmp/xx` 绝对路径 | **mermaid/excalidraw 必填非空**:相对文章目录、带 `images/` 前缀(源文件保留在 images/ 子目录)。**gemini 可空**:缺失/null/空串均可,或写 `/tmp` 绝对路径 |
| `source_prompt` | 仅 gemini 有意义 | 字符串 | 完整 prompt 文本,或 `"见 /tmp/si-prompt-01.txt(生成时写入)"` | gemini 重生时取 prompt 的来源(si-regen 支持两种形态:完整文本直接用;路径引用则 `cat` 该文件)。非 gemini 图片按真实 manifest 约定写空串 `""` |
| `status` | 必填 | 字符串 | `planned` \| `generated` \| `failed` | 生命周期见下 |

## 条件性细则

- **source_file 的条件性**:engine ∈ {mermaid, excalidraw} → 必须非空(缺失则重生时报"源文件缺失,请用 --force 重建");engine == gemini → 不强制(可缺省/空/`/tmp` 绝对路径)。
- **source_prompt 存哪里**:完整 prompt 文本(命令文件规范)或 `/tmp/si-prompt-{NN}.txt` 路径引用(真实 manifest 形态)两种都合法,校验器只要求是字符串;gemini 图片 source_prompt 为空时校验器给**警告**(不阻塞)——重生时无法取 prompt。
- **status 生命周期**:Step 3 写 manifest 时全部为 `planned`;每张图片执行后即时更新为 `generated` 或 `failed`。`failed` 的图保留在 manifest(不删除),`--force`/`--regen` 可重试。

## `_meta` 与 `pictures` 一致性要求(校验器强校验)

1. `_meta.total` == `pictures` 数组长度
2. `by_engine` 各键值之和 == `_meta.total`(by_engine 按 engine 统计,与 status 无关)
3. 每张 `id` 唯一(建议 1..N 连续递增,非连续仅警告)

## 校验项速查(a-g + h)

- a) 顶层是合法 JSON 对象
- b) `_meta.schema == "si-minimax/v3"`
- c) `_meta.source` 非空字符串;`source_mtime`/`source_size` 为整数(兼容数字字符串);`produced_at` 非空字符串
- d) `_meta.total` 为整数且 == `pictures` 长度
- e) `pictures` 非空数组;每张 `id` 为正整数且唯一;`engine` ∈ 枚举;`topic`/`content`/`anchor` 非空字符串;`status` ∈ 枚举
- f) engine ∈ {mermaid, excalidraw} → `source_file` 必填非空;gemini → `source_file` 可为空
- g) `by_engine` 键 ∈ 枚举,各值非负整数,之和 == `total`
- h)(附加)`source_prompt` 若存在必须为字符串;gemini 空 `source_prompt` 给警告

## 真实 manifest 兼容性备注

实测 `/home/xhm/文档/测试生图2/Prompt高级专业术语全解.si-plan.json`(si-minimax/v3)与命令文件规范有两处出入,校验器已按"两者都接受"实现:

1. `source_mtime`/`source_size` 实为**字符串**(`"1783740240"`),命令文件规范为整数 —— 校验器接受整数与纯数字字符串,新输出建议按命令文件写整数
2. gemini 图片**不带 `source_file` 键**,`source_prompt` 写路径引用而非完整文本;非 gemini 图片带 `source_prompt: ""` —— 校验器均兼容
