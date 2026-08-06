# smart-illustrator-minimax

> AI 自动给文章配图：正文配图 + 文章封面，全部自动生成，图片直接内嵌进文章副本。

一个给 **Markdown 文章自动配图** 的自定义命令（Claude Code slash command）。你只需要写文章，它会帮你规划、生成并嵌入配图——打开文章就能看到图，拷走也照样显示。

## 它怎么工作的（小白版 3 步）

1. **读文章，做规划** —— 读完你的文章，生成一份「配图规划清单」（manifest，一个 JSON 文件）：哪里该放图、放什么图、封面用什么主题和隐喻。
2. **按清单生成图片** —— 三种引擎自动挑选：
   - **mermaid**：架构图、流程图、状态机（代码画的，精确）
   - **excalidraw**：概念对比、手绘风示意图（像白板手画）
   - **minimax AI 生图**：封面图（AI 根据隐喻描述创作，纯黑背景 + 琥珀金主光的风格化封面）
3. **把图嵌进文章副本** —— 图片以 base64 直接写进文章的 `_image` 副本文件。**任何编辑器打开都 100% 可见**，文章单文件自包含，拷到哪都能看。原文章一个字符都不改。

> 一句话：**它替你完成「配图师」的全部工作——规划、作画、排版。你只管写内容。**

## 需要什么环境

| 依赖 | 用途 | 安装 |
|---|---|---|
| Claude Code | 运行命令 | 官方安装 |
| bun 或 node | 渲染 mermaid / excalidraw 图 | `curl -fsSL https://bun.sh/install \| bash` |
| ffmpeg | 图片格式统一、生成缩略图 | `sudo apt install ffmpeg`（macOS: `brew install ffmpeg`） |
| Minimax API Key | AI 生成封面图 | 环境变量 `MINIMAX_IMAGE_API_KEY` |

## 怎么安装

1. 把本仓库的 `minimax-command/smart-illustrator-minimax.md` 复制到 `~/.claude/commands/`
2. 把 `si-regen/` 目录复制到 `~/.claude/skills/`（校验脚本用）
3. 把 `scripts/minimax_t2i.py` 放到任意位置（如 `~/图片/`），并在步骤 1 的命令文件里确认脚本路径
4. 设置环境变量（写到 `~/.bashrc` 或 `~/.zshrc`）：
   ```bash
   export MINIMAX_IMAGE_API_KEY="你的-minimax-api-key"
   ```
5. 重启 Claude Code，完成。

## 怎么用

在 Claude Code 里对你的文章运行：

```text
/smart-illustrator-minimax "我的文章.md"
```

跑完会在文章旁边生成 `我的文章_images/` 目录：

```
我的文章_images/
├── 我的文章.si-plan.json      ← 配图规划清单（manifest）
├── 我的文章-image-01.png      ← 正文配图（按需 1~4 张）
├── 我的文章-cover.png         ← 封面原图
├── 我的文章-cover-thumb.png   ← 封面缩略图（内嵌进副本用）
└── 我的文章-image.md          ← 配图后的文章副本（打开这个看效果）
```

### 常用参数

| 参数 | 作用 |
|---|---|
| `/smart-illustrator-minimax "文章.md"` | 完整流程：正文图 + 1 张封面 |
| `/smart-illustrator-minimax "文章.md" --regen cover` | 只重新生成封面（不满意封面时用） |
| `/smart-illustrator-minimax "文章.md" --force` | 全部重新生成 |
| `/smart-illustrator-minimax "文章.md" --no-cover` | 这次不碰封面 |
| `/smart-illustrator-minimax "文章.md" --cover-ratio 3:4` | 指定封面比例（默认 16:9） |
| `/smart-illustrator-minimax "文章.md" --regen 2` | 只重生成第 2 张正文图 |

## 常见问题

**Q: 打开副本看不到图？**
A: 副本里的图是 base64 内嵌的，任何支持 Markdown 图片的编辑器都该显示。若看不到，检查是否打开的是 `_images/` 下的 `-image.md` 副本（不是原文件）。封面在文章标题下方（`![cover](...)` 行）。

**Q: manifest（.si-plan.json）是什么？**
A: 配图规划清单——记录每张图用什么引擎、放哪、封面主题和 prompt。它是「规划基准」，重跑时会参考它，避免每次随机生成。

**Q: API key 在哪设置？**
A: 环境变量 `MINIMAX_IMAGE_API_KEY`。没设置时正文图（mermaid/excalidraw）仍能生成，只有封面会失败。

**Q: 生成的封面不满意？**
A: 直接重跑 `--regen cover`。AI 生图每次结果不同，多试几次总能挑到满意的。

**Q: 会改我的原文吗？**
A: 不会。所有改动都发生在 `{文章}_images/` 目录里，原文件一个字符都不会动。

## 与作者原版的关系

本项目是 [axtonliu/smart-illustrator](https://github.com/axtonliu/smart-illustrator) 的 **minimax 替代版**：作者原版用 Gemini 生封面，本版改用 Minimax（国内可用），并加入了 manifest 规划机制、封面双重表示（frontmatter + base64 内嵌）等增强。作者原版说明见 [README.en.md](README.en.md) 和 [README.zh-CN.md](README.zh-CN.md)。
