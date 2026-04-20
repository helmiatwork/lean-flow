#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
from datetime import datetime, timezone, timedelta

projects_dir = Path.home() / ".claude" / "projects"
# window: "today" or "7d" from argv (default "today")
window = sys.argv[1] if len(sys.argv) > 1 else "today"

now = datetime.now(timezone.utc)
if window == "7d":
    cutoff = now - timedelta(days=7)
else:  # today
    cutoff = now.replace(hour=0, minute=0, second=0, microsecond=0)

models = {}  # model_name -> {input, output, cache_creation, cache_read}

for jsonl_file in projects_dir.rglob("*.jsonl"):
    try:
        with open(jsonl_file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except:
                    continue
                if entry.get("type") != "assistant":
                    continue
                # Check timestamp
                ts_str = entry.get("timestamp")
                if ts_str:
                    try:
                        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                        if ts < cutoff:
                            continue
                    except:
                        continue
                msg = entry.get("message", {})
                model = msg.get("model", "")
                if not model or model == "<synthetic>":
                    continue
                usage = msg.get("usage", {})
                if not usage:
                    continue
                inp = usage.get("input_tokens", 0) or 0
                out = usage.get("output_tokens", 0) or 0
                cc = usage.get("cache_creation_input_tokens", 0) or 0
                cr = usage.get("cache_read_input_tokens", 0) or 0
                if model not in models:
                    models[model] = {"input": 0, "output": 0, "cache_creation": 0, "cache_read": 0}
                models[model]["input"] += inp
                models[model]["output"] += out
                models[model]["cache_creation"] += cc
                models[model]["cache_read"] += cr
    except:
        continue

# Compute total output tokens for % calculation
total_out = sum(v["output"] for v in models.values()) or 1

# Sort by output tokens descending
sorted_models = sorted(models.items(), key=lambda x: x[1]["output"], reverse=True)

result = {
    "window": window,
    "models": [
        {
            "name": name,
            "input": data["input"],
            "output": data["output"],
            "cache_creation": data["cache_creation"],
            "cache_read": data["cache_read"],
            "pct": round(data["output"] / total_out * 100, 1)
        }
        for name, data in sorted_models
        if data["output"] > 0 or data["input"] > 0
    ]
}
print(json.dumps(result))
