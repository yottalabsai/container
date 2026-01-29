#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Qwen2.5-0.5B-Instruct 预制推理 Demo

- 第一次运行会从 HuggingFace 下载模型（走 /workspace/.cache/huggingface 缓存）
- 仅用于“开箱即用”验证镜像可用性，不代表 Verl 的核心能力（Verl 主要用于后训练 / RL）
"""

import os
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM


def main():
    model_id = os.environ.get("MODEL_ID", "Qwen/Qwen2.5-0.5B-Instruct")
    prompt = os.environ.get("DEMO_PROMPT", "用一句话解释什么是强化学习。")

    print(f"[demo] MODEL_ID={model_id}")
    print(f"[demo] torch={torch.__version__} cuda_available={torch.cuda.is_available()}")

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
        device_map="auto" if torch.cuda.is_available() else None,
        trust_remote_code=True,
    )
    model.eval()

    inputs = tokenizer(prompt, return_tensors="pt")
    if torch.cuda.is_available():
        inputs = {k: v.to("cuda") for k, v in inputs.items()}

    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=int(os.environ.get("MAX_NEW_TOKENS", "256")),
            do_sample=True,
            temperature=float(os.environ.get("TEMPERATURE", "0.7")),
            top_p=float(os.environ.get("TOP_P", "0.9")),
        )

    text = tokenizer.decode(output_ids[0], skip_special_tokens=True)
    print("\n================= OUTPUT =================")
    print(text)
    print("=========================================\n")


if __name__ == "__main__":
    main()
