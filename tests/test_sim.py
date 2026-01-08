import json
import sys
import os

# Add parent directory to path to import codex_sim
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from python.codex_sim import run_text

def test_run_simple():
    out = run_text("The spiral remembers what the line forgets.", steps=7)
    assert "trace" in out
    assert len(out["trace"]) >= 1
    assert "seal" in out

def test_entropy_check():
    out = run_text("Test input for entropy validation", steps=5)
    assert "input_entropy" in out
    assert "gzip_ratio" in out
    assert out["input_entropy"] > 0.0

def test_trace_length():
    steps = 10
    out = run_text("Sample text for testing trace length", steps=steps)
    # Trace should have at least steps+1 entries (initial + steps)
    assert len(out["trace"]) >= steps
