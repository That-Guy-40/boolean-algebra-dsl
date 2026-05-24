# Machines — Finite State Machines & Turing Machines

The **machine side** of the Church–Turing story, to sit opposite the function side
(`lambda.sh`). Two files, built one on the next:

- `state-machine.sh` — a **Finite State Machine**: a transition table, a start state,
  accept states. *Running an FSM is a left fold of the transition over the input*, so
  it's literally `foldl` from the list kit.
- `turing-machine.sh` — a **Turing Machine**: the same finite-state control **plus** a
  bounded read/write **tape**. That one addition (writing, and moving both ways) is
  the whole leap from FSM to universal machine.

The relationship is the theory anchor: **an FSM is the restricted special case of a
TM** — a TM that can't write and only moves one way. `test-state-machine.sh` (37
passing) and `test-turing-machine.sh` (40 passing) cover both, and wire them back to
Layer 1.

## Finite State Machine

A transition **table** is space-separated rules `state,symbol->nextstate`. Loading:

```bash
source ./state-machine.sh
```

| function | meaning |
|---|---|
| `fsm_step  TABLE STATE SYMBOL`        | one transition (→ `"DEAD"` if no rule) |
| `fsm_run   TABLE START INPUT`         | final state — **a `foldl`** of the transition |
| `fsm_trace TABLE START INPUT`         | the state after each symbol — **a `scanl`** |
| `fsm_accepts TABLE START ACCEPTS INPUT` | `"accept"` / `"reject"` |

```bash
fsm_run     "$FSM_PARITY" e '1 1 0 1'          # o      (three 1s = odd)
fsm_trace   "$FSM_PARITY" e '1 1 0 1'          # e o e e o
fsm_accepts "$FSM_DIV3" r0 r0 '1 1 0'          # accept  (110 = 6, divisible by 3)
fsm_accepts "$FSM_SEQ101" q0 q3 '0 1 0 1 0'    # accept  (contains 1 0 1)
fsm_run     "$FSM_TURNSTILE" locked 'coin push'  # locked
```

Built-in machines: `FSM_PARITY` (even/odd 1-count — ties to Layer 1's `xor_all`),
`FSM_DIV3` (divisible-by-3 over MSB-first binary), `FSM_SEQ101` (spot the substring
`1 0 1`), `FSM_TURNSTILE` (the classic locked/unlocked device). The suite checks each
verdict against an independent ground truth (popcount, value mod 3, substring search).

## Turing Machine

A **configuration** is the string `"state|head|tape"` (tape = space-separated cells).
`tm_step` is a pure function config → next config. The tape is **bounded** to `TM_TAPE`
cells (default 64), padded with the blank `TM_BLANK` (default `_`); running the head
off either end halts the machine. A **table** is rules `state,symbol->newstate,write,move`
with move ∈ `L | R | S`. Loading:

```bash
source ./turing-machine.sh        # sources state-machine.sh (the FSM idea) too
```

| function | meaning |
|---|---|
| `tm_step  TABLE CONFIG`                       | one step (→ same config, exit 1, if halted) |
| `tm_run   TABLE HALTS START INPUT [max] [h0]` | final tape (trailing blanks trimmed) |
| `tm_trace TABLE HALTS START INPUT [max] [h0]` | one configuration per line |
| `tm_steps TABLE HALTS START INPUT [max] [h0]` | number of steps taken |

```bash
tm_run "$TM_UNARY_INC" h s '1 1 1'          # 1 1 1 1       (append a stroke)
tm_run "$TM_UNARY_ADD" h a '1 1 1 + 1 1'    # 1 1 1 1 1     (3 + 2 = 5 strokes)
tm_run "$TM_FLIP"      h s '1 0 1 1'         # 0 1 0 0       (= word_not)
tm_run "$TM_BINARY_INC" h c '1 1 0 0'       # 0 0 1 0       (3 -> 4; LSB-first, = inc)
```

### Wiring the tape machine back to the gates

The headline checks: the **binary-increment TM equals Layer 1's `inc`**, and the
**bit-flip TM equals `word_not`** — a tape machine and a gate circuit computing the
identical function. (`TM_BINARY_INC` is, quite literally, Layer 1's carry ripple
walked along a tape.)

```bash
bits_to_int "$(tm_run "$TM_BINARY_INC" h c "$(int_to_bits 200 8)")"   # 201
bits_to_int "$(inc "$(int_to_bits 200 8)")"                           # 201  (same)
```

### An FSM is the restricted TM

`TM_PARITY` is a TM that only moves **right** and never **changes** a cell — which is
exactly an FSM. It halts in `he` (even) / `ho` (odd), matching `FSM_PARITY`'s `e` / `o`.
That equivalence is the theory anchor made runnable.

### Busy beavers

Run with `TM_BLANK=0` and a centred head (so there is room to move left). They halt —
after writing a startling number of 1s:

```bash
TM_BLANK=0
tm_run   "$TM_BB3" H A '' 100 $((TM_TAPE/2))   # six 1s
tm_steps "$TM_BB3" H A '' 100 $((TM_TAPE/2))   # 14   (the 3-state busy-beaver champion)
```

`TM_BB2` writes 4 ones in 6 steps; `TM_BB3` writes 6 in 14. They make the **halting**
question vivid: tiny machines, surprising runtimes, but they *do* stop.

## Tests

```bash
bash tests/test-state-machine.sh    # 37 passed, 0 failed
bash tests/test-turing-machine.sh   # 40 passed, 0 failed
```

> *Toward the capstone:* with the **machine** side here (FSM → Turing machine) and the
> **function** side already built (`lambda.sh` + Church numerals), the two halves of
> Church–Turing finally both exist. The finale is to compute one function *both* ways —
> a Turing machine and a Church/lambda term — and watch them agree (e.g. this binary
> increment vs. `church_succ`). See `TODO.md`.

---

*This is the reference; the plain-English walkthrough is
[`../TUTORIAL_LAYER7_MACHINES.md`](../TUTORIAL_LAYER7_MACHINES.md) (a turnstile, a parity
counter, then a tape machine that does Layer 1's arithmetic). The finale that makes the
machine and function sides agree is
[`../TUTORIAL_LAYER8_CHURCH_TURING.md`](../TUTORIAL_LAYER8_CHURCH_TURING.md). For every
layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
