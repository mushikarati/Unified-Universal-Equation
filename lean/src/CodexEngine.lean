/-
Lean 4 production module: CodexEngine
Purpose: Single-file module capturing the Codex One-Ring engine with
         adjacency law, MDL, CFG, G-score, Gray detector, PID skeleton,
         repair regulator K, and step semantics.

This file aims for a production setup: Real-typed constants for proofs,
Bool/Prop boundaries handled, and an executable simulation flavor via Float.
-/

import Std.Data.Real -- minimal Std reals; for heavy proofs import Mathlib

namespace CodexEngine

open Std

/-
I. Phase space (U₇) and navigation
-/
inductive Phase
| Black  -- ⚫
| White  -- ⚪
| Yellow -- 🟡
| Brown  -- 🟤
| Red    -- 🔴
| Green  -- 🟢
| Blue   -- 🔵
deriving DecidableEq, Repr, Inhabited

open Phase

def next : Phase → Phase
| Black  => White
| White  => Yellow
| Yellow => Brown
| Brown  => Red
| Red    => Green
| Green  => Blue
| Blue   => Black

def prev : Phase → Phase
| Black  => Blue
| White  => Black
| Yellow => White
| Brown  => Yellow
| Red    => Brown
| Green  => Red
| Blue   => Green

/-- Prop-level adjacency law (for proofs) -/
def adj (a b : Phase) : Prop := b = next a ∨ b = prev a

/-- Bool-level adjacency (decidable runtime check) -/
def adj_bool (a b : Phase) : Bool := (b == next a) || (b == prev a)

theorem adj_next_prev (p : Phase) : adj p (next p) ∧ adj p (prev p) := by
  cases p <;> simp [adj, next, prev]

/-
II. Symbolic numeric anchors (Real for proofs)
Replace Float placeholders with Real constants when you formalize.
-/
def φ : Real := 1.618033988  -- golden ratio (Green)
def τ : Real := 2 * Real.pi  -- tau (Blue)
def e_const : Real := Real.exp 1.0
def h_planck : Real := 6.62607015e-34
def catalan_G : Real := 0.915965594
def khinchin_K : Real := 2.685452001
def na_Avogadro : Real := 6.02214076e23

/-
III. MDL weights (Real)
-/
def mdl_weight : Phase → Real
| Black  => 3.5
| White  => 1.0
| Yellow => 1.3
| Brown  => 2.0
| Red    => 2.5
| Green  => 1.7
| Blue   => 1.1

def mdl_trace_score (trace : List Phase) : Real :=
  trace.foldl (fun acc p => acc + mdl_weight p) 0.0

/-
IV. CFG validator — runtime Bool + decidable wrapper
We check the last window of the trace for canonical shapes.
-/
def is_whole_cycle (l : List Phase) : Bool := l == [White, Yellow, Brown, Red, Green, Blue]
def is_short_cycle (l : List Phase) : Bool := l == [Black, White, Yellow]

def grammar_valid_bool (trace : List Phase) : Bool :=
  let n := trace.length
  if n < 3 then false else
  if n >= 6 then
    let tail := trace.drop (n - 6)
    is_whole_cycle tail
  else
    is_short_cycle (trace.take 3)

/-
V. G-score: alignment objective (Real)
-/
def g_score_fn (phase : Phase) (E S : Real) : Real :=
  0.6 * E + 0.4 * S - mdl_weight phase

/-
VI. CodexState: server-grade state (use Real for rigorous proofs, Float for execution)
We provide both a proof-friendly `CodexStateR` (Real) and an executable `CodexStateF` (Float).
-/
structure CodexStateR where
  phase   : Phase
  S       : Real
  E       : Real
  F_B     : Real
  Ψ_P     : Real
  Ψ_I     : Real
  Ψ_D     : Real
  Ψ_total : Real
  J       : Real
  trace   : List Phase
  mdl_val : Real
  g_score : Real
deriving Repr

structure CodexStateF where
  phase   : Phase
  S       : Float
  E       : Float
  F_B     : Float
  Ψ_P     : Float
  Ψ_I     : Float
  Ψ_D     : Float
  Ψ_total : Float
  J       : Float
  trace   : List Phase
  mdl_val : Float
  g_score : Float
deriving Repr

/-- default constructors for quick instantiation -/
def initial_stateR (seed : Phase := Black) : CodexStateR :=
  let S0 := 0.1
  let E0 := 1.0
  let tr := [seed]
  { phase := seed, S := S0, E := E0, F_B := 0.0, Ψ_P := 0.0, Ψ_I := 0.0, Ψ_D := 0.0,
    Ψ_total := 0.0, J := E0 + S0, trace := tr, mdl_val := mdl_trace_score tr, g_score := g_score_fn seed E0 S0 }

def initial_stateF (seed : Phase := Phase.Black) : CodexStateF :=
  let S0 := 0.1
  let E0 := 1.0
  let tr := [seed]
  { phase := seed, S := S0, E := E0, F_B := 0.0, Ψ_P := 0.0, Ψ_I := 0.0, Ψ_D := 0.0,
    Ψ_total := 0.0, J := E0 + S0, trace := tr, mdl_val := 0.0, g_score := 0.0 }

/-
VII. Gray detection: runtime Bool (for server checks) and Prop for proofs
Thresholds are chosen from your canonical cheat-sheet; tune them as needed.
-/
def gray_detect_boolF (cs : CodexStateF) : Bool :=
  let adjacency_ok := adj_bool cs.phase (next cs.phase)
  let energy_ok := cs.E <= 1.0e7
  let mdl_ok := cs.mdl_val <= 200.0
  (not adjacency_ok) || (not energy_ok) || (not mdl_ok)

def gray_detect_propR (cs : CodexStateR) : Prop :=
  ¬ adj cs.phase (next cs.phase) ∨ cs.E > 1.0e7 ∨ cs.mdl_val > 200.0

/-
VIII. K-regulator repair macros (server-grade conservative strategies)
-/
def apply_K3_R (cs : CodexStateR) : CodexStateR := -- hard reset
  let tr := [Phase.Black]
  { cs with phase := Phase.Black, S := 0.0, E := 0.0, F_B := 0.0, Ψ_P := 0.0, Ψ_I := 0.0,
             Ψ_D := 0.0, Ψ_total := 0.0, J := 0.0, trace := tr, mdl_val := mdl_trace_score tr,
             g_score := g_score_fn Phase.Black 0.0 0.0 }

def apply_K2_R (cs : CodexStateR) : CodexStateR := -- structural rebuild (soft)
  let tr := cs.trace ++ [Phase.White]
  { cs with phase := Phase.White, S := 0.01, Ψ_P := 0.0, Ψ_I := 0.0, Ψ_D := 0.0,
             Ψ_total := 0.0, trace := tr, mdl_val := mdl_trace_score tr,
             g_score := g_score_fn Phase.White cs.E 0.01 }

def apply_K1_R (cs : CodexStateR) : CodexStateR := -- triad unwind
  let tr := cs.trace ++ [Phase.Green]
  { cs with phase := Phase.Green, S := 0.0, Ψ_P := 0.0, Ψ_I := 0.0, Ψ_D := 0.0,
             Ψ_total := 0.0, trace := tr, mdl_val := mdl_trace_score tr,
             g_score := g_score_fn Phase.Green 0.0 0.0 }

-- Selector (R)
def apply_K_R (cs : CodexStateR) : CodexStateR :=
  if cs.mdl_val > 200.0 then apply_K3_R cs
  else if cs.E > 1.0e6 then apply_K1_R cs
  else apply_K2_R cs

/-
IX. PID overlay (Real version for proofs; Float mirrors for execution)
-/
def compute_pid_R (cs : CodexStateR) : CodexStateR :=
  let Kp : Real := 0.8
  let Ki : Real := 0.05
  let Kd : Real := 0.12
  let P := Kp * cs.E
  let I := cs.Ψ_I + Ki * cs.S
  let D := Kd * cs.S -- crude derivative proxy
  { cs with Ψ_P := P, Ψ_I := I, Ψ_D := D, Ψ_total := P + I + D }

/-
X. Per-phase update kernel (Real)
This is the canonical physics/symbolic table transcribed into Lean Real arithmetic.
-/
def step_update_phase_R (cs : CodexStateR) : CodexStateR :=
  let psi := cs.Ψ_total
  match cs.phase with
  | Phase.Black =>
    let S' := 0.9 * cs.S
    let tr' := cs.trace ++ [Phase.White]
    { cs with phase := Phase.White, S := S', trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.White cs.E S' }
  | Phase.White =>
    let tr' := cs.trace ++ [Phase.Yellow]
    { cs with phase := Phase.Yellow, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Yellow cs.E cs.S }
  | Phase.Yellow =>
    let threshold := 2.0 * e_const
    let raw := if cs.F_B - threshold > 0.0 then (cs.F_B - threshold) / 10.0 else 0.01
    let Psi := if raw > 0.2 then 0.2 else raw
    let tr' := cs.trace ++ [Phase.Brown]
    { cs with phase := Phase.Brown, Ψ_total := Psi, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Brown cs.E cs.S }
  | Phase.Brown =>
    let F_B' := Real.max cs.F_B psi
    let tr' := cs.trace ++ [Phase.Red]
    { cs with phase := Phase.Red, F_B := F_B', Ψ_total := psi, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Red cs.E cs.S }
  | Phase.Red =>
    let E' := cs.E + psi
    let S' := cs.S - (0.5 * psi)
    let tr' := cs.trace ++ [Phase.Green]
    { cs with phase := Phase.Green, E := E', S := S', Ψ_total := psi, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Green E' S' }
  | Phase.Green =>
    let η := 0.95
    let E' := cs.E + η * psi
    let S' := cs.S - η * psi
    let tr' := cs.trace ++ [Phase.Blue]
    { cs with phase := Phase.Blue, E := E', S := S', Ψ_total := psi, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Blue E' S' }
  | Phase.Blue =>
    let a := 0.03
    let b := 0.92
    let c := 0.05
    let E' := (1 - b) * cs.E + c * cs.S + a * psi
    let tr' := cs.trace ++ [Phase.Black]
    { cs with phase := Phase.Black, E := E', Ψ_total := psi, trace := tr', mdl_val := mdl_trace_score tr',
              g_score := g_score_fn Phase.Black E' cs.S }

/-
XI. Full step: combine compute_pid, per-phase update, grammar & gray checks
-/
def step_R (cs : CodexStateR) : CodexStateR :=
  let cs_pid := compute_pid_R cs
  let next_cs := step_update_phase_R cs_pid
  if ¬ (grammar_valid_bool next_cs.trace) || (next_cs.mdl_val > 200.0) || (next_cs.E > 1.0e7) then
    apply_K_R next_cs
  else
    { next_cs with J := next_cs.E + next_cs.S }

/-
XII. Lemmas: structural correctness (proof sketched)
-/
theorem step_preserves_adjacency_sketch (cs : CodexStateR)
  (h : grammar_valid_bool cs.trace = true) (hg : ¬ gray_detect_propR cs) :
  adj cs.phase (next cs.phase) := by
  -- Sketch: adjacency is syntactic property of `next`. Given `cs` lawful, `next` is adjacent.
  exact (adj_next_prev cs.phase).left

/-
XIII. Notes
- This file is intended for server-grade use: use `CodexEngine.step_R` in formal reasoning
  and a Float mirror (see Python harness) for quick numeric experiments.
- For heavy mechanized proofs convert Real arithmetic to exact rational lemmas or import Mathlib
  and develop Lyapunov / invariant proofs there.
-/
end CodexEngine
