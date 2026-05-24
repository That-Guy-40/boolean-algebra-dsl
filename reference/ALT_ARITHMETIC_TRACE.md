# Alt-Arithmetic Trace — a viewer for Layer 4 (number, built three ways)

Layer 4 defines *number* three different ways, and each hides its work. This is a
**read-only viewer** over `alt-arithmetic.sh`, in the spirit of `add_trace` /
`fsm_trace`: it changes nothing in the layer and drives the **same primitives**
(`peano_succ`/`peano_add`, the real numeral iteration, `mod_reduce`/`mod_mul`), so
each picture stays faithful to the model it draws. Lives in `alt-arithmetic-trace.sh`.

Each model gets a trace shaped to *its* idea of number:

| model | the idea | what the trace shows |
|---|---|---|
| **Peano** | a number is a tower of successors | the repeated `+1`, each one Layer-1 `inc` |
| **Church** | a number is "apply f n times" | the numeral iterating a step function |
| **Modular** | count past n−1 and wrap | the clock wrap, `raw = q·n + r` |

Bit strings are **LSB-first**, as everywhere in the project.

## Loading

```bash
source ./alt-arithmetic-trace.sh        # sources alt-arithmetic.sh (and Layer 1) for you
```

## The functions

| function | shows |
|---|---|
| `peano_trace OP A B [W]` | `A (OP) B` as its repeated lower operation. `OP ∈ add sub mult expt` |
| `church_trace N [int\|bits] [W]` | numeral `N` applying a step function `N` times (`int` = +1; `bits` = Layer-1 `inc`) |
| `mod_trace OP A B N` | `(A OP B) mod N` as `raw = q·N + r`, with a clock. `OP ∈ add sub mul` |
| `mod_trace_pow BASE E N` | `BASE^E mod N` by square-and-multiply, one row per exponent bit |

## `peano_trace` — a number is repeated succession

The headline of Layer 4: a Peano successor **is** Layer-1's `inc`, so addition is just
`+1` rippling the gates. `peano_trace add A B` shows `A`, then `B` successors:

```bash
peano_trace add 3 2          # 3 + 2
```
```
  Peano ADD  3 + 2   (width 8, LSB-first)
  "+2" = apply the successor 2 times; each S is Layer-1 inc

  step       value   bits
  ─────────────────────────────────────────
  start        3   1 1 0 0 0 0 0 0
  S (inc)      4   0 0 1 0 0 0 0 0
  S (inc)      5   1 0 1 0 0 0 0 0
  ─────────────────────────────────────────
  result = 5
```

`mult` shows repeated addition (`3 × 4` = add 3 to a total four times), `expt` repeated
multiplication, `sub` repeated predecessor. And `peano_trace add 0 N` draws the **tower
of successors** that builds `N` from zero — `5 = S(S(S(S(S(0)))))`, each step a real `inc`.

## `church_trace` — a number is "do f n times"

A Church numeral `N` is the function `λf. f∘f∘…∘f` (`N` copies). The trace picks a
concrete step function and watches it iterate:

```bash
church_trace 4               # integer successor (+1) from 0
church_trace 4 bits          # the same, but driving Layer-1 inc — the function↔gate handshake
```
```
  Church numeral 4  =  λf. f∘f∘…∘f   ("do f 4 times")
  iterating Layer-1 `inc` on all-zeros — the function↔gate handshake:

  apply #0   0 0 0 0 0 0 0 0  (=0)
  apply #1   1 0 0 0 0 0 0 0  (=1)
  …
  result = 0 0 1 0 0 0 0 0  (=4)   (= church_to_bits 4)
```

The `bits` mode is the literal handshake from the capstone: a pure function (the
numeral) driving the real gate circuit (`inc`) to build its own bit pattern.

## `mod_trace` — count past the top and wrap

Clock arithmetic made visible: the raw result, how many full turns it is, and where the
hand lands. Negative results (from `sub`) turn the clock backward.

```bash
mod_trace add 10 5 12        # 10 + 5 on a 12-clock
```
```
  Modular ADD  (10 + 5) mod 12
    10 + 5 = 15
    15 = 1 × 12 + 3   (one full turn, then 3)
    result = 3

    clock(12): 0 1 2 [3] 4 5 6 7 8 9 10 11
```

The clock face is drawn for moduli up to 24 (above that it's omitted but the
`raw = q·n + r` line still tells the whole story).

## `mod_trace_pow` — square-and-multiply, step by step

`base^e mod n` without the intermediates blowing up: square the base each step, and
fold it into the result only on the exponent bits that are 1.

```bash
mod_trace_pow 2 10 1000      # 2^10 mod 1000
```
```
  Modular POW  2^10 mod 1000   (square-and-multiply)
  exponent 10 in binary (LSB-first): 0 1 0 1

  bit  e&1  base (mod n)   result (mod n)
  ──────────────────────────────────────
    0   0   2            1
    1   1   4            4
    2   0   16           4
    3   1   256          24
  ──────────────────────────────────────
  result = 24   (rows where e&1=1 multiply the running result in)
```

## Why it can't lie

The viewer never re-implements the math: `peano_trace` steps the real `peano_succ` /
`peano_add` / `peano_mult`, `church_trace` iterates the actual step function (and is
checked against `church_to_int` / `church_to_bits`), and the modular traces use
`mod_reduce` / `mod_mul`. The test suite pins every trace's reported result against an
**independent** call to the real `peano_*` / `church_*` / `mod_*` functions over a
sweep, so the drawing is guaranteed faithful.

## Tests

```bash
bash tests/test-alt-arithmetic-trace.sh    # 131 passed, 0 failed   (standalone; ~40s)
```

A standalone (non-core) suite — the Peano traces ripple through the gate layer, so it's
deliberately slow, and kept separate from the fast core per the project convention.

---

*This is a viewer over **Layer 4** — see [`ALT_ARITHMETIC.md`](ALT_ARITHMETIC.md) for the
Peano / Church / modular models it traces, and
[`../TUTORIAL_LAYER4_ALT_ARITHMETIC.md`](../TUTORIAL_LAYER4_ALT_ARITHMETIC.md) for the
plain-English build. It's the same idea as the Layer-1 viewer
[`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md) and the machine-layer traces in
[`MACHINES.md`](MACHINES.md), pointed at the number models. For every layer at once, see
[`OVERVIEW.md`](OVERVIEW.md).*
