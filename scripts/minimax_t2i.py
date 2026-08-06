#!/usr/bin/env python3
"""
MiniMax 文生图 (text-to-image) 一键脚本
- 端点: https://api.minimaxi.com/v1/image_generation
- 鉴权: Bearer <API_KEY>  (从环境变量 MINIMAX_IMAGE_API_KEY 读取,缺省回落到 MINIMAX_API_KEY)
- 模型: image-01 (默认) / image-01-live
"""
import argparse
import base64
import json
import os
import sys
import urllib.request
from pathlib import Path

ENDPOINT = "https://api.minimaxi.com/v1/image_generation"
DEFAULT_MODEL = "image-01"
ASPECT_RATIOS = ["1:1", "16:9", "4:3", "3:2", "2:3", "3:4", "9:16", "21:9"]


def get_api_key() -> str:
    key = os.environ.get("MINIMAX_IMAGE_API_KEY") or os.environ.get("MINIMAX_API_KEY")
    if not key:
        sys.exit("❌ 没找到 API Key,请先设置 MINIMAX_IMAGE_API_KEY 环境变量")
    return key


def generate(prompt: str, *, model: str = DEFAULT_MODEL, aspect_ratio: str = "1:1",
             n: int = 1, response_format: str = "base64", seed: int | None = None,
             prompt_optimizer: bool = False, watermark: bool = False) -> dict:
    body = {
        "model": model,
        "prompt": prompt,
        "aspect_ratio": aspect_ratio,
        "response_format": response_format,
        "n": n,
        "prompt_optimizer": prompt_optimizer,
        "aigc_watermark": watermark,
    }
    if seed is not None:
        body["seed"] = seed
    payload = json.dumps(body).encode()
    req = urllib.request.Request(
        ENDPOINT,
        data=payload,
        headers={
            "Authorization": f"Bearer {get_api_key()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
    if result.get("base_resp", {}).get("status_code") != 0:
        sys.exit(f"❌ 接口报错: {result}")
    return result


def save_images(result: dict, out_dir: Path, response_format: str) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    saved = []
    if response_format == "base64":
        for i, b64 in enumerate(result["data"]["image_base64"]):
            p = out_dir / f"minimax-{i}.jpeg"
            p.write_bytes(base64.b64decode(b64))
            saved.append(p)
    else:  # url
        for i, url in enumerate(result["data"]["image_urls"]):
            with urllib.request.urlopen(url, timeout=60) as r:
                p = out_dir / f"minimax-{i}.jpeg"
                p.write_bytes(r.read())
                saved.append(p)
    return saved


def main() -> None:
    ap = argparse.ArgumentParser(description="MiniMax 文生图")
    ap.add_argument("prompt", help="图片描述,最长 1500 字符")
    ap.add_argument("--out", default="./minimax_out", help="输出目录")
    ap.add_argument("--model", default=DEFAULT_MODEL, choices=["image-01", "image-01-live"])
    ap.add_argument("--ratio", default="1:1", choices=ASPECT_RATIOS, help="宽高比")
    ap.add_argument("--n", type=int, default=1, help="生成张数 1-9")
    ap.add_argument("--format", default="base64", choices=["base64", "url"])
    ap.add_argument("--seed", type=int, default=None, help="固定 seed 可复现")
    ap.add_argument("--optimize", action="store_true", help="开启 prompt 自动改写")
    ap.add_argument("--watermark", action="store_true", help="加 AIGC 水印")
    args = ap.parse_args()

    result = generate(
        args.prompt,
        model=args.model,
        aspect_ratio=args.ratio,
        n=args.n,
        response_format=args.format,
        seed=args.seed,
        prompt_optimizer=args.optimize,
        watermark=args.watermark,
    )
    paths = save_images(result, Path(args.out), args.format)
    print(f"✅ 已生成 {len(paths)} 张图片:")
    for p in paths:
        print(f"  - {p}")


if __name__ == "__main__":
    main()