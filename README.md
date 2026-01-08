# Codex Engine — Production Repo (Lean + Python)

## Overview

This repository contains the **Codex Engine**, a production-grade implementation combining formal verification with practical simulation:

- **`lean/src/CodexEngine.lean`** — Formal Lean 4 module with Real-typed proofs, adjacency laws, MDL scoring, CFG validation, and PID control
- **`python/codex_sim.py`** — Numeric simulation harness with entropy validation, gzip compression analysis, and JSON output
- **`Dockerfile`** — Containerized build for server deployment
- **`Makefile`** — Convenience commands for testing and running
- **`.github/workflows/ci.yml`** — Continuous Integration pipeline

## Features

### Core Engine Components

1. **Seven-Phase Cyclic System (U₇)**
   - Black ⚫ → White ⚪ → Yellow 🟡 → Brown 🟤 → Red 🔴 → Green 🟢 → Blue 🔵 → Black
   - Adjacency law enforcement (both Prop-level for proofs and Bool for runtime)

2. **MDL (Minimum Description Length) Scoring**
   - Per-phase weights for trace complexity measurement
   - Real-typed constants for formal verification

3. **CFG (Context-Free Grammar) Validation**
   - Decidable runtime checks for canonical cycle shapes
   - Grammar constraints on trace patterns

4. **G-Score Alignment**
   - Objective function: `0.6*E + 0.4*S - mdl_weight(phase)`
   - Energy-entropy trade-off optimization

5. **Gray Zone Detection**
   - Multi-threshold anomaly detection
   - Energy bounds (E ≤ 1.0e7)
   - MDL bounds (mdl ≤ 200.0)
   - Adjacency violation checks

6. **K-Regulator Repair System**
   - K1: Triad unwind (Green reset)
   - K2: Structural rebuild (White soft reset)
   - K3: Hard reset (Black full reset)

7. **PID Overlay**
   - Proportional-Integral-Derivative control
   - Kp=0.8, Ki=0.05, Kd=0.12

### Python Simulator Features

- **Shannon entropy** calculation (byte-level)
- **Gzip compression ratio** analysis
- **White Gate** validation (entropy and compression thresholds)
- **Deterministic sealing** (SHA1-based, upgradeable to AES-256-GCM)
- **JSON trace output** with step-by-step state logging

## Server Prerequisites

- **Linux server** (Ubuntu 20.04+ or similar)
- **Python 3.11+**
- **(Optional)** Lean 4 + mathlib4 for formal proof development

## Quick Start (Python)

### 1. Set up environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Run simulation

```bash
# Using make
make sim

# Or directly
python python/codex_sim.py --input-file examples/sample.txt --steps 7 --out trace.json
```

### 3. Run tests

```bash
# Using make
make test

# Or directly
pytest -v tests/
```

## Docker Deployment

### Build image

```bash
make build-docker
# or: docker build -t codex-engine:latest .
```

### Run in container

```bash
make run-docker

# Or manually:
docker run --rm -v $(pwd)/examples:/data codex-engine:latest \
  --input-file /data/sample.txt --steps 7 --out /data/trace.json
```

## Lean Development

The Lean 4 module provides formal verification capabilities:

```bash
cd lean
lake build  # Requires Lean 4 and mathlib4
```

### Key Lean definitions

- `Phase` — Inductive type for seven phases
- `adj` / `adj_bool` — Adjacency predicates (Prop and Bool)
- `CodexStateR` — Real-typed state for proofs
- `CodexStateF` — Float-typed state for execution
- `step_R` — Single step function with PID, phase updates, and K-regulator
- `adj_next_prev` — Theorem proving adjacency properties

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs:

1. Python tests via pytest
2. Simulation smoke test
3. (Optional) Lean formatting/build checks

## Output Format

The simulator produces JSON with:

```json
{
  "input_entropy": 4.523,
  "gzip_ratio": 0.612,
  "flagged": false,
  "trace": ["Black", "White", "Yellow", "Brown", "Red", "Green", "Blue", "Black"],
  "seal": "⚿ABCD1234EFGH",
  "log": [
    {
      "phase": "White",
      "S": 0.09,
      "E": 1.0,
      "F_B": 0.0,
      "Psi_P": 0.0,
      "Psi_I": 0.005,
      "Psi_D": 0.0,
      "Psi_total": 0.005,
      "J": 1.09,
      "trace": ["Black", "White"],
      "mdl_val": 4.5,
      "g_score": 0.636
    }
    // ... more steps
  ]
}
```

## Production Notes

### Security

- **Replace `simple_seal`** with AES-256-GCM or HMAC-SHA256 for production
- **Add authentication** if exposing as web service
- **Validate inputs** thoroughly before processing

### Scalability

- For high-throughput scenarios, consider:
  - Async Python (asyncio/aiohttp)
  - Rust core implementation (via PyO3)
  - Compiled Lean binary (via Lake)

### Observability

Add structured logging and metrics:

```python
# Example: Prometheus metrics
from prometheus_client import Counter, Histogram
step_counter = Counter('codex_steps_total', 'Total steps executed')
energy_histogram = Histogram('codex_energy', 'Energy distribution')
```

### Formal Verification

To extend the Lean proofs:

1. Import `Mathlib.Analysis.SpecialFunctions.Log`
2. Develop Lyapunov function for J-invariant
3. Prove bounded energy: `∀ cs, step_R cs |> E ≤ bound`
4. Mechanize adjacency preservation across all phases

## Architecture

```
Unified-Universal-Equation/
├── lean/                  # Formal verification (Lean 4)
│   ├── leanpkg.toml
│   └── src/
│       └── CodexEngine.lean
├── python/                # Numeric simulation
│   └── codex_sim.py
├── tests/                 # Pytest suite
│   └── test_sim.py
├── examples/              # Sample inputs
│   └── sample.txt
├── .github/workflows/     # CI/CD
│   └── ci.yml
├── Dockerfile             # Container build
├── Makefile              # Build automation
├── LICENSE
└── README.md
```

## Next Steps

1. **Enhanced Cryptography**: Replace SHA1 seal with AES-256-GCM
2. **Full Formal Proofs**: Develop Lyapunov stability proofs in Lean
3. **REST API**: Wrap `codex_sim.py` in FastAPI/Flask
4. **Monitoring**: Add Prometheus/Grafana dashboards
5. **Benchmarking**: Profile performance on large inputs
6. **Rust Core**: Rewrite hot paths in Rust for 10-100x speedup

## License

See [LICENSE](LICENSE) file.

## Contributing

This is a research/production hybrid codebase. For formal verification questions, see Lean documentation. For simulation issues, check the Python tests.

## References

- Lean 4: https://leanprover.github.io/
- Mathlib4: https://github.com/leanprover-community/mathlib4
- Codex Engine specification: See `lean/src/CodexEngine.lean` for mathematical details
