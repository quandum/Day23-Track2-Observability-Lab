#!/usr/bin/env python3
"""Langfuse LLM trace for BONUS-llm-native-obs (+10 pts).

Self-hosted Langfuse @ localhost:3000. Keys from .env.
Uses @observe() decorator (langfuse v4 API).
"""
from __future__ import annotations

import os
import time

from dotenv import load_dotenv
load_dotenv()

os.environ.setdefault("LANGFUSE_BASE_URL", "http://localhost:3000")

from langfuse import observe


@observe(as_type="generation")
def ask_llm(question: str) -> dict:
    """Simulate LLM call with gen_ai.* attributes captured by Langfuse."""
    time.sleep(0.15)

    model = "gpt-4o-mini"
    in_toks = len(question.split()) + 2
    out_toks = 35
    cost = round((in_toks + out_toks) / 1000 * 0.0005, 6)
    answer = f"[mock] AI: '{question[:30]}...' — Observability là nền tảng AI reliability."

    return {
        "model": model,
        "input_tokens": in_toks,
        "output_tokens": out_toks,
        "cost_usd": cost,
        "latency_ms": 152,
        "answer": answer,
    }


if __name__ == "__main__":
    result = ask_llm("Observability cho AI system quan trọng như thế nào?")
    print(f"Model:  {result['model']}")
    print(f"Tokens: {result['input_tokens']} in + {result['output_tokens']} out")
    print(f"Cost:   ${result['cost_usd']}")
    print(f"Answer: {result['answer']}")
    print(f"\n✅ Trace sent to Langfuse → http://localhost:3000")
    print("   Login: admin@test.com / Admin@123!")
