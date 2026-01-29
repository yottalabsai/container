# Verl

Verl 是一个面向 **LLM 后训练 / 强化学习训练（RL）** 的框架，典型场景包括：
- RLHF / DPO / PPO 等训练流程的工程化
- 分布式训练、数据与采样 pipeline、训练作业编排等

> 本模板额外内置了一个小模型推理 demo（Qwen/Qwen2.5-0.5B-Instruct），用于验证镜像开箱可用。
> 推理 demo 不代表 Verl 的核心能力。

## 文件说明（镜像内）

- `/workspace/demo_qwen_infer.py`：预制推理 demo（控制台打印）
- `/workspace/Verl_Qwen2.5_Demo.ipynb`：Notebook demo
- `/workspace/EXAMPLES.md`：安装/使用示例
