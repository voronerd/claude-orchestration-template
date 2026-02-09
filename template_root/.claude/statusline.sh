#!/usr/bin/env python3
"""Claude Code Status Line - Context awareness for proactive handoffs
Format: Model XX% $X.XX mm:ss/mm:ss +N/-N

Color thresholds:
  Green  < 60%  - Plenty of room
  Yellow < 80%  - Start thinking about handoff
  Red    >= 80% - Prepare handoff NOW
"""
import json, sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("?")
    sys.exit(0)

# Colors
RED, YELLOW, GREEN, CYAN, DIM, RESET = (
    "\033[0;31m", "\033[0;33m", "\033[0;32m", "\033[0;36m", "\033[2m", "\033[0m"
)

def ms_to_mmss(ms):
    secs = int(ms) // 1000
    return f"{secs // 60}:{secs % 60:02d}"

def get(obj, *keys, default=None):
    for k in keys:
        if isinstance(obj, dict):
            obj = obj.get(k)
        else:
            return default
    return obj if obj is not None else default

# Model
model_info = data.get("model", {})
if isinstance(model_info, dict):
    model = model_info.get("display_name", model_info.get("id", "?"))
else:
    model = str(model_info) if model_info else "?"

# Context percentage
pct = get(data, "context_window", "used_percentage", default=None)
if pct is None:
    total = get(data, "context_window", "context_window_size", default=200000)
    used = get(data, "context_window", "total_input_tokens", default=0)
    pct = (used * 100 / total) if total > 0 else 0
pct_int = int(round(float(pct)))

# Cost
cost = get(data, "cost", "total_cost_usd", default=0)
cost_str = f" {DIM}${float(cost):.2f}{RESET}" if cost and float(cost) > 0 else ""

# Duration
total_ms = get(data, "cost", "total_duration_ms", default=0)
api_ms = get(data, "cost", "total_api_duration_ms", default=0)
dur_str = f" {DIM}{ms_to_mmss(total_ms)}/{ms_to_mmss(api_ms)}{RESET}" if int(total_ms) > 0 else ""

# Churn
added = get(data, "cost", "total_lines_added", default=0)
removed = get(data, "cost", "total_lines_removed", default=0)
churn_str = f" {DIM}+{added}/-{removed}{RESET}" if int(added) > 0 or int(removed) > 0 else ""

# Context color
if pct_int >= 80:
    color, indicator = RED, "!"
elif pct_int >= 60:
    color, indicator = YELLOW, "*"
else:
    color, indicator = GREEN, ""

print(f"{CYAN}{model}{RESET} {color}{indicator}{pct_int}%{RESET}{cost_str}{dur_str}{churn_str}")
