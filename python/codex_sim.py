#!/usr/bin/env python3
"""
codex_sim.py — CodexEngine numeric simulator / runner (server-oriented)
Usage:
    python codex_sim.py --input-file text.txt --steps 7 --out trace.json
Outputs:
    trace.json : JSON with step-by-step state, seal, and flags
"""

import argparse, gzip, json, collections, math, logging, hashlib, base64, sys
from dataclasses import dataclass, asdict
from typing import List

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# ---------- Utilities ----------
def shannon_entropy_bytes(b: bytes) -> float:
    if len(b) == 0: return 0.0
    freq = collections.Counter(b)
    N = len(b)
    return -sum((c/N) * math.log2(c/N) for c in freq.values())

def gzip_ratio(b: bytes) -> float:
    if len(b) == 0: return 1.0
    return len(gzip.compress(b)) / len(b)

def simple_seal(trace_str: str) -> str:
    # deterministic base32-like seal (non-crypto); replace with AES/HMAC in production
    h = hashlib.sha1(trace_str.encode("utf-8")).digest()
    return "⚿" + base64.b32encode(h)[:12].decode("utf-8")

# ---------- Compact Engine (Float mirror of Lean) ----------
PHASES = ["Black","White","Yellow","Brown","Red","Green","Blue"]
def next_phase(p: str) -> str:
    idx = PHASES.index(p)
    return PHASES[(idx + 1) % len(PHASES)]

@dataclass
class State:
    phase: str
    S: float
    E: float
    F_B: float
    Psi_P: float
    Psi_I: float
    Psi_D: float
    Psi_total: float
    J: float
    trace: List[str]
    mdl_val: float
    g_score: float

def mdl_weight(phase: str) -> float:
    table = {"Black":3.5,"White":1.0,"Yellow":1.3,"Brown":2.0,"Red":2.5,"Green":1.7,"Blue":1.1}
    return table[phase]

def mdl_trace_score(trace: List[str]) -> float:
    return sum(mdl_weight(p) for p in trace)

def g_score_fn(phase: str, E: float, S: float) -> float:
    return 0.6 * E + 0.4 * S - mdl_weight(phase)

def compute_pid(state: State, prev_E: float, prev_S: float):
    Kp, Ki, Kd = 0.8, 0.05, 0.12
    dE = state.E - prev_E
    dS = state.S - prev_S
    P = Kp * dE
    I = state.Psi_I + Ki * state.S
    D = Kd * dS
    state.Psi_P, state.Psi_I, state.Psi_D = P, I, D
    state.Psi_total = P + I + D

def gray_detect(state: State) -> bool:
    adjacency_ok = (next_phase(state.phase) == state.trace[-1]) or (state.phase == state.trace[-1])
    # Use MDL and E thresholds
    if state.E > 1.0e7: return True
    if state.mdl_val > 200.0: return True
    # runtime adjacency check: phase -> next must match allowed steps
    idx = PHASES.index(state.phase)
    expected = PHASES[(idx + 1) % 7]
    if expected != next_phase(state.phase):
        # defensive: compute as True if mismatch
        return False
    return False

def apply_K(state: State) -> State:
    # conservative hard reset (K3)
    state.phase = "Black"
    state.S = 0.0
    state.E = 0.0
    state.F_B = 0.0
    state.Psi_P = state.Psi_I = state.Psi_D = state.Psi_total = 0.0
    state.J = 0.0
    state.trace = ["Black"]
    state.mdl_val = mdl_trace_score(state.trace)
    state.g_score = g_score_fn("Black", 0.0, 0.0)
    return state

def step_once(state: State, prev_E: float, prev_S: float) -> State:
    compute_pid(state, prev_E, prev_S)
    psi = state.Psi_total
    # prospective updates
    E_n = state.E + psi
    S_n = state.S - 0.5 * psi
    F_B_n = max(state.F_B, psi)
    next_p = next_phase(state.phase)
    trace_n = state.trace + [next_p]
    mdl_n = mdl_trace_score(trace_n)
    g_n = g_score_fn(next_p, E_n, S_n)
    # grammar+gray checks
    if mdl_n > 200.0 or E_n > 1.0e7:
        state = apply_K(state)
        return state
    # commit
    new_state = State(phase=next_p, S=S_n, E=E_n, F_B=F_B_n, Psi_P=state.Psi_P, Psi_I=state.Psi_I,
                      Psi_D=state.Psi_D, Psi_total=psi, J=E_n + S_n, trace=trace_n, mdl_val=mdl_n, g_score=g_n)
    return new_state

# ---------- CLI / Runner ----------
def run_text(input_text: str, steps: int = 7):
    b = input_text.encode("utf-8")
    H = shannon_entropy_bytes(b)
    R = gzip_ratio(b)
    # white gate: example thresholds
    if not (3.5 < H < 6.8 and R > 0.35):
        logging.warning("Input fails White Gate: H=%.3f R=%.3f", H, R)
        # we still attempt, but mark as flagged
        flagged = True
    else:
        flagged = False
    s = State(phase="Black", S=0.1, E=1.0, F_B=0.0, Psi_P=0.0, Psi_I=0.0, Psi_D=0.0, Psi_total=0.0,
              J=1.1, trace=["Black"], mdl_val=mdl_trace_score(["Black"]), g_score=g_score_fn("Black",1.0,0.1))
    prev_E, prev_S = s.E, s.S
    log = []
    for i in range(steps):
        s = step_once(s, prev_E, prev_S)
        prev_E, prev_S = s.E, s.S
        log.append(asdict(s))
    trace_str = "->".join(s.trace)
    seal = simple_seal(trace_str)
    out = {"input_entropy": H, "gzip_ratio": R, "flagged": flagged, "trace": s.trace, "seal": seal, "log": log}
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-file", required=True)
    ap.add_argument("--steps", type=int, default=7)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    txt = open(args.input_file, "rb").read().decode("utf-8", errors="replace")
    result = run_text(txt, steps=args.steps)
    out_path = args.out or "codex_trace.json"
    open(out_path, "w", encoding="utf-8").write(json.dumps(result, indent=2))
    print("Wrote:", out_path)

if __name__ == "__main__":
    main()
