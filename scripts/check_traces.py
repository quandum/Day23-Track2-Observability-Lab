"""Check Jaeger for traces and display span hierarchy."""
from __future__ import annotations

import json
import sys
from urllib.request import urlopen

JAEGER = "http://localhost:16686"


def show_trace(trace_id: str) -> None:
    url = f"{JAEGER}/api/traces/{trace_id}"
    with urlopen(url) as resp:
        data = json.load(resp)
    for trace in data.get("data", []):
        spans = trace.get("spans", [])
        # Build parent map
        by_id = {s["spanID"]: s for s in spans}
        roots = [s for s in spans if "references" not in s or not any(r.get("refType") == "CHILD_OF" for r in s.get("references", []))]
        print(f"  trace {trace_id[:20]}... ({len(spans)} spans)")
        for s in spans:
            refs = s.get("references", [])
            parent = "root" if not any(r.get("refType") == "CHILD_OF" for r in refs) else refs[0].get("spanID", "?")[:12]
            tags = {t["key"]: str(t["value"])[:40] for t in s.get("tags", [])}
            genai = {k: v for k, v in tags.items() if k.startswith("gen_ai") or k == "span.kind"}
            print(f"    {s['operationName']} (parent={parent}) {genai}")


def main() -> int:
    url = f"{JAEGER}/api/traces?service=inference-api&limit=5&lookback=10m"
    with urlopen(url) as resp:
        data = json.load(resp)

    traces = data.get("data", [])
    print(f"Total traces found: {len(traces)}")

    full = 0
    for t in traces:
        spans = t.get("spans", [])
        ops = [s["operationName"] for s in spans]
        n = len(spans)
        if n >= 3:
            full += 1
        print(f"\n  [{n} spans]: {' → '.join(ops)}")
        if n >= 3:
            show_trace(t["traceID"])

    print(f"\nSummary: {len(traces)} traces, {full} full (>=3 spans)")
    return 0 if full > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
